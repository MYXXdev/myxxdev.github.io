#import "MYBPBAppDelegate.h"
#import "MYBPBBrowserController.h"

@interface MYBPBAppDelegate ()
@property(nonatomic,strong) UIView *privacyCurtain;   // hides page content from the app switcher snapshot
@end

@implementation MYBPBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application; (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [MYBPBBrowserController new];
    self.window.backgroundColor = UIColor.blackColor;
    [self.window makeKeyAndVisible];
    return YES;
}

// Privacy-first: a browser's app-switcher snapshot is itself a leak (whatever page was on screen sits in the
// snapshot cache until the next launch). Covering the window the instant the app resigns active, and removing the
// cover only once it's genuinely active again, keeps that snapshot blank no matter what was being browsed.
- (void)applicationWillResignActive:(UIApplication *)application {
    (void)application;
    if (self.privacyCurtain) return;
    UIView *curtain = [[UIView alloc] initWithFrame:self.window.bounds];
    curtain.backgroundColor = [UIColor colorWithRed:0.04 green:0.08 blue:0.09 alpha:1.0];
    UIImageView *mark = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppIcon60x60"]];
    mark.frame = CGRectMake(0, 0, 72, 72);
    mark.center = CGPointMake(CGRectGetMidX(curtain.bounds), CGRectGetMidY(curtain.bounds));
    mark.layer.cornerRadius = 16; mark.clipsToBounds = YES;
    mark.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [curtain addSubview:mark];
    curtain.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.window addSubview:curtain];
    self.privacyCurtain = curtain;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    (void)application;
    [self.privacyCurtain removeFromSuperview];
    self.privacyCurtain = nil;
}

// Belt and suspenders beyond the ephemeral data store itself (which never touches disk to begin with): on a real
// quit, actively drop every in-memory record too, so nothing lingers a moment longer than the process does.
- (void)applicationWillTerminate:(UIApplication *)application {
    (void)application;
    [MYBPBBrowserController purgeEphemeralData];
}

@end
