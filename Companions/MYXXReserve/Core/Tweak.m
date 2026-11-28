// MYXX Reserve — SpringBoard core.
// Original code by MYXXdev. Behaviour modelled on Sentinel 1.3.2 (power path,
// recovery) and Reverie 2.4.1 (wake-source blocking, timed button window),
// re-implemented for iOS 16.5.1 / Dopamine RootHide.
//
// Rules this file follows:
//  * Activation/recovery always use the TRUE battery level. Spoofing lives
//    only in the Display dylib.
//  * Every persistent setting we touch is journaled BEFORE we touch it, and
//    only what we changed is restored (also after a respring or crash).
//  * Every request gets a visible acknowledgement; nothing silently returns.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#import <spawn.h>
#import <mach/mach.h>
#import <sys/wait.h>
#import <dlfcn.h>
#import <roothide.h>
#import "../Shared/RSVShared.h"
#import "../Shared/RSVHook.h"

extern char **environ;

// ---------------------------------------------------------------------------
// Private API signatures (resolved at runtime; every call is guarded)
@interface NSObject (RSVPrivate)
+ (id)sharedInstance;
+ (id)sharedController;
+ (id)batterySaver;
+ (id)serviceForClientIdentifier:(NSString *)identifier;
+ (id)userRequestedAssertionDetailsWithIdentifier:(NSString *)i modeIdentifier:(NSString *)m lifetime:(id)l;
- (void)_simulateLockButtonPress;
- (BOOL)isOnAC;
- (BOOL)isInAirplaneMode;
- (void)setInAirplaneMode:(BOOL)on;
- (long long)getPowerMode;
- (BOOL)setPowerMode:(long long)mode error:(NSError **)err;
- (void)setBiometricAutoUnlockingDisabled:(BOOL)d forReason:(NSString *)r;
- (void)_stopObservingIfNecessary;
- (void)_startObservingIfNecessary;
- (id)takeModeAssertionWithDetails:(id)details error:(NSError **)err;
- (BOOL)invalidateAllActiveModeAssertionsWithError:(NSError **)err;
- (BOOL)screenIsOn;
@end

typedef int (*MRSendCommandFn)(int command, CFDictionaryRef options);

// ---------------------------------------------------------------------------
// State
typedef NS_ENUM(NSInteger, RSVState) {
    RSVStateIdle = 0,
    RSVStateQuickTest,
    RSVStateActive,       // real reserve (auto, manual or full test)
    RSVStateRecovering,
};

static RSVState gState = RSVStateIdle;
static BOOL gIsFullTest = NO;
static __weak UIWindow *gRootWindow = nil;
static UIView *gOverlay = nil;
static dispatch_source_t gResleepTimer = NULL;
static dispatch_source_t gSafetyTimer = NULL;
static NSMutableArray<NSNumber *> *gVolumePresses = nil;
static NSMutableArray<NSString *> *gMissingHooks = nil;
static BOOL gDidFinishLaunching = NO;
static int gSBToken = 0, gDispCfgToken = 0, gReqToken = 0, gThrottleToken = 0;
static uint32_t gLastNonce = 0;
static NSTimeInterval gLastHelperSleep = 0;

// ---------------------------------------------------------------------------
// Preferences (CFPreferences — works the same under RootHide's cfprefsd)
static CFStringRef kDomain, kStatusDomain, kJournalDomain;

static id RSVPref(NSString *key, id dflt) {
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, kDomain);
    id obj = v ? (__bridge_transfer id)v : nil;
    return obj ?: dflt;
}
static BOOL RSVPrefBool(NSString *key, BOOL dflt) { id v = RSVPref(key, nil); return v ? [v boolValue] : dflt; }
static NSInteger RSVPrefInt(NSString *key, NSInteger dflt) { id v = RSVPref(key, nil); return v ? [v integerValue] : dflt; }

static BOOL RSVEnabled(void)        { return RSVPrefBool(@"enabled", YES); }
static BOOL RSVAutoEnter(void)      { return RSVPrefBool(@"autoEnter", YES); }
static int  RSVThreshold(void)      { NSInteger t = RSVPrefInt(@"threshold", 3); return (int)MAX(1, MIN(20, t)); }
static BOOL RSVSpoof(void)          { return RSVPrefBool(@"spoofPercent", NO); }
static BOOL RSVUseLPM(void)         { return RSVPrefBool(@"lowPowerMode", YES); }
static BOOL RSVUseFocus(void)       { return RSVPrefBool(@"silenceFocus", YES); }
static BOOL RSVPauseMedia(void)     { return RSVPrefBool(@"pauseMedia", YES); }
static BOOL RSVBlockWakes(void)     { return RSVPrefBool(@"blockWakes", YES); }
static BOOL RSVRadioIsolation(void) { return RSVPrefBool(@"radioIsolation", NO); }   // off by default
static BOOL RSVThrottleCPU(void)    { return RSVPrefBool(@"throttleCPU", NO); }
static NSInteger RSVRearmMinutes(void) { return MAX(0, MIN(120, RSVPrefInt(@"rearmMinutes", 10))); }

// Journal / status helpers
static id RSVJournalGet(NSString *key) {
    CFPreferencesAppSynchronize(kJournalDomain);
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key, kJournalDomain);
    return v ? (__bridge_transfer id)v : nil;
}
static void RSVJournalSet(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, kJournalDomain);
    CFPreferencesAppSynchronize(kJournalDomain);   // must hit disk before the mutation it guards
}

