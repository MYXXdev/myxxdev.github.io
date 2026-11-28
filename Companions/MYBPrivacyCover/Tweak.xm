#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <notify.h>
#import <objc/runtime.h>
#import <roothide.h>
#import "../../Shared/MYBAppLockState.h"
#import "../../Shared/MYBConnectivity.h"
#import "../../Shared/MYBShieldTheme.h"
#import "../../Shared/MYBShieldMark.h"

// MYbloXX® App Lock and Private Previews. The helper writes a filter naming only the chosen apps; it loads this in UIKit apps, but the first thing it does is leave unless THIS app is one the person selected
// (and is not Settings, a phone or emergency interface, a system service or a recovery app: see MYBLockEligible). In a selected app it puts an opaque MYbloXX®
// cover over the app's own windows: on first launch, whenever the app leaves the screen (so the app switcher snapshot shows the cover), and, for App Lock,
// until Face ID or the device passcode (only if the person allowed that) succeeds for THIS visit. No passcode or biometric data is read, kept or logged.
static NSString *PrefsFile(void){return MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.applock.plist");}
static NSString *ProbeFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/AppLockProbe.plist");}
static BOOL LockMode,MaskMode,PasscodeFallback;
static MYBLockState State;
static BOOL Prompted;              // this visit already asked once: a cancel shows the Unlock button instead of asking again in a loop
static BOOL Left;                  // the app really left the screen (not just a system prompt or Control Center): the next activation is a new visit
static NSString *AppName;
static LAContext *Context;
static UIView *Cover;              // one cover per window, tracked by tag
static const NSInteger kCoverTag=0x4D59;

static NSDictionary *Config(void){return [NSDictionary dictionaryWithContentsOfFile:PrefsFile()]?:@{};}
static BOOL Paused(NSDictionary *c){id v=c[@"AppLockPausedUntil"];return [v isKindOfClass:NSNumber.class]&&[v doubleValue]>NSDate.date.timeIntervalSince1970;}
static void Probe(NSString *key,id value){
 // Best effort evidence for MYbloXX Settings. A sandboxed app may not be allowed to write here; that is fine and silent.
 NSString *file=ProbeFile();NSMutableDictionary *all=[[NSDictionary dictionaryWithContentsOfFile:file] mutableCopy]?:[NSMutableDictionary dictionary];
 NSString *bundle=NSBundle.mainBundle.bundleIdentifier;NSMutableDictionary *entry=[all[bundle] mutableCopy]?:[NSMutableDictionary dictionary];
 entry[key]=value;entry[@"time"]=@(NSDate.date.timeIntervalSince1970);all[bundle]=entry;
 [NSFileManager.defaultManager createDirectoryAtPath:file.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];[all writeToFile:file atomically:YES];
}

// Same look as every other MYbloXX® cover (Private Calls, Private Conversations, Private Album): a System Thick Material Dark blur with a 30% black
// tint over whatever was on screen, and the brand mark centered on it -- not a flat colour, not a system SF Symbol lock, not a one-off purple. App
// Lock's cover also has to double as the unlock screen (the others never show anything on top, since they only hide a backgrounding snapshot after
// access is already granted), so a name label, status line and Unlock button sit over that same background, styled with the same accent and type
// the rest of MYbloXX® uses, so a person moving between a locked app, Private Calls and Private Conversations sees one consistent look throughout.
@interface MYXXCoverView:UIView
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIButton *unlock;
@end
@implementation MYXXCoverView
- (instancetype)initWithFrame:(CGRect)frame{
 self=[super initWithFrame:frame];self.tag=kCoverTag;self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.opaque=YES;
 self.backgroundColor=MYBShieldBackground();
 UIVisualEffectView *blur=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];
 blur.frame=self.bounds;blur.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
 UIView *tint=[[UIView alloc] initWithFrame:blur.bounds];tint.backgroundColor=[UIColor colorWithWhite:0 alpha:0.30];tint.autoresizingMask=blur.autoresizingMask;
 [blur.contentView addSubview:tint];
 [self addSubview:blur];
 UIImageView *mark=[[UIImageView alloc] initWithImage:MYBShieldMarkImage()];mark.contentMode=UIViewContentModeScaleAspectFit;
 UILabel *name=[UILabel new];name.text=AppName.length?AppName:@"Protected";name.font=[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];name.textColor=UIColor.whiteColor;name.textAlignment=NSTextAlignmentCenter;
 self.status=[UILabel new];self.status.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];self.status.textColor=MYBShieldMuted();self.status.numberOfLines=0;self.status.textAlignment=NSTextAlignmentCenter;self.status.adjustsFontForContentSizeCategory=YES;
 UIButtonConfiguration *config=[UIButtonConfiguration filledButtonConfiguration];config.title=@"Unlock";config.baseForegroundColor=MYBShieldBackground();config.baseBackgroundColor=MYBShieldAccent();config.cornerStyle=UIButtonConfigurationCornerStyleLarge;config.contentInsets=NSDirectionalEdgeInsetsMake(12,28,12,28);
 self.unlock=[UIButton buttonWithConfiguration:config primaryAction:nil];self.unlock.hidden=YES;
 UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[mark,name,self.status,self.unlock]];stack.axis=UILayoutConstraintAxisVertical;stack.alignment=UIStackViewAlignmentCenter;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=NO;
 [self addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[
  [mark.widthAnchor constraintEqualToConstant:84],[mark.heightAnchor constraintEqualToConstant:84],
  [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],[stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
  [stack.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-64]]];
 return self;
}
@end

