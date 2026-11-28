#pragma once
#import <Foundation/Foundation.h>
// App Redirect Protection policy. Pure Foundation, so the same rules run in SpringBoard, Settings, the helper and the native tests.
// (Written without object subscripting on purpose: the focused redirect test also builds with the GNU runtime on Linux.)
//
// Two independent switches, saved in the Shield preferences:
//   RedirectAskAppStore    "Ask Before Apps Open the App Store"   on by default
//   RedirectAskOtherApps   "Ask Before Links Open Other Apps"     off by default
// Older releases saved one master switch (RedirectEnabled) and RedirectOtherApps. Those keys are never rewritten or deleted.
// While a new key is absent, its value is what the older keys effectively did, so an upgrade keeps exactly the coverage the person had:
//   App Store      = RedirectEnabled (absent counts as on)
//   Other apps     = RedirectEnabled AND RedirectOtherApps (absent counts as off)
// The first time either switch is touched, BOTH new keys are saved, the untouched one with its current effective value, so touching
// one switch can never widen or narrow the other.
#define MYB_REDIRECT_KEY_STORE @"RedirectAskAppStore"
#define MYB_REDIRECT_KEY_OTHER @"RedirectAskOtherApps"

typedef NS_ENUM(NSInteger,MYBRedirectKind){MYBRedirectNone=0,MYBRedirectAppStore,MYBRedirectApp};

static inline BOOL MYBRedirectLegacyStore(NSDictionary *settings){
 id master=[settings objectForKey:@"RedirectEnabled"];return master?[master boolValue]:YES;
}
static inline BOOL MYBRedirectLegacyOther(NSDictionary *settings){
 return MYBRedirectLegacyStore(settings)&&[[settings objectForKey:@"RedirectOtherApps"] boolValue];
}
static inline BOOL MYBRedirectAskAppStore(NSDictionary *settings){
 id v=[settings objectForKey:MYB_REDIRECT_KEY_STORE];return [v isKindOfClass:NSNumber.class]?[v boolValue]:MYBRedirectLegacyStore(settings);
}
static inline BOOL MYBRedirectAskOtherApps(NSDictionary *settings){
 id v=[settings objectForKey:MYB_REDIRECT_KEY_OTHER];return [v isKindOfClass:NSNumber.class]?[v boolValue]:MYBRedirectLegacyOther(settings);
}
// Saves one switch. The other keeps its current effective value (made explicit), the older keys and every saved permission are untouched.
static inline void MYBRedirectSetAskAppStore(NSMutableDictionary *settings,BOOL on){
 BOOL other=MYBRedirectAskOtherApps(settings);[settings setObject:@(on) forKey:MYB_REDIRECT_KEY_STORE];[settings setObject:@(other) forKey:MYB_REDIRECT_KEY_OTHER];
}
static inline void MYBRedirectSetAskOtherApps(NSMutableDictionary *settings,BOOL on){
 BOOL store=MYBRedirectAskAppStore(settings);[settings setObject:@(store) forKey:MYB_REDIRECT_KEY_STORE];[settings setObject:@(on) forKey:MYB_REDIRECT_KEY_OTHER];
}
// Upgrade fill (helper): make the effective choice explicit without changing it. A fresh install has neither older key and gets the
// baseline (App Store on, other apps off).
static inline void MYBRedirectMaterialize(NSMutableDictionary *settings){
 if([[settings objectForKey:MYB_REDIRECT_KEY_STORE] isKindOfClass:NSNumber.class]&&[[settings objectForKey:MYB_REDIRECT_KEY_OTHER] isKindOfClass:NSNumber.class])return;
 BOOL store=MYBRedirectAskAppStore(settings),other=MYBRedirectAskOtherApps(settings);
 [settings setObject:@(store) forKey:MYB_REDIRECT_KEY_STORE];[settings setObject:@(other) forKey:MYB_REDIRECT_KEY_OTHER];
}

// ---- what counts as an app, and what is system UI ------------------------------------------------------------------------------
// System surfaces are never the source or the destination of an app-to-app link: Home Screen, Spotlight, Settings, calls, the lock screen,
// widgets and Siri. The App Store as a SOURCE is the person tapping Open there.
static inline BOOL MYBRedirectSystemSurface(NSString *bundle){
 if(![bundle isKindOfClass:NSString.class]||!bundle.length)return YES;
 NSString *l=bundle.lowercaseString;
 for(NSString *prefix in @[@"com.apple.springboard",@"com.apple.preferences",@"com.apple.spotlight",@"com.apple.incallservice",@"com.apple.mobilephone",
   @"com.apple.telephonyutilities",@"com.apple.chronod",@"com.apple.preboard",@"com.apple.siri",@"com.apple.assistant",@"com.apple.purplebuddy",
   @"com.apple.carplay",@"com.apple.lockscreen",@"com.apple.camerauiservice",@"com.apple.safariviewservice"])
  if([l isEqual:prefix]||[l hasPrefix:[prefix stringByAppendingString:@"."]])return YES;
 return NO;
}
static inline BOOL MYBRedirectIsAppStore(NSString *bundle){return [@[@"com.apple.AppStore",@"com.apple.ios.StoreKitUIService"] containsObject:bundle];}

