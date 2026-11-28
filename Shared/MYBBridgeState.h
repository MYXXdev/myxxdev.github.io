// How a browser component folds the bridge's answer into its cached policy. Pure, so failure and staleness behave the
// same on a device as in the test.
//  * a good answer replaces rules, site exceptions and the bridge secret; the policy generation changes only when
//    something that affects a decision changed (so pending one-shot popup tokens are dropped exactly then);
//  * a failed answer keeps the last good policy but marks it STALE and ALWAYS changes the generation (the secret may be
//    gone, so no token issued under the old policy may be spent);
//  * a stale policy is never silently treated as fresh: callers read `stale` and diagnostics report bridge_failed.
#import <Foundation/Foundation.h>
static inline NSDictionary *MYBBridgeFold(id decoded,NSDictionary *previous,NSString **event){
 NSUInteger generation=[previous[@"generation"] unsignedIntegerValue];
 if([decoded isKindOfClass:NSDictionary.class]){
  NSDictionary *rules=[decoded[@"rules"] isKindOfClass:NSDictionary.class]?decoded[@"rules"]:@{};
  NSString *secret=[decoded[@"bridgeSecret"] isKindOfClass:NSString.class]?decoded[@"bridgeSecret"]:nil;
  NSArray *exceptions=[decoded[@"siteExceptions"] isKindOfClass:NSArray.class]?decoded[@"siteExceptions"]:@[];
  NSDictionary *policy=@{@"rules":rules,@"exceptions":exceptions,@"secret":secret?:@""};
  if(![policy isEqualToDictionary:previous[@"policy"]]||[previous[@"stale"] boolValue])generation++;
  if(event)*event=@"bridge_ready";
  return @{@"bridgeState":decoded,@"rules":rules,@"exceptions":exceptions,@"secret":secret?:@"",@"policy":policy,@"generation":@(generation),@"stale":@NO};
 }
 if(event)*event=@"bridge_failed";
 NSMutableDictionary *kept=[previous mutableCopy]?:[NSMutableDictionary dictionary];
 kept[@"rules"]=previous[@"rules"]?:@{};kept[@"exceptions"]=previous[@"exceptions"]?:@[];kept[@"secret"]=previous[@"secret"]?:@"";
 kept[@"bridgeState"]=nil;kept[@"stale"]=@YES;kept[@"generation"]=@(generation+1);
 return kept;
}
