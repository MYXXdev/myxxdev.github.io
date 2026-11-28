// MYbloXX In-App Ad Blocking: YouTube. Ads only.
// PROVENANCE: ADAPTED from two MIT projects. PoomSmart/YouTube-X (copyright (c) 2022-2026 PoomSmart): the reel/Shorts ad test
// (videoType 3, the ads custom-data marker), the ad-slot refusal, the player-response ad arrays, the playback-coordinator hook and the
// feed-section filter with its ad-logging-data test and renderer markers follow its Tweak.x. itzzace/ytkace (copyright (c) 2026 YTKACE
// contributors): the ad-request context decorator hooks follow its Ads feature. Both MIT notices travel with the package
// (usr/share/doc/mybloxx-inappads). What differs: a deliberately smaller marker list (shopping shelves are content, not ads), no
// background playback, upgrade-dialog or spam-signal changes, and counts reported to MYbloXX's service.
// WHAT THIS MODULE DOES, ON ITS OWN: it stops YouTube asking for ads (the ad-request context decorator), and removes what
// would reach the screen: feed/section ad renderers, ad Shorts, ad slots, player ad lists and the ads playback
// coordinator. It never touches playability or background playback, and it does not depend on any other tweak.
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

static IMP origAdsArray,origSlotsArray,origReelDS,origReelCM,origReelInfinite,origSetReels,origSlotType,origCoord,origAddSections,origSectionInit,origSectionInitT,origSectionInsert,origSectionReplace;

static id send0(id object,const char *selector){SEL sel=sel_registerName(selector);return [object respondsToSelector:sel]?((id(*)(id,SEL))objc_msgSend)(object,sel):nil;}

// Renderer markers that identify an advertisement. Kept short on purpose: shopping and merchandise shelves are
// content, not ads, and stay.
static NSArray<NSString *> *MYBYTAdMarkers(void){
 return @[@"feed_ad_metadata",@"brand_promo",@"text_search_ad",@"grid_ads_image_layout",@"in_feed_ad"];
}
// A renderer is an ad if YouTube attached ad-logging data to it, or its description carries an ad marker.
BOOL MYBYouTubeRendererIsAd(id renderer){
 if(!renderer)return NO;
 id options=send0(renderer,"compatibilityOptions");
 if(options&&[options respondsToSelector:sel_registerName("hasAdLoggingData")]&&((BOOL(*)(id,SEL))objc_msgSend)(options,sel_registerName("hasAdLoggingData")))return YES;
 NSString *text=[renderer description];
 for(NSString *marker in MYBYTAdMarkers())if([text containsString:marker])return YES;
 return NO;
}
// Section renderer (YTIItemSectionRenderer): ad when its first element renderer is an ad.
static BOOL MYBYTSectionIsAd(id section){
 NSArray *contents=send0(section,"contentsArray");
 if(![contents isKindOfClass:NSArray.class]||!contents.count)return NO;
 return MYBYouTubeRendererIsAd(send0(contents.firstObject,"elementRenderer"));
}
// Reel entries: videoType 3 is an ad; non-video entries carry the ads custom-data marker.
static BOOL MYBYTReelIsAd(id model){
 if(!model)return NO;
 SEL videoType=sel_registerName("videoType");
 if([model respondsToSelector:videoType])return ((int(*)(id,SEL))objc_msgSend)(model,videoType)==3;
 id renderer=send0(model,"renderer");
 return [[send0(renderer,"customData") description] containsString:@"reelNonVideoAdsCustomData"];
}

