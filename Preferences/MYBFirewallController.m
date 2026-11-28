#import "MYBMenuBase.h"
#import "MYBTileBase.h"
#import "MYBDesign.h"
#import "MYBTips.h"
#import "../Shared/MYBConnectivity.h"
#import "../Shared/MYBFirewallStore.h"
#import "../Shared/MYBFirewallList.h"
#import "../Shared/MYBMessageFirewallStore.h"
#import "../Shared/MYBMessageFirewallList.h"
#import "../Shared/MYBPCContacts.h"
#import "../Shared/MYBProtectionStats.h"
#import <ContactsUI/ContactsUI.h>
#import <notify.h>
// Call Firewall: general-purpose call blocking, visible in Settings (unlike Private Calls, which moved entirely into Phone's five-tap gesture). Its
// own file, its own switch, its own live channel (Shared/MYBFirewallStore.h, MYBFirewallList.h) -- it shares only the proven number-matching code
// with Private Calls (Shared/MYBPrivateCalls.h), never its list or state. A number can be in both lists, in neither, or in just one.
// Kept to two screens on purpose: a short overview here, with the two open-ended lists (Numbers, Ranges) pushed to their own single-purpose pages --
// the same shape as App Lock's Locked Apps picker -- so no one screen ever shows more than a handful of rows at once.
static NSString *MYBFirewallFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.firewall.plist");}
static NSString *MYBFWRegionNow(void){return [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];}
// Every write funnels through here so the live channel and the mailbox are always told immediately afterward: no reboot is ever needed to see a change.
static void MYBFWAfterChange(void){notify_post(MYB_FW_NOTIFY);MYBFWLPublish(MYBFirewallFile());}
static NSDictionary *MYBFWSettings(void){return MYBFWSettingsRead(MYBFirewallFile());}
static BOOL MYBFWSaveSettings(NSDictionary *changes){BOOL ok=MYBFWSettingsWrite(MYBFirewallFile(),changes);if(ok)MYBFWAfterChange();return ok;}
static BOOL MYBFWSaveEntry(NSString *key,NSString *display,NSString *action,BOOL on){BOOL ok=MYBFWStoreSet(MYBFirewallFile(),key,display,action,on,NSDate.date.timeIntervalSince1970);if(ok)MYBFWAfterChange();return ok;}
static BOOL MYBFWSaveRanges(NSArray *ranges){BOOL ok=MYBFWRangesWrite(MYBFirewallFile(),ranges);if(ok)MYBFWAfterChange();return ok;}

// Message Firewall: its own file, its own switch, its own two lists (Senders, Keywords) -- shares only MYBPrivateCalls.h's proven phone-number
// normalizing with the Call Firewall above it, never its list or state. Every write republishes the live list immediately, the same no-reboot
// guarantee the Call Firewall already makes; imagent reads it fresh on every incoming text (Companions/MYBMessageFirewall).
static NSString *MYBMessageFirewallFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.msgfirewall.plist");}
static void MYBMFAfterChange(void){MYBMFLPublish(MYBMessageFirewallFile());}
static BOOL MYBMFSaveSwitch(BOOL on){BOOL ok=MYBMFSwitchWrite(MYBMessageFirewallFile(),on);if(ok)MYBMFAfterChange();return ok;}
static BOOL MYBMFSaveSender(NSString *key,NSString *display,BOOL on){BOOL ok=MYBMFSetSender(MYBMessageFirewallFile(),key,display,on,NSDate.date.timeIntervalSince1970);if(ok)MYBMFAfterChange();return ok;}
static BOOL MYBMFSaveKeyword(NSString *key,NSString *display,BOOL on){BOOL ok=MYBMFSetKeyword(MYBMessageFirewallFile(),key,display,on,NSDate.date.timeIntervalSince1970);if(ok)MYBMFAfterChange();return ok;}
static BOOL MYBMFSavePatternCategory(NSString *key,BOOL on){BOOL ok=MYBMFPatternCategoryWrite(MYBMessageFirewallFile(),key,on);if(ok)MYBMFAfterChange();return ok;}

// Four-way choice sheet (Mute / Decline / Hang up / Allow), reused for every action picker so the wording never drifts between them. allowChoice:
// Allow only makes sense for a number already on the list (it exempts that one number from every blanket rule) -- the blanket rules themselves
// never offer it, since "allow" with no number behind it is just "no rule", which turning the whole blanket rule off already means.
// removeTitle: nil for a blanket rule (there's nothing to delete, only to turn off). When set, the handler is the caller's own already-confirmed
// removal -- the confirm step itself lives at the call site, next to the copy that explains what removing *this* kind of entry actually undoes.
static void MYBFWChooseAction(UIViewController *host,NSString *heading,NSString *message,BOOL allowChoice,NSString *removeTitle,void(^set)(NSString *),void(^remove)(void)){
 NSMutableArray *actions=[NSMutableArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"Mute",@"title",@"Silences the ringer. The caller keeps ringing.",@"detail",@"primary",@"style",^{set(MYB_PC_ACTION_MUTE);},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Decline",@"title",@"Declines the moment it rings.",@"detail",@"secondary",@"style",^{set(MYB_PC_ACTION_DECLINE);},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Hang up",@"title",@"Picks up and hangs up at once.",@"detail",@"secondary",@"style",^{set(MYB_PC_ACTION_HANGUP);},@"handler",nil],nil];
 if(allowChoice)[actions addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Allow",@"title",@"Rings normally, exempt from every rule below.",@"detail",@"secondary",@"style",^{set(MYB_FW_ACTION_ALLOW);},@"handler",nil]];
 if(removeTitle.length)[actions addObject:[NSDictionary dictionaryWithObjectsAndKeys:removeTitle,@"title",@"destructive",@"style",remove,@"handler",nil]];
 [actions addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Cancel",@"title",@"cancel",@"style",nil]];
 MYBShieldChoice(host,heading,message,[NSArray array],@"shield.lefthalf.filled",1,actions);
}

@interface MYBFWContactDelegate : NSObject <CNContactPickerDelegate>
@property(nonatomic,copy) void (^done)(NSArray<NSDictionary *> *numbers);
@end
@implementation MYBFWContactDelegate
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)property{
 (void)picker;id value=property.value;
 NSString *name=[CNContactFormatter stringFromContact:property.contact style:CNContactFormatterStyleFullName]?:@"";
 if(self.done)self.done([value isKindOfClass:CNPhoneNumber.class]?[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:[(CNPhoneNumber *)value stringValue],@"number",name,@"name",nil]]:[NSArray array]);
}
@end

