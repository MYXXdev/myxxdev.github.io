#import "MYBTileBase.h"
#import "MYBTips.h"
#import "../Shared/MYBShield.h"
#import "../Shared/MYBRedirectPolicy.h"
#import <notify.h>
// App Redirect Protection: two independent switches (App Store, other apps) and three tiles that open the saved permissions, the blocked
// attempts and the recent redirects. Clearing history never touches permissions; revoking one permission touches only that permission.
// Nothing here says an app "opened": MYbloXX® only knows what it stopped, what the person allowed and what it passed on to iOS.
static NSString *MYBRedirectShieldFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist");}
static NSArray *MYBRedirectGrants(NSString *filter){ // filter: all | appstore | appredirect
 NSMutableArray *out=[NSMutableArray array];
 for(NSDictionary *g in MYBShieldLiveGrants(MYBShieldPermissionsFile())){
  if(!MYBRedirectKindIsRedirect(g[@"kind"])||[g[@"mode"] isEqual:@"block"])continue;
  if(![filter isEqual:@"all"]&&![g[@"kind"] isEqual:filter])continue;[out addObject:g];
 }
 return out;
}
static NSArray *MYBRedirectEvents(NSString *filter,BOOL blockedOnly){
 NSMutableArray *out=[NSMutableArray array];
 NSArray *types=[filter isEqual:@"all"]?@[@"appstore",@"appredirect"]:@[filter];
 for(NSDictionary *i in MYBShieldActivityOfTypes(MYBShieldActivityFile(),types))if(!blockedOnly||MYBRedirectOutcomeForReason(i[@"reason"])==MYBOutcomeBlocked)[out addObject:i];
 return out;
}
static NSString *MYBRedirectRoute(NSString *kind,NSString *source,NSString *dest){
 NSString *from=MYBTileAppName(source);return [kind isEqual:@"appstore"]?[from stringByAppendingString:@" → App Store"]:[NSString stringWithFormat:@"%@ → %@",from,MYBTileAppName(dest)];
}

