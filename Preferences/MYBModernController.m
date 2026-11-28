#import "../Shared/MYBMYbloXXProfile.h"
#import "MYBMenuBase.h"
#import <roothide.h>
#import "MYBDesign.h"
#import "MYBTips.h"
#import "../Shared/MYBProxyCheck.h"
#import "../Shared/MYBOutcomeText.h"
#import "../Shared/MYBModeNames.h"
#import "../Shared/MYBOptions.h"
#import "../Shared/MYBModeCatalog.h"
#import "../Shared/MYBRuntimeStatus.h"
#import "../Shared/MYBStatusModel.h"
#import <notify.h>
#if !MYB_PREVIEW_HARNESS
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#endif
#import <math.h>
extern NSString *MYBPath(NSString *relativePath);
@protocol MYBDashboardScrollOwner <NSObject>
- (void)mybDashboardDidScroll:(UIScrollView *)scroll;
@end
@interface MYBDashboardController : MYBMenuBase
@property(nonatomic,assign) NSInteger localHealth;
@property(nonatomic,copy) NSString *heroKey;
@property(nonatomic,strong) NSTimer *statusTimer;
@property(nonatomic,assign) int statusNotifyToken;
@property(nonatomic,strong) NSNumber *statusRefreshError;
@property(nonatomic,strong) NSDate *statusRefreshAttempt;
@property(nonatomic,assign) BOOL statusRefreshing;
@property(nonatomic,assign) NSInteger statusRefreshFailures;
@property(nonatomic,strong) NSDictionary *statusCache;
@property(nonatomic,readonly) UITableView *modernTable;
@property(nonatomic,assign) BOOL modesExpanded; // in memory only: every launch starts collapsed
@end
@implementation MYBDashboardController
- (UITableView *)modernTable{return self.tableView;}
- (void)scrollViewDidScroll:(UIScrollView *)scroll{
 id<MYBDashboardScrollOwner> owner=(id<MYBDashboardScrollOwner>)self.chromeOwner;
 if([owner respondsToSelector:@selector(mybDashboardDidScroll:)])[owner mybDashboardDidScroll:scroll];
}
- (BOOL)mybHasBrandedHeader{return YES;} // read by MYBStyleNavigation: the bar title stays hidden until this header scrolls away
- (NSDictionary *)state{return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/State.plist")]?:@{};}
- (NSString *)mode{NSString *mode=MYBMigrateModeID(self.state[@"mode"])?:@"Default";if([mode isEqual:@"Custom"]){for(NSString *dir in @[@"PACCurrent",@"PAC"]){NSString *path=MYBMobileFile([NSString stringWithFormat:@"/var/mobile/Library/MYbloXX/%@/Custom.pac",dir]);if([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] hasPrefix:@"// MYbloXX® Proxy Override\n"])return @"Proxy";}}return mode;}
// Real protection only: the managed link is MYbloXX’s AND its temporary inline-PAC target is
// intact. A link whose target has vanished is shown as needing attention, never as enabled.
- (NSDictionary *)runtime{return MYBRuntimeStatusMirrored(MYBMobileFile(@"/var/mobile/Library/MYbloXX/RuntimeStatus.plist"));}
- (BOOL)enabled{return [self.runtime[@"enabled"] boolValue];}
// Verified protection only: configured on disk AND confirmed by the helper as the expected rules in the system’s
// effective proxy settings. "Configured" alone is shown as needing confirmation, never as plain Enabled.
- (NSString *)protection{return MYBRuntimeProtection(self.runtime);}
- (BOOL)intendedEnabled{return [self.state[@"enabled"] boolValue];}
// Structured status (Shared/MYBStatusModel.h): explicit state, explanation and tone; never inferred from text.
- (NSDictionary *)computeStatusModel{
 NSDictionary *m=MYBStatusModel(self.runtime,[self intendedEnabled],self.statusRefreshError);
 // A MYbloXX® profile (installed by Legacy Mode or by hand) is doing the blocking: say so instead of "another configuration".
 if(![m[@"active"] boolValue]&&[MYBInstalledMYbloXXProfile()[@"installed"] boolValue])
  return @{@"kind":@"profile",@"title":@"Legacy Profile Active",@"detail":@"A MYbloXX® profile is installed on this iPhone and is blocking for you. Open Supervision & Legacy Mode to switch to native protection.",@"tone":@"positive",@"active":@NO,@"refresh":@NO};
 return m;
}
- (NSDictionary *)statusModel{return self.statusCache?:[self computeStatusModel];}
- (BOOL)configurationLoaded{return [[self statusModel][@"active"] boolValue];}
- (NSString *)protectionText{NSDictionary *m=[self statusModel];return [NSString stringWithFormat:@"%@: %@",m[@"title"],m[@"detail"]];}
- (NSString *)heroEyebrow{return nil;}
- (UIView *)makeHero{NSDictionary *m=[self statusModel];return MYBDashboardHero(m[@"title"],m[@"detail"],m[@"tone"],MYBModeDisplay(self.mode));}
// The hero only changes when what it shows changes; rebuilding it on every
// refresh re-assigns the table header and makes the page jump while scrolling.
- (void)refreshHeroIfNeeded{
 NSDictionary *m=[self statusModel];
 NSString *key=[NSString stringWithFormat:@"%@|%@|%@|%@",m[@"kind"],m[@"detail"],m[@"tone"],MYBModeDisplay(self.mode)];
 // Another configuration is holding the proxy: if it is an old MYbloXX profile, offer the one-tap switch (once per launch, never nagging).
 static BOOL offeredOldProfile;
 if([m[@"kind"] isEqual:@"foreign"]&&!offeredOldProfile){offeredOldProfile=YES;dispatch_async(dispatch_get_main_queue(),^{[self offerOldProfileIfPresent];});}
 if([key isEqual:self.heroKey]&&self.tableView.tableHeaderView)return;
 // Replacing the header must not move what the user is reading.
 BOOL changed=self.heroKey!=nil;
 CGPoint offset=self.tableView.contentOffset;self.heroKey=key;[self refreshHero];
 if(offset.y>0)[self.tableView setContentOffset:offset animated:NO];
 if(changed)MYBStatusPop([self.tableView.tableHeaderView viewWithTag:91]); // one-shot, only when the status really changed
}
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"MYbloXX®";[self checkLocalHealth];
 // iOS is asked about profiles in the background; when the answer arrives the status card is redrawn.
 __weak typeof(self) weak=self;
 [NSNotificationCenter.defaultCenter addObserverForName:MYBProfileStateChanged object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;typeof(self) me=weak;if(!me)return;me.statusCache=[me computeStatusModel];[me refreshHeroIfNeeded];[me rebuildMenu];}];
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
- (void)viewWillAppear:(BOOL)animated{
 [super viewWillAppear:animated];
 [self rebuildMenu];
 [self checkLocalHealth];
}
static BOOL MYBRestoreTried; // once per Settings process: the first appearance may restore, every later one means the person came back here themselves
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];[self startLiveStatus];
 // Supervision state is read from iOS by the helper; the row shows what it reports and updates itself when that changes.
 NSString *before=[self supervisionLine];__weak typeof(self) weakSelf=self;
 [self silentHelper:@[@"supervisionstatus"] completion:^(int rc){(void)rc;typeof(self) me=weakSelf;if(!me||me.busy)return;
  if(![[me supervisionLine] isEqualToString:before])[me rebuildMenu];}];
 if(!MYBRestoreTried){MYBRestoreTried=YES;if(self.navigationController.topViewController==self)MYBNavRestore(self.navigationController);}
 else MYBNavClear();
 // The welcome screen on the Home Screen cannot remove a profile; it opens Settings with this note, and the offer appears straight away.
 NSString *note=MYBMobileFile(@"/var/mobile/Library/MYbloXX/WelcomeFix");
 if([NSFileManager.defaultManager fileExistsAtPath:note]){
  [NSFileManager.defaultManager removeItemAtPath:note error:NULL];
  __weak typeof(self) weak=self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.7*NSEC_PER_SEC)),dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{BOOL installed=[MYBInstalledMYbloXXProfileSync()[@"installed"] boolValue];dispatch_async(dispatch_get_main_queue(),^{typeof(self) me=weak;if(me&&installed)[me offerRemoveMYbloXXProfileThen:^(__unused int rc){[me rebuildMenu];}];});});
 }
}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self stopLiveStatus];}
- (void)viewDidDisappear:(BOOL)animated{
 [super viewDidDisappear:animated];
 [self stopLiveStatus]; // no health probe, timer or observer may outlive the screen
}
// ---- live status: helper notification + bounded polling, only while visible and in the foreground ----
- (void)startLiveStatus{
 if(self.statusTimer)return;
 __weak typeof(self) weak=self;
 int token=0;if(notify_register_dispatch("net.myxxdev.mybloxx.statuschanged",&token,dispatch_get_main_queue(),^(__unused int t){[weak statusTick];})==NOTIFY_STATUS_OK)self.statusNotifyToken=token;
 self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(__unused NSTimer *t){[weak statusTick];}];self.statusTimer.tolerance=1;
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(stopLiveStatus) name:UIApplicationDidEnterBackgroundNotification object:nil];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resumeLiveStatus) name:UIApplicationWillEnterForegroundNotification object:nil];
 [self statusTick];
}
- (void)resumeLiveStatus{if(self.viewIfLoaded.window)[self startLiveStatus];}
- (void)stopLiveStatus{
 [self.statusTimer invalidate];self.statusTimer=nil;
 if(self.statusNotifyToken){notify_cancel(self.statusNotifyToken);self.statusNotifyToken=0;}
 [NSNotificationCenter.defaultCenter removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
 [NSNotificationCenter.defaultCenter removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}
- (void)statusTick{
 if(!self.viewIfLoaded.window||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
 __weak typeof(self) weak=self;
 // File reads and hashing stay off the main thread.
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  NSDictionary *m=[weak computeStatusModel];
  dispatch_async(dispatch_get_main_queue(),^{
   typeof(self) me=weak;if(!me||!me.viewIfLoaded.window)return;
   me.statusCache=m;[me refreshHeroIfNeeded];
   if([m[@"refresh"] boolValue])[me requestVerification];
  });
 });
}
// Ask the helper (silently, never blocking the UI) to publish a fresh verification. At most one request in flight,
// one per 15 s, backing off to one per minute after repeated failures. A failure is shown, not hidden.
- (void)requestVerification{
#if !MYB_PREVIEW_HARNESS
 if(self.statusRefreshing||self.busy)return;
 NSTimeInterval gap=self.statusRefreshFailures>=3?60:15;
 if(self.statusRefreshAttempt&&-[self.statusRefreshAttempt timeIntervalSinceNow]<gap)return;
 self.statusRefreshing=YES;self.statusRefreshAttempt=[NSDate date];
 __weak typeof(self) weak=self;
 [self silentHelper:@[@"statuspublish"] completion:^(int rc){
  typeof(self) me=weak;if(!me)return;
  me.statusRefreshing=NO;me.statusRefreshError=rc?@(rc):nil;me.statusRefreshFailures=rc?me.statusRefreshFailures+1:0;
  me.statusCache=[me computeStatusModel];[me refreshHeroIfNeeded];
 }];
#endif
}
// One short list. Every feature keeps a destination, but explanations and detailed status live inside those screens.
// Blocking Mode expands in place: Default is the base and the five options can be combined; collapsed is the default.
- (NSArray *)modeRows{
 NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *m in MYBModeTable())[rows addObject:@{@"title":MYBModeName(m[@"mode"]),@"detail":[m[@"mode"] isEqual:@"Default"]?@"Always on. Options below are added to it.":m[@"short"],@"icon":m[@"icon"],@"mode":m[@"mode"],@"recommended":@([m[@"mode"] isEqual:@"blockAdSense"])}];
 [rows addObject:@{@"title":@"Exact Differences",@"icon":@"info.circle",@"page":@"MYBModeInfoController",@"action":@"openPage",@"inline":@YES}];
 return rows;
}
// Proxy Override is a Custom PAC written by MYbloXX® that is currently the selected mode (same test as the Proxy Override page).
static BOOL MYBProxyOverrideActive(void){
 NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/State.plist")];
 if(![state[@"mode"] isEqual:@"Custom"]||![state[@"enabled"] boolValue])return NO;
 for(NSString *dir in @[@"PACCurrent",@"PAC"]){NSString *path=MYBMobileFile([NSString stringWithFormat:@"/var/mobile/Library/MYbloXX/%@/Custom.pac",dir]);
  if([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] hasPrefix:@"// MYbloXX® Proxy Override\n"])return YES;}
 return NO;
}
// Recovery and anything that is currently changing how the phone connects are on the main page, not buried.
- (NSArray *)supportRows{
 NSMutableArray *support=[NSMutableArray array];
 if(MYBProxyOverrideActive())[support addObject:@{@"title":@"Proxy Override is On",@"detail":@"Your web traffic goes through your own proxy. Tap to change or turn it off.",@"icon":@"network",@"page":@"MYBProxyOverrideController",@"action":@"openPage"}];
 [support addObjectsFromArray:@[
  @{@"title":@"Backup & Updates",@"detail":@"Save, restore and update",@"icon":@"externaldrive",@"page":@"MYBBackupUpdatesController",@"action":@"openPage"},
  @{@"title":@"Help & Repair",@"detail":@"Check, repair and get support",@"icon":@"lifepreserver",@"page":@"MYBTroubleshootingController",@"action":@"openPage"},
  @{@"title":@"More Settings",@"detail":@"DNS, proxy, PIN and connectivity",@"icon":@"ellipsis.circle",@"page":@"MYBMoreSettingsController",@"action":@"openPage"}]];
 return support;
}
// The real state, read from what the helper last reported and from iOS’s own profile check; nothing here is inferred.
- (NSString *)supervisionLine{
 NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.supervision.plist")]?:@{};
 BOOL profile=[MYBInstalledMYbloXXProfile()[@"installed"] boolValue],supervised=[state[@"supervised"] boolValue],owned=[state[@"owned"] boolValue],known=state.count>0;
 NSString *sup=!known?@"Supervision: not checked yet":!supervised?@"Supervision: off":owned?@"Supervision: on, turned on by MYbloXX®":@"Supervision: on, already set up on this iPhone";
 return [sup stringByAppendingString:profile?@" · Legacy profile installed":@" · Native protection"];
}
- (NSArray *)supervisionRows{
 BOOL profile=[MYBInstalledMYbloXXProfile()[@"installed"] boolValue];
 NSMutableDictionary *row=[@{@"title":@"Supervision & Legacy Mode",@"detail":profile?@"Legacy profile installed. Tap to switch to native protection.":[self supervisionLine],@"icon":@"lock.shield",@"page":@"MYBLegacyController",@"action":@"openPage"} mutableCopy];
 if(profile){row[@"accent"]=@YES;row[@"tone"]=@(MYBToneAmber);}
 NSMutableArray *rows=[NSMutableArray arrayWithObject:row];
 return rows;
}
- (NSArray *)buildSections{
 NSMutableArray *top=[NSMutableArray arrayWithObjects:
  @{@"title":@"Protection",@"detail":self.busy?@"Applying...":@"",@"icon":@"power",@"accent":@YES,@"tone":@(MYBToneGreen),@"switch":@"protection"},
  @{@"title":@"Blocking Mode",@"detail":[@"Websites & network: " stringByAppendingString:MYBModeDisplay(self.mode)],@"icon":@"line.3.horizontal.decrease.circle",@"expander":@YES},nil];
 if(self.modesExpanded)[top addObjectsFromArray:[self modeRows]];
 [top addObject:@{@"title":@"Custom Rules",@"detail":@"Allow or block websites",@"icon":@"list.bullet.rectangle",@"page":@"MYBRulesController",@"action":@"openPage"}];
 [top addObject:@{@"title":@"Activity",@"detail":@"Website activity by app",@"icon":@"list.bullet.below.rectangle",@"page":@"MYBActivityController",@"action":@"openPage"}];
 return @[
 @{@"title":@"WEBSITE BLOCKING",@"rows":top},
 @{@"title":@"BROWSER & APP PROTECTION",@"rows":@[
  @{@"title":@"Pop-Up Control",@"detail":@"Stop pop-ups in your browser",@"icon":@"macwindow.on.rectangle",@"page":@"MYBPopupControlController",@"action":@"openPage"},
  @{@"title":@"App Redirect Protection",@"detail":@"Ask before a link opens another app",@"icon":@"arrow.triangle.branch",@"page":@"MYBRedirectController",@"action":@"openPage"},
  @{@"title":@"In-App Ad Blocking",@"detail":@"Hide ads inside supported apps",@"icon":@"nosign",@"page":@"MYBInAppAdsController",@"action":@"openPage"},
  @{@"title":@"Extra Privacy Protection",@"detail":@"App Lock, private items, notification privacy and clean sharing",@"icon":@"hand.raised.fill",@"page":@"MYBExtraPrivacyController",@"action":@"openPage"}]},
 @{@"title":@"PROTECTION CENTER",@"rows":@[
  @{@"title":@"Protection Center",@"detail":@"Call Firewall and Message Firewall together -- numbers, ranges, senders, keywords and scam patterns, with live blocked counts",@"icon":@"shield.lefthalf.filled",@"accent":@YES,@"tone":@(MYBToneGreen),@"page":@"MYBFirewallController",@"action":@"openPage"}]},
 @{@"title":@"BATTERY",@"rows":@[
  @{@"title":@"MYXX Reserve",@"detail":@"At low battery the phone sleeps before it dies, so the jailbreak survives",@"icon":@"battery.25",@"page":@"MYBReserveController",@"action":@"openPage"}]},
 @{@"title":@"PAUSE BLOCKING FOR AN APP",@"rows":@[
  @{@"title":@"App Switch Control",@"detail":@"Pause blocking while chosen apps are open",@"icon":@"bolt.fill",@"page":@"MYBAppControlController",@"action":@"openPage"}]},
 @{@"title":@"SUPERVISION & LEGACY MODE",@"rows":[self supervisionRows]},
 @{@"title":@"SETTINGS & SUPPORT",@"rows":[self supportRows]}];
}
- (void)rebuildMenu{
 self.title=@"MYbloXX®";
 NSArray *next=[self buildSections];
 // Coming back to this screen (from a page, a sheet or another app) changes nothing when nothing changed: the table is not rebuilt, so it cannot jump.
 if(self.menuSections.count&&[self.menuSections isEqual:next]){if(self.isViewLoaded)[self refreshHeroIfNeeded];return;}
 CGPoint offset=self.tableView.contentOffset;BOOL keep=self.menuSections.count>0&&self.isViewLoaded&&self.view.window;
 self.menuSections=next;
 [UIView performWithoutAnimation:^{[self.tableView reloadData];if(keep){[self.tableView layoutIfNeeded];self.tableView.contentOffset=offset;}}];
 if(self.isViewLoaded)[self refreshHeroIfNeeded];
}
// Expand or collapse in place. Only the mode rows are inserted or removed, with a fade; the scroll offset is never
// touched, so nothing jumps or resets. The chevron turns with the rows.
- (void)toggleModes{
 if(self.busy)return;
 NSUInteger count=[self modeRows].count;
 NSMutableArray *paths=[NSMutableArray array];
 for(NSUInteger i=0;i<count;i++)[paths addObject:[NSIndexPath indexPathForRow:2+i inSection:0]];
 BOOL open=!self.modesExpanded;
 // First time the options are opened: one short recommendation, unless the welcome tour already gave it. What it says is what the shipped blockAdSense PAC does.
 if(open&&![NSFileManager.defaultManager fileExistsAtPath:MYBMobileFile(@"/var/mobile/Library/MYbloXX/TourSawRecommendation")])
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.4*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   MYBTipShowOnce(self,@"blockAdSenseRecommended",@"Recommended: blockAdSense",@"MYXXdev™ recommends it. It blocks one more address than Default, graph.facebook.com, which apps use to talk to Facebook. It can stop Facebook and Messenger sign-in; switch it off then. You choose.",@"star.fill");});
 self.modesExpanded=open;self.menuSections=[self buildSections];
 UITableView *table=self.tableView;
 [table performBatchUpdates:^{
  if(open)[table insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationFade];
  else [table deleteRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationFade];
 } completion:nil];
 UITableViewCell *head=[table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
 if([head isKindOfClass:MYBPrismCell.class])[self styleExpander:(MYBPrismCell *)head animated:YES];
}
- (void)styleExpander:(MYBPrismCell *)cell animated:(BOOL)animated{
 UIImageView *chevron=[cell.mybAccessoryView isKindOfClass:UIImageView.class]?(UIImageView *)cell.mybAccessoryView:nil;
 if(!chevron){
  // Same glyph size, weight, tint and 18x20 slot as the navigation chevrons (MYBPrismCell), so it sits in the same trailing position.
  chevron=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
  chevron.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
  chevron.tintColor=[MYBMuted() colorWithAlphaComponent:.7];chevron.contentMode=UIViewContentModeScaleAspectFit;
  chevron.translatesAutoresizingMaskIntoConstraints=NO;[chevron.widthAnchor constraintEqualToConstant:18].active=YES;[chevron.heightAnchor constraintEqualToConstant:20].active=YES;cell.mybAccessoryView=chevron;
 }
 CGAffineTransform target=self.modesExpanded?CGAffineTransformMakeRotation(M_PI):CGAffineTransformIdentity;
 if(animated&&!MYBReduceMotion())[UIView animateWithDuration:.22 animations:^{chevron.transform=target;}];else chevron.transform=target;
 cell.isAccessibilityElement=YES;cell.accessibilityTraits=UIAccessibilityTraitButton;
 cell.accessibilityLabel=[NSString stringWithFormat:@"Blocking Mode, %@",MYBModeDisplay(self.mode)];
 cell.accessibilityValue=self.modesExpanded?@"Expanded":@"Collapsed";
 cell.accessibilityHint=self.modesExpanded?@"Collapses the list of modes":@"Shows the list of modes";
}
// Options combine: tapping one adds or removes it. Default clears them. Adding an option that blocks more shows that option’s
// warning first; removing one, and Default, apply straight away.
- (void)toggleOption:(NSString *)option{
 if(self.busy||!option)return;
 NSArray *chosen=MYBOptionsForModeID(self.mode)?:@[];
 if([option isEqual:@"Default"]){[self selectMode:@"Default"];return;}
 NSMutableSet *next=[NSMutableSet setWithArray:chosen];BOOL adding=![next containsObject:option];
 if(adding)[next addObject:option];else [next removeObject:option];
 NSString *mode=MYBModeIDForOptions(next);
 if(!adding){[self selectMode:mode];return;}
 [self selectMode:mode warnFor:option];
}
- (void)selectMode:(NSString *)mode{[self selectMode:mode warnFor:nil];}
- (void)selectMode:(NSString *)mode warnFor:(NSString *)added{
 if(self.busy||!mode)return;
 __weak typeof(self) weak=self;
 void(^apply)(void)=^{[weak runHelper:@[@"selectmode",mode] completion:^(__unused int rc){[weak rebuildMenu];}];};
 if(!added||[mode isEqual:@"Default"]||[mode isEqual:self.mode]){apply();return;} // removing an option, or Default, never needs a warning
 NSString *warning=MYBModeWarning(added,NO);
 [self confirm:[NSString stringWithFormat:@"Switch to %@?",MYBModeDisplay(mode)] message:warning?:@"This configuration adds more blocking. Some websites or app features may no longer work. You can return to Default at any time." action:apply];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 MYBPrismCell *cell=[self cardForEntry:row table:t];
 NSString *kind=row[@"switch"];
 if(kind){
  MYBPrismSwitch *control=[MYBPrismSwitch new];control.key=kind;
  BOOL protection=[kind isEqual:@"protection"];
  control.on=protection?self.enabled:NO;
  control.enabled=!self.busy;control.onTintColor=protection?MYBPositive():MYBAccent();
  [control addTarget:self action:@selector(protectionChanged:) forControlEvents:UIControlEventValueChanged];
  cell.mybAccessoryView=control;cell.selectionStyle=UITableViewCellSelectionStyleNone;
 }
 if(row[@"expander"])[self styleExpander:cell animated:NO];
 if(row[@"mode"]){
  NSArray *chosen=MYBOptionsForModeID(self.mode)?:@[];BOOL isDefault=[row[@"mode"] isEqual:@"Default"];
  BOOL current=isDefault?!chosen.count&&MYBModeIDValid(self.mode):[chosen containsObject:row[@"mode"]];
  cell.mybAccessoryType=current?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
  cell.selectionStyle=UITableViewCellSelectionStyleDefault;
 cell.accessibilityTraits=UIAccessibilityTraitButton|(current?UIAccessibilityTraitSelected:0);
 }
 [cell refreshContent];
 // A small "*Recommended" label right after the name (blockAdSense only). VoiceOver reads it as part of the row name.
 if([row[@"recommended"] boolValue]){
  NSString *name=row[@"title"]?:@"";UIFont *base=cell.mybTitleLabel.font?:[UIFont systemFontOfSize:17];
  NSMutableAttributedString *text=[[NSMutableAttributedString alloc] initWithString:name attributes:@{NSFontAttributeName:base,NSForegroundColorAttributeName:cell.mybTitleLabel.textColor?:UIColor.labelColor}];
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"  *Recommended" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold],NSForegroundColorAttributeName:[UIColor colorWithRed:1 green:.72 blue:.30 alpha:1]}]];
  cell.mybTitleLabel.attributedText=text;cell.accessibilityLabel=[name stringByAppendingString:@", recommended"];
 }
 return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(self.busy)return;
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if(row[@"expander"]){[self toggleModes];return;}
 if(row[@"mode"]){[self toggleOption:row[@"mode"]];return;}
 if(row[@"page"]){UIViewController *page=[NSClassFromString(row[@"page"]) new];if(page)[self.navigationController pushViewController:page animated:YES];return;}
 [super tableView:t didSelectRowAtIndexPath:p];
}
- (void)protectionChanged:(MYBPrismSwitch *)control{[self runHelper:@[control.on?@"enable":@"disable"] completion:^(__unused int rc){[self checkLocalHealth];}];}
- (void)checkLocalHealth {
 // Verification is local and instant now: there is no PAC server to probe.
 NSInteger previous=self.localHealth,result=[[self computeStatusModel][@"active"] boolValue]?1:0;self.statusCache=nil;
 self.localHealth=result;
 if(previous!=result||!self.menuSections.count)[self rebuildMenu];else [self refreshHeroIfNeeded];
}