static BOOL RealWindow(UIWindow *window){
 NSString *name=NSStringFromClass(window.class);
 return ![name containsString:@"TextEffects"]&&![name containsString:@"Keyboard"]&&![name containsString:@"StatusBar"]&&![name containsString:@"RemoteInput"];
}
static NSArray<UIWindow *> *AppWindows(void){
 NSMutableArray *out=[NSMutableArray array];
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)if([scene isKindOfClass:UIWindowScene.class])for(UIWindow *w in ((UIWindowScene *)scene).windows)if(RealWindow(w))[out addObject:w];
 return out;
}
static MYXXCoverView *CoverIn(UIWindow *window){UIView *v=[window viewWithTag:kCoverTag];return [v isKindOfClass:MYXXCoverView.class]?(MYXXCoverView *)v:nil;}
static void Cover_(UIWindow *window){
 if(!RealWindow(window))return;MYXXCoverView *cover=CoverIn(window);
 if(!cover){cover=[[MYXXCoverView alloc] initWithFrame:window.bounds];[window addSubview:cover];}
 [window bringSubviewToFront:cover];
}
static void CoverAll(void){for(UIWindow *w in AppWindows())Cover_(w);}
static void UncoverAll(void){for(UIWindow *w in AppWindows())[CoverIn(w) removeFromSuperview];}
static void Say(NSString *text,BOOL showUnlock){for(UIWindow *w in AppWindows()){MYXXCoverView *c=CoverIn(w);c.status.text=text;c.unlock.hidden=!showUnlock;}}
// Some locked apps declare NSFaceIDUsageDescription themselves and some don't; when one doesn't, LocalAuthentication either refuses the combined
// policy's biometric half outright (passcode-fallback off) or silently skips straight to the passcode sheet (fallback on) -- in both cases Face ID
// never actually shows, for a reason that has nothing to do with the person's settings. Supplying the missing string for this one process only
// fixes that the same way Private Calls and Private Conversations already do (PrivateUI.m).
static void MYXXEnsureFaceIDDescription(void){
 static dispatch_once_t once;
 dispatch_once(&once,^{
  NSString *reason=@"Confirm it's you to open this.";
  Method objectForKey=class_getInstanceMethod(NSBundle.class,@selector(objectForInfoDictionaryKey:));
  if(objectForKey){
   IMP orig=method_getImplementation(objectForKey);
   IMP replacement=imp_implementationWithBlock(^id(NSBundle *self_,NSString *key){
    id value=((id (*)(id,SEL,id))orig)(self_,@selector(objectForInfoDictionaryKey:),key);
    if(!value&&self_==NSBundle.mainBundle&&[key isEqualToString:@"NSFaceIDUsageDescription"])return reason;
    return value;
   });
   method_setImplementation(objectForKey,replacement);
  }
  Method infoDict=class_getInstanceMethod(NSBundle.class,@selector(infoDictionary));
  if(infoDict){
   IMP orig=method_getImplementation(infoDict);
   IMP replacement=imp_implementationWithBlock(^NSDictionary *(NSBundle *self_){
    NSDictionary *value=((NSDictionary * (*)(id,SEL))orig)(self_,@selector(infoDictionary));
    if(self_==NSBundle.mainBundle&&!value[@"NSFaceIDUsageDescription"]){
     NSMutableDictionary *merged=[NSMutableDictionary dictionaryWithDictionary:value?:@{}];merged[@"NSFaceIDUsageDescription"]=reason;return merged;
    }
    return value;
   });
   method_setImplementation(infoDict,replacement);
  }
 });
}
static void StartPrompt(void);
static void WireButtons(void){for(UIWindow *w in AppWindows()){MYXXCoverView *c=CoverIn(w);[c.unlock removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];[c.unlock addAction:[UIAction actionWithHandler:^(UIAction *a){(void)a;StartPrompt();}] forControlEvents:UIControlEventTouchUpInside];}}
static void StartPrompt(void){
 if(!LockMode||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
 unsigned long ticket=MYBLockBeginPrompt(&State);if(!ticket)return;     // already showing, or already unlocked
 Prompted=YES;
 MYXXEnsureFaceIDDescription();
 LAContext *context=[LAContext new];Context=context;
 LAPolicy policy=PasscodeFallback?LAPolicyDeviceOwnerAuthentication:LAPolicyDeviceOwnerAuthenticationWithBiometrics;
 if(!PasscodeFallback)context.localizedFallbackTitle=@"";
 NSError *probe=nil;
 if(![context canEvaluatePolicy:policy error:&probe]){
  MYBLockFinish(&State,ticket,0);Context=nil;Probe(@"lastCode",@(probe.code));
  Say(PasscodeFallback?[NSString stringWithFormat:@"Couldn’t ask for your passcode here (code %ld). Open MYbloXX Settings and turn off App Lock for this app.",(long)probe.code]
                      :[NSString stringWithFormat:@"Face ID isn’t available for this app (code %ld). Allow the device passcode in MYbloXX Settings, or turn off App Lock for this app.",(long)probe.code],YES);
  return;
 }
 Say(@"Unlock to continue",NO);
 [context evaluatePolicy:policy localizedReason:[NSString stringWithFormat:@"Unlock %@",AppName.length?AppName:@"this app"] reply:^(BOOL success,NSError *error){
  dispatch_async(dispatch_get_main_queue(),^{
   BOOL opened=MYBLockFinish(&State,ticket,success);               // a stale or cancelled result changes nothing
   if(opened){Context=nil;UncoverAll();Probe(@"lastCode",@0);return;}
   if(ticket!=State.prompt&&!State.authenticating&&MYBLockIsOpen(&State))return;
   if(!success){Probe(@"lastCode",@(error.code));Say(error.code==LAErrorUserCancel||error.code==LAErrorAppCancel||error.code==LAErrorSystemCancel?@"Locked. Tap Unlock to try again.":[NSString stringWithFormat:@"Couldn’t unlock (code %ld). Tap Unlock to try again.",(long)error.code],YES);}
  });
 }];
}
// A new visit: always locked first, then ask. Never skips the cover.
static void BeginVisit(void){
 NSDictionary *config=Config();
 if(!LockMode||Paused(config)||!MYBConnFlag(config,@"AppLockEnabled")){UncoverAll();return;}
 MYBLockActivate(&State);Prompted=NO;CoverAll();WireButtons();Say(@"Unlock to continue",NO);StartPrompt();
}
static void EndVisit(void){
 [Context invalidate];Context=nil;Prompted=NO;MYBLockLeave(&State);if(LockMode)CoverAll();
}
%hook UIWindow
- (void)makeKeyAndVisible{
 %orig;
 if(LockMode&&MYBLockIsOpen(&State)==0)Cover_(self);       // locked: the first frame already carries the cover
}
- (void)didAddSubview:(UIView *)subview{
 %orig;
 UIView *cover=[self viewWithTag:kCoverTag];if(cover&&subview!=cover)[self bringSubviewToFront:cover];
}
%end
%ctor {
 NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
 if(!bundle.length||!MYBLockEligible(bundle))return;                                         // Settings, phone, system and recovery apps: never touched
 if(NSProcessInfo.processInfo.operatingSystemVersion.majorVersion!=16)return;             // verified target only
 NSDictionary *config=Config();
 BOOL lockApp=MYBConnFlag(config,@"AppLockEnabled")&&[config[@"AppLockApps"] isKindOfClass:NSArray.class]&&[config[@"AppLockApps"] containsObject:bundle];
 BOOL maskApp=[config[@"AppLockPreviewApps"] isKindOfClass:NSArray.class]&&[config[@"AppLockPreviewApps"] containsObject:bundle];
 if(!lockApp&&!maskApp)return;                                                              // not selected: nothing is loaded, nothing is hooked
 LockMode=lockApp;MaskMode=maskApp||lockApp;PasscodeFallback=MYBConnFlag(config,@"AppLockPasscodeFallback");State=MYBLockInit();
 AppName=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]?:[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleName"];
 %init;
 Probe(@"loaded",@YES);Probe(@"mode",lockApp?@"lock":@"mask");
 NSNotificationCenter *center=NSNotificationCenter.defaultCenter;NSOperationQueue *main=NSOperationQueue.mainQueue;
 [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:main usingBlock:^(NSNotification *n){(void)n;if(MaskMode&&!State.authenticating)CoverAll();}];   // before the switcher snapshot
 [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:main usingBlock:^(NSNotification *n){(void)n;Left=YES;if(LockMode)EndVisit();else if(MaskMode)CoverAll();}];
 [center addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable object:nil queue:main usingBlock:^(NSNotification *n){(void)n;if(LockMode)EndVisit();else if(MaskMode)CoverAll();}];
 [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:main usingBlock:^(NSNotification *n){
  (void)n;
  if(LockMode){if(Left){Left=NO;BeginVisit();}else if(!Prompted&&!MYBLockIsOpen(&State)&&!State.authenticating)StartPrompt();}
  else if(MaskMode){Left=NO;UncoverAll();}
 }];
 static int token=0;
 notify_register_dispatch("com.apple.springboard.lockstate",&token,dispatch_get_main_queue(),^(int t){(void)t;if(LockMode)EndVisit();else if(MaskMode)CoverAll();});   // the device locked
 dispatch_async(dispatch_get_main_queue(),^{if(LockMode)BeginVisit();});
}
