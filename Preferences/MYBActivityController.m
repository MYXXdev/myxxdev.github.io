#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBTips.h"
#import <objc/message.h>
#import "../Shared/MYBActivityLog.h"
#import "../Shared/MYBWatch.h"
#import "../Shared/MYBWebsiteRules.h"
#import "../Shared/MYBRuleStore.h"
#import "../Shared/MYBDiagSession.h"
// Activity: what MYbloXX® blocked in the last 24 hours (and, while "Watch everything" is on, what it allowed), broken down by app.
// Apps first: tap an app to see its domains, tap a domain to allow or block it. Everything stays on this iPhone and clears itself.
// Allowed domains go straight out and never pass through MYbloXX®, so they are only listed while Watch everything is on.

static NSCache<NSString *,UIImage *> *ActIcons(void){static NSCache *c;static dispatch_once_t once;dispatch_once(&once,^{c=[NSCache new];c.countLimit=120;});return c;}
// An installed app’s own icon (the same system call the app lists use); nil when there is none.
static UIImage *ActIcon(NSString *bundle){
 if(!bundle.length)return nil;UIImage *hit=[ActIcons() objectForKey:bundle];if(hit)return hit;
 Class ui=UIImage.class;SEL sel=NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");if(![ui respondsToSelector:sel])return nil;
 CGFloat scale=UIScreen.mainScreen.scale;UIImage *raw=((UIImage *(*)(id,SEL,id,int,CGFloat))objc_msgSend)(ui,sel,bundle,2,scale);if(!raw)return nil;
 UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat preferredFormat];format.scale=scale;format.opaque=NO;
 UIImage *icon=[[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(34,34) format:format] imageWithActions:^(UIGraphicsImageRendererContext *context){(void)context;[raw drawInRect:CGRectMake(0,0,34,34)];}];
 if(icon)[ActIcons() setObject:icon forKey:bundle];return icon;
}
static BOOL ActHostIn(NSString *host,NSArray *rules){for(NSString *d in rules)if([host isEqual:d]||[host hasSuffix:[@"." stringByAppendingString:d]])return YES;return NO;}
static NSString *ActAgo(double wall){
 double s=MAX(0,NSDate.date.timeIntervalSince1970-wall);if(s<60)return @"just now";if(s<3600)return [NSString stringWithFormat:@"%d min ago",(int)(s/60)];return [NSString stringWithFormat:@"%d hr ago",(int)(s/3600)];
}
static NSString *ActTimes(NSInteger n){return [NSString stringWithFormat:@"%ld %@",(long)n,n==1?@"time":@"times"];}
// @"allowed-rule" | @"blocked-rule" | @"allowed" | @"blocked": the person’s own rules win, otherwise what was seen most.
static NSString *ActStatus(NSString *host,NSInteger blocked,NSInteger allowed,NSArray *allowRules,NSArray *blockRules){
 if(ActHostIn(host,allowRules))return @"allowed-rule";if(ActHostIn(host,blockRules))return @"blocked-rule";return allowed>blocked?@"allowed":@"blocked";
}
static BOOL ActIsAllowedStatus(NSString *s){return [s hasPrefix:@"allowed"];}
static NSString *ActStatusText(NSString *s){return [s isEqual:@"allowed-rule"]?@"Allowed by you":[s isEqual:@"blocked-rule"]?@"Blocked by you":ActIsAllowedStatus(s)?@"Allowed":@"Blocked";}

