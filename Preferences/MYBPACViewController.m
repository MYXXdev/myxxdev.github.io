#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBModeNames.h"
// PAC Script: a read-only look at the script MYbloXX generates, kept strictly apart from whether iOS confirms using it.
//   GENERATED  built from the selected mode, the current rules and your Custom Rules. It exists whether or not it is in use.
//   CONFIRMED  only when the system’s own proxy settings report this exact script (the same check Status uses).
// The helper writes a short-lived snapshot; this screen reads it into memory and deletes the file at once. Nothing is
// served over HTTP, nothing is editable, and the script is never added to copied diagnostics (it holds custom domains).
@interface MYBPACTextController : UIViewController
@property(nonatomic,copy) NSString *script;
@end
@implementation MYBPACTextController
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"PAC Script";self.view.backgroundColor=MYBBackground();MYBStyleNavigation(self);
 UITextView *text=[[UITextView alloc] init];text.translatesAutoresizingMaskIntoConstraints=NO;text.backgroundColor=UIColor.clearColor;
 text.editable=NO;text.selectable=NO;text.alwaysBounceVertical=YES;text.textContainerInset=UIEdgeInsetsMake(12,MYBMargin,24,MYBMargin);
 text.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];text.adjustsFontForContentSizeCategory=NO;text.textColor=UIColor.whiteColor;
 text.text=self.script;text.accessibilityLabel=@"PAC script, read only";text.indicatorStyle=UIScrollViewIndicatorStyleWhite;
 [self.view addSubview:text];
 [NSLayoutConstraint activateConstraints:@[[text.topAnchor constraintEqualToAnchor:self.view.topAnchor],[text.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[text.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],[text.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor]]];
}
@end

@interface MYBPACViewController : MYBMenuBase
@property(nonatomic,strong) NSDictionary *snapshot;
@property(nonatomic,assign) BOOL checked;
@end
@implementation MYBPACViewController
- (NSString *)heroEyebrow{return @"Transparency";}
- (NSString *)heroTitle{return @"PAC Script";}
- (NSString *)heroDetail{return @"The script MYbloXX® generates for your settings, and whether iOS confirms using it.";}
- (NSString *)snapshotPath{return MYBMobileFile(@"/var/mobile/Library/MYbloXX/PACView.plist");}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];
 if(self.checked)return;self.checked=YES;
 __weak typeof(self) weak=self;
 [self silentHelper:@[@"pacview"] completion:^(__unused int rc){
  MYBPACViewController *strong=weak;if(!strong)return;
  NSString *path=strong.snapshotPath;NSDictionary *record=[NSDictionary dictionaryWithContentsOfFile:path];
  [NSFileManager.defaultManager removeItemAtPath:path error:NULL]; // the script holds custom domains: keep it only in memory
  strong.snapshot=record?:@{};[strong rebuildMenu];
 }];
}
- (NSString *)sizeText:(NSUInteger)bytes{return bytes>=1024?[NSString stringWithFormat:@"%.1f KB",bytes/1024.0]:[NSString stringWithFormat:@"%lu bytes",(unsigned long)bytes];}
- (void)rebuildMenu{
 self.title=@"PAC Script";
 NSDictionary *s=self.snapshot;BOOL loaded=s!=nil;
 NSString *script=[s[@"script"] isKindOfClass:NSString.class]?s[@"script"]:nil;
 NSString *mode=[s[@"mode"] isKindOfClass:NSString.class]?s[@"mode"]:nil;
 NSString *v=[s[@"verification"] isKindOfClass:NSString.class]?s[@"verification"]:@"unchecked";
 NSString *generatedTitle=!loaded?@"Reading...":script?@"View Script":@"No Script Available";
 NSString *generatedDetail=!loaded?@"Building the script from your saved settings":script?[NSString stringWithFormat:@"%@ · fingerprint %@",[self sizeText:[s[@"bytes"] unsignedIntegerValue]],[[s[@"sha256"] description] substringToIndex:MIN((NSUInteger)12,[[s[@"sha256"] description] length])]]:@"MYbloXX® could not build a script from the saved mode.";
 NSString *confirmTitle,*confirmDetail,*icon=@"questionmark.circle";MYBTone tone=MYBToneSlate;
 if(!loaded){confirmTitle=@"Checking...";confirmDetail=@"Asking iOS which script it is using";}
 else if([v isEqual:@"applied"]){confirmTitle=@"Confirmed by iOS";confirmDetail=@"iOS reports using this exact script.";icon=@"checkmark.shield";tone=MYBToneGreen;}
 else if([v isEqual:@"identity-unavailable"]){confirmTitle=@"In Use, Script Not Identifiable";confirmDetail=@"iOS reports an inline PAC but does not show which one, so it cannot be confirmed as this script.";tone=MYBToneAmber;}
 else if([v isEqual:@"stale"]){confirmTitle=@"Not Up to Date";confirmDetail=@"The script saved for iOS differs from the one generated now. Repair MYbloXX® applies the current one.";icon=@"exclamationmark.triangle";tone=MYBToneAmber;}
 else if([v isEqual:@"not-applied"]){confirmTitle=@"Not Confirmed";confirmDetail=@"iOS is not using this script right now.";icon=@"exclamationmark.triangle";tone=MYBToneAmber;}
 else{confirmTitle=@"Not Confirmed";confirmDetail=@"Protection is off, or iOS could not be checked, so nothing is confirmed.";}
 self.menuSections=@[
  @{@"title":@"GENERATED BY MYbloXX®",@"rows":@[
    @{@"title":@"Mode",@"value":mode.length?MYBModeDisplay(mode):@"Not set",@"icon":@"slider.horizontal.3"},
    @{@"title":generatedTitle,@"detail":generatedDetail,@"icon":@"doc.plaintext",@"action":script?@"openScript":@""}],
   @"footer":@"Built from the selected mode, the current rules and your Custom Rules. Generating a script does not mean iOS is using it."},
  @{@"title":@"CONFIRMED BY iOS",@"rows":@[@{@"title":confirmTitle,@"detail":confirmDetail,@"icon":icon,@"accent":@YES,@"tone":@(tone)}],
   @"footer":@"Only “Confirmed by iOS” means the system is using this script. The script is shown read-only, can include domains you added, and is not part of copied diagnostics."}];
 [self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 MYBPrismCell *cell=(MYBPrismCell *)[super tableView:t cellForRowAtIndexPath:p];
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];
 if([row[@"action"] length]){cell.mybAccessoryType=UITableViewCellAccessoryDisclosureIndicator;cell.selectionStyle=UITableViewCellSelectionStyleDefault;}
 return cell;
}
- (void)openScript{
 NSString *script=[self.snapshot[@"script"] isKindOfClass:NSString.class]?self.snapshot[@"script"]:nil;if(!script.length)return;
 MYBPACTextController *page=[MYBPACTextController new];page.script=script;[self.navigationController pushViewController:page animated:YES];
}
@end