static void RSVStatusText(NSString *key, NSString *text) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)text, kStatusDomain);
    CFPreferencesAppSynchronize(kStatusDomain);
}

static void RSVLog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void RSVLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[MYXXReserve] %@", s);
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"HH:mm:ss";
    RSVStatusText(@"lastEvent", [NSString stringWithFormat:@"%@ — %@", [df stringFromDate:[NSDate date]], s]);
}

static void RSVSignal(uint8_t code, uint8_t detail) {
    if (!gSBToken) notify_register_check(RSV_N_SB_STATE, &gSBToken);
    notify_set_state(gSBToken, RSVPackStatus(RSV_BUILD, code, detail, RSVNow()));
    notify_post(RSV_N_SB_STATE);
}

static void RSVPublishDisplayConfig(void) {
    if (!gDispCfgToken) notify_register_check(RSV_N_DISPLAY_CFG, &gDispCfgToken);
    notify_set_state(gDispCfgToken, RSVPackDisplay(RSVEnabled() && RSVSpoof(), RSVThreshold()));
    notify_post(RSV_N_DISPLAY_CFG);
}

// ---------------------------------------------------------------------------
// Battery (true values only)
static float RSVTrueLevel(void) {
    UIDevice *d = [UIDevice currentDevice];
    if (!d.batteryMonitoringEnabled) d.batteryMonitoringEnabled = YES;
    return d.batteryLevel;
}

static BOOL RSVOnPower(void) {
    id ui = [objc_getClass("SBUIController") sharedInstance];
    if (ui && [ui respondsToSelector:@selector(isOnAC)]) return [ui isOnAC];   // what Sentinel uses
    UIDeviceBatteryState s = [UIDevice currentDevice].batteryState;
    return s == UIDeviceBatteryStateCharging || s == UIDeviceBatteryStateFull;
}

// ---------------------------------------------------------------------------
// Helper process
typedef void (^RSVHelperDone)(int exitCode);

static NSString *RSVHelperPath(void) {
    return jbroot(@"/usr/libexec/myxxreserved");
}

static BOOL RSVRunHelper(NSString *mode, RSVHelperDone done) {
    NSString *path = RSVHelperPath();
    const char *cpath = path.fileSystemRepresentation;
    char *argv[] = { (char *)"myxxreserved", (char *)mode.UTF8String, NULL };
    pid_t pid = 0;
    int rc = posix_spawn(&pid, cpath, NULL, NULL, argv, environ);
    if (rc != 0) {
        RSVLog(@"Could not start the power helper (%s, error %d) at %@", strerror(rc), rc, path);
        RSVSignal(RSVSBFailHelperLaunch, (uint8_t)rc);
        if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(-1); });
        return NO;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int status = 0;
        int code = -1;
        if (waitpid(pid, &status, 0) == pid) {
            if (WIFEXITED(status)) code = WEXITSTATUS(status);
            else if (WIFSIGNALED(status)) code = 128 + WTERMSIG(status);
        }
        if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(code); });
    });
    return YES;
}

// ---------------------------------------------------------------------------
// Second power route: request sleep from inside SpringBoard itself (the route
// Reverie uses). Used only when the helper is refused or cannot start, so a
// failure of one route never leaves the phone awake on the black screen.
typedef mach_port_t rsv_io_t;
extern const mach_port_t kIOMasterPortDefault;
extern CFMutableDictionaryRef IOServiceMatching(const char *name);
extern rsv_io_t IOServiceGetMatchingService(mach_port_t mainPort, CFDictionaryRef matching);
extern kern_return_t IOServiceOpen(rsv_io_t service, mach_port_t owningTask, uint32_t type, rsv_io_t *connect);
extern kern_return_t IOServiceClose(rsv_io_t connect);
extern kern_return_t IOObjectRelease(rsv_io_t object);
extern int IOPMSleepSystem(rsv_io_t fb);

// Returns 0 on success; otherwise the kernel/IOKit code from the step that failed.
static uint32_t RSVSpringBoardPower(BOOL reallySleep) {
    rsv_io_t svc = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"));
    if (!svc) return 0xE00002F0;   // kIOReturnNotFound
    rsv_io_t fb = 0;
    kern_return_t ko = IOServiceOpen(svc, mach_task_self(), 0, &fb);
    IOObjectRelease(svc);
    if (ko != KERN_SUCCESS || !fb) return ko ? (uint32_t)ko : 0xE00002BC;
    int kr = reallySleep ? IOPMSleepSystem(fb) : 0;
    IOServiceClose(fb);
    return (uint32_t)kr;
}

static NSString *RSVHelperExitText(int code) {
    switch (code) {
        case RSVExitOK: return @"OK";
        case RSVExitNoRootDomain: return @"power root domain not found";
        case RSVExitNoPMConnect: return @"power-management connection refused";
        case RSVExitSleepError: return @"sleep request was rejected by iOS";
        case RSVExitNoBackboardd: return @"backboardd not found";
        case RSVExitBadArgs: return @"bad arguments";
        case -1: return @"helper did not start";
        default: return [NSString stringWithFormat:@"exit %d", code];
    }
}