// ---- App Redirect Protection ----------------------------------------------------------------------------------------------------------
// Two switches, three tiles above ONE shared list. A tile filters the list in place. The list never claims an app "opened": MYbloXX® only
// knows what it stopped, what you allowed and what it passed on to iOS. Allowing a blocked route from history saves a permission for that
// one source (and destination) only; the launch itself waits for the next matching attempt.
// Can this history entry be turned into a permission without guessing? It needs the kind, a valid source and, for an app-to-app route, a valid destination.
static BOOL MYBRedirectEntryEligible(NSDictionary *e){
 NSString *type=e[@"type"],*source=e[@"source"],*dest=e[@"dest"];
 if(!MYBRedirectKindIsRedirect(type)||MYBRedirectOutcomeForReason(e[@"reason"])!=MYBOutcomeBlocked)return NO;
 return MYBShieldSourceValid(type,source)&&MYBShieldDestValid(type,[type isEqual:@"appstore"]?@"":dest)&&([type isEqual:@"appstore"]||dest.length);
}
@interface MYBRedirectController : MYBTileListBase
@property(nonatomic,strong) NSMutableDictionary *shield;
@property(nonatomic,assign) NSInteger listIndex; // 0 Allowed, 1 Blocked Attempts, 2 Recent. In memory only.
@property(nonatomic,strong) NSArray<NSDictionary *> *items;
@end
@implementation MYBRedirectController
- (NSString *)heroTitle{return @"App Redirect Protection";}
- (NSString *)heroDetail{return @"Asks before an app opens the App Store or another app.";}
- (NSString *)heroSymbol{return @"arrow.triangle.branch";}
- (MYBTone)heroTone{return MYBToneAmber;}
- (NSArray<NSDictionary *> *)tileSpecs{return @[@{@"label":@"Allowed",@"tone":@(MYBToneGreen),@"symbol":@"checkmark.circle.fill"},@{@"label":@"Blocked Attempts",@"tone":@(MYBToneRose),@"symbol":@"hand.raised.fill"},@{@"label":@"Recent",@"tone":@(MYBToneIndigo),@"symbol":@"clock.arrow.circlepath"}];}
- (NSArray<NSString *> *)tileValueTexts{return @[@([MYBRedirectGrants(@"all") count]).stringValue,@([MYBRedirectEvents(@"all",YES) count]).stringValue,@([MYBRedirectEvents(@"all",NO) count]).stringValue];}
- (void)updateTiles{
 [super updateTiles];
 MYBTileApplySelection(self.tableView.tableHeaderView,self.listIndex);
}
- (NSDictionary *)mybNavExtras{return @{@"list":@(self.listIndex)};}
- (void)mybApplyNavExtras:(NSDictionary *)extras{NSInteger index=[extras[@"list"] integerValue];if(index>=0&&index<=2&&index!=self.listIndex){self.listIndex=index;[self rebuildMenu];}}
- (void)tapTile:(NSInteger)index{
 if(index<0||index>2||index==self.listIndex)return;
 self.listIndex=index;[self rebuildMenu];
}
- (NSArray *)listRows{
 NSInteger k=self.listIndex;
 self.items=k==0?MYBRedirectGrants(@"all"):MYBRedirectEvents(@"all",k==1);
 return self.items;
}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];
 MYBTipShowOnce(self,@"redirect",@"App Redirect Protection",@"To allow a blocked app open, tap it under Blocked Attempts and choose how long; to undo, tap it under Allowed.",@"arrow.triangle.branch");
}
- (void)rebuildMenu{
 self.title=@"App Redirect Protection";
 self.shield=[[NSDictionary dictionaryWithContentsOfFile:MYBRedirectShieldFile()] mutableCopy]?:[NSMutableDictionary dictionary];
 [self listRows];
 NSInteger k=self.listIndex;NSMutableArray *rows=[NSMutableArray array];
 NSString *empty=k==0?@"No saved permissions":k==1?@"No blocked attempts":@"No recent redirects";
 if(!self.items.count)[rows addObject:@{@"title":empty,@"detail":k==0?@"MYbloXX® asks each time.":@"Redirects MYbloXX® asks about will appear here.",@"icon":@"checkmark.shield",@"tone":@(MYBToneSlate),@"info":@YES}];
 for(NSUInteger i=0;i<self.items.count;i++)[rows addObject:@{@"item":@(i)}];
 if(self.items.count&&k>0)[rows addObject:@{@"clear":@YES}];
 NSString *header=@[@"ALLOWED",@"BLOCKED ATTEMPTS",@"RECENT"][k];
 NSString *footer=k==0?@"Each permission covers one app opening the App Store, or one app opening one other app. Tap one to revoke just that one. Temporary permissions end by themselves."
  :k==1?@"These are events, not rules. Tap one to allow that exact route, or swipe to dismiss it. Clearing history never removes a permission."
  :@"Newest first. Permission saved means you allowed it; tap the link again if it did not continue. MYbloXX® can’t tell whether the other app really opened.";
 self.menuSections=@[
  @{@"title":@"ASK FIRST",@"rows":@[
    @{@"title":@"Ask Before Apps Open the App Store",@"detail":@"Asks when an app opens the App Store by itself. Opening the App Store from your Home Screen works as normal.",@"icon":@"bag.fill",@"accent":@(YES),@"tone":@(MYBToneAmber),@"switch":@"store"},
    @{@"title":@"Ask Before Links Open Other Apps",@"detail":@"Asks when a link in one app opens a different app. Only when MYbloXX® can tell which app sent it.",@"icon":@"arrow.up.forward.app.fill",@"accent":@(YES),@"tone":@(MYBToneAmber),@"switch":@"other"}],
   @"footer":@"The two switches work separately. Calls, Settings and the lock screen are never interrupted."},
  @{@"title":header,@"rows":rows,@"footer":footer}];
 [self.tableView reloadData];[self updateTiles];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if(p.section==0){
  NSString *key=row[@"switch"];MYBPrismCell *cell=[self cardForEntry:row table:t];
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.enabled=!self.busy;toggle.onTintColor=MYBAccent();
  toggle.on=[key isEqual:@"store"]?MYBRedirectAskAppStore(self.shield):MYBRedirectAskOtherApps(self.shield);
  [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];
  return cell;
 }
 if(row[@"info"])return MYBTileInfoCell(t,row[@"title"],row[@"detail"],row[@"icon"],MYBToneSlate,NO);
 if(row[@"clear"])return MYBTileInfoCell(t,@"Clear History",@"Removes events only. Saved permissions stay.",@"trash",MYBToneRose,YES);
 NSDictionary *i=self.items[[row[@"item"] integerValue]];
 if(self.listIndex==0){
  NSString *kind=i[@"kind"];NSString *mode=i[@"mode"];
  NSString *length=[mode isEqual:@"always"]?@"Always allowed":[mode isEqual:@"once"]?@"Allowed once":[NSString stringWithFormat:@"Allowed for 15 minutes · until %@",MYBTileClock([i[@"wallExpiry"] doubleValue])];
  NSString *scope=[kind isEqual:@"appstore"]?@"Any App Store request from this app":@"This app opening this app only";
  return MYBTileInfoCell(t,MYBRedirectRoute(kind,i[@"source"],i[@"dest"]),[NSString stringWithFormat:@"%@ · %@ · tap to revoke",length,scope],[kind isEqual:@"appstore"]?@"bag":@"arrow.up.forward.app",[mode isEqual:@"always"]?MYBToneGreen:MYBToneAmber,YES);
 }
 NSString *kind=i[@"type"];NSString *reason=i[@"reason"];MYBRedirectOutcome outcome=MYBRedirectOutcomeForReason(reason);NSInteger count=[i[@"count"] integerValue];
 NSString *state=MYBRedirectOutcomeTitle(outcome);if([reason isEqual:@"block-this-time"])state=@"Blocked this time";
 if([reason hasPrefix:@"permission-saved"])state=[reason hasPrefix:@"permission-saved-history"]?@"Allowed · tap the original link again":@"Permission saved · tap the link again";
 NSString *detail=[NSString stringWithFormat:@"%@ · %@%@ · %@",state,MYBRedirectReasonText(reason),count>1?[NSString stringWithFormat:@" · %ld×",(long)count]:@"",MYBTileAgo([i[@"last"] doubleValue])];
 if(outcome==MYBOutcomeBlocked){ // a blocked event can already have been allowed since: say so, so the list is not misleading
  NSDictionary *covered=MYBShieldDecideScheme(MYBShieldPermissionsFile(),kind,i[@"source"],[kind isEqual:@"appstore"]?nil:i[@"dest"],nil,NO);
  if([covered[@"verdict"] isEqual:@"allow"])detail=[detail stringByAppendingString:@" · Allowed now"];
  else if(MYBRedirectEntryEligible(i))detail=[detail stringByAppendingString:@" · tap to allow"];
 }
 return MYBTileInfoCell(t,MYBRedirectRoute(kind,i[@"source"],i[@"dest"]),detail,outcome==MYBOutcomeBlocked?@"hand.raised.fill":outcome==MYBOutcomeSaved?@"checkmark.seal.fill":@"arrow.right.circle.fill",outcome==MYBOutcomeBlocked?MYBToneRose:outcome==MYBOutcomeSaved?MYBToneGreen:MYBToneAmber,outcome==MYBOutcomeBlocked);
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(p.section==0)return;
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if(row[@"clear"]){
  MYBConfirmDestructive(self,@"Clear redirect history?",@"This removes the history list only. Your saved permissions stay as they are.",@"Clear History",^{MYBShieldClearActivityTypes(MYBShieldActivityFile(),@[@"appstore",@"appredirect"]);[self rebuildMenu];});return;
 }
 if(!row[@"item"])return;
 NSDictionary *i=self.items[[row[@"item"] integerValue]];
 if(self.listIndex==0){
  NSString *ident=i[@"id"];if(!ident)return;
  MYBConfirmDestructive(self,@"Revoke permission?",[NSString stringWithFormat:@"%@ will be asked about again next time. Nothing else changes.",MYBRedirectRoute(i[@"kind"],i[@"source"],i[@"dest"])],@"Revoke",^{MYBShieldRevoke(MYBShieldPermissionsFile(),ident);[self rebuildMenu];});
  return;
 }
 if(MYBRedirectOutcomeForReason(i[@"reason"])==MYBOutcomeBlocked)[self offerAllowForEntry:i];
}
// The action sheet for one blocked attempt. It names the source and destination, saves through the same permission store as the live prompt, and
// covers exactly that route. Allow Once is offered only when the event recorded its link type, so it is never wider than the live question’s.
- (void)offerAllowForEntry:(NSDictionary *)entry{
 NSString *type=entry[@"type"];BOOL store=[type isEqual:@"appstore"];NSString *route=MYBRedirectRoute(type,entry[@"source"],entry[@"dest"]);
 NSArray *facts=@[@[@"From",MYBTileAppName(entry[@"source"])],@[@"To",store?@"App Store":MYBTileAppName(entry[@"dest"])]];
 if(!MYBRedirectEntryEligible(entry)){
  MYBShieldChoice(self,@"Can’t Allow From Here",@"This attempt doesn’t say enough to allow it safely. Tap the original link again and answer the question that appears.",facts,@"exclamationmark.shield.fill",2,@[@{@"title":@"OK",@"style":@"primary"}]);return;
 }
 BOOL onceOK=entry[@"scheme"]!=nil;NSString *scheme=[entry[@"scheme"] length]?entry[@"scheme"]:nil;
 NSMutableArray *actions=[NSMutableArray array];
 void(^add)(NSString *,NSString *,NSString *,NSString *)=^(NSString *title,NSString *detail,NSString *mode,NSString *style){
  __block BOOL saved=NO;
  [actions addObject:@{@"title":title,@"detail":detail,@"style":style,
   @"handler":^{saved=[self saveAllowQuietly:entry mode:mode scheme:scheme];},
   @"result":^NSDictionary *{return saved?@{@"title":@"Allowed",@"message":@"Tap the original link again. This route is now under Allowed.",@"ok":@YES}:@{@"title":@"Couldn’t Save",@"message":[NSString stringWithFormat:@"%@ Nothing was allowed.",MYBShieldSaveFailureReason()],@"ok":@NO};}}];
 };
 if(onceOK)add(@"Allow Once",@"Only the next time, for this exact link",@"once",@"primary");
 add(@"Allow for 15 Minutes",store?@"Any App Store request from this app":@"This app opening this app only",@"temp",onceOK?@"secondary":@"primary");
 add(store?[NSString stringWithFormat:@"Always Allow from %@",MYBTileAppName(entry[@"source"])]:@"Always Allow This Route",store?@"Any App Store request from this app":@"This app opening this app only",@"always",@"secondary");
 [actions addObject:@{@"title":@"Dismiss This Entry",@"style":@"destructive",@"handler":^{MYBShieldDismissActivity(MYBShieldActivityFile(),entry);[self rebuildMenu];}}];
 [actions addObject:@{@"title":@"Cancel",@"style":@"cancel"}];
 NSString *note=onceOK?@"":@" Allow Once is only offered on the live question, because it is tied to the exact link.";
 MYBShieldChoice(self,[@"Allow " stringByAppendingString:route],[NSString stringWithFormat:@"This saves a permission for this route only. The link does not open now: you need to tap the original link again.%@",note],facts,@"arrow.triangle.branch",0,actions);
}
// Saves through the same permission store as the live prompt. Returns whether it was saved; the sheet shows the outcome.
- (BOOL)saveAllowQuietly:(NSDictionary *)entry mode:(NSString *)mode scheme:(NSString *)scheme{
 NSString *type=entry[@"type"],*dest=[type isEqual:@"appstore"]?nil:entry[@"dest"];
 NSDictionary *grant=MYBShieldAddGrantFor(MYBShieldPermissionsFile(),type,entry[@"source"],dest,mode,[mode isEqual:@"once"]?scheme:nil,nil);
 if(grant)MYBShieldRecordActivityScheme(MYBShieldActivityFile(),type,entry[@"source"],dest,[@"permission-saved-history-" stringByAppendingString:mode],nil,NO);
 [self rebuildMenu];return grant!=nil;
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)t trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)p{
 if(p.section==0||self.listIndex==0)return nil;
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];if(!row[@"item"])return nil;
 NSDictionary *entry=self.items[[row[@"item"] integerValue]];
 UIContextualAction *dismiss=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Dismiss" handler:^(UIContextualAction *a,UIView *v,void(^done)(BOOL)){(void)a;(void)v;BOOL ok=MYBShieldDismissActivity(MYBShieldActivityFile(),entry);[self rebuildMenu];done(ok);}];
 return [UISwipeActionsConfiguration configurationWithActions:@[dismiss]];
}
- (void)toggleChanged:(MYBPrismSwitch *)toggle{
 // Setting one switch writes both new keys from what is in effect now, so the other one never changes. The earlier keys are left as they are.
 if([toggle.key isEqual:@"store"])MYBRedirectSetAskAppStore(self.shield,toggle.on);else MYBRedirectSetAskOtherApps(self.shield,toggle.on);
 if(![self.shield writeToFile:MYBRedirectShieldFile() atomically:YES]){MYBComplete(self,NO,@"Couldn’t save",@"Your previous settings are retained.");[self rebuildMenu];return;}
 notify_post("net.myxxdev.mybloxx.safariguard.changed");[self refreshFilesBackup];[self rebuildMenu];
}
@end