// The player-response getters are protobuf accessors: when the app's own getter exists, its answer tells whether ads
// were present, and only then is a decision counted.
static void noDecorate1(id self_,SEL _cmd,id context){}
static void noDecorate2(id self_,SEL _cmd,id context,long long type){}
static NSMutableArray *adsArrayHook(IMP original,id self_,SEL _cmd){
 id list=original?((id(*)(id,SEL))original)(self_,_cmd):nil;
 if([list isKindOfClass:NSArray.class]&&[(NSArray *)list count])MYBAdsNoteDecisions(@"youtube",@"player",[(NSArray *)list count]);
 return [NSMutableArray array];
}
static NSMutableArray *hookPlayerAds(id self_,SEL _cmd){return adsArrayHook(origAdsArray,self_,_cmd);}
static NSMutableArray *hookSlotAds(id self_,SEL _cmd){return adsArrayHook(origSlotsArray,self_,_cmd);}
static BOOL noSlot(id self_,SEL _cmd,int type){
 BOOL wanted=origSlotType?((BOOL(*)(id,SEL,int))origSlotType)(self_,_cmd,type):NO;
 if(wanted)MYBAdsNoteDecisions(@"youtube",@"slot",1);
 return NO;
}
static id noCoordinator(id self_,SEL _cmd){MYBAdsNoteDecisions(@"youtube",@"player",1);return nil;}
static id reelEntry(IMP original,id self_,SEL _cmd,id entry){id model=((id(*)(id,SEL,id))original)(self_,_cmd,entry);if(MYBYTReelIsAd(model)){MYBAdsNoteDecisions(@"youtube",@"short",1);return nil;}return model;}
static id hookReelDS(id self_,SEL _cmd,id entry){return reelEntry(origReelDS,self_,_cmd,entry);}
static id hookReelCM(id self_,SEL _cmd,id entry){return reelEntry(origReelCM,self_,_cmd,entry);}
static id hookReelInf(id self_,SEL _cmd,id entry){return reelEntry(origReelInfinite,self_,_cmd,entry);}
static void hookSetReels(id self_,SEL _cmd,NSMutableOrderedSet *reels){
 if([reels isKindOfClass:NSMutableOrderedSet.class]){NSIndexSet *ads=[reels indexesOfObjectsPassingTest:^BOOL(id obj,NSUInteger i,BOOL *stop){return MYBYTReelIsAd(obj);}];if(ads.count){[reels removeObjectsAtIndexes:ads];MYBAdsNoteDecisions(@"youtube",@"short",ads.count);}}
 ((void(*)(id,SEL,id))origSetReels)(self_,_cmd,reels);
}
// Ads that arrive after a section was first built are inserted, replaced or seeded through the section view model (the lead tweak
// filters the same four entry points). An entry is an ad when its element renderer is one; anything else passes untouched.
static BOOL MYBYTEntryIsAd(id entry){
 if(!entry)return NO;
 if([entry respondsToSelector:sel_registerName("elementRenderer")])return MYBYouTubeRendererIsAd(send0(entry,"elementRenderer"));
 if([entry respondsToSelector:sel_registerName("compatibilityOptions")])return MYBYouTubeRendererIsAd(entry);
 return NO;
}
static NSArray *MYBYTEntriesWithoutAds(NSArray *entries){
 NSArray *kept=MYBAdsFilter(entries,^BOOL(id entry){return MYBYTEntryIsAd(entry);});
 if(kept!=entries)MYBAdsNoteDecisions(@"youtube",@"feed",entries.count-kept.count);
 return kept;
}
typedef __attribute__((ns_returns_retained)) id (*MYBYTInitEntriesIMP)(id,SEL,id);
typedef __attribute__((ns_returns_retained)) id (*MYBYTInitTransformIMP)(id,SEL,id,id);
__attribute__((ns_returns_retained)) static id hookSectionInitEntries(id self_,SEL _cmd,NSArray *entries){return ((MYBYTInitEntriesIMP)origSectionInit)(self_,_cmd,MYBYTEntriesWithoutAds(entries));}
__attribute__((ns_returns_retained)) static id hookSectionInitTransform(id self_,SEL _cmd,id transform,NSArray *entries){return ((MYBYTInitTransformIMP)origSectionInitT)(self_,_cmd,transform,MYBYTEntriesWithoutAds(entries));}
static void hookSectionInsert(id self_,SEL _cmd,NSArray *entries,NSUInteger index){
 NSArray *kept=MYBYTEntriesWithoutAds(entries);
 if(kept!=entries&&!kept.count)return; // everything inserted was an ad: nothing to insert
 ((void(*)(id,SEL,id,NSUInteger))origSectionInsert)(self_,_cmd,kept,index);
}
static void hookSectionReplace(id self_,SEL _cmd,id oldEntry,id newEntry){
 if(MYBYTEntryIsAd(newEntry)){MYBAdsNoteDecisions(@"youtube",@"feed",1);return;}
 ((void(*)(id,SEL,id,id))origSectionReplace)(self_,_cmd,oldEntry,newEntry);
}
static void hookAddSections(id self_,SEL _cmd,NSArray *sections){
 NSArray *kept=MYBAdsFilter(sections,^BOOL(id section){return MYBYTSectionIsAd(section);});
 if(kept!=sections)MYBAdsNoteDecisions(@"youtube",@"feed",sections.count-kept.count);
 ((void(*)(id,SEL,id))origAddSections)(self_,_cmd,kept);
}

