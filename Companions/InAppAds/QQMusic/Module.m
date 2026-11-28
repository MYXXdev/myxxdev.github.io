// MYbloXX In-App Ad Blocking: QQ Music. Ads only.
// PROVENANCE: written against interface evidence (class and selector names published by QQMusicNoAds (iOS宝藏, MIT)); no source text is used, but the choice of
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
static const MYBAdsRule kQQMusicRules[]={
 {"FlashWindow","setSplashItem:","v@:@",NO,YES,"slot"}};
NSUInteger MYBQQMusicInstallHooks(NSUInteger *attempted){return MYBAdsInstallRules(@"qqmusic",kQQMusicRules,sizeof(kQQMusicRules)/sizeof(kQQMusicRules[0]),attempted);}
#ifndef MYB_INAPPADS_TESTING
void MYBAdsRun_qqmusic(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"qqmusic"))return;
  MYBAdsReportLoaded(@"qqmusic",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBQQMusicInstallHooks(&attempted);MYBAdsLogResult("qqmusic",ok,attempted);MYBAdsReportHooks(@"qqmusic",ok,attempted,0);
 }
}
#endif
