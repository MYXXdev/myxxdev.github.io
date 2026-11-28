#pragma once
// In-App Ad Blocking diagnostics, both ends.
//
// CLIENT (inside each app): a module reports that it loaded, how many of its hooks were found, and how many ads it
// has filtered. It sends numbers and fixed labels only: never a URL, a title, an account, a message or any content.
// Reports go to MYbloXX's own loopback service (127.0.0.1) with the same bridge header the Shield browser components
// use, on a background queue, at most once every 20 seconds, so nothing waits on the network and nothing runs on the
// main thread. If the service is not running, the report is dropped and the app is unaffected.
//
// SERVER (MYbloXX's local service): validates every field against a fixed list, folds the reports into one record per
// module, and Settings reads that record. A report is an observation by the module, not proof of anything else:
//   loaded   the module's constructor ran in the app and its switch was on
//   hooks    how many of its hook points exist in this app version
//   decisions  ads the module actually identified and removed or refused ("filtering")
// "Hooks found" is not "effective": only a non-zero decision count means an ad was seen and handled, and even that says
// nothing about ads the module did not recognise.
#import <Foundation/Foundation.h>
#import "MYBLoopback.h"

static NSArray<NSString *> *MYBAdsReportModules(void){return @[@"youtube",@"instagram",@"tiktok",@"soundcloud",@"reddit",@"youtubemusic",@"x",@"messenger",@"facebook",@"amazon",@"threads",@"gmail",@"douban",@"qqmusic",@"sogou",@"wechat",@"bilibili"];}
static NSArray<NSString *> *MYBAdsReportCategories(void){return @[@"feed",@"reel",@"short",@"story",@"video",@"player",@"slot",@"request",@"comment",@"oversize"];}
static BOOL MYBAdsToken(NSString *v,NSUInteger max,NSString *allowed){
 if(![v isKindOfClass:NSString.class]||!v.length||v.length>max)return NO;
 return [v rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:allowed].invertedSet].location==NSNotFound;
}
#define MYB_ADS_VERSION_CHARS @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-_"

