#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBVersion.h"
#import "../Shared/MYBInAppAds.h"
#import "../Shared/MYBAdsReport.h"
#import <objc/message.h>
#import <notify.h>
// In-App Ad Blocking. One switch per supported app that is installed. On by default; a switch changes only that app’s
// module, and the app reads it when it starts, so the app must be reopened. This list is deliberately plain (icon, name,
// switch). Nothing here claims an app is protected; observations live in Status > In-App Ad Blocking. A material failure
// (the module loaded but found none of its hook points in the installed version) is the only thing shown on a row.
@interface MYBInAppAdsController : MYBMenuBase
@property(nonatomic,strong) NSMutableDictionary *prefs;
@property(nonatomic,strong) NSArray<NSDictionary *> *apps; // catalogue entries plus installed version and icon
@property(nonatomic,strong) NSDictionary *status; // module -> record from MYbloXX’s local service; nil when it could not be reached
@property(nonatomic,assign) BOOL loading;
@property(nonatomic,assign) NSUInteger generation;
@end
static NSString *MYBAdsInstalledVersion(NSString *bundle,NSString **name){
 Class cls=NSClassFromString(@"LSApplicationProxy");SEL sel=NSSelectorFromString(@"applicationProxyForIdentifier:");
 id proxy=[cls respondsToSelector:sel]?((id(*)(id,SEL,id))objc_msgSend)(cls,sel,bundle):nil;if(!proxy)return nil;
 NSString *version=[proxy respondsToSelector:NSSelectorFromString(@"shortVersionString")]?[proxy valueForKey:@"shortVersionString"]:nil;
 if(![version isKindOfClass:NSString.class]||!version.length)return nil; // not installed
 NSString *label=[proxy respondsToSelector:NSSelectorFromString(@"localizedName")]?[proxy valueForKey:@"localizedName"]:nil;
 if(name&&[label isKindOfClass:NSString.class]&&label.length)*name=label;return version;
}
static UIImage *MYBAdsIcon(NSString *bundle){
 Class ui=UIImage.class;SEL sel=NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");if(![ui respondsToSelector:sel])return nil;
 CGFloat scale=UIScreen.mainScreen.scale;UIImage *raw=((UIImage *(*)(id,SEL,id,int,CGFloat))objc_msgSend)(ui,sel,bundle,2,scale);if(!raw)return nil;
 UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat preferredFormat];format.scale=scale;format.opaque=NO;
 return [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(34,34) format:format] imageWithActions:^(UIGraphicsImageRendererContext *context){(void)context;[raw drawInRect:CGRectMake(0,0,34,34)];}];
}
// The placeholder names every supported app from the catalogue, so it can never fall behind the list.
static NSString *MYBAdsSupportedNames(void){
 NSMutableArray *names=[NSMutableArray array];for(NSDictionary *entry in MYBAdsCatalogue())if(![entry[@"discoveryOnly"] boolValue])[names addObject:entry[@"name"]];
 if(names.count<2)return @"Install a supported app, then reopen this screen";
 NSString *last=names.lastObject;[names removeLastObject];
 return [NSString stringWithFormat:@"Install %@ or %@, then reopen this screen",[names componentsJoinedByString:@", "],last];
}
@implementation MYBInAppAdsController
- (NSString *)file{return MYBMobileFile(MYB_ADS_PREFS_PATH);}
- (NSString *)heroEyebrow{return nil;}
- (NSString *)heroTitle{return @"In-App Ad Blocking";}
- (NSString *)heroDetail{return @"Remove ads in supported apps.";}
- (void)rebuildMenu{self.title=@"In-App Ad Blocking";self.prefs=[[NSDictionary dictionaryWithContentsOfFile:self.file] mutableCopy]?:[NSMutableDictionary dictionary];[self.tableView reloadData];}
- (void)viewDidLoad{[super viewDidLoad];self.apps=@[];[self loadApps];}
// Installed apps and icons are looked up off the main thread; a stale result never replaces a newer one.
- (void)loadApps{
 self.loading=YES;NSUInteger generation=++self.generation;[self.tableView reloadData];__weak typeof(self) weak=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSMutableArray *found=[NSMutableArray array];
  for(NSDictionary *entry in MYBAdsCatalogue())for(NSString *bundle in entry[@"bundles"]){
   if([entry[@"discoveryOnly"] boolValue])break; // discovery targets have no everyday switch
   NSString *name=nil;NSString *version=MYBAdsInstalledVersion(bundle,&name);if(!version)continue;
   NSMutableDictionary *row=[entry mutableCopy];row[@"installedBundle"]=bundle;row[@"version"]=version;row[@"label"]=name?:entry[@"name"];
   UIImage *icon=MYBAdsIcon(bundle);if(icon)row[@"icon"]=icon;[found addObject:row];break;
  }
  dispatch_async(dispatch_get_main_queue(),^{typeof(self) strong=weak;if(!strong||strong.generation!=generation)return;strong.apps=found;strong.loading=NO;[strong.tableView reloadData];});
 });
}
// What the module itself reported, read from MYbloXX’s local service off the main thread. "Loaded" and "hooks found" are
// observations that the module started and located its hook points; only "filtering" means an ad was actually handled.
- (void)refreshStatus{
 __weak typeof(self) weak=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  NSData *data=MYBLoopbackGET(MYB_BRIDGE_PORT,@"/mybloxx-status");id json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
  NSDictionary *ads=[json isKindOfClass:NSDictionary.class]&&[json[@"inAppAds"] isKindOfClass:NSDictionary.class]?json[@"inAppAds"]:nil;
  dispatch_async(dispatch_get_main_queue(),^{typeof(self) strong=weak;if(!strong)return;strong.status=ads;[strong.tableView reloadData];});
 });
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self refreshStatus];}
- (BOOL)showsPlaceholder{return self.loading||!self.apps.count;}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table{return 2;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{if(section==1)return 1;return self.showsPlaceholder?1:(NSInteger)self.apps.count;}
- (NSString *)sectionHeaderTitle:(NSInteger)section{return section==1?@"OTHER APPS":@"SUPPORTED APPS YOU HAVE INSTALLED";}
- (NSString *)sectionFooterTitle:(NSInteger)section{
 if(section==1)return @"For apps not listed above. Advanced.";
 return @"Close and reopen an app after changing its switch. Only ads are removed; playback, content and accounts are left alone. Technical details are in Status.";
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path{
 MYBPrismCell *cell=[MYBPrismCell cellForTable:table];
 if(path.section==1){
  cell.mybTitleLabel.text=@"Ad Network Blocking";cell.mybDetailLabel.text=@"Choose other apps";cell.mybIconView.image=[UIImage systemImageNamed:@"slider.horizontal.3"];cell.tone=MYBToneSlate;
  cell.mybAccessoryType=UITableViewCellAccessoryDisclosureIndicator;[cell refreshContent];return cell;
 }
 if(self.showsPlaceholder){
  cell.mybTitleLabel.text=self.loading?@"Looking for supported apps...":@"No supported apps found";
  cell.mybDetailLabel.text=self.loading?@"Reading your installed apps":MYBAdsSupportedNames();
  cell.mybIconView.image=[UIImage systemImageNamed:self.loading?@"hourglass":@"magnifyingglass"];cell.tone=MYBToneSlate;cell.selectionStyle=UITableViewCellSelectionStyleNone;
 }else{
  NSDictionary *app=self.apps[path.row];NSString *module=app[@"module"];BOOL on=MYBAdsModuleEnabled(self.prefs,module);
  cell.mybTitleLabel.text=app[@"label"];cell.mybTitleLabel.numberOfLines=2;
  // Material failure only: enabled, the app ran the module, and none of its hook points exist in this app version.
  BOOL failed=on&&[self.status[module][@"state"] isEqual:@"no-hooks-found"];
  cell.mybDetailLabel.numberOfLines=0;cell.mybDetailLabel.text=failed?@"Doesn\u2019t work with this version of the app yet":nil;
  cell.mybIconView.image=[UIImage systemImageNamed:on?@"nosign":@"app"];cell.tone=on?MYBToneGreen:MYBToneSlate;
  if(app[@"icon"])cell.mybAppIcon=app[@"icon"];
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=module;toggle.on=on;toggle.onTintColor=MYBAccent();[toggle addTarget:self action:@selector(changeModule:) forControlEvents:UIControlEventValueChanged];
  toggle.accessibilityLabel=[NSString stringWithFormat:@"Block ads in %@",app[@"label"]];cell.mybAccessoryView=toggle;
 }
 [cell refreshContent];return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path{
 [table deselectRowAtIndexPath:path animated:YES];
 if(path.section==1){Class page=NSClassFromString(@"MYBAdSDKController");UIViewController *next=page?[page new]:nil;if(next&&self.navigationController)[self.navigationController pushViewController:next animated:YES];}
}
- (void)changeModule:(MYBPrismSwitch *)toggle{
 NSString *module=toggle.key;if(!module.length||!MYBAdsEntry(module))return;
 NSMutableDictionary *current=[[NSDictionary dictionaryWithContentsOfFile:self.file] mutableCopy]?:[NSMutableDictionary dictionary];
 current[MYBAdsKey(module)]=@(toggle.on);
 if(![current writeToFile:self.file atomically:YES]){[toggle setOn:!toggle.on animated:YES];MYBMessage(self,@"Couldn’t Save",@"Your previous choice is unchanged.");return;}
 self.prefs=current;
 NSUInteger row=[self.apps indexOfObjectPassingTest:^BOOL(NSDictionary *a,NSUInteger i,BOOL *stop){(void)i;(void)stop;return [a[@"module"] isEqual:module];}];
 if(row!=NSNotFound){MYBPrismCell *cell=(MYBPrismCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)row inSection:0]];if([cell isKindOfClass:MYBPrismCell.class]){cell.tone=toggle.on?MYBToneGreen:MYBToneSlate;cell.mybIconView.image=[UIImage systemImageNamed:toggle.on?@"nosign":@"app"];[cell refreshContent];}}
}
@end

// ---- Status > In-App Ad Blocking: what each module reported ----------------------------------------------------------
// Observations only. Nothing here is a Protected/Working badge: "hooks found" means the module started and located its
// hook points; "ad items filtered" counts items it classified as ads. Neither proves every ad is blocked.
@interface MYBInAppAdsStatusController : MYBMenuBase
@property(nonatomic,strong) NSDictionary *status;
@property(nonatomic,assign) BOOL unreachable;
@property(nonatomic,strong) NSDictionary *prefs;
@end
@implementation MYBInAppAdsStatusController
static NSString *MYBAdsTime(NSNumber *seconds){
 if(!seconds)return nil;static NSDateFormatter *f;static dispatch_once_t once;dispatch_once(&once,^{f=[NSDateFormatter new];f.dateStyle=NSDateFormatterMediumStyle;f.timeStyle=NSDateFormatterMediumStyle;});
 return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:seconds.doubleValue]];
}
static NSString *MYBAdsStateText(NSDictionary *r,BOOL on){
 NSString *state=r[@"state"]?:@"not-observed";
 if([state isEqual:@"not-observed"])return on?@"Not seen running yet":@"Off";
 if([state isEqual:@"loaded"])return @"Loaded";
 if([state isEqual:@"no-hooks-found"])return @"No hook points found";
 if([state isEqual:@"hooks-found"])return @"Hooks found, no ad seen yet";
 return @"Filtering";
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self refresh];}
- (void)refresh{
 __weak typeof(self) weak=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  NSData *data=MYBLoopbackGET(MYB_BRIDGE_PORT,@"/mybloxx-status");id json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
  NSDictionary *ads=[json isKindOfClass:NSDictionary.class]&&[json[@"inAppAds"] isKindOfClass:NSDictionary.class]?json[@"inAppAds"]:nil;
  dispatch_async(dispatch_get_main_queue(),^{typeof(self) strong=weak;if(!strong)return;strong.status=ads;strong.unreachable=ads==nil;[strong rebuildMenu];});
 });
}
- (void)rebuildMenu{
 self.title=@"In-App Ad Blocking";
 self.prefs=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(MYB_ADS_PREFS_PATH)]?:@{};
 NSMutableArray *sections=[NSMutableArray array];
 if(self.unreachable)[sections addObject:@{@"title":@"STATUS SERVICE",@"rows":@[@{@"title":@"Not reachable",@"value":@"Retry",@"icon":@"exclamationmark.triangle",@"action":@"refresh"}]}];
 for(NSDictionary *entry in MYBAdsCatalogue()){
  if([entry[@"discoveryOnly"] boolValue])continue;
  NSString *module=entry[@"module"];NSDictionary *r=self.status[module];BOOL on=MYBAdsModuleEnabled(self.prefs,module);
  NSMutableArray *rows=[NSMutableArray array];
  [rows addObject:@{@"title":@"Switch",@"value":on?@"On":@"Off",@"icon":@"power"}];
  [rows addObject:@{@"title":@"Status",@"value":MYBAdsStateText(r,on),@"icon":@"waveform.path.ecg"}];
  if(r[@"loadedAt"]){
   [rows addObject:@{@"title":@"App version",@"value":r[@"appVersion"]?:@"Unknown",@"icon":@"app"}];
   [rows addObject:@{@"title":@"Module",@"value":[r[@"componentVersion"] isEqual:@MYB_COMPONENT_VERSION]?@"Current release":@"Older release, restart the app",@"icon":@"shippingbox"}];
   [rows addObject:@{@"title":@"Loaded as",@"value":r[@"arch"]?:@"Unknown",@"icon":@"cpu"}];
   if(r[@"hooksAttempted"])[rows addObject:@{@"title":@"Hook points",@"value":[NSString stringWithFormat:@"%@ of %@ found%@",r[@"hooksFound"],r[@"hooksAttempted"],@""],@"icon":@"link"}];
   NSDictionary *cats=r[@"categories"];NSMutableArray *bits=[NSMutableArray array];for(NSString *k in [cats.allKeys sortedArrayUsingSelector:@selector(compare:)])[bits addObject:[NSString stringWithFormat:@"%@ %@",k,cats[k]]];
   [rows addObject:@{@"title":@"Ad items filtered",@"value":[NSString stringWithFormat:@"%@%@",r[@"decisions"]?:@0,bits.count?[@" (" stringByAppendingFormat:@"%@)",[bits componentsJoinedByString:@", "]]:@""],@"icon":@"nosign"}];
   if([r[@"passedThrough"] longLongValue]>0)[rows addObject:@{@"title":@"Passed through (too large)",@"value":[r[@"passedThrough"] stringValue],@"icon":@"arrow.right"}];
   NSString *loaded=MYBAdsTime(r[@"loadedAt"]),*hooks=MYBAdsTime(r[@"hooksAt"]),*last=MYBAdsTime(r[@"lastDecisionAt"]);
   if(loaded)[rows addObject:@{@"title":@"App opened",@"value":loaded,@"icon":@"clock"}];
   if(hooks)[rows addObject:@{@"title":@"Hooks checked",@"value":hooks,@"icon":@"clock"}];
   if(last)[rows addObject:@{@"title":@"Last ad item filtered",@"value":last,@"icon":@"clock"}];
   if([r[@"state"] isEqual:@"no-hooks-found"])[rows addObject:@{@"title":@"Problem",@"value":@"None of this module\u2019s hook points exist in this app version",@"icon":@"exclamationmark.triangle"}];
  }
  [sections addObject:@{@"title":[entry[@"name"] uppercaseString],@"rows":rows}];
 }
 if(sections.count){NSMutableDictionary *last=[sections.lastObject mutableCopy];last[@"footer"]=@"These are observations from the last time each app was opened since MYbloXX\u00ae\u2019s service started. Hooks found means the module started and located its hook points. A count means it filtered items it classified as ads; it does not prove every ad is blocked.";sections[sections.count-1]=last;}
 self.menuSections=sections;[self.tableView reloadData];
}
@end
