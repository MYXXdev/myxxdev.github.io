// MYbloXX In-App Ad Blocking: Instagram. Ads only.
// PROVENANCE: ADAPTED from SoCuul/SCInsta (GPL-3.0, tested by its author on Instagram 418.2.0). The hooked classes and selectors,
// the sponsored/ad item test and the "do not create the ad pipeline" approach follow SCInsta's ad-removal code
// (src/Features/Feed/HideFeedItems.xm). This module is therefore a derivative work and is distributed under the GNU GPL v3 with its
// source (see NOTICE.md and COPYING in usr/share/doc/mybloxx-inappads); because it is compiled into MYBInAppAds.dylib, the whole
// dylib is GPL-3.0. What differs: it keeps only the ad handling (no shopping carousel, "New!" tray, suggestion or download changes),
// reads one MYbloXX switch, skips any hook whose class or selector is missing, and reports counts to MYbloXX's local service.
// Keeps only ad handling: sponsored items are dropped and the ad pipeline is not created. Shopping, suggestions and downloads
// are untouched. It skips any hook whose class or selector is missing and reports counts to MYbloXX's local service.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

static IMP origMain,origSundial,origContextual,origVideo,origChaining,origExplore,origExploreSwift;
static IMP origStoryPoolInit,origStoryMgrInit,origStoryFetchInit,origStoryParse,origSundialParse;

static BOOL MYBIGBool(id object,const char *selector){
 SEL sel=sel_registerName(selector);return [object respondsToSelector:sel]&&((BOOL(*)(id,SEL))objc_msgSend)(object,sel);
}
// An item is an ad only when the app itself says so: a feed item flagged sponsored, or an ad model object.
BOOL MYBInstagramItemIsAd(id item){
 if(!item)return NO;
 Class feedItem=objc_getClass("IGFeedItem"),adItem=objc_getClass("IGAdItem"),grid=objc_getClass("IGDiscoveryGridItem");
 if(adItem&&[item isKindOfClass:adItem])return YES;
 if(feedItem&&[item isKindOfClass:feedItem]&&(MYBIGBool(item,"isSponsored")||MYBIGBool(item,"isSponsoredApp")))return YES;
 if(grid&&[item isKindOfClass:grid]){
  id model=[item respondsToSelector:sel_registerName("model")]?((id(*)(id,SEL))objc_msgSend)(item,sel_registerName("model")):nil;
  if(adItem&&model&&[model isKindOfClass:adItem])return YES;
 }
 return NO;
}
static NSArray *filterList(IMP original,id self_,SEL _cmd,id adapter){
 NSArray *list=original?((NSArray *(*)(id,SEL,id))original)(self_,_cmd,adapter):nil;
 NSArray *kept=MYBAdsFilter(list,^BOOL(id item){return MYBInstagramItemIsAd(item);});
 if(kept!=list)MYBAdsNoteDecisions(@"instagram",@"feed",list.count-kept.count);
 return kept;
}
#define LIST_HOOK(NAME,ORIG) static NSArray *NAME(id self_,SEL _cmd,id adapter){return filterList(ORIG,self_,_cmd,adapter);}
LIST_HOOK(hookMain,origMain)LIST_HOOK(hookSundial,origSundial)LIST_HOOK(hookContextual,origContextual)
LIST_HOOK(hookVideo,origVideo)LIST_HOOK(hookChaining,origChaining)LIST_HOOK(hookExplore,origExplore)LIST_HOOK(hookExploreSwift,origExploreSwift)
// Ad pipelines: not created at all, so no ad is fetched and no slot is reserved. The originals are not called, so
// nothing is half-initialised. The never-initialised instance is deliberately not released: running dealloc on an
// object whose initialiser never ran is the riskier choice, and one small object per launch is the whole cost.
static id hookNilInit2(id self_,SEL _cmd,id a,id b){MYBAdsNoteDecisions(@"instagram",@"story",1);return nil;}
static id hookNilInit1(id self_,SEL _cmd,id a){MYBAdsNoteDecisions(@"instagram",@"story",1);return nil;}
static id hookNilParse(id self_,SEL _cmd,id response){MYBAdsNoteDecisions(@"instagram",@"reel",1);return nil;}

NSUInteger MYBInstagramInstallHooks(NSUInteger *attempted){
 struct H{const char *cls,*sel;IMP imp;IMP *orig;} table[]={
  {"IGMainFeedListAdapterDataSource","objectsForListAdapter:",(IMP)hookMain,&origMain},
  {"IGSundialFeedDataSource","objectsForListAdapter:",(IMP)hookSundial,&origSundial},
  {"IGContextualFeedViewController","objectsForListAdapter:",(IMP)hookContextual,&origContextual},
  {"IGVideoFeedViewController","objectsForListAdapter:",(IMP)hookVideo,&origVideo},
  {"IGChainingFeedViewController","objectsForListAdapter:",(IMP)hookChaining,&origChaining},
  {"IGExploreListKitDataSource","objectsForListAdapter:",(IMP)hookExplore,&origExplore},
  {"_TtC28IGExploreViewControllerSwift26IGExploreListKitDataSource","objectsForListAdapter:",(IMP)hookExploreSwift,&origExploreSwift},
  {"IGStoryAdPool","initWithUserSession:",(IMP)hookNilInit1,&origStoryPoolInit},
  {"IGStoryAdsManager","initWithUserSession:storyViewerLoggingContext:storyFullscreenSectionLoggingContext:viewController:",(IMP)hookNilInit2,&origStoryMgrInit},
  {"IGStoryAdsFetcher","initWithUserSession:delegate:",(IMP)hookNilInit2,&origStoryFetchInit},
  {"IGStoryAdsResponseParser","parsedObjectFromResponse:",(IMP)hookNilParse,&origStoryParse},
  {"IGSundialAdsResponseParser","parsedObjectFromResponse:",(IMP)hookNilParse,&origSundialParse}};
 NSUInteger count=sizeof(table)/sizeof(table[0]),ok=0;
 for(NSUInteger i=0;i<count;i++)if(MYBAdsHookNamed(table[i].cls,table[i].sel,NO,table[i].imp,table[i].orig))ok++;
 if(attempted)*attempted=count;return ok;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_instagram(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"instagram"))return;
  MYBAdsReportLoaded(@"instagram",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBInstagramInstallHooks(&attempted);MYBAdsLogResult("instagram",ok,attempted);MYBAdsReportHooks(@"instagram",ok,attempted,0);
 }
}
#endif
