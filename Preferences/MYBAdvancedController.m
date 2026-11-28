#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBTips.h"
#import "../Shared/MYBConnectivity.h"
#import "../Shared/MYBPrivateCallsStore.h"
#import "../Shared/MYBCallServiceChannel.h"
#import "../Shared/MYBCallServiceList.h"
#import "../Shared/MYBPCContacts.h"
#import <ContactsUI/ContactsUI.h>
#import <notify.h>
// Advanced: features most people never need, kept off the main page. Every switch is OFF until it is turned on here.
// Connectivity: Per-App Network Access and Keep Personal Hotspot Active. Extra Privacy Protection (Photos) has its own row on the main page.
static NSString *MYBConnFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.connectivity.plist");}
static NSString *MYBPrivFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.privacy.plist");}
static NSArray *MYBPCEffectiveNow(void);
static NSDictionary *MYBStatusAt(NSString *relative){return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(relative)];}
static NSString *MYBStatusAge(NSDictionary *status){
 double stamp=[status[@"time"] doubleValue];if(stamp<=0)return nil;
 NSTimeInterval age=NSDate.date.timeIntervalSince1970-stamp;
 if(age<90)return @"just now";if(age<3600)return [NSString stringWithFormat:@"%d min ago",(int)(age/60)];if(age<86400)return [NSString stringWithFormat:@"%d h ago",(int)(age/3600)];return @"over a day ago";
}
// Saves one switch and tells the tweak. NO means nothing changed and the caller must show the previous state.
static BOOL MYBSaveSwitch(NSString *file,NSString *key,BOOL on,const char *notification){
 int lock=MYBPCLockTake(file);   // the switch and the Private Calls list live in one file: never write them at the same time
 BOOL saved=MYBConnWriteFlag(file,key,on);MYBPCLockGive(lock);
 if(!saved)return NO;
 notify_post(notification);return YES;
}

