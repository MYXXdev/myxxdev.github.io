// Facebook module: classification, structured response filtering, the request handlers and hook installation, against stand-in classes.
// Stand-ins prove the module's own logic and its fail-open behaviour. They do not prove the real app's classes behave the same way.
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#import <objc/message.h>
#include "../Companions/InAppAds/Facebook/Module.m"
static int failures=0;static char kC,kS,kP;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)

typedef __attribute__((ns_returns_retained)) id (*InitCall)(id,SEL,void *);
static BOOL nextIsAd=NO;static int deallocs=0;
@interface Probe:NSObject @end
@implementation Probe
-(void)dealloc{deallocs++;}
@end
__attribute__((ns_returns_retained)) static id fakeModelInit(id s,SEL c,void *t){
 objc_setAssociatedObject(s,&kP,[Probe new],OBJC_ASSOCIATION_RETAIN);
 if(nextIsAd)objc_setAssociatedObject(s,&kC,@"SPONSORED",OBJC_ASSOCIATION_RETAIN);
 return s;}
static int fetches=0,starts=0;
static void fakeStart(id s,SEL c,id a,id b){starts++;}
static void fakeFetch(id s,SEL c,id p){fetches++;}
static NSArray *fakeItems(id s,SEL c){return @[@"a",@"b"];}