@interface MYBActivityBase:MYBMenuBase<UISearchResultsUpdating>
@property(nonatomic,strong) UISearchController *search;
@property(nonatomic,strong) UISegmentedControl *segment;
@property(nonatomic,strong) NSArray<UILabel *> *tileValues;
@property(nonatomic,strong) NSArray<NSDictionary *> *hosts;
@property(nonatomic,strong) NSDictionary *appIDs;
@property(nonatomic,strong) NSArray<NSString *> *allowRules,*blockRules;
@property(nonatomic,strong) NSTimer *timer;
- (NSString *)heroSymbol;
- (MYBTone)heroTone;
- (void)tapTile:(NSInteger)index;
@end
@implementation MYBActivityBase
- (NSString *)heroEyebrow{return @"MYbloXX®";}
- (NSArray<NSString *> *)segmentTitles{return @[];}
- (NSArray<NSDictionary *> *)tileSpecs{return @[];}
- (NSArray<NSString *> *)tileValueTexts{return @[];}
- (NSString *)searchPlaceholder{return @"Search";}
- (NSInteger)tileSelection{return -1;} // the bright tile on a screen where the tiles pick the view; -1 where they only navigate
- (NSString *)query{return [[self.search.searchBar.text?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];}
// The three summary tiles. Each one is a button: Activity opens the matching list, an app page switches to it.
- (void)tileTapped:(UITapGestureRecognizer *)tap{
 if(tap.state!=UIGestureRecognizerStateEnded)return;
 MYBPressPulse(tap.view);[[UIImpactFeedbackGenerator new] impactOccurred];
 [self tapTile:tap.view.tag-1000];
}
- (void)tapTile:(NSInteger)index{(void)index;}
- (UIView *)makeHero{
 UIView *hero=nil;UISegmentedControl *segment=nil;NSArray *values=nil;
 hero=MYBStatHero(self.heroSymbol,self.heroTone,self.heroTitle,self.heroDetail,self.tileSpecs,self.segmentTitles,self.segmentTitles.count?(self.segment?self.segment.selectedSegmentIndex:0):self.tileSelection,self,@selector(tileTapped:),@selector(segmentChanged),&values,&segment);
 self.tileValues=values;self.segment=segment;return hero;
}
- (NSString *)heroSymbol{return @"waveform.path.ecg";}
- (MYBTone)heroTone{return MYBToneViolet;}
- (void)updateTiles{NSArray *texts=self.tileValueTexts;for(NSUInteger i=0;i<self.tileValues.count&&i<texts.count;i++){MYBCountUp(self.tileValues[i],[texts[i] integerValue]);UIView *tile=[self.tableView.tableHeaderView viewWithTag:1000+i];if(tile)tile.accessibilityValue=texts[i];}if(!self.segmentTitles.count)MYBTileApplySelection(self.tableView.tableHeaderView,self.tileSelection);}
- (void)segmentChanged{[self rebuildMenu];}
- (void)loadSnapshot{
 self.hosts=MYBActivityList(MYBActivityFile(),MYBShieldWall());self.appIDs=MYBActivityAppIDs(MYBActivityFile())?:@{};
 NSDictionary *applied=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/AppliedRules.plist")]?:@{};
 NSDictionary *eff=MYBEffectiveRules(applied,[NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()]);
 self.allowRules=MYBRuleArray(eff[@"allowed"])?:@[];self.blockRules=MYBRuleArray(eff[@"blocked"])?:@[];
}
- (void)viewDidLoad{
 [super viewDidLoad];
 self.search=[[UISearchController alloc] initWithSearchResultsController:nil];self.search.searchResultsUpdater=self;self.search.obscuresBackgroundDuringPresentation=NO;self.search.searchBar.placeholder=self.searchPlaceholder;
 self.search.searchBar.autocapitalizationType=UITextAutocapitalizationTypeNone;self.search.searchBar.autocorrectionType=UITextAutocorrectionTypeNo;
 self.navigationItem.searchController=self.search;self.navigationItem.hidesSearchBarWhenScrolling=NO;self.definesPresentationContext=YES;
}
- (void)updateSearchResultsForSearchController:(UISearchController *)search{(void)search;[self rebuildMenu];}
- (void)viewWillAppear:(BOOL)animated{
 [super viewWillAppear:animated];[self rebuildMenu];
 // Live: refreshes every few seconds while open, but not while typing in the search bar.
 __weak typeof(self) weak=self;[self.timer invalidate];
 self.timer=[NSTimer scheduledTimerWithTimeInterval:4 repeats:YES block:^(NSTimer *t){typeof(self) me=weak;if(!me){[t invalidate];return;}if(!me.search.isActive&&!me.presentedViewController)[me rebuildMenu];}];
}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self.timer invalidate];self.timer=nil;}
- (NSDictionary *)domainRow:(NSDictionary *)h blocked:(NSInteger)blocked allowed:(NSInteger)allowed app:(NSString *)app{
 NSString *status=ActStatus(h[@"host"],blocked,allowed,self.allowRules,self.blockRules);BOOL ok=ActIsAllowedStatus(status);
 NSMutableArray *bits=[NSMutableArray arrayWithObject:ActStatusText(status)];
 NSInteger n=ok?(allowed?:blocked):(blocked?:allowed);[bits addObject:ActTimes(n)];
 if(app.length)[bits addObject:app];
 [bits addObject:ActAgo([h[@"last"] doubleValue])];
 return @{@"title":h[@"host"],@"detail":[bits componentsJoinedByString:@" · "],@"icon":ok?@"checkmark.circle.fill":@"hand.raised.fill",@"accent":@YES,@"tone":@(ok?MYBToneGreen:MYBToneRose),@"action":@"host",@"status":status};
}
- (NSString *)topApp:(NSDictionary *)h{
 NSDictionary *apps=h[@"apps"];if(!apps.count)return @"";
 NSArray *sorted=[apps.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *x,NSString *y){NSInteger tx=[apps[x][@"b"] integerValue]+[apps[x][@"a"] integerValue],ty=[apps[y][@"b"] integerValue]+[apps[y][@"a"] integerValue];return tx==ty?[x compare:y]:(tx>ty?NSOrderedAscending:NSOrderedDescending);}];
 return sorted.count>1?[NSString stringWithFormat:@"%@ +%lu",sorted[0],(unsigned long)sorted.count-1]:sorted[0];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 UITableViewCell *cell=[super tableView:t cellForRowAtIndexPath:p];
 NSString *bundle=row[@"bundle"];
 if([cell isKindOfClass:MYBPrismCell.class]&&bundle.length){UIImage *icon=ActIcon(bundle);if(icon){((MYBPrismCell *)cell).mybAppIcon=icon;[(MYBPrismCell *)cell refreshContent];}}
 return cell;
}
// Same helper path as Custom Rules: it replaces both lists, so start from the live ones and change exactly one host.
- (void)applyRuleForHost:(NSString *)host allow:(BOOL)allow{
 NSMutableArray *blocked=[self.blockRules mutableCopy],*allowed=[self.allowRules mutableCopy];
 if(allow){[blocked removeObject:host];if(![allowed containsObject:host])[allowed addObject:host];}else{[allowed removeObject:host];if(![blocked containsObject:host])[blocked addObject:host];}
 __weak typeof(self) weak=self;
 [self runHelper:@[@"localcustom",[blocked componentsJoinedByString:@","],[allowed componentsJoinedByString:@","]] completion:^(int rc){
  typeof(self) me=weak;if(!me)return;
  if(rc)[me showMessage:allow?@"Not allowed":@"Not blocked" detail:[NSString stringWithFormat:@"Your previous rules were kept (error %d).",rc]];
  else [me showMessage:allow?@"Allowed":@"Blocked" detail:allow?[NSString stringWithFormat:@"%@ can load now. Reload the page or app; it can take a moment to apply.",host]:[NSString stringWithFormat:@"%@ is blocked from now on. It can take a moment to apply.",host]];
  [me rebuildMenu];
 }];
}
// Connection Inspector: what MYbloXX® actually saw for this domain, and why. Where the evidence is missing it says so instead of guessing.
- (void)offerRuleForHost:(NSString *)host status:(NSString *)status{
 __weak typeof(self) weak=self;
 NSDictionary *record=nil;for(NSDictionary *h in self.hosts)if([h[@"host"] isEqual:host]){record=h;break;}
 BOOL allowed=ActIsAllowedStatus(status);NSInteger b=[record[@"b"] integerValue],a=[record[@"a"] integerValue];
 NSString *why=[status isEqual:@"allowed-rule"]?@"Your Allow rule":[status isEqual:@"blocked-rule"]?@"Your Block rule":allowed?@"Not blocked. Reason unavailable: no rule or protection is recorded for allowed traffic":@"MYbloXX® protection. Reason unavailable: which list matched is not recorded";
 NSDictionary *apps=record[@"apps"];NSArray *names=[apps isKindOfClass:NSDictionary.class]?[apps.allKeys sortedArrayUsingSelector:@selector(compare:)]:@[];
 NSMutableArray *real=[NSMutableArray array];for(NSString *n in names)if(![n isEqual:@"Unknown app"])[real addObject:n];
 NSString *app=!real.count?@"App unknown":real.count==1?real[0]:[NSString stringWithFormat:@"%@ and %lu more",real[0],(unsigned long)real.count-1];
 NSMutableArray *facts=[NSMutableArray arrayWithObjects:@[@"Decision",ActStatusText(status)],@[@"Because",why],@[@"App",app],@[@"Seen",[NSString stringWithFormat:@"%@ · %@",ActTimes(allowed?(a?:b):(b?:a)),ActAgo([record[@"last"] doubleValue])]],nil];
 NSString *scope=allowed?@"Blocking adds a rule for the whole phone, every app, not only browsers. You can undo it in Custom Rules › Blocked Domains."
                         :@"Allowing adds a rule for the whole phone, every app, not only browsers. You can undo it in Custom Rules › Allowed Domains.";
 MYBShieldChoice(self,host,scope,facts,allowed?@"checkmark.shield.fill":@"hand.raised.fill",allowed?1:2,@[
  @{@"title":allowed?@"Block It":@"Allow It",@"style":@"primary",@"handler":^{[weak applyRuleForHost:host allow:!allowed];}},
  @{@"title":@"Cancel",@"style":@"cancel"}]);
}
@end

