#pragma once
// Ad SDK load blocking for apps the person picked in Settings > In-App Ad Blocking > Ad Network Blocking (advanced).
//
// WHAT THIS IS. Infrastructure plus a short list of SDK entry points whose signature and failure behaviour are documented in the SDKs' own
// public headers. A blocked load is answered the way the SDK itself reports "no ad": the load's completion handler (or the delegate's
// did-fail method) is called ONCE with an error and no ad. A reward callback is never called, no ad object is ever fabricated and no
// server traffic is touched, so nothing can be earned from a blocked ad.
//
// WHAT THIS IS NOT. It does not cover every SDK. The two below are NOT covered, each for a specific reason recorded in kMYBAdSDKNotCovered
// (the single list the report, the audit document and the tests read). Nothing is hooked for them, so they behave exactly as without
// MYbloXX. An entry is added to the table above only after its class, selector, argument types and failure/cancel callback have been
// checked against the SDK's own published header AND the failure object can be built safely; a guess is never installed.
// The covered entries are implemented from the published headers and have not been confirmed on a device.
//
// LOADING AND GATING. This runs inside the one shared MYBInAppAds library. Its loader filter names the catalogue apps plus exactly the apps
// switched on here (written by the helper, Shared/MYBAdsFilter.h; never com.apple.UIKit), and it does
// nothing unless the app's own bundle id has its switch on (key "ads-sdk-<bundle id>", default off). A system app, SpringBoard or one of
// MYbloXX's own processes can never be selected. Hooks install only where the class exists and the method has exactly the expected
// signature, so a different SDK version leaves that entry point alone.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "MYBAdsSignature.h"

// Replacement blocks must have the SDK method's exact argument list even where an argument is not used.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
#define MYB_ADSDK_PREFIX @"ads-sdk-"

static inline BOOL MYBAdSDKSelected(NSDictionary *prefs,NSString *bundle){
 if(![bundle isKindOfClass:NSString.class]||!bundle.length)return NO;
 if([bundle hasPrefix:@"com.apple."]||[bundle hasPrefix:@"net.myxxdev."]||[bundle hasPrefix:@"__"])return NO;
 // On for every app unless the person switched that one off, so an app installed later is covered without any step.
 id v=[prefs isKindOfClass:NSDictionary.class]?prefs[[MYB_ADSDK_PREFIX stringByAppendingString:bundle]]:nil;
 return [v isKindOfClass:NSNumber.class]?[v boolValue]:YES;
}