@interface FakeDelegate:NSObject
@property NSMutableArray *events;@property NSMutableData *body;@property id response;@property NSError *error;
@end
@implementation FakeDelegate
- (instancetype)init{if((self=[super init])){_events=[NSMutableArray array];_body=[NSMutableData data];}return self;}
- (void)URLRequest:(id)t didSendDataWithProgress:(int64_t)n{[self.events addObject:@"progress"];}
- (void)URLRequest:(id)t didReceiveResponse:(NSURLResponse *)r{@synchronized(self){[self.events addObject:@"response"];self.response=r;}}
- (void)URLRequest:(id)t didReceiveData:(NSData *)d{[self.events addObject:@"data"];[self.body appendData:d];}
- (void)URLRequest:(id)t didCompleteWithError:(NSError *)e{@synchronized(self){[self.events addObject:e?@"error":@"done"];self.error=e;}}
- (NSUInteger)completions{@synchronized(self){NSUInteger n=0;for(NSString *x in self.events)if([x isEqual:@"error"]||[x isEqual:@"done"])n++;return n;}}
@end
@interface FakeHandler:NSObject
@property NSArray<NSData *> *chunks;@property BOOL fail;@property id response;
@end
@implementation FakeHandler
- (BOOL)canHandleRequest:(NSURLRequest *)r{return YES;}
- (float)handlerPriority{return 1;}
- (id)sendRequest:(NSURLRequest *)r withDelegate:(id)d{
 id token=[NSObject new];
 ((void(*)(id,SEL,id,int64_t))objc_msgSend)(d,sel_registerName("URLRequest:didSendDataWithProgress:"),token,5);
 ((void(*)(id,SEL,id,id))objc_msgSend)(d,sel_registerName("URLRequest:didReceiveResponse:"),token,self.response);
 for(NSData *c in self.chunks)((void(*)(id,SEL,id,id))objc_msgSend)(d,sel_registerName("URLRequest:didReceiveData:"),token,c);
 ((void(*)(id,SEL,id,id))objc_msgSend)(d,sel_registerName("URLRequest:didCompleteWithError:"),token,self.fail?[NSError errorWithDomain:@"x" code:1 userInfo:nil]:nil);
 return token;
}
@end
static FakeHandler *innerHandler;
static id fakeHandlerFor(id s,SEL c,NSURLRequest *r){return innerHandler;}
static NSData *J(id o){return [NSJSONSerialization dataWithJSONObject:o options:0 error:NULL];}
static NSMutableURLRequest *Req(NSString *name){NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://example.invalid/graphql"]];if(name)[r setValue:name forHTTPHeaderField:@"X-FB-Friendly-Name"];return r;}

int main(void){@autoreleasepool{
 NSUInteger attempted=0;
 REQUIRE(MYBFacebookInstallHooks(&attempted)==0&&attempted==6,"Facebook: no classes, no hooks");

 // classification of feed models
 Class model=objc_allocateClassPair(NSObject.class,"FBMemModelObject",0);objc_registerClassPair(model);
 class_addMethod(model,sel_registerName("initWithFBPandoTree:"),(IMP)fakeModelInit,"@@:^v");
 class_addMethod(model,sel_registerName("category"),imp_implementationWithBlock(^id(id s){return objc_getAssociatedObject(s,&kC);}),"@@:");
 class_addMethod(model,sel_registerName("sponsoredData"),imp_implementationWithBlock(^id(id s){return objc_getAssociatedObject(s,&kS);}),"@@:");
 Class pool=objc_allocateClassPair(NSObject.class,"FBVideoFeedAdsPool",0);objc_registerClassPair(pool);
 class_addMethod(pool,sel_registerName("insertedItems"),(IMP)fakeItems,"@@:");
 Class fetcher=objc_allocateClassPair(NSObject.class,"FBSnacksAdsPaginatingFetcher",0);objc_registerClassPair(fetcher);
 class_addMethod(fetcher,sel_registerName("startFetch:organicConsumption:"),(IMP)fakeStart,"v@:@@");
 class_addMethod(fetcher,sel_registerName("fetchAdsForStoryWithRequestPayload:"),(IMP)fakeFetch,"v@:@");
 class_addMethod(fetcher,sel_registerName("fetchAdsForStoryWithRequestPayloadAsync:"),(IMP)fakeFetch,"v@:@");
 Class net=objc_allocateClassPair(NSObject.class,"RCTNetworking",0);objc_registerClassPair(net);
 class_addMethod(net,sel_registerName("handlerForRequest:"),(IMP)fakeHandlerFor,"@@:@");
 REQUIRE(MYBFacebookInstallHooks(&attempted)==6,"Facebook: all six hooks installed");

 id organic=[model new];objc_setAssociatedObject(organic,&kC,@"NEWS_FEED",OBJC_ASSOCIATION_RETAIN);
 id sponsored=[model new];objc_setAssociatedObject(sponsored,&kC,@"SPONSORED",OBJC_ASSOCIATION_RETAIN);
 id paid=[model new];objc_setAssociatedObject(paid,&kS,@{@"x":@1},OBJC_ASSOCIATION_RETAIN);
 REQUIRE(!MYBFacebookModelIsAd(organic)&&!MYBFacebookModelIsAd(nil)&&MYBFacebookModelIsAd(sponsored)&&MYBFacebookModelIsAd(paid),"Facebook: only sponsored units are ads");
 // the real hooked initialiser, called the way the runtime calls it (+1 object in, +1 object out)
 nextIsAd=NO;
 id kept=((__attribute__((ns_returns_retained)) id(*)(id,SEL,void *))objc_msgSend)([model alloc],sel_registerName("initWithFBPandoTree:"),NULL);
 REQUIRE(kept!=nil&&deallocs==0,"Facebook: an organic unit is kept");
 nextIsAd=YES;
 @autoreleasepool{
  id dropped=((__attribute__((ns_returns_retained)) id(*)(id,SEL,void *))objc_msgSend)([model alloc],sel_registerName("initWithFBPandoTree:"),NULL);
  REQUIRE(dropped==nil,"Facebook: a sponsored unit never leaves the initialiser");
 }
 REQUIRE(deallocs==1,"Facebook: the rejected unit was freed exactly once (no leak, no double release)");


 // classification arriving after init: the unit is kept at init (and counted as unclassified), then re-checked once it is classified
 nextIsAd=NO;int32_t before=MYBFacebookUnclassifiedCount();
 id late=((__attribute__((ns_returns_retained)) id(*)(id,SEL,void *))objc_msgSend)([model alloc],sel_registerName("initWithFBPandoTree:"),NULL);
 id plainUnit=((__attribute__((ns_returns_retained)) id(*)(id,SEL,void *))objc_msgSend)([model alloc],sel_registerName("initWithFBPandoTree:"),NULL);
 REQUIRE(late!=nil&&MYBFacebookUnclassifiedCount()==before+2,"Facebook: an unclassified unit is kept at init and counted");
 NSArray *units=@[organic,late,plainUnit,kept];
 REQUIRE(MYBFacebookWithoutAds(units)==units,"Facebook: before classification nothing is removed");
 objc_setAssociatedObject(late,&kC,@"SPONSORED",OBJC_ASSOCIATION_RETAIN); // the marker is assigned after init
 NSArray *settled=MYBFacebookWithoutAds(units);
 REQUIRE(settled.count==3&&settled[0]==organic&&settled[1]==plainUnit&&settled[2]==kept,"Facebook: once classified the late ad is removed and ordinary units keep their order");
 // entries are "-name signature" (the signature is what lets a hook be written exactly), so match on the selector name that follows the sign
 BOOL (^lists)(NSArray *,NSString *)=^BOOL(NSArray *entries,NSString *name){for(NSString *e in entries)if([e hasPrefix:[@"-" stringByAppendingString:name]]&&([e length]==name.length+1||[e characterAtIndex:name.length+1]==' '))return YES;return NO;};
 REQUIRE(!lists(MYBFacebookItemSelectors(model),@"initWithFBPandoTree:")&&lists(MYBFacebookItemSelectors(pool),@"insertedItems"),"Facebook: discovery lists only item-like selectors, by name");

 // Watch and Stories
 id p=[pool new];REQUIRE([((NSArray *(*)(id,SEL))objc_msgSend)(p,sel_registerName("insertedItems")) count]==0,"Facebook: Watch ad list is empty");
 id f=[fetcher new];
 ((void(*)(id,SEL,id,id))objc_msgSend)(f,sel_registerName("startFetch:organicConsumption:"),nil,nil);
 ((void(*)(id,SEL,id))objc_msgSend)(f,sel_registerName("fetchAdsForStoryWithRequestPayload:"),nil);
 ((void(*)(id,SEL,id))objc_msgSend)(f,sel_registerName("fetchAdsForStoryWithRequestPayloadAsync:"),nil);
 REQUIRE(starts==0&&fetches==0,"Facebook: story ad requests are not made");

 // query identification
 REQUIRE(MYBFacebookIsAdQuery(@"MarketplaceHomeFeedAdsQueryRendererQuery")&&MYBFacebookIsAdQuery(@"MarketplaceHomeFeedAdsPaginationQuery")&&MYBFacebookIsAdQuery(@"MarketplaceHomeFeedBoostedListingAdsQuery"),"Facebook: the named ad queries are recognised");
 REQUIRE(!MYBFacebookIsAdQuery(@"MarketplacePDPQuery")&&!MYBFacebookIsAdQuery(@"MarketplaceAddressSearchQuery")&&!MYBFacebookIsAdQuery(@"")&&!MYBFacebookIsAdQuery(nil),"Facebook: ordinary queries are never failed");
 REQUIRE([MYBFacebookQueryName(Req(@"MarketplaceX")) isEqual:@"MarketplaceX"],"Facebook: name from the header");
 NSMutableURLRequest *bodyReq=Req(nil);bodyReq.HTTPBody=[@"a=1&fb_api_req_friendly_name=MarketplaceY%20Q&b=2" dataUsingEncoding:NSUTF8StringEncoding];
 REQUIRE([MYBFacebookQueryName(bodyReq) isEqual:@"MarketplaceY Q"],"Facebook: name from the body when the header is absent");

 // structured filtering
 id doc=@{@"data":@{@"marketplace_feed":@{@"edges":@[
  @{@"node":@{@"__typename":@"MarketplaceFeedListingStoryObject",@"id":@"1"}},
  @{@"node":@{@"__typename":@"MarketplaceFeedAdStory",@"id":@"2"}},
  @{@"node":@{@"story":@{@"__typename":@"MarketplaceSearchAdStory"},@"id":@"3"}},
  @{@"node":@{@"__typename":@"MarketplaceFeedListingStoryObject",@"id":@"4",@"title":@"Address Additional"}}],
  @"page_info":@{@"has_next_page":@YES,@"end_cursor":@"c"}}}};
 NSUInteger removed=0;NSData *out=MYBFacebookFilterResponse(J(doc),&removed);
 NSDictionary *back=[NSJSONSerialization JSONObjectWithData:out options:0 error:NULL];
 NSArray *edges=back[@"data"][@"marketplace_feed"][@"edges"];
 REQUIRE(removed==2&&edges.count==2&&[edges[0][@"node"][@"id"] isEqual:@"1"]&&[edges[1][@"node"][@"id"] isEqual:@"4"],"Facebook: exactly the two ad edges removed, organic listings kept in order");
 REQUIRE([back[@"data"][@"marketplace_feed"][@"page_info"][@"end_cursor"] isEqual:@"c"],"Facebook: pagination data is untouched");
 NSData *clean=J(@{@"data":@{@"edges":@[@{@"node":@{@"__typename":@"MarketplaceFeedListingStoryObject"}}]}});
 REQUIRE([MYBFacebookFilterResponse(clean,&removed) isEqual:clean]&&removed==0,"Facebook: a response without ads is returned byte for byte");
 NSData *garbage=[@"not json {" dataUsingEncoding:NSUTF8StringEncoding];
 REQUIRE([MYBFacebookFilterResponse(garbage,&removed) isEqual:garbage],"Facebook: unparseable data passes unchanged");
 NSMutableData *nd=[NSMutableData data];[nd appendData:J(@{@"data":@{@"edges":@[@{@"__typename":@"MarketplaceFeedAdStory"},@{@"__typename":@"Listing"}]}})];[nd appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];[nd appendData:[@"{broken" dataUsingEncoding:NSUTF8StringEncoding]];
 NSData *ndOut=MYBFacebookFilterResponse(nd,&removed);NSString *ndText=[[NSString alloc] initWithData:ndOut encoding:NSUTF8StringEncoding];
 REQUIRE(removed==1&&[ndText containsString:@"Listing"]&&![ndText containsString:@"AdStory"]&&[ndText hasSuffix:@"{broken"],"Facebook: newline-delimited responses are filtered line by line, unparseable lines kept");


 // diagnostics sink: records what the module reports, to check the size-limit accounting
 NSMutableArray *sent=[NSMutableArray array];
 MYBAdsReportSink=^(NSString *path){@synchronized(sent){[sent addObject:path];}};

 id networking=[net new];
 SEL hfr=sel_registerName("handlerForRequest:");
 SEL send=sel_registerName("sendRequest:withDelegate:"),cancel=sel_registerName("cancelRequest:");
 #define SEND(h,d) ((id(*)(id,SEL,id,id))objc_msgSend)((h),send,Req(nil),(d))
 // --- ad query: failed through the error callback, once, never as a success
 id blocked=((id(*)(id,SEL,id))objc_msgSend)(networking,hfr,Req(@"MarketplaceHomeFeedAdsQueryRendererQuery"));
 FakeDelegate *d1=[FakeDelegate new];
 id token=SEND(blocked,d1);
 REQUIRE(token!=nil,"Facebook: the blocked handler returns a token");
 NSDate *until=[NSDate dateWithTimeIntervalSinceNow:3];while(!d1.completions&&[until timeIntervalSinceNow]>0)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
 REQUIRE([d1.events isEqual:@[@"error"]]&&d1.error!=nil,"Facebook: an ad query completes once, with an error, and no fake success");
 ((void(*)(id,SEL,id))objc_msgSend)(blocked,cancel,token);
 REQUIRE(d1.completions==1,"Facebook: cancelling after completion does not complete it again");
 // --- cancellation before the scheduled failure: completes once, as a cancellation
 FakeDelegate *d2c=[FakeDelegate new];
 id t2=SEND(blocked,d2c);
 ((void(*)(id,SEL,id))objc_msgSend)(blocked,cancel,t2);
 ((void(*)(id,SEL,id))objc_msgSend)(blocked,cancel,t2);
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
 REQUIRE(d2c.completions==1,"Facebook: a cancelled ad query completes exactly once, however many cancels and the scheduled failure");
 REQUIRE([d2c.error.domain isEqual:NSURLErrorDomain]||[d2c.error.domain isEqual:@"net.myxxdev.mybloxx.ads"],"Facebook: the completion carries an error");
 ((void(*)(id,SEL,id))objc_msgSend)(blocked,cancel,[NSObject new]); // a token that is not ours is ignored
 // --- many concurrent requests, some cancelled from other threads
 NSMutableArray *ds=[NSMutableArray array];NSMutableArray *tokens=[NSMutableArray array];
 for(int i=0;i<200;i++){FakeDelegate *d=[FakeDelegate new];[ds addObject:d];[tokens addObject:SEND(blocked,d)];}
 dispatch_apply(200,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^(size_t i){if(i%2==0)((void(*)(id,SEL,id))objc_msgSend)(blocked,cancel,tokens[i]);});
 until=[NSDate dateWithTimeIntervalSinceNow:5];
 BOOL all=NO;while(!all&&[until timeIntervalSinceNow]>0){all=YES;for(FakeDelegate *d in ds)if(d.completions<1)all=NO;[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];}
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
 BOOL exactlyOnce=all;for(FakeDelegate *d in ds)if(d.completions!=1)exactlyOnce=NO;
 REQUIRE(exactlyOnce,"Facebook: 200 concurrent ad queries (half cancelled) each complete exactly once");

 // --- blended response: ads removed, consumer gets a consistent response and body
 NSData *adBody=J(doc);
 NSHTTPURLResponse *(^Resp)(NSInteger,NSString *,NSUInteger)=^NSHTTPURLResponse *(NSInteger code,NSString *type,NSUInteger len){
  return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.invalid/graphql"] statusCode:code HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type":type,@"Content-Length":[NSString stringWithFormat:@"%lu",(unsigned long)len],@"Content-Encoding":@"gzip",@"X-Keep":@"1"}];};
 innerHandler=[FakeHandler new];
 innerHandler.response=Resp(200,@"application/json",adBody.length);
 innerHandler.chunks=@[[adBody subdataWithRange:NSMakeRange(0,20)],[adBody subdataWithRange:NSMakeRange(20,adBody.length-20)]];
 id wrapped=((id(*)(id,SEL,id))objc_msgSend)(networking,hfr,Req(@"MarketplaceHomeFeedQuery"));
 REQUIRE(wrapped!=innerHandler&&[wrapped canHandleRequest:Req(nil)]&&[wrapped handlerPriority]==1,"Facebook: a Marketplace request is wrapped and still answers the handler questions");
 FakeDelegate *d3=[FakeDelegate new];
 SEND(wrapped,d3);
 NSDictionary *got=[NSJSONSerialization JSONObjectWithData:d3.body options:0 error:NULL];
 REQUIRE([got[@"data"][@"marketplace_feed"][@"edges"] count]==2,"Facebook: the delegate receives the filtered body");
 REQUIRE([d3.events isEqual:(@[@"progress",@"response",@"data",@"done"])],"Facebook: progress, then one response, then the body once, then completion");
 NSHTTPURLResponse *r3=d3.response;
 REQUIRE([r3 isKindOfClass:NSHTTPURLResponse.class]&&[r3.allHeaderFields[@"Content-Length"] integerValue]==(NSInteger)d3.body.length&&d3.body.length<adBody.length,"Facebook: the response length matches the changed body");
 REQUIRE(r3.allHeaderFields[@"Content-Encoding"]==nil&&[r3.allHeaderFields[@"X-Keep"] isEqual:@"1"]&&r3.statusCode==200&&[r3.URL.host isEqual:@"example.invalid"],"Facebook: other headers, status and URL are kept; the stale encoding is dropped");
 // nothing changed: the very same response object and the original bytes
 NSData *cleanBody=J(@{@"data":@{@"edges":@[@{@"node":@{@"__typename":@"MarketplaceFeedListingStoryObject"}}]}});
 innerHandler.response=Resp(200,@"application/json",cleanBody.length);innerHandler.chunks=@[cleanBody];
 FakeDelegate *d4=[FakeDelegate new];SEND(wrapped,d4);
 REQUIRE([d4.body isEqual:cleanBody]&&d4.response==innerHandler.response,"Facebook: with no ads the original response object and bytes are delivered");
 // unparseable
 innerHandler.response=Resp(200,@"application/json",9);innerHandler.chunks=@[garbage];
 FakeDelegate *d5=[FakeDelegate new];SEND(wrapped,d5);
 REQUIRE([d5.body isEqual:garbage]&&d5.response==innerHandler.response,"Facebook: unparseable data passes unchanged");
 // not a confirmed shape (no data object), and an ad-like edge outside an edges array
 NSData *wrongShape=J(@{@"edges":@[@{@"__typename":@"MarketplaceFeedAdStory"}]});
 innerHandler.response=Resp(200,@"application/json",wrongShape.length);innerHandler.chunks=@[wrongShape];
 FakeDelegate *d6=[FakeDelegate new];SEND(wrapped,d6);
 REQUIRE([d6.body isEqual:wrongShape],"Facebook: an object without a data object is not a confirmed shape and is untouched");
 NSData *notEdges=J(@{@"data":@{@"items":@[@{@"__typename":@"MarketplaceFeedAdStory"}]}});
 innerHandler.response=Resp(200,@"application/json",notEdges.length);innerHandler.chunks=@[notEdges];
 FakeDelegate *d7=[FakeDelegate new];SEND(wrapped,d7);
 REQUIRE([d7.body isEqual:notEdges],"Facebook: only arrays under \"edges\" are touched");
 // not JSON content, or not 200: forwarded at once, untouched
 innerHandler.response=Resp(200,@"image/jpeg",adBody.length);innerHandler.chunks=@[adBody];
 FakeDelegate *d8=[FakeDelegate new];SEND(wrapped,d8);
 REQUIRE([d8.body isEqual:adBody]&&d8.response==innerHandler.response,"Facebook: a non-JSON response is not processed");
 innerHandler.response=Resp(500,@"application/json",adBody.length);innerHandler.chunks=@[adBody];
 FakeDelegate *d9=[FakeDelegate new];SEND(wrapped,d9);
 REQUIRE([d9.body isEqual:adBody],"Facebook: an error status is not processed");
 // failure: response and bytes handed over as they arrived, then the error, once
 innerHandler.response=Resp(200,@"application/json",adBody.length);innerHandler.chunks=@[adBody];innerHandler.fail=YES;
 FakeDelegate *d10=[FakeDelegate new];SEND(wrapped,d10);
 REQUIRE([d10.body isEqual:adBody]&&d10.response==innerHandler.response&&d10.completions==1&&[d10.events.lastObject isEqual:@"error"],"Facebook: a failed request keeps its response and bytes and reports the error once");
 innerHandler.fail=NO;
 // not Marketplace: the app's own handler, untouched
 id plain=((id(*)(id,SEL,id))objc_msgSend)(networking,hfr,Req(@"FeedQuery"));
 REQUIRE(plain==innerHandler,"Facebook: a request outside Marketplace is not wrapped");
 // size limit: streamed as received, and recorded as passed through, not as filtered
 // Earlier tests recorded decisions before this sink existed, so their report is still waiting on the app-mode 20 second timer;
 // flush it now so the batch below starts empty and this response's own report is scheduled for the immediate test-mode flush.
 MYBAdsFlush(@"facebook");
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
 @synchronized(sent){[sent removeAllObjects];}
 NSMutableData *big=[NSMutableData dataWithLength:5*1024*1024];
 innerHandler.response=Resp(200,@"application/json",big.length+4);innerHandler.chunks=@[big,[@"tail" dataUsingEncoding:NSUTF8StringEncoding]];
 FakeDelegate *d11=[FakeDelegate new];SEND(wrapped,d11);
 REQUIRE(d11.body.length==big.length+4&&d11.response==innerHandler.response&&d11.completions==1,"Facebook: a body over the size limit passes through whole, with its original response");
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
 NSString *report;@synchronized(sent){report=[sent componentsJoinedByString:@" "];}
 if(![report containsString:@"oversize"]||[report containsString:@"feed"]){
  printf("diagnostic: reports after the oversize response: [%s]; pending: %s; body %lu of %lu; completions %d\n",report.UTF8String,[[MYBAdsPending() description] UTF8String],(unsigned long)d11.body.length,(unsigned long)big.length,(int)d11.completions);
  MYBAdsNoteDecisions(@"facebook",@"control",1);[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
  @synchronized(sent){printf("diagnostic: control note reached the sink: %s\n",[[sent componentsJoinedByString:@" "] containsString:@"control"]?"yes":"no");}
 }
 REQUIRE([report containsString:@"oversize"]&&![report containsString:@"feed"],"Facebook: the size-limit pass-through is reported as oversize, never as a filtered feed item");
 {
  NSDictionary *bundles=@{@"facebook":@[@"com.facebook.Facebook"]};
  NSTimeInterval now=1000;
  REQUIRE(MYBAdsRecordEvent(@{@"module":@"facebook",@"app":@"com.facebook.Facebook",@"phase":@"loaded",@"av":@"1.0",@"arch":@"arm64",@"ver":@"1"},bundles,now),"Facebook: load accepted");
  REQUIRE(MYBAdsRecordEvent(@{@"module":@"facebook",@"app":@"com.facebook.Facebook",@"phase":@"decisions",@"cat":@"oversize:2"},bundles,now),"Facebook: oversize report accepted");
  NSDictionary *rec=MYBAdsSnapshot()[@"facebook"];
  REQUIRE([rec[@"decisions"] intValue]==0&&[rec[@"passedThrough"] intValue]==2&&![rec[@"state"] isEqual:@"filtering"],"Facebook: passed-through responses are not counted as filtered and do not make the module look active");
 }
 MYBAdsReportSink=nil;
 if(failures)return 1;printf("Facebook ad module checks passed.\n");return 0;}}
