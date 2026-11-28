// Amazon module: the rule list, the hook that adds it to every web view's controller, and the discovery script.
// Stand-in WebKit classes prove the module's own logic. Whether the real Amazon app's pages carry these markers, and whether WebKit hides
// them, is a device check; nothing here proves it.
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include "../Companions/InAppAds/Amazon/Module.m"
static int failures=0;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)
@interface FakeController:NSObject @property NSMutableArray *lists;@end
@implementation FakeController
- (instancetype)init{if((self=[super init]))_lists=[NSMutableArray array];return self;}
- (void)addContentRuleList:(id)l{[self.lists addObject:l];}
@end
@interface FakeConfig:NSObject @property(strong) FakeController *userContentController;@end
@implementation FakeConfig @end
static BOOL initialised;
static id fakeInit(id self,SEL _cmd,CGRect frame,id config){initialised=YES;return self;}
int main(void){@autoreleasepool{
 // rules
 NSArray *rules=[NSJSONSerialization JSONObjectWithData:[MYBAmazonRuleJSON() dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
 REQUIRE(rules.count==1&&[rules[0][@"action"][@"type"] isEqual:@"css-display-none"]&&[rules[0][@"trigger"][@"url-filter"] isEqual:@".*"],"the rule list is one valid css-display-none rule");
 NSString *sel=rules[0][@"action"][@"selector"];
 REQUIRE([sel containsString:@"[data-ad-placement-metadata]"]&&[sel containsString:@"[data-ad-feedback-label-id]"],"the two confirmed markers are hidden");
 REQUIRE(![sel containsString:@"sponsored"]&&![sel containsString:@"isSponsored"],"unconfirmed markers are never hidden");
 REQUIRE(![MYBAmazonRuleJSON() containsString:@"http"],"nothing is fetched: no URL in the rules");
 // hook
 REQUIRE(MYBAmazonInstallHooks(NULL)==0,"no web view class, no hook");
 Class web=objc_allocateClassPair(NSObject.class,"WKWebView",0);objc_registerClassPair(web);
 class_addMethod(web,sel_registerName("initWithFrame:configuration:"),(IMP)fakeInit,"@@:{CGRect={CGPoint=dd}{CGSize=dd}}@");
 NSUInteger attempted=0;REQUIRE(MYBAmazonInstallHooks(&attempted)==1&&attempted==1,"the web view initialiser is hooked");
 SEL initSel=sel_registerName("initWithFrame:configuration:");
 FakeConfig *early=[FakeConfig new];early.userContentController=[FakeController new];
 initialised=NO;id v1=((id(*)(id,SEL,CGRect,id))objc_msgSend)([web alloc],initSel,CGRectZero,early);
 REQUIRE(v1&&initialised&&early.userContentController.lists.count==0,"before the rules are compiled nothing is added and the app's init still runs");
 MYBAmazonListReady(@"compiled-list");
 REQUIRE([early.userContentController.lists isEqual:@[@"compiled-list"]],"a controller created before the rules were ready receives them");
 FakeConfig *late=[FakeConfig new];late.userContentController=[FakeController new];
 ((id(*)(id,SEL,CGRect,id))objc_msgSend)([web alloc],initSel,CGRectZero,late);
 REQUIRE([late.userContentController.lists isEqual:@[@"compiled-list"]],"a controller created after receives them before its web view exists");
 MYBAmazonListReady(nil);
 REQUIRE([late.userContentController.lists count]==1,"a refused compile changes nothing");
 FakeConfig *none=[FakeConfig new];
 REQUIRE(((id(*)(id,SEL,CGRect,id))objc_msgSend)([web alloc],initSel,CGRectZero,none)!=nil,"a configuration without a controller is passed through");
 // discovery script: run it against a stub document
 JSContext *ctx=[JSContext new];
 ctx[@"document"]=@{};
 [ctx evaluateScript:@"var document={querySelectorAll:function(s){ if(s.indexOf('data-ad-placement')>=0)return [1,2,3]; if(s.indexOf('puis')>=0)throw new Error('bad'); return []; }};"];
 NSString *out=[[ctx evaluateScript:MYBAmazonDiscoveryScript()] toString];
 NSArray *counts=[out componentsSeparatedByString:@","];
 REQUIRE(counts.count==MYBAmazonHiddenSelectors().count+MYBAmazonCandidateSelectors().count,"one number per selector");
 REQUIRE([counts[0] isEqual:@"3"]&&[counts[1] isEqual:@"0"],"counts of the hidden markers");
 REQUIRE([counts containsObject:@"-1"],"a selector WebKit rejects reports -1, not a crash");
 for(NSString *c in counts)REQUIRE([c rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"-0123456789"] invertedSet]].location==NSNotFound,"the script returns numbers only, never page text");
 if(failures)return 1;printf("Amazon ad module checks passed.\n");return 0;}}
