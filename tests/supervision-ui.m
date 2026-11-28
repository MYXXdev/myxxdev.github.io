// Hide Supervision Message: the reserved space is reclaimed (not just the label hidden), the scroll position does not
// jump, and the layout is restored when the setting is off. Real UIKit in the iOS Simulator; the Settings classes
// (PSUIFooterHyperlinkView, PSListController) are not available here, so a stand-in view and table delegate exercise the
// shared layout code. Hooking the real Settings controller is verified on the iPhone only.
#import <UIKit/UIKit.h>
#import "../Shared/MYBSupervisionLayout.h"
@interface PSUIFooterHyperlinkView : UIView @end
@implementation PSUIFooterHyperlinkView @end
@interface SupTable : UIViewController<UITableViewDataSource,UITableViewDelegate>
@property UITableView *table;@property BOOL footerMode;@property BOOL hide;
@end
@implementation SupTable
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{return 3;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return 12;}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{UITableViewCell *c=[t dequeueReusableCellWithIdentifier:@"c"]?:[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];c.textLabel.text=[NSString stringWithFormat:@"Row %ld",(long)p.row];return c;}
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s{CGFloat h;if(self.hide&&MYBSupHeightOverride(t,s,YES,&h))return h;return s==0&&self.footerMode?96:20;}
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s{if(s!=0||!self.footerMode)return nil;UIView *box=[[UIView alloc] initWithFrame:CGRectMake(0,0,320,96)];PSUIFooterHyperlinkView *l=[[PSUIFooterHyperlinkView alloc] initWithFrame:CGRectMake(16,8,288,80)];l.tag=77;[box addSubview:l];return box;}
@end
@interface SupApp : UIResponder<UIApplicationDelegate> @property UIWindow *window; @end
@implementation SupApp
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o{
 (void)a;(void)o;self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];SupTable *vc=[SupTable new];self.window.rootViewController=vc;[self.window makeKeyAndVisible];
 // A timer callback, not a main-queue block: a nested run loop inside a main-queue block never drains the main queue,
 // which would hide the very asynchronous work the shipping code does.
 [NSTimer scheduledTimerWithTimeInterval:.3 repeats:NO block:^(NSTimer *timer){(void)timer;
  NSMutableArray *failures=[NSMutableArray array];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){if(!ok)[failures addObject:label];};
  void(^spin)(void)=^{for(int i=0;i<6;i++)[[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];};
  // --- A: the message is the table's header view
  UITableView *table=[[UITableView alloc] initWithFrame:self.window.bounds style:UITableViewStyleInsetGrouped];table.dataSource=vc;table.delegate=vc;vc.table=table;[vc.view addSubview:table];
  UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,table.bounds.size.width,120)];PSUIFooterHyperlinkView *link=[[PSUIFooterHyperlinkView alloc] initWithFrame:CGRectMake(16,10,table.bounds.size.width-32,100)];[header addSubview:link];table.tableHeaderView=header;[table reloadData];[table layoutIfNeeded];
  UITableView *ref=[[UITableView alloc] initWithFrame:self.window.bounds style:UITableViewStyleInsetGrouped];ref.dataSource=vc;ref.delegate=vc;[vc.view addSubview:ref];[ref reloadData];[ref layoutIfNeeded];CGFloat refContent=ref.contentSize.height,refRow=[ref rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].origin.y;[ref removeFromSuperview];
  CGFloat contentBefore=table.contentSize.height,firstRowBefore=[table rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].origin.y;
  link.hidden=YES;MYBSupApply(link,YES);spin();
  check(table.tableHeaderView==nil,@"A: the header container is removed, not just hidden");
  check(ABS(table.contentSize.height-refContent)<1,[NSString stringWithFormat:@"A: after hiding, the table is exactly as tall as one with no header (content %.0f, reference %.0f)",table.contentSize.height,refContent]);
  check(ABS([table rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].origin.y-refRow)<1,[NSString stringWithFormat:@"A: the first row sits where a header-less table puts it (reference %.0f, got %.0f)",refRow,[table rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].origin.y]);
  check(table.contentOffset.y<=-table.adjustedContentInset.top+1,@"A: at the top before, still at the top after (no scroll jump)");
  MYBSupRestoreAll();spin();
  check(table.tableHeaderView==header&&ABS(table.contentSize.height-contentBefore)<1,@"A: turning it off restores the original header and layout");
  // scrolled partway: position follows the content, never jumps past it
  [table setContentOffset:CGPointMake(0,300) animated:NO];link.hidden=YES;MYBSupApply(link,YES);spin();
  check(ABS(table.contentOffset.y-(300-(contentBefore-refContent)))<2,[NSString stringWithFormat:@"A: scrolled position follows the content (offset %.0f)",table.contentOffset.y]);
  MYBSupRestoreAll();spin();
  // --- B: the message is a section footer
  [table removeFromSuperview];vc.footerMode=YES;vc.hide=YES;UITableView *t2=[[UITableView alloc] initWithFrame:self.window.bounds style:UITableViewStyleInsetGrouped];t2.dataSource=vc;t2.delegate=vc;[vc.view addSubview:t2];[t2 reloadData];[t2 layoutIfNeeded];
  CGFloat footerBefore=CGRectGetHeight([t2 rectForFooterInSection:0]);UIView *footerView=[t2 footerViewForSection:0];PSUIFooterHyperlinkView *link2=(PSUIFooterHyperlinkView *)[t2 viewWithTag:77];
  check(footerBefore>=90&&link2!=nil,[NSString stringWithFormat:@"B: fixture has a 96pt footer holding the message (height %.0f, view %@)",footerBefore,footerView]);
  if(link2){link2.hidden=YES;MYBSupApply(link2,YES);spin();
   check(CGRectGetHeight([t2 rectForFooterInSection:0])<1,[NSString stringWithFormat:@"B: the section footer collapses to ~0 (%.1f)",CGRectGetHeight([t2 rectForFooterInSection:0])]);
   check(CGRectGetHeight([t2 rectForFooterInSection:1])>=19,@"B: other sections keep their normal footers");
   vc.hide=NO;MYBSupRestoreAll();spin();check(CGRectGetHeight([t2 rectForFooterInSection:0])>=90,@"B: turning it off restores the 96pt footer");}
  // --- C: unsupported layout (a view with no table): nothing happens, nothing crashes
  PSUIFooterHyperlinkView *orphan=[PSUIFooterHyperlinkView new];MYBSupApply(orphan,YES);MYBSupRestoreAll();check(YES,@"C: orphan view is ignored");
  // --- D: large text / width changes re-run the same code safely
  t2.frame=CGRectMake(0,0,320,self.window.bounds.size.height);vc.hide=YES;[t2 reloadData];[t2 layoutIfNeeded];spin();check(YES,@"D: width change does not crash");
  NSString *result=failures.count?[NSString stringWithFormat:@"FAIL: %@",failures]:@"PASS: header-view and section-footer collapse, restore, scroll position, orphan view";
  [result writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/supervision-result.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];NSLog(@"%@",result);
 }];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(SupApp.class));}}