// ---------------------------------------------------------------------------
// Overlay (Sentinel puts its black view on UIRootSceneWindow; we do the same,
// capturing that window via its -setFrame: exactly as the baseline does)
static UIView *RSVMakeOverlay(CGRect bounds, BOOL test) {
    UIView *v = [[UIView alloc] initWithFrame:bounds];
    v.backgroundColor = UIColor.blackColor;
    v.userInteractionEnabled = YES;           // swallow touches
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UILabel *l = [UILabel new];
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [UIColor colorWithWhite:1 alpha:0.35];
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    l.text = test ? @"MYXX Reserve test\nEnds by itself, or press Volume Up 3 times"
                  : @"MYXX Reserve\nPlug in power or press Volume Up 3 times";
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:l];
    [NSLayoutConstraint activateConstraints:@[
        [l.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [l.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-80],
        [l.widthAnchor constraintLessThanOrEqualToAnchor:v.widthAnchor constant:-40],
    ]];
    return v;
}

static UIWindow *RSVFindHostWindow(void) {
    UIWindow *w = gRootWindow;
    if (w) return w;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *win in ((UIWindowScene *)scene).windows)
            if ([win isKindOfClass:objc_getClass("UIRootSceneWindow")]) return win;
    }
    return nil;
}

static BOOL RSVShowOverlay(BOOL test) {
    if (gOverlay) return YES;
    UIWindow *host = RSVFindHostWindow();
    if (!host) {
        RSVLog(@"Could not find the root screen window for the black overlay");
        RSVSignal(RSVSBFailOverlay, 0);
        return NO;
    }
    gOverlay = RSVMakeOverlay(host.bounds, test);
    [host addSubview:gOverlay];
    [host bringSubviewToFront:gOverlay];
    return YES;
}

static void RSVHideOverlay(void) {
    [gOverlay removeFromSuperview];
    gOverlay = nil;
}

// ---------------------------------------------------------------------------
// Persistent-setting changes (journaled)
static NSString *const kDNDClient = @"com.myxxdev.reserve";

static void RSVSetLPM(BOOL on, NSError **err) {
    id saver = [objc_getClass("_CDBatterySaver") batterySaver];
    if ([saver respondsToSelector:@selector(setPowerMode:error:)]) [saver setPowerMode:on ? 1 : 0 error:err];
}
static BOOL RSVLPMIsOn(BOOL *known) {
    id saver = [objc_getClass("_CDBatterySaver") batterySaver];
    if (![saver respondsToSelector:@selector(getPowerMode)]) { if (known) *known = NO; return NO; }
    if (known) *known = YES;
    return [saver getPowerMode] != 0;
}
static id RSVAirplane(void) { return [objc_getClass("SBAirplaneModeController") sharedInstance]; }
static id RSVDNDService(void) {
    Class c = objc_getClass("DNDModeAssertionService");
    if (!c) { dlopen("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb", RTLD_LAZY); c = objc_getClass("DNDModeAssertionService"); }
    return [c respondsToSelector:@selector(serviceForClientIdentifier:)] ? [c serviceForClientIdentifier:kDNDClient] : nil;
}

static void RSVSetThrottle(BOOL on) {
    if (!gThrottleToken) notify_register_check(RSV_N_THROTTLE, &gThrottleToken);
    notify_set_state(gThrottleToken, on ? 1 : 0);
    notify_post(RSV_N_THROTTLE);
}

// Apply reserve-side changes. Each one: record intent -> mutate -> record outcome.
static void RSVApplyChanges(NSMutableArray<NSString *> *notes) {
    if (RSVUseLPM()) {
        BOOL known = NO;
        BOOL wasOn = RSVLPMIsOn(&known);
        if (!known) [notes addObject:@"Low Power Mode: not available"];
        else if (!wasOn) {
            // Recorded before the change. The switch may apply asynchronously, so
            // it is not re-read here; restoring "off" is correct either way
            // because it was off before we started.
            RSVJournalSet(@"changedLPM", @YES);
            NSError *e = nil;
            RSVSetLPM(YES, &e);
            [notes addObject:e ? [NSString stringWithFormat:@"Low Power Mode: error %@", e.localizedDescription] : @"Low Power Mode: turned on"];
        } else [notes addObject:@"Low Power Mode: already on (left alone)"];
    }
    if (RSVRadioIsolation()) {
        id ap = RSVAirplane();
        if ([ap respondsToSelector:@selector(isInAirplaneMode)] && [ap respondsToSelector:@selector(setInAirplaneMode:)]) {
            if (![ap isInAirplaneMode]) {
                RSVJournalSet(@"changedAirplane", @YES);
                [ap setInAirplaneMode:YES];
                [notes addObject:@"Airplane Mode: turned on"];
            } else [notes addObject:@"Airplane Mode: already on (left alone)"];
        } else [notes addObject:@"Airplane Mode: not available"];
    }
    if (RSVUseFocus()) {
        id svc = RSVDNDService();
        Class detailsCls = objc_getClass("DNDModeAssertionDetails");
        if (svc && [detailsCls respondsToSelector:@selector(userRequestedAssertionDetailsWithIdentifier:modeIdentifier:lifetime:)]) {
            RSVJournalSet(@"changedFocus", @YES);
            id details = [detailsCls userRequestedAssertionDetailsWithIdentifier:@"com.myxxdev.reserve.assertion"
                                                                   modeIdentifier:@"com.apple.donotdisturb.mode.default"
                                                                         lifetime:nil];
            NSError *e = nil;
            id a = [svc takeModeAssertionWithDetails:details error:&e];
            if (!a) { RSVJournalSet(@"changedFocus", @NO); [notes addObject:[NSString stringWithFormat:@"Do Not Disturb: skipped (%@)", e.localizedDescription ?: @"no assertion"]]; }
            else [notes addObject:@"Do Not Disturb: on (MYXX Reserve's own assertion)"];
        } else [notes addObject:@"Do Not Disturb: not available"];
    }
    if (RSVThrottleCPU()) {
        RSVJournalSet(@"changedThrottle", @YES);
        RSVSetThrottle(YES);
        [notes addObject:@"CPU slowdown: requested (see thermal status)"];
    }
}

