#import <Photos/Photos.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>
#import <mach-o/dyld.h>
#import <roothide.h>
#import "PrivateAlbum.h"
#import "PrivateUI.h"
#import "../../Shared/MYBConnectivity.h"

// MYbloXX® Extra Privacy Protection. Two independent switches, both OFF until turned on in MYbloXX® Settings:
//   RecentlyDeletedPrivacy  the 3-second hold on Recently Deleted (Albums > Utilities) hides or shows its contents
//   PrivateAlbum            five taps on Albums opens the Private Album
// A switch only decides whether the hooks act. Turning one off never touches Photos data, the hidden/visible choice, or the Private
// Album storage: the hold choice is remembered and the private copies stay where they are.
static NSDictionary *privacyPrefs;
static void ReloadPrivacyPrefs(void) { privacyPrefs = [NSDictionary dictionaryWithContentsOfFile:MYBPrivPrefsFile()] ?: @{}; }
static BOOL DeletedSwitchOn(void) { return MYBConnFlag(privacyPrefs, MYB_PRIV_KEY_DELETED); }
static BOOL AlbumLockOn(void) { return MYBConnFlag(privacyPrefs, MYB_PRIV_KEY_ALBUM_LOCK); }
static BOOL DeletedLockOn(void) { return MYBConnFlag(privacyPrefs, MYB_PRIV_KEY_DELETED_LOCK); }
static BOOL AlbumSwitchOn(void) { return MYBConnFlag(privacyPrefs, MYB_PRIV_KEY_ALBUM); }

static NSString *const HideRecentlyDeletedKey = @"com.myxxdev.emptyrecentlydeleted.enabled";
static const PHAssetCollectionSubtype RecentlyDeletedSubtype = (PHAssetCollectionSubtype)1000000201;
static char PrivateAlbumControllerKey;

static char ToggleGestureKey;
static char DeletedGestureKey;
static NSString *DeletedAlbumTitle;

static BOOL HideChosen(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HideRecentlyDeletedKey];
}
// Effective state: hidden only while the switch is ON and the user chose Hidden. Switch off = Photos behaves exactly as stock.
static BOOL HideRecentlyDeleted(void) {
    return DeletedSwitchOn() && HideChosen();
}

static BOOL IsRecentlyDeletedCollection(id collection) {
    if (![collection isKindOfClass:PHAssetCollection.class]) return NO;
    PHAssetCollection *album = collection;
    return album.assetCollectionType == PHAssetCollectionTypeSmartAlbum &&
        album.assetCollectionSubtype == RecentlyDeletedSubtype;
}

static BOOL IsDeletedLabel(NSString *label) {
    if (!label.length) return NO;
    return [label isEqualToString:DeletedAlbumTitle] ||
        [label isEqualToString:@"Recently Deleted"] ||
        [label isEqualToString:@"Eliminado recientemente"] ||
        [label isEqualToString:@"Eliminados recientemente"];
}

@interface PXPhotosDataSource : NSObject
+ (PHFetchResult *)_emptyAssetsFetchResult;
@end

static PHFetchResult *DeletedGridEmptyResult;

static PHFetchResult *NativeEmptyResult(void) {
    @synchronized (PHAsset.class) {
        if (DeletedGridEmptyResult) return DeletedGridEmptyResult;
    }
    Class sourceClass = NSClassFromString(@"PXPhotosDataSource");
    if (![sourceClass respondsToSelector:@selector(_emptyAssetsFetchResult)]) return nil;
    PHFetchResult *result = [sourceClass _emptyAssetsFetchResult];
    return [result isKindOfClass:PHFetchResult.class] && result.count == 0 ? result : nil;
}

%hook PHAsset

+ (PHFetchResult *)fetchAssetsInAssetCollection:(PHAssetCollection *)collection options:(PHFetchOptions *)options {
    if (!IsRecentlyDeletedCollection(collection)) return %orig;
    if (NSThread.isMainThread) DeletedAlbumTitle = [collection.localizedTitle copy];
    if (HideRecentlyDeleted()) {
        PHFetchResult *empty = NativeEmptyResult();
        if (empty) return empty;
    }
    return %orig;
}

%end

static BOOL IsAlbumsList(UINavigationController *navigation) {
    UITabBarController *tabs = navigation.tabBarController;
    return tabs.viewControllers.count == 4 && tabs.viewControllers[2] == navigation &&
        navigation.viewControllers.count == 1;
}