// ---- Numbers (its own page, same shape as App Lock's Locked Apps picker) --------------------------------------------------------------------
@interface MYBFWNumbersController : MYBMenuBase @property(nonatomic,strong) MYBFWContactDelegate *pickerDelegate; @end
@implementation MYBFWNumbersController
- (NSString *)heroTitle{return @"Numbers";}
- (NSString *)heroDetail{return @"Mute silences the ringer, Decline rejects at once, Hang up answers and ends immediately. Allow always rings through.";}
- (void)viewDidLoad{
 [super viewDidLoad];
 UIButton *plus=[UIButton buttonWithType:UIButtonTypeSystem];
 [plus setImage:[UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
 plus.tintColor=MYBAccent();plus.frame=CGRectMake(0,0,44,44);[plus addTarget:self action:@selector(addNumber) forControlEvents:UIControlEventTouchUpInside];
 plus.accessibilityLabel=@"Add a number";self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:plus];
}
- (void)rebuildMenu{
 self.title=@"Numbers";
 NSArray *entries=MYBFWEntries(MYBFirewallFile());
 NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *entry in entries){
  NSString *key=[entry objectForKey:@"k"];
  [rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:
   MYBPCLabelWithNumber(entry,MYBPCContactName(key),MYBFWRegionNow()),@"title",
   MYBFWActionName([entry objectForKey:@"a"]),@"value",@"phone.fill",@"icon",key,@"fwKey",@"edit",@"action",nil]];
 }
 if(!rows.count)[rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"No numbers yet",@"title",@"Tap + to add one",@"detail",@"phone.badge.plus",@"icon",nil]];
 self.menuSections=[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"",@"title",rows,@"rows",
  @"Only ordinary phone calls from these exact numbers are affected, never emergency calls, FaceTime or other apps. A caller ID match is a rule match, not proof of who is calling.",@"footer",nil]];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=[[self.menuSections[(NSUInteger)p.section] objectForKey:@"rows"] objectAtIndex:(NSUInteger)p.row];
 if([row objectForKey:@"fwKey"]){[t deselectRowAtIndexPath:p animated:YES];[self chooseActionForKey:[row objectForKey:@"fwKey"]];return;}
 [super tableView:t didSelectRowAtIndexPath:p];
}
- (void)chooseActionForKey:(NSString *)key{
 NSDictionary *entry=MYBFWEntryForKey(MYBFirewallFile(),key);if(!entry)return;
 NSString *shown=MYBPCLabel(entry,MYBPCContactName(key),MYBFWRegionNow()),*stored=[entry objectForKey:@"d"]?:shown;
 __weak typeof(self) weak=self;
 MYBFWChooseAction(self,shown,@"What should happen when this number calls?",YES,@"Remove from Call Firewall",
  ^(NSString *action){if(!MYBFWSaveEntry(key,stored,action,YES))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];},
  ^{MYBConfirmWithButton(weak,@"Remove this number?",@"Its calls go through normally again. No call record is deleted or changed.",@"Remove",^{
    if(!MYBFWSaveEntry(key,stored,[entry objectForKey:@"a"],NO))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];});});
}
- (BOOL)addRaw:(NSString *)raw name:(NSString *)name quiet:(BOOL)quiet{
 if(MYBPCIsProtectedNumber(raw)){if(!quiet)MYBComplete(self,NO,@"Not allowed",@"Emergency numbers can’t be added.");return NO;}
 NSString *key=MYBPCKey(raw,MYBFWRegionNow());
 if(!key){if(!quiet)MYBComplete(self,NO,@"Not a phone number",@"Type the number the way it shows when they call. A country code is not needed.");return NO;}
 NSString *action=MYB_PC_ACTION_DECLINE;NSDictionary *existing=MYBPCEntryForKeyLoose(MYBFWEntries(MYBFirewallFile()),key);
 if(existing){key=[existing objectForKey:@"k"];action=[existing objectForKey:@"a"];}
 NSString *label=MYBPCNameOnly(name)?:MYBPCContactName(key)?:MYBPCFormat(key,MYBFWRegionNow());
 if(!MYBFWSaveEntry(key,label,action,YES)){if(!quiet)MYBComplete(self,NO,@"Couldn’t save",@"Nothing was changed.");return NO;}
 return YES;
}
- (void)addNumber{
 __weak typeof(self) weak=self;
 MYBShieldChoice(self,@"Add a Number",nil,[NSArray array],@"phone.badge.plus",1,[NSArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"Type a Number",@"title",@"primary",@"style",^{[weak askNumber];},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Choose from Contacts",@"title",@"secondary",@"style",^{[weak pickContacts];},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Cancel",@"title",@"cancel",@"style",nil],nil]);
}
- (void)askNumber{
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Add a Number" message:@"Type it the way it shows when they call. A country code is not needed." preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.keyboardType=UIKeyboardTypePhonePad;field.placeholder=@"Phone number";field.autocorrectionType=UITextAutocorrectionTypeNo;}];
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 __weak UIAlertController *weak=alert;__weak typeof(self) weakSelf=self;
 [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){(void)a;
  [weakSelf addRaw:weak.textFields.firstObject.text name:nil quiet:NO];[weakSelf rebuildMenu];}]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (void)pickContacts{
 CNContactPickerViewController *picker=[CNContactPickerViewController new];
 picker.displayedPropertyKeys=[NSArray arrayWithObject:CNContactPhoneNumbersKey];
 self.pickerDelegate=[MYBFWContactDelegate new];
 __weak typeof(self) weak=self;
 self.pickerDelegate.done=^(NSArray<NSDictionary *> *numbers){
  NSInteger added=0,refused=0;for(NSDictionary *n in numbers){if([weak addRaw:[n objectForKey:@"number"] name:[n objectForKey:@"name"] quiet:YES])added++;else refused++;}
  [weak rebuildMenu];
  if(added||refused)MYBComplete(weak,added>0,added?@"Added":@"Not added",[NSString stringWithFormat:@"%ld number%@ added.%@",(long)added,added==1?@"":@"s",refused?[NSString stringWithFormat:@" %ld could not be read as a phone number.",(long)refused]:@""]);
 };
 picker.delegate=self.pickerDelegate;
 [self presentViewController:picker animated:YES completion:nil];
}
@end