// kind: 'C' a class-method loader taking (unit id, request, completion handler); 'B' a banner's loadRequest: with a delegate;
//       'D' an instance loadAd whose delegate is told through failSel.
typedef struct{const char *cls;const char *sel;const char *sig;char kind;BOOL classMethod;const char *failSel;const char *errorDomain;long errorCode;}MYBAdSDKEntry;
static const MYBAdSDKEntry kMYBAdSDKTable[]={
 // Google Mobile Ads: loaders answer through their completion handler (ad, error).
 {"GADInterstitialAd","loadWithAdUnitID:request:completionHandler:","v@:@@@",'C',YES,NULL,"com.google.admob",1},
 {"GADRewardedAd","loadWithAdUnitID:request:completionHandler:","v@:@@@",'C',YES,NULL,"com.google.admob",1},
 {"GADRewardedInterstitialAd","loadWithAdUnitID:request:completionHandler:","v@:@@@",'C',YES,NULL,"com.google.admob",1},
 {"GADAppOpenAd","loadWithAdUnitID:request:completionHandler:","v@:@@@",'C',YES,NULL,"com.google.admob",1},
 // Google Mobile Ads banners answer through the delegate.
 {"GADBannerView","loadRequest:","v@:@",'B',NO,"bannerView:didFailToReceiveAdWithError:","com.google.admob",1},
 // Meta Audience Network: each ad object tells its delegate through did-fail-with-error.
 {"FBInterstitialAd","loadAd","v@:",'D',NO,"interstitialAd:didFailWithError:","com.facebook.ads",1001},
 {"FBRewardedVideoAd","loadAd","v@:",'D',NO,"rewardedVideoAd:didFailWithError:","com.facebook.ads",1001},
 {"FBAdView","loadAd","v@:",'D',NO,"adView:didFailWithError:","com.facebook.ads",1001},
 // Vungle / Liftoff (VungleAdsSDK 7.x): VungleInterstitial and VungleRewarded take load: (optional bid response) and tell their delegate through
 // <format>AdDidFailToLoad:withError: with an NSError (Liftoff "Integrate Interstitial/Rewarded Ads" pages). The selector is matched exactly
 // before anything is replaced; the error domain and code are MYbloXX's own because the SDK documents NSError here, not a fixed value.
 {"VungleInterstitial","load:","v@:@",'B',NO,"interstitialAdDidFailToLoad:withError:","net.myxxdev.mybloxx.adsdk",1},
 {"VungleRewarded","load:","v@:@",'B',NO,"rewardedAdDidFailToLoad:withError:","net.myxxdev.mybloxx.adsdk",1},
 // Unity Ads 4.x (public headers, github.com/Unity-Technologies/unity-ads-ios tag 4.19.0, SourceCode/Public): the class methods
 // +load:loadDelegate: and +load:options:loadDelegate: tell the delegate unityAdsAdFailedToLoad:withError:withMessage: with the enum
 // UnityAdsLoadError (NSInteger; kUnityAdsLoadErrorNoFill = 3) and a message. errorCode is that enum value.
 {"UnityAds","load:loadDelegate:","v@:@@",'U',YES,"unityAdsAdFailedToLoad:withError:withMessage:","",3},
 {"UnityAds","load:options:loadDelegate:","v@:@@@",'V',YES,"unityAdsAdFailedToLoad:withError:withMessage:","",3},
 // Mintegral 8.1.9 (xcframeworks from the vendor's Swift package release; headers read): MTGNewInterstitialAdManager -loadAd tells its weak
 // delegate newInterstitialAdLoadFail:adManager: (NSError first); MTGRewardAdManager -loadVideoWithPlacementId:unitId:delegate: tells the
 // passed delegate onVideoAdLoadFailed:unitId:error:. Both take a plain NSError, so nothing is invented.
 {"MTGNewInterstitialAdManager","loadAd","v@:",'N',NO,"newInterstitialAdLoadFail:adManager:","net.myxxdev.mybloxx.adsdk",1},
 {"MTGRewardAdManager","loadVideoWithPlacementId:unitId:delegate:","v@:@@@",'R',NO,"onVideoAdLoadFailed:unitId:error:","net.myxxdev.mybloxx.adsdk",1},
 // LevelPlay 9.8.0 ad-unit API (IronSource.xcframework headers read): LPMInterstitialAd / LPMRewardedAd -loadAd; failure is the delegate's
 // didFailToLoadAdWithAdUnitId:error: (NSError). The ad object has no delegate getter and no ad-unit-id property (adId is a unique id), so the
 // delegate (weak, as the SDK holds it) and the unit id are recorded from -setDelegate: and -initWithAdUnitId: on the same class, and the
 // entry installs only when all three methods have exactly the documented signatures.
 {"LPMInterstitialAd","loadAd","v@:",'L',NO,"didFailToLoadAdWithAdUnitId:error:","net.myxxdev.mybloxx.adsdk",1},
 {"LPMRewardedAd","loadAd","v@:",'L',NO,"didFailToLoadAdWithAdUnitId:error:","net.myxxdev.mybloxx.adsdk",1}};
// SDKs that are deliberately NOT covered. status is always "not covered"; blocker is the specific thing that is missing.
typedef struct{const char *sdk;const char *status;const char *blocker;}MYBAdSDKGap;
static const MYBAdSDKGap kMYBAdSDKNotCovered[]={
 {"AppLovin MAX","not covered","Load failure is didFailToLoadAdForAdUnitIdentifier:withError: with an MAError (confirmed in the vendor's demo apps), and the AppLovinSDK.xcframework that declares MAError could not be fetched: artifacts.applovin.com (AppLovinSDK-13.7.0.xcframework.zip, from the vendor's Swift package) is refused by this environment's network policy, and the public github.com/AppLovin repository ships demo apps, not the framework. An NSError in place of an MAError can crash the app, so nothing is installed."},
 {"Google IMA","not covered","Failure is adsLoader:failedWithErrorData: with an IMAAdLoadingErrorData object (confirmed in googleads-ima-ios samples); the framework that declares it (GoogleInteractiveMediaAds-ios-v3.34.1.zip at imasdk.googleapis.com, named by the vendor's Swift package) is refused by this environment's network policy, and the content-video resume path is not verified. No object is invented."}};
