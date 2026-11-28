#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBWeb.h"
#import "../Shared/MYBProfiles.h"
#import "../Shared/MYBMYbloXXProfile.h"
#import "../Shared/MYBProfileInstall.h"
#import "../Shared/MYBOutcomeText.h"
#import "../Shared/MYBModeCatalog.h"
#import <notify.h>
// Legacy Mode: profile-based blocking for people who cannot or do not want to use native MYbloXX. It needs iOS to
// believe the device is supervised before it offers a PAC profile, so supervision spoofing is step 1 and the
// profiles are step 2. Profile identifiers (Default, allowY, ...) are unchanged; only the labels are.
static NSString *MYBProfileFile(NSString *mode){return @{@"blockApple":@"noApple",@"blockSocials":@"noSocials",@"blockXXX":@"noXXX"}[mode]?:mode;}
@interface MYBLegacyController : MYBMenuBase @end
@implementation MYBLegacyController
- (void)viewDidLoad{
 [super viewDidLoad];__weak typeof(self) weak=self;
 [NSNotificationCenter.defaultCenter addObserverForName:MYBProfileStateChanged object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;[weak rebuildMenu];}];
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];}
- (BOOL)hasProfile{return [MYBInstalledMYbloXXProfile()[@"installed"] boolValue];}
- (NSDictionary *)state{return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.supervision.plist")]?:@{};}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self runHelper:@[@"supervisionstatus"] completion:^(int rc){(void)rc;
  NSMutableArray *files=[NSMutableArray array];for(NSDictionary *m in MYBModeTable())[files addObject:MYBProfileFile(m[@"mode"])];
  MYBRefreshProfileStatus(self,@"profiles",files,nil); // the profiles share one identifier, so each is checked by its own PayloadUUID
 }];}