// One app’s domains.
@interface MYBActivityAppController:MYBActivityBase
@property(nonatomic,copy) NSString *appName;
@property(nonatomic,assign) NSInteger filter; // 0 all domains, 1 blocked, 2 allowed: chosen with the tiles
@end
@implementation MYBActivityAppController
- (NSString *)heroTitle{return self.appName?:@"App";}
- (NSString *)heroDetail{return @"The websites this app asked for. Tap one to allow or block it on the whole phone.";}
- (NSString *)heroSymbol{return @"app.badge.fill";}
- (MYBTone)heroTone{return MYBToneIndigo;}
- (NSString *)searchPlaceholder{return @"Find a domain";}
- (NSArray<NSString *> *)segmentTitles{return @[];} // the tiles pick the view; no second control repeats them
- (NSInteger)tileSelection{return self.filter==1?0:(self.filter==2?1:2);}
- (NSArray<NSDictionary *> *)tileSpecs{return @[@{@"label":@"Blocked",@"tone":@(MYBToneRose),@"symbol":@"xmark.circle.fill"},@{@"label":@"Allowed",@"tone":@(MYBToneGreen),@"symbol":@"checkmark.circle.fill"},@{@"label":@"Domains",@"tone":@(MYBToneViolet),@"symbol":@"globe"}];}
- (NSArray<NSString *> *)tileValueTexts{
 NSInteger b=0,a=0,sites=0;for(NSDictionary *h in self.hosts){NSDictionary *c=h[@"apps"][self.appName];if(!c)continue;b+=[c[@"b"] integerValue];a+=[c[@"a"] integerValue];sites++;}
 return @[[NSString stringWithFormat:@"%ld",(long)b],[NSString stringWithFormat:@"%ld",(long)a],[NSString stringWithFormat:@"%ld",(long)sites]];
}
// Tapping a tile shows that part of the list.
- (void)tapTile:(NSInteger)index{self.filter=index==0?1:(index==1?2:0);[self rebuildMenu];}
- (NSDictionary *)mybNavExtras{return @{@"filter":@(self.filter)};}
- (void)mybApplyNavExtras:(NSDictionary *)extras{NSInteger f=[extras[@"filter"] integerValue];if(f>=0&&f<=2&&f!=self.filter){self.filter=f;[self rebuildMenu];}}
- (void)rebuildMenu{
 self.title=self.appName?:@"App";[self loadSnapshot];[self updateTiles];
 NSString *q=self.query;NSInteger mode=self.filter;NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *h in self.hosts){
  NSDictionary *c=h[@"apps"][self.appName];if(!c)continue;if(q.length&&![h[@"host"] containsString:q])continue;
  NSInteger b=[c[@"b"] integerValue],a=[c[@"a"] integerValue];if((mode==1&&!b)||(mode==2&&!a))continue;
  [rows addObject:[self domainRow:h blocked:b allowed:a app:nil]];
 }
 if(!rows.count)rows=[@[@{@"title":q.length?@"No match":(mode==2?@"Nothing allowed yet":@"All quiet"),@"detail":q.length?@"No domain here matches that.":(mode==2?@"Allowed domains appear here while Watch everything is on.":@"Nothing from this app in the last 24 hours.")}] mutableCopy];
 self.menuSections=@[@{@"title":mode==1?@"BLOCKED DOMAINS":(mode==2?@"ALLOWED DOMAINS":@"DOMAINS"),@"rows":rows,@"footer":@"Allowing or blocking applies to the whole phone, not only this app."}];
 [self.tableView reloadData];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(self.busy)return;NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if([row[@"action"] isEqual:@"host"])[self offerRuleForHost:row[@"title"] status:row[@"status"]];
}
@end

