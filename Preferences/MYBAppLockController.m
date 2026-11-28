#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBTips.h"
#import <objc/message.h>
#import <notify.h>
#import "../Shared/MYBConnectivity.h"
#import "../Shared/MYBAppLockState.h"
// App Lock & Previews (and the app picker it shares with Notification Privacy). Every switch starts OFF and no app is selected until the person chooses one.
// Settings, phone and emergency interfaces, system services and the recovery apps are never listed (MYBLockEligible).
static NSString *LockFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.applock.plist");}
static NSDictionary *LockConfig(void){return [NSDictionary dictionaryWithContentsOfFile:LockFile()]?:@{};}
static BOOL LockSave(NSDictionary *config){BOOL ok=[config writeToFile:LockFile() atomically:YES];if(ok)notify_post("net.myxxdev.mybloxx.applock.changed");return ok;}
static NSString *NotifFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.notifprivacy.plist");}
static NSCache<NSString *,UIImage *> *LockIcons(void){static NSCache *c;static dispatch_once_t once;dispatch_once(&once,^{c=[NSCache new];c.countLimit=160;});return c;}
static UIImage *LockIcon(NSString *bundle){
 UIImage *hit=[LockIcons() objectForKey:bundle];if(hit)return hit;
 SEL sel=NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");if(![UIImage.class respondsToSelector:sel])return nil;
 CGFloat scale=UIScreen.mainScreen.scale;UIImage *raw=((UIImage *(*)(id,SEL,id,int,CGFloat))objc_msgSend)(UIImage.class,sel,bundle,2,scale);if(!raw)return nil;
 UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat preferredFormat];format.scale=scale;format.opaque=NO;
 UIImage *icon=[[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(34,34) format:format] imageWithActions:^(UIGraphicsImageRendererContext *c){(void)c;[raw drawInRect:CGRectMake(0,0,34,34)];}];
 if(icon)[LockIcons() setObject:icon forKey:bundle];return icon;
}
// Installed apps the person can see (User and visible System apps), minus everything that can never be selected.
NSArray<NSDictionary *> *MYBSelectableApps(void){
 NSMutableArray *apps=[NSMutableArray array];Class cls=NSClassFromString(@"LSApplicationWorkspace");
 id workspace=[cls respondsToSelector:NSSelectorFromString(@"defaultWorkspace")]?((id(*)(id,SEL))objc_msgSend)(cls,NSSelectorFromString(@"defaultWorkspace")):nil;SEL all=NSSelectorFromString(@"allApplications");
 if([workspace respondsToSelector:all])for(id app in ((id(*)(id,SEL))objc_msgSend)(workspace,all)){
  NSString *type=[app valueForKey:@"applicationType"],*bid=[app valueForKey:@"applicationIdentifier"],*name=[app valueForKey:@"localizedName"];
  if(!bid.length||!MYBLockEligible(bid))continue;
  BOOL user=[type isEqual:@"User"],system=[type isEqual:@"System"];if(!user&&!system)continue;
  if(system){id tags=[app respondsToSelector:NSSelectorFromString(@"appTags")]?[app valueForKey:@"appTags"]:nil;if([tags isKindOfClass:NSArray.class]&&([tags containsObject:@"hidden"]||[tags containsObject:@"Hidden"]))continue;if(!LockIcon(bid))continue;}
  [apps addObject:@{@"id":bid,@"name":name.length?name:bid}];
 }
 return [apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];}];
}

