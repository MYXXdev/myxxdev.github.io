#import "MYBRulesController.h"
#import "MYBTileBase.h"
#import "MYBTips.h"
#import "../Shared/MYBShield.h"
#import "../Shared/MYBWebsiteRules.h"
#import <notify.h>
// Pop-Up Control, in this order: Block Browser Pop-Ups (switch and Strict/Standard), Website Rules in Your Browser (Blocked / Allowed / URLs
// above one inline list, same storage and editor as before), and Pop-Up Permissions (saved permissions and recent attempts, kept compact).
// A browser website rule decides whether a page or address loads. A popup permission decides whether a site may open another window.
// Browser rules always apply in supported browsers: there is no switch for them, and no switch for blocked-page notices.
static NSString *MYBPopupShieldFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist");}
static NSArray *MYBPopupGrants(BOOL blocked){
 NSMutableArray *out=[NSMutableArray array];
 for(NSDictionary *g in MYBShieldLiveGrants(MYBShieldPermissionsFile()))if([g[@"kind"] isEqual:@"popup"]&&([g[@"mode"] isEqual:@"block"]==blocked))[out addObject:g];
 return out;
}

// ---- the three lists ---------------------------------------------------------------------------------------------------------------
@interface MYBPopupListController : MYBTileListBase
@property(nonatomic,copy) NSString *listKind; // allowed | blocked | recent
@property(nonatomic,strong) NSArray<NSDictionary *> *items;
@end
@implementation MYBPopupListController
- (NSString *)heroTitle{return [self.listKind isEqual:@"allowed"]?@"Allowed Popup Sites":[self.listKind isEqual:@"blocked"]?@"Always Blocked Popup Sites":@"Recent Popups";}
- (NSString *)heroDetail{
 return [self.listKind isEqual:@"allowed"]?@"Websites you let open new windows, and when each permission ends."
  :[self.listKind isEqual:@"blocked"]?@"Websites you chose Always Block for. Only saved rules are listed here."
  :@"New windows MYbloXX® stopped recently. Kept on this iPhone only.";
}
- (NSString *)heroSymbol{return [self.listKind isEqual:@"allowed"]?@"checkmark.circle.fill":[self.listKind isEqual:@"blocked"]?@"nosign":@"clock.arrow.circlepath";}
- (MYBTone)heroTone{return [self.listKind isEqual:@"allowed"]?MYBToneGreen:[self.listKind isEqual:@"blocked"]?MYBToneRose:MYBToneIndigo;}
- (void)rebuildMenu{
 self.title=self.heroTitle;
 self.items=[self.listKind isEqual:@"recent"]?MYBShieldActivityOfTypes(MYBShieldActivityFile(),@[@"popup"]):MYBPopupGrants([self.listKind isEqual:@"blocked"]);
 [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{return 1;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return self.items.count?self.items.count+1:1;}
- (NSString *)sectionHeaderTitle:(NSInteger)s{return [self.listKind isEqual:@"allowed"]?@"ALLOWED":[self.listKind isEqual:@"blocked"]?@"ALWAYS BLOCKED":@"RECENT";}
- (NSString *)sectionFooterTitle:(NSInteger)s{
 if([self.listKind isEqual:@"allowed"])return @"Each permission covers exactly one website and only lets it open new windows. It does not change which websites those windows may open. Temporary permissions end by themselves. Tap a row to revoke it and be asked again.";
 if([self.listKind isEqual:@"blocked"])return @"A saved Always Block stops that website from opening windows without asking. A one-time Block This Time is never saved here. Tap a row to remove the rule.";
 return @"Clearing this list does not remove any saved permission or Always Block rule. The latest 40 events are kept, with the website and the reason, never full addresses.";
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 BOOL recent=[self.listKind isEqual:@"recent"];
 if(!self.items.count){
  return MYBTileInfoCell(t,recent?@"No recent popups":[self.listKind isEqual:@"blocked"]?@"No Always Block rules":@"No allowed popup sites",recent?@"Blocked popups appear here.":[self.listKind isEqual:@"blocked"]?@"Choose Always Block on a popup question to add one.":@"Popups ask each time.",@"checkmark.shield",MYBToneSlate,NO);
 }
 if(p.row==(NSInteger)self.items.count){
  return MYBTileInfoCell(t,recent?@"Clear Recent Popups":[self.listKind isEqual:@"blocked"]?@"Remove All Always Block Rules":@"Revoke All Allowed Sites",recent?@"Removes this history only. Saved permissions and rules stay.":@"Removes these saved rules. Popup history stays.",@"trash",MYBToneRose,YES);
 }
 NSDictionary *i=self.items[p.row];
 if(recent){
  NSString *reason=i[@"reason"];BOOL once=[reason isEqual:@"popup-block-once"],rule=[reason isEqual:@"popup-saved-block"];NSInteger count=[i[@"count"] integerValue];
  NSString *state=once?@"Blocked this time":rule?@"Blocked by Always Block":@"Blocked";
  return MYBTileInfoCell(t,[i[@"source"] length]?i[@"source"]:@"Unknown website",[NSString stringWithFormat:@"%@ · %@%@%@ · %@",state,MYBShieldReasonText(reason),[i[@"dest"] length]?[@" → " stringByAppendingString:i[@"dest"]]:@"",count>1?[NSString stringWithFormat:@" · %ld×",(long)count]:@"",MYBTileAgo([i[@"last"] doubleValue])],@"macwindow",MYBToneRose,NO);
 }
 BOOL block=[self.listKind isEqual:@"blocked"];
 return MYBTileInfoCell(t,i[@"source"],block?@"This website · Always blocked from opening windows · tap to remove":[NSString stringWithFormat:@"This website · %@ · tap to revoke",MYBTileDuration(i[@"mode"],[i[@"wallExpiry"] doubleValue])],block?@"nosign":@"macwindow",block?MYBToneRose:[i[@"mode"] isEqual:@"always"]?MYBToneGreen:MYBToneAmber,YES);
}
- (void)revokeIDs:(NSArray<NSString *> *)ids{for(NSString *ident in ids)MYBShieldRevoke(MYBShieldPermissionsFile(),ident);[self rebuildMenu];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(!self.items.count)return;
 BOOL recent=[self.listKind isEqual:@"recent"],block=[self.listKind isEqual:@"blocked"];
 if(p.row==(NSInteger)self.items.count){
  if(recent){MYBConfirmDestructive(self,@"Clear recent popups?",@"This removes the history list only. Saved permissions and Always Block rules stay as they are.",@"Clear History",^{MYBShieldClearActivityTypes(MYBShieldActivityFile(),@[@"popup"]);[self rebuildMenu];});return;}
  NSMutableArray *ids=[NSMutableArray array];for(NSDictionary *g in self.items)if(g[@"id"])[ids addObject:g[@"id"]];
  MYBConfirmDestructive(self,block?@"Remove all Always Block rules?":@"Revoke all allowed sites?",block?@"These websites will be asked about again. Popup history is not affected.":@"These websites will be asked about again. Popup history is not affected.",block?@"Remove All":@"Revoke All",^{[self revokeIDs:ids];});return;
 }
 if(recent)return;
 NSDictionary *g=self.items[p.row];NSString *ident=g[@"id"];if(!ident)return;
 MYBConfirmDestructive(self,block?@"Remove this rule?":@"Revoke permission?",block?@"This website will be asked about again next time.":@"It stops working immediately. You will be asked again next time.",block?@"Remove":@"Revoke",^{[self revokeIDs:@[ident]];});
}
@end

// The three pop-up lists open from Pop-Up Permissions. Each one is the same list controller with its kind fixed.
@interface MYBPopupAllowedController : MYBPopupListController @end
@implementation MYBPopupAllowedController
- (instancetype)init{self=[super init];if(self)self.listKind=@"allowed";return self;}
@end
@interface MYBPopupBlockedController : MYBPopupListController @end
@implementation MYBPopupBlockedController
- (instancetype)init{self=[super init];if(self)self.listKind=@"blocked";return self;}
@end
@interface MYBPopupRecentController : MYBPopupListController @end
@implementation MYBPopupRecentController
- (instancetype)init{self=[super init];if(self)self.listKind=@"recent";return self;}
@end

// ---- Pop-Up Control ----------------------------------------------------------------------------------------------------------------
static NSString *MYBTipsFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.tips.plist");}
@interface MYBPopupControlController : MYBRulesController
@property(nonatomic,assign) BOOL strictnessExpanded; // in memory only: the list starts collapsed, like Blocking Mode
@end
@implementation MYBPopupControlController
- (BOOL)isShieldRules{return YES;}
- (BOOL)usesStatHero{return NO;}
- (BOOL)usesSearch{return NO;}
- (NSString *)heroTitle{return @"Pop-Up Control";}
- (NSString *)heroDetail{return @"Blocks pop-ups, and keeps your own website rules for Safari and other browsers.";}
- (BOOL)flag:(NSString *)key{return [self.shield[key] boolValue];}
- (void)rulesTileTapped:(UITapGestureRecognizer *)tap{
 if(tap.state!=UIGestureRecognizerStateEnded)return;
 MYBPressPulse(tap.view);[[UIImpactFeedbackGenerator new] impactOccurred];
 NSInteger index=tap.view.tag-1000;if(index<0||index>2||index==self.selectedList)return;
 self.selectedList=index;[self rebuildMenu];
}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];
 MYBTipShowOnce(self,@"popup",@"Pop-Up Control",@"Website Rules always apply in your browser; Pop-Up Permissions below are the sites you let open windows.",@"macwindow.on.rectangle");
}
- (BOOL)rulesNoticePending{return [[NSDictionary dictionaryWithContentsOfFile:MYBTipsFile()][@"BrowserRulesWereOff"] boolValue];}
- (void)dismissRulesNotice{
 NSMutableDictionary *tips=[([NSDictionary dictionaryWithContentsOfFile:MYBTipsFile()]?:@{}) mutableCopy];tips[@"BrowserRulesWereOff"]=@NO;[tips writeToFile:MYBTipsFile() atomically:YES];[self rebuildMenu];
}
- (void)rebuildMenu{
 [self loadRules];self.title=@"Pop-Up Control";
 BOOL popups=[self flag:@"BlockPopups"],standard=[self.shield[@"PopupMode"] isEqual:@"standard"];
 NSMutableArray *protect=[NSMutableArray arrayWithObject:
  @{@"title":@"Block Browser Pop-Ups",@"detail":@"Blocks new windows and tabs until you allow the website",@"icon":@"xmark.rectangle.fill",@"accent":@(YES),@"tone":@(MYBToneRose),@"switch":@"BlockPopups"}];
 if(popups){
  [protect addObject:@{@"title":@"Popup Mode",@"detail":standard?@"Standard":@"Strict",@"icon":@"slider.horizontal.3",@"accent":@(YES),@"tone":@(MYBToneRose),@"expander":@YES}];
  if(self.strictnessExpanded){
   [protect addObject:@{@"title":@"Strict",@"detail":@"Blocks every new window until you allow the website.",@"icon":@"shield.lefthalf.filled",@"tone":@(MYBToneRose),@"pick":@"strict",@"inline":@YES}];
   [protect addObject:@{@"title":@"Standard",@"detail":@"Lets through a window you opened with a tap, unless it goes to a website your rules block. Blocks the rest.",@"icon":@"hand.tap",@"tone":@(MYBToneRose),@"pick":@"standard",@"inline":@YES}];
  }
 }
 // Website rules: the selector, the Add action for the selected list, then that list’s real entries.
 NSInteger kind=MIN(self.selectedList,(NSInteger)self.lists.count-1);if(kind<0)kind=0;
 NSMutableArray *rules=[NSMutableArray array];
 if([self rulesNoticePending])[rules addObject:@{@"title":@"Browser rules are now always on",@"detail":@"You had them turned off. Your saved rules were kept and now apply in Safari and other supported browsers. Tap to dismiss.",@"icon":@"info.circle.fill",@"accent":@(YES),@"tone":@(MYBToneAmber),@"action":@"dismissRulesNotice"}];
 [rules addObject:@{@"selector":@YES,@"title":@"List"}];
 NSString *noun=kind==2?@"URL Prefix":(kind==1?@"Allowed Domain":@"Blocked Domain");
 [rules addObject:@{@"title":[@"Add " stringByAppendingString:noun],@"detail":kind==2?@"https://example.com/path":(kind==1?@"Always loads. Includes subdomains.":@"Always blocked. Includes subdomains."),@"icon":@"plus.circle.fill",@"accent":@(YES),@"tone":@(kind==1?MYBToneGreen:(kind==2?MYBToneBlue:MYBToneRose)),@"action":@"add"}];
 NSArray *items=self.lists[kind];
 for(NSUInteger i=0;i<items.count;i++){
  [rules addObject:@{@"title":items[i],@"detail":kind==2?@"URL prefix":@"Domain · includes subdomains",@"icon":kind==2?@"link":(kind==1?@"checkmark":@"hand.raised"),@"accent":@(YES),@"tone":@(kind==1?MYBToneGreen:(kind==2?MYBToneBlue:MYBToneRose)),@"action":@"edit",@"index":@(i),@"rule":@(YES)}];
 }
 if(!items.count)[rules addObject:@{@"title":@"Nothing here yet",@"detail":kind==2?@"URL prefixes you add appear here.":(kind==1?@"Allowed domains you add appear here.":@"Blocked domains you add appear here.")}];
 NSUInteger allowedSites=[MYBPopupGrants(NO) count],blockedSites=[MYBPopupGrants(YES) count],recent=[MYBShieldActivityOfTypes(MYBShieldActivityFile(),@[@"popup"]) count];
 [self applySections:@[
  @{@"title":@"BLOCK BROWSER POP-UPS",@"rows":protect,@"footer":@"When a website tries to open a window you are asked: Allow Once, Allow for 15 Minutes, Always Allow, Always Block or Block This Time."},
  @{@"title":@"WEBSITE RULES IN YOUR BROWSER",@"rows":rules,@"footer":@"A browser website rule decides whether a page or address loads. A popup permission decides whether a site may open another window. Phone-wide Custom Rules are separate. Tap a rule to edit it, swipe to delete."},
  @{@"title":@"PAGE CLEANUP",@"rows":@[@{@"title":@"Safari Cleanup",@"detail":@"Hide cookie banners, “Open in App” banners and other clutter",@"icon":@"wand.and.stars",@"accent":@(YES),@"tone":@(MYBToneTeal),@"page":@"MYBSafariCleanupController",@"action":@"openPage"}],@"footer":@"Separate from pop-up permissions, redirects and website rules. Off until you turn it on."},
 @{@"title":@"POP-UP PERMISSIONS · WINDOWS A SITE OPENS",@"rows":@[
    @{@"title":@"Sites Allowed to Open Windows",@"detail":[NSString stringWithFormat:@"%ld saved · each lasts as long as you chose",(long)allowedSites],@"icon":@"checkmark.circle",@"tone":@(MYBToneSlate),@"page":@"MYBPopupAllowedController",@"action":@"openPage"},
    @{@"title":@"Sites Always Blocked from Windows",@"detail":[NSString stringWithFormat:@"%ld saved · your Always Block choices",(long)blockedSites],@"icon":@"nosign",@"tone":@(MYBToneSlate),@"page":@"MYBPopupBlockedController",@"action":@"openPage"},
    @{@"title":@"Recent Pop-Up Attempts",@"detail":[NSString stringWithFormat:@"%ld in history · history only, not rules",(long)recent],@"icon":@"clock.arrow.circlepath",@"tone":@(MYBToneSlate),@"page":@"MYBPopupRecentController",@"action":@"openPage"}],
   @"footer":@"These are about new windows only. They are separate from Website Rules above, which decide whether a page loads at all."}]];
}
- (void)applySections:(NSArray *)sections{self.menuSections=sections;[self.tableView reloadData];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *key=row[@"switch"];
 if(row[@"selector"]){
  UITableViewCell *cell=[t dequeueReusableCellWithIdentifier:@"MYBRuleSelector"]?:[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MYBRuleSelector"];
  cell.backgroundColor=UIColor.clearColor;cell.selectionStyle=UITableViewCellSelectionStyleNone;
  for(UIView *old in [cell.contentView.subviews copy])[old removeFromSuperview];
  NSArray *specs=@[@{@"label":@"Blocked",@"tone":@(MYBToneRose),@"symbol":@"xmark.circle.fill"},@{@"label":@"Allowed",@"tone":@(MYBToneGreen),@"symbol":@"checkmark.circle.fill"},@{@"label":@"URLs",@"tone":@(MYBToneBlue),@"symbol":@"link"}];
  NSArray<UILabel *> *values=nil;UIView *strip=MYBTileStrip(specs,MIN(self.selectedList,2),self,@selector(rulesTileTapped:),&values);
  for(NSUInteger i=0;i<values.count;i++){NSString *count=@(i<self.lists.count?self.lists[i].count:0).stringValue;values[i].text=count;[strip viewWithTag:1000+i].accessibilityValue=count;}
  strip.translatesAutoresizingMaskIntoConstraints=NO;[cell.contentView addSubview:strip];
  [NSLayoutConstraint activateConstraints:@[[strip.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],[strip.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],[strip.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],[strip.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor]]];
  return cell;
 }
 MYBPrismCell *cell=[self cardForEntry:row table:t];
 if(row[@"expander"]){
  UIImageView *chevron=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
  chevron.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];chevron.tintColor=[MYBMuted() colorWithAlphaComponent:.7];chevron.contentMode=UIViewContentModeScaleAspectFit;
  chevron.translatesAutoresizingMaskIntoConstraints=NO;[chevron.widthAnchor constraintEqualToConstant:18].active=YES;[chevron.heightAnchor constraintEqualToConstant:20].active=YES;
  chevron.transform=self.strictnessExpanded?CGAffineTransformMakeRotation(M_PI):CGAffineTransformIdentity;cell.mybAccessoryView=chevron;cell.accessibilityTraits=UIAccessibilityTraitButton;cell.accessibilityValue=self.strictnessExpanded?@"Expanded":@"Collapsed";[cell refreshContent];
 }
 if(row[@"pick"]){BOOL on=[([self.shield[@"PopupMode"] isEqual:@"standard"]?@"standard":@"strict") isEqual:row[@"pick"]];cell.tone=on?MYBToneViolet:MYBToneSlate;cell.mybAccessoryType=on?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;cell.accessibilityTraits=on?UIAccessibilityTraitSelected:UIAccessibilityTraitNone;[cell refreshContent];}
 if(key.length){
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.enabled=!self.busy;toggle.onTintColor=MYBAccent();toggle.on=[self flag:key];
  [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];
 }
 return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if(row[@"selector"])return;
 if(row[@"expander"]){
  [tableView deselectRowAtIndexPath:p animated:YES];self.strictnessExpanded=!self.strictnessExpanded;[self rebuildMenu];return;
 }
 if(row[@"pick"]){
  [tableView deselectRowAtIndexPath:p animated:YES];if([row[@"pick"] isEqual:([self.shield[@"PopupMode"] isEqual:@"standard"]?@"standard":@"strict")])return;
  self.shield[@"PopupMode"]=row[@"pick"];
  if(![self.shield writeToFile:MYBPopupShieldFile() atomically:YES]){MYBComplete(self,NO,@"Couldn’t save",@"Your previous settings are retained.");}
  notify_post("net.myxxdev.mybloxx.safariguard.changed");[self refreshFilesBackup];[self rebuildMenu];return;
 }
 [super tableView:tableView didSelectRowAtIndexPath:p];
}
- (void)toggleChanged:(MYBPrismSwitch *)toggle{
 if(!toggle.key.length)return;
 self.shield[toggle.key]=@(toggle.on);
 if(![self.shield writeToFile:MYBPopupShieldFile() atomically:YES]){MYBComplete(self,NO,@"Couldn’t save",@"Your previous settings are retained.");[self rebuildMenu];return;}
 notify_post("net.myxxdev.mybloxx.safariguard.changed");[self refreshFilesBackup];[self rebuildMenu];
}
@end
