#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBProxyCheck.h"
#import "../Shared/MYBOutcomeText.h"
@interface MYBProxyOverrideController:MYBMenuBase @end
@implementation MYBProxyOverrideController
- (NSString *)file{return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.user.plist");}
- (NSString *)proxy{NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:self.file];id value=prefs?prefs[@"MYB2-proxy"]:[NSUserDefaults.standardUserDefaults objectForKey:@"MYB2-proxy"];return [value isKindOfClass:NSString.class]?value:@"";}
- (BOOL)valid:(NSString *)text{if(MYBProxyURLValid(text))return YES;return NO;}
- (BOOL)overrideSelected{NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/State.plist")];if(![state[@"mode"] isEqual:@"Custom"])return NO;for(NSString *dir in @[@"PACCurrent",@"PAC"]){NSString *path=MYBMobileFile([NSString stringWithFormat:@"/var/mobile/Library/MYbloXX/%@/Custom.pac",dir]);if([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] hasPrefix:@"// MYbloXX® Proxy Override\n"])return YES;}return NO;}
- (void)rebuildMenu{
 self.title=@"Proxy Override";
 NSString *saved=self.proxy;BOOL credentials=MYBProxyHasCredentials(saved),valid=MYBProxyURLValid(saved);NSURLComponents *url=valid?[NSURLComponents componentsWithString:saved]:nil;
 BOOL selected=self.overrideSelected;NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/State.plist")];BOOL on=[state[@"enabled"] boolValue];
 NSString *route=selected?(on?@"Override is ON":@"Override is selected, protection is off"):@"Override is OFF";
 NSString *routeDetail=selected?(on?[NSString stringWithFormat:@"All traffic goes through %@:%@. MYbloXX® blocking rules are not applied.",url.host?:@"your server",url.port?:@""]:@"Turn MYbloXX® protection on for the override to take effect."):@"MYbloXX® is filtering with its normal blocking rules.";
 NSString *serverDetail=credentials?@"The saved address has a username or password, which MYbloXX® doesn’t use. Enter the server again.":(valid?[NSString stringWithFormat:@"%@ · port %@",url.host,url.port]:@"Not set");
 self.menuSections=@[
 @{@"title":@"CURRENT STATE",@"rows":@[@{@"title":route,@"detail":routeDetail,@"icon":selected?@"network":@"checkmark.shield"}],
   @"footer":@"A proxy override sends your iPhone’s web traffic through a server you choose instead of MYbloXX®’s blocking rules. Use it only when you need a specific server, such as a work, school or home filtering proxy. While it is on, MYbloXX® blocking, custom rules and website exceptions are not applied. It is separate from DNS & Profiles, which only choose the DNS resolver, and from normal MYbloXX® blocking, where rules decide site by site."},
 @{@"title":@"YOUR PROXY SERVER",@"rows":@[@{@"title":@"Server",@"detail":serverDetail,@"icon":@"server.rack",@"action":@"editServer"}],
   @"footer":@"Example: proxy.example.com and port 8080. Only plain HTTP proxies are supported, without a username or password, so nothing secret is stored. Saving does not turn anything on."},
 @{@"title":@"TURN ON OR OFF",@"rows":@[
   @{@"title":@"Use This Proxy",@"detail":valid?(selected?@"Apply the saved server again":@"Route traffic through your server"):@"Set a server first",@"icon":@"arrow.triangle.branch",@"action":valid?@"applyProxy":@""},
   @{@"title":@"Return to MYbloXX® Filtering",@"detail":selected?@"Turn the override off and use Default mode":@"The override is already off",@"icon":@"shield.lefthalf.filled",@"action":selected?@"restoreDefault":@""}],
   @"footer":@"If the server can’t be reached while the override is on, websites and apps will not load until you turn it off here. Turning MYbloXX® protection off also turns the override off. If applying fails, your previous setup stays in place."}];
 [self.tableView reloadData];
}
- (void)editServer{
 if(self.busy)return;NSURLComponents *current=[NSURLComponents componentsWithString:self.proxy];
 MYBInput(self,@"Proxy Server",@"Enter a server you trust.",@[@{@"placeholder":@"proxy.example.com",@"value":current.host?:@""},@{@"placeholder":@"Port",@"value":current.port.stringValue?:@"8080",@"keyboard":@(UIKeyboardTypeNumberPad)}],@"Save Server",^(NSArray *values){
  NSString *host=[values[0] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],*port=[values[1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSString *problem=MYBProxyFieldProblem(host,port);if(problem){MYBMessage(self,@"Check Server Details",problem);return;}
  NSURLComponents *url=[NSURLComponents new];url.scheme=@"http";url.host=host;url.port=@(port.integerValue);if(![self valid:url.string]){MYBMessage(self,@"Check Server Details",@"Use a hostname or IP address without a path, username or password.");return;}
  NSMutableDictionary *prefs=[[NSDictionary dictionaryWithContentsOfFile:self.file] mutableCopy]?:[NSMutableDictionary dictionary];prefs[@"MYB2-proxy"]=url.string;
  if(![prefs writeToFile:self.file atomically:YES]){MYBMessage(self,@"Couldn’t Save",@"Your previous server is unchanged.");return;}[self refreshFilesBackup];[self rebuildMenu];
 });
}
- (void)applyProxy{
 if(self.busy||![self valid:self.proxy])return;NSString *address=self.proxy;NSURLComponents *u=[NSURLComponents componentsWithString:address];
 void(^apply)(void)=^{[self runHelper:@[@"proxy",address] completion:^(int rc){if(rc){NSDictionary *o=MYBProxyOutcome(rc);MYBMessage(self,o[@"title"],o[@"detail"]);}[self rebuildMenu];}];};
 [self confirm:@"Use This Proxy?" message:@"Web traffic will go through your server instead of MYbloXX® filtering. This also turns MYbloXX® protection on if it is off. You can return to normal filtering on this screen." action:^{
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
   BOOL reachable=MYBProxyReachable(u.host,u.port.integerValue,4);
   dispatch_async(dispatch_get_main_queue(),^{
    if(reachable)apply();
    else MYBConfirmDestructive(self,@"Can’t Reach This Server",[NSString stringWithFormat:@"This iPhone couldn’t connect to %@ port %@ within 4 seconds. If you apply it anyway, websites and apps stop loading until you return to MYbloXX® filtering.",u.host,u.port],@"Apply Anyway",apply);
   });
  });
 }];
}
- (void)restoreDefault{if(self.busy)return;[self runHelper:@[@"selectmode",@"Default"] completion:^(int rc){if(rc)MYBMessage(self,@"Couldn’t Turn the Override Off",[NSString stringWithFormat:@"Nothing was changed. (error %d)",rc]);[self rebuildMenu];}];}
@end