- (void)rebuildMenu{
 self.title=@"Supervision & Legacy Mode";NSDictionary *state=self.state;BOOL enabled=[state[@"supervised"] boolValue],owned=[state[@"owned"] boolValue];
 NSMutableArray *profiles=[NSMutableArray array];
 for(NSDictionary *m in MYBModeTable())[profiles addObject:@{@"title":[MYBModeName(m[@"mode"]) stringByAppendingString:@" Profile"],@"detail":m[@"short"],@"icon":m[@"icon"],@"profile":MYBProfileFile(m[@"mode"]),@"mode":m[@"mode"]}];
 NSString *spoofDetail=![state[@"available"] boolValue]?(state[@"reason"]?:@"Apple system-group storage cannot be accessed"):(enabled?(owned?@"On, enabled by MYbloXX®":@"On, enabled outside MYbloXX®"):@"Off");
 self.menuSections=@[
  @{@"title":@"STEP 1 · SUPERVISION",@"rows":@[
    @{@"title":@"Spoof Supervision",@"detail":spoofDetail,@"icon":@"lock.shield"},
    @{@"title":@"Hide Supervision Message",@"detail":@"Hides the banner in Settings",@"icon":@"eye.slash"}],
    @"footer":@"iOS only offers these profiles on a supervised device, so Spoof Supervision must be on before you install one. Your original supervision state is saved first and restored when you turn it off. Once the profile is installed you can hide the message. To install another profile later, turn Spoof Supervision back on."},
  @{@"title":[NSString stringWithFormat:@"STEP 2 · PROFILES · MYBLOXX® PROFILE %@",MYBProfileStatusText(@"profiles",MYBProfileFile(MYBModeTable().firstObject[@"mode"])).uppercaseString],@"rows":profiles,@"footer":@"Install one profile at a time. MYbloXX® gives you the profile as a file for Files or as a link for your browser, then iOS asks you to review and install it in Settings. The profile reads its rules from the internet and works without MYbloXX® running. If you set a noXXX PIN, getting a profile asks for it, but a profile cannot check the PIN afterwards. Installing a profile turns native MYbloXX® blocking off so the two never run together."},
  self.hasProfile?
   @{@"title":@"BACK TO NATIVE PROTECTION",@"rows":@[@{@"title":@"Return to Native Protection",@"detail":@"Removes the MYbloXX\u00ae profile and turns native protection on",@"icon":@"arrow.uturn.backward",@"accent":@(YES),@"tone":@(MYBToneBlue),@"action":@"return"}],
    @"footer":@"A MYbloXX\u00ae profile is installed on this iPhone. MYbloXX\u00ae removes it for you; if iOS asks for your passcode, enter it. Other profiles (DNS, VPN, work or school) are never touched."}:
   @{@"title":@"PROTECTION",@"rows":@[@{@"title":@"Native Protection",@"detail":@"No MYbloXX\u00ae profile is installed",@"icon":@"checkmark.seal.fill",@"accent":@(YES),@"tone":@(MYBToneGreen)}],
    @"footer":@"MYbloXX\u00ae is blocking with its own on-device method. A profile from step 2 would replace it until you return."}];
 [self.tableView reloadData];
}
- (NSString *)heroEyebrow{return @"Supervision & Legacy Mode";}
- (NSString *)heroTitle{return @"Supervision & Legacy Mode";}
- (NSString *)heroDetail{return @"Profile-based blocking instead of the normal on-device method. Use it only if normal blocking does not suit your setup.";}
// A profile chosen while supervision is off is remembered here, if the person leaves before supervision is confirmed. When Legacy Mode is opened again and the supervision record shows it is on, the same profile continues.
- (NSString *)pendingPath{return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.legacypending.plist");}
// The Legacy transaction. iOS refuses to install a proxy profile while MYbloXX’s own managed link is in place, so native protection is turned
// OFF the moment a profile is chosen (legacyprepare), before the profile is handed to iOS. If the install is cancelled, fails or never happens,
// native protection is turned back on automatically: here as soon as the profile is seen not to be installed, and by the helper’s watch loop
// after 15 minutes if this screen is never reopened. The record only says which profile is being waited for.
- (NSString *)transactionPath{return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.legacytransaction.plist");}
- (void)finishLegacySwitch:(NSString *)name{
 [NSFileManager.defaultManager removeItemAtPath:self.transactionPath error:NULL];[self rebuildMenu];
 MYBComplete(self,YES,@"Switched to the Legacy Profile",@"iOS reports the profile as installed. Native protection was switched off for the install, so the two do not compete. Use Return to Native Protection to switch back.");
}
// The switch did not complete (cancelled, failed, or iOS does not show the profile): native protection comes straight back.
- (void)restoreNativeAfterCancelledSwitch:(NSString *)why{
 [NSFileManager.defaultManager removeItemAtPath:self.transactionPath error:NULL];
 [self runHelper:@[@"enable"] completion:^(int rc){
  [self rebuildMenu];
  if(rc==0)MYBMessage(self,@"Native Protection Restored",why);
  else MYBMessage(self,@"Turn Protection Back On",@"The profile was not installed, but native protection could not be turned back on automatically. Use Return to Native Protection to turn it on.");
 }];
}
- (void)checkLegacyTransaction{
 NSDictionary *txn=[NSDictionary dictionaryWithContentsOfFile:self.transactionPath];NSString *name=txn[@"profile"];
 if(![name isKindOfClass:NSString.class]||self.busy)return;
 MYBRefreshProfileStatus(self,@"profiles",@[name],^{
  NSString *label=MYBProfileStatusText(@"profiles",name);
  if([@[@"Installed",@"Installed, Contents Not Checked"] containsObject:label]){[self finishLegacySwitch:name];return;}
  [self restoreNativeAfterCancelledSwitch:@"The profile was not installed, so MYbloXX\u00ae turned native protection back on. Nothing else changed."];
 });
}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];
 if([NSFileManager.defaultManager fileExistsAtPath:self.transactionPath]){[self checkLegacyTransaction];return;}
 NSString *path=self.pendingPath;NSDictionary *pending=[NSDictionary dictionaryWithContentsOfFile:path];
 if(!pending)return;
 [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
 NSDate *made=pending[@"time"];NSString *name=pending[@"profile"];
 NSString *wanted=[pending[@"key"] isKindOfClass:NSString.class]?pending[@"key"]:@"";
 if(wanted.length&&![wanted isEqual:MYBProfileInfo([NSData dataWithContentsOfFile:MYBPath([NSString stringWithFormat:@"/usr/share/mybloxx/profiles/%@.mobileconfig",name])])[@"key"]])return; // the profile changed since it was chosen (identifier AND PayloadUUID)
 if(![made isKindOfClass:NSDate.class]||made.timeIntervalSinceNow<-900||![name isKindOfClass:NSString.class])return;
 NSDictionary *state=self.state;
 if(![state[@"supervised"] boolValue]){[self showMessage:@"Supervision Is Still Off" detail:@"Supervision could not be confirmed, so no profile was downloaded. Turn on Spoof Supervision in step 1 and choose the profile again."];return;}
 for(NSDictionary *row in self.menuSections[1][@"rows"])if([row[@"profile"] isEqual:name]){[self downloadProfile:row];return;}
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(self.busy)return;
 if(p.section==2){if(self.hasProfile)[self returnToNative];return;}
 if(p.section!=1)return;
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSDictionary *state=self.state;
 if(![state[@"available"] boolValue]){[self showMessage:@"Supervision Unavailable" detail:@"Apple’s system-group storage could not be accessed, so the supervision step cannot run. Use Repair MYbloXX®, then try again."];return;}
 if(![state[@"supervised"] boolValue]){
  MYBConfirmWithButton(self,@"Supervision Needed First",@"iOS only offers legacy profiles on a supervised device. MYbloXX® can switch on its supervision setting for you. You do not need to close Settings. Your original value is saved and restored when you turn it off. Only use this on your own, unmanaged device.",@"Enable Supervision & Continue",^{[self enableSupervisionThenContinue:row];});
  return;
 }
 [self downloadProfile:row];
}
- (void)enableSupervisionThenContinue:(NSDictionary *)row{
 {NSData *bundled=[NSData dataWithContentsOfFile:MYBPath([NSString stringWithFormat:@"/usr/share/mybloxx/profiles/%@.mobileconfig",row[@"profile"]])];NSString *identifier=MYBProfileIdentifier(bundled);NSString *key=MYBProfileInfo(bundled)[@"key"];
 [@{@"profile":row[@"profile"],@"identifier":identifier?:@"",@"key":key?:@"",@"time":[NSDate date]} writeToFile:self.pendingPath atomically:YES];}
 [self runHelper:@[@"spoof"] completion:^(int rc){
  if(rc){[NSFileManager.defaultManager removeItemAtPath:self.pendingPath error:NULL];[self showMessage:@"Supervision Not Enabled" detail:@"MYbloXX® could not switch supervision on, so nothing was downloaded. Open Status & Diagnostics to see why, then try again."];return;}
  [self runHelper:@[@"supervisionstatus"] completion:^(int status){
   if(status||![self.state[@"supervised"] boolValue]){[NSFileManager.defaultManager removeItemAtPath:self.pendingPath error:NULL];[self showMessage:@"Supervision Not Confirmed" detail:@"The change was requested but the supervision record does not show it as on, so nothing was downloaded."];return;}
   [NSFileManager.defaultManager removeItemAtPath:self.pendingPath error:NULL];[self rebuildMenu];[self downloadProfile:row]; // Settings stays open: the chosen profile continues straight away
  }];
 }];
}
- (void)downloadProfile:(NSDictionary *)row{
 NSString *name=row[@"profile"],*mode=row[@"mode"];
 NSString *warning=MYBModeWarning(mode,YES);
 NSString *message=[(warning?[warning stringByAppendingString:@"\n\n"]:@"") stringByAppendingString:@"Native MYbloXX® blocking pauses while you install the profile, because iOS refuses to install it otherwise, and turns itself back on if you cancel. MYbloXX® hands the profile to iOS and opens Apple’s own review screen. iOS asks you to review and install it with your passcode; installing it is your confirmation. When you come back, MYbloXX® checks that iOS shows the profile as installed and only then turns native blocking off, because iOS allows only one proxy. If you cancel or it fails, native blocking stays on."];
 [self confirm:[@"Get " stringByAppendingString:row[@"title"]] message:message action:^{
  MYBProgress(self,@"Preparing Profile"); // one status sheet for the whole flow: no separate Applied sheet can cover the delivery options
  [self runHelper:@[@"legacyprepare"] completion:^(int gate){ // PIN check, then native protection off so iOS accepts the profile
   if(gate==90||gate==91){[self showMessage:@"Profile Not Prepared" detail:@"A noXXX PIN is set, so the PIN is required. A standalone profile cannot check a PIN once installed, so it would bypass noXXX. Nothing was changed."];return;}
   if(gate){[self showMessage:@"Profile Not Prepared" detail:@"Native protection could not be paused for the install, so nothing was changed. Open Status & Diagnostics to see why."];return;}
   {NSData *bundled=[NSData dataWithContentsOfFile:MYBPath([NSString stringWithFormat:@"/usr/share/mybloxx/profiles/%@.mobileconfig",name])];
    [@{@"profile":name,@"key":MYBProfileInfo(bundled)[@"key"]?:@"",@"time":[NSDate date]} writeToFile:self.transactionPath atomically:YES];}
   MYBDeliverProfileFile(self,@"profiles",name,row[@"title"],MYBLegacyProfileLink(name));
   // If iOS never takes the profile (the hand-over itself failed), there is nothing to wait for: native protection comes straight back.
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(12*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
    if(![NSFileManager.defaultManager fileExistsAtPath:self.transactionPath])return;
    NSDictionary *record=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.profileinstall.plist")];
    NSString *state=[record[@"state"] description];
    if([@[@"failed",@"restricted",@"invalid",@"unavailable"] containsObject:state])[self restoreNativeAfterCancelledSwitch:@"The profile could not be handed to iOS, so MYbloXX\u00ae turned native protection back on. Nothing else changed."];
   });
  }];
 }];
}
// The way back: native protection turns on only when iOS no longer holds a profile-made configuration. The helper refuses (exit 3) while one is present.
- (void)returnToNative{
 __weak typeof(self) weak=self;
 [self offerRemoveMYbloXXProfileThen:^(__unused int rc){[weak rebuildMenu];}];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 MYBPrismCell *cell=(MYBPrismCell *)[super tableView:t cellForRowAtIndexPath:p];
 if(p.section==0&&p.row==1){
  cell.tone=MYBToneIndigo;
  MYBPrismSwitch *hide=[MYBPrismSwitch new];hide.key=@"HideSupervisionSign";hide.onTintColor=MYBAccent();hide.enabled=!self.busy;
  hide.on=[[[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.appearance.plist")] objectForKey:@"HideSupervisionSign"] boolValue];
  [hide addTarget:self action:@selector(hideSign:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=hide;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];return cell;
 }
 if(p.section==1){cell.tone=MYBToneSlate;cell.mybAccessoryType=UITableViewCellAccessoryDisclosureIndicator;cell.selectionStyle=UITableViewCellSelectionStyleDefault;[cell refreshContent];return cell;}
 cell.tone=MYBToneAmber;
 MYBPrismSwitch *control=[MYBPrismSwitch new];control.key=@"supervision";NSDictionary *state=self.state;control.on=[state[@"supervised"] boolValue];
 control.enabled=!self.busy&&[state[@"available"] boolValue]&&(!control.on||[state[@"owned"] boolValue]);control.onTintColor=MYBAccent();
 [control addTarget:self action:@selector(change:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=control;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];return cell;
}
- (void)hideSign:(MYBPrismSwitch *)control{NSString *path=MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.appearance.plist");if(![@{@"HideSupervisionSign":@(control.on)} writeToFile:path atomically:YES]){[control setOn:!control.on animated:YES];[self showMessage:@"Unable to Save" detail:@"Try Repair MYbloXX®, then change the option again."];return;}notify_post("net.myxxdev.mybloxx.appearance.changed");[self showMessage:@"Appearance Saved" detail:@"Close Settings from the app switcher and reopen it. Your supervision state has not changed."];}
- (void)change:(MYBPrismSwitch *)control{
 if(![self.state[@"available"] boolValue]) {
  [control setOn:NO animated:YES];
  [self showMessage:@"Supervision Unavailable" detail:@"Apple’s system-group storage could not be accessed. Check Status after Repair MYbloXX®."];
  return;
 }
 BOOL enable=control.on;[control setOn:!enable animated:YES];[self confirm:enable?@"Spoof Supervision Status?":@"Disable Supervision Spoofing?" message:enable?@"Enabling Legacy Supervision will place your device into a spoofed supervised state to allow profile installation. Your original supervision value will be saved. Only use this on your own, unmanaged device.":@"This restores the supervision value saved before MYbloXX® enabled spoofing. Your MYbloXX® protection and rules will remain unchanged." action:^{[self runHelper:@[enable?@"spoof":@"unspoof"] completion:^(int rc){if(!rc)[self runHelper:@[@"supervisionstatus"] completion:^(int status){if(!status)[self rebuildMenu];}];}];}];}
@end