#define MYB_ADSDK_GAP_COUNT (sizeof(kMYBAdSDKNotCovered)/sizeof(kMYBAdSDKNotCovered[0]))
#define MYB_ADSDK_TABLE_COUNT (sizeof(kMYBAdSDKTable)/sizeof(kMYBAdSDKTable[0]))

static volatile int32_t MYBAdSDKBlocked;
// Set by the library start-up: told after each answered load so the count can be reported (coalesced there, never on the caller).
static void (^MYBAdSDKBlockedHook)(void);
#define MYB_ADSDK_NOTE_BLOCKED() do{__sync_fetch_and_add(&MYBAdSDKBlocked,1);void (^h)(void)=MYBAdSDKBlockedHook;if(h)h();}while(0)
static inline int32_t MYBAdSDKBlockedCount(void){return MYBAdSDKBlocked;}
static inline NSMutableSet<NSString *> *MYBAdSDKInstalled(void){static NSMutableSet *set;static dispatch_once_t once;dispatch_once(&once,^{set=[NSMutableSet set];});return set;}
static inline NSError *MYBAdSDKError(const MYBAdSDKEntry *e){
 return [NSError errorWithDomain:[NSString stringWithUTF8String:e->errorDomain] code:e->errorCode userInfo:@{NSLocalizedDescriptionKey:@"No ad available"}];
}
// The failure is delivered once, on the main queue, after the load call has returned (as the SDKs themselves do), so a caller that stores
// its result after calling load is never re-entered.
static inline void MYBAdSDKDeliver(dispatch_block_t block){dispatch_async(dispatch_get_main_queue(),block);}

