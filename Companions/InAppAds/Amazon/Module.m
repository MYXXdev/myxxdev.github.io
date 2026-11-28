// MYbloXX In-App Ad Blocking: Amazon Shopping (web content inside the app). Ads only.
//
// PROVENANCE: the choice of page markers (the ad-placement and ad-feedback data attributes that mark a sponsored result) comes from the
// "amznkiller" selector list named in the project brief. That project was NOT available to read or pin here, so this module is written
// from the marker names alone; no source text is used and its revision is not recorded. See NOTICE.md (usr/share/doc/mybloxx-inappads).
//
// How it works: a small bundled content rule list (WebKit's own, no JavaScript and nothing fetched from the internet) hides the elements
// that carry those markers, and is added to every WKWebView the Amazon app creates. Only this app loads this module.
//   Covered: sponsored results in Amazon's web-rendered pages (search, product pages) where they carry the confirmed markers.
//   NOT covered: native (non-web) cells, video ads, and the markers whose exact form is unconfirmed (isSponsoredProduct,
//   puis-sponsored-label-text, sponsored-products-detail-mobile). Hiding by a label alone could hide organic content, so those are only
//   counted by the opt-in discovery below, never hidden.
// Discovery (Status > Collect discovery details, off by default): a few times shortly after a page loads, counts how many elements match each
// candidate marker and logs the numbers only (never page text). That is the one focused device collection step that decides whether the
// unconfirmed markers can be used.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_ADS_COUNTER
#define MYB_ADS_COUNTER MYBAmazonDiscoveryCounter // one class per module: they share one dylib (a test that includes several modules in one file keeps the first name)
#endif
#import "../../../Shared/MYBAdsDiscovery.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#import <UIKit/UIKit.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations" // UIApplication.windows: the discovery walk only needs every window
#endif

static IMP origInitWithConfig;
static id MYBAmazonRuleList; // the compiled WKContentRuleList, once WebKit has compiled it
static NSHashTable *MYBAmazonControllers;

