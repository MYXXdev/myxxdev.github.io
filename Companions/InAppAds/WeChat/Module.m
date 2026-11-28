// MYbloXX In-App Ad Blocking: WeChat. Ads only.
// PROVENANCE: written against interface evidence (class and selector names published by WechatNoAds (hopeless, MIT)); no source text is used, but the choice of
// which methods to switch off follows it. See NOTICE.md in usr/share/doc/mybloxx-inappads. Each rule below is a table entry that switches
// off one advertising-only method (see Shared/MYBAdsRules.h). Everything else in the app, including the unlock or jailbreak-detection
// changes some of that project also makes, is deliberately left alone. A rule whose class or method is missing or has a different
// signature in the installed version stays off.
#import <Foundation/Foundation.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#import "../../../Shared/MYBAdsRules.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif
static const MYBAdsRule kWeChatRules[]={
 {"WAAppTaskSplashADConfig","canShowSplashADWindow","B@:",NO,YES,"slot"},
 {"WAAppTaskSplashADConfig","launchShow","B@:",NO,YES,"slot"},
 {"WAAppTask","splashAD_createSplashADWindow","v@:",NO,YES,"slot"},
 {"WAAppTask","mainThread_splashAD_handleSplashADContainerIsPreload:","v@:B",NO,YES,"slot"},
 {"WCAdvertiseStorage","setOAdvertiseData:","v@:@",NO,YES,"feed"},
 {"WCAdvertiseLogicMgr","updateAdvertiseDataList::","v@:@i",NO,YES,"feed"},
 {"WCAdvertiseLogicMgr","pdateAdvertiseDataItemDetail::","v@:@i",NO,YES,"feed"},
 {"WCAdvertiseLogicMgr","updateDataItemDetail:::","v@:@i@",NO,YES,"feed"},
 {"WCAdvertiseLogicMgr","requestForSnsADObjectOpRequest:","B@:@",NO,YES,"request"},
 {"WCAdvertiseLogicMgr","tryToPreloadWeAppForAdResource:","v@:@",NO,YES,"request"},
 {"WCAdvertiseLogicMgr","tryToPreloadWeAppForAdCanvas:","v@:@",NO,YES,"request"}};
NSUInteger MYBWeChatInstallHooks(NSUInteger *attempted){return MYBAdsInstallRules(@"wechat",kWeChatRules,sizeof(kWeChatRules)/sizeof(kWeChatRules[0]),attempted);}
#ifndef MYB_INAPPADS_TESTING
void MYBAdsRun_wechat(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"wechat"))return;
  MYBAdsReportLoaded(@"wechat",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBWeChatInstallHooks(&attempted);MYBAdsLogResult("wechat",ok,attempted);MYBAdsReportHooks(@"wechat",ok,attempted,0);
 }
}
#endif