// ---- Number Ranges (its own page) -----------------------------------------------------------------------------------------------------------
@interface MYBFWRangesController : MYBMenuBase @end
@implementation MYBFWRangesController
- (NSString *)heroTitle{return @"Number Ranges";}
- (NSString *)heroDetail{return @"Block a whole country code or a premium-rate block at once. The most specific range you add always wins over a broader one.";}
- (void)viewDidLoad{
 [super viewDidLoad];
 UIButton *plus=[UIButton buttonWithType:UIButtonTypeSystem];
 [plus setImage:[UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
 plus.tintColor=MYBAccent();plus.frame=CGRectMake(0,0,44,44);[plus addTarget:self action:@selector(askRange) forControlEvents:UIControlEventTouchUpInside];
 plus.accessibilityLabel=@"Add a range";self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:plus];
}
- (void)rebuildMenu{
 self.title=@"Number Ranges";
 NSArray *ranges=[MYBFWSettings() objectForKey:MYB_FW_KEY_RANGES];
 NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *r in ranges)
  [rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:[r objectForKey:@"prefix"],@"title",MYBFWActionName([r objectForKey:@"a"]),@"value",@"number",@"icon",[r objectForKey:@"prefix"],@"fwRange",@"edit",@"action",nil]];
 if(!rows.count)[rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"No ranges yet",@"title",@"Tap + to add one, e.g. +234 or +1900",@"detail",@"number.square",@"icon",nil]];
 self.menuSections=[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"",@"title",rows,@"rows",nil]];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=[[self.menuSections[(NSUInteger)p.section] objectForKey:@"rows"] objectAtIndex:(NSUInteger)p.row];
 if([row objectForKey:@"fwRange"]){[t deselectRowAtIndexPath:p animated:YES];[self chooseActionForRange:[row objectForKey:@"fwRange"]];return;}
 [super tableView:t didSelectRowAtIndexPath:p];
}
- (void)chooseActionForRange:(NSString *)prefix{
 NSArray *ranges=[MYBFWSettings() objectForKey:MYB_FW_KEY_RANGES];
 __weak typeof(self) weak=self;
 MYBFWChooseAction(self,prefix,@"Every number starting with this is handled this way.",NO,@"Remove This Range",
  ^(NSString *action){
   NSMutableArray *next=[NSMutableArray array];for(NSDictionary *r in ranges)if(![[r objectForKey:@"prefix"] isEqual:prefix])[next addObject:r];
   NSDictionary *updated=MYBFWValidRange(prefix,action);if(updated)[next addObject:updated];
   if(!MYBFWSaveRanges(next))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];},
  ^{MYBConfirmWithButton(weak,@"Remove this range?",@"Numbers in this range are no longer affected by it.",@"Remove",^{
    NSMutableArray *next=[NSMutableArray array];for(NSDictionary *r in ranges)if(![[r objectForKey:@"prefix"] isEqual:prefix])[next addObject:r];
    if(!MYBFWSaveRanges(next))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];});});
}
- (void)askRange{
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Add a Range" message:@"Every number starting with this is handled the way you choose next. For example +234 for a whole country, or +1900 for a premium-rate block." preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.keyboardType=UIKeyboardTypePhonePad;field.placeholder=@"+234";field.autocorrectionType=UITextAutocorrectionTypeNo;}];
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 __weak UIAlertController *weak=alert;__weak typeof(self) weakSelf=self;
 [alert addAction:[UIAlertAction actionWithTitle:@"Next" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){(void)a;
  NSString *norm=MYBFWNormalizedPrefix(weak.textFields.firstObject.text);
  if(!norm||norm.length<2){MYBComplete(weakSelf,NO,@"Not a usable prefix",@"Type at least a country code, such as +234.");return;}
  [weakSelf chooseActionForRange:norm];
 }]];
 [self presentViewController:alert animated:YES completion:nil];
}
@end