// ---- client ------------------------------------------------------------------------------------------------------
// Tests replace the sink; production leaves it nil and uses the loopback request.
static void (^MYBAdsReportSink)(NSString *pathAndQuery);
static NSObject *MYBAdsLock(void){static NSObject *o;static dispatch_once_t once;dispatch_once(&once,^{o=[NSObject new];});return o;}
static NSMutableDictionary<NSString *,NSMutableDictionary<NSString *,NSNumber *> *> *MYBAdsPending(void){static NSMutableDictionary *d;static dispatch_once_t once;dispatch_once(&once,^{d=[NSMutableDictionary dictionary];});return d;}
static dispatch_queue_t MYBAdsQueue(void){static dispatch_queue_t q;static dispatch_once_t once;dispatch_once(&once,^{q=dispatch_queue_create("net.myxxdev.mybloxx.adsreport",DISPATCH_QUEUE_SERIAL);});return q;}
static void MYBAdsSend(NSString *module,NSDictionary<NSString *,NSString *> *fields){
 NSMutableArray *items=[NSMutableArray array];
 NSString *app=NSBundle.mainBundle.bundleIdentifier?:@"";
 [items addObject:[NSURLQueryItem queryItemWithName:@"app" value:app]];[items addObject:[NSURLQueryItem queryItemWithName:@"module" value:module]];
 for(NSString *k in fields)[items addObject:[NSURLQueryItem queryItemWithName:k value:fields[k]]];
 NSURLComponents *c=[NSURLComponents new];c.queryItems=items;NSString *path=[@"/mybloxx-ads-event?" stringByAppendingString:c.percentEncodedQuery?:@""];
 dispatch_async(MYBAdsQueue(),^{
  if(MYBAdsReportSink){MYBAdsReportSink(path);return;}
  (void)MYBLoopbackGET(MYB_BRIDGE_PORT,path);
 });
}
static NSString *MYBAdsProcessArch(void){
#if defined(__arm64e__)
 return @"arm64e"; // the slice that loaded, so this is the architecture of the app process
#elif defined(__arm64__)
 return @"arm64";
#else
 return @"other";
#endif
}
static NSString *MYBAdsAppVersion(void){
 NSString *v=NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];return MYBAdsToken(v,24,MYB_ADS_VERSION_CHARS)?v:@"unknown";
}
__attribute__((unused)) static void MYBAdsReportLoaded(NSString *module,NSString *componentVersion){
 MYBAdsSend(module,@{@"phase":@"loaded",@"av":MYBAdsAppVersion(),@"arch":MYBAdsProcessArch(),@"ver":MYBAdsToken(componentVersion,40,MYB_ADS_VERSION_CHARS)?componentVersion:@"unknown"});
}
__attribute__((unused)) static void MYBAdsReportHooks(NSString *module,NSUInteger found,NSUInteger attempted,NSUInteger ownedElsewhere){
 MYBAdsSend(module,@{@"phase":@"hooks",@"found":[@(MIN(found,99)) stringValue],@"attempted":[@(MIN(attempted,99)) stringValue],@"owned":[@(MIN(ownedElsewhere,99)) stringValue]});
}
static void MYBAdsFlush(NSString *module){
 NSDictionary *batch;
 @synchronized(MYBAdsLock()){batch=[MYBAdsPending()[module] copy];[MYBAdsPending() removeObjectForKey:module];}
 if(!batch.count)return;
 NSMutableArray *parts=[NSMutableArray array];for(NSString *k in [batch.allKeys sortedArrayUsingSelector:@selector(compare:)])[parts addObject:[NSString stringWithFormat:@"%@:%lu",k,(unsigned long)MIN([batch[k] unsignedIntegerValue],100000)]];
 MYBAdsSend(module,@{@"phase":@"decisions",@"cat":[parts componentsJoinedByString:@","]});
}
// One ad identified and removed or refused. Cheap enough for a hot path: a lock and an increment; the send is
// coalesced and happens later, off the calling thread.
__attribute__((unused)) static void MYBAdsNoteDecisions(NSString *module,NSString *category,NSUInteger count){
 if(!count)return;BOOL schedule=NO;
 @synchronized(MYBAdsLock()){
  NSMutableDictionary *m=MYBAdsPending()[module];if(!m){m=[NSMutableDictionary dictionary];MYBAdsPending()[module]=m;schedule=YES;}
  m[category]=@([m[category] unsignedIntegerValue]+count);
 }
 if(schedule){
  NSTimeInterval wait=MYBAdsReportSink?0.0:20.0; // tests flush immediately; the app waits so one report covers a burst
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(wait*NSEC_PER_SEC)),MYBAdsQueue(),^{MYBAdsFlush(module);});
 }
}

