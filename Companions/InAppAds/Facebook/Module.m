// MYbloXX In-App Ad Blocking: Facebook (News Feed, Watch, Stories and Marketplace). Ads only.
//
// PROVENANCE. This module is NOT independently derived. Its design (which classes and selectors to hook, how a feed unit is
// recognised as sponsored, which Marketplace queries are advertising, hooking RCTNetworking handlerForRequest:) follows the research
// repositories listed below, which were read as interface evidence. The code was written here and shares no source text with them,
// but it implements the same approach, so it is an adaptation of that research (Facebook-Plus is GPL-3.0, so this module and the dylib it is compiled into are GPL-3.0):
//   Facebook-Plus   @1a3a98605e5d0073af32b681e4604f02fc609111  (src/Features/Ads/FBPAdsHooks.xm, Feed/FBPFeedHooks.xm)
//   MarketplaceAdBlock @dd89884b8725343a5acc633652e2e6fb2b86cc19 (Tweak.m; tested upstream on Facebook 584.0.0)
// Upstream's own Marketplace logic is marked there as adapted from a third party. Upstream claims are not our testing: nothing in
// this file has been run against the real Facebook app.
//
// Every hook installs only when its class and selector exist, so an app update that renames one turns off just that surface.
//  * News Feed: a unit the app classifies as sponsored (category SPONSORED, or sponsored data attached) is answered nil at the model
//    initialiser, so no blank cell is left. Upstream reads the classification at init; if a build assigns it later, that unit is kept
//    (counted in diagnostics as unclassified), because the real data-source path has not been inspected. See MYBFacebookWithoutAds.
//  * Watch: the ad items the app would interleave into the video feed (the list is answered empty).
//  * Stories: the ad requests are not made.
//  * Marketplace: queries the app names as advertising are completed with an error once; ad edges inside other Marketplace
//    responses are removed from parsed JSON. Anything unparseable, oversized or not a confirmed shape is passed on unchanged.
// What it never touches: organic posts and listings, messaging, search, pagination data, purchases and checkout.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#import "../../../Shared/MYBAdsDiscovery.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

static volatile int32_t MYBFacebookUnclassified;
static MYBAdsDiscoveryCounter *MYBFacebookModelTypes; // set only while discovery is on: model class name and how it was classified, counts only
static IMP origPandoInit,origVideoItems,origStoryStart,origStoryFetch,origStoryFetchAsync,origHandlerForRequest;

static id send0(id object,const char *selector){SEL sel=sel_registerName(selector);return [object respondsToSelector:sel]?((id(*)(id,SEL))objc_msgSend)(object,sel):nil;}

// ---- News Feed -------------------------------------------------------------------------------------------------------------
// The app tags a paid unit in its own model: a category of SPONSORED, or attached sponsored data.
BOOL MYBFacebookModelIsAd(id model){
 if(!model)return NO;
 id category=send0(model,"category");
 if([category isKindOfClass:NSString.class]&&[category isEqualToString:@"SPONSORED"])return YES;
 return send0(model,"sponsoredData")!=nil;
}
typedef __attribute__((ns_returns_retained)) id (*MYBFacebookInitIMP)(id,SEL,void *);
// An initialiser returns an owned object: rejecting an ad releases it here, keeping any other unit moves ownership to the caller.
__attribute__((ns_returns_retained)) static id hookPandoInit(id self,SEL _cmd,void *tree){
 id model=((MYBFacebookInitIMP)origPandoInit)(self,_cmd,tree);
 if(model&&MYBFacebookModelTypes)[MYBFacebookModelTypes note:[NSString stringWithFormat:@"%@|%@",NSStringFromClass([model class]),MYBFacebookModelIsAd(model)?@"ad":(send0(model,"category")||send0(model,"sponsoredData")?@"classified":@"unclassified")]];
 if(model&&MYBFacebookModelIsAd(model)){MYBAdsNoteDecisions(@"facebook",@"feed",1);return nil;}
 if(model&&!send0(model,"category")&&!send0(model,"sponsoredData"))__sync_fetch_and_add(&MYBFacebookUnclassified,1); // not classifiable at init (counted for discovery only)
 return model;
}