@interface MYBAdvancedController : MYBMenuBase @end
@implementation MYBAdvancedController
- (NSString *)heroTitle{return @"Advanced";}
- (NSString *)heroDetail{return @"Optional tools. Everything here is off until you turn it on.";}
- (void)rebuildMenu{
 self.title=@"Advanced";
 self.menuSections=@[@{@"title":@"CONNECTIVITY",@"rows":@[
   @{@"title":@"Connectivity",@"detail":@"Per-app network access and Personal Hotspot",@"icon":@"antenna.radiowaves.left.and.right",@"page":@"MYBConnectivityController",@"action":@"openPage"}],
   @"footer":@"Both tools are off until you switch them on."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
@end

@interface MYBConnectivityController : MYBMenuBase @end
@implementation MYBConnectivityController
- (NSString *)heroTitle{return @"Connectivity";}
- (NSString *)heroDetail{return @"Per-app network access and Personal Hotspot.";}
- (BOOL)flag:(NSString *)key{return MYBConnFlagInFile(MYBConnFile(),key);}
- (NSString *)networkStatusLine{
 NSDictionary *status=MYBStatusAt(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.netaccess.status.plist");
 if(![self flag:MYB_CONN_KEY_NETWORK_MENU])return nil;
 if(!status)return @"Waiting for Settings to be opened once. Close and reopen the Settings app.";
 return [NSString stringWithFormat:@"Settings: %@",status[@"state"]?:@"unknown"];
}
- (NSString *)hotspotStatusLine{
 if(![self flag:MYB_CONN_KEY_HOTSPOT])return nil;
 NSDictionary *status=MYBStatusAt(@"/var/mobile/Library/MYbloXX/HotspotStatus.plist");
 if(!status)return @"No hotspot activity seen yet.";
 BOOL up=[status[@"hotspotUp"] boolValue],holding=[status[@"holding"] boolValue];NSInteger devices=[status[@"devices"] integerValue];
 NSString *age=MYBStatusAge(status);
 NSString *line=!up?@"Personal Hotspot is off":holding?[NSString stringWithFormat:@"Holding for %ld connected %@",(long)devices,devices==1?@"device":@"devices"]:devices<0?@"Hotspot on; connected devices could not be read":@"Hotspot on, waiting for a device";
 return age?[NSString stringWithFormat:@"%@ · %@",line,age]:line;
}
- (void)rebuildMenu{
 self.title=@"Connectivity";
 NSMutableArray *net=[NSMutableArray arrayWithObject:
  @{@"title":@"Per-App Network Access",@"detail":@"Shows the iPhone’s own Off / WLAN / WLAN & Cellular Data choice for each app in Settings",@"icon":@"antenna.radiowaves.left.and.right",@"accent":@YES,@"tone":@(MYBToneBlue),@"switch":MYB_CONN_KEY_NETWORK_MENU}];
 if([self flag:MYB_CONN_KEY_NETWORK_MENU]){
  [net addObject:@{@"title":@"Open Cellular Settings",@"detail":@"Opens the iPhone’s own cellular page, where each app has its network choice",@"icon":@"gearshape.fill",@"tone":@(MYBToneBlue),@"action":@"openCellular"}];
  NSString *line=[self networkStatusLine];if(line)[net addObject:@{@"title":@"Status",@"detail":line,@"icon":@"info.circle",@"tone":@(MYBToneSlate)}];
 }
 NSMutableArray *hot=[NSMutableArray arrayWithObject:
  @{@"title":@"Keep Personal Hotspot Active",@"detail":@"While a device is connected to your hotspot, keeps the hotspot’s network awake with the iPhone locked",@"icon":@"personalhotspot",@"accent":@YES,@"tone":@(MYBToneGreen),@"switch":MYB_CONN_KEY_HOTSPOT}];
 if([self flag:MYB_CONN_KEY_HOTSPOT]){
  NSString *line=[self hotspotStatusLine];if(line)[hot addObject:@{@"title":@"Status",@"detail":line,@"icon":@"info.circle",@"tone":@(MYBToneSlate)}];
 }
 self.menuSections=@[
  @{@"title":@"PER-APP NETWORK ACCESS",@"rows":net,@"footer":@"Uses the iPhone’s own controls, in the iPhone’s own wording. The only change MYbloXX® makes is to show them. Turning this off hides them again but does not undo a choice you made there."},
  @{@"title":@"PERSONAL HOTSPOT",@"rows":hot,@"footer":@"Does not turn Personal Hotspot on or off. It only acts while Personal Hotspot is on and a device is connected, and lets go as soon as the hotspot turns off, the last device leaves, or you switch this off. Normal sleep is not changed otherwise."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *key=row[@"switch"];
 MYBPrismCell *cell=[self cardForEntry:row table:t];
 if(key.length){
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.onTintColor=MYBAccent();toggle.on=[self flag:key];
  [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];
 }
 return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if([row[@"action"] isEqual:@"openCellular"]){[tableView deselectRowAtIndexPath:p animated:YES];[self openCellular];return;}
 [super tableView:tableView didSelectRowAtIndexPath:p];
}
- (void)openCellular{
 NSURL *url=[NSURL URLWithString:@"App-prefs:MOBILE_DATA_SETTINGS_ID"];
 [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL opened){
  if(!opened)dispatch_async(dispatch_get_main_queue(),^{[self showMessage:@"Couldn’t open Cellular settings" detail:@"Open the Settings app and tap Cellular (or Mobile Data) yourself."];});
 }];
}
- (void)toggleChanged:(MYBPrismSwitch *)toggle{
 NSString *key=toggle.key;if(!key.length)return;
 if([key isEqual:MYB_CONN_KEY_NETWORK_MENU]&&!toggle.on){
  // Hiding the menu does not remove restrictions iOS already stored. Say so, and offer the way to review them first.
  MYBShieldChoice(self,@"Hide Per-App Network Access?",@"Apps you set to Off or WLAN Only keep that restriction after the menu is hidden, and you will not be able to see or change it. Review them first if you are not sure.",nil,@"antenna.radiowaves.left.and.right",2,@[
   @{@"title":@"Review in Settings",@"style":@"primary",@"handler":^{[self rebuildMenu];[self openCellular];}},
   @{@"title":@"Turn Off Anyway",@"style":@"destructive",@"handler":^{[self commit:key on:NO];}},
   @{@"title":@"Cancel",@"style":@"cancel",@"handler":^{[self rebuildMenu];}}]);return;
 }
 [self commit:key on:toggle.on];
}
- (void)commit:(NSString *)key on:(BOOL)on{
 if(!MYBSaveSwitch(MYBConnFile(),key,on,MYB_CONN_NOTIFY))MYBComplete(self,NO,@"Couldn’t save",@"Your previous setting is kept.");
 [self rebuildMenu];
 if(on&&[key isEqual:MYB_CONN_KEY_NETWORK_MENU])[self showMessage:@"Close and reopen Settings" detail:@"Swipe the Settings app away and open it again. The new choices appear under Cellular, then each app."];
}
@end

@interface MYBPrivateItemsController : MYBMenuBase @end
@implementation MYBPrivateItemsController
- (NSString *)heroTitle{return @"Private Items";}
- (NSString *)heroDetail{return @"Private Album, Recently Deleted and Private Conversations. Every switch is off until you turn it on.";}
- (BOOL)flag:(NSString *)key{return MYBConnFlagInFile(MYBPrivFile(),key);}
// Counts only, published by the Messages component. Nothing else about a conversation is ever stored or shown here.
- (NSDictionary *)messagesStatus{
 id value=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("MYBPMStatus"),CFSTR("com.apple.MobileSMS")));
 return [value isKindOfClass:NSDictionary.class]?value:@{};
}
- (void)rebuildMenu{
 self.title=@"Private Items";
 NSDictionary *status=[self messagesStatus];
 NSInteger held=[status[@"alertsHeld"] integerValue],count=[status[@"private"] integerValue];
 NSMutableArray *messages=[NSMutableArray arrayWithArray:@[
  @{@"title":@"Private Conversations",@"detail":@"In Messages, tap the Messages title five times to open them",@"icon":@"text.bubble.fill",@"accent":@YES,@"tone":@(MYBToneViolet),@"switch":MYB_PRIV_KEY_MESSAGES},
  @{@"title":@"Lock with Face ID or Passcode",@"detail":@"Ask before the private list opens",@"icon":@"faceid",@"switch":MYB_PRIV_KEY_MESSAGES_LOCK}]];
 if(status.count)[messages addObject:@{@"title":@"Private conversations",@"value":[NSString stringWithFormat:@"%ld",(long)count],@"icon":@"lock.fill"}];
 if(held>0)[messages addObject:@{@"title":@"Restore Alerts Now",@"detail":@"Opens Messages and puts Hide Alerts back to what it was",@"icon":@"bell.badge.fill",@"action":@"restoreAlerts"}];
 if(status.count)[messages addObject:@{@"title":@"Menu hooks found",@"value":[NSString stringWithFormat:@"%ld",(long)[status[@"stockMute"] integerValue]],@"icon":@"point.3.connected.trianglepath.dotted"}];
 [messages addObject:@{@"title":@"Copy Messages Diagnostics",@"detail":@"Copies class and menu names only. No messages, names or numbers.",@"icon":@"doc.on.doc",@"action":@"copyDiagnostics"}];
 [messages addObject:@{@"title":@"Show Tip Again",@"detail":@"Replays the Private Conversations tip in Messages",@"icon":@"lightbulb.fill",@"action":@"replayTips"}];
 self.menuSections=@[
  @{@"title":@"RECENTLY DELETED",@"rows":@[
    @{@"title":@"Recently Deleted Privacy",@"detail":@"In Photos, hold Recently Deleted for 3 seconds to hide or show what is inside",@"icon":@"trash.slash.fill",@"accent":@YES,@"tone":@(MYBToneRose),@"switch":MYB_PRIV_KEY_DELETED},
    @{@"title":@"Ask Before Showing",@"detail":@"Face ID or passcode before Recently Deleted is shown again",@"icon":@"faceid",@"switch":MYB_PRIV_KEY_DELETED_LOCK}],
   @"footer":@"Nothing is deleted. Hidden photos stay in Recently Deleted and come back when you hold it again. Turning this off shows them normally."},
  @{@"title":@"PRIVATE ALBUM",@"rows":@[
    @{@"title":@"Private Album",@"detail":@"In Photos, tap Albums five times to open it",@"icon":@"lock.rectangle.stack.fill",@"accent":@YES,@"tone":@(MYBToneViolet),@"switch":MYB_PRIV_KEY_ALBUM},
    @{@"title":@"Lock with Face ID or Passcode",@"detail":@"Ask before the Private Album opens",@"icon":@"faceid",@"switch":MYB_PRIV_KEY_ALBUM_LOCK}],
   @"footer":@"Private Album keeps its own copies outside your Photos library and closes when Photos leaves the screen. Move copies first and removes the original only after the copy is checked. If anything fails the original stays in Photos. Export as ZIP (in the Private Album) copies items out for the share sheet and leaves your private copies in place. Turning this off, updating or removing MYbloXX® never deletes your private items."},
  @{@"title":@"PRIVATE CONVERSATIONS",@"rows":messages,
   @"footer":@"Conversations stay in Apple Messages and are only hidden while MYbloXX® is active, so they show normally if the jailbreak or MYbloXX® is not running. Alerts are silenced with Messages' own Hide Alerts, set back to what it was when you return a conversation. In Spotlight search they are hidden on screen as far as this iOS version allows, which is still being verified. Siri suggestions, the search index itself, Apple Watch, Mac and iPad alerts are not covered. Turning this off shows every conversation again. Tap Restore Alerts Now before you remove MYbloXX®, or those conversations stay muted."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *key=row[@"switch"];
 MYBPrismCell *cell=[self cardForEntry:row table:t];
 if(key.length){
  MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.onTintColor=MYBAccent();toggle.on=[self flag:key];
  [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];
 }
 return cell;
}
- (void)saveKey:(NSString *)key on:(BOOL)on{
 if(!MYBSaveSwitch(MYBPrivFile(),key,on,MYB_PRIV_NOTIFY))MYBComplete(self,NO,@"Couldn’t save",@"Your previous setting is kept.");
 MYBCSLPublish(MYBPrivFile());
 [self rebuildMenu];
}
// Asks Messages (the only process that can) to put Hide Alerts back. The request is a number that changes each time; Messages remembers the last one it handled.
- (void)requestRestore{
 NSString *file=MYBPrivFile();
 NSMutableDictionary *prefs=[[NSDictionary dictionaryWithContentsOfFile:file] mutableCopy]?:[NSMutableDictionary dictionary];
 prefs[MYB_PRIV_KEY_MESSAGES_RESTORE]=@((long long)NSDate.date.timeIntervalSince1970);
 if(![prefs writeToFile:file atomically:YES]){MYBComplete(self,NO,@"Couldn’t ask Messages",@"Nothing was changed.");return;}
 notify_post(MYB_PRIV_NOTIFY);
 [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"sms:"] options:@{} completionHandler:nil];
}
- (void)restoreAlerts{
 MYBConfirmWithButton(self,@"Restore Alerts?",@"Messages opens and every private conversation goes back to the Hide Alerts setting it had before. They return to the ordinary list too.",@"Restore Alerts",^{[self requestRestore];});
}
- (void)copyDiagnostics{
 NSMutableDictionary *status=[[self messagesStatus] mutableCopy]?:[NSMutableDictionary dictionary];
 NSDictionary *spot=[NSDictionary dictionaryWithContentsOfFile:MYBRuleFile(@"var/mobile/Library/MYbloXX/PrivateSpotlightProbe.plist")];
 if(spot.count)status[@"spotlight"]=spot;
 if(!status.count){MYBComplete(self,NO,@"Nothing to Copy Yet",@"Open Messages once with Private Conversations switched on, then come back.");return;}
 NSData *json=[NSJSONSerialization dataWithJSONObject:status options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:NULL];
 NSString *text=json?[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]:nil;
 if(!text.length){MYBComplete(self,NO,@"Couldn’t Copy",@"Nothing was changed.");return;}
 UIPasteboard.generalPasteboard.string=text;
 MYBComplete(self,YES,@"Copied",@"Paste it into your message to MYXXdev™. It holds only class and menu names.");
}
- (void)replayTips{
 if(MYBTipsReplay())MYBComplete(self,YES,@"Tip Replays in Messages",@"The Private Conversations tip appears the next time you open Messages.");
 else MYBComplete(self,NO,@"Couldn’t Replay the Tip",@"Nothing was changed.");
}
- (void)toggleChanged:(MYBPrismSwitch *)toggle{
 NSString *key=toggle.key;if(!key.length)return;
 NSDictionary *status=[self messagesStatus];
 if([key isEqual:MYB_PRIV_KEY_MESSAGES]&&!toggle.on&&([status[@"private"] integerValue]>0)){
  // Visibility comes back by itself. Hide Alerts does not: only Messages can change it, so offer to do it now.
  MYBShieldChoice(self,@"Turn Off Private Conversations?",@"Every conversation shows in Messages again. Their alerts stay hidden until they are restored, and only Messages can do that.",nil,@"text.bubble.fill",2,@[
   @{@"title":@"Turn Off and Restore Alerts",@"style":@"primary",@"handler":^{[self saveKey:key on:NO];[self requestRestore];}},
   @{@"title":@"Turn Off Only",@"style":@"secondary",@"handler":^{[self saveKey:key on:NO];}},
   @{@"title":@"Cancel",@"style":@"cancel",@"handler":^{[self rebuildMenu];}}]);
  return;
 }
 [self saveKey:key on:toggle.on];
}
@end


// ---- Private Calls: the numbers --------------------------------------------------------------------------------------------------------------
// ONE store: PrivateCallsLog in the privacy preference file, changed only through MYBPCStoreMutate (Shared/MYBPrivateCallsStore.h). Phone and the
// incoming-call component read the same file; Phone's own requests and the r18 Phone list are merged in by the root helper ("pcapply").
static NSArray *MYBPCEffectiveNow(void){return MYBPCEffective(MYBPCStoreLog(MYBPrivFile()),nil);}
static BOOL MYBPCWrite(NSString *key,NSString *display,NSString *action,BOOL on){
 if(!MYBPCStoreSet(MYBPrivFile(),key,display,action,on,NSDate.date.timeIntervalSince1970,NULL))return NO;   // read back inside: only a verified write counts
 notify_post(MYB_PRIV_NOTIFY);
 MYBCSLPublish(MYBPrivFile());   // the call service gets the new list at once
 return YES;
}
static NSString *MYBPCRegionNow(void){return [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];}

@interface MYBPCContactDelegate : NSObject <CNContactPickerDelegate>
@property(nonatomic,copy) void (^done)(NSArray<NSDictionary *> *numbers);
@end
@implementation MYBPCContactDelegate
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)property{   // tapping a number adds it
 (void)picker;id value=property.value;
 NSString *name=[CNContactFormatter stringFromContact:property.contact style:CNContactFormatterStyleFullName]?:@"";
 if(self.done)self.done([value isKindOfClass:CNPhoneNumber.class]?[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:[(CNPhoneNumber *)value stringValue],@"number",name,@"name",nil]]:[NSArray array]);
}
@end

@interface MYBPrivateCallsController : MYBMenuBase @property(nonatomic,strong) MYBPCContactDelegate *pickerDelegate; @end
@implementation MYBPrivateCallsController
- (NSString *)heroTitle{return @"Private Numbers";}
- (NSString *)heroDetail{return @"Calls from these numbers leave Recents and open in Private Recents. Choose what happens when one rings.";}
- (NSDictionary *)phoneStatus{
 id value=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("MYBPCStatus"),CFSTR("com.apple.mobilephone")));
 return [value isKindOfClass:NSDictionary.class]?value:@{};
}
- (NSDictionary *)callStatus{
 id value=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("MYBPCCallStatus"),CFSTR("com.apple.InCallService")));
 return [value isKindOfClass:NSDictionary.class]?value:@{};
}
- (void)rebuildMenu{
 self.title=@"Private Numbers";
 NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *entry in MYBPCEffectiveNow())
  [rows addObject:@{@"title":MYBPCLabelWithNumber(entry,MYBPCContactName(entry[@"k"]),MYBPCRegionNow()),@"value":MYBPCActionName(entry[@"a"]),@"icon":@"phone.fill",@"pcKey":entry[@"k"],@"action":@"editNumber"}];
 if(!rows.count)[rows addObject:@{@"title":@"No private numbers yet",@"detail":@"Add one below, or press and hold a call in Phone → Recents.",@"icon":@"phone.badge.plus"}];
 NSMutableArray *add=[NSMutableArray arrayWithArray:@[
  @{@"title":@"Add a Number",@"detail":@"Type it with its country code",@"icon":@"plus.circle.fill",@"action":@"askNumber"},
  @{@"title":@"Choose from Contacts",@"detail":@"Tap one of a contact’s numbers",@"icon":@"person.crop.circle.badge.plus",@"action":@"pickContacts"}]];
 NSDictionary *phone=[self phoneStatus],*call=[self callStatus];
 NSMutableArray *help=[NSMutableArray array];
 if(phone.count||call.count)[help addObject:@{@"title":@"Copy Calls Diagnostics",@"detail":@"Copies class names and counts only. No numbers or names.",@"icon":@"doc.on.doc",@"action":@"copyDiagnostics"}];
 self.menuSections=@[
  @{@"title":@"NUMBERS",@"rows":rows,@"footer":@"Mute lets the call ring for the caller while your phone shows and plays nothing. Decline rejects the call the moment it rings and the caller goes to voicemail. Hang up picks the call up and ends it at once, with nothing shown on your phone. The missed-call notice and badge are still being worked on. Only ordinary phone calls from these exact numbers are affected, never emergency calls, unknown or withheld numbers, FaceTime or other apps. A caller ID match is a rule match and does not prove who is calling."},
  @{@"title":@"ADD",@"rows":add},
  @{@"title":@"",@"rows":help.count?help:@[]}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];
 __weak typeof(self) weak=self;[self silentHelper:@[@"pcapply"] completion:^(int rc){(void)rc;[weak rebuildMenu];}];}   // merge anything Phone left for the helper, then show the one list
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *entry=self.menuSections[p.section][@"rows"][p.row];
 if(entry[@"pcKey"]){[tableView deselectRowAtIndexPath:p animated:YES];[self chooseActionForKey:entry[@"pcKey"]];return;}
 [super tableView:tableView didSelectRowAtIndexPath:p];
}
- (void)chooseActionForKey:(NSString *)key{
 NSDictionary *entry=MYBPCEntryForKey(MYBPCEffectiveNow(),key);if(!entry)return;
 NSString *shown=MYBPCLabel(entry,MYBPCContactName(entry[@"k"]),MYBPCRegionNow()),*stored=entry[@"d"]?:shown;
 void (^set)(NSString *)=^(NSString *action){if(!MYBPCWrite(key,stored,action,YES))MYBComplete(self,NO,@"Couldn’t save",@"Your previous setting is kept.");[self rebuildMenu];};
 MYBShieldChoice(self,shown,@"What should happen when this number calls?",@[@[@"Mute",@"Silences the ringer. The caller keeps ringing"],@[@"Decline",@"Declines the moment it rings"],@[@"Hang up",@"Picks up and hangs up at once"]],@"phone.badge.waveform",1,@[
  @{@"title":@"Mute",@"style":@"primary",@"handler":^{set(MYB_PC_ACTION_MUTE);}},
  @{@"title":@"Decline",@"style":@"secondary",@"handler":^{set(MYB_PC_ACTION_DECLINE);}},
  @{@"title":@"Hang up",@"style":@"secondary",@"handler":^{set(MYB_PC_ACTION_HANGUP);}},
  @{@"title":@"Remove from Private Calls",@"style":@"destructive",@"handler":^{
    MYBConfirmWithButton(self,@"Remove this number?",@"Its calls show in normal Recents again. No call record is deleted or changed.",@"Remove",^{
     if(!MYBPCWrite(key,stored,entry[@"a"],NO))MYBComplete(self,NO,@"Couldn’t save",@"Your previous setting is kept.");[self rebuildMenu];});}},
  @{@"title":@"Cancel",@"style":@"cancel"}]);
}
- (BOOL)addRaw:(NSString *)raw name:(NSString *)name quiet:(BOOL)quiet{   // with or without a country code: one number either way
 if(MYBPCIsProtectedNumber(raw)){if(!quiet)MYBComplete(self,NO,@"Not allowed",@"Emergency numbers can’t be made private.");return NO;}
 NSString *key=MYBPCKey(raw,MYBPCRegionNow());
 if(!key){if(!quiet)MYBComplete(self,NO,@"Not a phone number",@"Type the number the way it shows when they call. A country code is not needed.");return NO;}
 NSString *action=MYB_PC_ACTION_MUTE;NSDictionary *existing=MYBPCEntryForKeyLoose(MYBPCEffectiveNow(),key);
 if(existing){key=existing[@"k"];action=existing[@"a"];}   // already private under another spelling: kept, not duplicated
 NSString *label=MYBPCNameOnly(name)?:MYBPCContactName(key)?:MYBPCFormat(key,MYBPCRegionNow());
 if(!MYBPCWrite(key,label,action,YES)){if(!quiet)MYBComplete(self,NO,@"Couldn’t save",@"Nothing was changed.");return NO;}
 return YES;
}
- (void)askNumber{
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Add a Number" message:@"Type it the way it shows when they call. A country code is not needed." preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.keyboardType=UIKeyboardTypePhonePad;field.placeholder=@"Phone number";field.autocorrectionType=UITextAutocorrectionTypeNo;}];
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 __weak UIAlertController *weak=alert;
 [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){(void)a;
  [self addRaw:weak.textFields.firstObject.text name:nil quiet:NO];[self rebuildMenu];}]];
 [self presentViewController:alert animated:YES completion:nil];
}
- (void)pickContacts{
 CNContactPickerViewController *picker=[CNContactPickerViewController new];
 picker.displayedPropertyKeys=@[CNContactPhoneNumbersKey];
 self.pickerDelegate=[MYBPCContactDelegate new];
 __weak typeof(self) weak=self;
 self.pickerDelegate.done=^(NSArray<NSDictionary *> *numbers){
  NSInteger added=0,refused=0;for(NSDictionary *n in numbers){if([weak addRaw:n[@"number"] name:n[@"name"] quiet:YES])added++;else refused++;}
  [weak rebuildMenu];
  if(added||refused)MYBComplete(weak,added>0,added?@"Added":@"Not added",[NSString stringWithFormat:@"%ld number%@ added.%@",(long)added,added==1?@"":@"s",refused?[NSString stringWithFormat:@" %ld could not be read as a phone number.",(long)refused]:@""]);
 };
 picker.delegate=self.pickerDelegate;
 [self presentViewController:picker animated:YES completion:nil];
}
- (void)copyDiagnostics{   // asks the call service for a fresh look first, so one tap does everything
 notify_post("net.myxxdev.mybloxx.csd.probe");
 notify_post("net.myxxdev.mybloxx.csm.probe");
 __weak typeof(self) weak=self;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weak copyDiagnosticsNow];});
}
- (void)copyDiagnosticsNow{
 MYBCSLPublish(MYBPrivFile());
 NSMutableDictionary *status=[NSMutableDictionary dictionary];
 NSDictionary *phone=[self phoneStatus],*call=[self callStatus];
 if(phone.count)status[@"phone"]=phone;if(call.count)status[@"incomingCalls"]=call;
 {NSString *audio=MYBCSCReadFrom(@"net.myxxdev.mybloxx.csm.%u");if(audio.length)status[@"audioService"]=@{@"loaded":@1,@"report":[audio componentsSeparatedByString:@"\n"]};else status[@"audioService"]=@{@"loaded":@0};}
 {id live=CFBridgingRelease(CFPreferencesCopyValue(MYB_CSL_LIVE_KEY,MYB_CSL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost));status[@"liveList"]=[live isKindOfClass:NSString.class]?@{@"published":@1,@"entries":@([[live componentsSeparatedByString:@"\n"] count]>2?[[live componentsSeparatedByString:@"\n"] count]-2:0)}:@{@"published":@0};}
 {NSString *box=MYBCSCReadFrom(MYB_CSL_NAME);status[@"listMailbox"]=box.length?@{@"published":@1,@"entries":@([[box componentsSeparatedByString:@"\n"] count]>2?[[box componentsSeparatedByString:@"\n"] count]-2:0),@"switch":@([box hasPrefix:@"sw=1"])}:@{@"published":@0};}
 {NSString *rep=MYBCSCRead();   // the call service part reports through system notification states, then its own preferences, then files
  if(!rep.length){CFPropertyListRef own=CFPreferencesCopyAppValue(MYB_CSC_OWN_KEY,MYB_CSC_OWN_DOMAIN);if(own&&CFGetTypeID(own)==CFStringGetTypeID())rep=(__bridge_transfer NSString *)own;else if(own)CFRelease(own);}
  if(rep.length){status[@"callService"]=@{@"loaded":@1,@"via":@"channel",@"report":[rep componentsSeparatedByString:@"\n"]};}
  else{
   CFPropertyListRef svc=CFPreferencesCopyAppValue(CFSTR("status"),CFSTR("net.myxxdev.mybloxx.callservice"));if(svc){status[@"callService"]=(__bridge_transfer id)svc;}else{for(NSString *f in @[@"/var/mobile/Library/MYbloXX/CallServiceProbe.plist",@"/var/tmp/MYbloXX-CallServiceProbe.plist",@"/tmp/MYbloXX-CallServiceProbe.plist"]){NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:f];if(d){status[@"callService"]=d;break;}}if(!status[@"callService"])status[@"callService"]=@{@"loaded":@([NSFileManager.defaultManager fileExistsAtPath:@"/var/tmp/MYbloXX-CallServiceAlive"]||[NSFileManager.defaultManager fileExistsAtPath:@"/tmp/MYbloXX-CallServiceAlive"]),@"report":@"not readable"};}
   CFPropertyListRef alive=CFPreferencesCopyAppValue(CFSTR("MYBAlive"),MYB_CSC_OWN_DOMAIN);
   if(alive){CFRelease(alive);NSMutableDictionary *d=[status[@"callService"] mutableCopy]?:[NSMutableDictionary dictionary];d[@"alive"]=@1;status[@"callService"]=d;}
  }}
 if(!status.count){MYBComplete(self,NO,@"Nothing to Copy Yet",@"Open Phone once with Private Calls switched on, then come back.");return;}
 NSData *json=[NSJSONSerialization dataWithJSONObject:status options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:NULL];
 NSString *text=json?[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]:nil;
 if(!text.length){MYBComplete(self,NO,@"Couldn’t Copy",@"Nothing was changed.");return;}
 UIPasteboard.generalPasteboard.string=text;
 MYBComplete(self,YES,@"Copied",@"Paste it into your message to MYXXdev™. It holds only class names and counts.");
}
@end