// Delegate-based failures (kinds B and D) follow what the SDKs themselves do:
//  - delivered once, on the main queue, after the load call has returned;
//  - to the delegate the object has WHEN IT IS DELIVERED (a delegate set or changed after load: is still the one told; none: nobody);
//  - only while the ad object is still alive (held weakly: an app that drops the ad object is not called back, as with a real load that is cancelled);
//  - a newer load on the same object supersedes an older one, so repeated loads give one failure for the latest, never a pile;
//  - no reward, impression or click selector is ever called, and no ad is ever reported as loaded.
static const char kMYBAdSDKLoadToken;
// obj's newest load supersedes older ones. delegateFor reads the delegate WHEN DELIVERED; call tells it. Nothing runs if obj is gone.
static inline void MYBAdSDKFailLaterCall(id obj,id (^delegateFor)(id),void (^call)(id,id)){
 NSNumber *token=nil;
 @synchronized(obj){NSUInteger n=[objc_getAssociatedObject(obj,&kMYBAdSDKLoadToken) unsignedIntegerValue]+1;token=@(n);objc_setAssociatedObject(obj,&kMYBAdSDKLoadToken,token,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
 __weak id weak=obj;
 dispatch_async(dispatch_get_main_queue(),^{
  id strong=weak;if(!strong)return; // the app let go of the ad: nothing to tell
  @synchronized(strong){
   if(![objc_getAssociatedObject(strong,&kMYBAdSDKLoadToken) isEqual:token])return; // superseded by a later load
   objc_setAssociatedObject(strong,&kMYBAdSDKLoadToken,@0,OBJC_ASSOCIATION_RETAIN_NONATOMIC); // delivered: this load cannot be delivered again
  }
  id delegate=delegateFor(strong);if(delegate)call(strong,delegate);
 });
}
static inline void MYBAdSDKFailLater(id obj,SEL delegateSel,SEL fail,NSError *error,BOOL errorFirst){
 MYBAdSDKFailLaterCall(obj,^id(id o){return [o respondsToSelector:delegateSel]?((id(*)(id,SEL))objc_msgSend)(o,delegateSel):nil;},^(id o,id d){
  if(![d respondsToSelector:fail])return;
  if(errorFirst)((void(*)(id,SEL,id,id))objc_msgSend)(d,fail,error,o);else((void(*)(id,SEL,id,id))objc_msgSend)(d,fail,o,error);
 });
}
// A delegate handed to the load call itself: told once per call, on the main queue, after the call has returned. keep: hold it until then
// (used where the SDK documents no ownership); otherwise it is held weakly, like the SDK's own delegates.
static inline void MYBAdSDKTellDelegate(id delegate,BOOL keep,void (^call)(id)){
 if(!delegate)return;id strongRef=keep?delegate:nil;__weak id weak=delegate;
 dispatch_async(dispatch_get_main_queue(),^{id d=strongRef?:weak;if(d)call(d);});
}
// LevelPlay: the ad object keeps neither its delegate nor its unit id readable, so they are recorded as the app sets them.
static const char kMYBLPMUnit,kMYBLPMDelegate;
static inline IMP MYBAdSDKReplacement(const MYBAdSDKEntry *e){
 NSError *error=MYBAdSDKError(e);SEL fail=e->failSel?sel_registerName(e->failSel):NULL;
 switch(e->kind){
  case 'C':return imp_implementationWithBlock(^(id self_,id unit,id request,id handler){
   MYB_ADSDK_NOTE_BLOCKED();
   if(handler){void (^complete)(id,NSError *)=handler;MYBAdSDKDeliver(^{complete(nil,error);});}
  });
  case 'B':case 'D':return imp_implementationWithBlock(^(id self_,id request){
   MYB_ADSDK_NOTE_BLOCKED();MYBAdSDKFailLater(self_,sel_registerName("delegate"),fail,error,NO);
  });
  case 'N':return imp_implementationWithBlock(^(id self_){
   MYB_ADSDK_NOTE_BLOCKED();MYBAdSDKFailLater(self_,sel_registerName("delegate"),fail,error,YES); // Mintegral: (error, adManager)
  });
  case 'U':return imp_implementationWithBlock(^(id self_,NSString *placement,id delegate){
   MYB_ADSDK_NOTE_BLOCKED();
   MYBAdSDKTellDelegate(delegate,YES,^(id d){if([d respondsToSelector:fail])((void(*)(id,SEL,id,NSInteger,id))objc_msgSend)(d,fail,placement,(NSInteger)e->errorCode,@"No ad available");});
  });
  case 'V':return imp_implementationWithBlock(^(id self_,NSString *placement,id options,id delegate){
   MYB_ADSDK_NOTE_BLOCKED();
   MYBAdSDKTellDelegate(delegate,YES,^(id d){if([d respondsToSelector:fail])((void(*)(id,SEL,id,NSInteger,id))objc_msgSend)(d,fail,placement,(NSInteger)e->errorCode,@"No ad available");});
  });
  case 'R':return imp_implementationWithBlock(^(id self_,NSString *placement,NSString *unit,id delegate){
   MYB_ADSDK_NOTE_BLOCKED();
   MYBAdSDKTellDelegate(delegate,NO,^(id d){if([d respondsToSelector:fail])((void(*)(id,SEL,id,id,id))objc_msgSend)(d,fail,placement,unit,error);});
  });
 }
 return NULL;
}
// LevelPlay ad objects (kind 'L'): record the unit id and the (weak) delegate as the app provides them, then answer -loadAd. Installed only when
// -loadAd, -setDelegate: and -initWithAdUnitId: all have exactly the documented signatures. If a load arrives for an object whose unit id was never
// recorded (it was created before this installed), the real load is left to run and is not counted: no failure is made up for an unknown unit.
static inline BOOL MYBAdSDKInstallLPM(Class cls,const MYBAdSDKEntry *e,Method loadMethod){
 SEL setSel=sel_registerName("setDelegate:"),initSel=sel_registerName("initWithAdUnitId:"),initCfg=sel_registerName("initWithAdUnitId:config:"),loadSel=sel_registerName(e->sel);
 Method setM=class_getInstanceMethod(cls,setSel),initM=class_getInstanceMethod(cls,initSel),cfgM=class_getInstanceMethod(cls,initCfg);
 if(!MYBAdsSignatureMatches(setM,"v@:@")||!MYBAdsSignatureMatches(initM,"@@:@"))return NO;
 BOOL withConfig=MYBAdsSignatureMatches(cfgM,"@@:@@");
 IMP origSet=method_getImplementation(setM),origInit=method_getImplementation(initM),origCfg=withConfig?method_getImplementation(cfgM):NULL,origLoad=method_getImplementation(loadMethod);
 NSError *error=MYBAdSDKError(e);SEL fail=sel_registerName(e->failSel);
 class_replaceMethod(cls,setSel,imp_implementationWithBlock(^(id self_,id delegate){
  __weak id w=delegate;id (^box)(void)=^id{return w;};objc_setAssociatedObject(self_,&kMYBLPMDelegate,box,OBJC_ASSOCIATION_COPY_NONATOMIC);
  ((void(*)(id,SEL,id))origSet)(self_,setSel,delegate);
 }),method_getTypeEncoding(setM));
 class_replaceMethod(cls,initSel,imp_implementationWithBlock(^id(id self_,NSString *unit){
  id r=((id(*)(id,SEL,id))origInit)(self_,initSel,unit);if(r&&[unit isKindOfClass:NSString.class])objc_setAssociatedObject(r,&kMYBLPMUnit,[unit copy],OBJC_ASSOCIATION_RETAIN_NONATOMIC);return r;
 }),method_getTypeEncoding(initM));
 if(withConfig)class_replaceMethod(cls,initCfg,imp_implementationWithBlock(^id(id self_,NSString *unit,id config){
  id r=((id(*)(id,SEL,id,id))origCfg)(self_,initCfg,unit,config);if(r&&[unit isKindOfClass:NSString.class])objc_setAssociatedObject(r,&kMYBLPMUnit,[unit copy],OBJC_ASSOCIATION_RETAIN_NONATOMIC);return r;
 }),method_getTypeEncoding(cfgM));
 class_replaceMethod(cls,loadSel,imp_implementationWithBlock(^(id self_){
  NSString *unit=objc_getAssociatedObject(self_,&kMYBLPMUnit);
  if(![unit isKindOfClass:NSString.class]||!unit.length){((void(*)(id,SEL))origLoad)(self_,loadSel);return;}
  MYB_ADSDK_NOTE_BLOCKED();
  MYBAdSDKFailLaterCall(self_,^id(id o){id (^box)(void)=objc_getAssociatedObject(o,&kMYBLPMDelegate);return box?box():nil;},^(id o,id d){
   if([d respondsToSelector:fail])((void(*)(id,SEL,id,id))objc_msgSend)(d,fail,unit,error);
  });
 }),method_getTypeEncoding(loadMethod));
 return YES;
}
static inline NSUInteger MYBAdSDKInstalledCount(void){@synchronized(MYBAdSDKInstalled()){return MYBAdSDKInstalled().count;}}
// Installs every entry whose class exists and whose method has exactly the stated signature. Returns how many were installed in this pass.
static inline NSUInteger MYBAdSDKInstall(NSUInteger *attempted){
 NSUInteger ok=0;
 for(NSUInteger i=0;i<MYB_ADSDK_TABLE_COUNT;i++){
  const MYBAdSDKEntry *e=&kMYBAdSDKTable[i];
  Class cls=objc_getClass(e->cls);if(!cls)continue;
  SEL sel=sel_registerName(e->sel);
  Method method=e->classMethod?class_getClassMethod(cls,sel):class_getInstanceMethod(cls,sel);
  if(!MYBAdsSignatureMatches(method,e->sig))continue;
  NSString *key=[NSString stringWithFormat:@"%p|%s|%d",(void *)cls,e->sel,e->classMethod];
  @synchronized(MYBAdSDKInstalled()){
   if([MYBAdSDKInstalled() containsObject:key])continue;
   if(e->kind=='L'){if(MYBAdSDKInstallLPM(cls,e,method)){[MYBAdSDKInstalled() addObject:key];ok++;}continue;}
   IMP replacement=MYBAdSDKReplacement(e);if(!replacement)continue;
   class_replaceMethod(e->classMethod?object_getClass(cls):cls,sel,replacement,method_getTypeEncoding(method));
   [MYBAdSDKInstalled() addObject:key];ok++;
  }
 }
 if(attempted)*attempted=MYB_ADSDK_TABLE_COUNT;
 return ok;
}
#pragma clang diagnostic pop
