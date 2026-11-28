// MYXX Reserve — Control Center toggle (loaded by CCSupport).
// Original code by MYXXdev. Tapping it asks SpringBoard to enter reserve now;
// SpringBoard acknowledges in the Settings status block.
#import <UIKit/UIKit.h>
#import <notify.h>
#import "../Shared/RSVShared.h"

@interface CCUIToggleModule : NSObject
- (void)refreshState;
@end

@interface RSVCCModule : CCUIToggleModule
@end

@implementation RSVCCModule

- (UIImage *)iconGlyph {
    return [UIImage systemImageNamed:@"moon.zzz.fill"];
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.42 green:0.17 blue:0.85 alpha:1.0];
}

- (BOOL)isSelected {
    int t = 0; uint64_t s = 0;
    if (notify_register_check(RSV_N_SB_STATE, &t) == NOTIFY_STATUS_OK) { notify_get_state(t, &s); notify_cancel(t); }
    uint8_t c = RSVStatusCode(s);
    return RSVStatusBuild(s) == RSV_BUILD && (c == RSVSBEntering || c == RSVSBSleepRequested);
}

- (void)setSelected:(BOOL)selected {
    if (!selected) { [self refreshState]; return; }   // waking happens with power / Volume Up ×3
    int t = 0;
    notify_register_check(RSV_N_REQUEST, &t);
    notify_set_state(t, RSVPackRequest(RSVRequestEnterNow, arc4random() | 1u));
    notify_cancel(t);
    notify_post(RSV_N_REQUEST);
    [self refreshState];
}

@end