// Restore ONLY what the journal says we changed. Safe to call repeatedly.
static void RSVRestoreChanges(NSMutableArray<NSString *> *notes) {
    if ([RSVJournalGet(@"changedThrottle") boolValue]) {
        RSVSetThrottle(NO);
        RSVJournalSet(@"changedThrottle", @NO);
        [notes addObject:@"CPU slowdown: off"];
    }
    if ([RSVJournalGet(@"changedFocus") boolValue]) {
        id svc = RSVDNDService();
        NSError *e = nil;
        if ([svc respondsToSelector:@selector(invalidateAllActiveModeAssertionsWithError:)])
            [svc invalidateAllActiveModeAssertionsWithError:&e];   // only assertions of OUR client id
        RSVJournalSet(@"changedFocus", @NO);
        [notes addObject:@"Do Not Disturb: MYXX Reserve assertion removed"];
    }
    if ([RSVJournalGet(@"changedAirplane") boolValue]) {
        id ap = RSVAirplane();
        if ([ap respondsToSelector:@selector(setInAirplaneMode:)]) [ap setInAirplaneMode:NO];
        RSVJournalSet(@"changedAirplane", @NO);
        [notes addObject:@"Airplane Mode: turned back off"];
    }
    if ([RSVJournalGet(@"changedLPM") boolValue]) {
        RSVSetLPM(NO, NULL);
        RSVJournalSet(@"changedLPM", @NO);
        [notes addObject:@"Low Power Mode: turned back off"];
    }
}

// In-memory, non-persistent changes (lost on respring anyway)
static void RSVApplySessionChanges(void) {
    id lsm = [objc_getClass("SBLockScreenManager") sharedInstance];
    if ([lsm respondsToSelector:@selector(setBiometricAutoUnlockingDisabled:forReason:)])
        [lsm setBiometricAutoUnlockingDisabled:YES forReason:@"com.myxxdev.reserve"];
    if (RSVBlockWakes()) {
        id lift = [objc_getClass("SBLiftToWakeController") sharedController];
        if ([lift respondsToSelector:@selector(_stopObservingIfNecessary)]) [lift _stopObservingIfNecessary];
    }
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
}
static void RSVRestoreSessionChanges(void) {
    id lsm = [objc_getClass("SBLockScreenManager") sharedInstance];
    if ([lsm respondsToSelector:@selector(setBiometricAutoUnlockingDisabled:forReason:)])
        [lsm setBiometricAutoUnlockingDisabled:NO forReason:@"com.myxxdev.reserve"];
    id lift = [objc_getClass("SBLiftToWakeController") sharedController];
    if ([lift respondsToSelector:@selector(_startObservingIfNecessary)]) [lift _startObservingIfNecessary];
}

// ---------------------------------------------------------------------------
// Timers
static void RSVCancelTimer(dispatch_source_t __strong *t) {
    if (*t) { dispatch_source_cancel(*t); *t = NULL; }
}

static void RSVRequestSleep(void);

static void RSVStartResleepTimer(void) {
    RSVCancelTimer(&gResleepTimer);
    gResleepTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    // Timers do not run while the system sleeps, so this only fires after
    // something woke the phone and nobody recovered: go back to sleep.
    dispatch_source_set_timer(gResleepTimer, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), 60 * NSEC_PER_SEC, 10 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(gResleepTimer, ^{
        if (gState == RSVStateActive && !RSVOnPower()) RSVRequestSleep();
    });
    dispatch_resume(gResleepTimer);
}

// ---------------------------------------------------------------------------
// Enter / exit
static void RSVRecover(NSString *reason, BOOL respring);

static void RSVRequestSleep(void) {
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    if (now - gLastHelperSleep < 20) return;   // de-duplicate bursts
    gLastHelperSleep = now;
    void (^fallback)(int) = ^(int helperCode) {
        if (gState != RSVStateActive) return;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            uint32_t kr = RSVSpringBoardPower(YES);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (gState != RSVStateActive) return;
                if (kr == 0) {
                    RSVSignal(RSVSBSleepRequested, 1);
                    RSVLog(@"Sleep requested by SpringBoard (helper: %@)", RSVHelperExitText(helperCode));
                } else {
                    RSVSignal(RSVSBFailSleep, (uint8_t)(helperCode < 0 ? 0xff : helperCode));
                    RSVLog(@"Sleep request failed on both routes: helper %@, SpringBoard 0x%08x — screen stays dark, recovery still works",
                           RSVHelperExitText(helperCode), kr);
                }
            });
        });
    };
    BOOL started = RSVRunHelper(@"sleep", ^(int code) {
        if (gState != RSVStateActive) return;
        if (code == RSVExitOK) {
            RSVSignal(RSVSBSleepRequested, 0);
            RSVLog(@"Sleep requested successfully (helper OK)");
        } else if (code != RSVExitSleepError) {
            // Helper could not reach power management: try the SpringBoard route.
            fallback(code);
        } else {
            RSVSignal(RSVSBFailSleep, (uint8_t)code);
            RSVLog(@"Sleep request failed: %@ — screen stays dark, recovery still works", RSVHelperExitText(code));
        }
    });
    if (!started) fallback(-1);
}

