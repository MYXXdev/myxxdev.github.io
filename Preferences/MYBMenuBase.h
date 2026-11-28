#import <UIKit/UIKit.h>
@class MYBPrismCell;
// Shared base for every MYbloXX settings screen: grouped table (headers and
// footers scroll with the content and never float over cards), reusable
// cards, one self-sizing hero, one helper runner.
@interface MYBMenuBase : UITableViewController
@property(nonatomic,strong) NSArray<NSDictionary *> *menuSections;
@property(nonatomic,assign) BOOL busy;
@property(nonatomic,strong) UILabel *subTitleLabel; // the small bar title of a subpage: hidden at rest, fades in as the large hero title scrolls under the bar, like the main screen
@property(nonatomic,strong) UIView *subTitleHost;
@property(nonatomic,weak) UILabel *heroNameLabel;
@property(nonatomic,assign) BOOL mybBuildingTitle;
@property(nonatomic,assign) BOOL revealed;
@property(nonatomic,assign) CFTimeInterval enterUntil; // while now is before this, rows glide in as they are first shown
@property(nonatomic,assign) NSUInteger enterCount;
@property(nonatomic,strong) NSMutableSet<NSString *> *entered; // rows that already glided in: a reload never replays it
// Runs a read-only helper action in the background: no progress UI, no menu rebuild, never sets `busy`. Completion on main.
- (void)silentHelper:(NSArray<NSString *> *)args completion:(void(^)(int))completion;
@property(nonatomic,assign) BOOL backupSyncPending;
@property(nonatomic,assign) BOOL completingHelper;
@property(nonatomic,assign) int lastHelperResult;
// The view controller whose navigation item carries this screen's bar title and
// buttons. Normally self; the dashboard is embedded in a PreferenceLoader parent.
@property(nonatomic,weak) UIViewController *chromeOwner;
// Custom section text stays separate from UIKit data-source titles, which
// otherwise populate default labels over our custom header/footer views.
- (NSString *)sectionHeaderTitle:(NSInteger)section;
- (NSString *)sectionFooterTitle:(NSInteger)section;
- (void)rebuildMenu;
// Page memory for Settings relaunches. A screen on the allow-list below is remembered (class, list selection, scroll position) while it is
// open. iOS reopens the MYbloXX® pane at its main screen after it relaunches Settings, and the saved route puts the person back. A screen
// that could replay an action (a PIN screen, a confirmation) is never on the list. See MYBNavSave / MYBNavRestore.
- (NSDictionary *)mybNavExtras;
- (void)mybApplyNavExtras:(NSDictionary *)extras;
- (void)mybRefreshInPlace;
- (void)mybRebuildKeepingOffset;
- (void)refreshFilesBackup;
- (void)showMessage:(NSString *)title detail:(NSString *)detail;
- (void)confirm:(NSString *)title message:(NSString *)message action:(void(^)(void))action;
- (void)offerRemoveMYbloXXProfileThen:(void(^)(int))completion;
- (void)runHelper:(NSArray<NSString *> *)args completion:(void(^)(int))completion;
- (void)askPINForScope:(NSString *)scope then:(void(^)(BOOL authorised))then;
// Hero header: subclasses override these (or -makeHero) instead of managing the table header.
- (NSString *)heroEyebrow;
- (NSString *)heroTitle;
- (NSString *)heroDetail;
- (UIView *)makeHero;
- (void)refreshHero;
// A fully configured reusable card for a menuSections entry.
- (MYBPrismCell *)cardForEntry:(NSDictionary *)entry table:(UITableView *)table;
- (void)offerProfileSwitchForResult:(int)rc args:(NSArray<NSString *> *)args completion:(void(^)(int))completion;
- (void)presentProfileOfferForResult:(int)rc identifier:(NSString *)identifier viaSettings:(BOOL)viaSettings completion:(void(^)(int))completion;
- (void)offerOldProfileIfPresent;
@end

void MYBNavSave(UINavigationController *nav);
void MYBNavClear(void);
BOOL MYBNavRestore(UINavigationController *nav);
