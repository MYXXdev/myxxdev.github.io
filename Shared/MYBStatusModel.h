// One structured status model for every surface that reports protection (Settings dashboard, diagnostics,
// Control Centre). It maps explicit machine-readable fields - never English message prefixes - to a kind, a short
// title, an explanation, a tone and two flags: `active` (the system is verifiably using MYbloXX’s rules) and
// `refresh` (a fresh helper verification would resolve the state). No kind is a bare "checking": every state
// either is a result or names the condition that prevents one.
//
// Input: the dictionary from MYBRuntimeStatusMirrored() - state, verification, mirrored, mirrorAge, verifiedAge.
//   intended     the user’s saved intent (State.plist enabled)
//   refreshError nil, or the exit status of the last attempt to ask the helper to publish a verification
#import <Foundation/Foundation.h>
#define MYB_STATUS_AWAIT_MAX_AGE 45.0   // seconds a published record may be and still count as "just applied, awaiting"
static inline NSDictionary *MYBStatusModel(NSDictionary *runtime,BOOL intended,NSNumber *refreshError){
 NSString *state=[runtime[@"state"] isKindOfClass:NSString.class]?runtime[@"state"]:@"error";
 NSString *verification=[runtime[@"verification"] isKindOfClass:NSString.class]?runtime[@"verification"]:nil;
 NSNumber *mirrorAge=[runtime[@"mirrorAge"] isKindOfClass:NSNumber.class]?runtime[@"mirrorAge"]:nil;
 #define MODEL(k,t,d,tone,act,ref) return @{@"kind":k,@"title":t,@"detail":d,@"tone":tone,@"active":@(act),@"refresh":@(ref)}
 if([state isEqual:@"configured"]){
  if([verification isEqual:@"applied"])MODEL(@"applied-verified",@"Enabled",@"The system is using MYbloXX®'s current rules (verified).",@"positive",YES,NO);
  if([verification isEqual:@"identity-unavailable"])MODEL(@"applied-unidentified",@"Protection applied",@"MYbloXX®'s configuration is installed and iOS is using a proxy script, but iOS does not let MYbloXX® confirm which rules it holds. This is not a verified result.",@"neutral",YES,NO);
  if([verification isEqual:@"stale"])MODEL(@"stale",@"Needs attention",@"The system is using older rules than MYbloXX® has. Repair re-applies the current ones.",@"warning",NO,YES);
  if([verification isEqual:@"not-applied"])MODEL(@"not-applied",@"Needs attention",@"MYbloXX® is configured, but the system is not using it. Repair re-applies it.",@"warning",NO,YES);
  if(refreshError&&refreshError.intValue!=0)MODEL(@"verification-unavailable",@"Can’t confirm protection",([NSString stringWithFormat:@"Configured, but the helper that confirms it could not run (error %d).",refreshError.intValue]),@"warning",NO,NO);
  if(mirrorAge&&mirrorAge.doubleValue>=0&&mirrorAge.doubleValue<=MYB_STATUS_AWAIT_MAX_AGE)MODEL(@"configured-awaiting",@"Confirming protection",@"Configured. Waiting for the system to confirm it is in use.",@"neutral",NO,YES);
  MODEL(@"verification-unavailable",@"Can’t confirm protection",@"Configured, but the background service has not reported recently.",@"warning",NO,YES);
 }
 if([state isEqual:@"disabled"]){
  if(intended)MODEL(@"not-applied",@"Needs attention",@"Protection is on in Settings but no configuration is installed. Repair re-applies it.",@"warning",NO,YES);
  MODEL(@"disabled",@"Disabled",@"",@"neutral",NO,NO);
 }
 if([state isEqual:@"target-missing"])MODEL(@"config-missing",@"Needs attention",@"The runtime configuration is missing. This is normal after a reboot until it is restored; Repair re-applies it.",@"warning",NO,YES);
 if([state isEqual:@"target-invalid"])MODEL(@"config-invalid",@"Needs attention",@"The runtime configuration is not valid. Repair rebuilds it from your saved settings.",@"warning",NO,YES);
 if([state isEqual:@"legacy-url"])MODEL(@"legacy",@"Needs attention",@"An older configuration is still installed. Repair updates it.",@"warning",NO,NO);
 if([state isEqual:@"experiment"])MODEL(@"experiment",@"Experiment active",@"The inline-PAC experiment is in control. Roll it back before using MYbloXX®.",@"warning",NO,NO);
 if([state isEqual:@"foreign"])MODEL(@"foreign",@"Another configuration",@"A configuration that is not MYbloXX®'s is installed. MYbloXX® leaves it alone.",@"warning",NO,NO);
 if([state isEqual:@"unverified"]){
  if(refreshError&&refreshError.intValue!=0)MODEL(@"verification-unavailable",@"Can’t confirm protection",([NSString stringWithFormat:@"Settings cannot read the system configuration and the helper did not answer (error %d).",refreshError.intValue]),@"warning",NO,NO);
  MODEL(@"verification-unavailable",@"Can’t confirm protection",@"Settings cannot read the system configuration and has no recent report from the helper.",@"warning",NO,YES);
 }
 MODEL(@"error",@"Status unreadable",@"The protection state could not be read. Repair or reopen Settings.",@"warning",NO,YES);
 #undef MODEL
}
