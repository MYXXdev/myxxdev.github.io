#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBAccelerationPolicy.h"
#import "../Shared/MYBAppSwitchLog.h"
#import <objc/message.h>
#import <notify.h>
@interface MYBAppControlController : MYBMenuBase<UISearchResultsUpdating>
@property(nonatomic,strong) NSMutableDictionary *prefs;
@property(nonatomic,strong) NSArray *apps;
@property(nonatomic,strong) NSArray *filtered;
@property(nonatomic,assign) BOOL loadingApps;
@property(nonatomic,assign) NSUInteger loadGeneration;
@property(nonatomic,strong) UISearchController *search;
@end
// App icons: looked up once per app on a serial background queue, decoded there, cached, and applied to the cell only if it
// still shows that app. Scrolling never triggers a lookup for an icon already cached, and a missing icon keeps the symbol.
static NSCache<NSString *,UIImage *> *MYBIconCache(void){static NSCache *c;static dispatch_once_t once;dispatch_once(&once,^{c=[NSCache new];c.countLimit=160;});return c;}
static NSMutableSet<NSString *> *MYBIconPending(void){static NSMutableSet *s;static dispatch_once_t once;dispatch_once(&once,^{s=[NSMutableSet set];});return s;}
static NSMutableSet<NSString *> *MYBIconMissing(void){static NSMutableSet *s;static dispatch_once_t once;dispatch_once(&once,^{s=[NSMutableSet set];});return s;}
static dispatch_queue_t MYBIconQueue(void){static dispatch_queue_t q;static dispatch_once_t once;dispatch_once(&once,^{q=dispatch_queue_create("net.myxxdev.mybloxx.icons",DISPATCH_QUEUE_SERIAL);});return q;}
static UIImage *MYBLoadAppIcon(NSString *bundle){
 Class ui=UIImage.class;SEL sel=NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
 if(![ui respondsToSelector:sel])return nil;
 CGFloat scale=UIScreen.mainScreen.scale;UIImage *raw=((UIImage *(*)(id,SEL,id,int,CGFloat))objc_msgSend)(ui,sel,bundle,2,scale);if(!raw)return nil;
 UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat preferredFormat];format.scale=scale;format.opaque=NO;
 return [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(34,34) format:format] imageWithActions:^(UIGraphicsImageRendererContext *context){(void)context;[raw drawInRect:CGRectMake(0,0,34,34)];}];
}
@implementation MYBAppControlController
- (void)applyIcon:(UIImage *)icon toCellForBundle:(NSString *)bid{
 for(NSIndexPath *path in self.tableView.indexPathsForVisibleRows){
  if(path.row>=(NSInteger)self.filtered.count||self.showsPlaceholder)continue;
  if(![self.filtered[path.row][@"id"] isEqual:bid])continue;
  MYBPrismCell *cell=(MYBPrismCell *)[self.tableView cellForRowAtIndexPath:path];if([cell isKindOfClass:MYBPrismCell.class]&&icon){cell.mybAppIcon=icon;[cell refreshContent];}
 }
}
- (UIImage *)cachedIconForBundle:(NSString *)bid{
 UIImage *hit=[MYBIconCache() objectForKey:bid];if(hit||[MYBIconMissing() containsObject:bid]||[MYBIconPending() containsObject:bid])return hit;
 [MYBIconPending() addObject:bid];__weak typeof(self) weak=self;
 dispatch_async(MYBIconQueue(),^{
  UIImage *icon=MYBLoadAppIcon(bid);
  dispatch_async(dispatch_get_main_queue(),^{
   [MYBIconPending() removeObject:bid];
   if(!icon){[MYBIconMissing() addObject:bid];return;}
   [MYBIconCache() setObject:icon forKey:bid];[weak applyIcon:icon toCellForBundle:bid];
  });
 });
 return nil;
}
- (NSString *)file{return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist");}
- (NSString *)heroEyebrow{return @"App Switch Control";}
- (NSString *)heroTitle{return @"App Switch Control";}
- (NSString *)heroDetail{return @"Temporarily pauses MYbloXX\u00ae website blocking for the whole phone while a selected app is in front.";}
- (void)rebuildMenu{self.title=@"App Switch Control";self.prefs=[[NSDictionary dictionaryWithContentsOfFile:self.file] mutableCopy]?:[NSMutableDictionary dictionary];[self.tableView reloadData];}
// Installed apps are enumerated off the main thread; the screen shows a loading
// card until they arrive, and a stale result can never overwrite a newer one.
- (void)loadApps{
 self.loadingApps=YES;NSUInteger generation=++self.loadGeneration;[self.tableView reloadData];
 __weak typeof(self) weakSelf=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSMutableArray *apps=[NSMutableArray array];Class cls=NSClassFromString(@"LSApplicationWorkspace");
  id workspace=[cls respondsToSelector:NSSelectorFromString(@"defaultWorkspace")]?((id(*)(id,SEL))objc_msgSend)(cls,NSSelectorFromString(@"defaultWorkspace")):nil;SEL all=NSSelectorFromString(@"allApplications");
  if([workspace respondsToSelector:all])for(id app in ((id(*)(id,SEL))objc_msgSend)(workspace,all)){NSString *type=[app valueForKey:@"applicationType"],*bid=[app valueForKey:@"applicationIdentifier"],*name=[app valueForKey:@"localizedName"];if([type isEqual:@"User"]&&bid.length)[apps addObject:@{@"id":bid,@"name":name?:bid}];}
  NSArray *sorted=[apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];}];
  dispatch_async(dispatch_get_main_queue(),^{
   typeof(self) strongSelf=weakSelf;if(!strongSelf||strongSelf.loadGeneration!=generation)return;
   strongSelf.apps=sorted;strongSelf.loadingApps=NO;[strongSelf applyFilter];
  });
 });
}
- (void)applyFilter{
 NSString *query=[self.search.searchBar.text?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 self.filtered=query.length?[self.apps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *app,__unused NSDictionary *bindings){return [app[@"name"] localizedCaseInsensitiveContainsString:query]||[app[@"id"] localizedCaseInsensitiveContainsString:query];}]]:self.apps;
 [self.tableView reloadData];
}
- (void)viewDidLoad{
 [super viewDidLoad];
 self.apps=@[];self.filtered=@[];
 self.search=[[UISearchController alloc] initWithSearchResultsController:nil];self.search.searchResultsUpdater=self;self.search.obscuresBackgroundDuringPresentation=NO;self.search.searchBar.placeholder=@"Find an app";
 self.navigationItem.searchController=self.search;self.navigationItem.hidesSearchBarWhenScrolling=NO;self.definesPresentationContext=YES;
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Activity" style:UIBarButtonItemStylePlain target:self action:@selector(openActivity)];
 [self loadApps];
}
- (void)openActivity{[self.navigationController pushViewController:[NSClassFromString(@"MYBAppSwitchActivityController") new] animated:YES];}
- (void)updateSearchResultsForSearchController:(UISearchController *)search{(void)search;[self applyFilter];}
- (BOOL)showsPlaceholder{return self.loadingApps||!self.filtered.count;}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table{return 1;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{return self.showsPlaceholder?1:self.filtered.count;}
- (NSString *)sectionHeaderTitle:(NSInteger)section{(void)section;return @"YOUR APPS";}
- (NSString *)sectionFooterTitle:(NSInteger)section{(void)section;return @"While a selected app is in front, MYbloXX® website blocking is paused for the whole phone, not only inside that app. Blocking comes back when you leave the app or lock the phone. SpeedyAds is a separate feature: it is switched on for the same app, inside that app only. Tap Activity to see when blocking was paused and resumed.";}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path{
 MYBPrismCell *cell=[MYBPrismCell cellForTable:table];
 if(self.showsPlaceholder){
  BOOL searching=self.search.searchBar.text.length>0;
  cell.mybTitleLabel.text=self.loadingApps?@"Loading apps...":(searching?@"No matching apps":@"No apps found");
  cell.mybDetailLabel.text=self.loadingApps?@"Reading your installed apps":(searching?@"Try a different name":@"Install an app, then reopen this screen");
  cell.mybIconView.image=[UIImage systemImageNamed:self.loadingApps?@"hourglass":@"magnifyingglass"];cell.tone=MYBToneSlate;cell.selectionStyle=UITableViewCellSelectionStyleNone;
  if(self.loadingApps){UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];spinner.color=MYBMuted();[spinner startAnimating];cell.mybAccessoryView=spinner;}
 }else{
  NSDictionary *app=self.filtered[path.row];NSString *bid=app[@"id"];BOOL on=[self.prefs[[@"enabled-" stringByAppendingString:bid]] boolValue];
  cell.mybTitleLabel.text=app[@"name"];cell.mybTitleLabel.numberOfLines=2;cell.mybDetailLabel.text=on?@"Pauses blocking while open":@"Blocking stays on";
  cell.mybIconView.image=[UIImage systemImageNamed:on?@"bolt.fill":@"app"];cell.tone=on?MYBToneAmber:MYBToneSlate;
  UIImage *icon=[self cachedIconForBundle:bid];if(icon)cell.mybAppIcon=icon;
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=bid;toggle.on=on;toggle.onTintColor=MYBAccent();[toggle addTarget:self action:@selector(changeApp:) forControlEvents:UIControlEventValueChanged];
  cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;
 }
 [cell refreshContent];return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path{[table deselectRowAtIndexPath:path animated:YES];}
- (void)changeApp:(MYBPrismSwitch *)toggle{
 NSString *bid=toggle.key;if(!bid.length)return;
 NSDictionary *stored=[NSDictionary dictionaryWithContentsOfFile:self.file]?:@{};NSMutableDictionary *current=[MYBAppControlChoices(stored) mutableCopy];if(stored[@"Uninstalling"])current[@"Uninstalling"]=stored[@"Uninstalling"];current[[@"enabled-" stringByAppendingString:bid]]=@(toggle.on);
 if(![current writeToFile:self.file atomically:YES]){[toggle setOn:!toggle.on animated:YES];MYBMessage(self,@"Couldn’t Save",@"Your previous app choices are unchanged.");return;}
 self.prefs=current;notify_post("net.myxxdev.mybloxx.speedyads.changed");[self refreshFilesBackup];
 // Acceleration loads only into the apps selected here: have the helper write that list. App Switch Control itself works without it, so a failure is
 // reported but the selection is kept.
 [self silentHelper:@[@"adsfilter"] completion:^(int rc){if(rc)MYBMessage(self,@"Saved, Acceleration Not Applied",[NSString stringWithFormat:@"Your choice is saved, but MYbloXX® could not update the list of apps that load ad acceleration (error %d). Use Repair MYbloXX® and try again.",rc]);}];
 // Refresh only this row’s caption and tile; reloading the table would interrupt the switch animation.
 NSUInteger row=[self.filtered indexOfObjectPassingTest:^BOOL(NSDictionary *app,NSUInteger i,BOOL *stop){(void)i;(void)stop;return [app[@"id"] isEqual:bid];}];
 if(row!=NSNotFound){NSIndexPath *path=[NSIndexPath indexPathForRow:(NSInteger)row inSection:0];MYBPrismCell *cell=(MYBPrismCell *)[self.tableView cellForRowAtIndexPath:path];if(cell){cell.mybDetailLabel.text=toggle.on?@"Pauses blocking while open":@"Blocking stays on";if(!cell.mybAppIcon){cell.mybIconView.image=[UIImage systemImageNamed:toggle.on?@"bolt.fill":@"app"];cell.tone=toggle.on?MYBToneAmber:MYBToneSlate;}}}
}
@end

// Raw foreground trace for support (Status & Diagnostics only). It is NOT the user-facing history: that is App Switch Control > Activity.
// Short, local record of what App Switch Control’s SpringBoard side did for the last app transitions (detected, skipped and why,
// overlay shown or not, helper result). It exists so a missing "Preparing App" screen can be explained from the device.
@interface MYBAppControlTraceController : MYBMenuBase
@end
@implementation MYBAppControlTraceController
- (NSString *)heroEyebrow{return @"Status & Diagnostics";}
- (NSString *)heroTitle{return @"App Switch Raw Trace";}
- (NSString *)heroDetail{return @"Technical log of foreground changes, for support. Not a history of pauses; see App Switch Control › Activity.";}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (void)rebuildMenu{
 self.title=@"App Switch Raw Trace";
 NSArray *log=[NSArray arrayWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.appcontrol-trace.plist")];
 NSMutableArray *rows=[NSMutableArray array];
 static NSDateFormatter *f;static dispatch_once_t once;dispatch_once(&once,^{f=[NSDateFormatter new];f.dateFormat=@"HH:mm:ss";});
 for(NSDictionary *entry in log.reverseObjectEnumerator){
  if(![entry isKindOfClass:NSDictionary.class]||![entry[@"e"] isKindOfClass:NSString.class])continue;
  NSDate *t=[entry[@"t"] isKindOfClass:NSDate.class]?entry[@"t"]:nil;
  [rows addObject:@{@"title":entry[@"e"],@"value":t?[f stringFromDate:t]:@"",@"icon":@"bolt.fill"}];
 }
 if(!rows.count)[rows addObject:@{@"title":@"Nothing recorded yet",@"detail":@"Open an app you selected in App Switch Control. If this stays empty after a respring, the SpringBoard side is not running.",@"icon":@"questionmark.circle"}];
 self.menuSections=@[@{@"title":@"RECENT ACTIVITY",@"rows":rows}];
 [self.tableView reloadData];
}
@end

// App Switch Control › Activity: only what it did for the person. Paused blocking, resumed blocking, and the times it couldn’t.
// The raw foreground trace (Settings, InCallService, __none__) is NOT shown here; it lives in Status & Diagnostics.
@interface MYBAppSwitchActivityController : MYBMenuBase
@property(nonatomic,strong) NSArray<NSDictionary *> *events;
@end
@implementation MYBAppSwitchActivityController
- (NSString *)heroTitle{return @"App Switch Activity";}
- (NSString *)heroDetail{return @"When blocking was paused and resumed for the whole phone because of a selected app.";}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (void)rebuildMenu{self.title=@"Activity";self.events=MYBAppSwitchEvents(MYBAppSwitchFile());[self.tableView reloadData];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{return 1;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.events.count?self.events.count+1:1;}
- (NSString *)sectionHeaderTitle:(NSInteger)s{return @"RECENT";}
- (NSString *)sectionFooterTitle:(NSInteger)s{return @"Pausing blocking affects the whole phone while the app is in front. Kept on this iPhone only; the latest 40 events. Clearing it does not change which apps are selected.";}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 MYBPrismCell *cell=[MYBPrismCell cellForTable:t];
 if(!self.events.count){cell.mybTitleLabel.text=@"Nothing yet";cell.mybDetailLabel.text=@"Open an app you selected and its pauses will appear here.";cell.mybIconView.image=[UIImage systemImageNamed:@"bolt.slash"];cell.tone=MYBToneSlate;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];return cell;}
 if(p.row==(NSInteger)self.events.count){cell.mybTitleLabel.text=@"Clear Activity";cell.mybDetailLabel.text=@"Removes this list only. Your selected apps stay.";cell.mybIconView.image=[UIImage systemImageNamed:@"trash"];cell.tone=MYBToneRose;[cell refreshContent];return cell;}
 NSDictionary *e=self.events[p.row];NSString *kind=e[@"kind"];BOOL bad=[kind isEqual:@"failed"]||[kind isEqual:@"resume-failed"];
 NSString *name=[e[@"name"] length]?e[@"name"]:e[@"app"];NSRelativeDateTimeFormatter *f=[NSRelativeDateTimeFormatter new];f.unitsStyle=NSRelativeDateTimeFormatterUnitsStyleShort;
 cell.mybTitleLabel.text=MYBAppSwitchTitle(kind);cell.mybTitleLabel.numberOfLines=2;
 cell.mybDetailLabel.text=[NSString stringWithFormat:@"%@ · %@",name,[f localizedStringForDate:[NSDate dateWithTimeIntervalSince1970:[e[@"time"] doubleValue]] relativeToDate:NSDate.date]];
 cell.mybIconView.image=[UIImage systemImageNamed:bad?@"exclamationmark.triangle.fill":[kind isEqual:@"paused"]?@"pause.circle.fill":@"play.circle.fill"];cell.tone=bad?MYBToneRose:[kind isEqual:@"paused"]?MYBToneAmber:MYBToneGreen;cell.selectionStyle=UITableViewCellSelectionStyleNone;
 [cell refreshContent];return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];
 if(self.events.count&&p.row==(NSInteger)self.events.count)MYBConfirmDestructive(self,@"Clear activity?",@"This removes the list only. The apps you selected stay as they are.",@"Clear Activity",^{MYBAppSwitchClear(MYBAppSwitchFile());[self rebuildMenu];});
}
@end

