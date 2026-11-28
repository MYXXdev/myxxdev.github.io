// MYXX Reserve — optional CPU slowdown while in reserve (thermalmonitord).
// Original code by MYXXdev.
//
// Reverie 2.4.1 captures thermalmonitord's CommonProduct (via -initProduct:)
// and calls -putDeviceInThermalSimulationMode:@"heavy"/@"off", but it makes
// that call from SpringBoard, where the captured pointer does not exist, so
// the option never takes effect. Here the call is made INSIDE thermalmonitord,
// triggered by a Darwin notification from SpringBoard, and every outcome is
// reported so Settings shows whether it actually happened on iOS 16.5.1.
// The feature is off by default.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import "../Shared/RSVShared.h"
#import "../Shared/RSVHook.h"

@interface NSObject (RSVThermal)
- (void)putDeviceInThermalSimulationMode:(NSString *)mode;
@end

static __weak id gProduct = nil;
static BOOL gThrottled = NO;

static void RSVThermalSignal(uint8_t code) {
    static int t = 0;
    if (!t) notify_register_check(RSV_N_THERMAL_STATE, &t);
    notify_set_state(t, RSVPackStatus(RSV_BUILD, code, gThrottled ? 1 : 0, RSVNow()));
    notify_post(RSV_N_THERMAL_STATE);
}

static id (*orig_initProduct)(id, SEL, void *);
static id hook_initProduct(id self, SEL _cmd, void *arg) {
    id r = orig_initProduct(self, _cmd, arg);
    if (r) { gProduct = r; RSVThermalSignal(RSVThermalProductFound); }
    return r;
}

static void RSVApplyThrottle(int token) {
    uint64_t want = 0;
    notify_get_state(token, &want);
    id p = gProduct;
    if (!p) { RSVThermalSignal(RSVThermalNoProduct); return; }
    if (![p respondsToSelector:@selector(putDeviceInThermalSimulationMode:)]) { RSVThermalSignal(RSVThermalNoSelector); return; }
    if (want && !gThrottled) {
        [p putDeviceInThermalSimulationMode:@"heavy"];
        gThrottled = YES;
        RSVThermalSignal(RSVThermalThrottled);
    } else if (!want && gThrottled) {
        [p putDeviceInThermalSimulationMode:@"off"];
        gThrottled = NO;
        RSVThermalSignal(RSVThermalUnthrottled);
    }
}

__attribute__((constructor)) static void RSVThermalInit(void) {
    @autoreleasepool {
        Class cp = objc_getClass("CommonProduct");
        BOOL ok = RSVHookInstance(cp, @selector(initProduct:), (IMP)hook_initProduct, (IMP *)&orig_initProduct);
        RSVThermalSignal(ok ? RSVThermalLoaded : RSVThermalNoProduct);
        int tok = 0;
        notify_register_dispatch(RSV_N_THROTTLE, &tok, dispatch_get_main_queue(), ^(int t) { RSVApplyThrottle(t); });
        // If thermalmonitord restarts while reserve asked for throttling, apply again.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            int t = 0; notify_register_check(RSV_N_THROTTLE, &t);
            uint64_t w = 0; notify_get_state(t, &w);
            if (w) RSVApplyThrottle(t);
        });
    }
}
