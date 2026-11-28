// WebKit Networking refresh engine against a fake process table: exact-path matching, SIGTERM then bounded wait then SIGKILL for the
// SAME identity only, pid reuse, no match as normal, failures reported without crashing.
#import <Foundation/Foundation.h>
#import "../Shared/MYBProcessRefresh.h"
static int failures=0;
static void check(BOOL ok,NSString *m){printf("%s %s\n",ok?"PASS":"FAIL",m.UTF8String);if(!ok)failures++;}
static NSString *NET=@"/System/Library/Frameworks/WebKit.framework/XPCServices/com.apple.WebKit.Networking.xpc/com.apple.WebKit.Networking";
static NSDictionary *proc(int pid,long long start,NSString *path){return @{@"pid":@(pid),@"start":@(start),@"path":path};}
int main(void){@autoreleasepool{
 __block NSMutableArray *table;__block NSMutableArray *sent;__block int waits;__block NSMutableDictionary *ignoresTerm,*sigErr;__block NSMutableDictionary *reuseAfterTerm;
 void(^world)(NSArray *)=^(NSArray *procs){table=[procs mutableCopy];sent=[NSMutableArray array];waits=0;ignoresTerm=[NSMutableDictionary dictionary];sigErr=[NSMutableDictionary dictionary];reuseAfterTerm=[NSMutableDictionary dictionary];};
 MYBProcessRefreshEnv *(^env)(void)=^MYBProcessRefreshEnv *{
  MYBProcessRefreshEnv *e=[MYBProcessRefreshEnv new];e.steps=5;
  e.list=^NSArray *{return [table copy];};
  e.startOf=^NSNumber *(int pid){for(NSDictionary *p in table)if([p[@"pid"] intValue]==pid)return p[@"start"];return nil;};
  e.signal=^int(int pid,int sig){
   [sent addObject:@[@(pid),@(sig)]];
   if(sigErr[@(pid)])return [sigErr[@(pid)] intValue];
   if(sig==15&&reuseAfterTerm[@(pid)]){ // the process exits and the pid is taken by something else with a new start time
    for(NSUInteger i=0;i<table.count;i++)if([table[i][@"pid"] intValue]==pid)table[i]=proc(pid,[reuseAfterTerm[@(pid)] longLongValue],@"/usr/bin/other");return 0;}
   if(sig==15&&ignoresTerm[@(pid)])return 0;
   for(NSUInteger i=0;i<table.count;i++)if([table[i][@"pid"] intValue]==pid){[table removeObjectAtIndex:i];break;}
   return 0;};
  e.wait=^{waits++;};return e;};
 void(^nolog)(NSString *)=^(NSString *l){(void)l;};
 // no matching process is normal
 world(@[proc(50,1,@"/usr/libexec/other")]);MYBRefreshOutcome o=MYBRefreshWebKitNetworking(env(),nolog);
 check(o.found==0&&sent.count==0&&waits==0,@"no WebKit Networking process: nothing signalled, nothing waited for");
 // the usual case: SIGTERM is enough
 world(@[proc(100,10,NET),proc(101,11,@"/usr/bin/x")]);o=MYBRefreshWebKitNetworking(env(),nolog);
 check(o.found==1&&o.terminated==1&&o.killed==0&&[sent isEqual:@[@[@100,@15]]],@"SIGTERM only, and only to the networking process");
 // a survivor: SIGKILL after the bounded wait, same identity
 world(@[proc(100,10,NET)]);ignoresTerm[@100]=@(1);o=MYBRefreshWebKitNetworking(env(),nolog);
 check(o.killed==1&&[sent isEqual:@[@[@100,@15],@[@100,@9]]]&&waits==5,@"a survivor is force-ended after exactly the bounded wait (5 steps)");
 // pid reused after SIGTERM: never killed
 world(@[proc(100,10,NET)]);reuseAfterTerm[@100]=@99;o=MYBRefreshWebKitNetworking(env(),nolog);
 check(o.killed==0&&![sent containsObject:@[@100,@9]],@"a pid reused by another process after SIGTERM is never force-ended");
 // pid already reused before any signal (stale snapshot)
 world(@[proc(100,10,NET)]);MYBProcessRefreshEnv *stale=env();stale.list=^NSArray *{return @[proc(100,10,NET)];};table=[@[proc(100,77,NET)] mutableCopy];
 o=MYBRefreshWebKitNetworking(stale,nolog);check(o.skippedReused==1&&sent.count==0,@"a snapshot entry whose pid now has a different start time is skipped without a signal");
 // look-alikes are not matched
 world(@[proc(1,1,NET),proc(200,2,@"/System/Library/Frameworks/WebKit.framework/XPCServices/com.apple.WebKit.WebContent.xpc/com.apple.WebKit.WebContent"),proc(201,3,@"/tmp/com.apple.WebKit.Networking"),proc(202,4,@"/x/../com.apple.WebKit.Networking.xpc/com.apple.WebKit.Networking"),proc(203,5,@"/tmp/evil-com.apple.WebKit.Networking.xpc/com.apple.WebKit.Networking.sh")]);
 o=MYBRefreshWebKitNetworking(env(),nolog);check(o.found==0&&sent.count==0,@"WebContent, wrong paths, '..' paths, launchd and look-alike names are never signalled");
 // two processes
 world(@[proc(100,10,NET),proc(110,12,NET)]);ignoresTerm[@110]=@(1);o=MYBRefreshWebKitNetworking(env(),nolog);
 check(o.found==2&&o.terminated==2&&o.killed==1&&[sent containsObject:@[@110,@9]]&&![sent containsObject:@[@100,@9]],@"each process is handled by its own identity");
 // signal failure is reported, not fatal
 world(@[proc(100,10,NET)]);sigErr[@100]=@1;o=MYBRefreshWebKitNetworking(env(),nolog);
 check(o.failed>=1&&o.terminated==0,@"a refused signal is counted as a failure and nothing else happens");
 return failures?1:0;}}
