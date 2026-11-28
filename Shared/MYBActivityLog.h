#pragma once
// Activity list. The blocking service sees every request the PAC sends to it, so it can count which websites were blocked
// and, while "Watch everything" is on, which were allowed. On by default; the person can turn it off in Settings (a marker file
// records that choice). Stored on this device only, as website name + counts + first/last time + the app that asked; never a
// full address, a path or a query. Capped at 300 websites and 24 hours: anything older is dropped automatically.
// Not part of backups or reports.
#import <Foundation/Foundation.h>
#import "MYBShield.h"
#define MYB_ACTIVITY_MAX_HOSTS 300
#define MYB_ACTIVITY_MAX_AGE (24*3600.0)
static inline NSString *MYBActivityFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/BlockedActivity.plist");}
// Always on. There is no switch: the list keeps itself to names only and clears itself every 24 hours.
static inline BOOL MYBActivityEnabled(void){return YES;}
// The same answer, looked up at most every 3 seconds, for the per-request path.
static inline BOOL MYBActivityEnabledFast(void){
 static double checked;static BOOL on=YES;static dispatch_once_t once;static NSLock *lock;dispatch_once(&once,^{lock=[NSLock new];});
 [lock lock];double now=NSDate.date.timeIntervalSince1970;if(now-checked>3||now<checked){on=MYBActivityEnabled();checked=now;}BOOL r=on;[lock unlock];return r;
}
// A plain DNS-style host only: lowercase letters, digits, dots and hyphens, with at least one dot. Ports are dropped.
static inline NSString *MYBActivityHost(NSString *raw){
 if(![raw isKindOfClass:NSString.class]||!raw.length||raw.length>300)return nil;
 NSString *h=raw.lowercaseString;NSRange colon=[h rangeOfString:@":" options:NSBackwardsSearch];if(colon.location!=NSNotFound)h=[h substringToIndex:colon.location];
 while([h hasSuffix:@"."])h=[h substringToIndex:h.length-1];
 if(h.length<3||h.length>253||[h rangeOfString:@"."].location==NSNotFound)return nil;
 if([h rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"].invertedSet].location!=NSNotFound)return nil;
 if([h hasPrefix:@"."]||[h hasPrefix:@"-"]||[h containsString:@".."])return nil;
 return h;
}
// One stored website, in the current shape: @{b,a,first,last,apps:{name:{b,a}}}. Older entries (a plain count, apps as plain numbers) are read as blocked.
static inline NSDictionary *MYBActivityNorm(id raw){
 if(![raw isKindOfClass:NSDictionary.class])return nil;NSDictionary *e=raw;
 NSInteger blocked=e[@"b"]?[e[@"b"] integerValue]:[e[@"count"] integerValue],allowed=[e[@"a"] integerValue];
 NSMutableDictionary *apps=[NSMutableDictionary dictionary];
 if([e[@"apps"] isKindOfClass:NSDictionary.class])for(NSString *name in e[@"apps"]){
  id v=e[@"apps"][name];
  if([v isKindOfClass:NSDictionary.class])apps[name]=@{@"b":@([v[@"b"] integerValue]),@"a":@([v[@"a"] integerValue])};
  else if([v isKindOfClass:NSNumber.class])apps[name]=@{@"b":@([v integerValue]),@"a":@0};
 }
 return @{@"b":@(blocked),@"a":@(allowed),@"first":e[@"first"]?:@0,@"last":e[@"last"]?:@0,@"apps":apps};
}
static inline NSDictionary *MYBActivityRead(NSString *path){
 NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:path];return [root isKindOfClass:NSDictionary.class]?root:@{};
}
static inline void MYBActivityWrite(NSString *path,NSDictionary *hosts,NSDictionary *ids){
 if(!hosts.count){[NSFileManager.defaultManager removeItemAtPath:path error:NULL];return;}
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"version":@2,@"hosts":hosts,@"ids":ids?:@{}} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
 if(data&&[data writeToFile:path atomically:YES])MYBShieldHandOver(path,0644);
}
// Merges counted websites into the stored file: keeps the newest MYB_ACTIVITY_MAX_HOSTS and drops anything older than 24 hours.
// `counts` is host -> @{b,a,apps:{name:{b,a}}}; `ids` is app name -> bundle identifier (for the app's icon).
static inline void MYBActivityMerge(NSString *path,NSDictionary<NSString *,NSDictionary *> *counts,NSDictionary<NSString *,NSString *> *ids,double now){
 if(!counts.count)return;int lock=MYBShieldLock(path);if(lock<0)return;
 NSDictionary *root=MYBActivityRead(path);NSMutableDictionary *hosts=[NSMutableDictionary dictionary],*known=[([root[@"ids"] isKindOfClass:NSDictionary.class]?root[@"ids"]:@{}) mutableCopy];
 NSDictionary *stored=[root[@"hosts"] isKindOfClass:NSDictionary.class]?root[@"hosts"]:@{};for(NSString *h in stored){NSDictionary *n=MYBActivityNorm(stored[h]);if(n)hosts[h]=n;}
 for(NSString *host in counts){
  NSDictionary *old=hosts[host],*add=counts[host];NSMutableDictionary *apps=[([old[@"apps"] isKindOfClass:NSDictionary.class]?old[@"apps"]:@{}) mutableCopy];
  for(NSString *app in add[@"apps"]){NSDictionary *o=apps[app],*n=add[@"apps"][app];apps[app]=@{@"b":@([o[@"b"] integerValue]+[n[@"b"] integerValue]),@"a":@([o[@"a"] integerValue]+[n[@"a"] integerValue])};}
  hosts[host]=@{@"b":@([old[@"b"] integerValue]+[add[@"b"] integerValue]),@"a":@([old[@"a"] integerValue]+[add[@"a"] integerValue]),@"first":old[@"first"]?:@(now),@"last":@(now),@"apps":apps};
 }
 for(NSString *k in ids)if(ids[k].length&&known.count<400)known[k]=ids[k];
 for(NSString *host in hosts.allKeys)if(now-[hosts[host][@"last"] doubleValue]>MYB_ACTIVITY_MAX_AGE)[hosts removeObjectForKey:host];
 if(hosts.count>MYB_ACTIVITY_MAX_HOSTS){
  NSArray *oldest=[hosts keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"last"] compare:b[@"last"]];}];
  for(NSUInteger i=0;i<oldest.count-MYB_ACTIVITY_MAX_HOSTS;i++)[hosts removeObjectForKey:oldest[i]];
 }
 MYBActivityWrite(path,hosts,known);MYBShieldUnlock(lock);
}
// Called for every request the service answers or passes on. Counts in memory and writes at most every 5 seconds.
// `app` is @{name,id} from the app lookup, or nil when the app could not be told. `allowed` is NO for a blocked request.
static inline void MYBActivityNote(NSString *rawHost,NSDictionary *app,BOOL allowed){
 static NSMutableDictionary<NSString *,NSMutableDictionary *> *pending;static NSMutableDictionary<NSString *,NSString *> *pendingIDs;static dispatch_queue_t queue;static dispatch_once_t once;static double checked;static BOOL on;
 dispatch_once(&once,^{pending=[NSMutableDictionary dictionary];pendingIDs=[NSMutableDictionary dictionary];queue=dispatch_queue_create("net.myxxdev.mybloxx.activity",DISPATCH_QUEUE_SERIAL);});
 NSString *host=MYBActivityHost(rawHost);if(!host)return;
 NSString *name=[app[@"name"] isKindOfClass:NSString.class]&&[app[@"name"] length]&&[app[@"name"] length]<=60?app[@"name"]:@"Unknown app",*bundle=[app[@"id"] isKindOfClass:NSString.class]&&[app[@"id"] length]<=200?app[@"id"]:nil;
 dispatch_async(queue,^{
  double now=MYBShieldWall();if(now-checked>3||now<checked){on=MYBActivityEnabled();checked=now;}
  if(!on){[pending removeAllObjects];[pendingIDs removeAllObjects];return;}
  BOOL first=pending.count==0;NSMutableDictionary *e=pending[host];
  if(!e){if(pending.count>=MYB_ACTIVITY_MAX_HOSTS)return;e=[@{@"b":@0,@"a":@0,@"apps":[NSMutableDictionary dictionary]} mutableCopy];pending[host]=e;}
  NSString *key=allowed?@"a":@"b";e[key]=@([e[key] integerValue]+1);
  NSMutableDictionary *apps=e[@"apps"],*per=[apps[name] mutableCopy]?:[@{@"b":@0,@"a":@0} mutableCopy];per[key]=@([per[key] integerValue]+1);apps[name]=per;
  if(bundle)pendingIDs[name]=bundle;
  if(first)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),queue,^{NSDictionary *batch=[pending copy],*ids=[pendingIDs copy];[pending removeAllObjects];[pendingIDs removeAllObjects];if(MYBActivityEnabled())MYBActivityMerge(MYBActivityFile(),batch,ids,MYBShieldWall());});
 });
}
// Newest first: @[@{host,b,a,first,last,apps}] (blocked count, allowed count, apps -> {b,a}).
static inline NSArray<NSDictionary *> *MYBActivityList(NSString *path,double now){
 NSDictionary *hosts=[MYBActivityRead(path)[@"hosts"] isKindOfClass:NSDictionary.class]?MYBActivityRead(path)[@"hosts"]:@{};
 NSMutableArray *out=[NSMutableArray array];
 for(NSString *h in hosts){NSDictionary *e=MYBActivityNorm(hosts[h]);if(!e||now-[e[@"last"] doubleValue]>MYB_ACTIVITY_MAX_AGE)continue;NSMutableDictionary *m=[e mutableCopy];m[@"host"]=h;[out addObject:m];}
 [out sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [b[@"last"] compare:a[@"last"]];}];return out;
}
static inline NSDictionary<NSString *,NSString *> *MYBActivityAppIDs(NSString *path){NSDictionary *ids=MYBActivityRead(path)[@"ids"];return [ids isKindOfClass:NSDictionary.class]?ids:@{};}
// The apps seen in a list of websites: @[@{name,b,a,sites}], busiest first.
static inline NSArray<NSDictionary *> *MYBActivityApps(NSArray<NSDictionary *> *hosts){
 NSMutableDictionary<NSString *,NSMutableDictionary *> *by=[NSMutableDictionary dictionary];
 for(NSDictionary *h in hosts)for(NSString *name in h[@"apps"]){
  NSDictionary *c=h[@"apps"][name];NSMutableDictionary *e=by[name]?:[@{@"name":name,@"b":@0,@"a":@0,@"sites":@0} mutableCopy];
  e[@"b"]=@([e[@"b"] integerValue]+[c[@"b"] integerValue]);e[@"a"]=@([e[@"a"] integerValue]+[c[@"a"] integerValue]);e[@"sites"]=@([e[@"sites"] integerValue]+1);by[name]=e;
 }
 return [by.allValues sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *x,NSDictionary *y){
  NSInteger tx=[x[@"b"] integerValue]+[x[@"a"] integerValue],ty=[y[@"b"] integerValue]+[y[@"a"] integerValue];
  if(tx!=ty)return tx>ty?NSOrderedAscending:NSOrderedDescending;return [x[@"name"] compare:y[@"name"]];
 }];
}
static inline BOOL MYBActivityClear(NSString *path){int lock=MYBShieldLock(path);if(lock<0)return NO;[NSFileManager.defaultManager removeItemAtPath:path error:NULL];MYBShieldUnlock(lock);return YES;}
// Drops anything older than 24 hours. Safe to call any time; the list screen calls it so the file never holds stale names.
static inline void MYBActivityPrune(NSString *path,double now){
 if(![NSFileManager.defaultManager fileExistsAtPath:path])return;int lock=MYBShieldLock(path);if(lock<0)return;
 NSDictionary *root=MYBActivityRead(path);NSDictionary *stored=[root[@"hosts"] isKindOfClass:NSDictionary.class]?root[@"hosts"]:@{};NSMutableDictionary *hosts=[NSMutableDictionary dictionary];BOOL changed=NO;
 for(NSString *h in stored){NSDictionary *e=MYBActivityNorm(stored[h]);if(e&&now-[e[@"last"] doubleValue]<=MYB_ACTIVITY_MAX_AGE)hosts[h]=e;else changed=YES;}
 if(changed)MYBActivityWrite(path,hosts,[root[@"ids"] isKindOfClass:NSDictionary.class]?root[@"ids"]:@{});
 MYBShieldUnlock(lock);
}
