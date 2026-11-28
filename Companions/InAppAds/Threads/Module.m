// MYbloXX In-App Ad Blocking: Threads. Ads only.
// PROVENANCE: written against interface evidence (class and selector names published by ThreadsPulse's Tweak.x, a class-dump based tweak;
// its repository carries no licence file, so no source text is used). Each rule below is an independent table entry that refuses one
// advertising-only call: the ad request, the sponsored items that come back, and their insertion into the feed. Posts, replies,
// follows, search and everything else are left alone. A rule whose class or method is missing or reshaped stays off.
#import <Foundation/Foundation.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#import "../../../Shared/MYBAdsRules.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif
static const MYBAdsRule kThreadsRules[]={
 {"_TtC15IGBCNAdsManager15IGBCNAdsManager","startNewAdDeliveryWithSurfaceDelegate:sessionId:analyticsModule:","v@:@@@",NO,YES,"request"},
 {"_TtC15IGBCNAdsManager15IGBCNAdsManager","processSponsoredItems:projectedItems:analyticsModule:","v@:@@@",NO,YES,"feed"},
 {"_TtC15IGBCNAdsManager37BCNMainFeedAdsInsertionSurfaceHandler","adInsertionHandler:shouldTryToInsertSponsoredItem:atInsertionIndex:focusedIndex:insertionContext:","v@:@@qq@",NO,YES,"feed"},
 {"_TtC15IGBCNAdsManager37BCNMainFeedAdsInsertionSurfaceHandler","receivedSponsoredItems:intentAwareData:","v@:@@",NO,YES,"feed"},
 {"_TtC15IGBCNAdsManager37BCNMainFeedAdsInsertionSurfaceHandler","adPlatformDidDeliverSponsoredItem:atAdRequestIndex:","v@:@q",NO,YES,"feed"},
 {"IGAdFetcherManager","adFetcher:didReturnAdsResponse:paginationInfo:requestMetadata:isFromCache:adRequestExtraInfo:","v@:@@@@B@",NO,YES,"request"}};
NSUInteger MYBThreadsInstallHooks(NSUInteger *attempted){return MYBAdsInstallRules(@"threads",kThreadsRules,sizeof(kThreadsRules)/sizeof(kThreadsRules[0]),attempted);}
#ifndef MYB_INAPPADS_TESTING
void MYBAdsRun_threads(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"threads"))return;
  MYBAdsReportLoaded(@"threads",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBThreadsInstallHooks(&attempted);MYBAdsLogResult("threads",ok,attempted);MYBAdsReportHooks(@"threads",ok,attempted,0);
 }
}
#endif