static void RSVEnter(NSString *kind, BOOL fullTest) {
    if (gState != RSVStateIdle) {
        RSVSignal(RSVSBBusy, (uint8_t)gState);
        RSVLog(@"Ignored '%@': reserve or a test is already running", kind);
        return;
    }
    gState = RSVStateActive;
    gIsFullTest = fullTest;
    gVolumePresses = [NSMutableArray new];
    RSVSignal(RSVSBEntering, fullTest ? 1 : 0);

    // Journal first: if SpringBoard dies at any point below, the next launch restores.
    RSVJournalSet(@"active", @YES);
    RSVJournalSet(@"kind", kind);
    RSVJournalSet(@"enteredAt", [NSDate date]);

    BOOL overlayOK = RSVShowOverlay(NO);
    NSMutableArray *notes = [NSMutableArray new];
    RSVApplyChanges(notes);
    RSVApplySessionChanges();
    if (RSVPauseMedia()) {
        MRSendCommandFn send = (MRSendCommandFn)dlsym(RTLD_DEFAULT, "MRMediaRemoteSendCommand");
        if (!send) { dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY); send = (MRSendCommandFn)dlsym(RTLD_DEFAULT, "MRMediaRemoteSendCommand"); }
        if (send) send(1 /* kMRPause */, NULL);
    }
    RSVLog(@"Entering reserve (%@)%@. %@", kind, overlayOK ? @"" : @" WITHOUT overlay", [notes componentsJoinedByString:@"; "]);

    if (fullTest) {
        // Independent escape for tests: wall-clock deadline, checked on every wake.
        RSVCancelTimer(&gSafetyTimer);
        gSafetyTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(gSafetyTimer, dispatch_walltime(NULL, 120 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, NSEC_PER_SEC);
        dispatch_source_set_event_handler(gSafetyTimer, ^{ RSVRecover(@"full test 2-minute safety timer", YES); });
        dispatch_resume(gSafetyTimer);
    }

    // Baseline timing: 1 s later, simulate the lock button, then request sleep.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (gState != RSVStateActive) return;
        id sb = UIApplication.sharedApplication;
        if ([sb respondsToSelector:@selector(_simulateLockButtonPress)]) [sb _simulateLockButtonPress];
        else RSVLog(@"_simulateLockButtonPress unavailable — screen not locked, continuing");
        gLastHelperSleep = 0;
        RSVRequestSleep();
        RSVStartResleepTimer();
    });
}

static void RSVSetRearmLatch(void) {
    RSVJournalSet(@"latchSince", [NSDate date]);
}

static void RSVRecover(NSString *reason, BOOL respring) {
    if (gState != RSVStateActive) return;   // idempotent across duplicate events
    gState = RSVStateRecovering;
    RSVCancelTimer(&gResleepTimer);
    RSVCancelTimer(&gSafetyTimer);

    NSMutableArray *notes = [NSMutableArray new];
    RSVRestoreChanges(notes);
    RSVRestoreSessionChanges();
    RSVHideOverlay();
    BOOL wasTest = gIsFullTest;
    gIsFullTest = NO;
    RSVJournalSet(@"active", @NO);
    if (!RSVOnPower() && !wasTest) RSVSetRearmLatch();

    RSVSignal(RSVSBRecovered, wasTest ? 1 : 0);
    RSVLog(@"Recovered (%@). %@", reason, [notes componentsJoinedByString:@"; "]);

    if (respring) {
        // Sentinel's recovery: restart backboardd so display/HID come back cleanly
        // after a forced system sleep. Our state is already restored above.
        RSVJournalSet(@"respringPending", @YES);
        BOOL started = RSVRunHelper(@"respring", ^(int code) {
            if (code != RSVExitOK) {
                RSVJournalSet(@"respringPending", @NO);
                RSVSignal(RSVSBFailRecovery, (uint8_t)code);
                RSVLog(@"Recovery respring failed: %@ (settings were already restored)", RSVHelperExitText(code));
                gState = RSVStateIdle;
            }
        });
        if (!started) gState = RSVStateIdle;
        // If the respring never takes SpringBoard down, do not stay stuck.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (gState == RSVStateRecovering) {
                gState = RSVStateIdle;
                RSVJournalSet(@"respringPending", @NO);
                RSVSignal(RSVSBFailRecovery, 0xfe);
                RSVLog(@"Recovery respring did not restart SpringBoard; settings are restored — respring manually");
            }
        });
    } else {
        gState = RSVStateIdle;
    }
}

