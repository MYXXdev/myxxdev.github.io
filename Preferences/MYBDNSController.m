#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBWeb.h"
// DNS Profiles. The original MYbloXX offered three DNS shortcuts (Cloudflare, Google, Quad9) that opened hosted profiles.
// They are bundled and served from this iPhone again. The profile file is local; the DNS provider it names is external.
@interface MYBDNSController : MYBMenuBase @end
@implementation MYBDNSController
- (NSString *)heroEyebrow{return @"Network";}
- (NSString *)heroTitle{return @"DNS Profiles";}
- (NSString *)heroDetail{return @"Choose which DNS resolver iOS uses.";}
static NSArray<NSString *> *MYBDNSProfileNamesList(void){return @[@"Cloudflare",@"Google",@"Quad9"];} // the three rows below
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];MYBRefreshProfileStatus(self,@"dns",MYBDNSProfileNamesList(),nil);}
- (void)rebuildMenu{
 self.title=@"DNS Profiles";
 self.menuSections=@[
 @{@"title":@"ENCRYPTED DNS",@"footer":@"The profile file is hosted on this iPhone by MYbloXX®; the DNS provider you pick is an outside service that will see your device’s DNS lookups. iOS shows the profile and asks you to install it in Settings. Only one DNS profile is used at a time.",@"rows":@[
  @{@"title":@"Cloudflare 1.1.1.1",@"detail":[@"Fast, privacy-focused resolver · " stringByAppendingString:MYBProfileStatusText(@"dns",@"Cloudflare")],@"icon":@"cloud",@"tone":@(MYBToneAmber),@"profile":@"Cloudflare",@"provider":@"Cloudflare"},
  @{@"title":@"Google Public DNS",@"detail":[@"Widely available general-purpose resolver · " stringByAppendingString:MYBProfileStatusText(@"dns",@"Google")],@"icon":@"globe",@"tone":@(MYBToneBlue),@"profile":@"Google",@"provider":@"Google"},
  @{@"title":@"Quad9",@"detail":[@"Also blocks known malicious domains · " stringByAppendingString:MYBProfileStatusText(@"dns",@"Quad9")],@"icon":@"shield.lefthalf.filled",@"tone":@(MYBToneTeal),@"profile":@"Quad9",@"provider":@"Quad9"}]},
 @{@"title":@"HOW IT FITS WITH MYbloXX®",@"footer":@"A DNS profile only chooses the resolver for the whole iPhone (Wi-Fi and cellular). It does not turn MYbloXX® blocking on or off, does not change your blocking mode or Proxy Override, and is separate from them. Legacy PAC profiles are in Legacy Mode. To stop using a DNS profile, open Settings > General > VPN & Device Management, choose the profile and tap Remove Profile. Uninstalling MYbloXX® or restoring default settings does not remove a profile you installed.",@"rows":@[
  ]}];
 [self.tableView reloadData];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 if(p.section!=0){[super tableView:t didSelectRowAtIndexPath:p];return;}
 [t deselectRowAtIndexPath:p animated:YES];if(self.busy)return;
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *name=row[@"profile"],*provider=row[@"provider"];
 [self confirm:[NSString stringWithFormat:@"Install %@ DNS?",row[@"title"]] message:[NSString stringWithFormat:@"MYbloXX® hands the DNS profile to iOS and opens Settings at it. Review it there and tap Install; iOS asks you to confirm. If another profile is waiting under Profile Downloaded, this one replaces it. After that your DNS lookups go to %@. You can remove it any time in Settings > General > VPN & Device Management.",provider] action:^{
  MYBDeliverProfileFile(self,@"dns",name,[NSString stringWithFormat:@"%@ DNS",row[@"title"]],nil);
 }];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 MYBPrismCell *cell=(MYBPrismCell *)[super tableView:t cellForRowAtIndexPath:p];
 if(p.section==0){cell.mybAccessoryType=UITableViewCellAccessoryDisclosureIndicator;cell.selectionStyle=UITableViewCellSelectionStyleDefault;}
 return cell;
}
@end