// Ad Network Blocking (advanced): the apps whose Google Mobile Ads, Meta Audience Network, Vungle/Liftoff, Unity Ads, Mintegral and LevelPlay loads are answered "no ad". Default: none.
// Same app list as App Control; a separate switch per app in the In-App Ad Blocking preferences ("ads-sdk-<bundle id>"). The app reads
// its switch when it starts, so it must be reopened. Not covered and not confirmed on a device: see Shared/MYBAdSDK.h.
#import "../Shared/MYBAdSDK.h"
#import "../Shared/MYBInAppAds.h"
#import <sys/stat.h>
#import <roothide.h>
#import "../Shared/MYBAdsFilter.h"
#import "../Shared/MYBAdsReport.h"
#import "../Shared/MYBAdSDKStatus.h"
#import "../Shared/MYBVersion.h"
@interface MYBAdSDKController : MYBAppControlController
@property(nonatomic,strong) NSDictionary *seen; // apps whose copy of the library has reported in (from MYbloXX\u00ae\u2019s service); nil when unreachable
@end
@implementation MYBAdSDKController
- (NSString *)file{return MYBMobileFile(MYB_ADS_PREFS_PATH);}
- (NSString *)heroEyebrow{return @"In-App Ad Blocking";}
- (NSString *)heroTitle{return @"Ad Network Blocking";}
- (NSString *)heroDetail{return @"Blocks ads from the big ad networks inside your apps. New apps are added automatically.";}
- (void)rebuildMenu{self.title=@"Ad Network Blocking";self.prefs=[[NSDictionary dictionaryWithContentsOfFile:self.file] mutableCopy]?:[NSMutableDictionary dictionary];[self.tableView reloadData];[self loadSeen];}
// Which apps' copies of the library have reported in. Only the library itself, running in the app, can prove it loaded.
- (void)loadSeen{
 __weak typeof(self) weak=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  NSData *d=MYBLoopbackGET(MYB_BRIDGE_PORT,@"/mybloxx-ads-sdk-read");id j=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;
  NSDictionary *apps=[j isKindOfClass:NSDictionary.class]&&[j[@"ok"] boolValue]&&[j[@"apps"] isKindOfClass:NSDictionary.class]?j[@"apps"]:nil;
  dispatch_async(dispatch_get_main_queue(),^{typeof(self) strong=weak;if(!strong)return;if(![strong.seen isEqual:apps]){strong.seen=apps;[strong.tableView reloadData];}});
 });
}
- (NSString *)sectionFooterTitle:(NSInteger)section{(void)section;return @"Every app is on automatically, including apps you install later. Close and reopen an app after changing its switch. Only six ad networks are covered (not AppLovin MAX, Google IMA or others). If an app misbehaves, switch it off here.";}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path{
 UITableViewCell *base=[super tableView:table cellForRowAtIndexPath:path];
 if(self.showsPlaceholder||![base isKindOfClass:MYBPrismCell.class])return base;
 MYBPrismCell *cell=(MYBPrismCell *)base;NSDictionary *app=self.filtered[path.row];NSString *bid=app[@"id"];
 BOOL on=MYBAdSDKSelected(self.prefs,bid);
 // "Active" only once the library itself has reported from inside the app; a saved switch and a written filter are not proof it loaded.
 NSDictionary *seenApp=self.seen[bid];MYBSDKState state=MYBAdSDKStatus(on,MYBAdSDKChangedAt(self.prefs,bid),seenApp,self.seen!=nil,@MYB_COMPONENT_VERSION);
 BOOL active=state==MYBSDKBlocking||state==MYBSDKHooksInstalled||state==MYBSDKLoadedNoSDK;
 cell.mybDetailLabel.text=MYBAdSDKStatusText(state,seenApp);
 cell.mybIconView.image=[UIImage systemImageNamed:state==MYBSDKBlocking?@"nosign":(on?(active?@"checkmark.circle":@"hourglass"):@"app")];cell.tone=state==MYBSDKBlocking?MYBToneGreen:MYBToneSlate;
 MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=bid;toggle.on=on;toggle.onTintColor=MYBAccent();[toggle addTarget:self action:@selector(changeApp:) forControlEvents:UIControlEventValueChanged];
 toggle.accessibilityLabel=[NSString stringWithFormat:@"Block ad SDK loads in %@",app[@"name"]];cell.mybAccessoryView=toggle;[cell refreshContent];return cell;
}
- (void)changeApp:(MYBPrismSwitch *)toggle{
 NSString *bid=toggle.key;if(!bid.length||!MYBAdSDKSelected(@{[MYB_ADSDK_PREFIX stringByAppendingString:bid]:@YES},bid)){[toggle setOn:NO animated:YES];return;} // system apps are never selectable
 NSMutableDictionary *current=[[NSDictionary dictionaryWithContentsOfFile:self.file] mutableCopy]?:[NSMutableDictionary dictionary];
 current[[MYB_ADSDK_PREFIX stringByAppendingString:bid]]=@(toggle.on);
 current[[MYB_ADSDK_CHANGED_PREFIX stringByAppendingString:bid]]=@(NSDate.date.timeIntervalSince1970); // reports from before this moment describe an older choice
 NSDictionary *previous=[NSDictionary dictionaryWithContentsOfFile:self.file];
 if(![current writeToFile:self.file atomically:YES]){[toggle setOn:!toggle.on animated:YES];MYBMessage(self,@"Couldn’t Save",@"Your previous choice is unchanged.");return;}
 self.prefs=current;[self.tableView reloadData];
 // The loader reads its list of apps when an app starts: ask the helper to write exactly the catalogue plus the selected apps. Only after the helper
 // has written and read that list back is the choice kept; otherwise the previous choice is restored.
 BOOL wanted=toggle.on;
 [self silentHelper:@[@"adsfilter"] completion:^(int rc){
  if(rc==0)return;
  NSMutableDictionary *back=[previous mutableCopy]?:[NSMutableDictionary dictionary];[back writeToFile:self.file atomically:YES];self.prefs=back;[self.tableView reloadData];
  MYBMessage(self,@"Couldn’t Apply the Change",[NSString stringWithFormat:@"MYbloXX® could not update the list of apps that load Ad Network Blocking (error %d), so your previous choice was restored. %@Use Repair MYbloXX® and try again.",rc,wanted?@"":@""]);
 }];
}
@end