// ---------------------------------------------------------------------------
// Quick test: proves startup, overlay, lock, and helper launch at any charge.
static void RSVQuickTest(void) {
    if (gState != RSVStateIdle) { RSVSignal(RSVSBBusy, (uint8_t)gState); RSVLog(@"Quick test ignored: something is already running"); return; }
    gState = RSVStateQuickTest;
    gVolumePresses = [NSMutableArray new];
    RSVSignal(RSVSBQuickTestRunning, 0);
    BOOL overlayOK = RSVShowOverlay(YES);
    RSVLog(@"Quick test started (overlay %@)", overlayOK ? @"shown" : @"FAILED");

    __block int probeCode = -2;
    __block uint32_t sbProbe = 0xFFFFFFFF;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (gState != RSVStateQuickTest) return;
        id sb = UIApplication.sharedApplication;
        if ([sb respondsToSelector:@selector(_simulateLockButtonPress)]) [sb _simulateLockButtonPress];
        RSVRunHelper(@"probe", ^(int code) { probeCode = code; });
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            uint32_t kr = RSVSpringBoardPower(NO);
            dispatch_async(dispatch_get_main_queue(), ^{ sbProbe = kr; });
        });
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (gState != RSVStateQuickTest) return;
        RSVHideOverlay();
        gState = RSVStateIdle;
        NSString *sbText = sbProbe == 0 ? @"OK" : [NSString stringWithFormat:@"refused 0x%08x", sbProbe];
        NSString *hText = probeCode == -2 ? @"never finished" : RSVHelperExitText(probeCode);
        if (overlayOK && probeCode == RSVExitOK) {
            RSVSignal(RSVSBQuickTestPassed, 0);
            RSVLog(@"Quick test passed: overlay, lock and power helper all worked (SpringBoard route: %@)", sbText);
        } else if (overlayOK && sbProbe == 0) {
            RSVSignal(RSVSBQuickTestPassed, 2);
            RSVLog(@"Quick test passed using the SpringBoard power route (helper: %@)", hText);
        } else {
            RSVSignal(RSVSBFailQuickTest, (uint8_t)(probeCode < 0 ? 0xff : probeCode));
            RSVLog(@"Quick test FAILED: overlay %@, helper %@, SpringBoard route %@", overlayOK ? @"OK" : @"failed", hText, sbText);
        }
    });
}

static void RSVEndQuickTestEarly(void) {
    if (gState != RSVStateQuickTest) return;
    RSVHideOverlay();
    gState = RSVStateIdle;
    RSVSignal(RSVSBQuickTestPassed, 1);
    RSVLog(@"Quick test ended early with Volume Up ×3 (button recovery works)");
}

// ---------------------------------------------------------------------------
// Automatic entry / charger recovery
static BOOL RSVLatchBlocks(int pct, int threshold) {
    NSDate *since = RSVJournalGet(@"latchSince");
    if (![since isKindOfClass:NSDate.class]) return NO;
    NSInteger mins = RSVRearmMinutes();
    BOOL expired = mins > 0 && -[since timeIntervalSinceNow] >= mins * 60.0;
    if (expired || pct > threshold) { RSVJournalSet(@"latchSince", nil); return NO; }
    return YES;
}

static void RSVEvaluateBattery(void) {
    if (!gDidFinishLaunching) return;
    BOOL power = RSVOnPower();
    if (gState == RSVStateActive) {
        if (power) RSVRecover(@"power connected", YES);
        return;
    }
    if (power) { RSVJournalSet(@"latchSince", nil); return; }
    if (gState != RSVStateIdle || !RSVEnabled() || !RSVAutoEnter()) return;
    int pct = RSVPercentFromLevel(RSVTrueLevel());
    int t = RSVThreshold();
    if (pct < 0 || pct > t) return;
    if (RSVLatchBlocks(pct, t)) return;
    RSVEnter(@"automatic", NO);
}

// ---------------------------------------------------------------------------
// Requests from Settings / Control Center
static void RSVHandleRequest(void) {
    uint64_t w = 0;
    if (!gReqToken) notify_register_check(RSV_N_REQUEST, &gReqToken);
    notify_get_state(gReqToken, &w);
    uint32_t nonce = RSVRequestNonce(w);
    uint8_t kind = RSVRequestKind(w);
    if (kind == RSVRequestNone || nonce == gLastNonce) return;   // duplicate delivery
    gLastNonce = nonce;
    RSVSignal(RSVSBRequestReceived, (uint8_t)(nonce & 0xff));   // visible acknowledgement
    RSVStatusText(@"lastAck", [NSString stringWithFormat:@"%u", nonce]); // durable copy for Settings

    if (!gDidFinishLaunching) { RSVLog(@"Request received before SpringBoard finished launching; try again"); return; }
    if ((kind == RSVRequestFullTest || kind == RSVRequestEnterNow) && RSVOnPower()) {
        RSVSignal(RSVSBBusy, 0xfd);
        RSVLog(@"Reserve not started: unplug the charger first (power connected = wake)");
        return;
    }
    switch (kind) {
        case RSVRequestQuickTest: RSVQuickTest(); break;
        case RSVRequestFullTest:  RSVEnter(@"full test", YES); break;
        case RSVRequestEnterNow:
            if (!RSVEnabled()) { RSVLog(@"Manual reserve ignored: MYXX Reserve is switched off"); RSVSignal(RSVSBBusy, 0xfe); break; }
            RSVEnter(@"manual", NO); break;
        case RSVRequestRecoverNow: RSVRecover(@"requested", YES); break;
        case RSVRequestPing:
            RSVSignal(gState == RSVStateActive ? RSVSBSleepRequested : RSVSBLoaded, (uint8_t)(nonce & 0xff));
            break;
        default: RSVLog(@"Unknown request %u", kind); break;
    }
}

