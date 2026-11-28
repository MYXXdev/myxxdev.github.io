// MYXX Reserve — battery percentage display.
// Original code by MYXXdev.
//
// Why Sentinel only fixed Control Center: it hooks -[_UIStatusBarStringView
// setText:] and rewrites any string containing "%". The number INSIDE the
// iOS 16 battery icon is not a string view: it is drawn by _UIBatteryView
// from its `chargePercent` (with `showsPercentage`, `percentageLabel`,
// `-_updatePercentage`). Both the icon and the Control Center text are owned
// by one object, _UIStatusBarBatteryItem (batteryView / staticBatteryView /
// percentView), which receives the phone's own battery entry
// (_UIStatusBarDataBatteryEntry: capacity, detailString) in
// -applyUpdate:toDisplayItem:.
//
// So we hook exactly that one method:
//  * input is the TRUE capacity from the update, never the view's current
//    value -> applying twice gives the same result (no double offset);
//  * only the phone's status-bar battery item is touched, so widgets,
//    Bluetooth/AirPods and other accessory battery views are unaffected;
//  * showsPercentage is never changed, so the system Battery Percentage
//    switch is respected;
//  * one shared calculation (RSVDisplayedPercent) feeds both outputs.
//
// Process scope (MYbloXX build): SpringBoard always (Home Screen, Lock Screen,
// Control Center). While the adjusted percentage is switched on, the MYbloXX
// helper also writes the installed apps into this loader's filter so the status
// bar inside apps shows the same number; an app picks it up the next time it
// opens. It never loads through com.apple.UIKit, and with the adjusted
// percentage off nothing loads in apps. The constructor exits at once in
// anything that is not SpringBoard or an .app bundle.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import "../Shared/RSVShared.h"
#import "../Shared/RSVHook.h"

@interface NSObject (RSVStatusBar)
- (id)data;
- (id)mainBatteryEntry;
- (long long)capacity;
- (NSString *)detailString;
- (UIView *)batteryView;
- (UIView *)staticBatteryView;
- (UILabel *)percentView;
- (void)setChargePercent:(double)p;
- (double)chargePercent;
@end

static uint64_t gCfg = 0;
static NSHashTable *gItems = nil;                // weak set of live battery items
static const void *kTrueCapKey = &kTrueCapKey;   // NSNumber, last true capacity
static const void *kTrueTextKey = &kTrueTextKey; // NSString, last true detail string

static BOOL RSVSpoofOn(void) { return RSVDisplaySpoof(gCfg) && RSVDisplayThreshold(gCfg) > 1; }

// Replace the number inside the system's own (localised) percent string, so
// "45%", "45 %" or "%45" keep their format.
static NSString *RSVRewriteText(NSString *trueText, long long trueCap, long long shown) {
    if (!trueText.length) return trueText;
    NSRange r = [trueText rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet];
    if (r.location == NSNotFound) return trueText;
    NSUInteger end = r.location;
    while (end < trueText.length && [NSCharacterSet.decimalDigitCharacterSet characterIsMember:[trueText characterAtIndex:end]]) end++;
    NSRange digits = NSMakeRange(r.location, end - r.location);
    NSString *found = [trueText substringWithRange:digits];
    // Only rewrite if the digits are the battery number (guards against odd strings).
    NSNumberFormatter *nf = [NSNumberFormatter new];
    nf.locale = NSLocale.currentLocale;
    NSNumber *parsed = [nf numberFromString:found];
    if (parsed && parsed.longLongValue != trueCap) return trueText;
    NSString *replacement = [nf stringFromNumber:@(shown)] ?: [NSString stringWithFormat:@"%lld", shown];
    return [trueText stringByReplacingCharactersInRange:digits withString:replacement];
}

static const void *kDeviatedKey = &kDeviatedKey; // @YES while views show a spoofed value

