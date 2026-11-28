#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBTips.h"
#import "../Shared/MYBConnectivity.h"
#import "../Shared/MYBCleanupRules.h"
#import <notify.h>
// Safari Cleanup: hides named page clutter in Safari. Every switch starts OFF. It only hides things (it never presses Accept for you), it is separate from
// pop-up permissions, redirects and phone-wide domain rules, and it has two ways out for a page that needs its own banner: Pause and a per-site exception.
static NSString *CleanupFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.cleanup.plist");}
static NSDictionary *CleanupStatus(void){return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/CleanupStatus.plist")];}
@interface MYBSafariCleanupController:MYBMenuBase @end
@implementation MYBSafariCleanupController
- (NSString *)heroTitle{return @"Safari Cleanup";}
- (NSString *)heroDetail{return @"Hide cookie banners and other clutter in Safari. It only hides; it never clicks Accept for you.";}
- (NSDictionary *)config{return [NSDictionary dictionaryWithContentsOfFile:CleanupFile()]?:@{};}
- (BOOL)saveConfig:(NSDictionary *)config{BOOL ok=[config writeToFile:CleanupFile() atomically:YES];if(ok)notify_post("net.myxxdev.mybloxx.cleanup.changed");return ok;}
- (NSString *)statusLine{
 NSDictionary *status=CleanupStatus();NSDictionary *config=self.config;
 BOOL any=MYBCleanupFlag(config,@"CleanupCookies")||MYBCleanupFlag(config,@"CleanupOpenInApp")||MYBCleanupFlag(config,@"CleanupChat")||MYBCleanupFlag(config,@"CleanupNewsletter");
 if(!any)return @"Everything is off";
 if(MYBCleanupPaused(config,NSDate.date.timeIntervalSince1970))return @"Paused";
 if(!status.count)return @"Waiting for Safari. Open Safari once, then come back.";
 NSString *state=status[@"state"];
 if([state isEqual:@"active"])return [NSString stringWithFormat:@"Active in Safari · %@ rules",status[@"rules"]?:@"built-in"];
 if([state isEqual:@"rejected-kept-previous"])return @"The last rule change was refused by Safari. The previous working rules are kept.";
 return @"Safari has not applied your latest change yet. Reopen Safari.";
}
- (void)rebuildMenu{
 self.title=@"Safari Cleanup";NSDictionary *config=self.config;double now=NSDate.date.timeIntervalSince1970;BOOL paused=MYBCleanupPaused(config,now);
 NSArray *exceptions=MYBCleanupExceptions(config);
 NSMutableArray *exRows=[NSMutableArray arrayWithObject:@{@"title":@"Add Site Exception",@"detail":@"Cleanup stays off on this site and its subdomains",@"icon":@"plus.circle.fill",@"accent":@YES,@"tone":@(MYBToneGreen),@"action":@"addException"}];
 for(NSString *host in exceptions)[exRows addObject:@{@"title":host,@"detail":@"Cleanup is off here · tap to remove",@"icon":@"checkmark.circle",@"tone":@(MYBToneSlate),@"action":@"removeException"}];
 self.menuSections=@[
  @{@"title":@"HIDE IN SAFARI",@"rows":@[
   @{@"title":@"Cookie Banners",@"detail":@"Hides known cookie notices. You are not accepting or rejecting anything.",@"icon":@"checkmark.shield.fill",@"accent":@YES,@"tone":@(MYBToneTeal),@"switch":@"CleanupCookies"},
   @{@"title":@"“Open in App” Banners",@"detail":@"Hides banners a website draws itself",@"icon":@"arrow.up.forward.app.fill",@"accent":@YES,@"tone":@(MYBToneBlue),@"switch":@"CleanupOpenInApp"},
   @{@"title":@"Chat Widgets",@"detail":@"Hides floating support chat bubbles",@"icon":@"bubble.left.fill",@"accent":@YES,@"tone":@(MYBToneViolet),@"switch":@"CleanupChat"},
   @{@"title":@"Newsletter Pop-Ups",@"detail":@"Hides known sign-up overlays",@"icon":@"envelope.badge.fill",@"accent":@YES,@"tone":@(MYBToneRose),@"switch":@"CleanupNewsletter"}],
   @"footer":@"Safari’s own app suggestion banner is not touched. Rules are narrow and named, so they cover known sites and may miss others. If a page needs a choice from you, it still shows its own controls when you pause or add an exception."},
  @{@"title":@"IF A PAGE BREAKS",@"rows":@[
   @{@"title":paused?@"Resume Cleanup":@"Pause for 10 Minutes",@"detail":paused?@"Paused now":@"Turns cleanup off everywhere, then back on by itself",@"icon":paused?@"play.circle.fill":@"pause.circle.fill",@"accent":@YES,@"tone":@(MYBToneAmber),@"action":@"togglePause"}],
   @"footer":@"Reload the page after pausing. If a page is covered, cannot scroll or will not let you sign in or check out, pause cleanup and add an exception for that site."},
  @{@"title":@"SITE EXCEPTIONS",@"rows":exRows,@"footer":@"Exceptions include subdomains."},
  @{@"title":@"STATUS",@"rows":@[@{@"title":@"Safari",@"detail":[self statusLine],@"icon":@"safari.fill",@"tone":@(MYBToneSlate)}],@"footer":@"Only Safari is covered. Other browsers are not changed."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *key=row[@"switch"];MYBPrismCell *cell=[self cardForEntry:row table:t];
 if(key.length){MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.onTintColor=MYBAccent();toggle.on=MYBCleanupFlag(self.config,key);[toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];}
 return cell;
}
- (void)toggled:(MYBPrismSwitch *)toggle{
 NSMutableDictionary *config=[self.config mutableCopy];config[toggle.key]=@(toggle.on);
 if(![self saveConfig:config])MYBComplete(self,NO,@"Couldn’t save",@"Your previous setting is kept.");
 [self rebuildMenu];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *action=row[@"action"];
 NSMutableDictionary *config=[self.config mutableCopy];
 if([action isEqual:@"togglePause"]){
  if(MYBCleanupPaused(config,NSDate.date.timeIntervalSince1970))[config removeObjectForKey:@"CleanupPausedUntil"];else config[@"CleanupPausedUntil"]=@(NSDate.date.timeIntervalSince1970+600);
  if(![self saveConfig:config])MYBComplete(self,NO,@"Couldn’t save",@"Nothing was changed.");[self rebuildMenu];
 }else if([action isEqual:@"addException"]){
  MYBInput(self,@"Add Site Exception",@"Cleanup will be off for this site and its subdomains.",@[@{@"placeholder":@"example.com"}],@"Add",^(NSArray *values){
   NSString *host=MYBCleanupHost(values.firstObject);
   if(!host){MYBMessage(self,@"Not a Website",@"Enter a website such as example.com.");return;}
   NSMutableDictionary *c=[[self config] mutableCopy];NSMutableArray *list=[MYBCleanupExceptions(c) mutableCopy];if(![list containsObject:host])[list addObject:host];c[@"CleanupExceptions"]=list;
   if(![self saveConfig:c])MYBComplete(self,NO,@"Couldn’t save",@"Nothing was changed.");[self rebuildMenu];
  });
 }else if([action isEqual:@"removeException"]){
  NSString *host=row[@"title"];
  MYBConfirmWithButton(self,host,@"Turn cleanup back on for this site?",@"Remove Exception",^{
   NSMutableDictionary *c=[[self config] mutableCopy];NSMutableArray *list=[MYBCleanupExceptions(c) mutableCopy];[list removeObject:host];c[@"CleanupExceptions"]=list;
   if(![self saveConfig:c])MYBComplete(self,NO,@"Couldn’t save",@"Nothing was changed.");[self rebuildMenu];
  });
 }
}
@end
