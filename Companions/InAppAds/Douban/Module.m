// MYbloXX In-App Ad Blocking: Douban. Ads only.
// PROVENANCE: written against interface evidence (class and selector names published by doubanNoads (iOS宝藏, MIT)); no source text is used, but the choice of
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
static const MYBAdsRule kDoubanRules[]={
 {"ReviewsListViewController","frd_fetchReviewAD","v@:",NO,YES,"request"},
 {"MTGSplashADManager","loadAndShow:","v@:@",NO,YES,"slot"},
 {"MTGSplashADManager","show:","v@:@",NO,YES,"slot"},
 {"GDTSplashAd","isAdValid","B@:",NO,YES,"slot"},
 {"DOUCommercialViewController","advertisement","@@:",NO,YES,"slot"}};
NSUInteger MYBDoubanInstallHooks(NSUInteger *attempted){return MYBAdsInstallRules(@"douban",kDoubanRules,sizeof(kDoubanRules)/sizeof(kDoubanRules[0]),attempted);}
#ifndef MYB_INAPPADS_TESTING
void MYBAdsRun_douban(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"douban"))return;
  MYBAdsReportLoaded(@"douban",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBDoubanInstallHooks(&attempted);MYBAdsLogResult("douban",ok,attempted);MYBAdsReportHooks(@"douban",ok,attempted,0);
 }
}
#endif
