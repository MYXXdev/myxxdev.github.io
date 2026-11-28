// MYbloXX In-App Ad Blocking: TikTok. Ads only.
// PROVENANCE: ADAPTED from Selandros/TikTokClean (MIT, copyright (c) 2026 selandros; tested by its author on TikTok 45.7.0 and
// 45.8.0): the ad test on AWEAwemeModel (isAds, isAdsOrPseudoAds, adInfo, adOrPseudoAdModel, adType) and the initialisers that
// discard an ad model follow its TCAwemeIsAd and AWEAwemeModel hooks. The MIT notice travels with the package
// (usr/share/doc/mybloxx-inappads). Not included: LIVE removal, downloads, auto-scroll, fullscreen or any other TikTokClean feature.
// Hooks the ad test on the video model and the initialisers that create an ad model, and discards it. LIVE, downloads,
// auto-scroll and everything else are untouched. No filesystem paths are used.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

static IMP origInit,origInitDict;

static BOOL sendBool(id o,const char *s){SEL sel=sel_registerName(s);return [o respondsToSelector:sel]&&((BOOL(*)(id,SEL))objc_msgSend)(o,sel);}
static id sendObject(id o,const char *s){SEL sel=sel_registerName(s);return [o respondsToSelector:sel]?((id(*)(id,SEL))objc_msgSend)(o,sel):nil;}
BOOL MYBTikTokAwemeIsAd(id aweme){
 if(!aweme)return NO;
 if(sendBool(aweme,"isAds")||sendBool(aweme,"isAdsOrPseudoAds"))return YES;
 if(sendBool(aweme,"checkIsAd")||sendBool(aweme,"isHardAdModel")||sendBool(aweme,"isHardAd"))return YES; // Douyin names the same decision differently (DYYY's classifier)
 if(sendObject(aweme,"adInfo")||sendObject(aweme,"adOrPseudoAdModel"))return YES;
 SEL adType=sel_registerName("adType");
 return [aweme respondsToSelector:adType]&&((long(*)(id,SEL))objc_msgSend)(aweme,adType)!=0;
}
// An ad model is never handed to the feed: the initialiser answers nil and the half-built object is released. An initialiser returns an
// owned (+1) object, so both the original call and these replacements are declared that way and ARC keeps the counts balanced: the
// object is released here when it is an ad, and ownership passes to the caller when it is not.
typedef __attribute__((ns_returns_retained)) id (*MYBTikTokInitIMP)(id,SEL);
typedef __attribute__((ns_returns_retained)) id (*MYBTikTokInitDictIMP)(id,SEL,id,NSError **);
__attribute__((ns_returns_retained)) static id hookInit(id self,SEL _cmd){
 id result=((MYBTikTokInitIMP)origInit)(self,_cmd);
 if(result&&MYBTikTokAwemeIsAd(result)){MYBAdsNoteDecisions(@"tiktok",@"video",1);return nil;}
 return result;
}
__attribute__((ns_returns_retained)) static id hookInitDict(id self,SEL _cmd,id dictionary,NSError **error){
 id result=((MYBTikTokInitDictIMP)origInitDict)(self,_cmd,dictionary,error);
 if(result&&MYBTikTokAwemeIsAd(result)){MYBAdsNoteDecisions(@"tiktok",@"video",1);return nil;}
 return result;
}
NSUInteger MYBTikTokInstallHooks(NSUInteger *attempted){
 NSUInteger ok=0;
 if(MYBAdsHookNamed("AWEAwemeModel","init",NO,(IMP)hookInit,&origInit))ok++;
 if(MYBAdsHookNamed("AWEAwemeModel","initWithDictionary:error:",NO,(IMP)hookInitDict,&origInitDict))ok++;
 if(attempted)*attempted=2;return ok;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_tiktok(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"tiktok"))return;
  MYBAdsReportLoaded(@"tiktok",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBTikTokInstallHooks(&attempted);MYBAdsLogResult("tiktok",ok,attempted);MYBAdsReportHooks(@"tiktok",ok,attempted,0);
 }
}
#endif
