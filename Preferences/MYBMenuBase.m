#import "MYBMenuBase.h"
#import <QuartzCore/QuartzCore.h>
#import "../Shared/MYBPinClient.h"
#import "MYBDesign.h"
#import "../Shared/MYBOutcomeText.h"
#import "../Shared/MYBProfileService.h"
#import "../Shared/MYBMYbloXXProfile.h"
#import "../Shared/MYBProfileMigration.h"
#import <sys/stat.h>
#import <fcntl.h>
#import <spawn.h>
#import <math.h>
#import <errno.h>
#import <signal.h>
#import <sys/wait.h>
extern char **environ;

// A helper that has not finished after this long is terminated so Settings can
// never sit behind a spinner forever. (Network checks inside the helper time out
// after 18 seconds per request.)
static const NSTimeInterval kMYBHelperTimeout=150;

static NSString *const kHeaderID=@"MYBSectionHeader";
static NSString *const kFooterID=@"MYBSectionFooter";

@implementation MYBMenuBase
- (instancetype)init {return [super initWithStyle:UITableViewStyleGrouped];}
- (UIViewController *)chrome{return self.chromeOwner?:self;}
- (NSString *)heroEyebrow{return nil;}
- (NSString *)heroTitle{return self.title;}
- (NSString *)heroDetail{return nil;}
// Every screen gets the same badge header: a gradient symbol, the screen name and one summary line. The symbol and colour come from this
// table, so a new screen only has to be listed here. A screen with no entry keeps the plain summary line.
static NSDictionary *MYBHeroStyle(NSString *cls){
 static NSDictionary *table;static dispatch_once_t once;dispatch_once(&once,^{table=@{
  @"MYBRulesController":@[@"list.bullet.rectangle.fill",@(MYBToneViolet)],@"MYBActivityController":@[@"waveform.path.ecg",@(MYBToneViolet)],@"MYBActivityAppController":@[@"app.badge.fill",@(MYBToneIndigo)],@"MYBActivityDomainsController":@[@"globe",@(MYBToneBlue)],
  @"MYBPopupControlController":@[@"macwindow.on.rectangle",@(MYBToneRose)],@"MYBRedirectController":@[@"arrow.triangle.branch",@(MYBToneAmber)],@"MYBMoreSettingsController":@[@"ellipsis.circle.fill",@(MYBToneSlate)],@"MYBBackupUpdatesController":@[@"externaldrive.fill",@(MYBToneBlue)],@"MYBAppSwitchActivityController":@[@"bolt.fill",@(MYBToneAmber)],@"MYBAppControlController":@[@"bolt.fill",@(MYBToneAmber)],@"MYBInAppAdsController":@[@"nosign",@(MYBToneRose)],
  @"MYBDNSController":@[@"globe.europe.africa.fill",@(MYBToneBlue)],@"MYBProxyOverrideController":@[@"network",@(MYBToneIndigo)],@"MYBLegacyController":@[@"lock.shield.fill",@(MYBToneSlate)],
  @"MYBPinController":@[@"lock.fill",@(MYBToneAmber)],@"MYBUpdatesController":@[@"arrow.down.circle.fill",@(MYBToneGreen)],@"MYBBackupController":@[@"externaldrive.fill",@(MYBToneTeal)],
  @"MYBTroubleshootingController":@[@"wrench.and.screwdriver.fill",@(MYBToneBlue)],@"MYBHelpTopicController":@[@"book.fill",@(MYBToneViolet)],
  @"MYBDiagnosticsController":@[@"checkmark.circle.fill",@(MYBToneGreen)],@"MYBModeInfoController":@[@"slider.horizontal.3",@(MYBToneIndigo)],@"MYBPopupStrictnessController":@[@"macwindow.on.rectangle",@(MYBToneRose)],
  @"MYBNetworkHubController":@[@"point.3.connected.trianglepath.dotted",@(MYBToneBlue)],@"MYBKeepFreshHubController":@[@"arrow.triangle.2.circlepath",@(MYBToneGreen)], @"MYBAppControlTraceController":@[@"bolt.horizontal.fill",@(MYBToneSlate)],
  @"MYBAdvancedController":@[@"gearshape.2.fill",@(MYBToneSlate)],@"MYBConnectivityController":@[@"antenna.radiowaves.left.and.right",@(MYBToneBlue)],@"MYBExtraPrivacyController":@[@"hand.raised.fill",@(MYBToneViolet)],
  @"MYBPrivateItemsController":@[@"lock.rectangle.stack.fill",@(MYBToneIndigo)],@"MYBAppLockController":@[@"lock.app.dashed",@(MYBToneViolet)],@"MYBLockAppPicker":@[@"checklist",@(MYBToneViolet)],@"MYBNotifPrivacyController":@[@"bell.badge.slash.fill",@(MYBToneRose)],
  @"MYBReserveController":@[@"battery.25",@(MYBToneViolet)],@"MYBCleanShareController":@[@"square.and.arrow.up.fill",@(MYBToneTeal)],@"MYBSafariCleanupController":@[@"wand.and.stars",@(MYBToneTeal)],@"MYBLocalNetworkController":@[@"network",@(MYBToneBlue)],@"MYBDiagSessionController":@[@"stethoscope",@(MYBToneBlue)],
  @"MYBFirewallController":@[@"shield.lefthalf.filled",@(MYBToneGreen)]};});
 return @{@"symbol":table[cls][0]?:@"",@"tone":table[cls][1]?:@0};
}
- (UIView *)makeHero{
 NSDictionary *style=MYBHeroStyle(NSStringFromClass(self.class));NSString *symbol=style[@"symbol"];
 if(symbol.length&&[self heroTitle].length)return MYBHeroBadge(symbol,(MYBTone)[style[@"tone"] integerValue],[self heroTitle],[self heroDetail]);
 return MYBHero([self heroEyebrow],[self heroTitle],[self heroDetail],YES);
}
- (void)viewDidLoad {
 [super viewDidLoad];
 self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
 self.view.backgroundColor=MYBBackground();
 MYBStyleTable(self.tableView);
 self.tableView.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;
 [self.tableView registerClass:MYBSectionHeaderView.class forHeaderFooterViewReuseIdentifier:kHeaderID];
 [self.tableView registerClass:MYBSectionFooterView.class forHeaderFooterViewReuseIdentifier:kFooterID];
 [self rebuildMenu];
 [self refreshHero];
 [self mybEnsureSubpageTitle];
 MYBStyleNavigation([self chrome]); // before the first frame: the bar never shows the system default and then restyles
}
// A subpage reveals its small bar title at the same point the main screen does: from the middle of the large hero title to its bottom edge.
- (BOOL)mybRevealsTitle{return self.chromeOwner==nil&&(![self isViewLoaded]||[self heroTitle].length>0);}
static UILabel *MYBHeroTitleLabel(UIView *root,NSString *text,int depth){
 if([root isKindOfClass:UILabel.class]&&[((UILabel *)root).text isEqualToString:text]&&((UILabel *)root).font.pointSize>=24)return (UILabel *)root;
 if(depth>6)return nil;
 for(UIView *sub in root.subviews){UILabel *found=MYBHeroTitleLabel(sub,text,depth+1);if(found)return found;}
 return nil;
}
// The bar reads the navigation item when the screen is pushed, before viewDidLoad. The faded title is therefore made the first time the item is
// asked for, and again whenever the title changes, so the bar never shows the system title for a frame and then swaps it.
- (UINavigationItem *)navigationItem{
 UINavigationItem *item=[super navigationItem];
 if(!self.mybBuildingTitle){self.mybBuildingTitle=YES;[self mybEnsureSubpageTitleOn:item];self.mybBuildingTitle=NO;}
 return item;
}
- (void)setTitle:(NSString *)title{[super setTitle:title];if(!self.mybBuildingTitle)[self mybEnsureSubpageTitle];}
- (void)mybEnsureSubpageTitle{self.mybBuildingTitle=YES;[self mybEnsureSubpageTitleOn:self.navigationItem];self.mybBuildingTitle=NO;}
- (void)mybEnsureSubpageTitleOn:(UINavigationItem *)item{
 if(self.chromeOwner!=nil){if(self.subTitleHost&&item.titleView==self.subTitleHost)item.titleView=nil;return;}
 if(!self.subTitleLabel){
  UILabel *label=[UILabel new];label.textColor=UIColor.whiteColor;label.font=[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];label.alpha=0;label.isAccessibilityElement=YES;label.accessibilityTraits=UIAccessibilityTraitHeader;
  self.subTitleLabel=label;UIView *host=[UIView new];host.isAccessibilityElement=NO;[host addSubview:label];self.subTitleHost=host;
 }
 NSString *text=self.title.length?self.title:([self isViewLoaded]?[self heroTitle]:nil)?:@"";
 if(![self.subTitleLabel.text isEqualToString:text]){self.subTitleLabel.text=text;[self.subTitleLabel sizeToFit];self.subTitleHost.frame=self.subTitleLabel.bounds;}
 if(item.titleView!=self.subTitleHost)item.titleView=self.subTitleHost;
}
- (void)scrollViewDidScroll:(UIScrollView *)scroll{
 if(!self.subTitleLabel)return;
 CGFloat moved=scroll.contentOffset.y+scroll.adjustedContentInset.top; // 0 at rest
 CGFloat start=34,end=64;UIView *header=self.tableView.tableHeaderView;
 UILabel *name=self.heroNameLabel;
 if(header&&(!name||![name isDescendantOfView:header])){name=MYBHeroTitleLabel(header,[self heroTitle],0);self.heroNameLabel=name;} // searched once per header, not on every scroll tick
 if(name.window){CGRect r=[name convertRect:name.bounds toView:header];CGRect h=[header convertRect:r toView:self.tableView];start=CGRectGetMidY(h);end=MAX(start+1,CGRectGetMaxY(h));}
 CGFloat alpha=MAX(0,MIN(1,(moved-start)/(end-start)));
 if(self.subTitleLabel.alpha!=alpha)self.subTitleLabel.alpha=alpha;
}
- (void)refreshHero{
 if(![self heroTitle].length)return;
 UIView *hero=[self makeHero];
 CGFloat width=self.tableView.bounds.size.width;
 if(width<=0)width=UIScreen.mainScreen.bounds.size.width;
 CGSize size=[hero systemLayoutSizeFittingSize:CGSizeMake(width,UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
 hero.frame=CGRectMake(0,0,width,ceil(size.height));
 self.tableView.tableHeaderView=hero;
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 // Re-measure only when the width changed (rotation, split view, text size);
 // reassigning on every pass is what made earlier headers re-layout repeatedly.
 UIView *header=self.tableView.tableHeaderView;CGFloat width=self.tableView.bounds.size.width;
 if(!header||width<=0||fabs(header.bounds.size.width-width)<=.5)return;
 CGSize size=[header systemLayoutSizeFittingSize:CGSizeMake(width,UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
 header.frame=CGRectMake(0,0,width,ceil(size.height));self.tableView.tableHeaderView=header;
}
// ---- page memory -----------------------------------------------------------------------------------------------------------------------
// What triggers the "jump to the main screen"? Nothing in MYbloXX® pops its navigation stack: no lifecycle callback, notification or refresh in
// this component calls popToRoot, setViewControllers or rebuilds the stack. The stack is lost only when iOS terminates Settings and starts it
// again; the pane then opens at its main screen because the pushed pages are plain UIKit pushes the system knows nothing about. So:
//  - a normal return keeps the stack as it is, and the visible screen refreshes in place (mybRefreshInPlace);
//  - a relaunch is repaired from this small saved route, validated before use.
static NSString *MYBNavFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.nav.plist");}
static NSSet<NSString *> *MYBNavClasses(void){
 static NSSet *set;static dispatch_once_t once;dispatch_once(&once,^{set=[NSSet setWithArray:@[@"MYBRulesController",@"MYBPopupControlController",@"MYBPopupAllowedController",@"MYBPopupBlockedController",@"MYBPopupRecentController",@"MYBRedirectController",@"MYBMoreSettingsController",@"MYBBackupUpdatesController",@"MYBAdvancedController",@"MYBConnectivityController",@"MYBExtraPrivacyController",@"MYBAppControlController",@"MYBAppSwitchActivityController",@"MYBInAppAdsController",@"MYBDNSController",@"MYBUpdatesController",@"MYBTroubleshootingController",@"MYBActivityController"]];});
 return set;
}
static BOOL MYBNavIsRoot(UIViewController *vc){return [NSStringFromClass(vc.class) isEqual:@"MYBModernController"];}
void MYBNavClear(void){[NSFileManager.defaultManager removeItemAtPath:MYBNavFile() error:NULL];}
void MYBNavSave(UINavigationController *nav){
 if(!nav)return;
 NSMutableArray *route=[NSMutableArray array];BOOL inside=NO;MYBMenuBase *top=nil;
 for(UIViewController *vc in nav.viewControllers){
  if(!inside){if(MYBNavIsRoot(vc))inside=YES;continue;}
  if(![MYBNavClasses() containsObject:NSStringFromClass(vc.class)]||![vc isKindOfClass:MYBMenuBase.class])break; // a screen that is not remembered ends the route there
  [route addObject:NSStringFromClass(vc.class)];top=(MYBMenuBase *)vc;
 }
 if(!inside)return;
 if(!route.count){MYBNavClear();return;}
 NSMutableDictionary *state=[@{@"version":@1,@"route":route,@"time":@(NSDate.date.timeIntervalSince1970)} mutableCopy];
 if(top&&top.isViewLoaded){CGFloat y=top.tableView.contentOffset.y+top.tableView.adjustedContentInset.top;if(y>0)state[@"offset"]=@(y);NSDictionary *extras=[top mybNavExtras];if(extras.count)state[@"extras"]=extras;}
 [state writeToFile:MYBNavFile() atomically:YES];
}
// Opens the remembered route, without animation, on top of the MYbloXX® main screen. Returns NO when there is nothing valid to open: the main
// screen then simply stays. Nothing but navigation is replayed: no action, confirmation, sheet, PIN prompt or typed text is ever restored.
BOOL MYBNavRestore(UINavigationController *nav){
 NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:MYBNavFile()];if(!state||!nav)return NO;
 NSArray *route=state[@"route"];double saved=[state[@"time"] doubleValue];
 BOOL valid=[state[@"version"] isEqual:@1]&&[route isKindOfClass:NSArray.class]&&route.count>0&&route.count<=6&&saved>0&&NSDate.date.timeIntervalSince1970-saved<12*3600&&saved<=NSDate.date.timeIntervalSince1970+60;
 NSMutableArray<UIViewController *> *pages=[NSMutableArray array];
 for(id name in valid?route:@[]){
  Class c=[name isKindOfClass:NSString.class]&&[MYBNavClasses() containsObject:name]?NSClassFromString(name):Nil;
  if(!c||![c isSubclassOfClass:MYBMenuBase.class]){valid=NO;break;}
  [pages addObject:[c new]];
 }
 if(!valid||!pages.count){MYBNavClear();return NO;}
 for(UIViewController *page in pages)[nav pushViewController:page animated:NO];
 MYBMenuBase *top=(MYBMenuBase *)pages.lastObject;NSDictionary *extras=state[@"extras"];CGFloat offset=[state[@"offset"] doubleValue];
 dispatch_async(dispatch_get_main_queue(),^{
  if([extras isKindOfClass:NSDictionary.class])[top mybApplyNavExtras:extras];
  if(offset>0&&top.isViewLoaded){[top.tableView layoutIfNeeded];CGFloat topInset=top.tableView.adjustedContentInset.top,maxY=MAX(-topInset,top.tableView.contentSize.height-top.tableView.bounds.size.height+top.tableView.adjustedContentInset.bottom);top.tableView.contentOffset=CGPointMake(0,MIN(maxY,offset-topInset));}
 });
 return YES;
}
- (NSDictionary *)mybNavExtras{return nil;}
- (void)mybApplyNavExtras:(NSDictionary *)extras{(void)extras;}
static __weak MYBMenuBase *MYBNavTop; // the remembered screen on screen now, for the background save
static void MYBNavWatchBackground(void){
 static dispatch_once_t once;dispatch_once(&once,^{
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *n){(void)n;MYBMenuBase *top=MYBNavTop;if(top.isViewLoaded&&top.view.window)MYBNavSave(top.navigationController);}];
 });
}
- (void)mybRefreshInPlace{
 if(!self.isViewLoaded||!self.view.window||self.presentedViewController||self.busy)return;
 CGPoint offset=self.tableView.contentOffset;
 [UIView performWithoutAnimation:^{[self rebuildMenu];[self.tableView layoutIfNeeded];CGFloat top=-self.tableView.adjustedContentInset.top,maxY=MAX(top,self.tableView.contentSize.height-self.tableView.bounds.size.height+self.tableView.adjustedContentInset.bottom);self.tableView.contentOffset=CGPointMake(offset.x,MIN(MAX(top,offset.y),maxY));}];
}
- (void)mybRebuildKeepingOffset{
 CGPoint offset=self.tableView.contentOffset;
 [UIView performWithoutAnimation:^{[self rebuildMenu];[self.tableView layoutIfNeeded];CGFloat top=-self.tableView.adjustedContentInset.top,maxY=MAX(top,self.tableView.contentSize.height-self.tableView.bounds.size.height+self.tableView.adjustedContentInset.bottom);self.tableView.contentOffset=CGPointMake(offset.x,MIN(MAX(top,offset.y),maxY));}];
}
- (void)mybWillEnterForeground:(NSNotification *)note{(void)note;[self mybRefreshInPlace];}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];[self.tableView flashScrollIndicators];
 if([MYBNavClasses() containsObject:NSStringFromClass(self.class)]){MYBNavWatchBackground();MYBNavTop=self;MYBNavSave(self.navigationController);}
 [NSNotificationCenter.defaultCenter removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(mybWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
 MYBMotionScreenAppeared();
 // No entrance animation after arrival: fading rows to 0 and sliding them back once the push transition had finished
 // was the visible "jump" when opening a menu. The navigation transition itself is the entrance.
}
- (void)viewWillDisappear:(BOOL)animated{
 [super viewWillDisappear:animated];
 [NSNotificationCenter.defaultCenter removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
 MYBMotionScreenDisappeared();
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous{
 [super traitCollectionDidChange:previous];
 if(![previous.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]&&self.isViewLoaded){[self refreshHero];[self.tableView reloadData];}
}
- (void)viewWillAppear:(BOOL)animated {
 [super viewWillAppear:animated];
 // The first time a screen is shown its rows glide in one after another, starting while the push is still moving, so there is no jump afterwards.
 if(MYBMotionAllowed()&&self.enterUntil==0){self.enterUntil=CACurrentMediaTime()+1.1;self.enterCount=0;}
 // viewDidLoad already built the menu. Building it again here replaced every cell in the middle of the push transition
 // (a second layout pass, and a reset scroll position). Later appearances refresh it, keeping the scroll position.
 if(self.revealed){
  CGPoint offset=self.tableView.contentOffset;
  [UIView performWithoutAnimation:^{[self rebuildMenu];[self.tableView layoutIfNeeded];CGFloat top=-self.tableView.adjustedContentInset.top,maxY=MAX(top,self.tableView.contentSize.height-self.tableView.bounds.size.height+self.tableView.adjustedContentInset.bottom);self.tableView.contentOffset=CGPointMake(offset.x,MIN(MAX(offset.y,top),maxY));}];
 }
 self.revealed=YES;
 [self mybEnsureSubpageTitle];[self scrollViewDidScroll:self.tableView]; // a restored scroll position shows the right title state at once
 MYBStyleNavigation([self chrome]);
}
- (void)rebuildMenu {
 self.menuSections=@[];
 [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {return self.menuSections.count;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
 NSArray *rows=self.menuSections[section][@"rows"];
 return rows.count;
}
- (NSString *)sectionHeaderTitle:(NSInteger)section {
 return self.menuSections[section][@"title"];
}
- (NSString *)sectionFooterTitle:(NSInteger)section {
 return self.menuSections[section][@"footer"];
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
 NSString *text=[self sectionHeaderTitle:section];if(!text.length)return nil;
 MYBSectionHeaderView *header=[tableView dequeueReusableHeaderFooterViewWithIdentifier:kHeaderID];[header setTitle:text];return header;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
 // A section without a title still needs a deliberate gap; grouped tables otherwise insert their own.
 return [self sectionHeaderTitle:section].length?UITableViewAutomaticDimension:(section==0?6:14);
}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
 NSString *text=[self sectionFooterTitle:section];if(!text.length)return nil;
 MYBSectionFooterView *footer=[tableView dequeueReusableHeaderFooterViewWithIdentifier:kFooterID];[footer setText:text];return footer;
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
 return [self sectionFooterTitle:section].length?UITableViewAutomaticDimension:2;
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)view forRowAtIndexPath:(NSIndexPath *)index {
 if([view isKindOfClass:MYBPrismCell.class]){
  MYBPrismCell *cell=(id)view;
  cell.firstInGroup=index.row==0;
  cell.lastInGroup=index.row==[self tableView:tableView numberOfRowsInSection:index.section]-1;
 }
 // A quiet rise-and-fade the first time each row is shown, never replayed by a reload or by scrolling it back into view.
 if(self.enterUntil>0&&CACurrentMediaTime()<self.enterUntil&&MYBMotionAllowed()){
  if(!self.entered)self.entered=[NSMutableSet set];
  NSString *key=[NSString stringWithFormat:@"%ld-%ld",(long)index.section,(long)index.row];
  if(![self.entered containsObject:key]){
   [self.entered addObject:key];
   NSTimeInterval delay=.035*MIN(self.enterCount++,12);
   view.alpha=0;view.transform=CGAffineTransformMakeTranslation(0,14);
   [UIView animateWithDuration:.45 delay:delay options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction animations:^{view.alpha=1;view.transform=CGAffineTransformIdentity;} completion:^(BOOL f){(void)f;view.alpha=1;view.transform=CGAffineTransformIdentity;}];
  }
 }
}
- (MYBPrismCell *)cardForEntry:(NSDictionary *)entry table:(UITableView *)table {
 MYBPrismCell *cell=[MYBPrismCell cellForTable:table];
 BOOL destructive=[entry[@"destructive"] boolValue];
 cell.mybTitleLabel.text=entry[@"title"];
 BOOL primary=[entry[@"primary"] boolValue]; // the one action a screen wants noticed: blue title and icon
 cell.mybTitleLabel.textColor=destructive?MYBDanger():(primary?[UIColor colorWithRed:.42 green:.70 blue:1 alpha:1]:[UIColor colorWithWhite:.95 alpha:1]);
 cell.mybDetailLabel.text=entry[@"detail"];
 NSString *icon=entry[@"icon"];
 if(icon.length){
  cell.mybIconView.image=[[UIImage systemImageNamed:icon] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  // Selective colour: icons are brand violet. Only destructive rows and rows that flag themselves as a status accent differ.
  cell.tone=destructive?MYBToneRose:(primary?MYBToneBlue:[entry[@"accent"] boolValue]&&entry[@"tone"]?(MYBTone)[entry[@"tone"] integerValue]:MYBToneViolet);
 }
 NSString *value=entry[@"value"];
 if(value.length){
  UILabel *right=[UILabel new];right.text=value;right.lineBreakMode=NSLineBreakByTruncatingMiddle;
  cell.mybAccessoryView=right;
 }else if(entry[@"action"]&&[entry[@"action"] length]){
  cell.mybAccessoryType=UITableViewCellAccessoryDisclosureIndicator;
 }
 BOOL actionable=[entry[@"action"] length]>0;
 cell.selectionStyle=actionable?UITableViewCellSelectionStyleDefault:UITableViewCellSelectionStyleNone;
 [cell refreshContent];
 return cell;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)p {
 return [self cardForEntry:self.menuSections[p.section][@"rows"][p.row] table:tableView];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)p {
 [tableView deselectRowAtIndexPath:p animated:YES];
 NSDictionary *entry=self.menuSections[p.section][@"rows"][p.row];
 // A row that names a page opens it from any screen. Without this a row whose controller delegated here did nothing.
 if([entry[@"page"] length]&&!self.busy){Class page=NSClassFromString(entry[@"page"]);UIViewController *next=page?[page new]:nil;if(next&&self.navigationController){[self.navigationController pushViewController:next animated:YES];return;}}
 NSString *action=entry[@"action"];
 if(!action.length)return;
 SEL selector=NSSelectorFromString(action);
 if([self respondsToSelector:selector]) {
  IMP imp=[self methodForSelector:selector];
  void (*func)(id,SEL)=(void *)imp;
  func(self,selector);
 }
}
// ---- Old MYbloXX profile: inspected and removed from THIS process --------------------------------------------------------------------
// The Settings component is entitled to use the profile service; the helper is not (iOS answers it "denied"), so the helper cannot even list
// profiles. The same shared decision logic (Shared/MYBProfileMigration.h) therefore runs here, bound to the profile service as this process
// sees it. The helper is used only for what needs root: turning native protection on afterwards.
static void MYBSettingsLog(NSString *line){
 int fd=open(MYBMobileFile(@"/var/mobile/Library/MYbloXX/ProfileDiagnostics.txt").fileSystemRepresentation,O_WRONLY|O_APPEND|O_CREAT,0666);if(fd<0)return;
 NSData *d=[[NSString stringWithFormat:@"%@ [settings] %@\n",[NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle],line] dataUsingEncoding:NSUTF8StringEncoding];
 if(d)write(fd,d.bytes,d.length);close(fd);
}
static MYBMigrationEnv *MYBSettingsMigrationEnv(void){
 MYBMigrationEnv *e=[MYBMigrationEnv new];
 e.list=^NSArray *{return MYBServiceList();};
 e.describe=^NSDictionary *(NSString *i){return MYBServiceDescribe(i);};
 e.effectivePAC=^NSString *{return MYBEffectivePACNow();};
 e.remove=^(NSString *i){MYBServiceRemove(i);};
 e.managedGone=^BOOL{struct stat st;return lstat("/var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist",&st)!=0;};
 e.effectiveClear=^BOOL(NSString *p){return MYBEffectiveProxyClear(p);};
 e.record=^BOOL(NSDictionary *d){NSMutableDictionary *m=[d mutableCopy];m[@"updated"]=NSDate.date;return [m writeToFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.oldprofile.plist") atomically:YES];};
 e.loadRecord=^NSDictionary *{return nil;};
 e.apply=^int(__unused NSString *m){return 0;}; // never reached: savedEnabled is NO, so the run ends after the removal is confirmed
 e.owned=^BOOL{return NO;};
 e.wait=^{usleep(500000);};e.steps=20;e.savedEnabled=NO;e.mode=@"Default";
 return e;
}
// Returns (on the main queue) the migration result for a read-only inspection (78 = recognised MYbloXX profile, nothing removed) and the
// identifier of a MYbloXX-identified profile when one is installed, even when its contents could not be read.
static void MYBInspectOldProfile(void(^done)(int rc,NSString *identifier)){
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSString *found=nil;for(NSString *i in (MYBServiceList()?:@[]))if([MYBLegacyProfileKnownIdentifiers() containsObject:i])found=i;
  int rc=MYBMigrationRun(MYBSettingsMigrationEnv(),NO,^(NSString *l){MYBSettingsLog(l);});
  MYBSettingsLog([NSString stringWithFormat:@"inspect result=%d identifier=%@",rc,found?:@"none"]);
  dispatch_async(dispatch_get_main_queue(),^{done(rc,found);});
 });
}
// Settings is the app asking, so each address is tried in turn until iOS accepts one; the last resort tells the person where to tap.
static void MYBOpenProfileURLs(NSArray<NSString *> *urls,NSUInteger index,void(^fallback)(void)){
 if(index>=urls.count){if(fallback)fallback();return;}
 NSURL *url=[NSURL URLWithString:urls[index]];
 if(!url){MYBOpenProfileURLs(urls,index+1,fallback);return;}
 [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL ok){dispatch_async(dispatch_get_main_queue(),^{if(!ok)MYBOpenProfileURLs(urls,index+1,fallback);});}];
}
static void MYBOpenProfileDetail(NSString *identifier){
 NSMutableArray *urls=[NSMutableArray array];
 if(identifier.length){[urls addObject:[@"prefs:root=General&path=ManagedConfigurationList/" stringByAppendingString:identifier]];[urls addObject:[@"App-prefs:General&path=ManagedConfigurationList/" stringByAppendingString:identifier]];}
 [urls addObjectsFromArray:@[@"prefs:root=General&path=ManagedConfigurationList",@"App-prefs:General&path=ManagedConfigurationList",@"prefs:root=General&path=ManagedConfigurationList&path=ManagedConfigurationList"]];
 MYBOpenProfileURLs(urls,0,^{
  UIViewController *top=nil;for(UIScene *c in UIApplication.sharedApplication.connectedScenes){if(![c isKindOfClass:UIWindowScene.class])continue;for(UIWindow *w in ((UIWindowScene *)c).windows){if(w.isKeyWindow){top=w.rootViewController;break;}}if(top)break;}while(top.presentedViewController)top=top.presentedViewController;
  if(top)MYBMessage(top,@"Open It From Settings",@"Open Settings > General > VPN & Device Management, choose the MYbloXX\u00ae profile and tap Remove Profile.");
 });
}
// One place decides what the person sees when a profile is in the way. 78 = a recognised MYbloXX profile: Switch to Native Protection (the only
// action that removes it). 3/76 = unrecognised or unreadable: explain, open Device Management, Check Again. 80-82 = a switch that stopped part-way.
- (void)offerProfileSwitchForResult:(int)rc args:(NSArray<NSString *> *)args completion:(void(^)(int))completion {
 if((rc==3||rc==76||rc==78)&&[MYBInstalledMYbloXXProfile()[@"installed"] boolValue]){[self offerRemoveMYbloXXProfileThen:completion];return;}
 if(rc==3||rc==76||rc==78){
  // The helper cannot see profiles; look here first so the person is offered the one-tap switch whenever an old MYbloXX profile is installed.
  __weak typeof(self) weak=self;
  MYBInspectOldProfile(^(int irc,NSString *identifier){typeof(self) me=weak;if(!me)return;
   [me presentProfileOfferForResult:irc==78?78:rc identifier:identifier viaSettings:irc==78 completion:completion];});
  return;
 }
 [self presentProfileOfferForResult:rc identifier:nil viaSettings:NO completion:completion];
}
// A MYbloXX® profile is in the way: remove it here (this process is allowed to ask iOS) and turn native protection on.
- (void)offerRemoveMYbloXXProfileThen:(void(^)(int))completion {
 MYBDismissStatus(self);
 __weak typeof(self) weak=self;
 MYBConfirmWithButton(self,@"Remove the MYbloXX\u00ae Profile?",@"A MYbloXX\u00ae profile is installed and is holding the connection, so native protection cannot start. MYbloXX\u00ae removes it now and turns native protection on. Your options, rules and permissions stay as they are. Other profiles (DNS, VPN, work or school) are never touched.",@"Remove and Switch",^{typeof(self) me=weak;[me removeMYbloXXProfilesThenEnable:completion];});
}
- (void)removeMYbloXXProfilesThenEnable:(void(^)(int))completion {
 MYBProgress(self,@"Removing Profile");
 __weak typeof(self) weak=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  BOOL removed=NO,gone=NO;MYBRemoveMYbloXXProfiles(&removed,&gone);
  MYBSettingsLog([NSString stringWithFormat:@"profile removal removed=%d gone=%d",removed,gone]);
  dispatch_async(dispatch_get_main_queue(),^{
   typeof(self) me=weak;if(!me)return;
   if(!gone){
    MYBDismissStatus(me);
    MYBConfirmWithButton(me,@"iOS Kept the Profile",@"iOS did not let MYbloXX\u00ae remove the profile. Open it, tap Remove Profile and enter your passcode, then come back and turn protection on.",@"Open the Profile",^{MYBOpenProfileDetail(MYBInstalledMYbloXXProfile()[@"identifier"]);});
    if(completion)completion(81);return;
   }
   [me runHelper:@[@"enable"] completion:^(int rc){
    typeof(self) m2=weak;if(!m2)return;
    if(rc==0)MYBComplete(m2,YES,@"Switched to Native Protection",@"The MYbloXX\u00ae profile was removed and native protection is on. Your options, rules and permissions were kept.");
    else MYBComplete(m2,NO,@"Profile Removed, Protection Is Not On",@"The profile is gone, but native protection could not be turned on. Use Repair MYbloXX\u00ae to finish.");
    if(completion)completion(rc);}];
  });
 });
}
// Shown by itself, once per launch, when the dashboard reports another configuration and an old MYbloXX profile is the reason.
- (void)offerOldProfileIfPresent {
 __weak typeof(self) weak=self;
 MYBInspectOldProfile(^(int irc,NSString *identifier){typeof(self) me=weak;if(!me||(irc!=78&&!identifier.length))return;
  [me presentProfileOfferForResult:irc==78?78:76 identifier:identifier viaSettings:irc==78 completion:nil];});
}
- (void)presentProfileOfferForResult:(int)rc identifier:(NSString *)identifier viaSettings:(BOOL)viaSettings completion:(void(^)(int))completion {
 MYBDismissStatus(self);
 NSDictionary *o=MYBProfileOutcome(rc);
 __weak typeof(self) weak=self;
 void(^finish)(int)=^(int r){typeof(self) m2=weak;if(!m2)return;
  if(r==0){MYBComplete(m2,YES,@"Switched to Native Protection",@"The old MYbloXX\u00ae profile was removed and native protection is on. Your options, rules and permissions were kept.");}
  else [m2 offerProfileSwitchForResult:r args:@[@"migrateprofile"] completion:nil];
  if(completion)completion(r);};
 void(^switchNow)(void)=^{typeof(self) me=weak;if(!me)return;
  if(!viaSettings){[me runHelper:@[@"migrateprofile"] completion:finish];return;}
  // Remove it here (this process is allowed to), then ask the helper to turn native protection on.
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
   int removed=MYBMigrationRun(MYBSettingsMigrationEnv(),YES,^(NSString *l){MYBSettingsLog(l);});
   MYBSettingsLog([NSString stringWithFormat:@"removal result=%d",removed]);
   dispatch_async(dispatch_get_main_queue(),^{typeof(self) m3=weak;if(!m3)return;
    if(removed!=0){finish(removed==3?81:removed);return;} // not removed: the guided steps are offered, nothing else was changed
    [m3 runHelper:@[@"enable"] completion:finish];});
  });};
 if(rc==78){MYBConfirmWithButton(self,o[@"title"],o[@"detail"],@"Switch to Native Protection",switchNow);return;}
 if(rc==82||rc==81||rc==80){
  MYBConfirmWithButton(self,o[@"title"],[o[@"detail"] stringByAppendingString:@" You can try the switch again; it picks up where it stopped."],@"Try Again",switchNow);return;}
 NSString *guided=identifier.length?[o[@"detail"] stringByAppendingString:@"\n\nMYbloXX\u00ae opens the profile for you: tap Remove Profile, enter your passcode, then come back and turn protection on."]:o[@"detail"];
 MYBConfirmWithButton(self,o[@"title"],guided,identifier.length?@"Open the Profile":@"Open Device Management",^{
  MYBOpenProfileDetail(identifier);
  typeof(self) me=weak;if(me&&completion)completion(rc);});
}
- (void)showMessage:(NSString *)title detail:(NSString *)detail {
 if(self.completingHelper)MYBComplete(self,self.lastHelperResult==0,title,detail);else MYBMessage(self,title,detail);
}
- (void)confirm:(NSString *)title message:(NSString *)message action:(void(^)(void))action {MYBConfirm(self,title,message,action);}
- (void)silentHelper:(NSArray<NSString *> *)args completion:(void(^)(int))completion {
#if MYB_PREVIEW_HARNESS
 if(completion)dispatch_async(dispatch_get_main_queue(),^{completion(0);});return;
#endif
 NSString *helper=MYBPath(@"/usr/sbin/MYXXdev/MYbloXX/MYXXdev");
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  pid_t pid=0;NSMutableArray<NSData *> *storage=[NSMutableArray array];const char *argv[8]={"MYXXdev",NULL,NULL,NULL,NULL,NULL,NULL,NULL};int count=1;
  for(NSString *item in args){if(count>=7)break;NSMutableData *bytes=[[item dataUsingEncoding:NSUTF8StringEncoding] mutableCopy]?:[NSMutableData data];[bytes appendBytes:"\0" length:1];[storage addObject:bytes];argv[count++]=(const char *)bytes.bytes;}
  int rc=posix_spawn(&pid,helper.fileSystemRepresentation,NULL,NULL,(char *const *)argv,environ);
  if(!rc){
   NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:20];int status=0;rc=125;
   for(;;){pid_t done=waitpid(pid,&status,WNOHANG);if(done==pid){rc=WIFEXITED(status)?WEXITSTATUS(status):125;break;}if(done<0&&errno!=EINTR){rc=125;break;}
    if(deadline.timeIntervalSinceNow<0){kill(pid,SIGKILL);waitpid(pid,&status,0);rc=124;break;}usleep(50000);}
  }
  if(completion)dispatch_async(dispatch_get_main_queue(),^{completion(rc);});
 });
}
- (void)runHelper:(NSArray<NSString *> *)args completion:(void(^)(int))completion {
#if MYB_PREVIEW_HARNESS
 if(completion)dispatch_async(dispatch_get_main_queue(),^{self.lastHelperResult=0;self.completingHelper=YES;completion(0);self.completingHelper=NO;});return;
#endif
 if(self.busy){
  // A control may already have flipped; put every control back to the truth instead of leaving it out of sync.
  [self rebuildMenu];return;
 }
 self.busy=YES;NSDate *operationStarted=[NSDate date];
 BOOL quietAutoRule=[@[@"localcustom",@"recoverrules",@"syncfiles"] containsObject:args.firstObject];
 BOOL quiet=quietAutoRule||[@[@"supervisionstatus",@"profilestage",@"profilestatus",@"profilediag",@"legacypreflight",@"migrateprofile",@"legacyprepare"] containsObject:args.firstObject]; // profile steps show their own messages
 if(!quiet)MYBProgress(self,[args.firstObject isEqual:@"updatecheck"]?@"Checking Updates":[args.firstObject isEqual:@"backupfiles"]?@"Saving Your Backup":[args.firstObject hasPrefix:@"restore"]?@"Restoring Your Setup":[args.firstObject isEqual:@"testrule"]?@"Checking Website":@"Applying Changes");
 NSString *helper=MYBPath(@"/usr/sbin/MYXXdev/MYbloXX/MYXXdev");
 __weak typeof(self) weakSelf=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  pid_t pid=0;
  NSMutableArray<NSData *> *storage=[NSMutableArray array];
  const char *argv[8]={NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL};
  int count=0;
  argv[count++]="MYXXdev";
  for(NSString *item in args){
   if(count>=7)break;
   NSMutableData *bytes=[[item dataUsingEncoding:NSUTF8StringEncoding] mutableCopy]?:[NSMutableData data];[bytes appendBytes:"\0" length:1];[storage addObject:bytes];
   argv[count++]=(const char *)bytes.bytes;
  }
  int rc=posix_spawn(&pid,helper.fileSystemRepresentation,NULL,NULL,(char *const *)argv,environ);
  if(!rc){
   NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:kMYBHelperTimeout];int status=0;rc=125;
   for(;;){
    pid_t done=waitpid(pid,&status,WNOHANG);
    if(done==pid){rc=WIFEXITED(status)?WEXITSTATUS(status):125;break;}
    if(done<0&&errno!=EINTR){rc=125;break;}
    if(deadline.timeIntervalSinceNow<0){kill(pid,SIGTERM);usleep(600000);if(waitpid(pid,&status,WNOHANG)==0){kill(pid,SIGKILL);waitpid(pid,&status,0);}rc=124;break;}
    usleep(40000);
   }
  }
  dispatch_async(dispatch_get_main_queue(),^{
   typeof(self) strongSelf=weakSelf;if(!strongSelf)return;
   strongSelf.busy=NO;
   [strongSelf rebuildMenu];
   // noXXX PIN: the helper refused to weaken noXXX without the PIN. Ask once, authorise exactly this change, then run it again.
   NSString *pinScope=(rc==MYB_PIN_EXIT_REQUIRED&&(!quietAutoRule||[args.firstObject isEqual:@"localcustom"]))?MYBPinScopeForArgs(args):nil;
   if(pinScope){MYBDismissStatus(strongSelf);[strongSelf askPINForScope:pinScope then:^(BOOL authorised){if(authorised)[strongSelf runHelper:args completion:completion];else if(completion)completion(MYB_PIN_EXIT_REQUIRED);}];return;}
   // A hand-installed MYbloXX profile (or another proxy owner) is in the way. Say so plainly and offer the right next step instead of a bare error.
   if([@[@"enable",@"reconfigure",@"repair",@"migrateprofile",@"mode",@"selectmode"] containsObject:args.firstObject]&&[@[@3,@76,@78,@80,@81,@82] containsObject:@(rc)]){
    [strongSelf offerProfileSwitchForResult:rc args:args completion:completion];return;}
   if(!quiet){
    NSString *detail=rc==124?@"This took too long and was stopped. Your previous settings were retained. Please try again.":rc?[NSString stringWithFormat:@"This change could not be applied (%d). Please try again.",rc]:nil;
    MYBComplete(strongSelf,rc==0,rc?@"Couldn’t apply changes":@"Applied",detail);
   }
   strongSelf.completingHelper=YES;strongSelf.lastHelperResult=rc;
   if(completion)completion(rc);
   strongSelf.completingHelper=NO;
   if(!rc){NSDictionary *backup=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/BackupStatus.plist")];NSDate *attempt=backup[@"lastAttempt"];if([backup[@"lastCode"] integerValue]&&[attempt isKindOfClass:NSDate.class]&&[attempt compare:operationStarted]!=NSOrderedAscending)MYBMessage(strongSelf,@"Change Applied, Backup Needs Attention",backup[@"lastResult"]?:@"Open Backup & Restore and choose Back Up Now.");}
   if(strongSelf.backupSyncPending)[strongSelf refreshFilesBackup];
  });
 });
}
- (void)askPINForScope:(NSString *)scope then:(void(^)(BOOL))then {
 NSString *helper=MYBPath(@"/usr/sbin/MYXXdev/MYbloXX/MYXXdev");__weak typeof(self) weak=self;
 MYBInputCancellable(self,@"Enter PIN",@"This change would weaken noXXX, so it needs your four-digit PIN.",@[@{@"placeholder":@"PIN",@"keyboard":@(UIKeyboardTypeNumberPad),@"secure":@YES}],@"Continue",^(NSArray *values){
  NSString *pin=[values.firstObject isKindOfClass:NSString.class]?values.firstObject:@"";
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
   NSString *out=nil;int rc=MYBPinHelperRun(helper,@[@"pinauth",scope],pin,&out);
   dispatch_async(dispatch_get_main_queue(),^{typeof(self) me=weak;if(!me)return;if(rc)MYBComplete(me,NO,@"PIN Not Accepted",MYBPinOutcomeText(rc,out));if(then)then(rc==0);});
  });
 },^{if(then)then(NO);});
}
- (void)refreshFilesBackup {
 self.backupSyncPending=YES;if(self.busy)return;self.backupSyncPending=NO;
 [self runHelper:@[@"syncfiles"] completion:^(int rc){if(rc){NSDictionary *status=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/BackupStatus.plist")];MYBMessage(self,@"Settings Saved, Backup Needs Attention",status[@"lastResult"]?:@"Your settings were saved, but the Files backup could not be updated. Open Backup & Restore and try Back Up Now.");}}];
}
@end
