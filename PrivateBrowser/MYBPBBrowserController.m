#import "MYBPBBrowserController.h"
#import <WebKit/WebKit.h>

// ---- a single tab: just a web view plus the bits of state the UI needs to show about it -----------------------
@interface MYBPBTab : NSObject
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,copy) NSString *title;
@end
@implementation MYBPBTab
@end

// ---- the tab switcher: a plain table, one row per tab, swipe to close, "+" to add ------------------------------
@protocol MYBPBTabListDelegate <NSObject>
- (NSArray<MYBPBTab *> *)tabListTabs;
- (NSInteger)tabListCurrentIndex;
- (void)tabListDidSelectIndex:(NSInteger)index;
- (void)tabListDidCloseIndex:(NSInteger)index;
- (void)tabListDidRequestNewTab;
@end
@interface MYBPBTabListController : UITableViewController
@property(nonatomic,weak) id<MYBPBTabListDelegate> listDelegate;
@end
@implementation MYBPBTabListController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tabs";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneTapped)];
    self.tableView.backgroundColor = [UIColor colorWithRed:0.04 green:0.08 blue:0.09 alpha:1.0];
}
- (void)addTapped { [self.listDelegate tabListDidRequestNewTab]; [self.navigationController popViewControllerAnimated:YES]; }
- (void)doneTapped { [self.navigationController popViewControllerAnimated:YES]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { (void)tv; (void)section; return [self.listDelegate tabListTabs].count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"tab"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tab"];
    MYBPBTab *tab = [self.listDelegate tabListTabs][(NSUInteger)ip.row];
    cell.backgroundColor = UIColor.clearColor;
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    cell.textLabel.text = tab.title.length ? tab.title : @"New Tab";
    cell.detailTextLabel.text = tab.webView.URL.absoluteString.length ? tab.webView.URL.absoluteString : @"about:blank";
    cell.accessoryType = (ip.row == [self.listDelegate tabListCurrentIndex]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    [self.listDelegate tabListDidSelectIndex:ip.row];
    [self.navigationController popViewControllerAnimated:YES];
}
- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { (void)tv; (void)ip; return YES; }
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    [self.listDelegate tabListDidCloseIndex:ip.row];
    [tv reloadData];
}
@end

// ---- the browser itself -----------------------------------------------------------------------------------------
@interface MYBPBBrowserController () <UITextFieldDelegate, WKNavigationDelegate, WKUIDelegate, MYBPBTabListDelegate>
@property(nonatomic,strong) NSMutableArray<MYBPBTab *> *tabs;
@property(nonatomic) NSInteger currentIndex;
@property(nonatomic,strong) UIView *webContainer;
@property(nonatomic,strong) UITextField *addressField;
@property(nonatomic,strong) UIButton *backButton;
@property(nonatomic,strong) UIButton *forwardButton;
@property(nonatomic,strong) UIButton *reloadButton;
@property(nonatomic,strong) UIButton *tabsButton;
@property(nonatomic,strong) UIProgressView *progressView;
@end

@implementation MYBPBBrowserController

// One ephemeral store for the whole app's lifetime: every tab's WKWebViewConfiguration points at this same instance,
// so tabs can share a logged-in session the way ordinary "Private Browsing" does, but absolutely nothing -- cookies,
// cache, local storage, IndexedDB, service workers -- ever reaches disk, and all of it disappears the moment the
// process exits (or MYBPBBrowserController purgeEphemeralData runs, which can be sooner than that).
+ (WKWebsiteDataStore *)sharedDataStore {
    static WKWebsiteDataStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [WKWebsiteDataStore nonPersistentDataStore]; });
    return store;
}
+ (void)purgeEphemeralData {
    WKWebsiteDataStore *store = [self sharedDataStore];
    [store fetchDataRecordsOfTypes:WKWebsiteDataStore.allWebsiteDataTypes completionHandler:^(NSArray<WKWebsiteDataRecord *> *records) {
        if (!records.count) return;
        [store removeDataOfTypes:WKWebsiteDataStore.allWebsiteDataTypes forDataRecords:records completionHandler:^{}];
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.08 blue:0.09 alpha:1.0];
    self.tabs = [NSMutableArray array];
    self.currentIndex = -1;
    [self buildChrome];
    [self openNewTabWithConfiguration:nil request:nil makeCurrent:YES];
}

// ---- chrome: address bar on top, toolbar on bottom, web view fills the middle -----------------------------------
- (void)buildChrome {
    UIView *top = [UIView new];
    top.backgroundColor = [UIColor colorWithRed:0.07 green:0.13 blue:0.14 alpha:1.0];
    top.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:top];

    self.addressField = [UITextField new];
    self.addressField.placeholder = @"Search or enter address -- nothing is saved";
    self.addressField.textColor = UIColor.whiteColor;
    self.addressField.tintColor = [UIColor colorWithRed:0.44 green:0.78 blue:0.70 alpha:1.0];
    self.addressField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.addressField.placeholder attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:1.0 alpha:0.4]}];
    self.addressField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.addressField.layer.cornerRadius = 10;
    self.addressField.keyboardType = UIKeyboardTypeWebSearch;
    self.addressField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.addressField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.addressField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.addressField.returnKeyType = UIReturnKeyGo;
    self.addressField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.addressField.delegate = self;
    UIView *padding = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,10)];
    self.addressField.leftView = padding; self.addressField.leftViewMode = UITextFieldViewModeAlways;
    self.addressField.translatesAutoresizingMaskIntoConstraints = NO;
    [top addSubview:self.addressField];

    self.progressView = [UIProgressView new];
    self.progressView.progressTintColor = [UIColor colorWithRed:0.44 green:0.78 blue:0.70 alpha:1.0];
    self.progressView.trackTintColor = UIColor.clearColor;
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.alpha = 0;
    [top addSubview:self.progressView];

    self.webContainer = [UIView new];
    self.webContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.webContainer];

    UIView *bottom = [UIView new];
    bottom.backgroundColor = top.backgroundColor;
    bottom.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bottom];

    self.backButton = [self toolbarButton:@"chevron.left" action:@selector(goBack)];
    self.forwardButton = [self toolbarButton:@"chevron.right" action:@selector(goForward)];
    self.reloadButton = [self toolbarButton:@"arrow.clockwise" action:@selector(reload)];
    self.tabsButton = [self toolbarButton:@"square.on.square" action:@selector(showTabs)];
    UIButton *wipeButton = [self toolbarButton:@"flame" action:@selector(wipeEverything)];
    UIButton *newTabButton = [self toolbarButton:@"plus" action:@selector(newTabTapped)];
    NSArray<UIButton *> *buttons = @[self.backButton, self.forwardButton, self.reloadButton, newTabButton, self.tabsButton, wipeButton];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:buttons];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.distribution = UIStackViewDistributionFillEqually;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [bottom addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [top.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [top.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [top.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [top.heightAnchor constraintEqualToConstant:52],

        [self.addressField.leadingAnchor constraintEqualToAnchor:top.leadingAnchor constant:10],
        [self.addressField.trailingAnchor constraintEqualToAnchor:top.trailingAnchor constant:-10],
        [self.addressField.centerYAnchor constraintEqualToAnchor:top.centerYAnchor constant:-2],
        [self.addressField.heightAnchor constraintEqualToConstant:36],

        [self.progressView.leadingAnchor constraintEqualToAnchor:top.leadingAnchor],
        [self.progressView.trailingAnchor constraintEqualToAnchor:top.trailingAnchor],
        [self.progressView.bottomAnchor constraintEqualToAnchor:top.bottomAnchor],
        [self.progressView.heightAnchor constraintEqualToConstant:2],

        [self.webContainer.topAnchor constraintEqualToAnchor:top.bottomAnchor],
        [self.webContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webContainer.bottomAnchor constraintEqualToAnchor:bottom.topAnchor],

        [bottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bottom.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bottom.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [bottom.heightAnchor constraintEqualToConstant:50],

        [stack.topAnchor constraintEqualToAnchor:bottom.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:bottom.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:bottom.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];
}
- (UIButton *)toolbarButton:(NSString *)systemImage action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:systemImage] forState:UIControlStateNormal];
    b.tintColor = UIColor.whiteColor;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

// ---- tabs ----------------------------------------------------------------------------------------------------
- (MYBPBTab *)currentTab { return (self.currentIndex >= 0 && self.currentIndex < (NSInteger)self.tabs.count) ? self.tabs[(NSUInteger)self.currentIndex] : nil; }

- (void)openNewTabWithConfiguration:(WKWebViewConfiguration *)suppliedConfig request:(NSURLRequest *)request makeCurrent:(BOOL)makeCurrent {
    WKWebViewConfiguration *config = suppliedConfig ?: [WKWebViewConfiguration new];
    config.websiteDataStore = [self.class sharedDataStore];   // every tab, new or window.open()'d, shares the one ephemeral store
    config.allowsInlineMediaPlayback = YES;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.webContainer.bounds configuration:config];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.navigationDelegate = self;   // wrapped transparently by MYbloXX's Shield hook once injected into this app
    webView.UIDelegate = self;
    webView.allowsBackForwardNavigationGestures = YES;
    [webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];

    MYBPBTab *tab = [MYBPBTab new];
    tab.webView = webView;
    tab.title = @"New Tab";
    [self.tabs addObject:tab];
    if (request) [webView loadRequest:request];
    if (makeCurrent) [self switchToIndex:(NSInteger)self.tabs.count - 1];
}
- (void)switchToIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) return;
    [self.currentTab.webView removeFromSuperview];
    self.currentIndex = index;
    WKWebView *webView = self.currentTab.webView;
    webView.frame = self.webContainer.bounds;
    [self.webContainer addSubview:webView];
    self.addressField.text = webView.URL.absoluteString;
    [self updateBackForwardButtons];
}
- (void)closeIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.tabs.count) return;
    MYBPBTab *tab = self.tabs[(NSUInteger)index];
    [tab.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    [tab.webView removeFromSuperview];
    [tab.webView stopLoading];
    [self.tabs removeObjectAtIndex:(NSUInteger)index];
    if (!self.tabs.count) { [self openNewTabWithConfiguration:nil request:nil makeCurrent:YES]; return; }
    NSInteger newIndex = MIN(index, (NSInteger)self.tabs.count - 1);
    self.currentIndex = -1;   // force switchToIndex to actually re-add the (possibly same-index) webview
    [self switchToIndex:newIndex];
}
- (void)newTabTapped { [self openNewTabWithConfiguration:nil request:nil makeCurrent:YES]; [self.addressField becomeFirstResponder]; }
- (void)showTabs {
    MYBPBTabListController *list = [[MYBPBTabListController alloc] initWithStyle:UITableViewStylePlain];
    list.listDelegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:list];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    [self presentViewController:nav animated:YES completion:nil];
}
- (NSArray<MYBPBTab *> *)tabListTabs { return self.tabs; }
- (NSInteger)tabListCurrentIndex { return self.currentIndex; }
- (void)tabListDidSelectIndex:(NSInteger)index { [self switchToIndex:index]; }
- (void)tabListDidCloseIndex:(NSInteger)index { [self closeIndex:index]; }
- (void)tabListDidRequestNewTab { [self openNewTabWithConfiguration:nil request:nil makeCurrent:YES]; }

