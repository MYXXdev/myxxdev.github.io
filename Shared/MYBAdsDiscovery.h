#pragma once
// Opt-in discovery for the in-app ad modules. It runs only inside a bounded session the person starts in Settings > In-App Ad Blocking >
// Status (10 minutes, then it stops by itself); nothing here runs otherwise. It exists so a short collection can say where an app's
// advertising lives, without guessing. The apps send what they collect to MYbloXX's local service, and Status shows it, copies it and
// shares it from the iPhone; no Mac is needed (the system log line remains as a second route).
//
// What is collected, and only this: class names, selector names with their type signatures, view class names with counts, and counts of
// model class names. Never a string from the app's content, never an account name, token, cookie, header, URL, search text, image or
// message. Every list is capped, so the log stays short and bounded whatever the app does.
//
// Where it goes: one line per collection, starting with "MYBAdsDiscovery <module>", holding one JSON object. It is sent to the local
// service in small pieces (kept in memory only, never written to disk, at most 24 lines and about 90 KB) and also written to the system log.
// How to read it: see docs/inappads/DISCOVERY.md (also summarised in Settings > In-App Ad Blocking > Status).
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>
#import "MYBAdsReport.h"
#import "MYBVersion.h"
#import "MYBWebsiteRules.h"
#if __has_include(<notify.h>)
#import <notify.h>
#endif

#define MYB_ADS_DISCOVERY_KEY @"ads-discovery-until"   // epoch seconds at which the session ends; absent or past means off
#define MYB_ADS_DISCOVERY_SESSION_KEY @"ads-discovery-session" // 8 hex digits: which session that is. A report carries it; anything else is dropped
#define MYB_ADS_DISCOVERY_NOTIFY "net.myxxdev.mybloxx.ads-discovery" // posted when a session starts or stops, so an app that is already open reacts
#define MYB_ADS_DISCOVERY_SECONDS 600                    // one session
#define MYB_ADS_DISCOVERY_MAX_LINE 7000   // characters in one collected line
#define MYB_ADS_DISCOVERY_MAX_ITEMS 60    // entries in any one list
#define MYB_ADS_DISCOVERY_CHUNK 700       // characters sent per request
#define MYB_ADS_DISCOVERY_MAX_CHUNKS 12
#define MYB_ADS_DISCOVERY_MAX_ENTRIES 24  // lines the service keeps
#define MYB_ADS_DISCOVERY_MAX_BYTES 90000

