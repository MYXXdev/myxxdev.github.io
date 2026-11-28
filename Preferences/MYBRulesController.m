#import "MYBRulesController.h"
#import "MYBDesign.h"
#import "../Shared/MYBWebsiteRules.h"
#import "../Shared/MYBRuleStore.h"
#import "../Shared/MYBBulkRules.h"
#import "../Shared/MYBPinClient.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <notify.h>
// Custom Rules and Browser Rules: the same screen, laid out like Activity. A badge header, tiles with counts, a segmented control for the
// list being shown, search, and one row per rule. Plain domains include their subdomains; a wildcard (*) matches any text.
// Adding one rule is a tap on +. Adding many is a long press on +, so nobody pastes thousands of domains by accident.
@interface MYBRulesController ()<UIDocumentPickerDelegate,UISearchResultsUpdating>
@property(nonatomic,assign) BOOL importAllow;
@property(nonatomic,strong) UISearchController *search;
@property(nonatomic,strong) NSArray<UILabel *> *tileValues;
@end
@implementation MYBRulesController
- (BOOL)isShieldRules{return NO;}
- (NSDictionary *)mybNavExtras{return @{@"segment":@(self.selectedList)};}
- (void)mybApplyNavExtras:(NSDictionary *)extras{
 NSInteger index=[extras[@"segment"] integerValue];
 if(index>=0&&index<(self.isShieldRules?3:2)&&index!=self.selectedList){self.selectedList=index;[self rebuildMenu];}
}
- (BOOL)usesStatHero{return YES;}
- (BOOL)usesSearch{return YES;}
- (NSString *)shieldFile{return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist");}
- (void)loadRules {
 self.lists=[NSMutableArray array];
 if(self.isShieldRules){self.shield=[[NSDictionary dictionaryWithContentsOfFile:self.shieldFile] mutableCopy]?:[NSMutableDictionary dictionary];for(NSString *key in @[@"Blocked",@"Allowed",@"URLs"]){NSArray *items=[self.shield[key] isKindOfClass:NSArray.class]?self.shield[key]:@[];[self.lists addObject:[items mutableCopy]];}}
 else {NSDictionary *applied=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/AppliedRules.plist")]?:@{};NSDictionary *draft=MYBEffectiveRules(applied,[NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()]);for(NSString *key in @[@"blocked",@"allowed"])[self.lists addObject:[draft[key] mutableCopy]?:[NSMutableArray array]];}
}
- (NSString *)undoPath{return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.bulkundo.plist");}
- (NSDictionary *)undoRecord{NSDictionary *r=[NSDictionary dictionaryWithContentsOfFile:self.undoPath];return MYBBulkUndoAvailable(r,self.lists[0],self.lists[1])?r:nil;}
- (BOOL)pinProtectsNoXXX{
 NSDictionary *pin=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/PinState.plist")],*state=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/State.plist")];
 return [pin[@"enabled"] boolValue]&&[state[@"enabled"] boolValue]&&MYBPinModeHasXXX(MYBMigrateModeID(state[@"mode"]));
}
- (NSString *)query{return [[self.search.searchBar.text?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];}
- (NSString *)heroTitle{return self.isShieldRules?@"Browser Rules":@"Custom Rules";}
- (NSString *)heroDetail{return self.isShieldRules?@"Your own rules for Safari and other browsers.":@"Domains you always block, and domains you always allow.";}
- (NSArray<NSString *> *)segmentTitles{return @[];} // the tiles are the list selector; no second control repeats them
- (NSInteger)current{return self.selectedList;}
// Which tile is bright: the list being shown, or Wildcards while that filter is on (Custom Rules).
- (NSInteger)tileSelection{return (!self.isShieldRules&&[self.search.searchBar.text isEqualToString:@"*"])?2:self.selectedList;}
- (NSArray<NSDictionary *> *)tileSpecs{
 NSMutableArray *tiles=[NSMutableArray arrayWithObjects:@{@"label":@"Blocked",@"tone":@(MYBToneRose),@"symbol":@"xmark.circle.fill"},@{@"label":@"Allowed",@"tone":@(MYBToneGreen),@"symbol":@"checkmark.circle.fill"},nil];
 [tiles addObject:self.isShieldRules?@{@"label":@"URLs",@"tone":@(MYBToneBlue),@"symbol":@"link"}:@{@"label":@"Wildcards",@"tone":@(MYBToneViolet),@"symbol":@"asterisk"}];
 return tiles;
}
- (NSUInteger)wildcardCount{NSUInteger n=0;for(NSArray *list in self.lists)for(NSString *item in list)if(MYBRuleIsWildcard(item))n++;return n;}
- (void)updateTiles{
 MYBTileApplySelection(self.tableView.tableHeaderView,self.tileSelection);
 NSArray *counts=@[@(self.lists.count>0?self.lists[0].count:0),@(self.lists.count>1?self.lists[1].count:0),@(self.isShieldRules?(self.lists.count>2?self.lists[2].count:0):[self wildcardCount])];
 for(NSUInteger i=0;i<self.tileValues.count&&i<counts.count;i++)MYBCountUp(self.tileValues[i],[counts[i] integerValue]);
}
- (UIView *)makeHero{
 if(!self.usesStatHero)return [super makeHero];
 NSArray *values=nil;UISegmentedControl *segment=nil;
 UIView *hero=MYBStatHero(self.isShieldRules?@"safari.fill":@"list.bullet.rectangle.fill",self.isShieldRules?MYBToneBlue:MYBToneViolet,self.heroTitle,self.heroDetail,self.tileSpecs,self.segmentTitles,self.tileSelection,self,@selector(tileTapped:),@selector(segmentChanged),&values,&segment);
 self.tileValues=values;return hero;
}
- (void)tileTapped:(UITapGestureRecognizer *)tap{
 if(tap.state!=UIGestureRecognizerStateEnded)return;
 MYBPressPulse(tap.view);[[UIImpactFeedbackGenerator new] impactOccurred];
 NSInteger index=tap.view.tag-1000;
 if(!self.isShieldRules&&index==2){self.search.searchBar.text=@"*";[self rebuildMenu];return;} // Wildcards: show only the rules that contain a *
 if(index<(self.isShieldRules?3:2)){self.selectedList=index;self.search.searchBar.text=@"";[self rebuildMenu];}
}
- (void)segmentChanged{[self rebuildMenu];}
- (void)updateSearchResultsForSearchController:(UISearchController *)search{(void)search;[self rebuildMenu];}
- (NSString *)kindWord:(NSInteger)kind{return kind==2?@"URL prefix":(kind==1?@"Allowed domain":@"Blocked domain");}
- (void)rebuildMenu{
 [self loadRules];
 NSInteger kind=MIN(self.current,(NSInteger)self.lists.count-1);if(kind<0)kind=0;
 NSString *q=self.query;
 NSMutableArray *rows=[NSMutableArray array];
 NSString *noun=kind==2?@"URL Prefix":(kind==1?@"Allowed Domain":@"Blocked Domain");
 [rows addObject:@{@"title":[@"Add " stringByAppendingString:noun],@"detail":kind==2?@"https://example.com/path":(kind==1?@"Always loads. Includes subdomains.":@"Always blocked. Includes subdomains."),@"icon":@"plus.circle.fill",@"accent":@(YES),@"tone":@(kind==1?MYBToneGreen:(kind==2?MYBToneBlue:MYBToneRose)),@"action":@"add"}];
 if(kind<2)[rows addObject:@{@"title":kind==1?@"Add an Allowed Wildcard":@"Add a Blocked Wildcard",@"detail":@"Use * for any text, like ads*.example.com",@"icon":@"asterisk.circle.fill",@"accent":@(YES),@"tone":@(MYBToneViolet),@"action":@"addWildcard"}];
 if(!self.isShieldRules)[rows addObject:@{@"title":@"Export Domains",@"detail":@"Share a plain-text list of your saved website rules.",@"icon":@"square.and.arrow.up",@"accent":@(YES),@"tone":@(MYBToneBlue),@"action":@"exportDomains"}];
 NSArray *items=self.lists[kind];NSUInteger shown=0;
 for(NSUInteger i=0;i<items.count;i++){
  NSString *item=items[i];if(q.length&&![item containsString:q])continue;shown++;
  BOOL wild=MYBRuleIsWildcard(item);
  [rows addObject:@{@"title":item,@"detail":kind==2?@"URL prefix":(wild?@"Wildcard · matches any text at the *":@"Domain · includes subdomains"),@"icon":wild?@"asterisk":(kind==2?@"link":(kind==1?@"checkmark":@"hand.raised")),@"accent":@(YES),@"tone":@(wild?MYBToneViolet:(kind==1?MYBToneGreen:(kind==2?MYBToneBlue:MYBToneRose))),@"action":@"edit",@"index":@(i),@"rule":@(YES)}];
 }
 if(!shown)[rows addObject:@{@"title":q.length?@"No match":@"Nothing here yet",@"detail":q.length?@"No rule contains that.":(kind==1?@"Allowed domains you add appear here.":@"Blocked domains you add appear here.")}];
 NSString *header=[NSString stringWithFormat:@"%@ · %lu",@[@"BLOCKED DOMAINS",@"ALLOWED DOMAINS",@"BLOCKED URL PREFIXES"][kind],(unsigned long)items.count];
 NSString *footer=kind==2?@"URL prefix rules apply to page navigations in those browsers, not individual page resources. Matching is case-sensitive.":(kind==1?(self.isShieldRules?@"Browser Rules allow rules apply to Browser Rules only; they do not override the main protection.":@"Allowed domains always load and win over blocked ones. Tap a rule to edit it, swipe to delete."):@"Blocking a domain also blocks everything under it. A wildcard matches any text where you put the *. Tap a rule to edit it, swipe to delete.");
 self.menuSections=@[@{@"title":header,@"rows":rows,@"footer":footer}];
 [self.tableView reloadData];[self updateTiles];
}
- (void)viewDidLoad {
 self.title=[self heroTitle];
 [super viewDidLoad];
 if(!self.usesSearch)return;
 self.search=[[UISearchController alloc] initWithSearchResultsController:nil];self.search.searchResultsUpdater=self;self.search.obscuresBackgroundDuringPresentation=NO;self.search.searchBar.placeholder=@"Find a rule";
 self.search.searchBar.autocapitalizationType=UITextAutocapitalizationTypeNone;self.search.searchBar.autocorrectionType=UITextAutocorrectionTypeNo;
 self.navigationItem.searchController=self.search;self.navigationItem.hidesSearchBarWhenScrolling=NO;self.definesPresentationContext=YES;
 UIButton *plus=[UIButton buttonWithType:UIButtonTypeSystem];
 [plus setImage:[UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];plus.tintColor=MYBAccent();plus.frame=CGRectMake(0,0,44,44);
 [plus addTarget:self action:@selector(addRule) forControlEvents:UIControlEventTouchUpInside];
 if(!self.isShieldRules){UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(bulkMenu:)];hold.minimumPressDuration=.6;[plus addGestureRecognizer:hold];}
 plus.accessibilityLabel=@"Add a rule";
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:plus];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];if(!self.isShieldRules)[self runHelper:@[@"recoverrules"] completion:^(int rc){if(rc)[self showMessage:@"Couldn’t recover saved rules" detail:@"Existing active rules are retained. Try Repair MYbloXX®."];[self rebuildMenu];}];else [self rebuildMenu];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(self.busy)return;
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *action=row[@"action"];NSInteger kind=MIN(self.current,(NSInteger)self.lists.count-1);
 if([action isEqual:@"add"])[self editKind:kind row:NSNotFound wildcard:NO];
 else if([action isEqual:@"addWildcard"])[self editKind:kind row:NSNotFound wildcard:YES];
 else if([action isEqual:@"edit"])[self editKind:kind row:[row[@"index"] integerValue] wildcard:MYBRuleIsWildcard(row[@"title"])];
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)t trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)p {
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];if(self.busy||![row[@"rule"] boolValue])return nil;
 NSInteger kind=MIN(self.current,(NSInteger)self.lists.count-1);NSInteger index=[row[@"index"] integerValue];
 UIContextualAction *remove=[UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(__unused UIContextualAction *a,__unused UIView *v,void(^done)(BOOL)){if(index<(NSInteger)self.lists[kind].count){[self.lists[kind] removeObjectAtIndex:index];[self saveRules];}done(YES);}];
 return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}
