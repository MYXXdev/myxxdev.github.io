#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBModeCatalog.h"
// Exact Differences: what each blocking mode adds to Default. The modes themselves are chosen inline on the dashboard
// (MYBModernController.m); PAC contents and stored mode identifiers are untouched by that presentation.
@interface MYBModeInfoController : MYBMenuBase @end
@implementation MYBModeInfoController
- (NSString *)heroDetail{return @"What each mode adds to the Default protection.";}
- (void)rebuildMenu{
 self.title=@"Exact Differences";
 NSMutableArray *rows=[NSMutableArray array];
 for(NSDictionary *m in MYBModeTable())[rows addObject:@{@"title":MYBModeName(m[@"mode"]),@"detail":m[@"long"],@"icon":m[@"icon"]}];
 self.menuSections=@[@{@"title":@"",@"rows":rows}];
 [self.tableView reloadData];
}
@end