// ---- app picker (Locked Apps / App Switcher Previews) -----------------------------------------------------------------------------------
@interface MYBLockAppPicker:MYBMenuBase<UISearchResultsUpdating>
@property(nonatomic,copy) NSString *listKey,*pageTitle,*pageDetail,*onDetail,*offDetail,*configPath;   // configPath nil = the App Lock file
@property(nonatomic,strong) NSArray<NSDictionary *> *apps,*filtered;
@property(nonatomic,strong) UISearchController *search;
@property(nonatomic,assign) BOOL loading;
@end
@implementation MYBLockAppPicker
- (NSString *)heroTitle{return self.pageTitle;}
- (NSString *)heroDetail{return self.pageDetail;}
- (void)viewDidLoad{
 [super viewDidLoad];self.apps=@[];self.filtered=@[];
 self.search=[[UISearchController alloc] initWithSearchResultsController:nil];self.search.searchResultsUpdater=self;self.search.obscuresBackgroundDuringPresentation=NO;self.search.searchBar.placeholder=@"Find an app";
 self.navigationItem.searchController=self.search;self.navigationItem.hidesSearchBarWhenScrolling=NO;self.definesPresentationContext=YES;
 self.loading=YES;__weak typeof(self) weak=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSArray *apps=MYBSelectableApps();dispatch_async(dispatch_get_main_queue(),^{typeof(self) me=weak;if(!me)return;me.apps=apps;me.loading=NO;[me applyFilter];});});
}
- (void)rebuildMenu{self.title=self.pageTitle;[self.tableView reloadData];}
- (void)updateSearchResultsForSearchController:(UISearchController *)search{(void)search;[self applyFilter];}
- (void)applyFilter{
 NSString *q=[self.search.searchBar.text?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 self.filtered=q.length?[self.apps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *a,NSDictionary *b){(void)b;return [a[@"name"] localizedCaseInsensitiveContainsString:q];}]]:self.apps;
 [self silentHelper:@[@"adsfilter"] completion:^(int rc){if(rc)MYBMessage(self,@"Saved, Not Applied",[NSString stringWithFormat:@"Your choice is saved, but MYbloXX® could not update which apps load App Lock (error %d). Use Repair MYbloXX® and try again.",rc]);}];
 [self.tableView reloadData];
}
- (BOOL)placeholder{return self.loading||!self.filtered.count;}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{(void)t;return 1;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{(void)t;(void)s;return self.placeholder?1:(NSInteger)self.filtered.count;}
- (NSString *)sectionHeaderTitle:(NSInteger)s{(void)s;return @"YOUR APPS";}
- (NSString *)sectionFooterTitle:(NSInteger)s{(void)s;return @"Settings, phone and emergency screens, system services and recovery apps are never listed. A change applies the next time the app opens.";}
- (NSDictionary *)config{return self.configPath?([NSDictionary dictionaryWithContentsOfFile:self.configPath]?:@{}):LockConfig();}
- (NSArray *)selected{NSArray *list=self.config[self.listKey];return [list isKindOfClass:NSArray.class]?list:@[];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 MYBPrismCell *cell=[MYBPrismCell cellForTable:t];
 if(self.placeholder){cell.mybTitleLabel.text=self.loading?@"Loading apps...":(self.search.searchBar.text.length?@"No matching apps":@"No apps found");cell.mybDetailLabel.text=self.loading?@"Reading your installed apps":@"";cell.mybIconView.image=[UIImage systemImageNamed:@"magnifyingglass"];cell.tone=MYBToneSlate;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];return cell;}
 NSDictionary *app=self.filtered[p.row];NSString *bid=app[@"id"];BOOL on=[self.selected containsObject:bid];
 cell.mybTitleLabel.text=app[@"name"];cell.mybTitleLabel.numberOfLines=2;cell.mybDetailLabel.text=on?self.onDetail:self.offDetail;cell.mybIconView.image=[UIImage systemImageNamed:on?@"lock.fill":@"app"];cell.tone=on?MYBToneViolet:MYBToneSlate;
 UIImage *icon=LockIcon(bid);if(icon)cell.mybAppIcon=icon;
 MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=bid;toggle.on=on;toggle.onTintColor=MYBAccent();[toggle addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;
 [cell refreshContent];return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{[t deselectRowAtIndexPath:p animated:YES];}
- (void)changed:(MYBPrismSwitch *)toggle{
 NSString *bid=toggle.key;if(!bid.length||!MYBLockEligible(bid))return;
 NSMutableDictionary *config=[self.config mutableCopy];NSMutableArray *list=[self.selected mutableCopy];
 if(toggle.on){if(![list containsObject:bid])[list addObject:bid];}else [list removeObject:bid];config[self.listKey]=list;
 if(!(self.configPath?[config writeToFile:self.configPath atomically:YES]:LockSave(config))){[toggle setOn:!toggle.on animated:YES];MYBMessage(self,@"Couldn’t Save",@"Your previous choices are unchanged.");return;}
 [self.tableView reloadData];
}
@end

// ---- App Lock & Previews --------------------------------------------------------------------------------------------------------------------
@interface MYBAppLockController:MYBMenuBase @end
@implementation MYBAppLockController
- (NSString *)heroTitle{return @"App Lock & Previews";}
- (NSString *)heroDetail{return @"Cover an app until Face ID unlocks it, and hide app previews in the app switcher.";}
- (BOOL)flag:(NSString *)key{return MYBConnFlag(LockConfig(),key);}
- (void)rebuildMenu{
 self.title=@"App Lock & Previews";NSDictionary *config=LockConfig();
 NSUInteger locked=[config[@"AppLockApps"] isKindOfClass:NSArray.class]?[config[@"AppLockApps"] count]:0,masked=[config[@"AppLockPreviewApps"] isKindOfClass:NSArray.class]?[config[@"AppLockPreviewApps"] count]:0;
 id until=config[@"AppLockPausedUntil"];BOOL paused=[until isKindOfClass:NSNumber.class]&&[until doubleValue]>NSDate.date.timeIntervalSince1970;
 self.menuSections=@[
  @{@"title":@"APP LOCK",@"rows":@[
   @{@"title":@"App Lock",@"detail":@"Cover chosen apps until you unlock with Face ID",@"icon":@"lock.app.dashed",@"accent":@YES,@"tone":@(MYBToneViolet),@"switch":@"AppLockEnabled"},
   @{@"title":@"Allow Device Passcode",@"detail":@"Lets the passcode unlock an app when Face ID does not work",@"icon":@"key.fill",@"switch":@"AppLockPasscodeFallback"},
   @{@"title":@"Locked Apps",@"detail":locked?[NSString stringWithFormat:@"%lu chosen · none by default",(unsigned long)locked]:@"None chosen",@"icon":@"checklist",@"accent":@YES,@"tone":@(MYBToneViolet),@"action":@"lockedApps"},
   @{@"title":paused?@"Resume App Lock":@"Pause App Lock for 10 Minutes",@"detail":paused?@"Paused now":@"If a locked app misbehaves, pause here or switch App Lock off",@"icon":paused?@"play.circle.fill":@"pause.circle.fill",@"tone":@(MYBToneAmber),@"action":@"pause"}],
   @"footer":@"The unlock prompt is iOS’s own; MYbloXX® never sees your face data or passcode. Locks again every time you leave the app and when the phone locks. Which launch routes are covered (Home Screen, App Library, Spotlight, notification taps, links, widgets, app switcher) is still being checked on a real phone, so this is not yet a promise for every route. It never covers Settings, calls or emergency screens."},
  @{@"title":@"PREVIEWS",@"rows":@[
   @{@"title":@"App Switcher Previews",@"detail":masked?[NSString stringWithFormat:@"%lu chosen",(unsigned long)masked]:@"None chosen",@"icon":@"rectangle.on.rectangle.slash",@"accent":@YES,@"tone":@(MYBToneBlue),@"action":@"previewApps"},
   @{@"title":@"Photos and Messages",@"detail":@"Private Album and Private Conversations are already covered when you leave them",@"icon":@"checkmark.circle",@"tone":@(MYBToneSlate)}],
   @"footer":@"A chosen app shows a MYbloXX® cover instead of its content in the app switcher. This does not stop screenshots or screen recording, and it only works while MYbloXX® and the jailbreak are running."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *key=row[@"switch"];MYBPrismCell *cell=[self cardForEntry:row table:t];
 if(key.length){MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.onTintColor=MYBAccent();toggle.on=[self flag:key];[toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];}
 return cell;
}
- (void)toggled:(MYBPrismSwitch *)toggle{
 NSMutableDictionary *config=[LockConfig() mutableCopy];config[toggle.key]=@(toggle.on);
 if(!LockSave(config))MYBComplete(self,NO,@"Couldn’t save",@"Your previous setting is kept.");
 [self silentHelper:@[@"adsfilter"] completion:^(int rc){if(rc)MYBMessage(self,@"Saved, Not Applied",[NSString stringWithFormat:@"Your choice is saved, but MYbloXX® could not update which apps load App Lock (error %d). Use Repair MYbloXX® and try again.",rc]);}];
 [self rebuildMenu];
}
- (MYBLockAppPicker *)picker{MYBLockAppPicker *p=[MYBLockAppPicker new];return p;}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];NSString *action=self.menuSections[p.section][@"rows"][p.row][@"action"];
 if([action isEqual:@"lockedApps"]){MYBLockAppPicker *pick=[self picker];pick.listKey=@"AppLockApps";pick.pageTitle=@"Locked Apps";pick.pageDetail=@"Choose the apps that stay covered until you unlock them.";pick.onDetail=@"Locked";pick.offDetail=@"Not locked";[self.navigationController pushViewController:pick animated:YES];}
 else if([action isEqual:@"previewApps"]){MYBLockAppPicker *pick=[self picker];pick.listKey=@"AppLockPreviewApps";pick.pageTitle=@"App Switcher Previews";pick.pageDetail=@"Choose the apps whose preview is hidden in the app switcher.";pick.onDetail=@"Preview hidden";pick.offDetail=@"Preview shown";[self.navigationController pushViewController:pick animated:YES];}
 else if([action isEqual:@"pause"]){
  NSMutableDictionary *config=[LockConfig() mutableCopy];id until=config[@"AppLockPausedUntil"];BOOL paused=[until isKindOfClass:NSNumber.class]&&[until doubleValue]>NSDate.date.timeIntervalSince1970;
  if(paused)[config removeObjectForKey:@"AppLockPausedUntil"];else config[@"AppLockPausedUntil"]=@(NSDate.date.timeIntervalSince1970+600);
  if(!LockSave(config))MYBComplete(self,NO,@"Couldn’t save",@"Nothing was changed.");[self rebuildMenu];
 }
}
@end

// ---- Notification Privacy ------------------------------------------------------------------------------------------------------------------
// MYbloXX® does not hook notification delivery. For each app you choose, it opens that app's own page in iOS Settings (the native controls) and tells you the exact
// setting to change, so calls, emergency alerts and system notifications are never touched. Nothing is changed for you, so what you had before stays recoverable:
// set the same option back in the same place.
@interface MYBNotifPrivacyController:MYBMenuBase @end
@implementation MYBNotifPrivacyController
- (NSString *)heroTitle{return @"Notification Privacy";}
- (NSString *)heroDetail{return @"Choose apps, then change their alerts with iOS’s own controls.";}
- (NSDictionary *)config{return [NSDictionary dictionaryWithContentsOfFile:NotifFile()]?:@{};}
- (NSArray *)listFor:(NSString *)key{NSArray *l=self.config[key];return [l isKindOfClass:NSArray.class]?l:@[];}
- (void)rebuildMenu{
 self.title=@"Notification Privacy";
 NSArray *hide=[self listFor:@"NotifHidePreviewApps"],*silence=[self listFor:@"NotifSilenceApps"];
 NSMutableDictionary *names=[NSMutableDictionary dictionary];for(NSDictionary *a in MYBSelectableApps())names[a[@"id"]]=a[@"name"];
 NSMutableArray *mine=[NSMutableArray array];
 for(NSString *b in hide)[mine addObject:@{@"title":names[b]?:b,@"detail":@"Hide Preview · tap for the steps",@"icon":@"eye.slash.fill",@"tone":@(MYBToneBlue),@"bundle":b,@"mode":@"hide",@"action":@"app"}];
 for(NSString *b in silence)[mine addObject:@{@"title":names[b]?:b,@"detail":@"Silence Alerts · tap for the steps",@"icon":@"bell.slash.fill",@"tone":@(MYBToneRose),@"bundle":b,@"mode":@"silence",@"action":@"app"}];
 if(!mine.count)[mine addObject:@{@"title":@"No apps chosen",@"detail":@"Nothing is changed until you choose an app and make the change in Settings",@"icon":@"bell",@"tone":@(MYBToneSlate)}];
 self.menuSections=@[
  @{@"title":@"CHOOSE APPS",@"rows":@[
   @{@"title":@"Hide Preview",@"detail":[NSString stringWithFormat:@"Keeps the notification, hides what it says · %lu chosen",(unsigned long)hide.count],@"icon":@"eye.slash.fill",@"accent":@YES,@"tone":@(MYBToneBlue),@"action":@"pickHide"},
   @{@"title":@"Silence Alerts",@"detail":[NSString stringWithFormat:@"Stops the alert on the surfaces you turn off · %lu chosen",(unsigned long)silence.count],@"icon":@"bell.slash.fill",@"accent":@YES,@"tone":@(MYBToneRose),@"action":@"pickSilence"}],
   @"footer":@"Calls, FaceTime, emergency alerts, Settings and system services are never listed. Choosing an app here changes nothing by itself."},
  @{@"title":@"YOUR APPS",@"rows":mine,@"footer":@"MYbloXX® does not touch notification delivery. iOS applies these settings itself, so only future notifications change: notifications already delivered stay in Notification Center until you clear them, and the red badge is a separate switch in the same Settings page. A rule for one app never affects another app or a Messages private conversation."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (void)openNativePage:(NSString *)bundle{
 NSURL *specific=[NSURL URLWithString:[@"App-prefs:NOTIFICATIONS_ID&path=" stringByAppendingString:bundle]];
 [UIApplication.sharedApplication openURL:specific options:@{} completionHandler:^(BOOL opened){
  if(opened)return;
  [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"App-prefs:NOTIFICATIONS_ID"] options:@{} completionHandler:^(BOOL second){
   if(!second)dispatch_async(dispatch_get_main_queue(),^{[self showMessage:@"Couldn’t open Settings page" detail:@"Open the Settings app, then Notifications, then the app."];});
  }];
 }];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *action=row[@"action"];
 if([action isEqual:@"pickHide"]||[action isEqual:@"pickSilence"]){
  BOOL hide=[action isEqual:@"pickHide"];MYBLockAppPicker *pick=[MYBLockAppPicker new];pick.configPath=NotifFile();pick.listKey=hide?@"NotifHidePreviewApps":@"NotifSilenceApps";
  pick.pageTitle=hide?@"Hide Preview":@"Silence Alerts";pick.pageDetail=hide?@"Choose apps whose notifications should hide their contents.":@"Choose apps whose alerts you want to turn off.";pick.onDetail=hide?@"Hide Preview":@"Silence Alerts";pick.offDetail=@"Not chosen";
  [self.navigationController pushViewController:pick animated:YES];return;
 }
 if(![action isEqual:@"app"])return;
 NSString *bundle=row[@"bundle"],*name=row[@"title"];BOOL hide=[row[@"mode"] isEqual:@"hide"];
 NSString *steps=hide?@"Tap Show Previews, then choose Never. Notifications still arrive and still make a sound; only their text is hidden.":@"Turn off the surfaces you want quiet: Lock Screen, Notification Center and Banners, plus Sounds and Badges. Turning off Allow Notifications silences the app completely.";
 __weak typeof(self) weak=self;
 MYBShieldChoice(self,name,[steps stringByAppendingString:@" Note what it was set to first. To undo, set it back in the same place."],nil,hide?@"eye.slash.fill":@"bell.slash.fill",0,@[
  @{@"title":@"Open Notification Settings",@"style":@"primary",@"handler":^{[weak openNativePage:bundle];}},
  @{@"title":@"Remove From My List",@"style":@"secondary",@"handler":^{
    NSMutableDictionary *c=[weak.config mutableCopy];NSString *key=hide?@"NotifHidePreviewApps":@"NotifSilenceApps";NSMutableArray *l=[[weak listFor:key] mutableCopy];[l removeObject:bundle];c[key]=l;[c writeToFile:NotifFile() atomically:YES];[weak rebuildMenu];}},
  @{@"title":@"Cancel",@"style":@"cancel"}]);
}
@end
