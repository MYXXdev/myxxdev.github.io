#import "../Shared/MYBAppControl.h"
static void need(BOOL ok,const char *text){if(!ok){fprintf(stderr,"FAIL: %s\n",text);exit(1);}}
int main(void){@autoreleasepool{
 NSDictionary *legacy=@{@"Enabled":@NO,@"AppControlEnabled":@NO,@"enabled-game.example":@YES,@"game.example-VideoRate":@8,@"game.example-ForceInline":@YES};
 need(MYBAppControlSelected(legacy,@"game.example"),"old master-off values do not disable the always-on service");
 need(!MYBAppControlSelected(legacy,@"other.app")&&!MYBAppControlSelected(legacy,@"com.apple.springboard")&&!MYBAppControlSelected(legacy,@"com.apple.Preferences"),"only chosen apps use App Control");
 NSDictionary *choices=MYBAppControlChoices(legacy);need(choices.count==1&&[choices[@"enabled-game.example"] boolValue],"migrate app choices and remove all obsolete tuning keys");
 NSMutableDictionary *removal=[choices mutableCopy];removal[@"Uninstalling"]=@YES;
 need(!MYBAppControlSelected(removal,@"game.example"),"internal removal gate quiesces the always-on service");
 NSDate *now=[NSDate date];NSDictionary *session=MYBAppControlPlan(choices,@{},YES,@"Default",@"game.example",now)[@"session"];
 need([MYBAppControlPlan(removal,session,NO,@"Default",@"game.example",now)[@"action"] isEqual:@"restore"],"uninstall gate still supports safe restoration");
 need(MYBAccelerationMultiplier==100,@"fixed multiplier".UTF8String);
 puts("Always-on App Control, legacy preference migration, per-app selection and uninstall gate passed");return 0;
}}
