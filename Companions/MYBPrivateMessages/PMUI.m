#import "PMUI.h"
#import "PMCore.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "../MYBPrivatePhotos/PrivateUI.h"

// The private list, its actions and the lock, in the same MYbloXX® look as the Private Album (shared sheets, colours and mark).
static UINavigationController *PrivateNav;
static UIWindow *CoverWindow;

static UIViewController *TopController(void) {
    UIViewController *top = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal) top = window.rootViewController;
    }
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top = top.presentedViewController;
    return top;
}

void PMUIMoveFromMenu(id conversation) {
    UIViewController *host = TopController();
    if (!host) return;
    MYXXShowChoice(host, @"Move to Private?", @"Alerts for this conversation will be hidden and it will leave the ordinary list. It stays in Apple Messages and keeps working normally.", @"lock.fill", @[
        @{@"title": @"Move to Private", @"style": @"primary", @"handler": ^{
            PMMove(conversation, ^(BOOL ok, NSString *message) { MYXXShowMessage(TopController() ?: host, ok ? @"Moved" : @"Not moved", message, ok); });
        }},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}

// ---- the list -----------------------------------------------------------------------------------------------------------------------------
@interface PMPickerController : UITableViewController
@property(nonatomic, copy) NSArray *items;
@property(nonatomic, copy) void (^picked)(id conversation);
@end
@implementation PMPickerController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Choose a Conversation";
    self.tableView.backgroundColor = MYXXBackground();
    self.tableView.separatorColor = [UIColor.whiteColor colorWithAlphaComponent:0.12];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
}
- (void)cancel { [self.navigationController dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)self.items.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:@"c"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    cell.backgroundColor = MYXXPanel(); cell.textLabel.textColor = UIColor.whiteColor;
    cell.textLabel.text = PMTitle(self.items[(NSUInteger)p.row]);
    return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    id conversation = self.items[(NSUInteger)p.row];
    [self.navigationController dismissViewControllerAnimated:YES completion:^{ if (self.picked) self.picked(conversation); }];
}
@end

@interface PMListController : UITableViewController
@property(nonatomic, copy) NSArray *items;
@end
@implementation PMListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Private Conversations";
    self.tableView.backgroundColor = MYXXBackground();
    self.tableView.separatorColor = [UIColor.whiteColor colorWithAlphaComponent:0.12];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"] style:UIBarButtonItemStylePlain target:self action:@selector(add)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Add a conversation";
    [self reload];
}
- (void)reload { self.items = PMPrivateConversations(); [self.tableView reloadData]; [self syncEmpty]; }
- (void)syncEmpty {
    if (self.items.count) { self.tableView.backgroundView = nil; return; }
    UILabel *label = [UILabel new];
    label.text = @"Nothing here yet.\nGo back to Messages, press and hold a conversation and choose Move to Private.";
    label.numberOfLines = 0; label.textAlignment = NSTextAlignmentCenter; label.textColor = MYXXMuted();
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]; label.adjustsFontForContentSizeCategory = YES;
    UIView *host = [UIView new]; host.backgroundColor = MYXXBackground();
    label.translatesAutoresizingMaskIntoConstraints = NO; [host addSubview:label];
    [NSLayoutConstraint activateConstraints:@[[label.leadingAnchor constraintEqualToAnchor:host.leadingAnchor constant:32], [label.trailingAnchor constraintEqualToAnchor:host.trailingAnchor constant:-32],
        [label.centerYAnchor constraintEqualToAnchor:host.centerYAnchor constant:-40]]];
    self.tableView.backgroundView = host;
}
- (void)done { PrivateNav = nil; [self.navigationController dismissViewControllerAnimated:YES completion:nil]; }   // the session stays open until Messages leaves the screen
- (void)add {
    PMPickerController *picker = [PMPickerController new];
    picker.items = PMOrdinaryConversations();
    __weak PMListController *weak = self;
    picker.picked = ^(id conversation) {
        PMMove(conversation, ^(BOOL ok, NSString *message) { MYXXShowMessage(TopController(), ok ? @"Moved" : @"Not moved", message, ok); [weak reload]; });
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    MYXXStyleNavigation(nav);
    [self presentViewController:nav animated:YES completion:nil];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)self.items.count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:@"c"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    cell.backgroundColor = MYXXPanel(); cell.textLabel.textColor = UIColor.whiteColor; cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.text = PMTitle(self.items[(NSUInteger)p.row]);
    return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    id conversation = self.items[(NSUInteger)p.row];
    [t deselectRowAtIndexPath:p animated:YES];
    UINavigationController *nav = self.navigationController;
    [nav dismissViewControllerAnimated:YES completion:^{
        PrivateNav = nil;
        if (!PMOpenNative(conversation)) MYXXShowMessage(TopController(), @"Couldn't open it", @"This conversation could not be opened from here. Nothing was changed.", NO);
    }];
}
- (void)confirmReturn:(id)conversation {
    MYXXShowChoice(self, @"Return to Messages?", @"It goes back to the ordinary list with its history intact, and Hide Alerts goes back to what it was before.", @"arrow.uturn.backward", @[
        @{@"title": @"Return to Messages", @"style": @"primary", @"handler": ^{
            PMReturn(conversation, ^(BOOL ok, NSString *message) { MYXXShowMessage(TopController() ?: self, ok ? @"Returned" : @"Returned, with a note", message, ok); [self reload]; });
        }},
        @{@"title": @"Cancel", @"style": @"cancel"}]);
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)t trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)p {
    id conversation = self.items[(NSUInteger)p.row];
    UIContextualAction *back = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Return" handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        (void)a; (void)v; [self confirmReturn:conversation]; done(YES);
    }];
    back.backgroundColor = MYXXAccent();
    return [UISwipeActionsConfiguration configurationWithActions:@[back]];
}
- (UIContextMenuConfiguration *)tableView:(UITableView *)t contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)p point:(CGPoint)point {
    id conversation = self.items[(NSUInteger)p.row];
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray *s) {
        (void)s;
        return [UIMenu menuWithChildren:@[[UIAction actionWithTitle:@"Return to Messages" image:[UIImage systemImageNamed:@"arrow.uturn.backward"] identifier:nil handler:^(UIAction *a) { (void)a; [self confirmReturn:conversation]; }]]];
    }];
}
@end

