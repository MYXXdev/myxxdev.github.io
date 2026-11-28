#import "../Shared/MYBShield.h"
// Shield bridge endpoints used by the Safari component. They mutate state (consume a one-time grant, record
// activity, create a grant), so they are NOT reachable by ordinary web pages:
//   * POST only, canonical loopback Host, no Origin / Sec-Fetch-Site header (browsers add them to cross-site requests),
//   * the X-MYbloXX-Bridge header (a page cannot send custom headers cross-origin without a CORS preflight, which is never answered),
//   * and a per-launch random secret that is only ever returned by the bridge-header-protected config route.
static NSString *bridgeSecret;
static NSString *shieldParam(NSArray<NSURLQueryItem *> *items,NSString *name,NSUInteger max){for(NSURLQueryItem *i in items)if([i.name isEqual:name]&&i.value.length<=max)return i.value;return nil;}
static BOOL bridgeAuthenticated(NSString *method,NSDictionary *headers,BOOL canonical,BOOL requirePost){
 if(!canonical||!bridgeSecret.length)return NO;if(requirePost&&![method isEqual:@"POST"])return NO;
 if(headers[@"origin"]||headers[@"sec-fetch-site"])return NO;if(![headers[@"x-mybloxx-bridge"] isEqual:@"1"])return NO;
 NSString *given=headers[@"x-mybloxx-bridge-secret"];if(given.length!=bridgeSecret.length)return NO;
 unsigned char diff=0;for(NSUInteger i=0;i<given.length;i++)diff|=(unsigned char)([given characterAtIndex:i]^[bridgeSecret characterAtIndex:i]);return diff==0; // constant-time compare
}
static NSDictionary *shieldAction(NSString *route,NSString *method,NSDictionary *headers,BOOL canonical,NSArray<NSURLQueryItem *> *q,int *status){
 *status=403;if(!bridgeAuthenticated(method,headers,canonical,YES))return nil;
 NSString *kind=shieldParam(q,@"kind",16),*source=shieldParam(q,@"source",253),*dest=shieldParam(q,@"dest",253);NSString *perms=MYBShieldPermissionsFile();
 if([route isEqual:@"/mybloxx-shield-check"]){
  if(![kind isEqual:@"popup"])return nil; // the Safari component only ever asks about popups
  NSDictionary *decision=MYBShieldDecide(perms,kind,source,dest,YES);*status=200;
  if([decision[@"verdict"] isEqual:@"allow"])return @{@"allowed":@YES,@"mode":decision[@"mode"]};
  BOOL saved=[decision[@"verdict"] isEqual:@"block"]; // a standing Always Block: refused without asking again, and shown in Recent activity
  NSString *reason=saved?@"popup-saved-block":shieldParam(q,@"reason",48);MYBShieldRecordActivity(MYBShieldActivityFile(),kind,source,dest,reason?:@"popup-strict");
  return saved?@{@"allowed":@NO,@"blocked":@YES}:@{@"allowed":@NO};
 }
 if([route isEqual:@"/mybloxx-shield-grant"]){
  if(![kind isEqual:@"popup"])return nil;NSDictionary *g=MYBShieldAddGrant(perms,kind,source,dest,shieldParam(q,@"mode",8));
  if(!g)return nil;*status=200;return @{@"ok":@YES,@"id":g[@"id"]};
 }
 return nil;
}
