// MYbloXX In-App Ad Blocking: Sogou Input. Ads only.
// PROVENANCE: written against interface evidence (class and selector names published by sougouinputNoAds (iOS宝藏, MIT)); no source text is used, but the choice of
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
static const MYBAdsRule kSogouRules[]={
 {"TGGDTSplashViewController","isShowSplash","B@:",NO,YES,"slot"},
 {"SGSAmsAdCell","initAmsAdViewWithModel:","v@:@",NO,YES,"slot"},
 {"SGSGDTNativeAdMixedBannerView","setupWithUnifiedNativeAdObject:","v@:@",NO,YES,"slot"},
 {"SGSGDTNativeAdMixedCommonView","setupWithUnifiedNativeAdObject:","v@:@",NO,YES,"slot"}};
NSUInteger MYBSogouInstallHooks(NSUInteger *attempted){return MYBAdsInstallRules(@"sogou",kSogouRules,sizeof(kSogouRules)/sizeof(kSogouRules[0]),attempted);}
#ifndef MYB_INAPPADS_TESTING
void MYBAdsRun_sogou(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"sogou"))return;
  MYBAdsReportLoaded(@"sogou",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBSogouInstallHooks(&attempted);MYBAdsLogResult("sogou",ok,attempted);MYBAdsReportHooks(@"sogou",ok,attempted,0);
 }
}
#endif
