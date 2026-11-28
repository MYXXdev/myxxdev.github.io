#import "MYBMenuBase.h"
#import <roothide.h>
#import "MYBDesign.h"
#import "../Shared/MYBLoopback.h"
#import "MYBWeb.h"
#import "../Shared/MYBProxyCheck.h"
#import "../Shared/MYBOutcomeText.h"
#import "../Shared/MYBHelp.h"
#import "../Shared/MYBVersion.h"
#import "MYBTips.h"
#import <notify.h>
// Help & Repair: the one place for checking, repairing, testing and learning. Technical logs and traces are one level down, under Advanced Diagnostics.
@interface MYBTroubleshootingController : MYBMenuBase @end
@implementation MYBTroubleshootingController
- (NSString *)heroEyebrow{return @"MYbloXX®";}
- (NSString *)heroTitle{return @"Help & Repair";}
- (NSString *)heroDetail{return @"Check, repair and get help.";}
- (void)rebuildMenu{
 self.title=@"Help & Repair";
 NSMutableArray *guides=[NSMutableArray array];NSUInteger i=0;
 for(NSDictionary *t in MYBHelpTopics()){[guides addObject:@{@"title":t[@"title"],@"detail":t[@"detail"],@"icon":t[@"icon"],@"topic":@(i)}];i++;}
 [guides addObject:@{@"title":@"Replay Welcome Tour",@"detail":@"Show the short tour again",@"icon":@"play.circle",@"action":@"replayTour"}];
 self.menuSections=@[
  @{@"title":@"CHECK & REPAIR",@"rows":@[
   @{@"title":@"Check Protection",@"detail":@"Confirm protection matches your settings",@"icon":@"checkmark.shield",@"accent":@(YES),@"tone":@(MYBToneGreen),@"action":@"localHealth"},
   @{@"title":@"Repair MYbloXX®",@"detail":@"Rebuild protection from your saved settings",@"icon":@"wrench.adjustable.fill",@"primary":@(YES),@"action":@"repair"},
   @{@"title":@"Live Status",@"detail":@"See how protection is doing now",@"icon":@"waveform.path.ecg",@"action":@"openStatusPage"},
   @{@"title":@"Reset iOS Connection Cache",@"detail":@"Refresh Wi-Fi and cellular connections",@"icon":@"arrow.triangle.2.circlepath",@"action":@"resetConnection"},
   @{@"title":@"Restore Default Settings",@"detail":@"Back to the fresh-install setup. Backups are kept.",@"icon":@"arrow.counterclockwise",@"destructive":@(YES),@"action":@"restoreDefaults"}]},
  @{@"title":@"SUPPORT",@"rows":@[
   @{@"title":@"Discord",@"detail":@"Chat with MYXXdev™ and other users",@"icon":@"bubble.left.and.bubble.right.fill",@"url":@"https://discord.gg/s33Xn4sX5f",@"action":@"openLink"},
   @{@"title":@"Telegram",@"detail":@"MYXXdevSupport",@"icon":@"paperplane.fill",@"url":@"https://t.me/MYXXdevSupport",@"action":@"openLink"},
   @{@"title":@"Support MYXXdev™",@"detail":@"Help support the development of MYbloXX®.",@"icon":@"heart.fill",@"url":@"https://myxxfm.com/donate",@"action":@"openLink"}]},
  @{@"title":@"TEST LINKS",@"rows":@[
   @{@"title":@"AdBlock Test",@"detail":@"See how many ads get blocked",@"icon":@"checkmark.seal",@"action":@"openAdTest"},
   @{@"title":@"Popup Test",@"detail":@"Opens in Safari",@"icon":@"macwindow.on.rectangle",@"action":@"openPopupTest"}],
   @"footer":@"Test pages open only when you tap them."},
  @{@"title":@"GUIDES",@"rows":guides},
  @{@"title":@"ADVANCED",@"rows":@[
   @{@"title":@"Advanced Diagnostics",@"detail":@"Logs, raw traces, the PAC script and low-level checks",@"icon":@"terminal",@"page":@"MYBDiagnosticsController",@"action":@"openPage"},
   @{@"title":@"Release",@"value":@MYB_RELEASE_LABEL,@"icon":@"info.circle"}]}];
 [self.tableView reloadData];
}
- (void)localHealth{[self runHelper:@[@"systemcheck"] completion:^(int rc){[self showMessage:rc?@"MYbloXX® Needs Attention":@"MYbloXX® Is Ready" detail:rc?@"Your system configuration could not be verified. Tap Repair MYbloXX®, then check again.":@"The MYbloXX® inline PAC is applied and matches your current settings. Confirm blocking in other applications too."];}];}
// Replays the tour on this screen’s own phone: a fresh marker (new text each time) and a notification SpringBoard listens for. Tips come back too.
- (void)replayTour{
 BOOL tips=MYBTipsReplay();
 NSString *marker=MYBMobileFile(@"/var/mobile/Library/MYbloXX/WelcomePending"),*dir=marker.stringByDeletingLastPathComponent;
 [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *label=[NSString stringWithFormat:@"replay-%.0f",NSDate.date.timeIntervalSince1970];
 BOOL wrote=[label writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 if(!wrote){MYBComplete(self,NO,@"Couldn’t Start the Tour",@"The tour could not be started from here. Nothing was changed.");return;}
 [NSFileManager.defaultManager removeItemAtPath:[dir stringByAppendingPathComponent:@"TourSawRecommendation"] error:NULL];
 notify_post("net.myxxdev.mybloxx.welcome.replay");
 (void)tips;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if(row[@"url"]){[t deselectRowAtIndexPath:p animated:YES];MYBPushWeb(self,row[@"url"],row[@"title"],nil);return;}
 if(row[@"topic"]){[t deselectRowAtIndexPath:p animated:YES];UIViewController *page=[NSClassFromString(@"MYBHelpTopicController") new];[page setValue:row[@"topic"] forKey:@"index"];[self.navigationController pushViewController:page animated:YES];return;}
 if(row[@"page"]&&!self.busy){[t deselectRowAtIndexPath:p animated:YES];UIViewController *page=[NSClassFromString(row[@"page"]) new];if(page)[self.navigationController pushViewController:page animated:YES];return;}
 [super tableView:t didSelectRowAtIndexPath:p];
}
- (void)openAdTest{MYBPushWeb(self,@"https://superadblocktest.com",@"AdBlock Test",nil);} // loads directly, no confirmation
// The popup test runs in the browser the person actually uses, so it leaves the app for their default browser (no embedded web view, which
// handles popups differently). The page is MYbloXX®'s own, served from this iPhone (127.0.0.1), so it needs the local service to be running.
- (void)openPopupTest{
 // The listener is checked by asking it for the test page itself, not just by connecting to the port: the right service must answer the right route with the page.
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSData *page=MYBLoopbackGET(8788,@"/mybloxx-window-test");
  NSString *html=page.length?[[NSString alloc] initWithData:page encoding:NSUTF8StringEncoding]:nil;
  BOOL up=[html containsString:@"Popup Test"]&&[html containsString:@"</html>"];
  dispatch_async(dispatch_get_main_queue(),^{
   if(up){[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"http://127.0.0.1:8788/mybloxx-window-test"] options:@{} completionHandler:nil];return;}
   MYBConfirmWithButton(self,@"Popup Test Isn’t Ready",@"The local service on this iPhone didn’t answer with the test page. This usually means it stopped after a restart or respring. Repair MYbloXX® starts it again.",@"Repair Now",^{[self runHelper:@[@"repair"] completion:^(__unused int rc){[self rebuildMenu];}];});});});
}
- (void)resetConnection{[self confirm:@"Reset iOS Connection Cache?" message:@"This will refresh your Wi-Fi and cellular connections. Any active connection may briefly disconnect." action:^{[self runHelper:@[@"connectionreset"] completion:^(__unused int rc){[self rebuildMenu];}];}];}
- (void)repair{[self confirm:@"Repair MYbloXX®?" message:@"This rebuilds the protection from your saved settings and refreshes iOS networking. Your rules and exceptions are retained." action:^{[self runHelper:@[@"repair"] completion:^(__unused int rc){[self rebuildMenu];}];}];}
- (void)restoreDefaults{MYBConfirmDestructive(self,@"Restore Default Settings?",@"MYbloXX® returns to a fresh installation: Default mode, Shield, App Redirect Protection and automatic updates on. Your custom rules, website, popup and app exceptions, App Control choices, Proxy Override and recent activity are cleared, and In-App Ad Blocking is switched off for every app. Your saved backups in Files are kept, and the current backup is copied first. DNS profiles you installed are not removed; delete them in Settings > General > VPN & Device Management.",@"Restore Defaults",^{[self runHelper:@[@"restoredefaults"] completion:^(int rc){[self rebuildMenu];
  NSDictionary *record=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/Defaults.plist")]?:@{};
  NSDictionary *o=MYBResetOutcome(rc,record,[record[@"needsRespring"] boolValue]);[self showMessage:o[@"title"] detail:o[@"detail"]];[self rebuildMenu];}];});}
- (void)openStatusPage{
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  BOOL up=MYBProxyReachable(@"127.0.0.1",8788,1.0);
  dispatch_async(dispatch_get_main_queue(),^{
   if(up){MYBPushWeb(self,@"http://127.0.0.1:8788/mybloxx-status-page",@"Status Page",nil);return;}
   MYBConfirmWithButton(self,@"Live Status Isn’t Running",@"The local status service on this iPhone isn’t answering. This usually means it stopped after a restart or respring. Repair MYbloXX® starts it again.",@"Repair Now",^{[self repair];});});});
}
@end