// Every blocked, or every allowed, domain from all apps in one list.
@interface MYBActivityDomainsController:MYBActivityBase
@property(nonatomic,assign) BOOL allowed; // NO: the blocked list. YES: the allowed list
@end
@implementation MYBActivityDomainsController
- (NSString *)heroTitle{return self.allowed?@"Allowed Domains":@"Blocked Domains";}
- (NSString *)heroDetail{return self.allowed?@"Everything your apps were allowed to reach. Tap a domain to block it.":@"Everything MYbloXX® blocked in the last 24 hours. Tap a domain to allow it.";}
- (NSString *)heroSymbol{return self.allowed?@"checkmark.circle.fill":@"hand.raised.fill";}
- (MYBTone)heroTone{return self.allowed?MYBToneGreen:MYBToneRose;}
- (NSString *)searchPlaceholder{return @"Find a domain or app";}
- (void)rebuildMenu{
 self.title=[self heroTitle];[self loadSnapshot];
 NSString *q=self.query;NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *h in self.hosts){
  NSInteger b=[h[@"b"] integerValue],a=[h[@"a"] integerValue];if(self.allowed?!a:!b)continue;
  BOOL match=!q.length||[h[@"host"] containsString:q];if(!match)for(NSString *app in h[@"apps"])if([app.lowercaseString containsString:q]){match=YES;break;}if(!match)continue;
  [rows addObject:[self domainRow:h blocked:self.allowed?0:b allowed:self.allowed?a:0 app:[self topApp:h]]];
 }
 NSMutableArray *sections=[NSMutableArray array];
 if(self.allowed&&!MYBWatchActive())[sections addObject:@{@"title":@"",@"rows":@[@{@"title":@"Watch everything",@"detail":@"Start 10 minutes of watching to fill this list",@"icon":@"eye.fill",@"accent":@YES,@"tone":@(MYBToneTeal),@"action":@"watch"}],@"footer":@"Allowed domains go straight out, so MYbloXX® only sees them while Watch everything is on."}];
 if(!rows.count)rows=[@[@{@"title":q.length?@"No match":@"All quiet",@"detail":q.length?@"Nothing in the last 24 hours matches that.":(self.allowed?(MYBWatchActive()?@"Watch everything is on and no allowed domains have been seen yet.":@"Allowed traffic is not being observed right now, so this list is empty. Turn on Watch everything to see it."):@"Nothing has been blocked yet.")}] mutableCopy];
 [sections addObject:@{@"title":self.allowed?@"ALLOWED · LAST 24 HOURS":@"BLOCKED · LAST 24 HOURS",@"rows":rows,@"footer":rows.count>1||[rows.firstObject[@"action"] length]?@"Tap a domain to change it.":@""}];
 self.menuSections=sections;[self.tableView reloadData];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(self.busy)return;NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if([row[@"action"] isEqual:@"host"])[self offerRuleForHost:row[@"title"] status:row[@"status"]];
 if([row[@"action"] isEqual:@"watch"]){
  __weak typeof(self) weak=self;
  [self runHelper:@[@"watch",@"on",@"600"] completion:^(int rc){typeof(self) me=weak;if(!me)return;
   if(rc==69)[me showMessage:@"Turn on protection first" detail:@"Watch everything works with MYbloXX® protection. Turn Protection on, then try again."];
   else if(rc)[me showMessage:@"Couldn\u2019t start Watch everything" detail:[NSString stringWithFormat:@"Nothing was changed (error %d).",rc]];
   [me rebuildMenu];}];
 }
}
@end

