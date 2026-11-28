// MYbloXX In-App Ad Blocking: YouTube Music. Ads only.
// PROVENANCE: written against interface evidence (class-dump headers of YouTube Music; YouTube-X's published selectors for the same
// InnerTube client). Not copied, but it makes the same decisions on the same selectors as the YouTube module, which is adapted from
// MIT projects; see NOTICE.md in usr/share/doc/mybloxx-inappads.
// YouTube Music is built on the same InnerTube client as YouTube. This module stops the app asking for ads (the ad-request context
// decorator) and answers "no ads" to the player response's ad list and ad lead-in.
// It does NOT touch playability, playback state, Premium or entitlement state, background playback, skip limits or downloads.
// Which of these classes exist in a given YouTube Music version is checked at run time; a class or method that is missing leaves
// that one hook off and the app untouched.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

static IMP origAdsArray,origIntro,origMonetized;
static void noDecorate(id self_,SEL _cmd,id context){MYBAdsNoteDecisions(@"youtubemusic",@"request",1);}
static NSMutableArray *hookPlayerAds(id self_,SEL _cmd){
 id list=origAdsArray?((id(*)(id,SEL))origAdsArray)(self_,_cmd):nil;
 if([list isKindOfClass:NSArray.class]&&[(NSArray *)list count])MYBAdsNoteDecisions(@"youtubemusic",@"player",[(NSArray *)list count]);
 return [NSMutableArray array];
}
// The "ad intro" renderer is the short ad lead-in shown before a track; the answer is "none" only when the app had one.
static id hookAdIntro(id self_,SEL _cmd){id intro=origIntro?((id(*)(id,SEL))origIntro)(self_,_cmd):nil;if(intro)MYBAdsNoteDecisions(@"youtubemusic",@"player",1);return nil;}
// A response the app marks as monetised (carrying ads) is reported as not monetised; counted only when the app said yes. YouTube Music Ultimate
// (RemoveAds.x) answers the same way; the selector is declared in both published YouTube Music class dumps.
static BOOL hookMonetized(id self_,SEL _cmd){BOOL was=origMonetized?((BOOL(*)(id,SEL))origMonetized)(self_,_cmd):NO;if(was)MYBAdsNoteDecisions(@"youtubemusic",@"player",1);return NO;}
// Only the four hook points that appear in a published YouTube Music class dump (version 3.59, Class-Dumped-Apps and ios-app-headers) are used.
// See Companions/InAppAds/evidence.json. Hooks that exist only in the YouTube app (ad slots, the Impl decorator) are NOT assumed for YouTube Music.
NSUInteger MYBYouTubeMusicInstallHooks(NSUInteger *attempted){
 static IMP ignored;
 struct H{const char *cls,*sel;BOOL classMethod;IMP imp;IMP *orig;} table[]={
  {"YTIPlayerResponse","playerAdsArray",NO,(IMP)hookPlayerAds,&origAdsArray},
  {"YTIPlayerResponse","adIntroRenderer",NO,(IMP)hookAdIntro,&origIntro},
  {"YTIPlayerResponse","isMonetized",NO,(IMP)hookMonetized,&origMonetized},
  {"YTAdsInnerTubeContextDecorator","decorateContext:",NO,(IMP)noDecorate,&ignored}};
 NSUInteger count=sizeof(table)/sizeof(table[0]),ok=0;
 for(NSUInteger i=0;i<count;i++)if(MYBAdsHookNamed(table[i].cls,table[i].sel,table[i].classMethod,table[i].imp,table[i].orig))ok++;
 if(attempted)*attempted=count;return ok;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_youtubemusic(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"youtubemusic"))return;
  MYBAdsReportLoaded(@"youtubemusic",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBYouTubeMusicInstallHooks(&attempted);MYBAdsLogResult("youtubemusic",ok,attempted);MYBAdsReportHooks(@"youtubemusic",ok,attempted,0);
 }
}
#endif