static BOOL IsDeletedRowAtPoint(UIView *candidate, UIView *root, CGPoint point) {
    if (candidate.hidden || candidate.alpha < 0.01) return NO;
    CGRect rect = [candidate convertRect:candidate.bounds toView:root];
    if (point.y < CGRectGetMinY(rect) - 4 || point.y > CGRectGetMaxY(rect) + 4) return NO;

    if (CGRectGetHeight(rect) <= 90 &&
        (IsDeletedLabel(candidate.accessibilityLabel) ||
         ([candidate isKindOfClass:UILabel.class] && IsDeletedLabel(((UILabel *)candidate).text)))) {
        return YES;
    }
    for (UIView *child in candidate.subviews) {
        if (IsDeletedRowAtPoint(child, root, point)) return YES;
    }
    return NO;
}

@interface PXPhotosDataSource (MYXXRefresh)
- (void)refetchResultsForAssetCollection:(PHAssetCollection *)collection;
- (void)_publishReloadChange;
@end

static char AppliedDeletedStateKey;

static id ReadObjectIvar(id object, const char *name) {
    if (!object) return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    return type && type[0] == '@' ? object_getIvar(object, ivar) : nil;
}

static void UpdateNativeDeletedGrid(UIViewController *controller) {
    Class gridClass = NSClassFromString(@"PXPhotosUIViewController");
    if (!gridClass || ![controller isKindOfClass:gridClass]) return;

    id content = ReadObjectIvar(controller, "_contentController");
    id model = ReadObjectIvar(content, "_viewModel");
    id wrapper = ReadObjectIvar(model, "_currentDataSource");
    PXPhotosDataSource *source = ReadObjectIvar(wrapper, "_photosDataSource");
    PHAssetCollection *collection = ReadObjectIvar(source, "_containerCollection");
    if (!IsRecentlyDeletedCollection(collection) ||
        ![source respondsToSelector:@selector(refetchResultsForAssetCollection:)]) return;

    PHFetchResult *empty = ReadObjectIvar(source, "_emptyAssetsFetchResult");
    if ([empty isKindOfClass:PHFetchResult.class] && empty.count == 0) {
        @synchronized (PHAsset.class) {
            DeletedGridEmptyResult = empty;
        }
    }

    BOOL hidden = HideRecentlyDeleted();
    if (hidden && !NativeEmptyResult()) return;

    NSNumber *applied = objc_getAssociatedObject(source, &AppliedDeletedStateKey);
    if (applied && applied.boolValue == hidden) return;
    objc_setAssociatedObject(source, &AppliedDeletedStateKey, @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    PXPhotosDataSource *parent = ReadObjectIvar(source, "_parentDataSource");
    if ([parent respondsToSelector:@selector(refetchResultsForAssetCollection:)]) {
        [parent refetchResultsForAssetCollection:collection];
    }
    [source refetchResultsForAssetCollection:collection];
    if ([source respondsToSelector:@selector(_publishReloadChange)]) {
        [source _publishReloadChange];
    }
}

// ---- five taps on the Albums title ------------------------------------------------------------------------------------------------------
// The title is found by what is on screen (a visible label that reads the Albums screen's own title, large or collapsed), never by a fixed
// position, so it follows scrolling, rotation and Dynamic Type. Only touches that start on that label count; the bar's buttons are never
// involved. If no such label can be found on this iOS build, the older Albums-tab gesture stays active as the fallback (see myxx_handleAlbumTaps:).
static char TitleGestureKey;
static char TitleDelegateKey;
static UILabel *AlbumsTitleLabel(UIView *root, NSString *title, int depth) {
    if (depth > 8 || root.hidden || root.alpha < 0.05) return nil;
    if ([root isKindOfClass:UILabel.class] && [((UILabel *)root).text isEqualToString:title] && root.window) return (UILabel *)root;
    for (UIView *child in root.subviews) {
        UILabel *found = AlbumsTitleLabel(child, title, depth + 1);
        if (found) return found;
    }
    return nil;
}
static BOOL TouchOnAlbumsTitle(UINavigationController *navigation, UITouch *touch) {
    NSString *title = navigation.topViewController.navigationItem.title ?: navigation.topViewController.title;
    if (!title.length) return NO;
    UILabel *label = AlbumsTitleLabel(navigation.navigationBar, title, 0);
    if (!label) return NO;
    CGRect frame = CGRectInset([label convertRect:label.bounds toView:navigation.navigationBar], -8, -6);
    return CGRectContainsPoint(frame, [touch locationInView:navigation.navigationBar]);
}
@interface MYXXTitleTapDelegate : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak) UINavigationController *navigation;
@end
@implementation MYXXTitleTapDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    UINavigationController *navigation = self.navigation;
    return navigation && AlbumSwitchOn() && IsAlbumsList(navigation) && navigation.tabBarController.selectedViewController == navigation &&
        !navigation.presentedViewController && TouchOnAlbumsTitle(navigation, touch);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