- (void)toggleChanged:(MYBPrismSwitch *)toggle{(void)toggle;}
// ---- Export Domains ---------------------------------------------------------------------------------------------------------------------
// Read-only. The text is built from the saved phone-wide rules (never from what the search field is showing), holds domain rules only, and is
// handed to the share sheet or the clipboard. It changes, uploads and reapplies nothing, and it says nothing about whether a domain is safe.
- (NSString *)exportTextForBlocked:(BOOL)blocked allowed:(BOOL)allowed count:(NSUInteger *)countOut{
 NSMutableString *text=[NSMutableString string];NSUInteger total=0;
 NSDateFormatter *stamp=[NSDateFormatter new];stamp.dateFormat=@"yyyy-MM-dd HH:mm";
 [text appendFormat:@"# MYbloXX® Custom Rules export, for review\n# Exported %@\n# Plain text, one rule per line. A domain rule also covers its subdomains.\n# A line marked [pattern] uses * to match any text. Patterns are not exact domains.\n# Only your saved phone-wide domain rules are listed. This file is not a safety check: MYbloXX® has not looked into any of these domains.\n",[stamp stringFromDate:NSDate.date]];
 NSArray *titles=@[@"BLOCKED",@"ALLOWED"];BOOL wanted[2]={blocked,allowed};
 for(NSInteger kind=0;kind<2;kind++){
  if(!wanted[kind]||kind>=(NSInteger)self.lists.count)continue;
  NSArray *items=self.lists[kind];
  if((blocked&&allowed)||items.count)[text appendFormat:@"\n## %@ (%lu)\n",titles[kind],(unsigned long)items.count];
  for(NSString *item in items){[text appendString:MYBRuleIsWildcard(item)?[@"[pattern] " stringByAppendingString:item]:item];[text appendString:@"\n"];total++;}
 }
 if(countOut)*countOut=total;return text;
}
- (void)exportDomains{
 if(self.busy)return;
 [self loadRules]; // the saved rules as they are now, whatever the search field or scroll position shows
 __weak typeof(self) weak=self;
 MYBChoose(self,@"Export Domains",@[@"Blocked Domains",@"Allowed Domains",@"Both Lists"],^(NSUInteger which){
  typeof(self) me=weak;if(!me)return;
  BOOL blocked=which!=1,allowed=which!=0;NSUInteger count=0;NSString *text=[me exportTextForBlocked:blocked allowed:allowed count:&count];
  if(!count){MYBMessage(me,@"Nothing to Export",which==0?@"You have no blocked domains saved.":which==1?@"You have no allowed domains saved.":@"You have no saved domains.");return;}
  MYBChoose(me,@"Export",@[@"Share or Save to Files",@"Copy as Text"],^(NSUInteger how){
   typeof(self) me2=weak;if(!me2)return;
   if(how==1){UIPasteboard.generalPasteboard.string=text;MYBComplete(me2,YES,@"Copied",[NSString stringWithFormat:@"%lu rule%@ copied as plain text.",(unsigned long)count,count==1?@"":@"s"]);return;}
   NSString *name=which==0?@"MYbloXX-blocked-domains.txt":which==1?@"MYbloXX-allowed-domains.txt":@"MYbloXX-domains.txt";
   NSURL *file=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];NSError *error=nil;
   if(![text writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:&error]){MYBComplete(me2,NO,@"Couldn’t Export",@"The file could not be created. Your rules were not changed.");return;}
   UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
   share.completionWithItemsHandler=^(UIActivityType type,BOOL done,NSArray *items,NSError *err){(void)type;(void)done;(void)items;(void)err;[NSFileManager.defaultManager removeItemAtURL:file error:NULL];};
   share.popoverPresentationController.sourceView=me2.view;share.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(me2.view.bounds),CGRectGetMidY(me2.view.bounds),1,1);
   [me2 presentViewController:share animated:YES completion:nil];
  });
 });
}
- (void)saveRules {
 if(self.isShieldRules){NSArray *keys=@[@"Blocked",@"Allowed",@"URLs"];for(NSUInteger i=0;i<keys.count;i++)self.shield[keys[i]]=self.lists[i];if(![self.shield writeToFile:self.shieldFile atomically:YES]){MYBComplete(self,NO,@"Couldn’t save",@"Your previous browser rules are retained.");[self rebuildMenu];return;}notify_post("net.myxxdev.mybloxx.safariguard.changed");[self refreshFilesBackup];[self rebuildMenu];}
 else {
  [self runHelper:@[@"localcustom",[self.lists[0] componentsJoinedByString:@","],[self.lists[1] componentsJoinedByString:@","]] completion:^(int rc){
   if(rc)[self showMessage:@"Rules not applied" detail:[NSString stringWithFormat:@"Previous working rules retained (error %d).",rc]];
   [self rebuildMenu];
  }];
 }
}
// ---- bulk add (long press on +) -------------------------------------------------------------------------------------------
- (void)importRules{
 if(self.busy||self.isShieldRules)return;
 __weak typeof(self) weak=self;
 MYBChoose(self,@"Add Many Domains",@[@"Paste Blocked Domains",@"Paste Allowed Domains",@"Open a Blocked List File",@"Open an Allowed List File"],^(NSUInteger i){
  typeof(self) me=weak;if(!me)return;BOOL allow=(i==1||i==3);
  if(i<2){
   NSString *text=UIPasteboard.generalPasteboard.string;
   if(!text.length){MYBMessage(me,@"Nothing to Paste",@"Copy a list of domains first, then try again.");return;}
   [me previewImport:text allow:allow];return;
  }
  me.importAllow=allow;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.45*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypePlainText,UTTypeText] asCopy:YES];
   picker.delegate=me;picker.allowsMultipleSelection=NO;[me presentViewController:picker animated:YES completion:nil];
  });
 });
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
 NSURL *url=urls.firstObject;if(!url)return;
 NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:NULL];
 if([attributes[NSFileSize] unsignedLongLongValue]>2*1024*1024){MYBMessage(self,@"File Too Large",@"Choose a smaller list or split it into parts.");return;}
 NSString *text=[NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];
 if(!text.length){MYBMessage(self,@"Couldn’t Read File",@"Choose a plain text file with one domain on each line.");return;}
 [self previewImport:text allow:self.importAllow];
}
- (void)previewImport:(NSString *)text allow:(BOOL)allow{
 NSDictionary *plan=MYBBulkPlan(text,allow,self.lists[0],self.lists[1]);NSString *summary=MYBBulkSummary(plan);NSUInteger add=[plan[@"add"] count];
 if(!add){MYBMessage(self,@"Nothing to Import",summary);return;}
 if(allow&&[self pinProtectsNoXXX])summary=[summary stringByAppendingString:@"\n\nnoXXX PIN protection is on. If noXXX blocks any of these, you will be asked for your PIN."];
 MYBConfirmWithButton(self,[NSString stringWithFormat:@"Add %lu to %@?",(unsigned long)add,allow?@"Allowed":@"Blocked"],summary,[NSString stringWithFormat:@"Add %lu",(unsigned long)add],^{[self applyImport:plan];});
}
// One transaction: the helper writes every file and applies the PAC, or changes nothing. Undo is recorded only after it succeeded.
- (void)applyImport:(NSDictionary *)plan{
 NSArray *beforeBlocked=[self.lists[0] copy],*beforeAllowed=[self.lists[1] copy];
 MYBProgress(self,@"Importing");
 [self runHelper:@[@"localcustom",MYBBulkCSV(plan[@"blockedAfter"]),MYBBulkCSV(plan[@"allowedAfter"])] completion:^(int rc){
  if(rc){
   [self rebuildMenu];
   MYBComplete(self,NO,@"Nothing Was Imported",rc==MYB_PIN_EXIT_REQUIRED?@"noXXX PIN protection needs the PIN for this change. Your rules were not changed.":rc==MYB_PIN_EXIT_LOCKED?@"Too many wrong PINs. Try again later. Your rules were not changed.":[NSString stringWithFormat:@"Your previous rules are still in place (error %d).",rc]);
   return;
  }
  [MYBBulkUndoRecord(beforeBlocked,beforeAllowed,plan) writeToFile:self.undoPath atomically:YES];
  [self rebuildMenu];
  MYBComplete(self,YES,[NSString stringWithFormat:@"%lu Added",(unsigned long)[plan[@"add"] count]],@"Undo Last Import is on this screen until you change your rules again.");
 }];
}
- (void)undoImport{
 NSDictionary *record=self.undoRecord;if(!record||self.busy)return;
 MYBConfirmWithButton(self,@"Undo Last Import?",@"The domains you added are removed. Your other rules stay as they are.",@"Undo",^{
  MYBProgress(self,@"Undoing");
  [self runHelper:@[@"localcustom",MYBBulkCSV(record[@"beforeBlocked"]),MYBBulkCSV(record[@"beforeAllowed"])] completion:^(int rc){
   [self rebuildMenu];
   if(rc){MYBComplete(self,NO,@"Nothing Was Undone",[NSString stringWithFormat:@"Your rules are as they were (error %d).",rc]);return;}
   [NSFileManager.defaultManager removeItemAtPath:self.undoPath error:NULL];[self.tableView reloadData];
   MYBComplete(self,YES,@"Import Undone",@"Your rules are back to how they were.");
  }];
 });
}
- (void)bulkMenu:(UILongPressGestureRecognizer *)hold{
 if(hold.state!=UIGestureRecognizerStateBegan||self.busy||self.isShieldRules)return;
 [[UIImpactFeedbackGenerator new] impactOccurred];
 NSMutableArray *names=[NSMutableArray arrayWithObject:@"Add Many Domains"];BOOL undo=self.undoRecord!=nil;if(undo)[names addObject:@"Undo Last Bulk Add"];
 __weak typeof(self) weak=self;
 MYBChoose(self,@"Bulk Add",names,^(NSUInteger i){typeof(self) me=weak;if(!me)return;if(i==0)[me importRules];else [me undoImport];});
}
- (void)addRule{
 if(self.busy)return;
 NSArray *names=self.isShieldRules?@[@"Block a Domain",@"Allow a Domain",@"Block a URL Prefix"]:@[@"Block a Domain",@"Allow a Domain",@"Block a Wildcard",@"Allow a Wildcard"];
 MYBChoose(self,@"Add a Rule",names,^(NSUInteger index){
  if(self.isShieldRules){[self editKind:index row:NSNotFound wildcard:NO];return;}
  [self editKind:index%2 row:NSNotFound wildcard:index>=2];
 });
}
- (BOOL)valid:(NSString *)text kind:(NSInteger)kind {
 if(kind==2){NSURLComponents *url=[NSURLComponents componentsWithString:text];return text.length<=2048&&[@[@"http",@"https"] containsObject:url.scheme]&&url.host.length&&!url.user.length&&!url.password.length;}
 if(self.isShieldRules&&MYBRuleIsWildcard(text))return NO; // the browser guard matches plain domains and URL prefixes only
 return MYBValidRuleEntry(text);
}
- (void)editKind:(NSInteger)kind row:(NSInteger)row wildcard:(BOOL)wildcard{
 NSMutableArray *items=self.lists[kind];BOOL editing=row!=NSNotFound&&row<(NSInteger)items.count;NSString *old=editing?items[row]:@"";
 NSString *detail=kind==2?@"Enter a complete URL prefix. Matching is case-sensitive.":(wildcard?@"Use * for any text, for example ads*.example.com. The name must end in a real domain like example.com, so one rule can never block a whole ending such as .com.":@"Enter a domain without https:// or a path. It includes everything under it.");
 MYBInput(self,editing?@"Edit Rule":(wildcard?@"Add Wildcard":@"Add Rule"),detail,@[@{@"value":old,@"placeholder":kind==2?@"https://example.com/path":(wildcard?@"ads*.example.com":@"example.com")}],@"Save Rule",^(NSArray *values){
  NSString *value=[values.firstObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(kind!=2)value=value.lowercaseString;if(kind!=2&&[value hasPrefix:@"*."]&&![[value substringFromIndex:2] containsString:@"*"])value=[value substringFromIndex:2];
  if(![self valid:value kind:kind]){MYBMessage(self,@"Check This Rule",kind==2?@"Use a complete http or https address.":@"Use a valid domain, or a wildcard that ends in a real domain such as example.com.");return;}
  if((![value isEqual:old]&&[items containsObject:value])||(kind<2&&[self.lists[kind==1?0:1] containsObject:value])){MYBMessage(self,@"Already Listed",@"Keep each domain in either Blocked or Allowed.");return;}
  if(!editing&&items.count>=20000){MYBMessage(self,@"Rule Limit Reached",@"Remove a rule before adding another.");return;}
  if(editing)items[row]=value;else [items addObject:value];[self saveRules];
 });
}
@end