// "Wipe": the explicit, visible panic button -- closes every tab, purges every in-memory record from the shared
// store right now, and starts over with one blank tab. A user doesn't have to quit the app to get a clean slate.
- (void)wipeEverything {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Wipe Everything?" message:@"Closes every tab and clears all in-memory browsing data right now." preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weak = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Wipe" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { (void)a; [weak performWipe]; }]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:confirm animated:YES completion:nil];
}
- (void)performWipe {
    for (MYBPBTab *tab in self.tabs) { [tab.webView removeObserver:self forKeyPath:@"estimatedProgress"]; [tab.webView stopLoading]; [tab.webView removeFromSuperview]; }
    [self.tabs removeAllObjects];
    self.currentIndex = -1;
    [self.class purgeEphemeralData];
    [self openNewTabWithConfiguration:nil request:nil makeCurrent:YES];
}

// ---- navigation controls ---------------------------------------------------------------------------------------
- (void)goBack { [self.currentTab.webView goBack]; }
- (void)goForward { [self.currentTab.webView goForward]; }
- (void)reload { [self.currentTab.webView reload]; }
- (void)updateBackForwardButtons {
    self.backButton.enabled = self.currentTab.webView.canGoBack;
    self.forwardButton.enabled = self.currentTab.webView.canGoForward;
    self.backButton.alpha = self.backButton.enabled ? 1.0 : 0.3;
    self.forwardButton.alpha = self.forwardButton.enabled ? 1.0 : 0.3;
}