// Spoof off: never touch the views unless we previously changed them (then put
// the true values back once). Spoof on: write the adjusted value.
static void RSVApply(id item) {
    NSNumber *capN = objc_getAssociatedObject(item, kTrueCapKey);
    if (!capN) return;
    BOOL spoof = RSVSpoofOn();
    BOOL deviated = [objc_getAssociatedObject(item, kDeviatedKey) boolValue];
    if (!spoof && !deviated) return;   // stock display untouched
    long long trueCap = capN.longLongValue;
    long long shown = spoof ? RSVDisplayedPercent(trueCap, RSVDisplayThreshold(gCfg)) : trueCap;
    double fraction = (double)shown / 100.0;   // same conversion the system uses for capacity

    if ([item respondsToSelector:@selector(batteryView)]) {
        UIView *bv = [item batteryView];
        if ([bv respondsToSelector:@selector(setChargePercent:)] && [bv chargePercent] != fraction) [bv setChargePercent:fraction];
    }
    if ([item respondsToSelector:@selector(staticBatteryView)]) {
        UIView *sv = [item staticBatteryView];
        if ([sv respondsToSelector:@selector(setChargePercent:)] && [sv chargePercent] != fraction) [sv setChargePercent:fraction];
    }
    if ([item respondsToSelector:@selector(percentView)]) {
        UILabel *pv = [item percentView];
        NSString *trueText = objc_getAssociatedObject(item, kTrueTextKey);
        if ([pv isKindOfClass:UILabel.class] && trueText.length) {
            NSString *want = spoof ? RSVRewriteText(trueText, trueCap, shown) : trueText;
            if (![pv.text isEqualToString:want]) pv.text = want;
        }
    }
    objc_setAssociatedObject(item, kDeviatedKey, spoof ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id (*orig_applyUpdate)(id, SEL, __unsafe_unretained id, __unsafe_unretained id);
static id hook_applyUpdate(id self, SEL _cmd, __unsafe_unretained id update, __unsafe_unretained id displayItem) {
    id r = orig_applyUpdate(self, _cmd, update, displayItem);
    @try {
        id data = [update respondsToSelector:@selector(data)] ? [update data] : nil;
        id entry = [data respondsToSelector:@selector(mainBatteryEntry)] ? [data mainBatteryEntry] : nil;
        if (entry && [entry respondsToSelector:@selector(capacity)]) {
            objc_setAssociatedObject(self, kTrueCapKey, @([entry capacity]), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSString *detail = [entry respondsToSelector:@selector(detailString)] ? [entry detailString] : nil;
            if (detail) objc_setAssociatedObject(self, kTrueTextKey, [detail copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (objc_getAssociatedObject(self, kTrueCapKey)) {
            [gItems addObject:self];
            // Re-apply after every update (idempotent; input is the true value).
            // When spoofing is off and the item never deviated, this writes nothing.
            RSVApply(self);
        }
    } @catch (NSException *e) {
        NSLog(@"[MYXXReserve] display update error: %@", e);
    }
    return r;
}

static void RSVReloadConfig(int token) {
    uint64_t w = 0;
    notify_get_state(token, &w);
    gCfg = w;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (id item in gItems.allObjects) RSVApply(item);   // also restores stock when turned off
    });
}

__attribute__((constructor)) static void RSVDisplayInit(void) {
    @autoreleasepool {
        NSBundle *mb = NSBundle.mainBundle;
        BOOL isSB = [mb.bundleIdentifier isEqualToString:@"com.apple.springboard"];
        BOOL isApp = [mb.bundlePath hasSuffix:@".app"];
        if (!isSB && !isApp) return;   // daemons/extensions with UIKit: do nothing

        Class item = objc_getClass("_UIStatusBarBatteryItem");
        BOOL hooked = RSVHookInstance(item, @selector(applyUpdate:toDisplayItem:), (IMP)hook_applyUpdate, (IMP *)&orig_applyUpdate);
        gItems = [NSHashTable weakObjectsHashTable];

        int token = 0;
        notify_register_check(RSV_N_DISPLAY_CFG, &token);
        RSVReloadConfig(token);
        int dtok = 0;
        notify_register_dispatch(RSV_N_DISPLAY_CFG, &dtok, dispatch_get_main_queue(), ^(int t) { RSVReloadConfig(t); });

        if (isSB) {
            // Startup proof for the display hook, shown separately in Settings.
            int st = 0;
            notify_register_check(RSV_N_DISP_STATE, &st);
            notify_set_state(st, RSVPackStatus(RSV_BUILD, hooked ? 1 : 0x81, 0, RSVNow()));
            notify_post(RSV_N_DISP_STATE);
        }
    }
}