// Connection session: an opt-in, short, local window. It records only when it started and stopped; the export is built from the website activity MYbloXX® already
// keeps, limited to that window, and shows domains only. Nothing here touches the PAC apply path, network services or radio settings.
static NSString *DiagFile(void){return MYBMobileFile(@"/var/mobile/Library/MYbloXX/DiagSession.plist");}
@interface MYBDiagPreviewController:UIViewController @property(nonatomic,copy) NSString *text; @end
@implementation MYBDiagPreviewController
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"Export Preview";self.view.backgroundColor=UIColor.systemBackgroundColor;
 UITextView *view=[[UITextView alloc] initWithFrame:self.view.bounds];view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
 view.editable=NO;view.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];view.text=self.text;view.textContainerInset=UIEdgeInsetsMake(16,12,16,12);[self.view addSubview:view];
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share:)];
}
- (void)share:(UIBarButtonItem *)item{
 UIActivityViewController *sheet=[[UIActivityViewController alloc] initWithActivityItems:@[self.text?:@""] applicationActivities:nil];
 sheet.popoverPresentationController.barButtonItem=item;[self presentViewController:sheet animated:YES completion:nil];
}
@end
@interface MYBDiagSessionController:MYBActivityBase @end
@implementation MYBDiagSessionController
- (NSString *)heroTitle{return @"Connection Session";}
- (NSString *)heroDetail{return @"A short, local recording window you start yourself. Nothing is kept unless you start one.";}
- (NSString *)heroSymbol{return @"stethoscope";}
- (BOOL)includes:(NSString *)key{return [NSUserDefaults.standardUserDefaults boolForKey:[@"MYBDiagInclude" stringByAppendingString:key]];}
- (void)rebuildMenu{
 self.title=@"Connection Session";[self loadSnapshot];
 NSDictionary *state=MYBDiagState(DiagFile(),NSDate.date.timeIntervalSince1970);BOOL active=[state[@"active"] boolValue],has=[state[@"start"] doubleValue]>0;
 double left=MAX(0,MYB_DIAG_MAX_SECONDS-(NSDate.date.timeIntervalSince1970-[state[@"start"] doubleValue]));
 NSString *line=active?[NSString stringWithFormat:@"Recording · stops by itself in %d min",(int)ceil(left/60)]:has?@"Stopped · results kept for 24 hours":@"Not recording";
 NSMutableArray *rows=[NSMutableArray arrayWithObject:@{@"title":active?@"Stop Session":@"Start Session",@"detail":line,@"icon":active?@"stop.circle.fill":@"record.circle",@"accent":@YES,@"tone":@(active?MYBToneRose:MYBToneGreen),@"action":@"toggleSession"}];
 NSMutableArray *sections=[NSMutableArray arrayWithObject:@{@"title":@"SESSION",@"rows":rows,@"footer":MYBWatchActive()?@"Allowed domains are included while Watch everything is on.":@"Blocked domains are recorded as usual. To include allowed domains, also turn on Watch everything in Activity. A session lasts 30 minutes at most."}];
 if(has){
  [sections addObject:@{@"title":@"WHAT TO SHARE",@"rows":@[
   @{@"title":@"App names",@"detail":@"Which app asked, when it is known",@"icon":@"app.fill",@"switchKey":@"Apps"},
   @{@"title":@"Counts",@"detail":@"How many times each domain was seen",@"icon":@"number",@"switchKey":@"Counts"}],@"footer":@"Domain names and decisions are always in the export. Full links, query strings, passwords and page content are never recorded."}];
  [sections addObject:@{@"title":@"",@"rows":@[
   @{@"title":@"Preview Export",@"detail":@"See exactly what would be shared",@"icon":@"doc.text.magnifyingglass",@"accent":@YES,@"tone":@(MYBToneBlue),@"action":@"preview"},
   @{@"title":@"Clear Session",@"icon":@"trash",@"destructive":@YES,@"action":@"clearSession"}]}];
 }
 self.menuSections=sections;[self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];MYBPrismCell *cell=[self cardForEntry:row table:t];
 NSString *key=row[@"switchKey"];
 if(key.length){MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.onTintColor=MYBAccent();toggle.on=[self includes:key];[toggle addTarget:self action:@selector(includeChanged:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];}
 return cell;
}
- (void)includeChanged:(MYBPrismSwitch *)toggle{[NSUserDefaults.standardUserDefaults setBool:toggle.on forKey:[@"MYBDiagInclude" stringByAppendingString:toggle.key]];}
- (NSString *)exportText{
 NSDictionary *state=MYBDiagState(DiagFile(),NSDate.date.timeIntervalSince1970);
 return MYBDiagExport(self.hosts,state,[self includes:@"Apps"],[self includes:@"Counts"],self.allowRules,self.blockRules);
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];NSString *action=self.menuSections[p.section][@"rows"][p.row][@"action"];
 double now=NSDate.date.timeIntervalSince1970;
 if([action isEqual:@"toggleSession"]){
  BOOL active=[MYBDiagState(DiagFile(),now)[@"active"] boolValue];
  if(!(active?MYBDiagStop(DiagFile(),now):MYBDiagStart(DiagFile(),now)))MYBComplete(self,NO,@"Couldn’t save",@"Nothing was changed.");
  [self rebuildMenu];
 }else if([action isEqual:@"preview"]){
  MYBDiagPreviewController *preview=[MYBDiagPreviewController new];preview.text=[self exportText];[self.navigationController pushViewController:preview animated:YES];
 }else if([action isEqual:@"clearSession"]){
  __weak typeof(self) weak=self;MYBConfirmDestructive(self,@"Clear this session?",@"The recording window is removed. Your normal Activity list is not changed.",@"Clear",^{MYBDiagClear(DiagFile());[weak rebuildMenu];});
 }
}
@end

