#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import <roothide.h>
#import "PMCore.h"
#import "PMUI.h"
#import "../../Shared/MYBConnectivity.h"

// MYbloXX® Private Conversations: Messages only (com.apple.MobileSMS). Nothing here is loaded anywhere else, and nothing in this file touches
// CommCenter, carrier or SIM settings, calls, or message delivery. Everything stays OFF until the switch in MYbloXX® Settings is turned on.

// ---- five taps on the Messages title ----------------------------------------------------------------------------------------------------------
// The title is the visible label that reads the list screen's own title (large or collapsed header), never a fixed position. Only touches that start
// on that label count, so the bar's buttons and normal navigation are untouched.
static char TapsKey, DelegateKey;
static BOOL IsConversationList(UIViewController *controller) {
    NSString *name = NSStringFromClass(controller.class);
    return [name hasPrefix:@"CKConversationList"] && ![name containsString:@"Search"] && ![name containsString:@"Cell"];
}
static UILabel *TitleLabel(UIView *root, NSString *title, int depth) {
    if (depth > 8 || root.hidden || root.alpha < 0.05) return nil;
    if ([root isKindOfClass:UILabel.class] && [((UILabel *)root).text isEqualToString:title] && root.window) return (UILabel *)root;
    for (UIView *child in root.subviews) { UILabel *found = TitleLabel(child, title, depth + 1); if (found) return found; }
    return nil;
}
static BOOL TouchOnTitle(UINavigationController *nav, UITouch *touch) {
    UIViewController *top = nav.topViewController;
    NSString *title = top.navigationItem.title ?: top.title;
    if (!title.length) return NO;
    UILabel *label = TitleLabel(nav.navigationBar, title, 0);
    if (!label) return NO;
    CGRect frame = CGRectInset([label convertRect:label.bounds toView:nav.navigationBar], -8, -6);
    return CGRectContainsPoint(frame, [touch locationInView:nav.navigationBar]);
}
@interface MYXXPMTapDelegate : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak) UINavigationController *navigation;
@end
@implementation MYXXPMTapDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    UINavigationController *nav = self.navigation;
    return nav && PMActive() && IsConversationList(nav.topViewController) && !nav.presentedViewController && nav.viewControllers.count == 1 && TouchOnTitle(nav, touch);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
@end

@interface UINavigationController (MYXXPrivateMessages)
- (void)myxx_privateTaps:(UITapGestureRecognizer *)gesture;
@end

%hook UINavigationController
- (void)viewDidLayoutSubviews {
    %orig;
    if (!PMSwitchOn()) return;
    UIViewController *top = self.topViewController;
    PMNoteTop(top);
    UITapGestureRecognizer *taps = objc_getAssociatedObject(self.navigationBar, &TapsKey);
    BOOL onList = IsConversationList(top) && self.viewControllers.count == 1;
    if (!onList) {
        if (taps.enabled) { taps.enabled = NO; taps.enabled = YES; }        // leaving the list: half-counted taps are dropped
        return;
    }
    if (!PMActive()) return;
    if (!taps) {
        MYXXPMTapDelegate *delegate = [MYXXPMTapDelegate new];
        delegate.navigation = self;
        taps = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(myxx_privateTaps:)];
        taps.numberOfTapsRequired = 5;
        taps.cancelsTouchesInView = NO;
        taps.delaysTouchesEnded = NO;
        taps.delegate = delegate;
        [self.navigationBar addGestureRecognizer:taps];
        objc_setAssociatedObject(self.navigationBar, &TapsKey, taps, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self.navigationBar, &DelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);   // the recognizer holds it weakly
    }
    if (top.viewIfLoaded.window) { PMScanList(top); PMMaybeShowTip(self); }
}
%new
- (void)myxx_privateTaps:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized || !PMActive() || self.presentedViewController) return;
    PMOpenFromGesture(self);
}
%end

%ctor {
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier;
    if (![bundle isEqualToString:@"com.apple.MobileSMS"]) return;                    // hard scope: Messages and nothing else
    // iOS 16 only; on any other version Messages is left exactly as Apple ships it.
    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 16) return;
    PMInstallHooks();
    %init;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    void (^settle)(void) = ^{
        for (int i = 1; i <= 3; i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * i * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ PMReconcile(); });
    };
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; PMCoverIfNeeded(); }];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; PMLockAll(); }];
    [center addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; PMCoverIfNeeded(); PMLockAll(); }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; PMUncover(); PMReloadPrefs(); settle(); }];
    static int token = 0;
    notify_register_dispatch(MYB_PRIV_NOTIFY, &token, dispatch_get_main_queue(), ^(int t) {
        (void)t;
        PMReloadPrefs();
        if (!PMSwitchOn()) PMLockAll();       // switched off: the private session closes and every conversation is visible again
        PMRefreshLists();
        PMReconcile();
    });
    settle();
}
