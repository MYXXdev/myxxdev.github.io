#import "../Preferences/MYBMenuBase.h"
#import "../Preferences/MYBDesign.h"
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <roothide.h>
#define MYB_SHEET_TEST 1
#import "../Shared/MYBShieldSheet.h"
@interface MYBDashboardController:MYBMenuBase @end
@interface MYBDiagnosticsController:MYBMenuBase @end
#import "../Shared/MYBInAppAds.h"
@interface MYBAppControlController:MYBMenuBase @end
@interface PreviewDashboard:MYBDashboardController @end
@implementation PreviewDashboard
- (BOOL)enabled{return YES;}
- (BOOL)configurationLoaded{return YES;}
- (void)checkLocalHealth{[self setValue:@1 forKey:@"localHealth"];}
- (NSDictionary *)statusModel{return @{@"kind":@"applied-verified",@"title":@"Enabled",@"detail":@"The system is using MYbloXX's current rules (verified).",@"tone":@"positive",@"active":@YES,@"refresh":@NO};}
@end
@interface PreviewDashboardExpanded:PreviewDashboard @end
@implementation PreviewDashboardExpanded
- (void)viewDidLoad{[self setValue:@YES forKey:@"modesExpanded"];[super viewDidLoad];}
@end
@interface MYBInAppAdsController:MYBMenuBase @end
@interface PreviewInAppAds:MYBInAppAdsController @end
@implementation PreviewInAppAds
- (void)loadApps{
 NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *e in MYBAdsCatalogue()){if([e[@"discoveryOnly"] boolValue])continue;NSMutableDictionary *r=[e mutableCopy];r[@"installedBundle"]=e[@"bundles"][0];r[@"version"]=@"1.0.0";r[@"label"]=e[@"name"];[rows addObject:r];}
 [self setValue:rows forKey:@"apps"];[self setValue:@NO forKey:@"loading"];[self.tableView reloadData];
}
@end
@interface PreviewStatus:MYBDiagnosticsController @end
@implementation PreviewStatus
- (BOOL)systemEnabled{return YES;}
@end
@interface PreviewApps:MYBAppControlController @end
@implementation PreviewApps
- (void)viewDidLoad{[super viewDidLoad];NSArray *apps=@[@{@"id":@"com.apple.mobilesafari",@"name":@"Safari"},@{@"id":@"com.apple.Maps",@"name":@"Maps"},@{@"id":@"com.apple.mobilenotes",@"name":@"Notes"},@{@"id":@"game.example",@"name":@"Candy Crush Saga"},@{@"id":@"com.google.ios.youtube",@"name":@"YouTube"}];[self setValue:apps forKey:@"apps"];[self setValue:apps forKey:@"filtered"];[self.tableView reloadData];}
@end
static NSUInteger textLabelCount(UIView *view){
 if(view.hidden||view.alpha<.01)return 0;
 NSUInteger count=[view isKindOfClass:UILabel.class]&&[(UILabel *)view text].length?1:0;
 for(UIView *child in view.subviews)count+=textLabelCount(child);
 return count;
}
static void fixture(NSString *path,NSDictionary *value){NSString *file=jbroot(path);[NSFileManager.defaultManager createDirectoryAtPath:file.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];[value writeToFile:file atomically:YES];}
@interface PreviewApp:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) WKWebView *web;
@property(nonatomic,strong) AVPlayer *player;
@end
@implementation PreviewApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options{
 (void)app;(void)options;
 fixture(@"/var/mobile/Library/MYbloXX/State.plist",@{@"enabled":@YES,@"mode":@"blockAdSense"});
 fixture(@"/var/mobile/Library/MYbloXX/AppliedRules.plist",@{@"blocked":@[@"ads.example.com",@"metrics.example.com"],@"allowed":@[@"example.org"]});
 fixture(@"/var/mobile/Library/MYbloXX/BackupStatus.plist",@{@"lastSuccess":[NSDate date],@"lastResult":@"Your backup is current.",@"initialized":@YES});
 fixture(@"/var/mobile/Library/MYbloXX/Updates.plist",@{@"automatic":@YES,@"lastSuccess":[NSDate date],@"revision":@"preview"});
 fixture(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.supervision.plist",@{@"available":@YES,@"supervised":@NO,@"owned":@NO});
 fixture(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist",@{@"enabled-com.apple.mobilesafari":@YES,@"enabled-game.example":@YES,@"enabled-com.google.ios.youtube":@YES});
 fixture(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist",@{@"Enabled":@YES,@"BlockPopups":@YES,@"ShowBlocked":@YES,@"Blocked":@[],@"Allowed":@[],@"URLs":@[]});
 NSString *page=NSProcessInfo.processInfo.arguments.lastObject;
 NSDictionary *classes=@{@"restraint":@"PreviewDashboard",@"restraint-solid":@"PreviewDashboard",@"restraint-still":@"PreviewDashboard",@"modes":@"PreviewDashboardExpanded",@"modeinfo":@"MYBModeInfoController",@"troubleshooting":@"MYBTroubleshootingController",@"dashboard":@"PreviewDashboard",@"rules":@"MYBRulesController",@"shield":@"MYBPopupControlController",@"apps":@"PreviewApps",@"inappads":@"PreviewInAppAds",@"updates":@"MYBUpdatesController",@"status":@"PreviewStatus",@"backup":@"MYBBackupController",@"supervision":@"MYBLegacyController",@"proxy":@"MYBProxyOverrideController",@"redirects":@"MYBRedirectController",@"notice":@"MYBUpdatesController",@"form":@"MYBRulesController",@"strictness":@"MYBPopupStrictnessController",@"dns":@"MYBDNSController",@"dashboard-scrolled":@"PreviewDashboard",@"sheet-centre":@"MYBUpdatesController",@"inappads-status":@"MYBInAppAdsStatusController",@"legacy-prompt":@"MYBLegacyController"};
 if([page isEqual:@"restraint-solid"])MYBSetAccessibilityOverride(1,-1);if([page isEqual:@"restraint-still"])MYBSetAccessibilityOverride(-1,1);
 MYBMenuBase *controller=[NSClassFromString(classes[page]?:@"PreviewDashboard") new];
 UIViewController *parent=[UIViewController new];parent.title=@"Settings";UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:parent];[nav pushViewController:controller animated:NO];
 self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.window.rootViewController=nav;[self.window makeKeyAndVisible];
 if([page isEqual:@"media"])[self mediaProbe:controller];
 [self afterActive:0 run:^{
  [self.window layoutIfNeeded];NSMutableArray *errors=[NSMutableArray array];
  [self checkRestraint:controller page:page errors:errors];
  for(UITableViewCell *row in controller.tableView.visibleCells){if(![row isKindOfClass:MYBPrismCell.class])continue;MYBPrismCell *cell=(id)row;
   [cell layoutIfNeeded];UIView *icon=cell.mybIconView;CGRect iconFrame=[icon convertRect:icon.bounds toView:icon.superview];if(!icon.superview.hidden&&fabs(CGRectGetMidY(iconFrame)-CGRectGetMidY(icon.superview.bounds))>1)[errors addObject:[NSString stringWithFormat:@"icon center %@ image=%@ box=%@",cell.mybTitleLabel.text,NSStringFromCGRect(iconFrame),NSStringFromCGRect(icon.superview.bounds)]];
   CGRect title=[cell.mybTitleLabel convertRect:cell.mybTitleLabel.bounds toView:cell.contentView];
   if(cell.mybAccessoryView){CGRect accessory=[cell.mybAccessoryView convertRect:cell.mybAccessoryView.bounds toView:cell.contentView];if(CGRectGetMaxX(title)>CGRectGetMinX(accessory)-7)[errors addObject:@"text overlaps accessory"];}
   CGSize text=[cell.mybTitleLabel sizeThatFits:CGSizeMake(cell.mybTitleLabel.bounds.size.width,CGFLOAT_MAX)];if(text.height>cell.mybTitleLabel.bounds.size.height+1)[errors addObject:@"clipped row title"];
  }
  for(NSInteger section=0;section<[controller.tableView numberOfSections];section++){
   for(UIView *sectionView in @[[controller.tableView headerViewForSection:section]?:[UIView new],[controller.tableView footerViewForSection:section]?:[UIView new]]){
    if(([sectionView isKindOfClass:MYBSectionHeaderView.class]||[sectionView isKindOfClass:MYBSectionFooterView.class])&&textLabelCount(sectionView)!=1)[errors addObject:@"duplicate or missing section text"];
   }
  }
  if([page isEqual:@"dashboard"]||[page isEqual:@"restraint"]){
   // The Blocking Mode chevron must sit where the navigation chevrons sit and be the same size.
   UIImageView *modeChevron=nil,*navChevron=nil;MYBPrismCell *modeCell=nil,*navCell=nil;
   for(UITableViewCell *row in controller.tableView.visibleCells){if(![row isKindOfClass:MYBPrismCell.class])continue;MYBPrismCell *cell=(id)row;NSString *t=cell.mybTitleLabel.text;
    if([t isEqual:@"Blocking Mode"]&&[cell.mybAccessoryView isKindOfClass:UIImageView.class]){modeChevron=(id)cell.mybAccessoryView;modeCell=cell;}
    if([t isEqual:@"Custom Rules"]){navChevron=[cell valueForKey:@"chevron"];navCell=cell;}}
   if(modeChevron&&navChevron){
    [modeCell layoutIfNeeded];[navCell layoutIfNeeded];
    CGRect a=[modeChevron convertRect:modeChevron.bounds toView:modeCell],b=[navChevron convertRect:navChevron.bounds toView:navCell];
    if(fabs((modeCell.bounds.size.width-CGRectGetMaxX(a))-(navCell.bounds.size.width-CGRectGetMaxX(b)))>1)[errors addObject:@"Blocking Mode chevron is not at the navigation arrows' trailing position"];
    // Both slots are 18 pt wide and use the same 12 pt semibold symbol configuration; the two glyphs are the same shape rotated, so their image frames differ in height only by intrinsic size.
    if(fabs(a.size.width-b.size.width)>1)[errors addObject:@"Blocking Mode chevron slot is not as wide as the navigation arrows' slot"];
    if(fabs(CGRectGetMidY(a)-CGRectGetMidY(b))>2.5)[errors addObject:[NSString stringWithFormat:@"Blocking Mode chevron is not vertically centred like the navigation arrows (%.1f vs %.1f)",CGRectGetMidY(a),CGRectGetMidY(b)]];
   }else [errors addObject:@"Blocking Mode or Custom Rules row not found for the chevron check"];
  }
  if([page isEqual:@"dashboard-scrolled"]){[controller.tableView setContentOffset:CGPointMake(0,320) animated:NO];if([controller.tableView.delegate respondsToSelector:@selector(scrollViewDidScroll:)])[controller.tableView.delegate scrollViewDidScroll:controller.tableView];} // visual inspection only; this harness does not host the dashboard in its real container
  void(^writeResult)(NSArray *)=^(NSArray *errs){
   NSString *result=errs.count?[NSString stringWithFormat:@"FAIL: %@",errs]:@"PASS: real controllers, centered icons, aligned accessories and unclipped labels";
  NSString *directory=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];[NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];[result writeToFile:[directory stringByAppendingPathComponent:@"layout-result.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  };
  if([page hasPrefix:@"shieldsheet"]){
   NSArray *errs=nil;[self presentShieldSheet:nav solid:[page hasSuffix:@"solid"] done:writeResult];(void)errs;
  }else if([page isEqual:@"sheet-centre"]){
   // One shared sheet layout: icon, title and message centred, also when the text is long and wraps.
   MYBMessage(controller,@"Checking for Updates With A Deliberately Long Title That Must Wrap",@"The message is long enough to wrap onto several lines so that a layout that only looks centred for short text would show up here. Each line stays centred under the icon.");
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
    NSMutableArray *errs=[NSMutableArray array];UIViewController *sheet=nav.presentedViewController;[sheet.view layoutIfNeeded];
    if(!sheet)[errs addObject:@"no sheet presented"];
    NSMutableArray *labels=[NSMutableArray array],*images=[NSMutableArray array];collect(sheet.view,UILabel.class,labels);collect(sheet.view,UIImageView.class,images);
    CGFloat mid=CGRectGetMidX(sheet.view.bounds);NSUInteger checked=0;
    for(UILabel *l in labels){if(l.hidden||!l.text.length||l.text.length<12)continue;checked++;CGRect f=[l.superview convertRect:l.frame toView:sheet.view];
     if(l.textAlignment!=NSTextAlignmentCenter)[errs addObject:[NSString stringWithFormat:@"label not centre-aligned: %@",l.text]];
     if(fabs(CGRectGetMidX(f)-mid)>1.5)[errs addObject:[NSString stringWithFormat:@"label not centred (%.1f vs %.1f): %@",CGRectGetMidX(f),mid,l.text]];}
    for(UIImageView *i in images){if(i.hidden||!i.image||i.bounds.size.width>120||i.bounds.size.width<8)continue;checked++;CGRect f=[i.superview convertRect:i.frame toView:sheet.view];if(fabs(CGRectGetMidX(f)-mid)>1.5)[errs addObject:[NSString stringWithFormat:@"icon not centred (%.1f vs %.1f)",CGRectGetMidX(f),mid]];}
    if(checked<3)[errs addObject:@"expected an icon, a title and a message"];
    writeResult(errs);
   });
  }else writeResult(errors);
  if([page isEqual:@"notice"])MYBMessage(controller,@"MYbloXX® is up to date",@"You’re using the latest protection rules.");
  if([page isEqual:@"legacy-prompt"])MYBConfirmWithButton(controller,@"Supervision Needed First",@"iOS only offers legacy profiles on a supervised device. MYbloXX® can switch on its supervision setting for you. Settings will close to refresh iOS, and you then continue with this profile.",@"Enable Supervision & Continue",^{});
  if([page isEqual:@"form"])MYBInput(controller,@"Add a Rule",@"Enter a domain without a protocol or path.",@[@{@"placeholder":@"example.com"}],@"Save Rule",^(__unused NSArray *values){});
 }];return YES;
}
static void collect(UIView *v,Class c,NSMutableArray *out){if([v isKindOfClass:c])[out addObject:v];for(UIView *s in v.subviews)collect(s,c,out);}
static void walkLayers(CALayer *l,void(^visit)(CALayer *)){visit(l);for(CALayer *c in l.sublayers)walkLayers(c,visit);}
// Restraint checks, run on the real controllers: what the screen DRAWS, not whether an effect exists.
//  * no system separator lines, no glass surfaces in the table, one solid surface per row group
//  * nothing animates continuously; all cards share one left/right margin; rows are at least 44 pt tall
//  * the dashboard stays short and keeps modes behind their own screen
- (void)checkRestraint:(MYBMenuBase *)controller page:(NSString *)page errors:(NSMutableArray *)errors{
 UITableView *table=controller.tableView;
 if(table.separatorStyle!=UITableViewCellSeparatorStyleNone)[errors addObject:@"system separators are on (full-width lines)"];
 if(![table.backgroundView isKindOfClass:MYBBackdropView.class])[errors addObject:@"backdrop is not the fixed backdrop"];
 NSMutableArray *glass=[NSMutableArray array];collect(table,MYBGlassView.class,glass);if(glass.count)[errors addObject:@"glass surface inside the table (glass is for sheets only)"];
 __block NSUInteger repeating=0;walkLayers(controller.view.layer,^(CALayer *l){for(NSString *k in l.animationKeys){CAAnimation *a=[l animationForKey:k];if(a.repeatCount>1||a.repeatDuration>0)repeating++;}});
 if(repeating)[errors addObject:[NSString stringWithFormat:@"%lu continuous animation(s) running",(unsigned long)repeating]];
 for(UITableViewCell *cell in table.visibleCells)if(fabs(cell.alpha-1)>.01||!CGAffineTransformIsIdentity(cell.transform))[errors addObject:@"a row was left faded or displaced after the reveal"];
 CGFloat width=table.bounds.size.width;NSUInteger prism=0;NSMutableArray *checks=[NSMutableArray array];
 for(UITableViewCell *cell in table.visibleCells){
  if(![cell isKindOfClass:MYBPrismCell.class])continue;prism++;MYBPrismCell *c=(id)cell;UIView *panel=[c mybPanelView];[cell layoutIfNeeded];
  CGRect f=[panel convertRect:panel.bounds toView:table];
  if(fabs(CGRectGetMinX(f)-MYBMargin)>.5||fabs(CGRectGetMaxX(f)-(width-MYBMargin))>.5)[checks addObject:[NSString stringWithFormat:@"card edges %.1f..%.1f, expected %.1f..%.1f",CGRectGetMinX(f),CGRectGetMaxX(f),MYBMargin,width-MYBMargin]];
  if(cell.bounds.size.height<44)[checks addObject:[NSString stringWithFormat:@"row %.0fpt tall (under 44)",cell.bounds.size.height]];
  CGFloat a=0;[panel.backgroundColor getRed:NULL green:NULL blue:NULL alpha:&a];
  if([page isEqual:@"restraint-solid"]){if(a<.99)[checks addObject:@"row surface is translucent under Reduce Transparency"];}
  else if(a<.5||a>.95)[checks addObject:[NSString stringWithFormat:@"row surface alpha %.2f: expected restrained translucency (.5-.95)",a]];
  if(panel.layer.borderWidth>0)[checks addObject:@"row panel has a border"];
 }
 if(checks.count)[errors addObject:[checks.firstObject stringByAppendingFormat:@" (+%lu more)",(unsigned long)checks.count-1]];
 if(!prism)[errors addObject:@"no rows were drawn"];
 UIView *header=table.tableHeaderView;
 if([page hasPrefix:@"restraint"]){
  if(header.bounds.size.height>110)[errors addObject:[NSString stringWithFormat:@"dashboard header is %.0fpt tall (limit 110)",header.bounds.size.height]];
  NSUInteger rows=0;for(NSInteger s=0;s<table.numberOfSections;s++)rows+=[table numberOfRowsInSection:s];
  if(rows>14)[errors addObject:[NSString stringWithFormat:@"dashboard has %lu rows (limit 14)",(unsigned long)rows]];
  NSMutableString *all=[NSMutableString string];for(NSInteger s=0;s<controller.menuSections.count;s++)for(NSDictionary *r in controller.menuSections[s][@"rows"])[all appendFormat:@"|%@",r[@"title"]];
  for(NSString *mode in @[@"allowY!",@"blockAdSense",@"noApple",@"noSocials",@"noXXX",@"blockApple",@"blockSocials",@"blockXXX"])if([all containsString:mode])[errors addObject:[@"mode listed on the dashboard: " stringByAppendingString:mode]];
  if(![all containsString:@"|Blocking Mode"]||![all containsString:@"|Custom Rules"])[errors addObject:@"Blocking Mode and Custom Rules must both be dashboard rows"];
  if([page isEqual:@"restraint-solid"]){MYBBackdropView *b=(id)table.backgroundView;if([b glowVisible])[errors addObject:@"backdrop glow visible under Reduce Transparency"];}
  if([page isEqual:@"restraint"]){if(!MYBMotionAllowed())[errors addObject:@"motion should be allowed on a visible, foreground screen"];}
  if([page isEqual:@"restraint-still"]){if(MYBMotionAllowed())[errors addObject:@"motion allowed under Reduce Motion"];}
  MYBMotionScreenDisappeared();if(MYBMotionAllowed())[errors addObject:@"motion still allowed after the screen left"];MYBMotionScreenAppeared();
 }
 if([page isEqual:@"modes"]){
  // Inline Blocking Mode, expanded: Protection, Blocking Mode, six modes, Exact Differences, then Custom Rules.
  NSUInteger modeRows=0,checked=0;NSMutableString *all=[NSMutableString string];NSArray *rows=controller.menuSections.firstObject[@"rows"];
  for(NSDictionary *r in rows){if(r[@"mode"])modeRows++;[all appendFormat:@"|%@",r[@"title"]];}
  for(UITableViewCell *cell in table.visibleCells)if([cell isKindOfClass:MYBPrismCell.class]&&((MYBPrismCell *)cell).mybAccessoryType==UITableViewCellAccessoryCheckmark)checked++;
  if(modeRows!=6)[errors addObject:[NSString stringWithFormat:@"%lu mode rows (expected 6)",(unsigned long)modeRows]];
  if(checked!=1)[errors addObject:[NSString stringWithFormat:@"%lu selected modes (expected exactly 1)",(unsigned long)checked]];
  if(![[rows.lastObject objectForKey:@"title"] isEqual:@"Custom Rules"])[errors addObject:@"Custom Rules must follow the expanded modes"];
  if(![all hasPrefix:@"|Protection|Blocking Mode|"])[errors addObject:@"order must start Protection, Blocking Mode"];
  if(![all containsString:@"allowY!"]||![all containsString:@"blockAdSense"]||![all containsString:@"noApple"]||![all containsString:@"noSocials"]||![all containsString:@"noXXX"])[errors addObject:@"mode names/casing changed"];
 }
 if(header&&header.bounds.size.height>260)[errors addObject:@"oversized header"];
}
// The branded Shield sheet exactly as the SpringBoard / Safari prompts build it: size, tap targets, single-fire handlers,
// opaque material under Reduce Transparency, scrolling at the largest text size, and no second presentation on top.
- (void)presentShieldSheet:(UIViewController *)host solid:(BOOL)solid done:(void(^)(NSArray *))done{
 if(solid)setenv("MYB_SHEET_SOLID","1",1);
 __block int ran=0,resultRan=0;
 MYBShieldSheet *sheet=[MYBShieldSheet new];sheet.heading=@"Popup blocked";sheet.message=@"example.com tried to open a new window.\nThe page asked for a window without a tap.";
 sheet.facts=@[@[@"Page",@"example.com"],@[@"Wants to open",@"ads.example.net"]];
 MYBShieldAction *once=[MYBShieldAction title:@"Allow once" detail:nil style:MYBShieldActionPrimary handler:^{ran++;}];once.result=^NSDictionary *{resultRan++;return @{@"ok":@YES,@"title":@"Popup permission saved",@"message":@"Allowed once."};};
 sheet.actions=@[once,[MYBShieldAction title:@"Allow for 15 minutes" detail:nil style:MYBShieldActionSecondary handler:^{ran+=100;}],[MYBShieldAction title:@"Block This Time" detail:nil style:MYBShieldActionCancel handler:nil]];
 BOOL shown=[MYBShieldSheet present:sheet from:host completion:nil];
 NSMutableArray *errors=[NSMutableArray array];if(!shown)[errors addObject:@"sheet was not presented"];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  [sheet.view layoutIfNeeded];
  if(host.presentedViewController!=sheet)[errors addObject:@"sheet is not on screen"];
  if(fabs(sheet.card.alpha-1)>.01||!CGAffineTransformIsIdentity(sheet.card.transform))[errors addObject:@"card left faded or displaced"];
  if(sheet.buttons.count!=3)[errors addObject:@"wrong button count"];
  for(UIButton *b in sheet.buttons){CGRect r=[b convertRect:b.bounds toView:sheet.view];if(b.bounds.size.height<44)[errors addObject:[NSString stringWithFormat:@"button %@ is %.0fpt tall",b.accessibilityLabel,b.bounds.size.height]];if(!CGRectContainsRect(sheet.view.safeAreaLayoutGuide.layoutFrame,r)&&CGRectGetMaxY(r)>sheet.view.bounds.size.height)[errors addObject:@"button outside the screen"];}
  CGRect card=sheet.card.frame;if(card.size.width>520.5)[errors addObject:@"card wider than 520pt"];if(CGRectGetMinX(card)<0||CGRectGetMaxX(card)>sheet.view.bounds.size.width)[errors addObject:@"card off screen horizontally"];
  CGFloat a=0;[sheet.card.backgroundColor getRed:NULL green:NULL blue:NULL alpha:&a];
  if(solid&&a<.99)[errors addObject:@"card translucent under Reduce Transparency"];if(!solid&&a>.5)[errors addObject:@"card is opaque although transparency is allowed"];
  if(!sheet.card.accessibilityViewIsModal)[errors addObject:@"sheet is not modal for VoiceOver"];
  // No stacking: a second sheet while one is up must be refused.
  if([MYBShieldSheet present:[MYBShieldSheet new] from:host completion:nil])[errors addObject:@"a second sheet stacked on the first"];
  // Single fire: two taps on the same button run the handler once and show the result once.
  UIButton *first=sheet.buttons.firstObject;[first sendActionsForControlEvents:UIControlEventTouchUpInside];[first sendActionsForControlEvents:UIControlEventTouchUpInside];
  if(ran!=1)[errors addObject:[NSString stringWithFormat:@"handler ran %d (expected 1, no other action)",ran]];if(resultRan!=1)[errors addObject:@"result shown more than once"];
  if(sheet.buttons.count!=0)[errors addObject:@"a successful result dismisses itself and offers no button"];
  done(errors);
 });
}
// The checks are about a visible, foreground app. A fixed 2 s was a timing assumption that a slow host breaks (the app was not yet
// active); the harness now waits until it is, up to 60 s, and the checks themselves are unchanged.
- (void)afterActive:(int)n run:(void(^)(void))work{
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((n?0.5:2.0)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive&&n<120){[self afterActive:n+1 run:work];return;}
  work();
 });
}
- (void)mediaProbe:(UIViewController *)owner{
 NSURL *file=[NSBundle.mainBundle URLForResource:@"video-probe" withExtension:@"mp4"];self.player=[AVPlayer playerWithURL:file];
 WKWebViewConfiguration *config=[WKWebViewConfiguration new];config.mediaTypesRequiringUserActionForPlayback=WKAudiovisualMediaTypeNone;
 NSString *script=[NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"Acceleration" withExtension:@"js"] encoding:NSUTF8StringEncoding error:NULL];script=[script stringByReplacingOccurrencesOfString:@"__MYB_INITIAL_ENABLED__" withString:@"true"];
 [config.userContentController addUserScript:[[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO]];
 self.web=[[WKWebView alloc] initWithFrame:CGRectMake(20,160,320,180) configuration:config];[owner.view addSubview:self.web];
 NSString *video=[[NSData dataWithContentsOfURL:file] base64EncodedStringWithOptions:0];[self.web loadHTMLString:[NSString stringWithFormat:@"<video muted autoplay src='data:video/mp4;base64,%@'></video>",video] baseURL:nil];
 [self probeMedia:0];
}
// The page is given time to load the video (readyState>0) and run the injected script (a fixed 3 s was a timing assumption that a slow host breaks):
// the probe waits until both exist, up to 60 s, and then asserts exactly what it always asserted. If the page still throws, the
// app's own exception message is recorded so a failure says why.
- (void)probeMedia:(int)attempt{
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(attempt?0.5:3)*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  [self.web evaluateJavaScript:@"(window.__MYBAppControl&&document.querySelector('video')&&document.querySelector('video').readyState>0)?'ready':'waiting'" completionHandler:^(id state,NSError *e0){
   if(![state isEqual:@"ready"]&&attempt<120){[self probeMedia:attempt+1];return;}
   self.player.rate=100;float nativeRate=self.player.rate;BOOL fast=self.player.currentItem.canPlayFastForward;
   [self.web evaluateJavaScript:@"JSON.stringify({requested:window.__MYBAppControl.requestedRate,webRate:document.querySelector('video').playbackRate,ready:document.querySelector('video').readyState,networkState:document.querySelector('video').networkState,mediaError:(document.querySelector('video').error?document.querySelector('video').error.code:0),canPlayH264:document.createElement('video').canPlayType('video/mp4; codecs="avc1.42E01E"')})" completionHandler:^(id result,NSError *error){
    NSData *data=[result isKindOfClass:NSString.class]?[result dataUsingEncoding:NSUTF8StringEncoding]:nil;NSMutableDictionary *report=data?[[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] mutableCopy]:[NSMutableDictionary dictionary];report[@"nativeRate"]=@(nativeRate);report[@"nativeCanFastForward"]=@(fast);report[@"note"]=@"Player acceptance probe, not a guarantee of effective ad playback speed on every device.";report[@"waitedHalfSeconds"]=@(attempt);
    if(error){report[@"error"]=error.localizedDescription;report[@"exception"]=error.userInfo[@"WKJavaScriptExceptionMessage"]?:@"(none)";report[@"pageState"]=state?:@"(no answer)";if(e0)report[@"stateError"]=e0.localizedDescription;}
    NSData *bytes=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL];[bytes writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/media-result.json"] atomically:YES];
   }];
  }];
 });
}

@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(PreviewApp.class));}}