// The Activity screen.
@interface MYBActivityController:MYBActivityBase
@property(nonatomic,assign) NSInteger appsSection;
@end
@implementation MYBActivityController
- (NSString *)heroTitle{return @"Activity";}
- (NSString *)heroDetail{return @"Website activity: what MYbloXX® blocked, which app asked, and rules you can change. A rule applies to the whole phone, not just one app.";}
- (NSString *)heroSymbol{return @"waveform.path.ecg";}
- (MYBTone)heroTone{return MYBToneViolet;}
- (NSString *)searchPlaceholder{return @"Find an app or domain";}
- (NSArray<NSString *> *)segmentTitles{return @[@"Apps",@"Domains"];}
- (NSArray<NSDictionary *> *)tileSpecs{return @[@{@"label":@"Blocked",@"tone":@(MYBToneRose),@"symbol":@"xmark.circle.fill"},@{@"label":@"Allowed",@"tone":@(MYBToneGreen),@"symbol":@"checkmark.circle.fill"},@{@"label":@"Apps",@"tone":@(MYBToneViolet),@"symbol":@"square.grid.2x2.fill"}];}
- (NSArray<NSString *> *)tileValueTexts{
 NSInteger b=0,a=0;for(NSDictionary *h in self.hosts){b+=[h[@"b"] integerValue];a+=[h[@"a"] integerValue];}
 return @[[NSString stringWithFormat:@"%ld",(long)b],[NSString stringWithFormat:@"%ld",(long)a],[NSString stringWithFormat:@"%lu",(unsigned long)MYBActivityApps(self.hosts).count]];
}
// Blocked and Allowed open the full list of each; Apps jumps down to the apps.
- (void)tapTile:(NSInteger)index{
 if(index==2){
  if(self.segment.selectedSegmentIndex!=0){self.segment.selectedSegmentIndex=0;[self rebuildMenu];}
  NSInteger section=self.appsSection;
  if(section<(NSInteger)self.menuSections.count&&[self.menuSections[section][@"rows"] count])[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section] atScrollPosition:UITableViewScrollPositionTop animated:YES];
  return;
 }
 MYBActivityDomainsController *page=[MYBActivityDomainsController new];page.allowed=index==1;[self.navigationController pushViewController:page animated:YES];
}
- (NSString *)watchDetail{
 if(MYBWatchActive()){NSInteger m=(MYBWatchSecondsLeft()+59)/60;return [NSString stringWithFormat:@"Watching · %ld min left",(long)m];}
 return @"See allowed domains too, for 10 minutes";
}
- (void)rebuildMenu{
 self.title=@"Activity";[self loadSnapshot];[self updateTiles];
 NSString *q=self.query;NSMutableArray *sections=[NSMutableArray array];
 [sections addObject:@{@"title":@"",@"rows":@[@{@"title":@"Watch everything",@"detail":[self watchDetail]}],
  @"footer":MYBWatchActive()?@"Right now MYbloXX® also counts the allowed domains your apps open. It stops by itself when the time is up, and nothing else about your browsing changes.":@"Normally MYbloXX® only sees what it blocks. Turn this on for 10 minutes to also see what is allowed; it switches itself off."}];
 NSMutableArray *rows=[NSMutableArray array];NSString *header=nil,*footer=@"";
 if(self.segment.selectedSegmentIndex==0){
  header=@"APPS · LAST 24 HOURS";
  for(NSDictionary *app in MYBActivityApps(self.hosts)){
   NSString *name=app[@"name"];
   if(q.length&&![name.lowercaseString containsString:q]){BOOL siteMatch=NO;for(NSDictionary *h in self.hosts)if(h[@"apps"][name]&&[h[@"host"] containsString:q]){siteMatch=YES;break;}if(!siteMatch)continue;}
   NSInteger b=[app[@"b"] integerValue],a=[app[@"a"] integerValue],sites=[app[@"sites"] integerValue];
   NSMutableArray *bits=[NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%ld blocked",(long)b]];if(a)[bits addObject:[NSString stringWithFormat:@"%ld allowed",(long)a]];[bits addObject:[NSString stringWithFormat:@"%ld %@",(long)sites,sites==1?@"domain":@"domains"]];
   NSString *bundle=self.appIDs[name];BOOL system=[name isEqual:@"iOS system"],unknown=[name isEqual:@"Unknown app"];
   [rows addObject:@{@"title":name,@"detail":[bits componentsJoinedByString:@" · "],@"icon":unknown?@"questionmark.circle.fill":(system?@"gearshape.fill":@"app.fill"),@"accent":@YES,@"tone":@(MYBToneSlate),@"bundle":bundle?:@"",@"action":@"app"}];
  }
  footer=rows.count?@"Tap an app to see its domains. “Safari & web pages” covers Safari and web pages shown inside apps. Some requests can’t be matched to an app.":@"";
 }else{
  header=@"DOMAINS · LAST 24 HOURS";
  for(NSDictionary *h in self.hosts){
   BOOL match=!q.length||[h[@"host"] containsString:q];if(!match)for(NSString *a in h[@"apps"])if([a.lowercaseString containsString:q]){match=YES;break;}if(!match)continue;
   [rows addObject:[self domainRow:h blocked:[h[@"b"] integerValue] allowed:[h[@"a"] integerValue] app:[self topApp:h]]];
  }
  footer=rows.count?@"Tap a domain to allow or block it.":@"";
 }
 if(!rows.count)rows=[@[@{@"title":q.length?@"No match":@"All quiet",@"detail":q.length?@"Nothing in the last 24 hours matches that.":@"Nothing has been blocked yet. Apps and domains show up here as MYbloXX® blocks them."}] mutableCopy];
 self.appsSection=sections.count;
 [sections addObject:@{@"title":header,@"rows":rows,@"footer":footer}];
 if(!q.length)[sections addObject:@{@"title":@"",@"rows":@[@{@"title":@"Connection Session",@"detail":@"Record a short window and preview what you would share",@"icon":@"stethoscope",@"accent":@YES,@"tone":@(MYBToneBlue),@"action":@"session"}]}];
 if(self.hosts.count&&!q.length)[sections addObject:@{@"title":@"",@"rows":@[@{@"title":@"Clear List Now",@"icon":@"trash",@"destructive":@YES,@"action":@"clear"}],
  @"footer":@"Only domain names and app names are kept, never pages, searches or anything you type. They stay on this iPhone and clear themselves every 24 hours."}];
 self.menuSections=sections;[self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{
 [super viewWillAppear:animated];
 // A finished watch leaves a harmless marker behind; remove it so the next start is clean.
 if(MYBWatchStoredMillis()>0&&!MYBWatchActive())[self silentHelper:@[@"watch",@"off"] completion:^(__unused int rc){}];
}
- (BOOL)isWatchRow:(NSIndexPath *)p{return [self.menuSections[p.section][@"rows"][p.row][@"title"] isEqual:@"Watch everything"];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 if([self isWatchRow:p]){
  NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
  MYBPrismCell *cell=[self cardForEntry:row table:t];cell.mybIconView.image=[UIImage systemImageNamed:@"eye.fill"];cell.tone=MYBToneTeal;
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=@"watch";toggle.on=MYBWatchActive();toggle.onTintColor=MYBAccent();
  [toggle addTarget:self action:@selector(watchChanged:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];return cell;
 }
 return [super tableView:t cellForRowAtIndexPath:p];
}
- (void)watchChanged:(MYBPrismSwitch *)toggle{
 __weak typeof(self) weak=self;
 [self runHelper:toggle.on?@[@"watch",@"on",@"600"]:@[@"watch",@"off"] completion:^(int rc){
  typeof(self) me=weak;if(!me)return;
  if(rc==69)[me showMessage:@"Turn on protection first" detail:@"Watch everything works with MYbloXX® protection. Turn Protection on, then try again."];
  else if(rc)[me showMessage:@"Couldn’t change Watch everything" detail:[NSString stringWithFormat:@"Nothing was changed (error %d).",rc]];
  [me rebuildMenu];
 }];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(self.busy||[self isWatchRow:p])return;
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *action=row[@"action"];
 if([action isEqual:@"session"]){[self.navigationController pushViewController:[MYBDiagSessionController new] animated:YES];return;}
 if([action isEqual:@"clear"]){__weak typeof(self) weak=self;MYBConfirmDestructive(self,@"Clear the list?",@"The list is cleared now. It keeps filling as domains are blocked.",@"Clear",^{MYBActivityClear(MYBActivityFile());[weak rebuildMenu];});return;}
 if([action isEqual:@"app"]){MYBActivityAppController *page=[MYBActivityAppController new];page.appName=row[@"title"];[self.navigationController pushViewController:page animated:YES];return;}
 if([action isEqual:@"host"])[self offerRuleForHost:row[@"title"] status:row[@"status"]];
}
@end