// The markers that are hidden (confirmed form: data attributes on the sponsored result).
NSArray<NSString *> *MYBAmazonHiddenSelectors(void){return @[@"[data-ad-placement-metadata]",@"[data-ad-feedback-label-id]"];}
// Candidates that are only counted, never hidden, until a device collection confirms how they appear.
NSArray<NSString *> *MYBAmazonCandidateSelectors(void){return @[@"[isSponsoredProduct]",@".isSponsoredProduct",@".puis-sponsored-label-text",@"[class*='sponsored-products-detail-mobile']",@"[id*='sponsored-products-detail-mobile']"];}
NSString *MYBAmazonRuleJSON(void){
 NSArray *rules=@[@{@"trigger":@{@"url-filter":@".*"},@"action":@{@"type":@"css-display-none",@"selector":[MYBAmazonHiddenSelectors() componentsJoinedByString:@", "]}}];
 NSData *data=[NSJSONSerialization dataWithJSONObject:rules options:0 error:NULL];
 return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
// Adds the compiled list to a user content controller (anything that answers addContentRuleList:). Returns YES when added.
BOOL MYBAmazonApply(id controller){
 SEL sel=sel_registerName("addContentRuleList:");
 if(!MYBAmazonRuleList||!controller||![controller respondsToSelector:sel])return NO;
 ((void(*)(id,SEL,id))objc_msgSend)(controller,sel,MYBAmazonRuleList);return YES;
}
static void MYBAmazonRegister(id controller){
 if(!controller)return;
 @synchronized(MYBAmazonControllers){[MYBAmazonControllers addObject:controller];}
 MYBAmazonApply(controller);
}
static id hookInitWithConfig(id self,SEL _cmd,CGRect frame,id configuration){
 id controller=[configuration respondsToSelector:sel_registerName("userContentController")]?((id(*)(id,SEL))objc_msgSend)(configuration,sel_registerName("userContentController")):nil;
 MYBAmazonRegister(controller); // before the web view exists, so even its first page is filtered
 return ((id(*)(id,SEL,CGRect,id))origInitWithConfig)(self,_cmd,frame,configuration);
}
// Called when WebKit has compiled the rules: controllers created earlier receive the list now.
void MYBAmazonListReady(id list){
 if(!list)return;
 MYBAmazonRuleList=list;
 NSArray *all;@synchronized(MYBAmazonControllers){all=MYBAmazonControllers.allObjects;}
 for(id c in all)MYBAmazonApply(c);
}
// WebKit compiles the rule list asynchronously; controllers created before it is ready receive it as soon as it is.
static void MYBAmazonCompile(void){
 Class store=NSClassFromString(@"WKContentRuleListStore");SEL def=sel_registerName("defaultStore");
 if(!store||![store respondsToSelector:def])return;
 id s=((id(*)(id,SEL))objc_msgSend)(store,def);
 SEL compile=sel_registerName("compileContentRuleListForIdentifier:encodedContentRuleList:completionHandler:");
 if(![s respondsToSelector:compile])return;
 void(^done)(id,NSError *)=^(id list,NSError *error){
  MYBAmazonListReady(list); // a refusal (nil) hides nothing and leaves the app untouched
 };
 ((void(*)(id,SEL,id,id,id))objc_msgSend)(s,compile,@"net.myxxdev.mybloxx.amazon",MYBAmazonRuleJSON(),done);
}
NSUInteger MYBAmazonInstallHooks(NSUInteger *attempted){
 if(!MYBAmazonControllers)MYBAmazonControllers=[NSHashTable weakObjectsHashTable];
 NSUInteger ok=0;
 if(MYBAdsHookNamed("WKWebView","initWithFrame:configuration:",NO,(IMP)hookInitWithConfig,&origInitWithConfig))ok++;
 if(attempted)*attempted=1;
 return ok;
}
// The counting script for discovery: numbers only.
NSString *MYBAmazonDiscoveryScript(void){
 NSMutableArray *parts=[NSMutableArray array];
 for(NSString *s in [MYBAmazonHiddenSelectors() arrayByAddingObjectsFromArray:MYBAmazonCandidateSelectors()]){
  NSData *quoted=[NSJSONSerialization dataWithJSONObject:@[s] options:0 error:NULL];
  NSString *lit=[[NSString alloc] initWithData:[quoted subdataWithRange:NSMakeRange(1,quoted.length-2)] encoding:NSUTF8StringEncoding];
  [parts addObject:[NSString stringWithFormat:@"(function(){try{return document.querySelectorAll(%@).length}catch(e){return -1}})()",lit]];
 }
 return [NSString stringWithFormat:@"[%@].join(',')",[parts componentsJoinedByString:@","]];
}
#ifndef MYB_INAPPADS_TESTING
// Discovery is its own thing: it needs no hook, no rule list and no ad switch. It looks at every web view the app has, counts markers, and
// stops by itself when the session ends. Six samples, 20 seconds apart, starting when the session starts.
static void MYBAmazonDiscover(void){
 NSArray *names=[MYBAmazonHiddenSelectors() arrayByAddingObjectsFromArray:MYBAmazonCandidateSelectors()];
 for(int i=1;i<=6;i++){
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(i*20*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   if(!MYBAdsDiscoveryLive(@"amazon"))return; // ended, stopped or replaced: no more samples
   for(UIWindow *w in UIApplication.sharedApplication.windows){
    NSMutableArray *queue=[NSMutableArray arrayWithObject:w];NSUInteger visited=0;
    while(queue.count&&visited<3000){
     UIView *v=queue.firstObject;[queue removeObjectAtIndex:0];visited++;
     Class web=NSClassFromString(@"WKWebView"); // looked up by name so WebKit is not linked into every app this dylib loads in
     if(web&&[v isKindOfClass:web]){
      void(^reply)(id,NSError *)=^(id result,NSError *error){
       if(![result isKindOfClass:NSString.class])return;
       NSArray *counts=[(NSString *)result componentsSeparatedByString:@","];
       NSMutableDictionary *seen=[NSMutableDictionary dictionary];
       for(NSUInteger k=0;k<names.count&&k<counts.count;k++)seen[names[k]]=@([counts[k] integerValue]); // our own selector text and a count each; nothing from the page
       MYBAdsDiscoveryLog(@"amazon",@{@"phase":@"counts",@"selectorCounts":seen});
      };
      ((void(*)(id,SEL,id,id))objc_msgSend)(v,sel_registerName("evaluateJavaScript:completionHandler:"),MYBAmazonDiscoveryScript(),reply);
     }
     [queue addObjectsFromArray:v.subviews];
    }
   }
  });
 }
}
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_amazon(void){
 @autoreleasepool{
  // Discovery first and unconditionally: a session works with the ad switch off, and starts in an app that is already open.
  MYBAdsDiscoveryWatch(@"amazon",^(NSString *session){
   MYBAdsDiscoveryStarted(@"amazon",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);MYBAmazonDiscover();
  });
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"amazon"))return;
  MYBAdsReportLoaded(@"amazon",@MYB_COMPONENT_VERSION);
  NSUInteger attempted=0,ok=MYBAmazonInstallHooks(&attempted);
  MYBAdsLogResult("amazon",ok,attempted);
  MYBAdsReportHooks(@"amazon",ok,attempted,0);
  if(ok)dispatch_async(dispatch_get_main_queue(),^{MYBAmazonCompile();});
 }
}
#else
void MYBAmazonCompileForTesting(void){MYBAmazonCompile();}
#endif
