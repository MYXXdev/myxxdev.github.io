#import <UIKit/UIKit.h>
#import "PCStore.h"
#import "PCPhone.h"
#import "PCCall.h"

// MYbloXX® Private Calls. Two small, separate parts in one component: Phone (Recents) and the incoming-call app (actions). Nothing here is loaded in any other
// process, and nothing touches CommCenter, carrier or SIM settings, call delivery, outgoing calls, emergency calls, FaceTime or other apps' calls.
// Everything stays OFF until the switch in MYbloXX® Settings is turned on, and on any iOS other than 16 both parts do nothing at all.
__attribute__((constructor)) static void PCInit(void) {
    @autoreleasepool {
        NSString *bundle = NSBundle.mainBundle.bundleIdentifier;
        if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 16) return;
        if ([bundle isEqualToString:@"com.apple.InCallService"]) { PCCallInstall(); return; }
        if (![bundle isEqualToString:@"com.apple.mobilephone"]) return;
        PCPhoneInstall();
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; PCPhoneCoverIfNeeded(); }];
        [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; PCPhoneLockAll(); }];
        [center addObserverForName:UIApplicationProtectedDataWillBecomeUnavailable object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; PCPhoneCoverIfNeeded(); PCPhoneLockAll(); }];
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) { (void)n; PCPhoneUncover(); PCReload(); }];
    }
}
