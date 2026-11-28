#import "MYBMenuBase.h"
#import "MYBDesign.h"
// More Settings: the deeper tools. Backup, updates, recovery and help are on the main page; this page is for people who change how the phone connects.
@interface MYBMoreSettingsController : MYBMenuBase @end
@implementation MYBMoreSettingsController
- (NSString *)heroTitle{return @"More Settings";}
- (NSString *)heroDetail{return @"Deeper tools. Most people never need these.";}
- (void)rebuildMenu{
 self.title=@"More Settings";
 self.menuSections=@[
  @{@"title":@"PROTECT THESE SETTINGS",@"rows":@[
    @{@"title":@"PIN Protection",@"detail":@"Ask for a PIN before protection can be weakened",@"icon":@"lock.fill",@"page":@"MYBPinController",@"action":@"openPage"}]},
  @{@"title":@"NETWORK TOOLS",@"rows":@[
    @{@"title":@"DNS Profiles",@"detail":@"Choose the DNS for the whole iPhone",@"icon":@"globe",@"page":@"MYBDNSController",@"action":@"openPage"},
    @{@"title":@"Proxy Override",@"detail":@"Send web traffic through your own proxy",@"icon":@"network",@"page":@"MYBProxyOverrideController",@"action":@"openPage"},
    @{@"title":@"Connectivity",@"detail":@"Per-app network access and Personal Hotspot",@"icon":@"antenna.radiowaves.left.and.right",@"page":@"MYBConnectivityController",@"action":@"openPage"}],
   @"footer":@"These change how your iPhone connects. If something stops working after changing one, open Help & Repair on the main page."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
@end

// Backup & Updates: the two things that keep your settings safe and current, together on one page.
@interface MYBBackupUpdatesController : MYBMenuBase @end
@implementation MYBBackupUpdatesController
- (NSString *)heroTitle{return @"Backup & Updates";}
- (NSString *)heroDetail{return @"Keep your settings safe and MYbloXX® up to date.";}
- (void)rebuildMenu{
 self.title=@"Backup & Updates";
 self.menuSections=@[
  @{@"title":@"BACKUP",@"rows":@[
    @{@"title":@"Backup & Restore",@"detail":@"Save your settings to Files, or bring them back",@"icon":@"externaldrive",@"page":@"MYBBackupController",@"action":@"openPage"}]},
  @{@"title":@"UPDATES",@"rows":@[
    @{@"title":@"Updates",@"detail":@"Automatic updates",@"icon":@"arrow.down.circle",@"page":@"MYBUpdatesController",@"action":@"openPage"}]}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];}
@end
