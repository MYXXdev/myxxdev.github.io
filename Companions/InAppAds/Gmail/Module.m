// MYbloXX In-App Ad Blocking: Gmail. Ads only.
// PROVENANCE: written against interface evidence (the AdsCell and GBTAdsCellImpl class names and their row-height methods, published by
// gmail-no-ads by Hao Nguyen; no source text is used). The inbox's advertisement rows
// are given zero height, so they take no space; mail, labels, search and accounts are left alone. A rule whose class or method is
// missing or reshaped stays off.
#import <Foundation/Foundation.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#import "../../../Shared/MYBAdsRules.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif
static const MYBAdsRule kGmailRules[]={
 {"AdsCell","heightForObject:width:expansionState:","d@:@d@",YES,NO,"slot"},
 {"AdsCell","heightForObject:width:","d@:@d",YES,NO,"slot"},
 {"GBTAdsCellImpl","heightForObject:width:expansionState:","d@:@d@",YES,NO,"slot"},
 {"GBTAdsCellImpl","heightForObject:width:","d@:@d",YES,NO,"slot"}};
NSUInteger MYBGmailInstallHooks(NSUInteger *attempted){return MYBAdsInstallRules(@"gmail",kGmailRules,sizeof(kGmailRules)/sizeof(kGmailRules[0]),attempted);}
#ifndef MYB_INAPPADS_TESTING
void MYBAdsRun_gmail(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"gmail"))return;
  MYBAdsReportLoaded(@"gmail",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBGmailInstallHooks(&attempted);MYBAdsLogResult("gmail",ok,attempted);MYBAdsReportHooks(@"gmail",ok,attempted,0);
 }
}
#endif
