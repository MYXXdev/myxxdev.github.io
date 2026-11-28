#import "../Shared/MYBSupervision.h"
#import "../Shared/MYBRedirectPolicy.h"
#import "../Shared/MYBPACDecision.h"
static void require(BOOL ok,const char *s){if(!ok){fprintf(stderr,"FAIL %s\n",s);exit(1);}}
static BOOL redirectIntercepted(NSDictionary *settings,NSString *source,NSString *destination,BOOL link){return MYBRedirectClassify(settings,source,destination,link)!=MYBRedirectNone;}
int main(void){@autoreleasepool{
 NSString *url=@"https://adult.example/path",*base=@"function FindProxyForURL(u,h){return h==='ads.example'?'PROXY 127.0.0.1:8788':'DIRECT';}",*adult=@"function FindProxyForURL(u,h){return h==='adult.example'||h==='ads.example'?'PROXY 127.0.0.1:8788':'DIRECT';}";
  {
  __block int rateCalls=0;BOOL(^rate)(void)=^BOOL{rateCalls++;return YES;};BOOL(^noRate)(void)=^BOOL{rateCalls++;return NO;};
  require(MYBRedirectPromptPlan(NO,YES,NO,rate)==MYBPromptLeaveAlone&&rateCalls==0,"locked or unknown lock state: leave the transition alone, no prompt, rate limiter untouched");
  require(MYBRedirectPromptPlan(YES,NO,NO,rate)==MYBPromptUnavailable&&rateCalls==0,"no way to present: declined as 'unavailable' (recorded), never claims an option");
  require(MYBRedirectPromptPlan(YES,YES,YES,rate)==MYBPromptSuppressed&&rateCalls==0,"a prompt already on screen suppresses a second one");
  require(MYBRedirectPromptPlan(YES,YES,NO,noRate)==MYBPromptSuppressed&&rateCalls==1,"rate-limited repeat is suppressed");
  require(MYBRedirectPromptPlan(YES,YES,NO,rate)==MYBPromptShow&&rateCalls==2,"otherwise the prompt is shown");
  require([MYBRedirectPlanReason(MYBPromptUnavailable,@"appstore") isEqual:@"prompt-unavailable"]&&[MYBRedirectPlanReason(MYBPromptSuppressed,@"appredirect") isEqual:@"prompt-suppressed"]&&[MYBRedirectPlanReason(MYBPromptShow,@"appstore") isEqual:@"appstore"],"activity reasons distinguish the three outcomes");
 }
require([MYBBlockAttribution(url,@"blockXXX",adult,base,@{},nil) isEqual:@"Blocked by MYbloXX® noXXX rules."],"adult category provenance");
 require([MYBBlockAttribution(@"https://ads.example/",@"blockXXX",adult,base,@{},nil) isEqual:@"Blocked by MYbloXX® Default rules."],"Default provenance takes precedence over selected category");
 require([MYBBlockAttribution(url,@"Custom",adult,base,@{@"blocked":@[@"adult.example"]},nil) isEqual:@"Blocked by your MYbloXX® rules."],"applied custom provenance");
 require([MYBBlockAttribution(url,@"blockXXX",adult,base,@{@"blocked":@[@"adult.example"]},nil) isEqual:@"Blocked by MYbloXX® noXXX rules."],"inactive custom list must not claim block");
 require([MYBBlockAttribution(url,@"blockXXX",nil,base,@{},nil) isEqual:@"Blocked by MYbloXX®."],"unverified provenance remains neutral");
 require([MYBBlockAttribution(url,nil,nil,nil,nil,@"custom") isEqual:@"Blocked by your MYbloXX® rules."],"verified browser custom rule");
 require(MYBEvaluatePAC(@"function FindProxyForURL(u,h){while(true){} }",url,@"adult.example")==nil,"execution deadline");
 require(redirectIntercepted(@{},@"com.apple.mobilesafari",@"com.apple.AppStore",YES),"Safari protected by default");
 require(redirectIntercepted(@{},@"org.mozilla.ios.Firefox",@"com.apple.ios.StoreKitUIService",YES),"Firefox store transitions protected");
 require(!redirectIntercepted(@{},@"com.apple.springboard",@"com.apple.AppStore",YES),"direct App Store launch untouched");
 require(!redirectIntercepted(@{},@"com.apple.mobilesafari",@"com.google.ios.youtube",YES),"other app handoffs untouched");
 require(!redirectIntercepted(@{@"RedirectEnabled":@NO},@"com.apple.mobilesafari",@"com.apple.AppStore",YES),"master off");
 require(!redirectIntercepted(@{@"RedirectApps":@{@"com.apple.mobilesafari":@NO}},@"com.apple.mobilesafari",@"com.apple.AppStore",YES),"per-app exception");
 require(redirectIntercepted(@{@"RedirectApps":@{@"test.app":@YES}},@"test.app",@"com.apple.AppStore",YES),"selected app protected");
 require(!redirectIntercepted(@{},@"com.apple.mobilesafari",@"com.apple.AppStore",NO),"non-link launch untouched");
 require(MYBRedirectClassify(@{},@"com.apple.mobilesafari",@"com.apple.AppStore",YES)==MYBRedirectAppStore,"app store kind");
 require(MYBRedirectClassify(@{@"RedirectOtherApps":@YES},@"com.apple.mobilesafari",@"com.google.ios.youtube",YES)==MYBRedirectApp,"other app redirects are opt-in");
 require(MYBRedirectClassify(@{@"RedirectOtherApps":@YES},@"com.apple.mobilesafari",@"com.apple.springboard",YES)==MYBRedirectNone,"never intercept a move to SpringBoard");
 require(MYBRedirectClassify(@{@"RedirectOtherApps":@YES,@"RedirectApps":@{@"com.apple.mobilesafari":@NO}},@"com.apple.mobilesafari",@"com.google.ios.youtube",YES)==MYBRedirectNone,"unselected source untouched");
 require(MYBRedirectClassify(@{@"RedirectOtherApps":@YES,@"RedirectEnabled":@NO},@"com.apple.mobilesafari",@"com.google.ios.youtube",YES)==MYBRedirectNone,"master off");
 // App Redirect Protection: one switch over the two older keys. Every combination, including absent keys, maps explicitly.
 require(MYBRedirectProtectionState(@{@"RedirectEnabled":@YES,@"RedirectOtherApps":@YES})==MYBRedirectProtectionOn,"both on shows On");
 require(MYBRedirectProtectionState(@{@"RedirectEnabled":@NO,@"RedirectOtherApps":@NO})==MYBRedirectProtectionOff,"both off shows Off");
 require(MYBRedirectProtectionState(@{@"RedirectEnabled":@NO,@"RedirectOtherApps":@YES})==MYBRedirectProtectionOff,"master off wins: other apps was ignored while it was off");
 require(MYBRedirectProtectionState(@{@"RedirectEnabled":@YES,@"RedirectOtherApps":@NO})==MYBRedirectProtectionAppStoreOnly,"mixed state is kept and shown as App Store only");
 require(MYBRedirectProtectionState(@{})==MYBRedirectProtectionAppStoreOnly,"an old install with neither key behaves as before: App Store only");
 require(MYBRedirectProtectionState(@{@"RedirectOtherApps":@YES})==MYBRedirectProtectionOn,"absent master counts as on, as before");
 {
  // The shown state always agrees with what the policy really intercepts (nothing widened, nothing dropped).
  NSArray *values=@[@YES,@NO,[NSNull null]];
  for(id enabled in values)for(id other in values){
   NSMutableDictionary *settings=[NSMutableDictionary dictionary];if(![enabled isKindOfClass:NSNull.class])settings[@"RedirectEnabled"]=enabled;if(![other isKindOfClass:NSNull.class])settings[@"RedirectOtherApps"]=other;
   MYBRedirectProtection shown=MYBRedirectProtectionState(settings);
   BOOL appStore=MYBRedirectClassify(settings,@"com.apple.mobilesafari",@"com.apple.AppStore",YES)==MYBRedirectAppStore;
   BOOL otherApp=MYBRedirectClassify(settings,@"com.apple.mobilesafari",@"com.google.ios.youtube",YES)==MYBRedirectApp;
   require(appStore==(shown!=MYBRedirectProtectionOff)&&otherApp==(shown==MYBRedirectProtectionOn),"displayed state equals real interception");
  }
  NSMutableDictionary *edit=[@{@"RedirectEnabled":@YES,@"RedirectOtherApps":@NO,@"RedirectApps":@{@"x.app":@YES}} mutableCopy];
  MYBRedirectProtectionApply(edit,YES);require([edit[@"RedirectOtherApps"] boolValue]&&MYBRedirectProtectionState(edit)==MYBRedirectProtectionOn,"turning it on ends the mixed state");
  require([edit[@"RedirectApps"][@"x.app"] boolValue],"app choices untouched");
  MYBRedirectProtectionApply(edit,NO);require(MYBRedirectProtectionState(edit)==MYBRedirectProtectionOff&&![edit[@"RedirectOtherApps"] boolValue],"turning it off clears both");
 }
 NSFileManager *fm=NSFileManager.defaultManager;NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];NSString *config=[root stringByAppendingPathComponent:@"config.plist"],*record=[root stringByAppendingPathComponent:@"backup.plist"];
 [@{@"IsSupervised":@NO,@"Unrelated":@"before"} writeToFile:config atomically:YES];require(MYBChangeSupervision(YES,config,record)==0,"enable supervision");require([MYBSupervisionStatus(config,record)[@"owned"] boolValue],"owned value verified");
 NSMutableDictionary *current=[[NSDictionary dictionaryWithContentsOfFile:config] mutableCopy];current[@"Unrelated"]=@"after";[current writeToFile:config atomically:YES];require(MYBChangeSupervision(NO,config,record)==0,"restore supervision value");current=[[NSDictionary dictionaryWithContentsOfFile:config] mutableCopy];require(![current[@"IsSupervised"] boolValue]&&[current[@"Unrelated"] isEqual:@"after"],"preserve unrelated later edits");
 current[@"IsSupervised"]=@YES;[current writeToFile:config atomically:YES];require(MYBChangeSupervision(YES,config,record)==3&&MYBChangeSupervision(NO,config,record)==3,"foreign supervision untouched");
 [@{@"Unrelated":@"retained"} writeToFile:config atomically:YES];require(MYBChangeSupervision(YES,config,record)==0&&MYBChangeSupervision(NO,config,record)==0,"missing-key supervision round trip");require([NSDictionary dictionaryWithContentsOfFile:config][@"IsSupervised"]==nil,"original missing key retained");// A clean unmanaged device can have the directory but no details plist.
 NSString *fresh=[root stringByAppendingPathComponent:@"fresh.plist"];
 NSString *freshRecord=[root stringByAppendingPathComponent:@"fresh-owner.plist"];
 require([MYBSupervisionStatus(fresh,freshRecord)[@"available"] boolValue],"missing plist has a safe writable parent");
 require(MYBChangeSupervision(YES,fresh,freshRecord)==0,"create owned supervision details");
 require([NSDictionary dictionaryWithContentsOfFile:fresh][@"IsSupervised"]!=nil,"owned minimal record created");
 require(MYBChangeSupervision(NO,fresh,freshRecord)==0,"remove owned minimal record");
 require(![fm fileExistsAtPath:fresh] && ![fm fileExistsAtPath:freshRecord],"original file absence restored");
 [fm removeItemAtPath:root error:NULL];
 printf("B22 provenance, redirect policy and reversible supervision checks passed.\n");
 }return 0;}