// ---- Blocked Senders (its own page, same shape as Numbers above) ----------------------------------------------------------------------------
@interface MYBMFSendersController : MYBMenuBase @property(nonatomic,strong) MYBFWContactDelegate *pickerDelegate; @end
@implementation MYBMFSendersController
- (NSString *)heroTitle{return @"Blocked Senders";}
- (NSString *)heroDetail{return @"A phone number or an iMessage/email handle. Texts from an exact match never arrive -- no notification, no badge, nothing to see later.";}
- (void)viewDidLoad{
 [super viewDidLoad];
 UIButton *plus=[UIButton buttonWithType:UIButtonTypeSystem];
 [plus setImage:[UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
 plus.tintColor=MYBAccent();plus.frame=CGRectMake(0,0,44,44);[plus addTarget:self action:@selector(addSender) forControlEvents:UIControlEventTouchUpInside];
 plus.accessibilityLabel=@"Add a blocked sender";self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:plus];
}
- (void)rebuildMenu{
 self.title=@"Blocked Senders";
 NSArray *entries=MYBMFEffective(MYBMessageFirewallFile(),MYB_MF_KEY_SENDERS);
 NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *entry in entries){
  NSString *key=[entry objectForKey:@"k"];
  NSString *shown=[key hasPrefix:@"h:"]?([entry objectForKey:@"d"] ?: MYBMFDisplaySender(key,MYBFWRegionNow())):MYBPCLabelWithNumber(entry,MYBPCContactName(key),MYBFWRegionNow());
  [rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:shown,@"title",@"Blocked",@"value",[key hasPrefix:@"h:"]?@"at":@"phone.fill",@"icon",key,@"mfKey",@"edit",@"action",nil]];
 }
 if(!rows.count)[rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"No senders yet",@"title",@"Tap + to add one",@"detail",@"message.badge.filled.fill",@"icon",nil]];
 self.menuSections=[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"",@"title",rows,@"rows",
  @"Only iMessage and SMS text content is affected, never phone calls, FaceTime or other apps.",@"footer",nil]];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=[[self.menuSections[(NSUInteger)p.section] objectForKey:@"rows"] objectAtIndex:(NSUInteger)p.row];
 NSString *key=[row objectForKey:@"mfKey"];
 if(key.length){
  [t deselectRowAtIndexPath:p animated:YES];
  __weak typeof(self) weak=self;
  MYBConfirmWithButton(self,@"Remove this sender?",@"Their texts go through normally again.",@"Remove",^{
   if(!MYBMFSaveSender(key,[row objectForKey:@"title"],NO))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];});
  return;
 }
 [super tableView:t didSelectRowAtIndexPath:p];
}
- (BOOL)addRaw:(NSString *)raw name:(NSString *)name quiet:(BOOL)quiet{
 if(MYBPCIsProtectedNumber(raw)){if(!quiet)MYBComplete(self,NO,@"Not allowed",@"Emergency numbers can’t be added.");return NO;}
 NSString *key=MYBMFSenderKey(raw,MYBFWRegionNow());
 if(!key){if(!quiet)MYBComplete(self,NO,@"Not usable",@"Type a phone number, or an iMessage/email handle.");return NO;}
 NSString *label=MYBPCNameOnly(name)?:([key hasPrefix:@"h:"]?[raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]:(MYBPCContactName(key)?:MYBPCFormat(key,MYBFWRegionNow())));
 if(!MYBMFSaveSender(key,label,YES)){if(!quiet)MYBComplete(self,NO,@"Couldn’t save",@"Nothing was changed.");return NO;}
 return YES;
}
- (void)addSender{
 __weak typeof(self) weak=self;
 MYBShieldChoice(self,@"Block a Sender",nil,[NSArray array],@"message.badge.filled.fill",1,[NSArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"Type a Number or Handle",@"title",@"primary",@"style",^{[weak askSender];},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Choose from Contacts",@"title",@"secondary",@"style",^{[weak pickContacts];},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Cancel",@"title",@"cancel",@"style",nil],nil]);
}
- (void)askSender{
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Block a Sender" message:@"A phone number the way it shows when they text, or an iMessage/email handle." preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"Number or handle";field.autocorrectionType=UITextAutocorrectionTypeNo;field.keyboardType=UIKeyboardTypeEmailAddress;}];
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 __weak UIAlertController *weak=alert;__weak typeof(self) weakSelf=self;
 [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){(void)a;
  [weakSelf addRaw:weak.textFields.firstObject.text name:nil quiet:NO];[weakSelf rebuildMenu];}]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (void)pickContacts{
 CNContactPickerViewController *picker=[CNContactPickerViewController new];
 picker.displayedPropertyKeys=[NSArray arrayWithObject:CNContactPhoneNumbersKey];
 self.pickerDelegate=[MYBFWContactDelegate new];
 __weak typeof(self) weak=self;
 self.pickerDelegate.done=^(NSArray<NSDictionary *> *numbers){
  NSInteger added=0,refused=0;for(NSDictionary *n in numbers){if([weak addRaw:[n objectForKey:@"number"] name:[n objectForKey:@"name"] quiet:YES])added++;else refused++;}
  [weak rebuildMenu];
  if(added||refused)MYBComplete(weak,added>0,added?@"Added":@"Not added",[NSString stringWithFormat:@"%ld number%@ added.%@",(long)added,added==1?@"":@"s",refused?[NSString stringWithFormat:@" %ld could not be read as a phone number.",(long)refused]:@""]);
 };
 picker.delegate=self.pickerDelegate;
 [self presentViewController:picker animated:YES completion:nil];
}
@end