// ---- server ------------------------------------------------------------------------------------------------------
static NSMutableDictionary *MYBAdsRecords(void){static NSMutableDictionary *d;static dispatch_once_t once;dispatch_once(&once,^{d=[NSMutableDictionary dictionary];});return d;}
static BOOL MYBAdsSmallInt(NSString *v,long long max,long long *out){
 if(!MYBAdsToken(v,7,@"0123456789"))return NO;long long n=v.longLongValue;if(n>max)return NO;*out=n;return YES;
}
// Returns YES if the event was valid and recorded. `bundles` maps module to the bundle ids it may report from.
__attribute__((unused)) static BOOL MYBAdsRecordEvent(NSDictionary<NSString *,NSString *> *q,NSDictionary<NSString *,NSArray<NSString *> *> *bundles,NSTimeInterval now){
 NSString *module=q[@"module"],*app=q[@"app"],*phase=q[@"phase"];
 if(![MYBAdsReportModules() containsObject:module]||![bundles[module] containsObject:app])return NO; // the reporting app must be the module's own app
 NSMutableDictionary *r;
 @synchronized(MYBAdsRecords()){
  r=MYBAdsRecords()[module];if(!r){r=[NSMutableDictionary dictionary];MYBAdsRecords()[module]=r;}
  if([phase isEqual:@"loaded"]){
   if(!MYBAdsToken(q[@"av"],24,MYB_ADS_VERSION_CHARS)||![@[@"arm64",@"arm64e",@"other"] containsObject:q[@"arch"]]||!MYBAdsToken(q[@"ver"],40,MYB_ADS_VERSION_CHARS))return NO;
   // A new launch starts a new record: counts belong to one run of the app.
   [r removeAllObjects];r[@"appVersion"]=q[@"av"];r[@"arch"]=q[@"arch"];r[@"componentVersion"]=q[@"ver"];r[@"bundle"]=app;r[@"loadedAt"]=@((long long)now);r[@"decisions"]=@0;r[@"categories"]=@{};
   return YES;
  }
  if(!r[@"loadedAt"])return NO; // hooks and decisions only count after a load report in this run
  if([phase isEqual:@"hooks"]){
   long long found,attempted,owned;if(!MYBAdsSmallInt(q[@"found"],99,&found)||!MYBAdsSmallInt(q[@"attempted"],99,&attempted)||!MYBAdsSmallInt(q[@"owned"],99,&owned)||found>attempted)return NO;
   r[@"hooksFound"]=@(found);r[@"hooksAttempted"]=@(attempted);r[@"hooksOwnedElsewhere"]=@(owned);r[@"hooksAt"]=@((long long)now);return YES;
  }
  if([phase isEqual:@"decisions"]){
   NSString *cat=q[@"cat"];if(!MYBAdsToken(cat,120,@"abcdefghijklmnopqrstuvwxyz0123456789:,"))return NO;
   NSMutableDictionary *cats=[r[@"categories"] mutableCopy]?:[NSMutableDictionary dictionary];long long total=[r[@"decisions"] longLongValue],passed=[r[@"passedThrough"] longLongValue];
   for(NSString *pair in [cat componentsSeparatedByString:@","]){
    NSArray *kv=[pair componentsSeparatedByString:@":"];long long n;if(kv.count!=2||![MYBAdsReportCategories() containsObject:kv[0]]||!MYBAdsSmallInt(kv[1],100000,&n))return NO;
    if([kv[0] isEqual:@"oversize"]){passed+=n;continue;} // passed through because of its size: not a filtered ad
    cats[kv[0]]=@([cats[kv[0]] longLongValue]+n);total+=n;
   }
   r[@"categories"]=cats;r[@"decisions"]=@(total);r[@"passedThrough"]=@(passed);r[@"lastDecisionAt"]=@((long long)now);return YES;
  }
 }
 return NO;
}
// The state Settings shows. "filtering" is the only state that means an ad was actually handled.
static NSString *MYBAdsStateFor(NSDictionary *r){
 if(!r.count)return @"not-observed";
 if(!r[@"hooksAttempted"])return @"loaded";
 if([r[@"hooksFound"] longLongValue]==0)return @"no-hooks-found";
 return [r[@"decisions"] longLongValue]>0?@"filtering":@"hooks-found";
}
__attribute__((unused)) static NSDictionary *MYBAdsSnapshot(void){
 NSMutableDictionary *out=[NSMutableDictionary dictionary];
 @synchronized(MYBAdsRecords()){for(NSString *m in MYBAdsReportModules()){NSMutableDictionary *r=[MYBAdsRecords()[m] mutableCopy]?:[NSMutableDictionary dictionary];r[@"state"]=MYBAdsStateFor(r);out[m]=r;}}
 return out;
}