// ---- opening, with the optional device lock -----------------------------------------------------------------------------------------------
static void Present(UIViewController *host) {
    if (PrivateNav && !PrivateNav.presentingViewController) PrivateNav = nil;   // a list that is no longer on screen never blocks the gesture
    if (PrivateNav || host.presentedViewController) return;
    PMSessionBegin();
    PMListController *list = [PMListController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    MYXXStyleNavigation(nav);
    PrivateNav = nav;
    [host presentViewController:nav animated:YES completion:nil];
}
void PMOpenFromGesture(UIViewController *host) {
    if (PrivateNav && !PrivateNav.presentingViewController) PrivateNav = nil;
    if (!PMActive() || !host || PrivateNav) return;
    if (!PMLockOn()) { Present(host); return; }
    // Shared with Private Calls and Private Photos (PrivateUI.m, compiled into this dylib too) so all three ask the same way, with Face ID actually
    // offered rather than the passcode-only fallback a bare LAContext call gets in a host app that declares no NSFaceIDUsageDescription of its own.
    MYXXAuthenticate(host, @"Open Private Conversations", ^{ Present(TopController() ?: host); });
}

// ---- lock, cover ---------------------------------------------------------------------------------------------------------------------------
void PMLockAll(void) {
    PMSessionEnd();
    if (PrivateNav) {
        PrivateNav.view.hidden = YES;
        UIViewController *presenter = PrivateNav.presentingViewController;
        PrivateNav = nil;
        [presenter dismissViewControllerAnimated:NO completion:nil];
    }
    if (PMPrivateThreadVisible()) PMPopPrivateThread();
}
void PMCoverIfNeeded(void) {
    if (CoverWindow || !(PMSessionUnlocked() || PrivateNav || PMPrivateThreadVisible())) return;
    UIWindowScene *scene = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) if ([candidate isKindOfClass:UIWindowScene.class]) { scene = (UIWindowScene *)candidate; break; }
    if (!scene) return;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.windowLevel = UIWindowLevelAlert + 1000;
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = UIColor.clearColor;
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterialDark]];   // the screen behind, softly blurred
    blur.frame = root.view.bounds; blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIView *tint = [[UIView alloc] initWithFrame:blur.bounds]; tint.backgroundColor = [UIColor colorWithWhite:0 alpha:0.30]; tint.autoresizingMask = blur.autoresizingMask;
    [blur.contentView addSubview:tint];
    [root.view addSubview:blur];
    UIImageView *mark = [[UIImageView alloc] initWithImage:MYXXMarkImage()];
    mark.contentMode = UIViewContentModeScaleAspectFit;
    mark.frame = CGRectMake(0, 0, 84, 84);
    mark.center = CGPointMake(CGRectGetMidX(root.view.bounds), CGRectGetMidY(root.view.bounds));
    mark.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [root.view addSubview:mark];
    window.rootViewController = root;
    window.hidden = NO;
    CoverWindow = window;
}
void PMUncover(void) { CoverWindow.hidden = YES; CoverWindow = nil; }

// One short branded tip per launch, only on the ordinary list and only while the switch is on. "Replay Tips" in MYbloXX® Settings shows it again.
static BOOL TipShown;
void PMMaybeShowTip(UIViewController *host) {
    if (TipShown || !PMActive() || host.presentedViewController) return;
    TipShown = YES;
    NSArray *facts = @[
        @[@"Open", @"Tap the Messages title at the top five times."],
        @[@"Move", @"Open it once, go back, then press and hold a conversation and choose Move to Private."],
        @[@"Return", @"In the private list, swipe a conversation and choose Return, or press and hold it."],
        @[@"Please note", @"Conversations stay in Apple Messages. They show normally whenever MYbloXX® or the jailbreak is not active."]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *top = TopController();
        if (top && !top.presentedViewController) MYXXShowTipFactsOnce(top, @"messages", @"Private Conversations", @"A quiet way to keep a few threads out of the main list.", facts, @"lock.fill");
    });
}