// ---------------------------------------------------------------------------
// Hooks
static void (*orig_rootWindowSetFrame)(id, SEL, CGRect);
static void hook_rootWindowSetFrame(UIWindow *self, SEL _cmd, CGRect f) {
    gRootWindow = self;
    orig_rootWindowSetFrame(self, _cmd, f);
}

static void (*orig_updateBatteryState)(id, SEL, void *);
static void hook_updateBatteryState(id self, SEL _cmd, void *arg) {
    orig_updateBatteryState(self, _cmd, arg);
    RSVEvaluateBattery();
}

static void (*orig_ACPowerChanged)(id, SEL);
static void hook_ACPowerChanged(id self, SEL _cmd) {
    orig_ACPowerChanged(self, _cmd);
    RSVEvaluateBattery();
}

static BOOL RSVBlockingWakes(void) {
    return (gState == RSVStateActive) && RSVBlockWakes();
}

static void (*orig_tapToWake)(id, SEL, void *);
static void hook_tapToWake(id self, SEL _cmd, void *arg) {
    if (RSVBlockingWakes()) return;
    orig_tapToWake(self, _cmd, arg);
}

static void (*orig_liftWake)(id, SEL, void *, long long, long long);
static void hook_liftWake(id self, SEL _cmd, void *mgr, long long gesture, long long orientation) {
    if (RSVBlockingWakes()) return;
    orig_liftWake(self, _cmd, mgr, gesture, orientation);
}

// iOS 16: -(BOOL)disallowsSinglePressForReason:(id *)outReason. The argument is
// an out-pointer, NOT an object: it must never pass through ARC (0.2.0/0.2.1
// typed it as `id`, ARC retained the stack pointer on every side-button press
// and SpringBoard crashed into safe mode). It is passed through untouched.
static BOOL (*orig_lockDisallowSingle)(id, SEL, void *);
static BOOL hook_lockDisallowSingle(id self, SEL _cmd, void *outReason) {
    if (RSVBlockingWakes()) return YES;
    return orig_lockDisallowSingle(self, _cmd, outReason);
}

// Volume Up x3 recovery. Sentinel: UIPress.type == 102 with force == 1.0 on
// -[SpringBoard _handlePhysicalButtonEvent:]. Reverie: presses inside a short
// window. We combine them: 3 presses within 4 s (the first press may only
// wake the system, so the window is a bit longer than Reverie's 2 s).
static BOOL (*orig_physicalButton)(id, SEL, __unsafe_unretained id);
static BOOL hook_physicalButton(id self, SEL _cmd, __unsafe_unretained id event) {
    if (gState == RSVStateActive || gState == RSVStateQuickTest) {
        NSSet<UIPress *> *presses = [event isKindOfClass:UIPressesEvent.class] ? ((UIPressesEvent *)event).allPresses : nil;
        for (UIPress *p in presses) {
            if (![p isKindOfClass:UIPress.class]) continue;
            // 102 = private "volume up" press type; force 1.0 = pressed down (as Sentinel checks)
            if ((NSInteger)p.type == 102 && p.force == 1.0) {
                NSTimeInterval now = [NSDate date].timeIntervalSince1970;
                [gVolumePresses addObject:@(now)];
                NSIndexSet *old = [gVolumePresses indexesOfObjectsPassingTest:^BOOL(NSNumber *t, NSUInteger i, BOOL *s) { return now - t.doubleValue > 4.0; }];
                [gVolumePresses removeObjectsAtIndexes:old];
                if (gVolumePresses.count >= 3) {
                    [gVolumePresses removeAllObjects];
                    if (gState == RSVStateQuickTest) RSVEndQuickTestEarly();
                    else RSVRecover(@"Volume Up ×3", YES);
                }
            }
        }
    }
    return orig_physicalButton(self, _cmd, event);
}

static void RSVStartupRestore(void);

static void (*orig_didFinishLaunching)(id, SEL, void *);
static void hook_didFinishLaunching(id self, SEL _cmd, void *app) {
    orig_didFinishLaunching(self, _cmd, app);
    RSVStartupRestore();
}

// After a respring (our own recovery, a crash, or a manual respring while in
// reserve) restore anything the journal still lists.
static void RSVStartupRestore(void) {
    if (gDidFinishLaunching) return;
    gDidFinishLaunching = YES;
    BOOL wasActive = [RSVJournalGet(@"active") boolValue];
    BOOL respringPending = [RSVJournalGet(@"respringPending") boolValue];
    NSMutableArray *notes = [NSMutableArray new];
    RSVRestoreChanges(notes);   // no-op unless something is still recorded
    RSVJournalSet(@"respringPending", @NO);
    if (wasActive) {
        RSVJournalSet(@"active", @NO);
        if (!RSVOnPower()) RSVSetRearmLatch();
        RSVSignal(RSVSBRestoredAfterRespring, 0);
        RSVLog(@"SpringBoard restarted while reserve was active; restored: %@", notes.count ? [notes componentsJoinedByString:@"; "] : @"nothing needed");
    } else if (respringPending) {
        RSVSignal(RSVSBRecovered, 2);
        RSVLog(@"Recovery respring completed");
    } else {
        RSVSignal(RSVSBLoaded, 0);
        RSVLog(@"Loaded v%s (build %d)%@", RSV_VERSION, RSV_BUILD,
               gMissingHooks.count ? [NSString stringWithFormat:@"; unavailable hooks: %@", [gMissingHooks componentsJoinedByString:@", "]] : @"");
    }
    RSVPublishDisplayConfig();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ RSVEvaluateBattery(); });
}