@end

@interface UINavigationController (MYXXDeletedGesture)
- (void)myxx_holdRecentlyDeleted:(UILongPressGestureRecognizer *)gesture;
- (void)myxx_titleTaps:(UITapGestureRecognizer *)gesture;
@end

@interface UITabBarController (MYXXPrivatePhotosOpen)
- (void)myxx_openPrivateAlbum;
@end

static BOOL AlbumsTitleAvailable(UINavigationController *navigation) {
    NSString *title = navigation.topViewController.navigationItem.title ?: navigation.topViewController.title;
    return title.length && AlbumsTitleLabel(navigation.navigationBar, title, 0) != nil;
}

// A short branded tip the first time each gesture is useful: only on the Albums list, only when its switch is on, one per launch.
static BOOL TipShownThisLaunch;
static void MaybeShowAlbumsTips(UINavigationController *navigation) {
    if (TipShownThisLaunch || navigation.presentedViewController) return;
    // One tip, both gestures, shown while either is switched on in MYbloXX® Settings.
    if (!AlbumSwitchOn() && !DeletedSwitchOn()) return;
    NSArray *facts = @[
        @[@"Recently Deleted", @"In Albums \u2192 Utilities, hold Recently Deleted for three seconds to hide or show its items."],
        @[@"Private Album", @"Tap the Albums title at the top five times."]];
    TipShownThisLaunch = YES;
    UIViewController *top = navigation.tabBarController ?: navigation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (top.view.window && !top.presentedViewController) MYXXShowTipFactsOnce(top, @"photos", @"Photos Privacy", @"Two quiet gestures from MYbloXX\u00ae.", facts, @"hand.raised.fill");
    });
}


%hook UINavigationController

- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *top = self.topViewController;

    UpdateNativeDeletedGrid(top);

    BOOL onAlbums = IsAlbumsList(self);
    UITapGestureRecognizer *titleTaps = objc_getAssociatedObject(self.navigationBar, &TitleGestureKey);
    if (!onAlbums && titleTaps.enabled) { titleTaps.enabled = NO; titleTaps.enabled = YES; } // leaving Albums: any half-counted taps are dropped
    if (onAlbums && AlbumSwitchOn() && !titleTaps) {
        MYXXTitleTapDelegate *delegate = [MYXXTitleTapDelegate new];
        delegate.navigation = self;
        UITapGestureRecognizer *taps = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(myxx_titleTaps:)];
        taps.numberOfTapsRequired = 5;
        taps.cancelsTouchesInView = NO;
        taps.delaysTouchesEnded = NO;
        taps.delegate = delegate;
        [self.navigationBar addGestureRecognizer:taps];
        objc_setAssociatedObject(self.navigationBar, &TitleGestureKey, taps, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self.navigationBar, &TitleDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC); // the recognizer holds its delegate weakly
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil
            usingBlock:^(NSNotification *note) { (void)note; taps.enabled = NO; taps.enabled = YES; }]; // backgrounding resets the count
    }
    if (onAlbums && top.viewIfLoaded.window) MaybeShowAlbumsTips(self);

    UIView *list = onAlbums ? top.viewIfLoaded : nil;
    if (list && DeletedSwitchOn() && !objc_getAssociatedObject(list, &DeletedGestureKey)) {
        UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self
            action:@selector(myxx_holdRecentlyDeleted:)];
        hold.minimumPressDuration = 3;
        hold.cancelsTouchesInView = NO;
        [list addGestureRecognizer:hold];
        objc_setAssociatedObject(list, &DeletedGestureKey, hold, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (void)myxx_titleTaps:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized || !AlbumSwitchOn() || !IsAlbumsList(self)) return;
    [self.tabBarController myxx_openPrivateAlbum];
}

