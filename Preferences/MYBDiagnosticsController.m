#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBModeNames.h"
#import "../Shared/MYBRuntimeStatus.h"
#import "../Shared/MYBStatusModel.h"
#import "../Shared/MYBCallServiceChannel.h"
#import <notify.h>
// Local Network Check: read-only. iOS gives no supported way to read another app's Local Network permission, so this does not pretend to: it explains how to
// read the three states in iOS itself and opens the right place. It scans nothing, disconnects nothing and changes no permission, firewall, hotspot or carrier state.
@interface MYBLocalNetworkController : MYBMenuBase @end
@implementation MYBLocalNetworkController
- (NSString *)heroTitle{return @"Local Network Check";}
- (NSString *)heroDetail{return @"Review which apps may talk to devices on your Wi-Fi. This page only explains and opens Settings.";}
- (void)rebuildMenu{
 self.title=@"Local Network Check";
 self.menuSections=@[
  @{@"title":@"WHERE TO LOOK",@"rows":@[
   @{@"title":@"Open Privacy & Security",@"detail":@"Then tap Local Network",@"icon":@"hand.raised.fill",@"accent":@YES,@"tone":@(MYBToneBlue),@"action":@"openPrivacy"},
   @{@"title":@"Settings › Privacy & Security › Local Network",@"detail":@"If the button above does not open it, follow this path yourself",@"icon":@"signpost.right.fill"}],
   @"footer":@"MYbloXX® cannot read these choices for you: iOS does not let one app see another app’s permission, so nothing here is guessed."},
  @{@"title":@"HOW TO READ THE LIST",@"rows":@[
   @{@"title":@"Switch on",@"detail":@"Allowed: the app may find and talk to devices on your network",@"icon":@"checkmark.circle.fill",@"tone":@(MYBToneGreen)},
   @{@"title":@"Switch off",@"detail":@"Denied: the app asked and was told no, or you turned it off",@"icon":@"xmark.circle.fill",@"tone":@(MYBToneRose)},
   @{@"title":@"App not in the list",@"detail":@"Undetermined: the app has not asked yet, so iOS has no answer to show",@"icon":@"questionmark.circle.fill",@"tone":@(MYBToneSlate)}],
   @"footer":@"Turning a switch off or on changes only that app’s own permission, and only in iOS Settings."}];
 [self.tableView reloadData];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];
 if(![self.menuSections[p.section][@"rows"][p.row][@"action"] isEqual:@"openPrivacy"])return;
 [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"App-prefs:Privacy"] options:@{} completionHandler:^(BOOL opened){
  if(!opened)dispatch_async(dispatch_get_main_queue(),^{[self showMessage:@"Couldn’t open Settings page" detail:@"Open the Settings app, then Privacy & Security, then Local Network."];});
 }];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
@end