// ---------------------------------------------------------------------------
static void RSVPrefsChanged(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
    dispatch_async(dispatch_get_main_queue(), ^{
        CFPreferencesAppSynchronize(kDomain);
        RSVPublishDisplayConfig();
        RSVEvaluateBattery();
    });
}

__attribute__((constructor)) static void RSVInit(void) {
    @autoreleasepool {
        if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        kDomain = CFSTR(RSV_DOMAIN);
        kStatusDomain = CFSTR(RSV_STATUS_DOMAIN);
        kJournalDomain = CFSTR(RSV_JOURNAL_DOMAIN);
        gMissingHooks = [NSMutableArray new];

        // Earliest possible startup proof — independent of reserve and of
        // SpringBoard finishing its launch.
        RSVSignal(RSVSBLoaded, 0xff);
        RSVStatusText(@"hooks", @"");
        // notifyd drops a name's state when its last registration goes away.
        // The helper exits right after reporting, so SpringBoard keeps these
        // names registered for the whole session.
        static int holdHelper = 0, holdThermal = 0, holdDisplay = 0;
        notify_register_check(RSV_N_HELPER_STATE, &holdHelper);
        notify_register_check(RSV_N_THERMAL_STATE, &holdThermal);
        notify_register_check(RSV_N_DISP_STATE, &holdDisplay);

        Class sb = objc_getClass("SpringBoard");
        RSVHookNote(gMissingHooks, RSVHookInstance(sb, @selector(applicationDidFinishLaunching:), (IMP)hook_didFinishLaunching, (IMP *)&orig_didFinishLaunching), @"SpringBoard launch");
        RSVHookNote(gMissingHooks, RSVHookInstance(sb, @selector(_handlePhysicalButtonEvent:), (IMP)hook_physicalButton, (IMP *)&orig_physicalButton), @"Volume Up recovery");
        RSVHookNote(gMissingHooks, RSVHookInstance(objc_getClass("UIRootSceneWindow"), @selector(setFrame:), (IMP)hook_rootWindowSetFrame, (IMP *)&orig_rootWindowSetFrame), @"root window");
        Class ui = objc_getClass("SBUIController");
        RSVHookNote(gMissingHooks, RSVHookInstance(ui, @selector(updateBatteryState:), (IMP)hook_updateBatteryState, (IMP *)&orig_updateBatteryState), @"battery updates");
        RSVHookNote(gMissingHooks, RSVHookInstance(ui, @selector(ACPowerChanged), (IMP)hook_ACPowerChanged, (IMP *)&orig_ACPowerChanged), @"charger updates");
        RSVHookNote(gMissingHooks, RSVHookInstance(objc_getClass("SBTapToWakeController"), @selector(tapToWakeDidRecognize:), (IMP)hook_tapToWake, (IMP *)&orig_tapToWake), @"tap-to-wake block");
        RSVHookNote(gMissingHooks, RSVHookInstance(objc_getClass("SBLiftToWakeController"), @selector(wakeGestureManager:didUpdateWakeGesture:orientation:), (IMP)hook_liftWake, (IMP *)&orig_liftWake), @"raise-to-wake block");
        Method lockM = class_getInstanceMethod(objc_getClass("SBLockHardwareButtonActions"), @selector(disallowsSinglePressForReason:));
        const char *lockT = lockM ? method_getTypeEncoding(lockM) : NULL;
        BOOL lockSigOK = lockT && lockT[0] == 'B' && strstr(lockT, "^") != NULL;   // BOOL return, pointer argument
        if (!lockSigOK) [gMissingHooks addObject:@"side-button block (unexpected signature)"];
        else RSVHookNote(gMissingHooks, RSVHookInstance(objc_getClass("SBLockHardwareButtonActions"), @selector(disallowsSinglePressForReason:), (IMP)hook_lockDisallowSingle, (IMP *)&orig_lockDisallowSingle), @"side-button block");
        RSVStatusText(@"hooks", [gMissingHooks componentsJoinedByString:@", "]);

        // Second battery source (Reverie uses these notifications).
        NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
        for (NSNotificationName name in @[UIDeviceBatteryLevelDidChangeNotification, UIDeviceBatteryStateDidChangeNotification]) {
            [nc addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { RSVEvaluateBattery(); }];
        }

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, RSVPrefsChanged,
                                        CFSTR(RSV_N_PREFS), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        int tok = 0;
        notify_register_dispatch(RSV_N_REQUEST, &tok, dispatch_get_main_queue(), ^(int t) { RSVHandleRequest(); });
        // Prime the nonce so a request left over from before this respring is not replayed.
        notify_register_check(RSV_N_REQUEST, &gReqToken);
        uint64_t w = 0; notify_get_state(gReqToken, &w); gLastNonce = RSVRequestNonce(w);

        // Fallback in case the launch hook is unavailable on this build.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!gDidFinishLaunching) RSVStartupRestore();
        });
    }
}
