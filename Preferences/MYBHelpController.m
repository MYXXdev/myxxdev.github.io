#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBHelp.h"
// One help guide page: bundled, offline text for the current build. The Help & Repair screen (MYBTroubleshootingController) lists the guides.
@interface MYBHelpTopicController : MYBMenuBase
@property(nonatomic,assign) NSUInteger index;
@end
@implementation MYBHelpTopicController
- (NSDictionary *)topic{NSArray *all=MYBHelpTopics();return self.index<all.count?all[self.index]:@{};}
- (NSString *)heroEyebrow{return @"Help";}
- (NSString *)heroTitle{return self.topic[@"title"]?:@"Help";}
- (NSString *)heroDetail{return self.topic[@"detail"]?:@"";}
- (void)rebuildMenu{
 self.title=self.topic[@"title"]?:@"Help";
 NSMutableArray *sections=[NSMutableArray array];
 for(NSDictionary *block in self.topic[@"blocks"])[sections addObject:@{@"title":block[@"h"],@"rows":@[],@"footer":block[@"t"]}];
 self.menuSections=sections;[self.tableView reloadData];
}
@end