@end
#if !MYB_PREVIEW_HARNESS
// PreferenceLoader requires a real PSListController. Its own table is left
// completely alone; the UIKit dashboard is embedded as a child and laid out
// with explicit frames. Auto Layout anchors on a UIScrollView/UITableView host
// resolve against its scrolling content area, not its visible frame, which is
// what made the previous embedding drift and bleed into the home-indicator area.
@interface MYBModernController : PSListController <MYBDashboardScrollOwner>
@property (nonatomic,assign) BOOL userScrolled; // latched by the first real touch scroll: until then the bar title stays at alpha 0, whatever the layout offsets are
@property (nonatomic,strong) UILabel *barTitle; // the bar title: invisible at rest, fades in as the header’s own MYbloXX name scrolls under the bar
@property (nonatomic,strong) UIView *titleHost; // what the bar holds: UIKit changes the alpha of a titleView during a push, so the fade is done on the label inside it, which UIKit never touches
@property (nonatomic,strong) UIView *topScrim; // fixed cover over the status and navigation bar area, faded in as the dashboard scrolls
@property (nonatomic,strong) MYBDashboardController *dashboard;
@property (nonatomic,assign) BOOL dashboardPlaced; // the first layout puts the header below the bar once, never again
@end
@implementation MYBModernController
- (BOOL)mybHasBrandedHeader{return YES;}
// The bar reads this screen’s navigation item when it is pushed, before viewDidLoad. The faded title view must already be in place
// then, or the bar draws the stock "MYbloXX®" title for the first moments. So it is created as early as the object exists.
- (void)mybEnsureBarTitle{
 if(!self.barTitle){
  UILabel *barTitle=[UILabel new];barTitle.text=@"MYbloXX\u00ae";barTitle.textColor=UIColor.whiteColor;barTitle.font=[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];barTitle.alpha=0;barTitle.isAccessibilityElement=NO;[barTitle sizeToFit];
  self.barTitle=barTitle;
  UIView *host=[[UIView alloc] initWithFrame:barTitle.bounds];host.isAccessibilityElement=NO;[host addSubview:barTitle];self.titleHost=host;
 }
 if(self.navigationItem.titleView!=self.titleHost)self.navigationItem.titleView=self.titleHost;
 MYBStyleNavigationItem(self); // the clear title look is in place before the push starts, so no title text is ever drawn
 self.navigationItem.title=@"";
}
- (void)setSpecifier:(PSSpecifier *)specifier{[super setSpecifier:specifier];[self mybEnsureBarTitle];}
- (void)setTitle:(NSString *)title{[super setTitle:title];[self mybEnsureBarTitle];}
- (NSArray *)specifiers {
 if(!_specifiers) {
  PSSpecifier *section=[PSSpecifier preferenceSpecifierNamed:@"MYbloXX®" target:nil set:NULL get:NULL detail:nil cell:PSGroupCell edit:nil];
  _specifiers=[NSMutableArray arrayWithObject:section];
 }
 return _specifiers;
}
- (void)viewDidLoad {
 [super viewDidLoad];
 self.title=@"MYbloXX®";
 self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
 self.view.backgroundColor=MYBBackground();
 UIView *host=self.view;
 if([host isKindOfClass:UIScrollView.class]){
  // The stock table is hidden behind the dashboard: it must not scroll, bounce or inset.
  UIScrollView *scroll=(UIScrollView *)host;
  scroll.scrollEnabled=NO;scroll.bounces=NO;scroll.alwaysBounceVertical=NO;scroll.showsVerticalScrollIndicator=NO;
  scroll.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;
  if([host isKindOfClass:UITableView.class])((UITableView *)host).separatorStyle=UITableViewCellSeparatorStyleNone;
 }
 // The dashboard background runs behind the status bar and navigation bar. The host paints the same backdrop the
 // dashboard uses, so neither the bar area nor a push/pop transition ever shows a flat dark fill.
 MYBBackdropView *backdrop=[MYBBackdropView new];
 if([host isKindOfClass:UITableView.class])((UITableView *)host).backgroundView=backdrop;
 else{backdrop.frame=host.bounds;backdrop.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[host insertSubview:backdrop atIndex:0];}
 MYBDashboardController *dashboard=[MYBDashboardController new];
 dashboard.chromeOwner=self;
 self.dashboard=dashboard;
 [self addChildViewController:dashboard];
 dashboard.view.translatesAutoresizingMaskIntoConstraints=YES;
 dashboard.view.autoresizingMask=UIViewAutoresizingNone;
 [host addSubview:dashboard.view];
 [dashboard didMoveToParentViewController:self];
 // The bar’s scroll-edge appearance follows the dashboard’s scrolling, not the hidden stock table.
 [self setContentScrollView:dashboard.tableView forEdge:NSDirectionalRectEdgeTop];
 // The dashboard scrolls full-bleed under a transparent bar, so rows could show through the status area. This fixed cover has
 // the same dark blur the other screens' bars use. It is invisible at rest (the purple background shows) and fades in as
 // soon as content moves under the bar. It does not rely on UIKit’s scroll-edge detection, which does not see this hosted table.
 UIView *scrim=[UIView new];scrim.userInteractionEnabled=NO;scrim.alpha=0;scrim.isAccessibilityElement=NO;
 if(!MYBReduceTransparency()){UIVisualEffectView *blur=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];blur.frame=scrim.bounds;blur.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[scrim addSubview:blur];}
 scrim.backgroundColor=[MYBBackground() colorWithAlphaComponent:MYBReduceTransparency()?1:.62];
 self.topScrim=scrim;[host addSubview:scrim];
 // UIKit never sees this hosted table scroll, so it cannot switch the bar from its at-rest look (title hidden) to its scrolled look.
 // The title is therefore driven here, from the same scroll position as the scrim.
 [self mybEnsureBarTitle];
}
static UILabel *MYBHeaderName(UIView *root,int depth){
 if([root isKindOfClass:UILabel.class]&&[((UILabel *)root).text hasPrefix:@"MYbloXX\u00ae"]&&((UILabel *)root).font.pointSize>=24)return (UILabel *)root;
 if(depth>6)return nil;
 for(UIView *sub in root.subviews){UILabel *found=MYBHeaderName(sub,depth+1);if(found)return found;}
 return nil;
}
- (void)mybDashboardDidScroll:(UIScrollView *)scroll{
 CGFloat moved=scroll.contentOffset.y+scroll.adjustedContentInset.top; // 0 at rest
 CGFloat alpha=MAX(0,MIN(1,moved/10));
 if(self.topScrim.alpha!=alpha)self.topScrim.alpha=alpha;
 // The bar title appears as the header’s large MYbloXX name passes under the bar: from its middle (starting) to its bottom edge (fully shown).
 CGFloat start=34,end=64;UITableView *table=[scroll isKindOfClass:UITableView.class]?(UITableView *)scroll:nil;
 UILabel *name=table.tableHeaderView?MYBHeaderName(table.tableHeaderView,0):nil;
 if(name&&name.window){CGRect r=[name convertRect:name.bounds toView:table.tableHeaderView];CGRect h=[table.tableHeaderView convertRect:r toView:table];start=CGRectGetMidY(h);end=MAX(start+1,CGRectGetMaxY(h));}
 if(scroll.isTracking||scroll.isDragging||scroll.isDecelerating)self.userScrolled=YES;
 CGFloat titleAlpha=self.userScrolled?MAX(0,MIN(1,(moved-start)/(end-start))):0;
 if(self.titleHost&&self.navigationItem.titleView!=self.titleHost)self.navigationItem.titleView=self.titleHost; // Settings can clear it; the faded title is the only one drawn
 if(self.barTitle&&self.barTitle.alpha!=titleAlpha)self.barTitle.alpha=titleAlpha;
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 UIView *host=self.view;
 if([host isKindOfClass:UIScrollView.class]){
  UIScrollView *scroll=(UIScrollView *)host;
  if(!CGPointEqualToPoint(scroll.contentOffset,CGPointZero))scroll.contentOffset=CGPointZero;
  if(!UIEdgeInsetsEqualToEdgeInsets(scroll.contentInset,UIEdgeInsetsZero))scroll.contentInset=UIEdgeInsetsZero;
 }
 // Full-bleed: the dashboard starts at the top of the screen and keeps the system’s safe-area inset, so its background
 // fills the status and navigation bar area and the bar’s scroll-edge appearance follows its scrolling.
 CGRect frame=host.bounds;
 if(!CGRectEqualToRect(self.dashboard.view.frame,frame)){self.dashboard.view.frame=frame;}
 UITableView *table=self.dashboard.tableView;
 table.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentAlways;
 if(!self.dashboardPlaced&&table.adjustedContentInset.top>0){table.contentOffset=CGPointMake(0,-table.adjustedContentInset.top);self.dashboardPlaced=YES;}
 [host bringSubviewToFront:self.dashboard.view];
 CGFloat top=MAX(self.dashboard.tableView.safeAreaInsets.top,host.safeAreaInsets.top);
 self.topScrim.frame=CGRectMake(0,0,host.bounds.size.width,top);[host bringSubviewToFront:self.topScrim];
 [self mybDashboardDidScroll:self.dashboard.tableView];
}
- (void)viewWillAppear:(BOOL)animated {
 [super viewWillAppear:animated];
 MYBStyleNavigation(self);
 if(self.titleHost)self.navigationItem.titleView=self.titleHost; // the faded bar title is the only title drawn, from the first appearance
 self.navigationItem.backButtonTitle=@"MYbloXX\u00ae";self.navigationItem.title=@""; // child pages keep their back label; no system title can draw
}
@end
#endif