// The three apps that can be collected from. App Store has no everyday switch; Facebook and Amazon also have theirs.
static inline NSArray<NSString *> *MYBAdsDiscoveryModules(void){return @[@"facebook",@"appstore",@"amazon"];}
// On only while a session is running. A stored time more than one session length ahead is not believed, so a bad value cannot leave
// collection on for good.
static inline BOOL MYBAdsDiscoveryEnabledAt(NSDictionary *prefs,NSTimeInterval now){
 id v=[prefs isKindOfClass:NSDictionary.class]?prefs[MYB_ADS_DISCOVERY_KEY]:nil;
 if(![v isKindOfClass:NSNumber.class])return NO;
 double until=[v doubleValue];return until>now&&until-now<=MYB_ADS_DISCOVERY_SECONDS+5;
}
// The id of the session that is running at `now`, or nil. A session needs BOTH a live end time and a well-formed id.
static inline NSString *MYBAdsDiscoverySessionAt(NSDictionary *prefs,NSTimeInterval now){
 if(!MYBAdsDiscoveryEnabledAt(prefs,now))return nil;
 id s=prefs[MYB_ADS_DISCOVERY_SESSION_KEY];
 return ([s isKindOfClass:NSString.class]&&[(NSString *)s length]==8&&MYBAdsToken(s,8,@"0123456789abcdef"))?s:nil;
}
static inline BOOL MYBAdsDiscoveryEnabled(NSDictionary *prefs){return MYBAdsDiscoverySessionAt(prefs,NSDate.date.timeIntervalSince1970)!=nil;}
// Words that suggest advertising in a class or selector name. "Ad" counts only as a whole word part (AdSlot, adItem, isAd), so Add,
// Address, Adapter, Adjust and Advance do not match.
static inline BOOL MYBAdsDiscoveryNameLooksAdLike(NSString *name){
 NSString *low=name.lowercaseString;
 for(NSString *w in @[@"sponsor",@"advert",@"promot",@"impression",@"placement",@"admob",@"adunit",@"adslot",@"adinfo"])if([low containsString:w])return YES;
 for(NSUInteger i=0;i+1<name.length;i++){
  unichar a=[name characterAtIndex:i],b=[name characterAtIndex:i+1];
  if((a=='A'||(a=='a'&&(i==0||![[NSCharacterSet letterCharacterSet] characterIsMember:[name characterAtIndex:i-1]])))&&b=='d'){
   if(i+2>=name.length)return YES;
   unichar c=[name characterAtIndex:i+2];
   NSCharacterSet *lower=[NSCharacterSet lowercaseLetterCharacterSet];
   if(![lower characterIsMember:c])return YES; // Ad followed by an upper-case letter, digit or symbol
   if(c=='s'&&(i+3>=name.length||![lower characterIsMember:[name characterAtIndex:i+3]]))return YES; // Ads
  }
 }
 return NO;
}
// A type encoding without the stack offsets ("v24@0:8@16" becomes "v@:@").
static inline NSString *MYBAdsDiscoverySignature(Method method){
 NSMutableString *out=[NSMutableString string];
 char *ret=method_copyReturnType(method);if(ret){[out appendFormat:@"%s",ret];free(ret);}
 for(unsigned i=0;i<method_getNumberOfArguments(method);i++){char *a=method_copyArgumentType(method,i);if(a){[out appendFormat:@"%s",a];free(a);}}
 return out;
}
// Selectors defined on the class itself (instance side, then class side) whose names contain any keyword, as "name signature", capped.
// When keywords is empty every selector qualifies.
static inline NSArray<NSString *> *MYBAdsDiscoverySelectors(Class cls,NSArray<NSString *> *keywords,NSUInteger cap){
 NSMutableArray *out=[NSMutableArray array];if(!cls)return out;
 for(int side=0;side<2&&out.count<cap;side++){
  Class target=side?object_getClass(cls):cls;unsigned n=0;Method *list=class_copyMethodList(target,&n);
  for(unsigned i=0;i<n&&out.count<cap;i++){
   NSString *name=NSStringFromSelector(method_getName(list[i]));NSString *low=name.lowercaseString;BOOL hit=!keywords.count;
   for(NSString *k in keywords)if([low containsString:k.lowercaseString]){hit=YES;break;}
   if(!hit&&MYBAdsDiscoveryNameLooksAdLike(name))hit=YES;
   if(hit)[out addObject:[NSString stringWithFormat:@"%@%@ %@",side?@"+":@"-",name,MYBAdsDiscoverySignature(list[i])]];
  }
  free(list);
 }
 return out;
}
// The class and its superclass names up to (not including) NSObject: where a model or view sits in the app's own hierarchy.
static inline NSArray<NSString *> *MYBAdsDiscoveryChain(Class cls){
 NSMutableArray *out=[NSMutableArray array];
 while(cls&&cls!=NSObject.class&&out.count<8){[out addObject:NSStringFromClass(cls)];cls=class_getSuperclass(cls);}
 return out;
}
// Names of classes whose name looks ad-like, optionally only from images whose path contains one of imageFragments (empty means any).
static inline NSArray<NSString *> *MYBAdsDiscoveryAdLikeClasses(NSArray<NSString *> *imageFragments,NSUInteger cap){
 unsigned count=0;Class *all=objc_copyClassList(&count);NSMutableArray *out=[NSMutableArray array];
 for(unsigned i=0;i<count;i++){
  const char *image=class_getImageName(all[i]);
  if(imageFragments.count){
   BOOL inside=NO;for(NSString *f in imageFragments)if(image&&strstr(image,f.UTF8String)){inside=YES;break;}
   if(!inside)continue;
  }
  NSString *name=NSStringFromClass(all[i]);
  if(MYBAdsDiscoveryNameLooksAdLike(name))[out addObject:name];
 }
 free(all);
 NSArray *sorted=[out sortedArrayUsingSelector:@selector(compare:)];
 return sorted.count>cap?[sorted subarrayWithRange:NSMakeRange(0,cap)]:sorted; // sorted first, so the same names are kept every time
}
// Every module of the shared dylib includes this header, and an Objective-C class can be defined only once per image. Each module
// therefore names its own copy before the include (#define MYB_ADS_COUNTER MYB<Module>DiscoveryCounter); the default is used by
// binaries and tests that include the header once.
#ifndef MYB_ADS_COUNTER
#define MYB_ADS_COUNTER MYBAdsDiscoveryCounter
#endif
// A bounded counter of names (view or model class names). Past the cap new names fall into "other", so the log never grows.
@interface MYB_ADS_COUNTER:NSObject
@property(nonatomic,strong) NSMutableDictionary<NSString *,NSNumber *> *counts;
@property(nonatomic,assign) NSUInteger cap;
@end
@implementation MYB_ADS_COUNTER
- (instancetype)initWithCap:(NSUInteger)cap{if((self=[super init])){_counts=[NSMutableDictionary dictionary];_cap=cap?:MYB_ADS_DISCOVERY_MAX_ITEMS;}return self;}
- (void)note:(NSString *)name{
 if(!name.length)return;
 @synchronized(self){
  NSString *key=(self.counts[name]||self.counts.count<self.cap)?name:@"other";
  self.counts[key]=@(self.counts[key].unsignedLongLongValue+1);
 }
}
- (NSDictionary<NSString *,NSNumber *> *)snapshot{@synchronized(self){return [self.counts copy];}}
@end
// View classes below the given roots (breadth first, at most maxViews visited), counted by class name. Uses only subviews; no view
// content, text or image is read.
static inline NSDictionary<NSString *,NSNumber *> *MYBAdsDiscoveryViewClasses(NSArray *roots,NSUInteger maxViews){
 MYB_ADS_COUNTER *counter=[[MYB_ADS_COUNTER alloc] initWithCap:MYB_ADS_DISCOVERY_MAX_ITEMS];
 NSMutableArray *queue=[roots mutableCopy];NSUInteger visited=0;SEL subs=sel_registerName("subviews");
 while(queue.count&&visited<maxViews){
  id view=queue.firstObject;[queue removeObjectAtIndex:0];visited++;
  [counter note:NSStringFromClass([view class])];
  if([view respondsToSelector:subs]){id kids=((id(*)(id,SEL))objc_msgSend)(view,subs);if([kids isKindOfClass:NSArray.class])[queue addObjectsFromArray:kids];}
 }
 return counter.snapshot;
}
// The windows of the running app, with no UIKit import.
static inline NSArray *MYBAdsDiscoveryWindows(void){
 Class app=NSClassFromString(@"UIApplication");SEL shared=sel_registerName("sharedApplication"),windows=sel_registerName("windows");
 id instance=[app respondsToSelector:shared]?((id(*)(id,SEL))objc_msgSend)(app,shared):nil;
 id list=[instance respondsToSelector:windows]?((id(*)(id,SEL))objc_msgSend)(instance,windows):nil;
 return [list isKindOfClass:NSArray.class]?list:@[];
}
// One collection as text: "MYBAdsDiscovery <module> <json>", plain ASCII, cut at MYB_ADS_DISCOVERY_MAX_LINE characters. Also used by tests.
static inline NSString *MYBAdsDiscoveryLine(NSString *module,NSDictionary *info){
 NSData *json=[NSJSONSerialization isValidJSONObject:info]?[NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingSortedKeys error:NULL]:nil;
 NSString *text=json?[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]:@"{}";
 NSData *ascii=[text dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];if(ascii)text=[[NSString alloc] initWithData:ascii encoding:NSASCIIStringEncoding]?:text;
 if(text.length>MYB_ADS_DISCOVERY_MAX_LINE)text=[[text substringToIndex:MYB_ADS_DISCOVERY_MAX_LINE] stringByAppendingString:@"...cut"];
 return [NSString stringWithFormat:@"MYBAdsDiscovery %@ %@",module,text];
}
// CLIENT. A collector works for ONE session, the one it saw when it started. Before every collection and again before every piece is sent it
// re-reads the saved preferences: if that session has ended (time, Stop, Clear) or another has begun, nothing is sent, so a report that was
// queued cannot land in a later session. The service enforces the same with the session id carried by every piece.
static NSDictionary *(^MYBAdsDiscoveryPrefsReader)(void); // tests replace it
static inline NSDictionary *MYBAdsDiscoveryReadPrefs(void){
 if(MYBAdsDiscoveryPrefsReader)return MYBAdsDiscoveryPrefsReader();
 NSString *rel=@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.inappads.plist";
 return [NSDictionary dictionaryWithContentsOfFile:MYBRuleFile(rel)]?:[NSDictionary dictionaryWithContentsOfFile:[@"/" stringByAppendingString:rel]];
}
static inline NSMutableDictionary<NSString *,NSString *> *MYBAdsDiscoverySessions(void){static NSMutableDictionary *d;static dispatch_once_t once;dispatch_once(&once,^{d=[NSMutableDictionary dictionary];});return d;}
static inline NSString *MYBAdsDiscoveryClientSession(NSString *module){@synchronized(MYBAdsDiscoverySessions()){return MYBAdsDiscoverySessions()[module];}}
static inline BOOL MYBAdsDiscoveryLive(NSString *module){
 NSString *mine=MYBAdsDiscoveryClientSession(module);if(!mine)return NO;
 return [mine isEqual:MYBAdsDiscoverySessionAt(MYBAdsDiscoveryReadPrefs(),NSDate.date.timeIntervalSince1970)];
}
// Starts `start` once per session: now if a session is running, and again whenever the person starts a new one (a Darwin notification), so an
// app that was already open needs no restart. Returns whether `start` ran now.
static inline BOOL MYBAdsDiscoveryEvaluate(NSString *module,void(^start)(NSString *session)){
 NSString *sid=MYBAdsDiscoverySessionAt(MYBAdsDiscoveryReadPrefs(),NSDate.date.timeIntervalSince1970);if(!sid)return NO;
 @synchronized(MYBAdsDiscoverySessions()){if([MYBAdsDiscoverySessions()[module] isEqual:sid])return NO;MYBAdsDiscoverySessions()[module]=sid;}
 if(start)start(sid);return YES;
}
static inline void MYBAdsDiscoveryWatch(NSString *module,void(^start)(NSString *session)){
 void(^go)(void)=[^{MYBAdsDiscoveryEvaluate(module,start);} copy];
 go();
#if __has_include(<notify.h>)&&!defined(MYB_INAPPADS_TESTING)
 static NSMutableArray *tokens;static dispatch_once_t once;dispatch_once(&once,^{tokens=[NSMutableArray array];});
 int token=0;if(notify_register_dispatch(MYB_ADS_DISCOVERY_NOTIFY,&token,dispatch_get_main_queue(),^(int t){(void)t;go();})==NOTIFY_STATUS_OK)[tokens addObject:@(token)];
#endif
}
static inline NSArray<NSString *> *MYBAdsDiscoveryPaths(NSString *module,NSString *line,NSString *app,NSString *sid,NSString *session){
 NSUInteger n=(line.length+MYB_ADS_DISCOVERY_CHUNK-1)/MYB_ADS_DISCOVERY_CHUNK;if(!n||n>MYB_ADS_DISCOVERY_MAX_CHUNKS)return @[];
 NSMutableArray *paths=[NSMutableArray array];
 for(NSUInteger i=0;i<n;i++){
  NSString *piece=[line substringWithRange:NSMakeRange(i*MYB_ADS_DISCOVERY_CHUNK,MIN((NSUInteger)MYB_ADS_DISCOVERY_CHUNK,line.length-i*MYB_ADS_DISCOVERY_CHUNK))];
  NSURLComponents *c=[NSURLComponents new];
  c.queryItems=@[[NSURLQueryItem queryItemWithName:@"app" value:app],[NSURLQueryItem queryItemWithName:@"module" value:module],[NSURLQueryItem queryItemWithName:@"id" value:sid],
   [NSURLQueryItem queryItemWithName:@"s" value:session?:@""],[NSURLQueryItem queryItemWithName:@"i" value:@(i).stringValue],[NSURLQueryItem queryItemWithName:@"n" value:@(n).stringValue],[NSURLQueryItem queryItemWithName:@"d" value:piece]];
  [paths addObject:[@"/mybloxx-ads-discovery?" stringByAppendingString:c.percentEncodedQuery?:@""]];
 }
 return paths;
}
static inline void MYBAdsDiscoverySend(NSString *module,NSString *line){
 NSString *session=MYBAdsDiscoveryClientSession(module);if(!session||!MYBAdsDiscoveryLive(module))return;
 NSArray *paths=MYBAdsDiscoveryPaths(module,line,NSBundle.mainBundle.bundleIdentifier?:@"",[NSString stringWithFormat:@"%08x",arc4random()],session);
 if(!paths.count)return;
 dispatch_async(MYBAdsQueue(),^{for(NSString *path in paths){
  if(!MYBAdsDiscoveryLive(module))return; // ended or replaced while this was waiting in the queue: the rest is dropped
  if(MYBAdsReportSink)MYBAdsReportSink(path);else(void)MYBLoopbackGET(MYB_BRIDGE_PORT,path);}});
}
static inline void MYBAdsDiscoveryLog(NSString *module,NSDictionary *info){
 if(!MYBAdsDiscoveryLive(module))return; // expired, stopped or another session: nothing is collected or logged
 NSString *line=MYBAdsDiscoveryLine(module,info);NSLog(@"%@",line);MYBAdsDiscoverySend(module,line);
}
// Sent the moment a collector starts. It proves that the collector ran in the app and that the message reached MYbloXX®'s service. It does NOT
// prove that the screen you meant was open or inspected: only a later collection with details shows that.
static inline void MYBAdsDiscoveryStarted(NSString *module,NSString *appVersion){
 MYBAdsDiscoveryLog(module,@{@"phase":@"started",@"appVersion":appVersion.length?appVersion:@"unknown",@"componentVersion":@MYB_COMPONENT_VERSION});
}

