#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBDefaults.h"
#import <notify.h>
// Popup Strictness: pick one policy. The wording mirrors MYBShieldPopupVerdict (Shared/MYBShield.h) exactly:
//   Strict   blocks every new window until the site is allowed.
//   Standard allows a window opened by a tap; blocks one opened without a tap, or going to a site you block.
@interface MYBPopupStrictnessController : MYBMenuBase @end
@implementation MYBPopupStrictnessController
- (NSString *)file{return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist");}
- (NSString *)heroEyebrow{return @"Shield";}
- (NSString *)heroTitle{return @"Popup Strictness";}
- (NSString *)heroDetail{return @"Choose how new browser windows are handled when Block Popups is on.";}
- (NSString *)selected{return MYBShieldPopupMode([NSDictionary dictionaryWithContentsOfFile:self.file]?:@{});}
- (void)rebuildMenu{
 self.title=@"Popup Strictness";
 self.menuSections=@[@{@"title":@"",@"rows":@[
   @{@"title":@"Strict",@"detail":@"Blocks every new window until you allow the site.",@"icon":@"shield.lefthalf.filled",@"mode":@"strict"},
   @{@"title":@"Standard",@"detail":@"Lets a window you opened with a tap through. Blocks windows that open on their own, and windows going to sites you block.",@"icon":@"hand.tap",@"mode":@"standard"}],
  @"footer":@"Whatever you choose, you can allow a site once or always from the notice that appears when a window is blocked. Strict is the recommended default."}];
 [self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];MYBPrismCell *cell=[self cardForEntry:row table:t];
 BOOL on=[[self selected] isEqual:row[@"mode"]];
 cell.tone=on?MYBToneViolet:MYBToneSlate;cell.mybAccessoryType=on?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
 cell.selectionStyle=UITableViewCellSelectionStyleDefault;cell.accessibilityTraits=on?UIAccessibilityTraitSelected:UIAccessibilityTraitNone;
 [cell refreshContent];return cell;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];
 NSString *mode=self.menuSections[p.section][@"rows"][p.row][@"mode"];if([mode isEqual:[self selected]])return;
 // Read-modify-write the Shield preferences so every other saved value (rules, switches, exceptions) is kept as it is.
 NSMutableDictionary *saved=[[NSDictionary dictionaryWithContentsOfFile:self.file] mutableCopy]?:[NSMutableDictionary dictionary];saved[@"PopupMode"]=mode;
 if(![saved writeToFile:self.file atomically:YES]){[self showMessage:@"Couldn’t Save" detail:@"Your previous popup setting is unchanged."];[self rebuildMenu];return;}
 notify_post("net.myxxdev.mybloxx.safariguard.changed");[self refreshFilesBackup];[self rebuildMenu];
}
@end