// ---- Ad Network Blocking: "the library loaded in this app" -----------------------------------------------------------------------------
// Writing a loader filter only says the library MAY load in an app. The one proof that it did is the library itself, running in that app,
// telling MYbloXX®'s service. Settings shows an app as active only after this arrives; until then it says the app must be reopened.
// Memory only, at most 96 apps, newest first replaced. The service takes it only on bridge-header routes (BlockedServer/main.m).
// One report per process launch: `launch` (random, per process), `t` (the wall time at which this process read the choices, so it can be compared with
// the time the choice last changed), `ver` (the library's own version, so a library from before an upgrade is told apart), and the counts.
__attribute__((unused)) static NSString *MYBAdSDKLaunchId(void){static NSString *l;static dispatch_once_t once;dispatch_once(&once,^{l=[[NSUUID.UUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""] substringToIndex:8].lowercaseString;});return l;}
__attribute__((unused)) static void MYBAdSDKReportLoaded(NSUInteger installed,NSUInteger attempted,NSUInteger blocked,NSTimeInterval readAt,NSString *componentVersion){
 NSString *app=NSBundle.mainBundle.bundleIdentifier?:@"";
 NSURLComponents *c=[NSURLComponents new];
 c.queryItems=@[[NSURLQueryItem queryItemWithName:@"app" value:app],[NSURLQueryItem queryItemWithName:@"installed" value:[@(MIN(installed,99)) stringValue]],[NSURLQueryItem queryItemWithName:@"attempted" value:[@(MIN(attempted,99)) stringValue]],
  [NSURLQueryItem queryItemWithName:@"blocked" value:[@(MIN(blocked,100000)) stringValue]],[NSURLQueryItem queryItemWithName:@"launch" value:MYBAdSDKLaunchId()],
  [NSURLQueryItem queryItemWithName:@"t" value:[NSString stringWithFormat:@"%lld",(long long)readAt]],[NSURLQueryItem queryItemWithName:@"ver" value:MYBAdsToken(componentVersion,40,MYB_ADS_VERSION_CHARS)?componentVersion:@"unknown"],
  [NSURLQueryItem queryItemWithName:@"av" value:MYBAdsAppVersion()],[NSURLQueryItem queryItemWithName:@"arch" value:MYBAdsProcessArch()]];
 NSString *path=[@"/mybloxx-ads-sdk-loaded?" stringByAppendingString:c.percentEncodedQuery?:@""];
 dispatch_async(MYBAdsQueue(),^{if(MYBAdsReportSink){MYBAdsReportSink(path);return;}(void)MYBLoopbackGET(MYB_BRIDGE_PORT,path);});
}
static NSMutableDictionary *MYBAdSDKSeen(void){static NSMutableDictionary *d;static dispatch_once_t once;dispatch_once(&once,^{d=[NSMutableDictionary dictionary];});return d;}
__attribute__((unused)) static BOOL MYBAdSDKRecordLoaded(NSDictionary<NSString *,NSString *> *q,NSTimeInterval now){
 NSString *app=q[@"app"];
 if(!MYBAdsToken(app,200,@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")||![app containsString:@"."]||[app hasPrefix:@"com.apple."]||[app hasPrefix:@"net.myxxdev."]||[app hasPrefix:@"__"])return NO;
 long long installed,attempted;
 long long blocked,readAt;
 if(!MYBAdsSmallInt(q[@"installed"],99,&installed)||!MYBAdsSmallInt(q[@"attempted"],99,&attempted)||installed>attempted||!MYBAdsSmallInt(q[@"blocked"],100000,&blocked)||!MYBAdsToken(q[@"launch"],8,@"0123456789abcdef")||!MYBAdsToken(q[@"t"],12,@"0123456789")||!MYBAdsToken(q[@"ver"],40,MYB_ADS_VERSION_CHARS)||!MYBAdsToken(q[@"av"],24,MYB_ADS_VERSION_CHARS)||![@[@"arm64",@"arm64e",@"other"] containsObject:q[@"arch"]])return NO;
 readAt=[q[@"t"] longLongValue];if(readAt>(long long)now+300)return NO; // a time in the future is not a launch that happened
 @synchronized(MYBAdSDKSeen()){
  NSDictionary *old=MYBAdSDKSeen()[app];
  if(!old&&MYBAdSDKSeen().count>=96)return NO;
  // Reports of the same launch only move forward; a report from another launch replaces the record only if that launch started later.
  if([old[@"launch"] isEqual:q[@"launch"]]&&blocked<[old[@"blocked"] longLongValue])blocked=[old[@"blocked"] longLongValue];
  else if(old&&![old[@"launch"] isEqual:q[@"launch"]]&&readAt<[old[@"readAt"] longLongValue])return NO;
  MYBAdSDKSeen()[app]=@{@"launch":q[@"launch"],@"readAt":@(readAt),@"ver":q[@"ver"],@"blocked":@(blocked),@"installed":@(installed),@"attempted":@(attempted),@"appVersion":q[@"av"],@"arch":q[@"arch"],@"at":@((long long)now)};
 }
 return YES;
}
__attribute__((unused)) static NSDictionary *MYBAdSDKSeenSnapshot(void){@synchronized(MYBAdSDKSeen()){return [MYBAdSDKSeen() copy];}}
__attribute__((unused)) static void MYBAdSDKSeenReset(void){@synchronized(MYBAdSDKSeen()){[MYBAdSDKSeen() removeAllObjects];}}
