#import "PrivateUI.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <notify.h>
#import <objc/runtime.h>
#define MYB_SHEET_CLASS MYXXSheet
#import "../../Shared/MYBShieldSheet.h"
#import "../../Shared/MYBConnectivity.h"

UIColor *MYXXBackground(void) { return MYBShieldBackground(); }
UIColor *MYXXPanel(void) { return MYBShieldPanel(); }
UIColor *MYXXAccent(void) { return MYBShieldAccent(); }
UIColor *MYXXMuted(void) { return MYBShieldMuted(); }
UIImage *MYXXMarkImage(void) { return MYBShieldMarkImage(); }

void MYXXStyleNavigation(UINavigationController *navigation) {
    navigation.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    navigation.view.backgroundColor = MYBShieldBackground();
    UINavigationBarAppearance *bar = [UINavigationBarAppearance new];
    [bar configureWithOpaqueBackground];
    bar.backgroundColor = MYBShieldBackground();
    bar.shadowColor = MYBShieldHairline();
    UIFont *base = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    bar.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor,
        NSFontAttributeName: [UIFont systemFontOfSize:base.pointSize weight:UIFontWeightSemibold]};
    UIFont *large = [UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle];
    bar.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor,
        NSFontAttributeName: [UIFont systemFontOfSize:large.pointSize weight:UIFontWeightBold]};
    navigation.navigationBar.standardAppearance = bar;
    navigation.navigationBar.scrollEdgeAppearance = bar;
    navigation.navigationBar.compactAppearance = bar;
    navigation.navigationBar.tintColor = MYBShieldAccent();
    UIToolbarAppearance *tools = [UIToolbarAppearance new];
    [tools configureWithOpaqueBackground];
    tools.backgroundColor = MYBShieldPanel();
    navigation.toolbar.standardAppearance = tools;
    navigation.toolbar.scrollEdgeAppearance = tools;
    navigation.toolbar.tintColor = MYBShieldAccent();
}

// Sheets never stack: one at a time, the next waits for the one on screen to leave.
static NSMutableArray<void (^)(void)> *Pending;
static BOOL Showing;
static void Drain(void) {
    if (Showing || !Pending.count) return;
    void (^next)(void) = Pending.firstObject;
    [Pending removeObjectAtIndex:0];
    next();
}
static UIViewController *Top(UIViewController *host) {
    UIViewController *top = host;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top = top.presentedViewController;
    return top;
}
static void Enqueue(void (^present)(UIViewController *top, void (^done)(void)), UIViewController *host) {
    if (!Pending) Pending = [NSMutableArray array];
    __weak UIViewController *weakHost = host;
    [Pending addObject:^{
        UIViewController *strongHost = weakHost;
        if (!strongHost.view.window) { Drain(); return; } // the screen went away: nothing to show it on
        Showing = YES;
        present(Top(strongHost), ^{ Showing = NO; dispatch_async(dispatch_get_main_queue(), ^{ Drain(); }); });
    }];
    Drain();
}
static MYBShieldActionStyle StyleFor(NSString *name) {
    if ([name isEqual:@"primary"]) return MYBShieldActionPrimary;
    if ([name isEqual:@"destructive"]) return MYBShieldActionDestructive;
    if ([name isEqual:@"cancel"]) return MYBShieldActionCancel;
    return MYBShieldActionSecondary;
}
static void Present(UIViewController *host, MYXXSheet *sheet, void (^done)(void)) {
    sheet.kicker = @"MYBLOXX® PRIVACY";
    sheet.onGone = done;
    if (![MYXXSheet present:sheet from:host completion:nil]) done();
}

void MYXXShowMessage(UIViewController *host, NSString *title, NSString *message, BOOL ok) {
    Enqueue(^(UIViewController *top, void (^done)(void)) {
        MYXXSheet *sheet = [MYXXSheet new];
        sheet.heading = title; sheet.message = message;
        sheet.symbol = ok ? @"checkmark.shield.fill" : @"exclamationmark.shield.fill";
        sheet.tone = ok ? MYBShieldPositive() : MYBShieldWarning();
        sheet.actions = @[[MYBShieldAction title:@"OK" detail:nil style:MYBShieldActionPrimary handler:nil]];
        sheet.dismissOnBackdrop = YES;
        Present(top, sheet, done);
    }, host);
}

void MYXXShowConfirmation(UIViewController *host, NSString *text, NSString *symbol) {
    Enqueue(^(UIViewController *top, void (^done)(void)) {
        MYXXSheet *sheet = [MYXXSheet new];
        sheet.heading = text;
        sheet.symbol = symbol ?: @"checkmark.shield.fill";
        sheet.tone = MYBShieldPositive();
        sheet.autoClose = 1.6;
        sheet.dismissOnBackdrop = YES; // a tap anywhere closes it sooner
        sheet.actions = @[];
        Present(top, sheet, done);
    }, host);
}

void MYXXShowChoice(UIViewController *host, NSString *title, NSString *message, NSString *symbol, NSArray<NSDictionary *> *choices) {
    Enqueue(^(UIViewController *top, void (^done)(void)) {
        MYXXSheet *sheet = [MYXXSheet new];
        sheet.heading = title; sheet.message = message;
        sheet.symbol = symbol ?: @"questionmark.circle.fill";
        sheet.tone = MYBShieldAccent();
        NSMutableArray *actions = [NSMutableArray array];
        for (NSDictionary *choice in choices) {
            void (^handler)(void) = choice[@"handler"];
            [actions addObject:[MYBShieldAction title:choice[@"title"] detail:choice[@"detail"]
                style:StyleFor(choice[@"style"]) handler:handler]];
        }
        sheet.actions = actions;
        sheet.dismissOnBackdrop = YES;
        Present(top, sheet, done);
    }, host);
}