NSUInteger MYBYouTubeInstallHooks(NSUInteger *attempted){
 static IMP ignoredOrig[3];
 struct H{const char *cls,*sel;BOOL classMethod;IMP imp;IMP *orig;} table[]={
  {"YTIPlayerResponse","playerAdsArray",NO,(IMP)hookPlayerAds,&origAdsArray},
  {"YTIPlayerResponse","adSlotsArray",NO,(IMP)hookSlotAds,&origSlotsArray},
  {"YTLocalPlaybackController","createAdsPlaybackCoordinator",NO,(IMP)noCoordinator,&origCoord},
  {"YTAdElementsCellExternallyManagedSlotAdapterImpl","isValidSlotType:",NO,(IMP)noSlot,&origSlotType},
  {"YTReelDataSource","makeContentModelForEntry:",NO,(IMP)hookReelDS,&origReelDS},
  {"YTReelContentModel","makeContentModelForEntry:",YES,(IMP)hookReelCM,&origReelCM},
  {"YTReelInfinitePlaybackDataSource","makeContentModelForEntry:",NO,(IMP)hookReelInf,&origReelInfinite},
  {"YTReelInfinitePlaybackDataSource","setReels:",NO,(IMP)hookSetReels,&origSetReels},
  {"YTInnerTubeCollectionViewController","addSectionsFromArray:",NO,(IMP)hookAddSections,&origAddSections},
  {"YTArraySectionViewModel","initWithEntries:",NO,(IMP)hookSectionInitEntries,&origSectionInit},
  {"YTArraySectionViewModel","initWithTransform:entries:",NO,(IMP)hookSectionInitTransform,&origSectionInitT},
  {"YTArraySectionViewModel","insertEntries:atIndex:",NO,(IMP)hookSectionInsert,&origSectionInsert},
  {"YTArraySectionViewModel","replaceEntry:withEntry:",NO,(IMP)hookSectionReplace,&origSectionReplace},
  // The ad-request context: YouTube is told not to ask for ads at all. The original is never needed, so it is not kept.
  {"YTAdsInnerTubeContextDecorator","decorateContext:",NO,(IMP)noDecorate1,&ignoredOrig[0]},
  {"YTAdsInnerTubeContextDecorator","decorateContext:serviceType:",NO,(IMP)noDecorate2,&ignoredOrig[1]},
  {"YTAdsInnerTubeContextDecoratorImpl","decorateContext:",NO,(IMP)noDecorate1,&ignoredOrig[2]}};
 NSUInteger count=sizeof(table)/sizeof(table[0]),ok=0;
 for(NSUInteger i=0;i<count;i++){
  if(MYBAdsHookNamed(table[i].cls,table[i].sel,table[i].classMethod,table[i].imp,table[i].orig)){ok++;continue;}
  // The two ad-array getters of the player response are generated protobuf accessors that may not exist on the class
  // until first use; when absent, provide them so the answer is an empty list, as the lead tweak does.
  if(table[i].imp==(IMP)hookPlayerAds||table[i].imp==(IMP)hookSlotAds){
   Class cls=objc_getClass(table[i].cls);
   if(cls&&class_addMethod(cls,sel_registerName(table[i].sel),table[i].imp,"@@:"))ok++;
  }
 }
 if(attempted)*attempted=count;return ok;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_youtube(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"youtube"))return;
  MYBAdsReportLoaded(@"youtube",@MYB_COMPONENT_VERSION);
  NSUInteger attempted=0,ok=MYBYouTubeInstallHooks(&attempted);
  MYBAdsLogResult("youtube",ok,attempted);
  MYBAdsReportHooks(@"youtube",ok,attempted,0);
 }
}
#endif