// How sure we are of WHO asked. Only the first two may start an app-to-app prompt.
//   Process    the process that sent the request is itself an installed app
//   Broker     LaunchServices sent it and the request itself names an installed app, and that app is the one in front
//   Front      only the app in front is known, with an explicit link payload and a LaunchServices sender. App Store only.
//   None       nothing usable (a daemon, SpringBoard, a previous-scene guess): the request is left alone
typedef NS_ENUM(NSInteger,MYBSourceTrust){MYBSourceNone=0,MYBSourceFront,MYBSourceBroker,MYBSourceProcess};

// The decision. `explicitOpen` is positive evidence that this is an app asking to open something (an open request from a requester, or an
// open-URL action), not just a screen change. `isApp` answers "is this bundle an installed application?".
static inline MYBRedirectKind MYBRedirectDecide(NSDictionary *settings,NSString *source,MYBSourceTrust trust,NSString *destination,BOOL explicitOpen,BOOL(^isApp)(NSString *)){
 if(!explicitOpen||trust==MYBSourceNone)return MYBRedirectNone;
 if(![source isKindOfClass:NSString.class]||![destination isKindOfClass:NSString.class]||!source.length||!destination.length||[source isEqual:destination])return MYBRedirectNone;
 if(MYBRedirectSystemSurface(source)||[source isEqual:@"com.apple.AppStore"]||MYBRedirectIsAppStore(source))return MYBRedirectNone;
 if(isApp&&!isApp(source))return MYBRedirectNone;
 if(MYBRedirectIsAppStore(destination))return MYBRedirectAskAppStore(settings)?MYBRedirectAppStore:MYBRedirectNone;
 if(trust<MYBSourceBroker)return MYBRedirectNone; // other apps need a verified sender, never the app that merely happened to be in front
 if(MYBRedirectSystemSurface(destination)||(isApp&&!isApp(destination)))return MYBRedirectNone; // normal launches, calls, Settings and services
 return MYBRedirectAskOtherApps(settings)?MYBRedirectApp:MYBRedirectNone;
}
// Older entry point, kept for callers that already have a verified source. A direct launch from SpringBoard and moves within one app are never touched.
static inline MYBRedirectKind MYBRedirectClassify(NSDictionary *settings,NSString *source,NSString *destination,BOOL linkRequest){
 return MYBRedirectDecide(settings,source,MYBSourceProcess,destination,linkRequest,nil);
}

// What to do with one intercepted redirect, decided BEFORE anything is declined, so a decline never happens without a way to ask.
//   LeaveAlone   the device is locked (or its state cannot be determined): never interfere, no prompt, no decline.
//   Show         decline and show the prompt.
//   Suppressed   decline, but no new prompt: the same attempt is already being asked about, or was answered a moment ago (iOS repeats a refused open).
//   Unavailable  no prompt can be shown right now: the request is NOT declined. It goes ahead and the outcome is recorded.
// `rateAllows` is only evaluated when every earlier condition passed, because evaluating it counts as a notification.
typedef NS_ENUM(NSInteger,MYBPromptPlan){MYBPromptLeaveAlone=0,MYBPromptShow,MYBPromptSuppressed,MYBPromptUnavailable};
static inline MYBPromptPlan MYBRedirectPromptPlan(BOOL unlockedKnown,BOOL presenterAvailable,BOOL promptVisible,BOOL(^rateAllows)(void)){
 if(!unlockedKnown)return MYBPromptLeaveAlone;
 if(!presenterAvailable)return MYBPromptUnavailable;
 if(promptVisible)return MYBPromptSuppressed;
 return rateAllows()?MYBPromptShow:MYBPromptSuppressed;
}
// Plan for the real prompt state: `visibleKey` is what the sheet on screen asks about (nil when none), `key` is this attempt.
// A different attempt while a sheet is open cannot safely be asked about, so it is not declined.
static inline MYBPromptPlan MYBRedirectPlanFor(BOOL unlockedKnown,BOOL canMakeWindow,NSString *visibleKey,NSString *key,BOOL(^rateAllows)(void)){
 if(!unlockedKnown)return MYBPromptLeaveAlone;
 if(visibleKey.length)return [visibleKey isEqual:key]?MYBPromptSuppressed:MYBPromptUnavailable;
 return MYBRedirectPromptPlan(unlockedKnown,canMakeWindow,NO,rateAllows);
}
static inline NSString *MYBRedirectPlanReason(MYBPromptPlan plan,NSString *type){
 return plan==MYBPromptUnavailable?@"prompt-unavailable":plan==MYBPromptSuppressed?@"prompt-suppressed":type;
}