// ---- address bar: a bare URL goes straight through; anything else is a DuckDuckGo search (no first-party
// MYbloXX search/telemetry involved -- this just asks a privacy-respecting search engine, same as typing it there) --
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSString *text = [textField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [textField resignFirstResponder];
    if (!text.length) return YES;
    NSURL *url = [self urlForAddressBarText:text];
    [self.currentTab.webView loadRequest:[NSURLRequest requestWithURL:url]];
    return YES;
}
- (NSURL *)urlForAddressBarText:(NSString *)text {
    BOOL looksLikeURL = [text containsString:@"."] && ![text containsString:@" "];
    NSString *withScheme = text;
    if (looksLikeURL && ![text.lowercaseString hasPrefix:@"http://"] && ![text.lowercaseString hasPrefix:@"https://"]) withScheme = [@"https://" stringByAppendingString:text];
    NSURL *candidate = looksLikeURL ? [NSURL URLWithString:withScheme] : nil;
    if (candidate && candidate.host.length) return candidate;
    NSString *encoded = [text stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet] ?: text;
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://duckduckgo.com/html/?q=%@", encoded]];
}

// ---- WKNavigationDelegate / progress -----------------------------------------------------------------------------
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    (void)change; (void)context;
    if (![keyPath isEqualToString:@"estimatedProgress"] || object != self.currentTab.webView) return;
    float p = (float)self.currentTab.webView.estimatedProgress;
    self.progressView.alpha = (p >= 1.0) ? 0 : 1;
    [self.progressView setProgress:p animated:YES];
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)navigation;
    if (webView != self.currentTab.webView) return;
    self.addressField.text = webView.URL.absoluteString;
    self.currentTab.title = webView.title.length ? webView.title : self.currentTab.title;
    [self updateBackForwardButtons];
}
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { (void)webView; (void)navigation; (void)error; [self updateBackForwardButtons]; }
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { (void)webView; (void)navigation; (void)error; [self updateBackForwardButtons]; }

// ---- WKUIDelegate: target=_blank / window.open() become new tabs, and basic JS dialogs actually work -------------
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    (void)webView; (void)windowFeatures;
    __block WKWebView *created = nil;
    [self openNewTabWithConfiguration:configuration request:nil makeCurrent:YES];
    created = self.currentTab.webView;
    if (navigationAction.request.URL) [created loadRequest:navigationAction.request];
    return created;
}
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    (void)webView; (void)frame;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { (void)a; completionHandler(); }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    (void)webView; (void)frame;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) { (void)a; completionHandler(NO); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { (void)a; completionHandler(YES); }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc {
    for (MYBPBTab *tab in self.tabs) [tab.webView removeObserver:self forKeyPath:@"estimatedProgress"];
}

@end
