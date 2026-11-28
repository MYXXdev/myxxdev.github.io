// Ad SDK load blocking, on real Objective-C classes that mimic the public SDK interfaces: failure delivered once with an error and no ad,
// no reward path, nothing touched in unselected apps, unrelated methods untouched, wrong signatures skipped, no stacking on a second pass.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../Shared/MYBAdSDK.h"
static int failures=0;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)
static Class make(const char *name){Class c=objc_allocateClassPair(NSObject.class,name,0);objc_registerClassPair(c);return c;}
static void add(Class c,const char *sel,id block,const char *types){class_addMethod(c,sel_registerName(sel),imp_implementationWithBlock(block),types);}
static void pump(void){[[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]];}
int main(void){@autoreleasepool{
 // selection: default off, exact bundle, never a system or MYbloXX process
 REQUIRE(!MYBAdSDKSelected(nil,@"com.game.x")&&!MYBAdSDKSelected(@{},@"com.game.x")&&!MYBAdSDKSelected(@{@"ads-sdk-com.game.x":@"yes"},@"com.game.x")&&!MYBAdSDKSelected(@{@"ads-sdk-com.game.x":@NO},@"com.game.x"),"off by default and for anything that is not an on number");
 REQUIRE(MYBAdSDKSelected(@{@"ads-sdk-com.game.x":@YES},@"com.game.x")&&!MYBAdSDKSelected(@{@"ads-sdk-com.game.x":@YES},@"com.game.y"),"selection is per exact bundle id");
 REQUIRE(!MYBAdSDKSelected(@{@"ads-sdk-com.apple.springboard":@YES},@"com.apple.springboard")&&!MYBAdSDKSelected(@{@"ads-sdk-net.myxxdev.mybloxx":@YES},@"net.myxxdev.mybloxx")&&!MYBAdSDKSelected(@{@"ads-sdk-":@YES},@""),"system and MYbloXX processes can never be selected");
 // the two SDKs that are not covered: each has a specific blocker, and nothing is hooked for any of them
 {const char *want[]={"AppLovin MAX","Google IMA"};
  REQUIRE(MYB_ADSDK_GAP_COUNT==2,"two SDKs are recorded as not covered");
  for(NSUInteger i=0;i<MYB_ADSDK_GAP_COUNT;i++){const MYBAdSDKGap *g=&kMYBAdSDKNotCovered[i];REQUIRE(!strcmp(g->sdk,want[i])&&!strcmp(g->status,"not covered")&&strlen(g->blocker)>60,"each gap has the exact name, status and a specific blocker");}
  for(NSUInteger i=0;i<MYB_ADSDK_TABLE_COUNT;i++){const char *c=kMYBAdSDKTable[i].cls;REQUIRE(strncmp(c,"MA",2)&&strncmp(c,"IMA",3),"no hook exists for an uncovered SDK");}}
 NSUInteger attempted=0;
 REQUIRE(MYBAdSDKInstall(&attempted)==0&&attempted==16,"with no SDK present nothing installs");
 // fake Google Mobile Ads
 __block int realLoads=0,rewards=0;
 Class inter=make("GADInterstitialAd"),rewarded=make("GADRewardedAd"),other=make("GADAppOpenAd");
 Class interMeta=object_getClass(inter),rewardedMeta=object_getClass(rewarded),otherMeta=object_getClass(other);
 add(interMeta,"loadWithAdUnitID:request:completionHandler:",^(id s,id u,id r,id h){realLoads++;((void(^)(id,NSError *))h)(@"AD",nil);},"v@:@@@?");
 add(rewardedMeta,"loadWithAdUnitID:request:completionHandler:",^(id s,id u,id r,id h){realLoads++;},"v@:@@@?");
 add(otherMeta,"loadWithAdUnitID:request:orientation:completionHandler:",^(id s,id u,id r,long long o,id h){realLoads++;},"v@:@@q@?"); // other shape, not in the table
 add(otherMeta,"loadWithAdUnitID:request:completionHandler:",^(id s,id u,long long r,id h){realLoads++;},"v@:@q@?"); // same name, wrong argument types: must be skipped
 Class banner=make("GADBannerView");
 add(banner,"loadRequest:",^(id s,id r){realLoads++;},"v@:@");add(banner,"delegate",^id(id s){return objc_getAssociatedObject(s,"d");},"@@:");
 Class fbi=make("FBInterstitialAd");add(fbi,"loadAd",^(id s){realLoads++;},"v@:");add(fbi,"delegate",^id(id s){return objc_getAssociatedObject(s,"d");},"@@:");
 Class fbr=make("FBRewardedVideoAd");add(fbr,"loadAd",^BOOL(id s){realLoads++;return YES;},"B@:"); // wrong return type: skipped
 NSUInteger ok=MYBAdSDKInstall(&attempted);
 REQUIRE(attempted==16&&ok==4,"installs the interstitial, rewarded, banner and Meta interstitial entry points; the wrong-argument and wrong-return ones are skipped");
 __block int handlerCalls=0;__block id gotAd=@"unset";__block NSError *gotError=nil;
 void (^handler)(id,NSError *)=^(id ad,NSError *error){handlerCalls++;gotAd=ad;gotError=error;};
 ((void(*)(id,SEL,id,id,id))objc_msgSend)(inter,sel_registerName("loadWithAdUnitID:request:completionHandler:"),@"unit",nil,handler);
 REQUIRE(handlerCalls==0&&realLoads==0,"the failure is delivered after the load call returns, and the real load never runs");
 pump();
 REQUIRE(handlerCalls==1&&gotAd==nil&&gotError!=nil&&[gotError.domain isEqual:@"com.google.admob"],"the interstitial completion handler is called exactly once with no ad and an error");
 pump();REQUIRE(handlerCalls==1,"and never again");
 handlerCalls=0;
 ((void(*)(id,SEL,id,id,id))objc_msgSend)(rewarded,sel_registerName("loadWithAdUnitID:request:completionHandler:"),@"unit",nil,handler);pump();
 REQUIRE(handlerCalls==1&&gotAd==nil&&gotError!=nil&&realLoads==0&&rewards==0,"a rewarded load fails the same way and no reward callback exists to call");
 ((void(*)(id,SEL,id,id,id))objc_msgSend)(inter,sel_registerName("loadWithAdUnitID:request:completionHandler:"),@"unit",nil,nil);pump();
 REQUIRE(realLoads==0,"a load with no handler does not crash and still does not load");
 // the other shapes keep their original behaviour
 ((void(*)(id,SEL,id,id,long long,id))objc_msgSend)(other,sel_registerName("loadWithAdUnitID:request:orientation:completionHandler:"),@"u",nil,0,nil);
 ((void(*)(id,SEL,id,long long,id))objc_msgSend)(other,sel_registerName("loadWithAdUnitID:request:completionHandler:"),@"u",1,nil);
 REQUIRE(realLoads==2,"a method with a different shape is left running as the app wrote it");
 // banner: delegate told once; no delegate or a delegate without the method is a quiet no-op
 Class del=make("MYBTestBannerDelegate");__block int bannerFails=0;__block NSError *bannerError=nil;
 add(del,"bannerView:didFailToReceiveAdWithError:",^(id s,id v,NSError *e){bannerFails++;bannerError=e;},"v@:@@");
 __attribute__((objc_precise_lifetime)) id bv=[banner new],d=[del new];objc_setAssociatedObject(bv,"d",d,OBJC_ASSOCIATION_RETAIN);
 ((void(*)(id,SEL,id))objc_msgSend)(bv,sel_registerName("loadRequest:"),nil);pump();
 REQUIRE(bannerFails==1&&bannerError!=nil&&realLoads==2,"the banner delegate is told once that no ad was received, and the real load does not run");
 id bare=[banner new];((void(*)(id,SEL,id))objc_msgSend)(bare,sel_registerName("loadRequest:"),nil);
 id mute=[banner new];objc_setAssociatedObject(mute,"d",[NSObject new],OBJC_ASSOCIATION_RETAIN);((void(*)(id,SEL,id))objc_msgSend)(mute,sel_registerName("loadRequest:"),nil);pump();
 REQUIRE(bannerFails==1,"a banner with no delegate, or a delegate without the method, is a quiet no-op");
 // Meta interstitial
 Class fdel=make("MYBTestFBDelegate");__block int fbFails=0;add(fdel,"interstitialAd:didFailWithError:",^(id s,id a,NSError *e){fbFails++;REQUIRE([e.domain isEqual:@"com.facebook.ads"],"Meta error domain");},"v@:@@");
 __attribute__((objc_precise_lifetime)) id fi=[fbi new];objc_setAssociatedObject(fi,"d",[fdel new],OBJC_ASSOCIATION_RETAIN);((void(*)(id,SEL))objc_msgSend)(fi,sel_registerName("loadAd"));pump();
 REQUIRE(fbFails==1,"the Meta interstitial delegate is told once through did-fail-with-error");
 REQUIRE(((BOOL(*)(id,SEL))objc_msgSend)([fbr new],sel_registerName("loadAd"))==YES&&realLoads==3,"the Meta rewarded method with another return type is untouched");
 REQUIRE(MYBAdSDKBlockedCount()==7,"every blocked load is counted once, at the call");
 // a second pass installs nothing and does not stack
 REQUIRE(MYBAdSDKInstall(&attempted)==0,"a second install pass adds nothing");
 handlerCalls=0;((void(*)(id,SEL,id,id,id))objc_msgSend)(inter,sel_registerName("loadWithAdUnitID:request:completionHandler:"),@"unit",nil,handler);pump();
 REQUIRE(handlerCalls==1,"still exactly one failure after a second pass");

 // ---- Vungle / Liftoff: callback correctness, not only the signature ----
 {
  __block int vLoads=0,failsI=0,failsR=0,rewardsV=0,loadedV=0,impressions=0,mainThreadCalls=0;__block id gotAdI=nil;__block NSError *gotErrV=nil;
  Class vi=make("VungleInterstitial"),vr=make("VungleRewarded");
  add(vi,"load:",^(id s,id bid){vLoads++;},"v@:@");add(vi,"delegate",^id(id s){return objc_getAssociatedObject(s,"d");},"@@:");
  add(vr,"load:",^(id s,id bid){vLoads++;},"v@:@");add(vr,"delegate",^id(id s){return objc_getAssociatedObject(s,"d");},"@@:");
  Class vdel=make("MYBTestVungleDelegate"),vdel2=make("MYBTestVungleDelegate2"),vdelMute=make("MYBTestVungleDelegateMute");
  add(vdel,"interstitialAdDidFailToLoad:withError:",^(id s,id ad,NSError *e){failsI++;gotAdI=ad;gotErrV=e;if(NSThread.isMainThread)mainThreadCalls++;},"v@:@@");
  add(vdel,"rewardedAdDidFailToLoad:withError:",^(id s,id ad,NSError *e){failsR++;gotErrV=e;if(NSThread.isMainThread)mainThreadCalls++;},"v@:@@");
  for(NSString *n in @[@"interstitialAdDidLoad:",@"rewardedAdDidLoad:"])add(vdel,n.UTF8String,^(id s,id ad){loadedV++;},"v@:@");
  add(vdel,"rewardedAdDidRewardUser:",^(id s,id ad){rewardsV++;},"v@:@");
  for(NSString *n in @[@"interstitialAdDidTrackImpression:",@"rewardedAdDidTrackImpression:"])add(vdel,n.UTF8String,^(id s,id ad){impressions++;},"v@:@");
  __block int secondDelegateFails=0;add(vdel2,"interstitialAdDidFailToLoad:withError:",^(id s,id ad,NSError *e){secondDelegateFails++;},"v@:@@");
  NSUInteger ok2=MYBAdSDKInstall(&attempted);
  REQUIRE(ok2==2&&attempted==16,"both Vungle entry points install when their exact signatures are present");
  SEL load=sel_registerName("load:");
  // the failure is delivered after load returns, on the main queue, once; the real load never runs
  __attribute__((objc_precise_lifetime)) id a=[vi new];__attribute__((objc_precise_lifetime)) id dl=[vdel new];objc_setAssociatedObject(a,"d",dl,OBJC_ASSOCIATION_RETAIN);
  ((void(*)(id,SEL,id))objc_msgSend)(a,load,nil);
  REQUIRE(failsI==0&&vLoads==0,"nothing is delivered inside the load call and the real load does not run");
  pump();pump();
  REQUIRE(failsI==1&&gotAdI==a&&[gotErrV isKindOfClass:NSError.class]&&mainThreadCalls==1,"interstitial: told once, with the same ad object and an NSError, on the main thread");
  REQUIRE(loadedV==0&&rewardsV==0&&impressions==0,"no loaded, reward or impression callback is ever made");
  // rewarded: same, and never a reward
  __attribute__((objc_precise_lifetime)) id r=[vr new];objc_setAssociatedObject(r,"d",dl,OBJC_ASSOCIATION_RETAIN);
  ((void(*)(id,SEL,id))objc_msgSend)(r,load,@"bid");pump();
  REQUIRE(failsR==1&&rewardsV==0&&loadedV==0&&vLoads==0,"rewarded: one failure, never a reward, no load");
  // repeated loads on one object: one failure, for the latest
  failsI=0;for(int i=0;i<3;i++)((void(*)(id,SEL,id))objc_msgSend)(a,load,nil);pump();
  REQUIRE(failsI==1,"three loads in a row give one failure, not three");
  ((void(*)(id,SEL,id))objc_msgSend)(a,load,nil);pump();
  REQUIRE(failsI==2,"a later, separate load is answered again, once");
  pump();REQUIRE(failsI==2,"and a delivered failure is never repeated");
  // the delegate is the one present at delivery: set or changed after load
  failsI=0;secondDelegateFails=0;__attribute__((objc_precise_lifetime)) id late=[vi new];
  ((void(*)(id,SEL,id))objc_msgSend)(late,load,nil);
  __attribute__((objc_precise_lifetime)) id d1=[vdel2 new];objc_setAssociatedObject(late,"d",d1,OBJC_ASSOCIATION_RETAIN);pump();
  REQUIRE(secondDelegateFails==1&&failsI==0,"a delegate set after load is the one told");
  objc_setAssociatedObject(late,"d",nil,OBJC_ASSOCIATION_RETAIN);((void(*)(id,SEL,id))objc_msgSend)(late,load,nil);pump();
  REQUIRE(secondDelegateFails==1,"no delegate: nobody is told and nothing crashes");
  __attribute__((objc_precise_lifetime)) id mute=[vi new];objc_setAssociatedObject(mute,"d",[vdelMute new],OBJC_ASSOCIATION_RETAIN);((void(*)(id,SEL,id))objc_msgSend)(mute,load,nil);pump();
  REQUIRE(secondDelegateFails==1&&failsI==0,"a delegate without the optional method is left alone");
  // object lifetime: an ad the app released before delivery is not called back
  failsI=0;
  @autoreleasepool{id gone=[vi new];objc_setAssociatedObject(gone,"d",dl,OBJC_ASSOCIATION_RETAIN);((void(*)(id,SEL,id))objc_msgSend)(gone,load,nil);}
  pump();
  REQUIRE(failsI==0,"a released ad object is not called back (nothing is kept alive by the block)");
  // a load made off the main thread is still answered once, on the main thread
  failsI=0;mainThreadCalls=0;
  dispatch_semaphore_t sem=dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(0,0),^{((void(*)(id,SEL,id))objc_msgSend)(a,load,nil);dispatch_semaphore_signal(sem);});
  dispatch_semaphore_wait(sem,DISPATCH_TIME_FOREVER);pump();
  REQUIRE(failsI==1&&mainThreadCalls==1,"a load from a background thread is answered once, on the main thread");
  // the failure object is a plain NSError with the documented type, never a made-up SDK object
  REQUIRE([gotErrV.domain length]>0&&gotErrV.code!=0,"the error carries a domain and a non-zero code");
 }

 // ---- Unity Ads, Mintegral, LevelPlay: the interfaces read from the vendors' own headers ----
 {
  __block int real=0,uFail=0,uOther=0,mFail=0,mNIFail=0,lFail=0,lPlain=0,lMain=0,rewardish=0;__block NSInteger uCode=-1;__block NSString *uMsg=nil,*uPlace=nil,*lUnit=nil,*mUnit=nil;__block NSError *mErr=nil;
  Class ua=make("UnityAds");Class uaMeta=object_getClass(ua);
  add(uaMeta,"load:loadDelegate:",^(id s,id p,id d){real++;},"v@:@@");add(uaMeta,"load:options:loadDelegate:",^(id s,id p,id o,id d){real++;},"v@:@@@");
  add(uaMeta,"load:",^(id s,id p){real++;},"v@:@"); // single-argument load has no delegate: not hooked
  Class udel=make("MYBTestUnityDelegate");
  add(udel,"unityAdsAdFailedToLoad:withError:withMessage:",^(id s,id p,NSInteger e,id m){uFail++;uCode=e;uMsg=m;uPlace=p;if(!NSThread.isMainThread)uOther++;},"v@:@q@");
  add(udel,"unityAdsAdLoaded:",^(id s,id p){rewardish++;},"v@:@");add(udel,"unityAdsShowComplete:withFinishState:",^(id s,id p,NSInteger st){rewardish++;},"v@:@q");
  Class mi=make("MTGNewInterstitialAdManager");add(mi,"loadAd",^(id s){real++;},"v@:");add(mi,"delegate",^id(id s){return objc_getAssociatedObject(s,"d");},"@@:");
  Class mr=make("MTGRewardAdManager");add(mr,"loadVideoWithPlacementId:unitId:delegate:",^(id s,id p,id u,id d){real++;},"v@:@@@");
  Class mdel=make("MYBTestMintegralDelegate");
  add(mdel,"newInterstitialAdLoadFail:adManager:",^(id s,NSError *e,id m){mNIFail++;mErr=e;},"v@:@@");
  add(mdel,"onVideoAdLoadFailed:unitId:error:",^(id s,id p,id u,NSError *e){mFail++;mUnit=u;mErr=e;},"v@:@@@");
  add(mdel,"onVideoAdLoadSuccess:unitId:",^(id s,id p,id u){rewardish++;},"v@:@@");add(mdel,"onVideoAdDismissed:unitId:withConverted:withRewardInfo:",^(id s,id p,id u,BOOL c,id r){rewardish++;},"v@:@@B@");
  Class li=make("LPMInterstitialAd"),lr=make("LPMRewardedAd");
  for(Class c in @[li,lr]){
   add(c,"loadAd",^(id s){lPlain++;},"v@:");
   add(c,"setDelegate:",^(id s,id d){},"v@:@");
   add(c,"initWithAdUnitId:",^id(id s,NSString *u){return s;},"@@:@");
   add(c,"initWithAdUnitId:config:",^id(id s,NSString *u,id cfg){return s;},"@@:@@");
  }
  Class ldel=make("MYBTestLevelPlayDelegate");
  add(ldel,"didFailToLoadAdWithAdUnitId:error:",^(id s,NSString *u,NSError *e){lFail++;lUnit=u;if(NSThread.isMainThread)lMain++;},"v@:@@");
  add(ldel,"didLoadAdWithAdInfo:",^(id s,id i){rewardish++;},"v@:@");add(ldel,"didRewardAdWithAdInfo:reward:",^(id s,id i,id r){rewardish++;},"v@:@@");
  NSUInteger before=MYBAdSDKInstalledCount(),ok3=MYBAdSDKInstall(&attempted);
  REQUIRE(ok3==6&&MYBAdSDKInstalledCount()==before+6,"Unity (2), Mintegral (2) and LevelPlay (2) entry points install when every documented signature is present");
  // Unity Ads
  id ud=[udel new];
  ((void(*)(id,SEL,id,id))objc_msgSend)(ua,sel_registerName("load:loadDelegate:"),@"Interstitial_iOS",ud);
  REQUIRE(uFail==0&&real==0,"Unity: nothing inside the load call and the real load does not run");pump();
  REQUIRE(uFail==1&&uCode==3&&[uMsg length]>0&&[uPlace isEqual:@"Interstitial_iOS"]&&uOther==0,"Unity: the load delegate gets NoFill (3) with a message and the placement, once, on the main thread");
  ((void(*)(id,SEL,id,id,id))objc_msgSend)(ua,sel_registerName("load:options:loadDelegate:"),@"Rewarded_iOS",nil,ud);pump();
  REQUIRE(uFail==2&&rewardish==0,"Unity: the options form fails the same way and no loaded or show-complete callback is made");
  ((void(*)(id,SEL,id,id))objc_msgSend)(ua,sel_registerName("load:loadDelegate:"),@"x",nil);pump();
  REQUIRE(uFail==2,"Unity: no delegate, nobody is told");
  ((void(*)(id,SEL,id))objc_msgSend)(ua,sel_registerName("load:"),@"p");REQUIRE(real==1,"Unity: the single-argument load (no delegate) is left to run");real=0;
  // Mintegral
  __attribute__((objc_precise_lifetime)) id mgr=[mi new],md=[mdel new];objc_setAssociatedObject(mgr,"d",md,OBJC_ASSOCIATION_RETAIN);
  ((void(*)(id,SEL))objc_msgSend)(mgr,sel_registerName("loadAd"));REQUIRE(mNIFail==0&&real==0,"Mintegral interstitial: nothing inside the call, real load does not run");pump();
  REQUIRE(mNIFail==1&&[mErr isKindOfClass:NSError.class],"Mintegral interstitial: the weak delegate gets newInterstitialAdLoadFail with an NSError, once");
  ((void(*)(id,SEL,id,id,id))objc_msgSend)([mr new],sel_registerName("loadVideoWithPlacementId:unitId:delegate:"),@"pl",@"unit9",md);pump();
  REQUIRE(mFail==1&&[mUnit isEqual:@"unit9"]&&real==0&&rewardish==0,"Mintegral rewarded: onVideoAdLoadFailed with placement, unit and NSError; no success, dismissed or reward callback");
  // LevelPlay
  __attribute__((objc_precise_lifetime)) id ad=((id(*)(id,SEL,id))objc_msgSend)([li alloc],sel_registerName("initWithAdUnitId:"),@"ia_unit");
  __attribute__((objc_precise_lifetime)) id ld=[ldel new];((void(*)(id,SEL,id))objc_msgSend)(ad,sel_registerName("setDelegate:"),ld);
  ((void(*)(id,SEL))objc_msgSend)(ad,sel_registerName("loadAd"));REQUIRE(lFail==0&&lPlain==0,"LevelPlay: nothing inside the call, real load does not run");pump();
  REQUIRE(lFail==1&&[lUnit isEqual:@"ia_unit"]&&lMain==1,"LevelPlay: didFailToLoadAdWithAdUnitId:error: with the unit given at creation, once, on the main thread");
  for(int i=0;i<3;i++)((void(*)(id,SEL))objc_msgSend)(ad,sel_registerName("loadAd"));pump();
  REQUIRE(lFail==2,"LevelPlay: repeated loads give one failure");
  __attribute__((objc_precise_lifetime)) id rad=((id(*)(id,SEL,id,id))objc_msgSend)([lr alloc],sel_registerName("initWithAdUnitId:config:"),@"rw_unit",nil);
  ((void(*)(id,SEL,id))objc_msgSend)(rad,sel_registerName("setDelegate:"),ld);((void(*)(id,SEL))objc_msgSend)(rad,sel_registerName("loadAd"));pump();
  REQUIRE(lFail==3&&[lUnit isEqual:@"rw_unit"]&&rewardish==0,"LevelPlay rewarded (config initialiser): same failure with its own unit and never a reward");
  // an object whose unit was never recorded (created before the hooks) keeps its real load and is not counted
  int32_t counted=MYBAdSDKBlockedCount();
  id stranger=[li alloc];((void(*)(id,SEL))objc_msgSend)(stranger,sel_registerName("loadAd"));pump();
  REQUIRE(lPlain==1&&MYBAdSDKBlockedCount()==counted,"LevelPlay: an ad with an unknown unit id is left to load and is not counted");
  // the delegate is weak: a released delegate is not called, and changing it moves the callback
  lFail=0;@autoreleasepool{id temp=[ldel new];((void(*)(id,SEL,id))objc_msgSend)(ad,sel_registerName("setDelegate:"),temp);((void(*)(id,SEL))objc_msgSend)(ad,sel_registerName("loadAd"));}pump();
  REQUIRE(lFail==0,"LevelPlay: a released delegate is not called (held weakly, as the SDK does)");
  ((void(*)(id,SEL,id))objc_msgSend)(ad,sel_registerName("setDelegate:"),ld);((void(*)(id,SEL))objc_msgSend)(ad,sel_registerName("loadAd"));pump();
  REQUIRE(lFail==1,"LevelPlay: a delegate set later receives the failure");
  // a class missing -setDelegate: is not touched at all
  Class lx=make("LPMBannerLikeNotInTable");(void)lx;
  REQUIRE(MYBAdSDKInstall(&attempted)==0,"nothing stacks on another pass");
 }
 if(failures){fprintf(stderr,"%d failure(s)\n",failures);return 1;}
 printf("Ad SDK blocking checks passed.\n");return 0;}}
