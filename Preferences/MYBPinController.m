#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "../Shared/MYBPinClient.h"
// noXXX PIN: set, change and remove a four-digit PIN. The PIN itself is checked and stored only by the privileged helper
// (Helper/MYBPin.inc). This screen reads the one public status file, which holds no secret.
@interface MYBPinController : MYBMenuBase @end
@implementation MYBPinController
- (NSDictionary *)pinState{return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/MYbloXX/PinState.plist")]?:@{};}
- (BOOL)pinEnabled{return [self.pinState[@"enabled"] boolValue];}
- (NSString *)heroEyebrow{return @"Keep noXXX on";}
- (NSString *)heroTitle{return @"noXXX PIN";}
- (NSString *)heroDetail{return self.pinEnabled?@"A four-digit PIN is required to weaken noXXX.":@"Ask for a four-digit PIN before noXXX can be weakened.";}
- (void)rebuildMenu{
 self.title=@"noXXX PIN";BOOL on=self.pinEnabled;
 NSMutableArray *rows=[NSMutableArray array];
 [rows addObject:@{@"title":on?@"Change PIN":@"Set PIN",@"detail":on?@"PIN protection is on":@"PIN protection is off",@"icon":@"lock.fill",@"tone":@(MYBToneTeal),@"action":on?@"changePIN":@"setPIN"}];
 if(on)[rows addObject:@{@"title":@"Remove PIN",@"detail":@"Needs the current PIN",@"icon":@"lock.open",@"tone":@(MYBToneBlue),@"action":@"removePIN"}];
 self.menuSections=@[
  @{@"title":@"",@"rows":rows,@"footer":@"With a PIN, leaving noXXX, turning protection off, allowing a site that noXXX blocks, adding such an Allow rule, using a Proxy Override, or restoring a backup or the defaults all ask for the PIN first. Adding more options to noXXX never does."},
  @{@"title":@"GOOD TO KNOW",@"rows":@[@{@"title":@"A forgotten PIN cannot be recovered",@"detail":@"There is no reset code. Removing MYbloXX® clears it.",@"icon":@"exclamationmark.circle",@"tone":@(MYBToneBlue)}],@"footer":@"Wrong PINs are slowed down, even after a restart. This keeps casual and accidental changes out; it cannot stop someone who has full control of the device. The PIN is never saved in a backup."}];
 [self.tableView reloadData];
}
- (void)finish:(int)rc output:(NSString *)out success:(NSString *)ok{
 if(rc==0){MYBComplete(self,YES,ok,nil);[self rebuildMenu];return;}
 MYBComplete(self,NO,@"PIN Not Saved",MYBPinOutcomeText(rc,out));[self rebuildMenu];
}
- (void)runPIN:(NSString *)action input:(NSString *)input success:(NSString *)ok{
 NSString *helper=MYBPath(@"/usr/sbin/MYXXdev/MYbloXX/MYXXdev");MYBProgress(self,@"Saving");__weak typeof(self) weak=self;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSString *out=nil;int rc=MYBPinHelperRun(helper,@[action],input,&out);dispatch_async(dispatch_get_main_queue(),^{[weak finish:rc output:out success:ok];});});
}
- (NSDictionary *)pinField:(NSString *)placeholder{return @{@"placeholder":placeholder,@"keyboard":@(UIKeyboardTypeNumberPad),@"secure":@YES};}
- (void)setPIN{
 MYBInput(self,@"Set a PIN",@"Choose four digits you will remember. There is no way to recover them.",@[[self pinField:@"New PIN"],[self pinField:@"Confirm PIN"]],@"Save PIN",^(NSArray *v){
  NSString *a=v.count>0?v[0]:@"",*b=v.count>1?v[1]:@"";
  if(!MYBPinFormatValid(a)){MYBComplete(self,NO,@"PIN Not Saved",@"A PIN is exactly four digits.");return;}
  if(![a isEqual:b]){MYBComplete(self,NO,@"PIN Not Saved",@"The two PINs are different.");return;}
  [self runPIN:@"pinset" input:a success:@"PIN Saved"];
 });
}
- (void)changePIN{
 MYBInput(self,@"Change PIN",@"Enter the current PIN, then the new one.",@[[self pinField:@"Current PIN"],[self pinField:@"New PIN"],[self pinField:@"Confirm new PIN"]],@"Save PIN",^(NSArray *v){
  NSString *old=v.count>0?v[0]:@"",*a=v.count>1?v[1]:@"",*b=v.count>2?v[2]:@"";
  if(!MYBPinFormatValid(old)||!MYBPinFormatValid(a)){MYBComplete(self,NO,@"PIN Not Saved",@"A PIN is exactly four digits.");return;}
  if(![a isEqual:b]){MYBComplete(self,NO,@"PIN Not Saved",@"The two new PINs are different.");return;}
  [self runPIN:@"pinset" input:[NSString stringWithFormat:@"%@\n%@",old,a] success:@"PIN Changed"];
 });
}
- (void)removePIN{
 MYBInput(self,@"Remove PIN",@"Enter the current PIN. noXXX will no longer ask for it.",@[[self pinField:@"Current PIN"]],@"Remove PIN",^(NSArray *v){
  NSString *old=v.count>0?v[0]:@"";if(!MYBPinFormatValid(old)){MYBComplete(self,NO,@"PIN Not Removed",@"A PIN is exactly four digits.");return;}
  [self runPIN:@"pinremove" input:old success:@"PIN Removed"];
 });
}
@end