%new
- (void)myxx_holdRecentlyDeleted:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || !DeletedSwitchOn() || !IsAlbumsList(self)) return;
    UIViewController *top = self.topViewController;
    UIView *list = top.viewIfLoaded;
    if (list != gesture.view || !IsDeletedRowAtPoint(list, list, [gesture locationInView:list])) return;

    BOOL hidden = !HideChosen();
    void (^apply)(void) = ^{
        [NSUserDefaults.standardUserDefaults setBool:hidden forKey:HideRecentlyDeletedKey];
        // The centered MYbloXX® confirmation, with the exact words.
        NSString *words = hidden ? @"Recently Deleted: Hidden" : @"Recently Deleted: Visible";
        MYXXShowConfirmation(top, words, hidden ? @"eye.slash.fill" : @"eye.fill");
    };
    if (!hidden && DeletedLockOn()) MYXXAuthenticate(top, @"Show Recently Deleted", apply);   // only showing needs the check; hiding never does
    else apply();
}

%end

@interface UITabBarController (MYXXPrivatePhotos)
- (void)myxx_handleAlbumTaps:(UITapGestureRecognizer *)gesture;
- (void)myxx_openPrivateAlbum;
- (void)myxx_lockPrivateAlbum:(NSNotification *)notification;
@end

%hook UITabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UITabBar *tabBar = self.tabBar;
    if (objc_getAssociatedObject(tabBar, &ToggleGestureKey)) {
        return;
    }
    if (!AlbumSwitchOn()) return; // re-checked on the next appearance after the switch is turned on

    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(myxx_handleAlbumTaps:)];
    gesture.numberOfTapsRequired = 5;
    gesture.cancelsTouchesInView = NO;
    gesture.delaysTouchesEnded = NO;
    [tabBar addGestureRecognizer:gesture];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(myxx_lockPrivateAlbum:)
        name:UIApplicationDidEnterBackgroundNotification object:nil];
    objc_setAssociatedObject(tabBar, &ToggleGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)myxx_openPrivateAlbum {
    if (self.presentedViewController) return;
    void (^open)(void) = ^{
        if (self.presentedViewController) return;
        UIViewController *album = MYXXCreatePrivateAlbum();
        objc_setAssociatedObject(self, &PrivateAlbumControllerKey, album, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self presentViewController:album animated:YES completion:nil];
    };
    if (AlbumLockOn()) MYXXAuthenticate(self, @"Open Private Album", open);   // optional lock; the five taps themselves are unchanged
    else open();
}

%new
- (void)myxx_handleAlbumTaps:(UITapGestureRecognizer *)gesture {
    UITabBar *tabBar = self.tabBar;
    if (gesture.state != UIGestureRecognizerStateRecognized ||
        self.presentedViewController || !AlbumSwitchOn() || tabBar.items.count != 4) return;
    CGFloat width = CGRectGetWidth(tabBar.bounds) / 4;
    CGFloat x = [gesture locationInView:tabBar].x;
    if (width <= 0 || x < 0 || x >= width * 4) return;
    NSInteger slot = (NSInteger)(x / width);
    if (tabBar.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) slot = 3 - slot;
    if (slot != 2) return;
    // The five taps belong to the Albums title. This tab gesture is only the fallback for a build where that title cannot be found.
    UIViewController *albums = self.viewControllers[2];
    if ([albums isKindOfClass:UINavigationController.class] && AlbumsTitleAvailable((UINavigationController *)albums)) return;
    self.selectedIndex = 2;
    [self myxx_openPrivateAlbum];
}

%new
- (void)myxx_lockPrivateAlbum:(NSNotification *)notification {
    (void)notification;
    UIViewController *album = objc_getAssociatedObject(self, &PrivateAlbumControllerKey);
    if (album && self.presentedViewController == album) {
        album.view.hidden = YES;
        [self dismissViewControllerAnimated:NO completion:nil];
    }
    objc_setAssociatedObject(self, &PrivateAlbumControllerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end

%ctor {
    ReloadPrivacyPrefs();
    static int privacyToken = 0;
    notify_register_dispatch(MYB_PRIV_NOTIFY, &privacyToken, dispatch_get_main_queue(), ^(int token) {
        (void)token;
        ReloadPrivacyPrefs();
    });
    // The standalone "MYXX Private Photos" package hooks the same methods. Never install both: if it is loaded, MYbloXX® stays out of the way.
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "MYXXEmptyRecentlyDeleted")) return;
    }
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.mobileslideshow"] &&
        [NSProcessInfo processInfo].operatingSystemVersion.majorVersion == 16) {
        %init;
    }
}
