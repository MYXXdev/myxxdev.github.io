#import "../Preferences/MYBDesign.h"
@interface MYBSwitchProbe : NSObject
@property NSInteger callbacks;
@property BOOL lastValue;
- (void)changed:(MYBPrismSwitch *)control;
@end
@implementation MYBSwitchProbe
- (void)changed:(MYBPrismSwitch *)control{self.callbacks++;self.lastValue=control.on;}
@end
@interface MYBSwitchTestApp : UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation MYBSwitchTestApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options{
 (void)app;(void)options;self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[UIViewController new];[self.window makeKeyAndVisible];
 dispatch_async(dispatch_get_main_queue(),^{
  NSMutableArray *failures=[NSMutableArray array];
  void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *label){if(!ok)[failures addObject:label];};
  MYBPrismSwitch *control=[MYBPrismSwitch new];control.frame=CGRectMake(20,100,60,44);[self.window.rootViewController.view addSubview:control];[control layoutIfNeeded];
  MYBSwitchProbe *probe=[MYBSwitchProbe new];[control addTarget:probe action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
  check(control.bounds.size.width>=44&&control.bounds.size.height>=44,@"usable touch area");
  check([control hitTest:CGPointMake(30,22) withEvent:nil]==control,@"track routes touch to control");
  check([control hitTest:CGPointMake(10,22) withEvent:nil]==control,@"thumb routes touch to control");
  MYBPrismCell *cell=[[MYBPrismCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.frame=CGRectMake(0,180,self.window.bounds.size.width,80);cell.mybTitleLabel.text=@"Protection";cell.mybAccessoryView=control;cell.selectionStyle=UITableViewCellSelectionStyleNone;[self.window.rootViewController.view addSubview:cell];[cell layoutIfNeeded];
  CGPoint inCell=[cell convertPoint:CGPointMake(30,22) fromView:control];check([cell hitTest:inCell withEvent:nil]==control,@"custom preference cell routes accessory touches to switch");
  [control sendActionsForControlEvents:UIControlEventTouchUpInside];check(control.on&&probe.callbacks==1&&probe.lastValue,@"tap enables and sends one original callback");
  [control sendActionsForControlEvents:UIControlEventTouchUpInside];check(!control.on&&probe.callbacks==2&&!probe.lastValue,@"second tap disables");
  [control setOn:YES animated:NO];check(control.on&&probe.callbacks==2,@"programmatic change does not fire user callback");
  control.enabled=NO;[control sendActionsForControlEvents:UIControlEventTouchUpInside];check(control.on&&probe.callbacks==2,@"disabled control ignores tap");check(![control accessibilityActivate],@"disabled VoiceOver does not toggle");
  control.enabled=YES;check([control accessibilityActivate]&&!control.on&&probe.callbacks==3,@"VoiceOver toggles and sends one callback");
  check([control.accessibilityValue isEqual:@"Off"],@"VoiceOver state matches control");
  NSString *result=failures.count?[NSString stringWithFormat:@"FAIL: %@",failures]:@"PASS: touch hit-testing, tap callbacks, programmatic state, disabled state and VoiceOver";
  NSString *file=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/switch-result.txt"];[result writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];NSLog(@"%@",result);exit(failures.count?1:0);
 });return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(MYBSwitchTestApp.class));}}