// ---- Watch and Stories -----------------------------------------------------------------------------------------------------
static NSArray *hookVideoItems(id self,SEL _cmd){
 id items=origVideoItems?((id(*)(id,SEL))origVideoItems)(self,_cmd):nil;
 if([items isKindOfClass:NSArray.class]&&[(NSArray *)items count])MYBAdsNoteDecisions(@"facebook",@"video",[(NSArray *)items count]);
 return @[];
}
static void hookStoryStart(id self,SEL _cmd,id a,id b){MYBAdsNoteDecisions(@"facebook",@"story",1);}
static void hookStoryFetch(id self,SEL _cmd,id payload){MYBAdsNoteDecisions(@"facebook",@"story",1);}

// ---- Marketplace: which requests are advertising ---------------------------------------------------------------------------
// The query name travels in a request header, or as a form field in the body when the header is absent.
NSString *MYBFacebookQueryName(NSURLRequest *request){
 NSString *name=[request valueForHTTPHeaderField:@"X-FB-Friendly-Name"];
 if(name.length)return name;
 NSData *body=request.HTTPBody;
 if(!body.length||body.length>512*1024)return nil;
 NSString *text=[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
 NSURLComponents *form=[NSURLComponents new];form.percentEncodedQuery=text;
 for(NSURLQueryItem *item in form.queryItems)if([item.name isEqualToString:@"fb_api_req_friendly_name"])return item.value;
 return nil;
}
// Exact names only: a query is failed when it is positively known to fetch advertising, never by a loose word match.
BOOL MYBFacebookIsAdQuery(NSString *name){
 static NSSet<NSString *> *known;static dispatch_once_t once;
 dispatch_once(&once,^{known=[NSSet setWithArray:@[@"MarketplaceHomeFeedAdsQueryRendererQuery",@"MarketplaceHomeFeedAdsPaginationQuery",
  @"MarketplaceHomeFeedBoostedListingAdsQuery",@"MarketplaceHomeFeedBoostedListingAdsPaginationQuery",
  @"MarketplaceContextualSponsoredFeedSurfaceQuery",@"MarketplacePersonalizedSponsoredFeedQuery"]];});
 return name.length&&[known containsObject:name];
}
BOOL MYBFacebookIsMarketplaceQuery(NSString *name){return [name hasPrefix:@"Marketplace"];}

// ---- Marketplace: ad items inside other responses --------------------------------------------------------------------------
// Only the confirmed shape is processed: a JSON object with a "data" object, and only arrays stored under the key "edges". An edge is
// an ad when its own type, its node's, or its node story's type is one of the ad story types.
static BOOL MYBFacebookTypeIsAd(id type){
 if(![type isKindOfClass:NSString.class])return NO;
 NSString *t=type;
 return [t hasSuffix:@"AdStory"]||[t hasSuffix:@"AdsStory"]||[t hasPrefix:@"Sponsored"]||[t containsString:@"BoostedListingAd"];
}
BOOL MYBFacebookEdgeIsAd(id edge){
 if(![edge isKindOfClass:NSDictionary.class])return NO;
 if(MYBFacebookTypeIsAd(edge[@"__typename"]))return YES;
 id node=edge[@"node"];
 if(![node isKindOfClass:NSDictionary.class])return NO;
 if(MYBFacebookTypeIsAd(node[@"__typename"]))return YES;
 id story=node[@"story"];
 return [story isKindOfClass:NSDictionary.class]&&MYBFacebookTypeIsAd(story[@"__typename"]);
}
static NSUInteger MYBFacebookStrip(id value,BOOL isEdges){
 NSUInteger removed=0;
 if([value isKindOfClass:NSMutableArray.class]){
  NSMutableArray *list=value;
  for(NSInteger i=(NSInteger)list.count-1;i>=0;i--){
   if(isEdges&&MYBFacebookEdgeIsAd(list[i])){[list removeObjectAtIndex:i];removed++;}else removed+=MYBFacebookStrip(list[i],NO);
  }
 }else if([value isKindOfClass:NSMutableDictionary.class]){
  NSMutableDictionary *d=value;
  for(id key in [d allKeys])removed+=MYBFacebookStrip(d[key],[key isEqual:@"edges"]);
 }
 return removed;
}
// Structured, not text replacement: parse, remove ad edges, serialise. Returns the original object (same bytes) when nothing was an ad,
// when the data is not a confirmed shape, or when it does not parse.
NSData *MYBFacebookFilterResponse(NSData *data,NSUInteger *removedOut){
 if(removedOut)*removedOut=0;
 if(!data.length)return data;
 id parsed=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
 if(parsed){
  if(![parsed isKindOfClass:NSMutableDictionary.class]||![parsed[@"data"] isKindOfClass:NSDictionary.class])return data;
  NSUInteger removed=MYBFacebookStrip(parsed,NO);
  if(!removed)return data;
  NSData *out=[NSJSONSerialization dataWithJSONObject:parsed options:0 error:NULL];
  if(!out)return data;
  if(removedOut)*removedOut=removed;return out;
 }
 // Newline-delimited JSON (incremental delivery): each line that is a confirmed shape is filtered, every other line is kept as it was.
 NSString *text=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
 if(!text||![text containsString:@"\n"])return data;
 NSUInteger total=0;NSMutableArray *lines=[NSMutableArray array];
 for(NSString *line in [text componentsSeparatedByString:@"\n"]){
  NSData *lineData=[line dataUsingEncoding:NSUTF8StringEncoding];NSUInteger n=0;
  NSData *out=lineData.length?MYBFacebookFilterResponse(lineData,&n):lineData;
  NSString *replaced=n&&out?[[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding]:nil;
  if(replaced)total+=n;
  [lines addObject:replaced?:line];
 }
 if(!total)return data;
 if(removedOut)*removedOut=total;
 return [[lines componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
}
// The response the consumer sees must describe the body it receives: same status, URL and headers, with the length of the new body,
// and no content-encoding (the bytes handed over are plain JSON).
NSHTTPURLResponse *MYBFacebookResponseForBody(NSHTTPURLResponse *original,NSData *body){
 NSMutableDictionary *fields=[NSMutableDictionary dictionary];
 [original.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(id k,id v,BOOL *stop){
  if([k isKindOfClass:NSString.class]&&([k caseInsensitiveCompare:@"Content-Length"]==NSOrderedSame||[k caseInsensitiveCompare:@"Content-Encoding"]==NSOrderedSame))return;
  fields[k]=v;
 }];
 fields[@"Content-Length"]=[NSString stringWithFormat:@"%lu",(unsigned long)body.length];
 return [[NSHTTPURLResponse alloc] initWithURL:original.URL statusCode:original.statusCode HTTPVersion:@"HTTP/1.1" headerFields:fields]?:original;
}
static BOOL MYBFacebookResponseEligible(id response){
 if(![response isKindOfClass:NSHTTPURLResponse.class])return NO;
 NSHTTPURLResponse *r=response;if(r.statusCode!=200)return NO;
 NSString *type=[[r valueForHTTPHeaderField:@"Content-Type"] lowercaseString];
 return [type containsString:@"json"]||[type containsString:@"javascript"]||[type hasPrefix:@"text/plain"];
}

// ---- Marketplace: the handlers ---------------------------------------------------------------------------------------------
// React Native's networking layer asks a handler object to send each request and reports back to a delegate. Both sides are small
// informal protocols (send/cancel/priority; progress/response/data/complete), reproduced here by name and resolved at runtime.
#define MYB_FB_SEND_DATA sel_registerName("URLRequest:didReceiveData:")
#define MYB_FB_SEND_RESPONSE sel_registerName("URLRequest:didReceiveResponse:")
#define MYB_FB_SEND_DONE sel_registerName("URLRequest:didCompleteWithError:")
static void MYBFacebookCall2(id target,SEL sel,id a,id b){if([target respondsToSelector:sel])((void(*)(id,SEL,id,id))objc_msgSend)(target,sel,a,b);}

// A request that is answered without being sent. Whoever gets there first (the scheduled failure, or a cancel) completes it; the other is a no-op,
// so the delegate hears exactly one completion.
@interface MYBFacebookBlockedToken:NSObject
@property(nonatomic,strong) id delegate;
@property(nonatomic) int completed;
- (BOOL)finishWithError:(NSError *)error;
@end
@implementation MYBFacebookBlockedToken
- (BOOL)finishWithError:(NSError *)error{
 id delegate;
 @synchronized(self){if(self.completed)return NO;self.completed=1;delegate=self.delegate;self.delegate=nil;}
 MYBFacebookCall2(delegate,MYB_FB_SEND_DONE,self,error);
 return YES;
}
@end
@interface MYBFacebookBlockedHandler:NSObject @end
@implementation MYBFacebookBlockedHandler
- (BOOL)canHandleRequest:(NSURLRequest *)request{return YES;}
- (float)handlerPriority{return 0;}
- (id)sendRequest:(NSURLRequest *)request withDelegate:(id)delegate{
 MYBFacebookBlockedToken *token=[MYBFacebookBlockedToken new];token.delegate=delegate;
 MYBAdsNoteDecisions(@"facebook",@"request",1);
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{ // after the caller has stored the token
  [token finishWithError:[NSError errorWithDomain:@"net.myxxdev.mybloxx.ads" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Advertising request not sent"}]];
 });
 return token;
}
- (void)cancelRequest:(id)token{
 if([token isKindOfClass:MYBFacebookBlockedToken.class])[(MYBFacebookBlockedToken *)token finishWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
}
@end

// Sits between the app's handler and its delegate. Progress callbacks pass straight through. The response and body are held (up to a
// limit) so that, if ad edges are removed, the delegate is given a response whose length matches the new body.
#define MYB_FB_HOLD_LIMIT (4*1024*1024)
@interface MYBFacebookResponseFilter:NSObject
@property(nonatomic,strong) id delegate;
@property(nonatomic,strong) id heldResponse;
@property(nonatomic,strong) NSMutableData *buffer;
@property(nonatomic) BOOL passthrough,eligible;
@property(nonatomic,strong) id token;
@property(nonatomic,copy) void(^onFinish)(void);
@end
@implementation MYBFacebookResponseFilter
- (instancetype)initWithDelegate:(id)delegate{if((self=[super init])){_delegate=delegate;_buffer=[NSMutableData data];}return self;}
- (id)forwardingTargetForSelector:(SEL)selector{return self.delegate;}
- (BOOL)respondsToSelector:(SEL)selector{return [super respondsToSelector:selector]||[self.delegate respondsToSelector:selector];}
- (void)releaseHeld{ // sends on what was held back, unchanged
 if(self.heldResponse){id r=self.heldResponse;self.heldResponse=nil;MYBFacebookCall2(self.delegate,MYB_FB_SEND_RESPONSE,self.token,r);}
}
- (void)URLRequest:(id)token didReceiveResponse:(id)response{
 self.token=token;
 if(self.passthrough||!MYBFacebookResponseEligible(response)){self.passthrough=YES;MYBFacebookCall2(self.delegate,MYB_FB_SEND_RESPONSE,token,response);return;}
 self.eligible=YES;self.heldResponse=response;
}
- (void)URLRequest:(id)token didReceiveData:(NSData *)data{
 self.token=token;
 if(self.passthrough){MYBFacebookCall2(self.delegate,MYB_FB_SEND_DATA,token,data);return;}
 [self.buffer appendData:data];
 if(self.buffer.length>MYB_FB_HOLD_LIMIT){ // too large to hold: stop filtering this response and deliver it as it is
  self.passthrough=YES;[self releaseHeld];
  NSData *held=[self.buffer copy];self.buffer=[NSMutableData data];
  MYBAdsNoteDecisions(@"facebook",@"oversize",1);
  MYBFacebookCall2(self.delegate,MYB_FB_SEND_DATA,token,held);
 }
}
- (void)URLRequest:(id)token didCompleteWithError:(NSError *)error{
 self.token=token;
 if(!self.passthrough){
  NSData *body=self.buffer;NSUInteger removed=0;
  NSData *out=(error||!self.eligible)?body:MYBFacebookFilterResponse(body,&removed);
  if(removed&&[self.heldResponse isKindOfClass:NSHTTPURLResponse.class])self.heldResponse=MYBFacebookResponseForBody(self.heldResponse,out);
  [self releaseHeld];
  if(out.length)MYBFacebookCall2(self.delegate,MYB_FB_SEND_DATA,token,out);
  if(removed)MYBAdsNoteDecisions(@"facebook",@"feed",removed);
  self.buffer=[NSMutableData data];
 }
 MYBFacebookCall2(self.delegate,MYB_FB_SEND_DONE,token,error);
 if(self.onFinish){void(^f)(void)=self.onFinish;self.onFinish=nil;f();}
}
@end

static NSMutableSet *MYBFacebookInflight(void){static NSMutableSet *set;static dispatch_once_t once;dispatch_once(&once,^{set=[NSMutableSet set];});return set;}
@interface MYBFacebookWrappedHandler:NSObject
@property(nonatomic,strong) id inner;
@end
@implementation MYBFacebookWrappedHandler
- (id)forwardingTargetForSelector:(SEL)selector{return self.inner;}
- (BOOL)respondsToSelector:(SEL)selector{return [super respondsToSelector:selector]||[self.inner respondsToSelector:selector];}
- (BOOL)conformsToProtocol:(Protocol *)protocol{return [super conformsToProtocol:protocol]||[self.inner conformsToProtocol:protocol];}
- (id)sendRequest:(NSURLRequest *)request withDelegate:(id)delegate{
 MYBFacebookResponseFilter *filter=[[MYBFacebookResponseFilter alloc] initWithDelegate:delegate];
 // The filter lives until the request completes. (Held in a set rather than on the token: the token may not be an object that takes associations.)
 @synchronized(MYBFacebookInflight()){[MYBFacebookInflight() addObject:filter];}
 __weak MYBFacebookResponseFilter *weakFilter=filter; // the in-flight set holds the strong reference; the block must not
 filter.onFinish=^{MYBFacebookResponseFilter *f=weakFilter;if(f)@synchronized(MYBFacebookInflight()){[MYBFacebookInflight() removeObject:f];}};
 id token=((id(*)(id,SEL,id,id))objc_msgSend)(self.inner,sel_registerName("sendRequest:withDelegate:"),request,filter);
 if(!token){@synchronized(MYBFacebookInflight()){[MYBFacebookInflight() removeObject:filter];}}
 return token;
}
@end

// ---- News Feed: classification that arrives after init ---------------------------------------------------------------------
// The upstream-evidenced hook classifies a unit at init. A list of already-built units can be re-checked once their classification is
// present: ads are removed, ordinary units are kept in order. NOT yet connected to the app's data source (that class has not been
// inspected; Status > Collect discovery details logs exactly the data-source class and selectors needed), so today it backs the tests and
// diagnostics only. It stays unconnected until a device log names the real insertion or update method; wiring it blind could change ordinary feed behaviour.
NSArray *MYBFacebookWithoutAds(NSArray *models){
 NSMutableArray *kept=[NSMutableArray arrayWithCapacity:models.count];
 for(id m in models)if(!MYBFacebookModelIsAd(m))[kept addObject:m];
 return kept.count==models.count?models:kept;
}
// Bounded, opt-in discovery (Status > Collect discovery details): names only, no content. It answers the open question about the real
// insertion path: which object the feed list is backed by, which of its methods insert or update items (with their full signatures, so a
// hook can be written exactly), and what kinds of model objects the app builds and whether each carries its classification at creation.
NSArray<NSString *> *MYBFacebookItemSelectors(Class cls){
 return MYBAdsDiscoverySelectors(cls,@[@"item",@"unit",@"edge",@"insert",@"update",@"section",@"model",@"story",@"feed",@"batch",@"append",@"reload"],40);
}
// Everything one collection holds, as plain data. windows are the app's windows; tests pass their own views.
NSDictionary *MYBFacebookDiscoveryInfo(NSUInteger phase,NSArray *windows,NSArray<NSString *> *imageFragments){
 NSMutableDictionary *sources=[NSMutableDictionary dictionary];
 NSMutableArray *queue=[windows mutableCopy];NSUInteger visited=0;SEL dsSel=sel_registerName("dataSource");
 while(queue.count&&visited<4000){
  id view=queue.firstObject;[queue removeObjectAtIndex:0];visited++;
  if([view respondsToSelector:dsSel]&&sources.count<6){
   id ds=((id(*)(id,SEL))objc_msgSend)(view,dsSel);
   if(ds&&!sources[NSStringFromClass([ds class])])sources[NSStringFromClass([ds class])]=@{@"listView":NSStringFromClass([view class]),@"chain":MYBAdsDiscoveryChain(object_getClass(ds)),@"selectors":MYBFacebookItemSelectors(object_getClass(ds))};
  }
  id kids=[view respondsToSelector:sel_registerName("subviews")]?((id(*)(id,SEL))objc_msgSend)(view,sel_registerName("subviews")):nil;
  if([kids isKindOfClass:NSArray.class])[queue addObjectsFromArray:kids];
 }
 return @{@"phase":@(phase),@"unclassifiedAtInit":@(MYBFacebookUnclassified),@"modelTypes":MYBFacebookModelTypes?MYBFacebookModelTypes.snapshot:@{},
  @"dataSources":sources,@"adLikeClasses":MYBAdsDiscoveryAdLikeClasses(imageFragments,MYB_ADS_DISCOVERY_MAX_ITEMS),@"viewClasses":MYBAdsDiscoveryViewClasses(windows,4000)};
}

static id hookHandlerForRequest(id self,SEL _cmd,NSURLRequest *request){
 NSString *name=MYBFacebookQueryName(request);
 if(MYBFacebookIsAdQuery(name))return [MYBFacebookBlockedHandler new];
 id handler=origHandlerForRequest?((id(*)(id,SEL,id))origHandlerForRequest)(self,_cmd,request):nil;
 if(handler&&MYBFacebookIsMarketplaceQuery(name)&&[handler respondsToSelector:sel_registerName("sendRequest:withDelegate:")]){
  MYBFacebookWrappedHandler *wrapped=[MYBFacebookWrappedHandler new];wrapped.inner=handler;return wrapped;
 }
 return handler;
}

// ---- Install ---------------------------------------------------------------------------------------------------------------
// The networking layer is loaded by the app after launch, so Marketplace hooks are retried once when the class appears.
NSUInteger MYBFacebookInstallHooks(NSUInteger *attempted){
 NSUInteger ok=0;
 if(MYBAdsHookNamed("FBMemModelObject","initWithFBPandoTree:",NO,(IMP)hookPandoInit,&origPandoInit))ok++;
 if(MYBAdsHookNamed("FBVideoFeedAdsPool","insertedItems",NO,(IMP)hookVideoItems,&origVideoItems))ok++;
 if(MYBAdsHookNamed("FBSnacksAdsPaginatingFetcher","startFetch:organicConsumption:",NO,(IMP)hookStoryStart,&origStoryStart))ok++;
 if(MYBAdsHookNamed("FBSnacksAdsPaginatingFetcher","fetchAdsForStoryWithRequestPayload:",NO,(IMP)hookStoryFetch,&origStoryFetch))ok++;
 if(MYBAdsHookNamed("FBSnacksAdsPaginatingFetcher","fetchAdsForStoryWithRequestPayloadAsync:",NO,(IMP)hookStoryFetch,&origStoryFetchAsync))ok++;
 if(MYBAdsHookNamed("RCTNetworking","handlerForRequest:",NO,(IMP)hookHandlerForRequest,&origHandlerForRequest))ok++;
 if(attempted)*attempted=6;return ok;
}
int32_t MYBFacebookUnclassifiedCount(void){return MYBFacebookUnclassified;}
#ifndef MYB_INAPPADS_TESTING
static void MYBFacebookDiscover(void){
 MYBFacebookModelTypes=[[MYBAdsDiscoveryCounter alloc] initWithCap:MYB_ADS_DISCOVERY_MAX_ITEMS];
 for(NSNumber *delay in @[@25,@80])
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.intValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   MYBAdsDiscoveryLog(@"facebook",MYBFacebookDiscoveryInfo(delay.unsignedIntegerValue,MYBAdsDiscoveryWindows(),@[@"Facebook.app"]));
  });
}
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_facebook(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  // Collecting interface details needs no switch: with Facebook's ad switch off nothing is hooked and nothing is blocked; only class,
  // selector and view names are gathered during the session (model counts need the hooks, so they stay empty). It starts now if a session is
  // running, and when one is started later while the app is already open. Set up before the hooks, so every model built from then on is counted.
  MYBAdsDiscoveryWatch(@"facebook",^(NSString *session){MYBAdsDiscoveryStarted(@"facebook",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);MYBFacebookDiscover();});
  if(!MYBAdsModuleEnabled(prefs,@"facebook"))return;
  MYBAdsReportLoaded(@"facebook",@MYB_COMPONENT_VERSION);
  NSUInteger attempted=0,ok=MYBFacebookInstallHooks(&attempted);
  MYBAdsLogResult("facebook",ok,attempted);
  MYBAdsReportHooks(@"facebook",ok,attempted,0);
  if(ok<attempted){ // the React Native layer is loaded later: look again shortly after launch
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(8*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
    if(!origHandlerForRequest&&MYBAdsHookNamed("RCTNetworking","handlerForRequest:",NO,(IMP)hookHandlerForRequest,&origHandlerForRequest))MYBAdsReportHooks(@"facebook",ok+1,attempted,0);
   });
  }
 }
}
#endif