// ---- Keyword Auto-Delete (its own page) ------------------------------------------------------------------------------------------------------
@interface MYBMFKeywordsController : MYBMenuBase @end
@implementation MYBMFKeywordsController
- (NSString *)heroTitle{return @"Keyword Auto-Delete";}
- (NSString *)heroDetail{return @"A text whose message body contains any word or phrase below never arrives, from anyone. Not case-sensitive, and matches anywhere in the message.";}
- (void)viewDidLoad{
 [super viewDidLoad];
 UIButton *plus=[UIButton buttonWithType:UIButtonTypeSystem];
 [plus setImage:[UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
 plus.tintColor=MYBAccent();plus.frame=CGRectMake(0,0,44,44);[plus addTarget:self action:@selector(askKeyword) forControlEvents:UIControlEventTouchUpInside];
 plus.accessibilityLabel=@"Add a keyword";self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:plus];
}
- (void)rebuildMenu{
 self.title=@"Keyword Auto-Delete";
 NSArray *entries=MYBMFEffective(MYBMessageFirewallFile(),MYB_MF_KEY_KEYWORDS);
 NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *entry in entries){
  NSString *key=[entry objectForKey:@"k"];
  [rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:[entry objectForKey:@"d"] ?: key,@"title",@"text.badge.xmark",@"icon",key,@"mfKeyword",@"edit",@"action",nil]];
 }
 if(!rows.count)[rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"No keywords yet",@"title",@"Tap + to add one",@"detail",@"text.badge.plus",@"icon",nil]];
 self.menuSections=[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"",@"title",rows,@"rows",
  @"Checked against the plain text of the message only, never the sender. Up to 200 keywords.",@"footer",nil]];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=[[self.menuSections[(NSUInteger)p.section] objectForKey:@"rows"] objectAtIndex:(NSUInteger)p.row];
 NSString *key=[row objectForKey:@"mfKeyword"];
 if(key.length){
  [t deselectRowAtIndexPath:p animated:YES];
  __weak typeof(self) weak=self;
  MYBConfirmWithButton(self,@"Remove this keyword?",@"Messages containing it will start arriving normally again.",@"Remove",^{
   if(!MYBMFSaveKeyword(key,[row objectForKey:@"title"],NO))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];});
  return;
 }
 [super tableView:t didSelectRowAtIndexPath:p];
}
- (void)askKeyword{
 if(MYBMFEffective(MYBMessageFirewallFile(),MYB_MF_KEY_KEYWORDS).count>=MYB_MF_MAX_KEYWORDS){MYBComplete(self,NO,@"Limit reached",@"Remove one before adding another.");return;}
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Add a Keyword" message:@"A word or short phrase. Any text that contains it, anywhere, is deleted before it arrives." preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"Word or phrase";field.autocorrectionType=UITextAutocorrectionTypeNo;}];
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 __weak UIAlertController *weak=alert;__weak typeof(self) weakSelf=self;
 [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){(void)a;
  NSString *raw=weak.textFields.firstObject.text;
  NSString *key=MYBMFKeywordKey(raw);
  if(!key){MYBComplete(weakSelf,NO,@"Not usable",@"Type at least one word.");return;}
  if(!MYBMFSaveKeyword(key,[raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],YES))MYBComplete(weakSelf,NO,@"Couldn’t save",@"Nothing was changed.");
  [weakSelf rebuildMenu];
 }]];
 [self presentViewController:alert animated:YES completion:nil];
}
@end

// ---- Known Scam Patterns (its own page) -- Mikey's own 54-rule bundled scam detector, three switches, one per category -------------------------
@interface MYBMFPatternsController : MYBMenuBase @end
@implementation MYBMFPatternsController
- (NSString *)heroTitle{return @"Known Scam Patterns";}
- (NSString *)heroDetail{return @"A 54-rule scam detector covering phishing, fake bank/delivery alerts, and gift-card and crypto scams in English, Spanish and more. Scam messages are blocked by default; order confirmations and marketing texts are left alone unless you turn them on.";}
- (BOOL)flag:(NSString *)key defaultValue:(BOOL)def{return MYBMFPatternCategoryOn(MYBMessageFirewallFile(),key,def);}
- (void)rebuildMenu{
 self.title=@"Known Scam Patterns";
 NSArray *rows=[NSArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"Scam Messages",@"title",@"Phishing, fake bank/Apple/USPS alerts, gift-card and crypto scams",@"detail",@"exclamationmark.shield.fill",@"icon",@YES,@"accent",[NSNumber numberWithInteger:MYBToneRose],@"tone",MYB_MF_KEY_PATTERNS_JUNK,@"switch",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Order & Shipping Confirmations",@"title",@"Off by default, so a real order or statement text is never deleted",@"detail",@"shippingbox.fill",@"icon",@YES,@"accent",[NSNumber numberWithInteger:MYBToneBlue],@"tone",MYB_MF_KEY_PATTERNS_TRANSACTION,@"switch",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Promotional Texts",@"title",@"Opt-in marketing with “reply STOP” language",@"detail",@"tag.fill",@"icon",@YES,@"accent",[NSNumber numberWithInteger:MYBToneViolet],@"tone",MYB_MF_KEY_PATTERNS_PROMOTION,@"switch",nil],nil];
 self.menuSections=[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"",@"title",rows,@"rows",
  @"Checked against the plain text of the message only, never the sender. A match is deleted before it arrives -- no notification, no badge.",@"footer",nil]];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=[[self.menuSections[(NSUInteger)p.section] objectForKey:@"rows"] objectAtIndex:(NSUInteger)p.row];
 NSString *key=[row objectForKey:@"switch"];
 MYBPrismCell *cell=[self cardForEntry:row table:t];
 if(key.length){
  BOOL def=[key isEqualToString:MYB_MF_KEY_PATTERNS_JUNK];
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.onTintColor=MYBAccent();toggle.on=[self flag:key defaultValue:def];
  [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
  cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];
 }
 return cell;
}
- (void)toggled:(MYBPrismSwitch *)toggle{
 if(!MYBMFSavePatternCategory(toggle.key,toggle.on)){
  [toggle setOn:!toggle.on animated:YES];MYBComplete(self,NO,@"Couldn’t save",@"Your previous setting is kept.");return;
 }
 [self rebuildMenu];
}
@end

