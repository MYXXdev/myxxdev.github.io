#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBPACStamp.h"
@interface MYBUpdatesController : MYBMenuBase @end
@implementation MYBUpdatesController
- (NSDictionary *)state{return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/Updates.plist")]?:@{};}
// The date of the rules actually in use, read from the active Default PAC: UTC, whatever format wrote it.
- (NSString *)rulesDate{
 for(NSString *path in @[@"/var/mobile/Library/MYbloXX/PACCurrent/Default.pac",@"/var/mobile/Library/MYbloXX/PAC/Default.pac"]){
  NSData *data=[NSData dataWithContentsOfFile:MYBMobileFile(path)];long long stamp=MYBPACStamp(data);if(stamp>0)return MYBPACStampText(stamp);
 }
 return @"unknown";
}
- (NSString *)heroEyebrow{return @"Stay current";}
- (NSString *)heroTitle{return @"Automatic Updates";}
- (NSString *)heroDetail{return @"Protection rules refresh once a day.";}
- (void)rebuildMenu{
 self.title=@"Automatic Updates";NSDictionary *state=self.state;NSDate *date=state[@"lastCheck"]?:state[@"lastSuccess"];
 NSString *last=[date isKindOfClass:NSDate.class]?[NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle]:@"Not checked yet";
 self.menuSections=@[
  @{@"title":@"",@"rows":@[@{@"title":@"Automatic Updates",@"detail":@"Check once a day while jailbroken",@"icon":@"arrow.triangle.2.circlepath",@"tone":@(MYBToneTeal),@"switch":@"automatic"}],@"footer":@"Your custom rules are always kept."},
  @{@"title":@"MANUAL CHECK",@"rows":@[@{@"title":self.busy?@"Checking Updates":@"Check Now",@"detail":[@"Last checked: " stringByAppendingString:last],@"icon":@"arrow.down.circle",@"tone":@(MYBToneBlue),@"action":@"checkNow"}],@"footer":[NSString stringWithFormat:@"Protection rules dated %@.%@",[self rulesDate],[state[@"lastResult"] isKindOfClass:NSString.class]&&[state[@"lastResult"] length]?[@" Last result: " stringByAppendingString:state[@"lastResult"]]:@""]}];
 [self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *entry=self.menuSections[p.section][@"rows"][p.row];
 MYBPrismCell *cell=[self cardForEntry:entry table:t];
 if(entry[@"switch"]){
  MYBPrismSwitch *control=[MYBPrismSwitch new];control.key=@"automatic";control.on=[self.state[@"automatic"] boolValue];control.enabled=!self.busy;control.onTintColor=MYBAccent();
  [control addTarget:self action:@selector(toggleAutomatic:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=control;cell.selectionStyle=UITableViewCellSelectionStyleNone;
 }
 [cell refreshContent];return cell;
}
- (void)toggleAutomatic:(MYBPrismSwitch *)control{
 // Ask the helper for the state the switch now shows, not "the opposite of what is on disk":
 // that way a double tap or a stale file can never leave the switch and the policy disagreeing.
 [self runHelper:@[@"updatepolicy",control.on?@"on":@"off"] completion:nil];
}
- (void)checkNow{
 NSDate *oldSuccess=[self.state[@"lastSuccess"] copy];
 [self runHelper:@[@"updatecheck"] completion:^(int rc){
  NSString *detail=[self.state[@"lastResult"] isKindOfClass:NSString.class]?self.state[@"lastResult"]:nil;
  if(rc&&!detail.length)detail=[NSString stringWithFormat:@"The previous rules remain active (error %d). See control.log.",rc];
  // Only an installed generation counts as an update; an unrelated upstream commit or an unchanged rules file does not.
  BOOL changed=[self.state[@"lastSuccess"] isKindOfClass:NSDate.class]&&![oldSuccess isEqual:self.state[@"lastSuccess"]];
  [self showMessage:rc?@"Couldn’t Check Updates":changed?@"MYbloXX® Updated":@"MYbloXX® is up to date" detail:rc?detail:changed?@"The latest protection rules are installed. Your custom rules are unchanged.":@"You’re using the latest protection rules."];
 }];
}
@end