// Tips: dismissal is remembered in Photos' own defaults, so it survives upgrades and uninstalls of the tweak. "Replay Tips" in Settings raises
// a counter in the shared tips file; a higher counter than the one Photos last saw clears every remembered tip once.
static NSString *TipKey(NSString *key) { return [@"net.myxxdev.mybloxx.photos.tip." stringByAppendingString:key]; }
static void SyncReplay(void) {
    NSDictionary *tips = [NSDictionary dictionaryWithContentsOfFile:MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.tips.plist")];
    NSInteger wanted = [tips[@"ReplayCount"] integerValue];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger seen = [defaults integerForKey:@"net.myxxdev.mybloxx.photos.tip.replay"];
    if (wanted <= seen) return;
    for (NSString *name in @[@"deleted", @"album", @"photos"]) [defaults removeObjectForKey:TipKey(name)];
    [defaults setInteger:wanted forKey:@"net.myxxdev.mybloxx.photos.tip.replay"];
}
void MYXXShowTipOnce(UIViewController *host, NSString *key, NSString *heading, NSString *message, NSString *symbol) {
    MYXXShowTipFactsOnce(host, key, heading, message, nil, symbol);
}
// The same sheet with labelled lines under the sentence: both Photos gestures are shown together in one tip.
void MYXXShowTipFactsOnce(UIViewController *host, NSString *key, NSString *heading, NSString *message, NSArray<NSArray<NSString *> *> *facts, NSString *symbol) {
    SyncReplay();
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults boolForKey:TipKey(key)]) return;
    Enqueue(^(UIViewController *top, void (^done)(void)) {
        MYXXSheet *sheet = [MYXXSheet new];
        sheet.heading = heading; sheet.message = message; sheet.facts = facts;
        sheet.symbol = symbol ?: @"lightbulb.fill";
        sheet.tone = MYBShieldAccent();
        sheet.actions = @[[MYBShieldAction title:@"Got It" detail:nil style:MYBShieldActionPrimary handler:^{
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:TipKey(key)];
        }]];
        sheet.dismissOnBackdrop = NO; // a tip is dismissed with its button, so it is remembered only once it was read
        Present(top, sheet, done);
    }, host);
}

// LocalAuthentication only offers Face ID to a process whose own Info.plist declares NSFaceIDUsageDescription; MobileSMS, mobileslideshow and
// mobilephone/InCallService are Apple's own bundles and declare no such thing, so without this LAContext silently treats Face ID as unavailable and
// goes straight to the passcode sheet every time, in every one of these three hosts -- not a permissions problem the person can fix, and not a sign
// Face ID is off: the host app simply never says it wants to use it. Supplying the one string iOS asks for, only for the key that is missing and only
// read back from this process's own main bundle, is what actually turns Face ID on here; it changes nothing about what the system Face ID prompt itself
// shows or how it is authorized.
static void MYXXEnsureFaceIDDescription(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *reason = @"Confirm it's you to open this.";
        Method objectForKey = class_getInstanceMethod(NSBundle.class, @selector(objectForInfoDictionaryKey:));
        if (objectForKey) {
            IMP orig = method_getImplementation(objectForKey);
            IMP replacement = imp_implementationWithBlock(^id(NSBundle *self_, NSString *key) {
                id value = ((id (*)(id, SEL, id))orig)(self_, @selector(objectForInfoDictionaryKey:), key);
                if (!value && self_ == NSBundle.mainBundle && [key isEqualToString:@"NSFaceIDUsageDescription"]) return reason;
                return value;
            });
            method_setImplementation(objectForKey, replacement);
        }
        Method infoDict = class_getInstanceMethod(NSBundle.class, @selector(infoDictionary));
        if (infoDict) {
            IMP orig = method_getImplementation(infoDict);
            IMP replacement = imp_implementationWithBlock(^NSDictionary *(NSBundle *self_) {
                NSDictionary *value = ((NSDictionary * (*)(id, SEL))orig)(self_, @selector(infoDictionary));
                if (self_ == NSBundle.mainBundle && !value[@"NSFaceIDUsageDescription"]) {
                    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:value ?: @{}];
                    merged[@"NSFaceIDUsageDescription"] = reason;
                    return merged;
                }
                return value;
            });
            method_setImplementation(infoDict, replacement);
        }
    });
}

void MYXXAuthenticate(UIViewController *host, NSString *reason, void (^proceed)(void)) {
    MYXXEnsureFaceIDDescription();
    LAContext *context = [LAContext new];
    NSError *error = nil;
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
        MYXXShowMessage(host, @"Device lock needed", @"This is set to ask for Face ID or your passcode, but this phone can't check either. Set a passcode, or turn the lock off in MYbloXX® Settings.", NO);
        return;
    }
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:reason reply:^(BOOL success, NSError *failure) {
        (void)failure;
        dispatch_async(dispatch_get_main_queue(), ^{ if (success && proceed) proceed(); });
    }];
}