// ---- Overview (the only screen most people ever open) ----------------------------------------------------------------------------------------
@interface MYBFirewallController : MYBTileListBase @end
@implementation MYBFirewallController
- (NSString *)heroTitle{return @"Protection Center";}
- (NSString *)heroDetail{return [NSString stringWithFormat:@"Call Firewall and Message Firewall, together. %ld of %ld protections are on right now.",(long)self.protectionsOnCount,(long)self.protectionsTotalCount];}
- (NSString *)heroSymbol{return @"shield.lefthalf.filled";}
- (MYBTone)heroTone{return MYBToneGreen;}
// Two real, all-time counters (Shared/MYBProtectionStats.h -- bumped once per call/message actually blocked, read
// back here over the same sandbox-safe mailbox the rest of the call service's diagnostics already use) plus a
// protection score: how many of the protections below are actually switched on right now, out of how many exist.
// No fabricated numbers: a protection that has never blocked anything shows 0, honestly, until it has.
- (NSArray<NSDictionary *> *)tileSpecs{
 return @[
  @{@"label":@"Calls Blocked",@"tone":@(MYBToneRose),@"symbol":@"phone.down.fill"},
  @{@"label":@"Texts Blocked",@"tone":@(MYBToneBlue),@"symbol":@"message.badge.filled.fill"},
  @{@"label":@"Protections On",@"tone":@(MYBToneGreen),@"symbol":@"checkmark.shield.fill"},
 ];
}
// How many of the protections below are switched on right now, out of how many exist -- the number a tile can show
// (MYBCountUp only ever animates a plain integer; "out of N" lives in the hero detail text instead, not the tile).
- (NSInteger)protectionsOnCount{
 NSDictionary *settings=MYBFWSettings();
 NSArray *onKeys=@[MYB_FW_KEY_SWITCH,MYB_FW_KEY_ALLOWLIST,MYB_FW_KEY_INTL_BLOCK,MYB_FW_KEY_JUNKCALLERS_ON];
 NSInteger on=0;for(NSString *k in onKeys)if([[settings objectForKey:k] boolValue])on++;
 if(MYBMFSwitchOn(MYBMessageFirewallFile()))on++;
 if(MYBMFPatternCategoryOn(MYBMessageFirewallFile(),MYB_MF_KEY_PATTERNS_JUNK,YES))on++;
 return on;
}
- (NSInteger)protectionsTotalCount{return 6;}
- (NSArray<NSString *> *)tileValueTexts{
 return @[
  [NSString stringWithFormat:@"%llu",(unsigned long long)MYBPSCallsBlocked()],
  [NSString stringWithFormat:@"%llu",(unsigned long long)MYBPSMessagesBlocked()],
  [NSString stringWithFormat:@"%ld",(long)self.protectionsOnCount],
 ];
}
- (void)tapTile:(NSInteger)index{(void)index;}
- (BOOL)flag:(NSString *)key{
 if([key isEqualToString:MYB_MF_KEY_SWITCH])return MYBMFSwitchOn(MYBMessageFirewallFile());
 return [[MYBFWSettings() objectForKey:key] boolValue];
}
- (void)rebuildMenu{
 self.title=@"Protection Center";
 NSDictionary *settings=MYBFWSettings();
 BOOL allowList=[[settings objectForKey:MYB_FW_KEY_ALLOWLIST] boolValue];
 BOOL intlOn=[[settings objectForKey:MYB_FW_KEY_INTL_BLOCK] boolValue];
 NSString *unknownAction=[settings objectForKey:MYB_FW_KEY_UNKNOWN_ACTION];
 NSUInteger numbers=MYBFWEntries(MYBFirewallFile()).count,ranges=[[settings objectForKey:MYB_FW_KEY_RANGES] count];
 NSUInteger senders=MYBMFEffective(MYBMessageFirewallFile(),MYB_MF_KEY_SENDERS).count,keywords=MYBMFEffective(MYBMessageFirewallFile(),MYB_MF_KEY_KEYWORDS).count;

 NSMutableArray *topRows=[NSMutableArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"Call Firewall",@"title",@"Turns every rule on this screen on or off at once",@"detail",@"shield.lefthalf.filled",@"icon",@YES,@"accent",[NSNumber numberWithInteger:MYBToneGreen],@"tone",MYB_FW_KEY_SWITCH,@"switch",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Allow List Mode",@"title",allowList?@"Only your own numbers ring":@"Off: the rules below apply on their own",@"detail",@"checklist",@"icon",@YES,@"accent",[NSNumber numberWithInteger:MYBToneViolet],@"tone",MYB_FW_KEY_ALLOWLIST,@"switch",nil],nil];
 if(allowList)[topRows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Everyone Else",@"title",MYBFWActionName([settings objectForKey:MYB_FW_KEY_DEFAULT_ACTION]),@"value",@"person.fill.questionmark",@"icon",@"chooseDefault",@"action",nil]];

 NSMutableArray *ruleRows=[NSMutableArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"Numbers",@"title",numbers?[NSString stringWithFormat:@"%lu added",(unsigned long)numbers]:@"None yet",@"detail",@"phone.fill",@"icon",@"MYBFWNumbersController",@"page",@"openPage",@"action",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"No Caller ID",@"title",unknownAction.length?MYBFWActionName(unknownAction):@"No rule",@"value",@"questionmark.circle",@"icon",@"chooseUnknown",@"action",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Block International Numbers",@"title",@"Any number whose country code is not your own",@"detail",@"globe",@"icon",@YES,@"accent",[NSNumber numberWithInteger:MYBToneBlue],@"tone",MYB_FW_KEY_INTL_BLOCK,@"switch",nil],nil];
 if(intlOn)[ruleRows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"International Action",@"title",MYBFWActionName([settings objectForKey:MYB_FW_KEY_INTL_ACTION]),@"value",@"globe.badge.chevron.backward",@"icon",@"chooseIntl",@"action",nil]];
 [ruleRows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Number Ranges",@"title",ranges?[NSString stringWithFormat:@"%lu added",(unsigned long)ranges]:@"None yet",@"detail",@"number.square",@"icon",@"MYBFWRangesController",@"page",@"openPage",@"action",nil]];
 BOOL junkCallersOn=[[settings objectForKey:MYB_FW_KEY_JUNKCALLERS_ON] boolValue];
 [ruleRows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Known Junk Callers",@"title",@"Mikey's own 1.1M-number international spam-caller list",@"detail",@"phone.down.fill",@"icon",@YES,@"accent",[NSNumber numberWithInteger:MYBToneRose],@"tone",MYB_FW_KEY_JUNKCALLERS_ON,@"switch",nil]];
 if(junkCallersOn)[ruleRows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Known Junk Callers Action",@"title",MYBFWActionName([settings objectForKey:MYB_FW_KEY_JUNKCALLERS_ACTION]),@"value",@"phone.down.circle",@"icon",@"chooseJunkCallers",@"action",nil]];

 BOOL patternsJunkOn=MYBMFPatternCategoryOn(MYBMessageFirewallFile(),MYB_MF_KEY_PATTERNS_JUNK,YES);
 NSMutableArray *messageRows=[NSMutableArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"Message Firewall",@"title",@"Turns sender blocking, keyword auto-delete and scam patterns on or off at once",@"detail",@"message.badge.filled.fill",@"icon",@YES,@"accent",[NSNumber numberWithInteger:MYBToneGreen],@"tone",MYB_MF_KEY_SWITCH,@"switch",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Blocked Senders",@"title",senders?[NSString stringWithFormat:@"%lu added",(unsigned long)senders]:@"None yet",@"detail",@"person.crop.circle.badge.xmark",@"icon",@"MYBMFSendersController",@"page",@"openPage",@"action",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Keyword Auto-Delete",@"title",keywords?[NSString stringWithFormat:@"%lu added",(unsigned long)keywords]:@"None yet",@"detail",@"text.badge.xmark",@"icon",@"MYBMFKeywordsController",@"page",@"openPage",@"action",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Known Scam Patterns",@"title",patternsJunkOn?@"Scam detector on":@"Off",@"detail",@"exclamationmark.shield.fill",@"icon",@"MYBMFPatternsController",@"page",@"openPage",@"action",nil],nil];
 [messageRows addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Copy Message Firewall Diagnostics",@"title",@"Whether the message hook is actually installed, and what it has seen. Class and counter names only -- no messages, numbers or contacts.",@"detail",@"doc.on.doc",@"icon",@"copyMessageFirewallDiagnostics",@"action",nil]];

 self.menuSections=[NSArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"CALLS",@"title",topRows,@"rows",
   @"Mute silences the ringer, Decline rejects at once, Hang up answers and ends immediately.",@"footer",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"RULES",@"title",ruleRows,@"rows",
   @"Only ordinary phone calls are affected, never emergency calls or FaceTime. Known Junk Callers is checked last, after every rule above -- a number on your own Numbers list always wins.",@"footer",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"MESSAGES",@"title",messageRows,@"rows",
   @"Blocked texts never arrive at all -- no notification, no badge, nothing left to see later. Only iMessage and SMS content is affected.",@"footer",nil],nil];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];[self updateTiles];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=[[self.menuSections[(NSUInteger)p.section] objectForKey:@"rows"] objectAtIndex:(NSUInteger)p.row];
 NSString *key=[row objectForKey:@"switch"];
 MYBPrismCell *cell=[self cardForEntry:row table:t];
 if(key.length){
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.onTintColor=MYBAccent();toggle.on=[self flag:key];
  [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
  cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];
 }
 return cell;
}
- (void)toggled:(MYBPrismSwitch *)toggle{
 BOOL ok=[toggle.key isEqualToString:MYB_MF_KEY_SWITCH]?MYBMFSaveSwitch(toggle.on):MYBFWSaveSettings([NSDictionary dictionaryWithObject:[NSNumber numberWithBool:toggle.on] forKey:toggle.key]);
 if(!ok){[toggle setOn:!toggle.on animated:YES];MYBComplete(self,NO,@"Couldn’t save",@"Your previous setting is kept.");return;}
 [self rebuildMenu];[self updateTiles];
}
// Answers the one question a plist can't: whether the message-blocking hook actually loaded into imagent and what it has seen since. The switch
// and both lists are read straight from the local settings file (no imagent round trip needed for those); the hook's own self-report
// (Shared/MYBMessageFirewallList.h's MYBMFHReadReport) is the only part that depends on imagent having a chance to speak at all.
- (void)copyMessageFirewallDiagnostics{
 NSMutableDictionary *status=[NSMutableDictionary dictionary];
 status[@"messageFirewallSwitch"]=@(MYBMFSwitchOn(MYBMessageFirewallFile()));
 status[@"blockedSendersCount"]=@(MYBMFEffective(MYBMessageFirewallFile(),MYB_MF_KEY_SENDERS).count);
 status[@"blockedKeywordsCount"]=@(MYBMFEffective(MYBMessageFirewallFile(),MYB_MF_KEY_KEYWORDS).count);
 status[@"scamPatternsOn"]=@(MYBMFPatternCategoryOn(MYBMessageFirewallFile(),MYB_MF_KEY_PATTERNS_JUNK,YES));
 status[@"messagesBlockedAllTime"]=@(MYBPSMessagesBlocked());
 NSString *report=MYBMFHReadReport();
 if(report.length){
  // Report() published Counters.description -- an NSDictionary printout, one "key = value;" entry per line, braces on their own lines. Parsed
  // defensively rather than assumed exact, since this is debug output, not a wire format anything else depends on.
  NSMutableDictionary *parsed=[NSMutableDictionary dictionary];
  NSCharacterSet *trim=[NSCharacterSet characterSetWithCharactersInString:@"{}\" \t"];
  for(NSString *line in [report componentsSeparatedByString:@";"]){
   NSRange eq=[line rangeOfString:@"="];
   if(eq.location==NSNotFound)continue;
   NSString *key=[[line substringToIndex:eq.location] stringByTrimmingCharactersInSet:trim];
   NSString *val=[[line substringFromIndex:eq.location+1] stringByTrimmingCharactersInSet:trim];
   if(key.length)parsed[key]=val;
  }
  status[@"hookReport"]=parsed.count?parsed:report;
 }else status[@"hookReport"]=@"never reported in -- the hook may not have loaded into imagent at all, or imagent has not restarted since install";
 NSData *json=[NSJSONSerialization dataWithJSONObject:status options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:NULL];
 NSString *text=json?[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]:nil;
 if(!text.length){MYBComplete(self,NO,@"Couldn’t Copy",@"Nothing was changed.");return;}
 UIPasteboard.generalPasteboard.string=text;
 MYBComplete(self,YES,@"Copied",@"Paste it into your message to MYXXdev™. It holds only class and counter names, no messages or numbers.");
}
- (void)chooseDefault{
 __weak typeof(self) weak=self;
 MYBFWChooseAction(self,@"Everyone Else",@"Applied to any call from a number not on your Numbers list, while Allow List Mode is on.",NO,nil,
  ^(NSString *action){if(!MYBFWSaveSettings([NSDictionary dictionaryWithObject:action forKey:MYB_FW_KEY_DEFAULT_ACTION]))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];},nil);
}
- (void)chooseUnknown{
 __weak typeof(self) weak=self;
 void(^save)(NSString *)=^(NSString *action){if(!MYBFWSaveSettings([NSDictionary dictionaryWithObject:action forKey:MYB_FW_KEY_UNKNOWN_ACTION]))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];};
 MYBShieldChoice(self,@"No Caller ID",@"Applied to a call that arrives with no number at all. Choose No Rule to leave it alone.",[NSArray array],@"questionmark.circle",1,[NSArray arrayWithObjects:
  [NSDictionary dictionaryWithObjectsAndKeys:@"Mute",@"title",@"primary",@"style",^{save(MYB_PC_ACTION_MUTE);},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Decline",@"title",@"secondary",@"style",^{save(MYB_PC_ACTION_DECLINE);},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Hang up",@"title",@"secondary",@"style",^{save(MYB_PC_ACTION_HANGUP);},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"No Rule",@"title",@"secondary",@"style",^{save(@"");},@"handler",nil],
  [NSDictionary dictionaryWithObjectsAndKeys:@"Cancel",@"title",@"cancel",@"style",nil],nil]);
}
- (void)chooseIntl{
 __weak typeof(self) weak=self;
 MYBFWChooseAction(self,@"International Action",@"Applied to a number whose country code is not your own, while Block International Numbers is on.",NO,nil,
  ^(NSString *action){if(!MYBFWSaveSettings([NSDictionary dictionaryWithObject:action forKey:MYB_FW_KEY_INTL_ACTION]))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];},nil);
}
- (void)chooseJunkCallers{
 __weak typeof(self) weak=self;
 MYBFWChooseAction(self,@"Known Junk Callers",@"Applied to any number on Mikey's own bundled spam-caller list, as long as that number isn't already on your own Numbers list or covered by a rule above.",NO,nil,
  ^(NSString *action){if(!MYBFWSaveSettings([NSDictionary dictionaryWithObject:action forKey:MYB_FW_KEY_JUNKCALLERS_ACTION]))MYBComplete(weak,NO,@"Couldn’t save",@"Your previous setting is kept.");[weak rebuildMenu];},nil);
}
@end
