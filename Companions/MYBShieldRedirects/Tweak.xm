// MYbloXX Shield redirect protection.
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import "../../Shared/MYBRedirectPolicy.h"
#import "../../Shared/MYBWebsiteRules.h"
#import "../../Shared/MYBShield.h"
#import "../../Shared/MYBShieldPending.h"
#import "../../Shared/MYBShieldTheme.h"
#import "../../Shared/MYBShieldSheet.h"
#import <roothide.h>
#import "Welcome.h"
@interface MYBShieldApplication:NSObject
@property(nonatomic,copy) NSString *bundleIdentifier;
@end
@interface MYBShieldEntity:NSObject
@property(nonatomic,strong) MYBShieldApplication *application;
@property(nonatomic,copy) NSSet *actions;
@end
@interface MYBShieldProcess:NSObject
@property(nonatomic,copy) NSString *bundleIdentifier;
@property(nonatomic,copy) NSString *name;
@end
@interface MYBShieldLayoutElement:NSObject
@property(nonatomic,copy) NSString *uniqueIdentifier;
@end
@interface MYBShieldLayout:NSObject
- (MYBShieldLayoutElement *)elementWithRole:(long long)role;
@end
@interface MYBShieldTransitionContext:NSObject
@property(nonatomic,strong) MYBShieldLayout *previousLayoutState;
@end
@interface MYBShieldTransition:NSObject
@property(nonatomic,copy) NSSet<MYBShieldEntity *> *fromApplicationSceneEntities;
@property(nonatomic,copy) NSSet<MYBShieldEntity *> *toApplicationSceneEntities;
@property(nonatomic,copy) NSString *eventLabel;
@property(nonatomic,strong) MYBShieldProcess *originatingProcess;
@property(nonatomic,strong) MYBShieldTransitionContext *applicationContext;
- (void)declineWithReason:(id)reason;
@end
@interface MYBLSProxy:NSObject
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@property(nonatomic,readonly) NSString *localizedName;
@property(nonatomic,readonly) NSString *applicationType;
@end
@interface MYBLockManager:NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end
static NSDictionary *redirectSettings;
static void readRedirectSettings(void){redirectSettings=[NSDictionary dictionaryWithContentsOfFile:MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist")]?:@{};}
static void changed(CFNotificationCenterRef c,void *o,CFStringRef n,const void *v,CFDictionaryRef i){(void)c;(void)o;(void)n;(void)v;(void)i;dispatch_async(dispatch_get_main_queue(),^{readRedirectSettings();});}
static NSString *appName(NSString *bundle){
 Class proxy=NSClassFromString(@"LSApplicationProxy");NSString *name=nil;
 if([proxy respondsToSelector:@selector(applicationProxyForIdentifier:)])name=[(id)[(Class)proxy applicationProxyForIdentifier:bundle] localizedName];
 return name.length?name:bundle;
}
// Device lock state decides whether we may show anything. If it cannot be determined the transition is left alone.
static BOOL deviceUnlocked(void){
 Class lock=NSClassFromString(@"SBLockScreenManager");id manager=[lock respondsToSelector:@selector(sharedInstance)]?[(id)lock sharedInstance]:nil;
 return [manager respondsToSelector:@selector(isUILocked)]&&![(MYBLockManager *)manager isUILocked];
}
static UIWindow *promptWindow;
static NSString *promptKey;                 // what the sheet on screen is asking about
static NSMutableDictionary *promptLast;
static void closePrompt(void){promptWindow.hidden=YES;promptWindow=nil;promptKey=nil;}
// A window for SpringBoard-level UI. Prefers a foreground-active window scene; SpringBoard may expose its main
// display's scene in another activation state (or none), so any window scene is accepted next, and finally a plain
// frame-based window on the main screen, which UIKit attaches to the default scene. Returns nil only if UIKit
// itself cannot create one, and that is reported to the caller BEFORE the transition is declined.
static UIWindow *makePromptWindow(void){
 UIWindowScene *scene=nil,*any=nil;
 for(UIScene *c in UIApplication.sharedApplication.connectedScenes){if(![c isKindOfClass:UIWindowScene.class])continue;any=any?:(UIWindowScene *)c;if(c.activationState==UISceneActivationStateForegroundActive){scene=(UIWindowScene *)c;break;}}
 scene=scene?:any;
 UIWindow *window=scene?[[UIWindow alloc] initWithWindowScene:scene]:[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
 if(!window)return nil;window.windowLevel=UIWindowLevelAlert+1;window.rootViewController=[UIViewController new];return window;
}
// The link type of the attempt being judged, for the history entry: nil = not seen, @"" = an app-open request with no link, else the scheme.
static NSString *gEventScheme;static BOOL gEventSchemeKnown;
static void recordActivity(NSString *type,NSString *source,NSString *target,NSString *reason){MYBShieldRecordActivityScheme(MYBShieldActivityFile(),type,source,target,reason,gEventScheme,gEventSchemeKnown);}
// Scoped permission, never combined: the App Store permission is per source app; an app-to-app permission is per
// source AND destination. A grant is made only here, from SpringBoard's own UI, never from a web page. The lock
// state is checked again when the prompt is about to be shown and again when a choice is made: nothing is shown
// or granted on a locked device.
// Re-opens the link the person just allowed. The declined transition cannot be resumed, so the same URL is opened again through LaunchServices
// while the source app is still in front. That attempt is judged like any other: it is let through only by the permission that was just saved
// (same source, destination and scheme), and a request whose sender cannot be identified is not touched at all. There is no separate
// time-window allowance: nothing but the saved permission can let a later request through. The URL exists only in memory, only for this one
// pending attempt, and is never written or logged.
static void reopenAllowedURL(NSURL *url,NSString *type,NSString *source,NSString *target){
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.4*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  id workspace=nil;Class cls=NSClassFromString(@"LSApplicationWorkspace");SEL dflt=NSSelectorFromString(@"defaultWorkspace");
  if([cls respondsToSelector:dflt])workspace=((id(*)(id,SEL))objc_msgSend)(cls,dflt);
  SEL sensitive=NSSelectorFromString(@"openSensitiveURL:withOptions:"),plain=NSSelectorFromString(@"openURL:withOptions:");
  BOOL ok=NO;
  if([workspace respondsToSelector:sensitive])ok=((BOOL(*)(id,SEL,id,id))objc_msgSend)(workspace,sensitive,url,nil);
  else if([workspace respondsToSelector:plain])ok=((BOOL(*)(id,SEL,id,id))objc_msgSend)(workspace,plain,url,nil);
  if(!ok){ // LaunchServices refused: the system application object is the second route
   UIApplication *app=UIApplication.sharedApplication;if([app respondsToSelector:@selector(openURL:options:completionHandler:)]){[app openURL:url options:@{} completionHandler:nil];ok=YES;}
  }
  recordActivity(type,source,target,ok?@"allowed-reopened":@"allowed-reopen-failed");
 });
}
// ---- who asked, and is it really a link ------------------------------------------------------------------------------------------
// Only a sender MYbloXX® can name with confidence is ever asked about (see Shared/MYBRedirectPolicy.h). A previous-scene guess, a daemon, SpringBoard,
// Spotlight, Settings, calls and the lock screen are left alone, and so is any request that cannot be matched. A cached answer is kept for a minute.
static BOOL isInstalledApp(NSString *bundle){
 if(![bundle isKindOfClass:NSString.class]||!bundle.length)return NO;
 static NSMutableDictionary *cache;if(!cache)cache=[NSMutableDictionary dictionary];
 NSArray *hit=cache[bundle];double now=NSDate.timeIntervalSinceReferenceDate;
 if(hit&&now-[hit[1] doubleValue]<60)return [hit[0] boolValue];
 Class proxy=NSClassFromString(@"LSApplicationProxy");id found=[proxy respondsToSelector:@selector(applicationProxyForIdentifier:)]?[(Class)proxy applicationProxyForIdentifier:bundle]:nil;
 NSString *type=[found respondsToSelector:@selector(applicationType)]?[(MYBLSProxy *)found applicationType]:nil;
 BOOL app=[type isEqual:@"User"]||[type isEqual:@"System"];
 if(cache.count>200)[cache removeAllObjects];cache[bundle]=@[@(app),@(now)];return app;
}
static NSString *frontApp(void){
 id application=UIApplication.sharedApplication;SEL front=NSSelectorFromString(@"_accessibilityFrontMostApplication");
 id app=[application respondsToSelector:front]?((id(*)(id,SEL))objc_msgSend)(application,front):nil;
 NSString *name=[app respondsToSelector:@selector(bundleIdentifier)]?[(MYBShieldApplication *)app bundleIdentifier]:nil;
 return [name isKindOfClass:NSString.class]&&name.length?name:nil;
}
// The options of an open request: does it carry a link or a user activity, and does it name the app that sent it? Only keys are matched by
// meaning and only strings that are valid bundle identifiers count; the values are never logged.
static BOOL optionsCarryLink(id value,int depth){
 if(depth>2||![value isKindOfClass:NSDictionary.class])return NO;
 for(id key in value){NSString *k=[key isKindOfClass:NSString.class]?[key lowercaseString]:@"";
  if([k containsString:@"url"]||[k containsString:@"useractivity"]||[k containsString:@"userinfoactivity"])return YES;
  if(optionsCarryLink(value[key],depth+1))return YES;}
 return NO;
}
static NSString *optionsNamedSource(id value,int depth){
 if(depth>2||![value isKindOfClass:NSDictionary.class])return nil;
 for(id key in value){NSString *k=[key isKindOfClass:NSString.class]?[key lowercaseString]:@"";id v=value[key];
  if([k containsString:@"source"]&&[v isKindOfClass:NSString.class]&&MYBShieldBundleValid(v))return v;
  NSString *inner=optionsNamedSource(v,depth+1);if(inner.length)return inner;}
 return nil;
}
// Entry hold-back (SBMainWorkspace _handleOpenApplicationRequest:...). The sender is the requesting process when that is an installed app;
// for a request LaunchServices (lsd) sends on an app's behalf it is the app the request itself names, if that app is also the one in front;
// the app in front alone, with an explicit link payload, is accepted for the App Store only. Anything else has no usable sender.
static NSString *entrySource(id origin,NSDictionary *options,MYBSourceTrust *trust){
 *trust=MYBSourceNone;
 NSString *bundle=[origin respondsToSelector:@selector(bundleIdentifier)]?[(MYBShieldProcess *)origin bundleIdentifier]:nil;
 if(bundle.length){if(MYBRedirectSystemSurface(bundle)||!isInstalledApp(bundle))return nil;*trust=MYBSourceProcess;return bundle;}
 NSString *name=[origin respondsToSelector:@selector(name)]?[(MYBShieldProcess *)origin name]:nil;
 if(![name isEqual:@"lsd"])return nil; // SpringBoard itself or another daemon: a direct launch is never touched
 NSString *front=frontApp();if(!front.length||MYBRedirectSystemSurface(front)||!isInstalledApp(front))return nil;
 NSString *named=optionsNamedSource(options,0);
 if(named.length&&[named isEqual:front]){*trust=MYBSourceBroker;return front;}
 if(optionsCarryLink(options,0)){*trust=MYBSourceFront;return front;}
 return nil;
}
static NSString *attemptKey(NSString *type,NSString *source,NSString *target){return [NSString stringWithFormat:@"%@|%@|%@",type,source,target?:@""];}
static NSMutableDictionary *outcomeAt;      // attempt key -> when its outcome was recorded, so a repeated refused open is not recorded twice
static void noteOutcome(NSString *key){if(!outcomeAt)outcomeAt=[NSMutableDictionary dictionary];outcomeAt[key]=@(NSDate.timeIntervalSinceReferenceDate);if(outcomeAt.count>64)[outcomeAt removeAllObjects];}
static BOOL recentOutcome(NSString *key){double at=[outcomeAt[key] doubleValue];return at>0&&NSDate.timeIntervalSinceReferenceDate-at<8;}
static void recordOutcome(NSString *type,NSString *source,NSString *target,NSString *reason){noteOutcome(attemptKey(type,source,target));recordActivity(type,source,target,reason);}
// `held` is the original open request when it was held back at its entry (see the MYBEntry group): it is released exactly once, whatever the
// outcome (allowed, not allowed, dismissed, locked, no prompt, or the time limit), so the requesting app is never left waiting.
// Every prompt ends in exactly one recorded outcome: Block This Time, closed without an answer, Allow saved (and what was done with it), or a failed save.
static void presentPrompt(UIWindow *window,MYBRedirectKind kind,NSString *source,NSString *dest,NSString *scheme,NSURL *resumeURL,NSString *actionKinds,dispatch_block_t held){
 (void)actionKinds;
 gEventScheme=scheme;gEventSchemeKnown=YES; // every outcome recorded for this prompt carries its link type
 NSString *attempt=NSUUID.UUID.UUIDString; // this prompt is for one pending attempt; a one-time permission made here is stored as a retry approval (matched by source, destination and scheme) and keeps this id only as a label
 BOOL store=kind==MYBRedirectAppStore;NSString *type=store?@"appstore":@"appredirect",*target=store?nil:dest;
 promptWindow=window;promptKey=attemptKey(type,source,target); // held from now on, so a second attempt sees "already visible"
 if(!MYBPendingBegin(MYBPendingStore(),attempt,source,dest,scheme,NSDate.timeIntervalSinceReferenceDate)){closePrompt();if(held)held();return;}
 if(held)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(30*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MYBPendingCancel(MYBPendingStore(),attempt);held();}); // nobody answered: the request goes on and is judged again by the transition check
 dispatch_async(dispatch_get_main_queue(),^{
  if(promptWindow!=window){if(held)held();return;}
  if(!deviceUnlocked()){closePrompt();if(held)held();recordActivity(type,source,target,@"prompt-unavailable");return;} // locked meanwhile: no prompt, nothing declined here
  NSString *from=appName(source),*to=store?@"the App Store":appName(dest);
  window.hidden=NO;
  NSString *detail=store?@"MYbloXX® can’t tell whether you tapped a store link or an ad opened the App Store, and it does not cover App Store sheets an app shows inside itself.":@"MYbloXX® asks before a link opens another app. It only asks when it can tell which app sent the link.";
  NSString *perms=MYBShieldPermissionsFile();
  __block BOOL recorded=NO; // one outcome per prompt
  MYBShieldSheet *sheet=[MYBShieldSheet new];sheet.heading=MYBShieldTitle(type);
  sheet.message=[NSString stringWithFormat:@"%@ tried to open %@.\n\n%@",from,to,detail];
  sheet.facts=@[@[@"From",from],@[@"Wants to open",to]];
  NSMutableArray *actions=[NSMutableArray array];
  for(NSArray *entry in @[@[@"Allow once",@"once"],@[@"Allow for 15 minutes",@"temp"],@[[NSString stringWithFormat:@"Always allow from %@",from],@"always"]]){
   NSString *mode=entry[1];__block NSDictionary *grant=nil;__block BOOL attempted=NO;__block MYBPendingOutcome pendingOutcome=MYBPendingNone;
   MYBShieldAction *a=[MYBShieldAction title:entry[0] detail:nil style:MYBShieldActionSecondary handler:^{
    if(attempted)return; // a repeated tap never writes twice
    attempted=YES;
    grant=deviceUnlocked()&&MYBPendingIsPending(MYBPendingStore(),attempt,NSDate.timeIntervalSinceReferenceDate)?MYBShieldAddGrantFor(perms,type,source,target,mode,scheme,attempt):nil; // lock state and the pending attempt re-checked at action time
    // The declined transition has no continuation; the link is opened again instead (reopenAllowedURL), run at most once and only after a saved permission.
    dispatch_block_t resume=nil;if(held)resume=held;else if(resumeURL)resume=^{reopenAllowedURL(resumeURL,type,source,target);};
    pendingOutcome=MYBPendingFinish(MYBPendingStore(),attempt,grant!=nil,NSDate.timeIntervalSinceReferenceDate,resume);
    if(held){held();} // not allowed: released here and judged again as before
    if(grant){
     recorded=YES;
     if(held&&pendingOutcome==MYBPendingResumed)recordOutcome(type,source,target,@"allowed-released");
     else if(!held&&resumeURL&&pendingOutcome==MYBPendingResumed)noteOutcome(attemptKey(type,source,target)); // reopenAllowedURL records what happened to the link
     else recordOutcome(type,source,target,[@"permission-saved-" stringByAppendingString:mode]); // the person taps the link again
    }else if(deviceUnlocked()){
     // Failure keeps the previous permissions (the writer replaces the file only after a complete write) and records the real reason.
     recorded=YES;NSLog(@"MYbloXX® Shield: could not save %@ permission for %@ -> %@: %@",mode,source,target?:@"-",MYBShieldLastError());recordOutcome(type,source,target,MYBShieldSaveFailureReason());
    }
   }];
   a.result=^NSDictionary *{
    NSString *shown=(!grant&&!deviceUnlocked())?@"The device was locked. Nothing was allowed.":MYBPendingMessage(pendingOutcome,from,to,MYBShieldDurationText(mode));
    return @{@"ok":@(grant!=nil),@"title":grant?(pendingOutcome==MYBPendingResumed?@"Allowed":@"Permission saved · tap the link again"):@"Not allowed",@"message":shown};
   };
   [actions addObject:a];
  }
  ((MYBShieldAction *)actions.firstObject).style=MYBShieldActionPrimary;
  [actions addObject:[MYBShieldAction title:@"Block This Time" detail:nil style:MYBShieldActionCancel handler:^{if(recorded)return;recorded=YES;recordOutcome(type,source,target,@"block-this-time");}]]; // saves no permission; it is an event, never a rule
  sheet.actions=actions;sheet.dismissOnBackdrop=NO;
  sheet.onGone=^{MYBPendingCancel(MYBPendingStore(),attempt);if(held)held();if(!recorded){recorded=YES;recordOutcome(type,source,target,@"dismissed");}closePrompt();}; // dismissed, cancelled or locked: the attempt ends and nothing is allowed
  if(![MYBShieldSheet present:sheet from:window.rootViewController completion:^(BOOL shown){
   // A prompt that did not actually appear must not leave the window claiming the slot.
   if(!shown){recorded=YES;if(held)held();closePrompt();recordActivity(type,source,target,@"prompt-unavailable");}
  }]){recorded=YES;if(held)held();closePrompt();recordActivity(type,source,target,@"prompt-unavailable");}
 });
}
// Entry hold-back for the App Store and, when switched on, for other apps. A device capture showed the original request arriving at
// -[SBMainWorkspace _handleOpenApplicationRequest:options:activationSettings:origin:withResult:] (bundle id, options dictionary, activation settings, the
// requesting process, the result block) before its transition exists, and that the App Store open carries a user activity, not a link, so it can
// never be re-opened by URL. Here the call is held back instead: MYbloXX® asks first, and on Allow the very same call is passed on unchanged, so the
// first tap opens the App Store. Not allowed, dismissed or unanswered: the same call is passed on and the transition check judges it as before.
// Everything MYbloXX® cannot name with confidence, and every case where no prompt can be shown, is passed on untouched.
// The result block is never called or inspected here.
static MYBRedirectKind entryKind(NSString *dest,NSString *source,MYBSourceTrust trust,NSDictionary *options){
 if(!dest.length||!source.length||![options isKindOfClass:NSDictionary.class])return MYBRedirectNone;
 return MYBRedirectDecide(redirectSettings,source,trust,dest,YES,^BOOL(NSString *b){return isInstalledApp(b);});
}
static BOOL entryWantsHold(MYBRedirectKind kind,NSString *dest,NSString *source){
 if(kind==MYBRedirectNone||!NSThread.isMainThread||promptWindow||!deviceUnlocked())return NO;
 if(MYBRedirectPromptPlan(deviceUnlocked(),YES,NO,^BOOL{return YES;})==MYBPromptLeaveAlone)return NO;
 BOOL store=kind==MYBRedirectAppStore;
 if(MYBShieldAllowsScheme(MYBShieldPermissionsFile(),store?@"appstore":@"appredirect",source,store?nil:dest,nil,NO))return NO; // already allowed: untouched
 return YES;
}
%group MYBEntry
%hook SBMainWorkspace
- (void)_handleOpenApplicationRequest:(NSString *)bundle options:(NSDictionary *)options activationSettings:(id)activation origin:(id)origin withResult:(id)result{
 NSString *dest=[bundle isKindOfClass:NSString.class]?bundle:nil;
 MYBSourceTrust trust=MYBSourceNone;NSString *source=entrySource(origin,options,&trust);
 MYBRedirectKind kind=entryKind(dest,source,trust,options);
 if(!entryWantsHold(kind,dest,source)){%orig;return;}
 UIWindow *window=makePromptWindow();if(!window){%orig;recordActivity(kind==MYBRedirectAppStore?@"appstore":@"appredirect",source,kind==MYBRedirectAppStore?nil:dest,@"prompt-unavailable");return;}
 BOOL store=kind==MYBRedirectAppStore;
 NSString *type=store?@"appstore":@"appredirect",*target=store?nil:dest;
 gEventScheme=nil;gEventSchemeKnown=YES; // an app-open request has no link
 id heldResult=[result copy]; // a block that outlives this call must be on the heap; it is only held and handed back, never called here
 __block BOOL released=NO;
 dispatch_block_t original=^{
  if(released)return;released=YES;
  // Not allowed: iOS follows a refused open with a second request for the same app a few milliseconds later. It must not raise a second prompt,
  // so the prompt gap for this source is started now, exactly as it is when the transition check declines.
  if(!MYBShieldAllowsScheme(MYBShieldPermissionsFile(),type,source,target,nil,NO)){if(!promptLast)promptLast=[NSMutableDictionary dictionary];MYBShieldShouldNotify(promptLast,attemptKey(type,source,target),NSDate.timeIntervalSinceReferenceDate,8);}
  %orig(bundle,options,activation,origin,heldResult);}; // the same call, once
 presentPrompt(window,kind,source,dest,nil,nil,@"entry-held",original);
}
%end
%end
%hook SBMainWorkspace
- (BOOL)_canExecuteTransitionRequest:(id)requestObject forExecution:(BOOL)execute{
 if(![requestObject isKindOfClass:%c(SBMainWorkspaceTransitionRequest)])return %orig;
 MYBShieldTransition *request=requestObject;NSString *label=request.eventLabel;
 if([label containsString:@"ActivateFromBreadcrumb"])return %orig;
 MYBShieldEntity *from=request.fromApplicationSceneEntities.anyObject,*to=request.toApplicationSceneEntities.anyObject;
 id action=from.actions.anyObject;if(action&&![action isKindOfClass:%c(UIOpenURLAction)])return %orig;
 // The link to open again, and positive evidence this is an app opening something: an open-URL action on either scene, or an explicit open request from a requester.
 // A transition with neither (a screen change, a switcher move, a notification tap) is not a link.
 NSURL *resumeURL=nil;NSString *scheme=nil;NSMutableArray *seenKinds=[NSMutableArray array];BOOL openAction=NO;
 for(MYBShieldEntity *entity in @[from?:(id)NSNull.null,to?:(id)NSNull.null]){
  if(![(id)entity respondsToSelector:@selector(actions)])continue;
  for(id candidate in entity.actions){
   [seenKinds addObject:NSStringFromClass([candidate class])];
   if(![candidate isKindOfClass:%c(UIOpenURLAction)])continue;openAction=YES;
   if(resumeURL)continue;
   id u=((id(*)(id,SEL))objc_msgSend)(candidate,NSSelectorFromString(@"url"));if([u isKindOfClass:NSURL.class]){resumeURL=u;scheme=MYBShieldNormalScheme([(NSURL *)u scheme]);} // the permission scheme and the link come from the same action
  }
 }
 BOOL requested=[label containsString:@"OpenApplication"]&&[label containsString:@"ForRequester"];
 if(!requested&&!openAction)return %orig;
 // Who sent it: the requesting process when it is an installed app. A request LaunchServices sends has no app of its own; the app being left is then
 // used for the App Store only, and only with an open-URL action. A previous-scene guess is never used.
 NSString *source=nil;MYBSourceTrust trust=MYBSourceNone;
 NSString *originBundle=request.originatingProcess.bundleIdentifier;
 if(originBundle.length){if(!MYBRedirectSystemSurface(originBundle)&&isInstalledApp(originBundle)){source=originBundle;trust=MYBSourceProcess;}}
 else if([request.originatingProcess.name isEqual:@"lsd"]&&openAction){NSString *left=from.application.bundleIdentifier;if(left.length&&!MYBRedirectSystemSurface(left)&&isInstalledApp(left)){source=left;trust=MYBSourceFront;}}
 NSString *destination=to.application.bundleIdentifier;
 MYBRedirectKind kind=MYBRedirectDecide(redirectSettings,source,trust,destination,YES,^BOOL(NSString *b){return isInstalledApp(b);});
 if(kind==MYBRedirectNone||MYBRedirectPromptPlan(deviceUnlocked(),YES,NO,^BOOL{return YES;})==MYBPromptLeaveAlone)return %orig; // not ours, or the device is locked / its state unknown: never interfere
 NSString *type=kind==MYBRedirectAppStore?@"appstore":@"appredirect",*target=kind==MYBRedirectAppStore?nil:destination;
 gEventScheme=scheme;gEventSchemeKnown=YES; // the first history entry for this attempt (blocked, suppressed, unavailable) records the link type
 // A one-time grant is consumed only by the transition that actually executes, not by the preliminary "can it run" check.
 if(MYBShieldAllowsScheme(MYBShieldPermissionsFile(),type,source,target,scheme,execute))return %orig;
 // Decide whether the person can be asked BEFORE declining. SpringBoard evaluates a transition on its main thread; anything else cannot present UI.
 // If no question can be shown, the request is NOT declined: it goes ahead and that is recorded.
 UIWindow *window=nil;
 static NSMutableDictionary *seen;if(!seen)seen=[NSMutableDictionary dictionary];if(!promptLast)promptLast=[NSMutableDictionary dictionary];
 NSString *key=attemptKey(type,source,target);
 // The same attempt is evaluated more than once (can it run, then run): it is counted and announced once.
 BOOL firstSight=MYBShieldShouldNotify(seen,key,NSDate.timeIntervalSinceReferenceDate,1.5);
 if(NSThread.isMainThread&&!promptWindow)window=makePromptWindow();
 MYBPromptPlan plan=MYBRedirectPlanFor(YES,window!=nil,promptWindow?promptKey:nil,key,^BOOL{return MYBShieldShouldNotify(promptLast,key,NSDate.timeIntervalSinceReferenceDate,8);});
 if(plan==MYBPromptShow&&!window)plan=MYBPromptUnavailable;
 if(plan==MYBPromptUnavailable){if(firstSight)recordActivity(type,source,target,@"prompt-unavailable");return %orig;}
 [request declineWithReason:@"MYbloXX® Shield"];
 if(plan==MYBPromptSuppressed){if(firstSight&&!recentOutcome(key))recordActivity(type,source,target,@"prompt-suppressed");return NO;}
 presentPrompt(window,kind,source,destination,scheme,resumeURL,[seenKinds componentsJoinedByString:@","],nil);
 return NO;
}
%end
%ctor{if([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]){readRedirectSettings();welcomeObserveReplay();welcomeStart(^(BOOL *ready){*ready=deviceUnlocked()&&!promptWindow;});{Method entry=class_getInstanceMethod(NSClassFromString(@"SBMainWorkspace"),NSSelectorFromString(@"_handleOpenApplicationRequest:options:activationSettings:origin:withResult:"));const char *enc=entry?method_getTypeEncoding(entry):NULL;if(enc&&strcmp(enc,"v56@0:8@16@24@32@40@?48")==0){%init(MYBEntry);}} CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,changed,CFSTR("net.myxxdev.mybloxx.safariguard.changed"),NULL,CFNotificationSuspensionBehaviorCoalesce);%init;}}