@interface MYBDiagnosticsController : MYBMenuBase @end
@implementation MYBDiagnosticsController
- (NSDictionary *)state{return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/State.plist")]?:@{};}
- (BOOL)systemEnabled{return [MYBStatusModel(MYBRuntimeStatusMirrored(MYBMobileFile(@"/var/mobile/Library/MYbloXX/RuntimeStatus.plist")),YES,nil)[@"active"] boolValue];}
- (void)rebuildMenu{
 self.title=@"Advanced Diagnostics";NSDictionary *state=self.state;
 self.menuSections=@[@{@"title":@"PROTECTION STATUS",@"rows":@[
 @{@"title":@"Protection",@"value":self.systemEnabled?@"Enabled":@"Disabled",@"icon":@"shield.lefthalf.filled"},
 @{@"title":@"Selected Mode",@"value":MYBModeDisplay(state[@"mode"]),@"icon":@"slider.horizontal.3"}]},
 @{@"title":@"LOW-LEVEL CHECKS",@"rows":@[
 @{@"title":@"Check a Website",@"icon":@"globe",@"action":@"testDomain"},
 @{@"title":@"In-App Ad Blocking",@"detail":@"What each app module reported",@"icon":@"nosign",@"page":@"MYBInAppAdsStatusController"},
 @{@"title":@"App Switch Raw Trace",@"detail":@"Technical foreground log for support",@"icon":@"bolt.fill",@"page":@"MYBAppControlTraceController"},
 @{@"title":@"Local Network Check",@"detail":@"How to review each app’s Local Network permission",@"icon":@"network",@"page":@"MYBLocalNetworkController"},
 @{@"title":@"PAC Script",@"detail":@"Read-only view of the generated script",@"icon":@"doc.plaintext",@"page":@"MYBPACViewController"},
 @{@"title":@"Message Pipeline Probe",@"detail":@"Research for a possible Message Firewall. Copies class and method names only, never a number or message.",@"icon":@"doc.on.doc",@"action":@"copyMessageProbe"}]}];[self.tableView reloadData];
}
// Copies the one-time, read-only report from Companions/MYBMessageProbe (no hook, no live message ever touched -- see that file's own comment).
// Exists only so the real shape of imagent's message pipeline can be learned from this phone before any blocking code is written.
// Reads every channel the probe writes to, in the same fallback order Copy Calls Diagnostics already uses for the call service: the mailbox first,
// then imagent's own preferences domain, then a dedicated domain, then plain files, and finally a bare alive marker if the full report never made it.
- (void)copyMessageProbe{
 notify_post("net.myxxdev.mybloxx.imp.probe");
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  NSString *report=MYBCSCReadFrom(@"net.myxxdev.mybloxx.imp.%u");
  NSString *via=report.length?@"mailbox":nil;
  if(!report.length){CFPropertyListRef own=CFPreferencesCopyAppValue(CFSTR("MYBMessageProbeReport"),CFSTR("com.apple.imagent"));if(own&&CFGetTypeID(own)==CFStringGetTypeID()){report=(__bridge_transfer NSString *)own;via=@"imagent preferences";}else if(own)CFRelease(own);}
  if(!report.length){CFPropertyListRef dom=CFPreferencesCopyAppValue(CFSTR("status"),CFSTR("net.myxxdev.mybloxx.messageprobe"));if(dom&&CFGetTypeID(dom)==CFStringGetTypeID()){report=(__bridge_transfer NSString *)dom;via=@"dedicated preferences";}else if(dom)CFRelease(dom);}
  if(!report.length){for(NSString *f in @[@"/var/mobile/Library/MYbloXX/MessageProbe.plist",@"/var/tmp/MYbloXX-MessageProbe.plist",@"/tmp/MYbloXX-MessageProbe.plist"]){NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:f];NSString *r=d[@"report"];if(r.length){report=r;via=[@"file " stringByAppendingString:f];break;}}}
  if(!report.length){
   BOOL aliveOnly=[NSFileManager.defaultManager fileExistsAtPath:@"/var/tmp/MYbloXX-MessageProbeAlive"]||[NSFileManager.defaultManager fileExistsAtPath:@"/tmp/MYbloXX-MessageProbeAlive"];
   CFPropertyListRef alive=CFPreferencesCopyAppValue(CFSTR("MYBAlive"),CFSTR("com.apple.imagent"));if(alive){aliveOnly=YES;CFRelease(alive);}
   if(aliveOnly){UIPasteboard.generalPasteboard.string=@"alive marker found, but the full report never arrived on any channel";MYBComplete(self,NO,@"Partial Result Copied",@"imagent loaded this part but every full-report channel was refused. The partial note is on your clipboard -- send it back.");return;}
   MYBComplete(self,NO,@"Nothing to Copy Yet",@"No channel this part writes to has anything yet. Respring or reboot once more, wait a few seconds after unlock, then try again.");return;
  }
  UIPasteboard.generalPasteboard.string=[NSString stringWithFormat:@"[via: %@]\n%@",via,report];
  MYBComplete(self,YES,@"Copied",@"Paste it wherever you want to send it. It holds only class, property and method names, never a number, a contact or a message.");
 });
}
- (void)testDomain{
 MYBInput(self,@"Check a Website",@"See how your current rules handle a website.",@[@{@"placeholder":@"example.com"}],@"Check Website",^(NSArray *values){NSString *input=[values.firstObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  [self runHelper:@[@"testrule",input] completion:^(int rc){
   if(rc){MYBMessage(self,@"Unable to Check",rc==64?@"Enter a valid domain, such as example.com.":@"Your current configuration could not be checked. Please try again.");return;}
   NSDictionary *result=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.ruletest.plist")];BOOL allowed=[result[@"result"] isEqual:@"DIRECT"];MYBDecision(self,allowed,result[@"domain"],allowed?(self.systemEnabled?@"Your current rules allow this website.":@"Protection is paused."):@"Your current rules block this website.");
  }];
 });
}
@end
