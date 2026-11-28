#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <notify.h>
#import <roothide.h>
#import <CommonCrypto/CommonDigest.h>
#import "../../Shared/MYBCleanupRules.h"
#import "../../Shared/MYBConnectivity.h"

// MYbloXX® Safari Cleanup. Safari only (the filter plist), and separate from popup permissions, redirects and phone-wide domain rules. It adds one WebKit
// content-rule list that HIDES named page elements with CSS. It never clicks, accepts or dismisses anything, never reads page content, and writes no URLs.
static NSString *PrefsFile(void){return MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.cleanup.plist");}
static NSString *RulesFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/CleanupRules.json");}
static NSString *GoodFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/CleanupRulesLastGood.json");}
static NSString *StatusFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/CleanupStatus.plist");}
static NSHashTable<WKWebView *> *Views;
static WKContentRuleList *Current;
static NSString *CurrentID,*Source=@"built-in";
static NSUInteger Generation,Applied;
static NSTimer *PauseTimer;

static void WriteStatus(NSString *state){
 NSDictionary *status=@{@"loaded":@YES,@"state":state?:@"",@"rules":Source?:@"",@"views":@(Views.count),@"applied":@(Applied),@"time":@(NSDate.date.timeIntervalSince1970)};
 NSString *file=StatusFile();[NSFileManager.defaultManager createDirectoryAtPath:file.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];[status writeToFile:file atomically:YES];
}
static void Attach(WKWebView *view){
 WKContentRuleList *list=Current;if(!list)return;
 WKUserContentController *controller=view.configuration.userContentController;if(!controller)return;
 [controller addContentRuleList:list];Applied++;
}
static void Detach(WKContentRuleList *list){
 if(!list)return;for(WKWebView *view in Views.allObjects)[view.configuration.userContentController removeContentRuleList:list];
}
static void Reload(void){
 NSUInteger generation=++Generation;
 NSDictionary *config=[NSDictionary dictionaryWithContentsOfFile:PrefsFile()]?:@{};
 NSString *source=nil;NSDictionary *rules=MYBCleanupLoad(RulesFile(),GoodFile(),&source);Source=source;
 double now=NSDate.date.timeIntervalSince1970;
 [PauseTimer invalidate];PauseTimer=nil;
 id until=config[@"CleanupPausedUntil"];
 if([until isKindOfClass:NSNumber.class]&&[until doubleValue]>now)PauseTimer=[NSTimer scheduledTimerWithTimeInterval:[until doubleValue]-now+1 repeats:NO block:^(NSTimer *t){(void)t;Reload();}];
 NSString *json=MYBCleanupRuleJSON(rules,config,now);
 if(!json){WKContentRuleList *old=Current;Current=nil;Detach(old);WriteStatus(MYBCleanupPaused(config,now)?@"paused":@"off");return;}
 unsigned char digest[CC_SHA256_DIGEST_LENGTH];NSData *bytes=[json dataUsingEncoding:NSUTF8StringEncoding];CC_SHA256(bytes.bytes,(CC_LONG)bytes.length,digest);
 NSMutableString *hex=[NSMutableString stringWithString:@"MYBCleanup-"];for(int i=0;i<8;i++)[hex appendFormat:@"%02x",digest[i]];
 NSString *identifier=hex;
 [WKContentRuleListStore.defaultStore compileContentRuleListForIdentifier:identifier encodedContentRuleList:json completionHandler:^(WKContentRuleList *list,NSError *error){
  dispatch_async(dispatch_get_main_queue(),^{
   if(generation!=Generation)return;                                     // a newer change already took over
   if(!list||error){WriteStatus(@"rejected-kept-previous");return;}       // a rule WebKit refuses never replaces the working set
   WKContentRuleList *old=Current;NSString *oldID=CurrentID;
   Current=list;CurrentID=identifier;for(WKWebView *view in Views.allObjects){if(old)[view.configuration.userContentController removeContentRuleList:old];Attach(view);}
   if(oldID&&![oldID isEqual:identifier])[WKContentRuleListStore.defaultStore removeContentRuleListForIdentifier:oldID completionHandler:^(NSError *e){(void)e;}];
   WriteStatus(@"active");
  });
 }];
}
%hook WKWebView
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
 WKWebView *view=%orig;
 if(view){[Views addObject:view];Attach(view);}
 return view;
}
%end
%ctor {
 if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.mobilesafari"])return;   // Safari is verified first; other browsers are not covered
 Views=[NSHashTable weakObjectsHashTable];
 %init;
 dispatch_async(dispatch_get_main_queue(),^{Reload();});
 static int token=0;
 notify_register_dispatch("net.myxxdev.mybloxx.cleanup.changed",&token,dispatch_get_main_queue(),^(int t){(void)t;Reload();});
}