// ---- what a recorded event means (shared by the history screens) --------------------------------------------------------------
// Blocked: the request was stopped. Saved: the person allowed it and the permission was saved (the link may still need a second tap).
// Continued: the request went on to iOS; MYbloXX® has no evidence the other app really opened, so it never says "Opened".
typedef NS_ENUM(NSInteger,MYBRedirectOutcome){MYBOutcomeBlocked=0,MYBOutcomeSaved,MYBOutcomeContinued};
static inline MYBRedirectOutcome MYBRedirectOutcomeForReason(NSString *reason){
 if(![reason isKindOfClass:NSString.class])return MYBOutcomeBlocked;
 if([reason hasPrefix:@"permission-saved"]||[reason isEqual:@"allowed-reopen-failed"]||[reason hasPrefix:@"allowed-no-url"])return MYBOutcomeSaved;
 if([reason isEqual:@"allowed-released"]||[reason isEqual:@"allowed-and-released"]||[reason isEqual:@"allowed-reopened"]||[reason isEqual:@"allowed-and-reopened"]||[reason isEqual:@"prompt-unavailable"]||[reason isEqual:@"passed-on"])return MYBOutcomeContinued;
 return MYBOutcomeBlocked;
}
static inline NSString *MYBRedirectOutcomeTitle(MYBRedirectOutcome o){return o==MYBOutcomeSaved?@"Permission saved":o==MYBOutcomeContinued?@"Allowed to continue":@"Blocked";}
// One sentence for the reason, never a claim about intent or about whether an app opened.
static inline NSString *MYBRedirectReasonText(NSString *reason){
 NSDictionary *t=[NSDictionary dictionaryWithObjectsAndKeys:
  @"MYbloXX® asked and the request was stopped.",@"appstore",
  @"MYbloXX® asked and the request was stopped.",@"appredirect",
  @"You chose Block This Time. Nothing was saved.",@"block-this-time",
  @"The question was closed without an answer, so the request stayed blocked.",@"dismissed",
  @"Blocked. A question for this app was already showing or had just been answered, so you were not asked again.",@"prompt-suppressed",
  @"No question could be shown at that moment, so MYbloXX® let the request continue.",@"prompt-unavailable",
  @"You allowed it. The request was passed on to iOS. MYbloXX® can’t tell whether the other app opened.",@"allowed-released",
  @"You allowed it. The link was sent to iOS again. MYbloXX® can’t tell whether the other app opened.",@"allowed-reopened",
  @"You allowed it and the permission is saved. Tap the link again.",@"allowed-reopen-failed",
  @"You allowed it and the permission is saved. Tap the link again.",@"permission-saved",
  @"You allowed this route from the history. Tap the original link again.",@"permission-saved-history",
  @"You chose Allow, but MYbloXX® could not open its permissions file, so nothing was allowed.",@"save-failed-access",
  @"You chose Allow, but the permission could not be written, so nothing was allowed.",@"save-failed-write",
  @"You chose Allow, but the saved permission could not be confirmed, so nothing was allowed.",@"save-failed-check",
  @"You chose Allow, but the permission could not be saved, so nothing was allowed.",@"save-failed",nil];
 NSString *base=[reason isKindOfClass:NSString.class]?reason:@"";
 if([base hasPrefix:@"permission-saved-history"])base=@"permission-saved-history";
 else if([base hasPrefix:@"permission-saved"])base=@"permission-saved";
 if([base isEqual:@"allowed-and-released"])base=@"allowed-released";if([base isEqual:@"allowed-and-reopened"])base=@"allowed-reopened";if([base hasPrefix:@"allowed-no-url"])base=@"permission-saved";
 NSString *text=[t objectForKey:base];return text?:@"Blocked by MYbloXX®.";
}
// The permission kinds the redirect screens handle. Popups and websites never appear in them.
static inline BOOL MYBRedirectKindIsRedirect(NSString *kind){return [kind isEqual:@"appstore"]||[kind isEqual:@"appredirect"];}

// ---- the single combined switch of earlier releases (kept only so its tests and older callers still compile) --------------------
// Settings no longer shows or writes it: the two switches above are independent. It still describes what the older keys meant.
typedef NS_ENUM(NSInteger,MYBRedirectProtection){MYBRedirectProtectionOff=0,MYBRedirectProtectionOn,MYBRedirectProtectionAppStoreOnly};
static inline MYBRedirectProtection MYBRedirectProtectionState(NSDictionary *settings){
 if(!MYBRedirectLegacyStore(settings))return MYBRedirectProtectionOff;
 return [[settings objectForKey:@"RedirectOtherApps"] boolValue]?MYBRedirectProtectionOn:MYBRedirectProtectionAppStoreOnly;
}
static inline void MYBRedirectProtectionApply(NSMutableDictionary *settings,BOOL on){[settings setObject:@(on) forKey:@"RedirectEnabled"];[settings setObject:@(on) forKey:@"RedirectOtherApps"];}
