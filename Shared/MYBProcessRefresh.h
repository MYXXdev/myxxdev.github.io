#pragma once
// Refreshing the WebKit network process after a committed protection change, so browsers stop using a connection or proxy decision
// that was made under the old rules. Pure logic over a small environment object (the helper binds the real process table; tests bind a
// fake one). Rules:
//   * only processes whose EXECUTABLE PATH is exactly the WebKit Networking service are touched (never a name guess);
//   * a process is identified by pid AND start time, so a pid that was reused by something else is never signalled;
//   * SIGTERM first, a short bounded wait, then SIGKILL only for the same surviving identities, re-verified just before the signal;
//   * no matching process is normal; failures are reported but never fail a change that is already committed.
#import <Foundation/Foundation.h>
#define MYB_WEBKIT_NETWORKING_PATH_SUFFIX @"/com.apple.WebKit.Networking.xpc/com.apple.WebKit.Networking"

@interface MYBProcessRefreshEnv : NSObject
@property(copy) NSArray<NSDictionary *> *(^list)(void);         // [{pid:NSNumber, start:NSNumber (identity), path:NSString}]
@property(copy) NSNumber *(^startOf)(int);                       // current start identity of a pid, or nil when it is gone
@property(copy) int (^signal)(int,int);                          // pid, signal -> errno (0 = sent)
@property(copy) void (^wait)(void);                              // one bounded wait step
@property int steps;
@end
@implementation MYBProcessRefreshEnv @end

typedef struct {int found,terminated,killed,failed,skippedReused;} MYBRefreshOutcome;

static inline BOOL MYBRefreshMatchesPath(NSString *path){return [path isKindOfClass:NSString.class]&&[path hasSuffix:MYB_WEBKIT_NETWORKING_PATH_SUFFIX]&&![path containsString:@".."];}
static inline BOOL MYBRefreshSameIdentity(MYBProcessRefreshEnv *e,NSDictionary *target){
 NSNumber *now=e.startOf([target[@"pid"] intValue]);return now&&[now isEqual:target[@"start"]];
}
static inline MYBRefreshOutcome MYBRefreshWebKitNetworking(MYBProcessRefreshEnv *e,void(^log)(NSString *)){
 MYBRefreshOutcome out={0,0,0,0,0};
 NSMutableArray *targets=[NSMutableArray array];
 for(NSDictionary *p in (e.list()?:@[]))if([p[@"pid"] intValue]>1&&MYBRefreshMatchesPath(p[@"path"]))[targets addObject:p];
 out.found=(int)targets.count;if(!targets.count){log(@"WEBKIT_REFRESH: no WebKit Networking process is running; nothing to do");return out;}
 for(NSDictionary *t in targets){
  if(!MYBRefreshSameIdentity(e,t)){out.skippedReused++;continue;}
  int err=e.signal([t[@"pid"] intValue],15);if(err==0)out.terminated++;else{out.failed++;log([NSString stringWithFormat:@"WEBKIT_REFRESH: SIGTERM to %@ failed (%d)",t[@"pid"],err]);}
 }
 NSMutableArray *alive=[targets mutableCopy];
 for(int i=0;i<=e.steps;i++){
  [alive filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *t,id bindings){(void)bindings;return MYBRefreshSameIdentity(e,t);}]];
  if(!alive.count)break;if(i<e.steps)e.wait();
 }
 for(NSDictionary *t in alive){
  if(!MYBRefreshSameIdentity(e,t)){out.skippedReused++;continue;} // re-verified immediately before the signal
  if(e.signal([t[@"pid"] intValue],9)==0)out.killed++;else out.failed++;
 }
 log([NSString stringWithFormat:@"WEBKIT_REFRESH: found %d, terminated %d, force-ended %d, failed %d, skipped (pid reused) %d",out.found,out.terminated,out.killed,out.failed,out.skippedReused]);
 return out;
}