// The front door: four short cards, each opening its own screen. The main Settings page stays short because this is the only row it needs.
@interface MYBExtraPrivacyController : MYBMenuBase @end
@implementation MYBExtraPrivacyController
- (NSString *)heroTitle{return @"Extra Privacy Protection";}
- (NSString *)heroDetail{return @"Optional tools. Everything is off until you turn it on.";}
- (void)rebuildMenu{
 self.title=@"Extra Privacy Protection";
 self.menuSections=@[@{@"title":@"",@"rows":@[
  @{@"title":@"App Lock & Previews",@"detail":@"Face ID for chosen apps and hidden app switcher previews",@"icon":@"lock.app.dashed",@"accent":@YES,@"tone":@(MYBToneViolet),@"page":@"MYBAppLockController",@"action":@"openPage"},
  @{@"title":@"Private Items",@"detail":@"Private Album, Recently Deleted and Private Conversations",@"icon":@"lock.rectangle.stack.fill",@"accent":@YES,@"tone":@(MYBToneIndigo),@"page":@"MYBPrivateItemsController",@"action":@"openPage"},
  @{@"title":@"Notification Privacy",@"detail":@"Hide previews or silence alerts for chosen apps",@"icon":@"bell.badge.slash.fill",@"accent":@YES,@"tone":@(MYBToneRose),@"page":@"MYBNotifPrivacyController",@"action":@"openPage"},
  @{@"title":@"Clean Share",@"detail":@"Clean a link, remove photo location, redact a screenshot",@"icon":@"square.and.arrow.up.fill",@"accent":@YES,@"tone":@(MYBToneTeal),@"page":@"MYBCleanShareController",@"action":@"openPage"}],
  @"footer":@"Connection Inspector is in Activity, Safari Cleanup is in browser protection, and Local Network Check is in Diagnostics."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
@end