// ---- SERVER (MYbloXX's local service) ------------------------------------------------------------------------------
// Memory only. Accepts pieces only while a session the person started is open, only from the module's own app, and only when every
// field has the expected shape. The assembled line must be one "MYBAdsDiscovery <module> {json}" with no URL in it.
static NSMutableDictionary *MYBAdsDiscoveryState(void){
 static NSMutableDictionary *d;static dispatch_once_t once;
 dispatch_once(&once,^{d=[@{@"until":@0,@"session":@"",@"entries":[NSMutableArray array],@"partial":[NSMutableDictionary dictionary]} mutableCopy];});
 return d;
}
static inline BOOL MYBAdsDiscoveryPrintable(NSString *v,NSUInteger max){
 if(![v isKindOfClass:NSString.class]||!v.length||v.length>max)return NO;
 for(NSUInteger i=0;i<v.length;i++){unichar c=[v characterAtIndex:i];if(c<0x20||c>0x7e)return NO;}
 return YES;
}
__attribute__((unused)) static BOOL MYBAdsDiscoveryAccept(NSDictionary<NSString *,NSString *> *q,NSDictionary<NSString *,NSArray<NSString *> *> *bundles,NSTimeInterval now){
 NSString *module=q[@"module"],*app=q[@"app"],*sid=q[@"id"],*d=q[@"d"];
 if(![MYBAdsDiscoveryModules() containsObject:module]||![bundles[module] containsObject:app])return NO;
 NSString *session=q[@"s"];
 if(!MYBAdsToken(sid,8,@"0123456789abcdef")||!MYBAdsToken(session,8,@"0123456789abcdef")||!MYBAdsDiscoveryPrintable(d,MYB_ADS_DISCOVERY_CHUNK))return NO;
 long long i,n;if(!MYBAdsSmallInt(q[@"i"],99,&i)||!MYBAdsSmallInt(q[@"n"],99,&n)||n<1||n>MYB_ADS_DISCOVERY_MAX_CHUNKS||i>=n)return NO;
 @synchronized(MYBAdsDiscoveryState()){
  NSMutableDictionary *st=MYBAdsDiscoveryState();
  if([st[@"until"] doubleValue]<=now)return NO; // no session open: nothing is kept
  if(![st[@"session"] isEqual:session])return NO; // a report from an earlier or cleared session never enters this one
  NSMutableDictionary *partial=st[@"partial"];NSMutableDictionary *p=partial[sid];
  if(!p){if(partial.count>=8)[partial removeAllObjects];p=[@{@"module":module,@"app":app,@"n":@(n),@"parts":[NSMutableDictionary dictionary]} mutableCopy];partial[sid]=p;}
  if(![p[@"module"] isEqual:module]||![p[@"app"] isEqual:app]||[p[@"n"] longLongValue]!=n)return NO;
  NSMutableDictionary *parts=p[@"parts"];parts[@(i)]=d;
  if(parts.count<(NSUInteger)n)return YES;
  NSMutableString *line=[NSMutableString string];for(long long k=0;k<n;k++){NSString *piece=parts[@(k)];if(!piece){[partial removeObjectForKey:sid];return NO;}[line appendString:piece];}
  [partial removeObjectForKey:sid];
  NSString *prefix=[NSString stringWithFormat:@"MYBAdsDiscovery %@ {",module];
  if(![line hasPrefix:prefix]||line.length>MYB_ADS_DISCOVERY_MAX_LINE+16||[line containsString:@"://"])return NO;
  NSMutableArray *entries=st[@"entries"];[entries addObject:@{@"module":module,@"at":@((long long)now),@"line":[line copy]}];
  NSUInteger bytes=0;for(NSDictionary *e in entries)bytes+=[e[@"line"] length];
  while(entries.count>MYB_ADS_DISCOVERY_MAX_ENTRIES||(bytes>MYB_ADS_DISCOVERY_MAX_BYTES&&entries.count>1)){bytes-=[entries.firstObject[@"line"] length];[entries removeObjectAtIndex:0];}
  return YES;
 }
}
// op: start (opens a session, returns its end time), stop (ends it; what was collected stays until cleared), clear (deletes what was collected).
__attribute__((unused)) static NSDictionary *MYBAdsDiscoveryControl(NSString *op,NSTimeInterval now){
 @synchronized(MYBAdsDiscoveryState()){
  NSMutableDictionary *st=MYBAdsDiscoveryState();
  if([op isEqual:@"start"]){
   [st[@"entries"] removeAllObjects];[st[@"partial"] removeAllObjects];st[@"until"]=@(now+MYB_ADS_DISCOVERY_SECONDS);
   NSString *fresh;do{fresh=[NSString stringWithFormat:@"%08x",arc4random()];}while([fresh isEqual:st[@"session"]]||[fresh isEqual:@"00000000"]); // never the previous session's id
   st[@"session"]=fresh;
  }
  // Stop and Clear both END the session: its id is forgotten, so a report that was still on its way (or is sent later) is refused and cannot
  // repopulate what was just cleared. Clear also deletes what was collected.
  else if([op isEqual:@"stop"]){st[@"until"]=@0;st[@"session"]=@"";[st[@"partial"] removeAllObjects];}
  else if([op isEqual:@"clear"]){st[@"until"]=@0;st[@"session"]=@"";[st[@"entries"] removeAllObjects];[st[@"partial"] removeAllObjects];}
  else return @{@"ok":@NO};
  return @{@"ok":@YES,@"until":st[@"until"],@"session":st[@"session"]};
 }
}
__attribute__((unused)) static NSDictionary *MYBAdsDiscoverySnapshot(NSTimeInterval now){
 @synchronized(MYBAdsDiscoveryState()){
  NSMutableDictionary *st=MYBAdsDiscoveryState();double until=[st[@"until"] doubleValue];
  return @{@"ok":@YES,@"active":@(until>now),@"until":@(until>now?until:0),@"entries":[st[@"entries"] copy]};
 }
}
