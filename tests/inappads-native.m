// Behaviour tests for the In-App Ad Blocking helper and the Instagram, YouTube, SoundCloud and Reddit modules, run on
// real Objective-C classes built at run time (the apps themselves are not available to CI).
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../Shared/MYBAdsReport.h"
#include "../Companions/InAppAds/Instagram/Module.m"
#include "../Companions/InAppAds/YouTube/Module.m"
#include "../Companions/InAppAds/SoundCloud/Module.m"
#include "../Companions/InAppAds/Reddit/Module.m"
static int failures=0;
static NSMutableArray *sent;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)
static Class make(const char *name,Class sup){Class c=objc_allocateClassPair(sup?:NSObject.class,name,0);objc_registerClassPair(c);return c;}
static void add(Class c,const char *sel,id block,const char *types){class_addMethod(c,sel_registerName(sel),imp_implementationWithBlock(block),types);}
static void addClass(Class c,const char *sel,id block,const char *types){class_addMethod(object_getClass(c),sel_registerName(sel),imp_implementationWithBlock(block),types);}

int main(void){@autoreleasepool{
 sent=[NSMutableArray array];MYBAdsReportSink=^(NSString *path){@synchronized(sent){[sent addObject:path];}};
 // ---- preferences: off unless explicitly on
 REQUIRE(MYBAdsModuleEnabled(nil,@"youtube"),"missing prefs mean on");
 REQUIRE(MYBAdsModuleEnabled(@{},@"youtube"),"absent key means on");
 REQUIRE(MYBAdsModuleEnabled(@{@"ads-youtube":@"yes"},@"youtube")&&!MYBAdsModuleEnabled(@{@"ads-youtube":@NO},@"youtube"),"only an explicit off turns a module off");
 REQUIRE(MYBAdsModuleEnabled(@{@"ads-youtube":@YES},@"youtube")&&!MYBAdsModuleEnabled(@{@"ads-reddit":@NO},@"reddit"),"switches are independent");
 REQUIRE(!MYBAdsVersionVerified(@"instagram",@"418.2.0"),"upstream-tested is not verified by us");
 REQUIRE(MYBAdsCatalogue().count==18,"eighteen modules in the catalogue");
 for(NSDictionary *e in MYBAdsCatalogue()){REQUIRE(![e[@"ours"] length],"nothing is claimed verified yet");REQUIRE([e[@"bundles"] count]>0,"every module has a bundle filter");}

 // ---- helper: missing things change nothing; inherited methods are overridden on the subclass only
 REQUIRE(!MYBAdsHookNamed("NoSuchClassAnywhere","foo",NO,(IMP)0x1,NULL),"missing class is skipped");
 Class base=make("MYBTBase",nil);add(base,"value",^int(id s){return 1;},"i@:");
 Class sub=make("MYBTSub",base);
 static IMP origValue;static int(*fn)(id,SEL)=NULL;
 REQUIRE(!MYBAdsHook(sub,sel_registerName("nope"),NO,imp_implementationWithBlock(^int(id s){return 2;}),NULL),"missing selector is skipped");
 REQUIRE(MYBAdsHook(sub,sel_registerName("value"),NO,imp_implementationWithBlock(^int(id s){return 2;}),&origValue),"inherited method hooks");
 fn=(int(*)(id,SEL))origValue;
 REQUIRE(((int(*)(id,SEL))objc_msgSend)([base new],sel_registerName("value"))==1,"superclass untouched");
 REQUIRE(((int(*)(id,SEL))objc_msgSend)([sub new],sel_registerName("value"))==2&&fn([sub new],sel_registerName("value"))==1,"subclass changed and original reachable");

 // ---- filter: untouched array returned as is (same object) when nothing is an ad
 NSArray *plain=@[@1,@2,@3];REQUIRE(MYBAdsFilter(plain,^BOOL(id i){return NO;})==plain,"no ads: same array, no copy");
 NSArray *mixed=@[@1,@"ad",@2,@"ad",@3];NSArray *clean=MYBAdsFilter(mixed,^BOOL(id i){return [i isEqual:@"ad"];});
 REQUIRE([clean isEqualToArray:(@[@1,@2,@3])],"ads removed, order kept");
 REQUIRE([MYBAdsFilter(@[@"ad"],^BOOL(id i){return YES;}) isEqualToArray:@[]],"all ads gives an empty list");

 // ---- Instagram: every hook is skipped while the classes are absent, nothing crashes
 NSUInteger attempted=0;REQUIRE(MYBInstagramInstallHooks(&attempted)==0&&attempted==12,"Instagram: no classes, no hooks");
 Class feedItem=make("IGFeedItem",nil),adItem=make("IGAdItem",nil),grid=make("IGDiscoveryGridItem",nil);
 add(feedItem,"isSponsored",^BOOL(id s){return [objc_getAssociatedObject(s,"sp") boolValue];},"B@:");
 add(feedItem,"isSponsoredApp",^BOOL(id s){return NO;},"B@:");
 add(grid,"model",^id(id s){return objc_getAssociatedObject(s,"model");},"@@:");
 id organic=[feedItem new],sponsored=[feedItem new],ad=[adItem new],gridAd=[grid new],gridOk=[grid new];
 objc_setAssociatedObject(sponsored,"sp",@YES,OBJC_ASSOCIATION_RETAIN);objc_setAssociatedObject(gridAd,"model",ad,OBJC_ASSOCIATION_RETAIN);objc_setAssociatedObject(gridOk,"model",organic,OBJC_ASSOCIATION_RETAIN);
 Class mainDS=make("IGMainFeedListAdapterDataSource",nil);
 add(mainDS,"objectsForListAdapter:",^NSArray *(id s,id a){return @[organic,sponsored,ad,gridAd,gridOk,@"story-tray"];},"@@:@");
 Class storyPool=make("IGStoryAdPool",nil);add(storyPool,"initWithUserSession:",^id(id s,id u){return s;},"@@:@");
 Class parser=make("IGSundialAdsResponseParser",nil);add(parser,"parsedObjectFromResponse:",^id(id s,id r){return @"ads";},"@@:@");
 attempted=0;NSUInteger ok=MYBInstagramInstallHooks(&attempted);REQUIRE(ok==3&&attempted==12,"Instagram: only the classes present are hooked");
 NSArray *feed=((NSArray *(*)(id,SEL,id))objc_msgSend)([mainDS new],sel_registerName("objectsForListAdapter:"),nil);
 REQUIRE([feed isEqualToArray:(@[organic,gridOk,@"story-tray"])],"Instagram: sponsored, ad and ad-grid items removed; organic and other items kept in order");
 REQUIRE(((id(*)(id,SEL,id))objc_msgSend)([storyPool alloc],sel_registerName("initWithUserSession:"),nil)==nil,"Instagram: story ad pool is not created");
 REQUIRE(((id(*)(id,SEL,id))objc_msgSend)([parser new],sel_registerName("parsedObjectFromResponse:"),nil)==nil,"Instagram: ads response parses to nothing");
 {
  // The Reel comment shopping carousel is ordinary shopping UI: its initialiser carries no advertising signal (only a frame, text and a style),
  // so it is NOT hooked. It is created normally and counted as nothing.
  Class pill=make("_TtC35IGCommentThreadCommerceCarouselPill31IGCommentThreadCommerceCarousel",nil);__block BOOL originalRan=NO;
  add(pill,"initWithFrame:pillText:pillStyle:",^id(id s,CGRect f,id t,NSInteger st){originalRan=YES;return s;},"@@:{CGRect={CGPoint=dd}{CGSize=dd}}@q");
  attempted=0;NSUInteger again=MYBInstagramInstallHooks(&attempted);
  id made=((id(*)(id,SEL,CGRect,id,NSInteger))objc_msgSend)([pill alloc],sel_registerName("initWithFrame:pillText:pillStyle:"),(CGRect){{0,0},{0,0}},@"Shop",0);
  REQUIRE(again==0&&attempted==12&&made!=nil&&originalRan,"Instagram: an ordinary shopping component is created by the app, not hooked, not removed");
 }
 REQUIRE(!MYBInstagramItemIsAd(nil)&&!MYBInstagramItemIsAd(@"text"),"Instagram: unknown objects are never ads");
 // Ordinary Stories, Reels and LIVE items, and pagination, are untouched.
 Class tray=make("IGStoryTrayViewModel",nil),reelItem=make("IGReelItemModel",nil),liveItem=make("IGLiveBroadcastModel",nil);
 id t=[tray new],r=[reelItem new],l=[liveItem new];
 REQUIRE(!MYBInstagramItemIsAd(t)&&!MYBInstagramItemIsAd(r)&&!MYBInstagramItemIsAd(l),"Instagram: Story tray, Reel and LIVE items are not ads");
 NSMutableArray *page=[NSMutableArray array],*expect=[NSMutableArray array];
 for(int i=0;i<50;i++){id o=(i%5==0)?[adItem new]:[feedItem new];[page addObject:o];if(i%5)[expect addObject:o];}
 Class pager=make("IGContextualFeedViewController",nil);add(pager,"objectsForListAdapter:",^NSArray *(id s,id a){return page;},"@@:@");
 MYBInstagramInstallHooks(&attempted);
 NSArray *p1=((NSArray *(*)(id,SEL,id))objc_msgSend)([pager new],sel_registerName("objectsForListAdapter:"),nil);
 REQUIRE([p1 isEqualToArray:expect]&&p1.count==40,"Instagram: a 50-item page loses exactly its 10 ads and keeps order");
 NSArray *p2=((NSArray *(*)(id,SEL,id))objc_msgSend)([pager new],sel_registerName("objectsForListAdapter:"),nil);
 REQUIRE([p2 isEqualToArray:expect],"Instagram: the next page is filtered on its own, with no state carried over");
 NSArray *same=@[t,r,l];Class tray2=make("IGSundialFeedDataSource",nil);add(tray2,"objectsForListAdapter:",^NSArray *(id s,id a){return same;},"@@:@");
 MYBInstagramInstallHooks(&attempted);
 REQUIRE(((NSArray *(*)(id,SEL,id))objc_msgSend)([tray2 new],sel_registerName("objectsForListAdapter:"),nil)==same,"Instagram: a list with no ads is returned untouched");

 // ---- YouTube
 attempted=0;REQUIRE(MYBYouTubeInstallHooks(&attempted)==0&&attempted==16,"YouTube: no classes, no hooks, no crash");
 Class resp=make("YTIPlayerResponse",nil);Class coll=make("YTInnerTubeCollectionViewController",nil);Class reelDS=make("YTReelDataSource",nil);Class slot=make("YTAdElementsCellExternallyManagedSlotAdapterImpl",nil);
 Class element=make("MYBTElement",nil);add(element,"description",^NSString *(id s){return objc_getAssociatedObject(s,"d")?:@"video_with_context";},"@@:");
 Class section=make("MYBTSection",nil);add(section,"contentsArray",^NSArray *(id s){return objc_getAssociatedObject(s,"c");},"@@:");
 Class wrapper=make("MYBTWrapper",nil);add(wrapper,"elementRenderer",^id(id s){return objc_getAssociatedObject(s,"e");},"@@:");
 id (^mk)(NSString *)=^id(NSString *desc){id e=[element new];objc_setAssociatedObject(e,"d",desc,OBJC_ASSOCIATION_RETAIN);id w=[wrapper new];objc_setAssociatedObject(w,"e",e,OBJC_ASSOCIATION_RETAIN);id sec=[section new];objc_setAssociatedObject(sec,"c",@[w],OBJC_ASSOCIATION_RETAIN);return sec;};
 id normal=mk(@"video_with_context"),shopping=mk(@"product_carousel shopping_carousel"),adSec=mk(@"x feed_ad_metadata y"),brand=mk(@"brand_promo");
 __block NSArray *received=nil;add(coll,"addSectionsFromArray:",^(id s,NSArray *a){received=a;},"v@:@");
 add(reelDS,"makeContentModelForEntry:",^id(id s,id e){return e;},"@@:@");
 add(slot,"isValidSlotType:",^BOOL(id s,int t){return YES;},"B@:i");
 Class reel=make("MYBTReel",nil);add(reel,"videoType",^int(id s){return [objc_getAssociatedObject(s,"t") intValue];},"i@:");
Class secVM=make("YTArraySectionViewModel",nil);__block NSArray *vmInit=nil,*vmInsert=nil;__block id vmReplaced=nil;__block NSUInteger vmIndex=99;__block int vmInsertCalls=0;
 add(secVM,"initWithEntries:",^id(id s,NSArray *e){vmInit=e;return s;},"@@:@");
 add(secVM,"initWithTransform:entries:",^id(id s,id t,NSArray *e){vmInit=e;return s;},"@@:@@");
 add(secVM,"insertEntries:atIndex:",^(id s,NSArray *e,NSUInteger i){vmInsert=e;vmIndex=i;vmInsertCalls++;},"v@:@Q");
 add(secVM,"replaceEntry:withEntry:",^(id s,id o,id n){vmReplaced=n;},"v@:@@");
 id (^entry)(NSString *)=^id(NSString *desc){id e=[element new];objc_setAssociatedObject(e,"d",desc,OBJC_ASSOCIATION_RETAIN);id w=[wrapper new];objc_setAssociatedObject(w,"e",e,OBJC_ASSOCIATION_RETAIN);return w;};
 Class decorator=make("YTAdsInnerTubeContextDecorator",nil);__block int decorated=0;add(decorator,"decorateContext:",^(id s,id c){decorated++;},"v@:@");
 attempted=0;ok=MYBYouTubeInstallHooks(&attempted);
 REQUIRE(attempted==16&&ok==10,"YouTube: ten hooks on the classes present (two getters added, eight methods hooked, ad-request decorator and section view model included)");
 {
  id eOk=entry(@"video_with_context"),eAd=entry(@"x feed_ad_metadata y"),eShop=entry(@"product_carousel shopping_carousel");
  ((id(*)(id,SEL,id))objc_msgSend)([secVM alloc],sel_registerName("initWithEntries:"),@[eOk,eAd,eShop]);
  REQUIRE([vmInit isEqualToArray:(@[eOk,eShop])],"YouTube: a section seeded with entries loses its ad entry, keeping ordinary and shopping entries in order");
  ((id(*)(id,SEL,id,id))objc_msgSend)([secVM alloc],sel_registerName("initWithTransform:entries:"),@"t",@[eAd,eOk]);
  REQUIRE([vmInit isEqualToArray:(@[eOk])],"YouTube: the transform initialiser is filtered the same way");
  NSArray *clean=@[eOk,eShop];((void(*)(id,SEL,id,NSUInteger))objc_msgSend)([secVM new],sel_registerName("insertEntries:atIndex:"),clean,2);
  REQUIRE(vmInsert==clean&&vmIndex==2&&vmInsertCalls==1,"YouTube: an insert with no ads reaches the app untouched, with its index");
  ((void(*)(id,SEL,id,NSUInteger))objc_msgSend)([secVM new],sel_registerName("insertEntries:atIndex:"),@[eAd,eOk],0);
  REQUIRE([vmInsert isEqualToArray:(@[eOk])]&&vmInsertCalls==2,"YouTube: an insert is reduced to its non-ad entries");
  ((void(*)(id,SEL,id,NSUInteger))objc_msgSend)([secVM new],sel_registerName("insertEntries:atIndex:"),@[eAd],0);
  REQUIRE(vmInsertCalls==2,"YouTube: an insert made only of ads is not performed");
  ((void(*)(id,SEL,id,id))objc_msgSend)([secVM new],sel_registerName("replaceEntry:withEntry:"),eOk,eAd);
  REQUIRE(vmReplaced==nil,"YouTube: replacing an entry with an ad is refused");
  ((void(*)(id,SEL,id,id))objc_msgSend)([secVM new],sel_registerName("replaceEntry:withEntry:"),eAd,eOk);
  REQUIRE(vmReplaced==eOk,"YouTube: replacing an entry with an ordinary one goes through");
 }
 ((void(*)(id,SEL,id))objc_msgSend)([coll new],sel_registerName("addSectionsFromArray:"),@[normal,adSec,shopping,brand]);
 REQUIRE([received isEqualToArray:(@[normal,shopping])],"YouTube: ad sections removed; ordinary and shopping sections kept");
 REQUIRE(!((BOOL(*)(id,SEL,int))objc_msgSend)([slot new],sel_registerName("isValidSlotType:"),1),"YouTube: ad slots are refused");
 id adReel=[reel new],okReel=[reel new];objc_setAssociatedObject(adReel,"t",@3,OBJC_ASSOCIATION_RETAIN);objc_setAssociatedObject(okReel,"t",@1,OBJC_ASSOCIATION_RETAIN);
 REQUIRE(((id(*)(id,SEL,id))objc_msgSend)([reelDS new],sel_registerName("makeContentModelForEntry:"),adReel)==nil,"YouTube: ad Short is dropped");
 REQUIRE(((id(*)(id,SEL,id))objc_msgSend)([reelDS new],sel_registerName("makeContentModelForEntry:"),okReel)==okReel,"YouTube: ordinary Short is returned unchanged");
 id arr=((id(*)(id,SEL))objc_msgSend)([resp new],sel_registerName("playerAdsArray"));REQUIRE([arr isKindOfClass:NSArray.class]&&[arr count]==0,"YouTube: player ads list is empty");
 REQUIRE(!MYBYouTubeRendererIsAd(nil)&&!MYBYouTubeRendererIsAd(@"video_with_context"),"YouTube: ordinary renderers are not ads");
 // The ad-request context is handled by this module alone, with no dependence on any other tweak.
 ((void(*)(id,SEL,id))objc_msgSend)([decorator new],sel_registerName("decorateContext:"),nil);
 REQUIRE(decorated==0,"YouTube: the ad-request decorator is silenced by the module itself");
 NSUInteger again=0;REQUIRE(MYBYouTubeInstallHooks(&again)==0&&again==16,"YouTube: a second install pass adds nothing and wraps nothing twice");
 NSString *src=[NSString stringWithContentsOfFile:@"Companions/InAppAds/YouTube/Module.m" encoding:NSUTF8StringEncoding error:NULL];
 REQUIRE([src rangeOfString:@"{\"YTIPlayabilityStatus\""].location==NSNotFound&&[src rangeOfString:@"isPlayableInBackground"].location==NSNotFound,"YouTube: never hooks playability or background playback");
 REQUIRE([src rangeOfString:@"YouTopia"].location==NSNotFound&&[src rangeOfString:@"OwnedByAnotherTweak"].location==NSNotFound,"YouTube: no ownership or deference logic remains");
 // Ordinary Shorts, LIVE and shopping content, and list order, survive (pagination: every page is filtered on its own).
 id live=mk(@"live_chat_renderer video_with_context"),shorts=mk(@"reel_shelf shorts_lockup"),adMid=mk(@"x feed_ad_metadata");
 ((void(*)(id,SEL,id))objc_msgSend)([coll new],sel_registerName("addSectionsFromArray:"),@[live,adMid,shorts,adMid,normal]);
 REQUIRE([received isEqualToArray:(@[live,shorts,normal])],"YouTube: LIVE and Shorts shelves are kept, only ad sections go");
 ((void(*)(id,SEL,id))objc_msgSend)([coll new],sel_registerName("addSectionsFromArray:"),@[]);REQUIRE(received.count==0,"YouTube: an empty page stays empty");
 NSMutableOrderedSet *set=[NSMutableOrderedSet orderedSetWithArray:@[okReel,adReel]];
 Class infinite=make("YTReelInfinitePlaybackDataSource",nil);__block NSOrderedSet *seen=nil;add(infinite,"setReels:",^(id s,NSMutableOrderedSet *r){seen=[r copy];},"v@:@");
 add(infinite,"makeContentModelForEntry:",^id(id s,id e){return e;},"@@:@");
 MYBYouTubeInstallHooks(&attempted);
 ((void(*)(id,SEL,id))objc_msgSend)([infinite new],sel_registerName("setReels:"),set);
 REQUIRE(seen.count==1&&seen[0]==okReel,"YouTube: only the ad Short leaves the reel set; ordinary Shorts stay");
 // ---- SoundCloud
 attempted=0;REQUIRE(MYBSoundCloudInstallHooks(&attempted)==1&&attempted==3,"SoundCloud: only the Foundation session hook installs while the app classes are absent");
 Class permit=make("_TtC10SoundCloud19AdsRequestPermitter",nil);add(permit,"shouldRequestAds",^BOOL(id s){return YES;},"B@:");
 Class banner=make("_TtC3Ads30DisplayAdBannerFeatureProvider",nil);add(banner,"canRequestAdBanner",^BOOL(id s){return YES;},"B@:");
 REQUIRE(MYBSoundCloudInstallHooks(&attempted)==2&&attempted==3,"SoundCloud: both checks hooked (the session hook was already in place)");
 {
  NSURLRequest *(^R)(NSString *)=^NSURLRequest *(NSString *u){return [NSURLRequest requestWithURL:[NSURL URLWithString:u]];};
  REQUIRE(MYBSoundCloudRequestIsAd(R(@"https://soundcloud.com/ads/queue_start"))&&MYBSoundCloudRequestIsAd(R(@"https://api-v2.soundcloud.com/ads/queue_start"))&&MYBSoundCloudRequestIsAd(R(@"https://api-v2.soundcloud.com/ads"))&&MYBSoundCloudRequestIsAd(R(@"https://promoted.soundcloud.com/x")),"SoundCloud: ad requests are recognised");
  REQUIRE(!MYBSoundCloudRequestIsAd(R(@"https://api-v2.soundcloud.com/tracks/1"))&&!MYBSoundCloudRequestIsAd(R(@"https://api-v2.soundcloud.com/adsense"))&&!MYBSoundCloudRequestIsAd(R(@"https://api-v2.soundcloud.com/me/ads-history"))&&!MYBSoundCloudRequestIsAd(R(@"https://notsoundcloud.com/ads/x"))&&!MYBSoundCloudRequestIsAd(R(@"https://soundcloud.com.evil.example/ads/x"))&&!MYBSoundCloudRequestIsAd(R(@"https://example.com/ads/queue_start"))&&!MYBSoundCloudRequestIsAd(nil),"SoundCloud: the app's own API, look-alike paths and look-alike hosts are not touched");
  NSURLSessionConfiguration *cfg=[NSURLSessionConfiguration defaultSessionConfiguration];
  REQUIRE([cfg.protocolClasses isKindOfClass:NSArray.class]&&[cfg.protocolClasses.firstObject isEqual:NSClassFromString(@"MYBSoundCloudAdProtocol")]&&[[cfg.protocolClasses filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id c,NSDictionary *b){return [c isEqual:NSClassFromString(@"MYBSoundCloudAdProtocol")];}]] count]==1,"SoundCloud: every session configuration lists the ad protocol exactly once");
  // A real request through a real session: the ad path fails with a connection error, an ordinary path is not claimed.
  NSURLSession *session=[NSURLSession sessionWithConfiguration:cfg];__block NSError *adError=nil;__block BOOL done=NO;
  [[session dataTaskWithURL:[NSURL URLWithString:@"https://soundcloud.com/ads/queue_start"] completionHandler:^(NSData *d,NSURLResponse *r,NSError *e){adError=e;done=YES;}] resume];
  NSDate *until=[NSDate dateWithTimeIntervalSinceNow:5];while(!done&&[until timeIntervalSinceNow]>0)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
  REQUIRE(done&&adError.code==NSURLErrorCannotConnectToHost&&[adError.domain isEqual:NSURLErrorDomain],"SoundCloud: an ad request through a session fails with a connection error, not a fake success");
 }
 REQUIRE(!((BOOL(*)(id,SEL))objc_msgSend)([permit new],sel_registerName("shouldRequestAds"))&&!((BOOL(*)(id,SEL))objc_msgSend)([banner new],sel_registerName("canRequestAdBanner")),"SoundCloud: ad requests are refused");

 // ---- Reddit: response filtering
 NSDictionary *feedJSON=@{@"data":@{@"home":@{@"elements":@{@"edges":@[@{@"node":@{@"__typename":@"SubredditPost",@"id":@"t3_a"}},@{@"node":@{@"__typename":@"AdPost",@"id":@"t3_ad"}},@{@"node":@{@"__typename":@"CellGroup",@"adPayload":@{@"x":@1},@"cells":@[]}},@{@"node":@{@"__typename":@"CellGroup",@"id":@"t3_b"}}]}}}};
 NSData *in=[NSJSONSerialization dataWithJSONObject:feedJSON options:0 error:NULL];NSData *out=MYBRedditFilterResponse(in);
 NSDictionary *parsed=[NSJSONSerialization JSONObjectWithData:out options:0 error:NULL];NSArray *edges=parsed[@"data"][@"home"][@"elements"][@"edges"];
 REQUIRE(edges.count==2&&[edges[0][@"node"][@"id"] isEqual:@"t3_a"]&&[edges[1][@"node"][@"id"] isEqual:@"t3_b"],"Reddit: promoted entries removed, organic posts kept in order");
 NSData *noAds=[NSJSONSerialization dataWithJSONObject:@{@"data":@{@"home":@{@"elements":@{@"edges":@[@{@"node":@{@"__typename":@"SubredditPost"}}]}}}} options:0 error:NULL];
 REQUIRE(MYBRedditFilterResponse(noAds)==noAds,"Reddit: a response with no ad marker is passed through as the same bytes");
 NSData *marked=[NSJSONSerialization dataWithJSONObject:@{@"data":@{@"x":@{@"note":@"mentions AdPost in text"}}} options:0 error:NULL];
 REQUIRE(MYBRedditFilterResponse(marked)==marked,"Reddit: a marker with no ad structure leaves the response untouched");
 NSData *comments=[NSJSONSerialization dataWithJSONObject:@{@"data":@{@"post":@{@"commentsPageAds":@[@{@"id":@"a"}],@"commentTreeAds":@[],@"title":@"t"}}} options:0 error:NULL];
 NSDictionary *cp=[NSJSONSerialization JSONObjectWithData:MYBRedditFilterResponse(comments) options:0 error:NULL];
 REQUIRE([cp[@"data"][@"post"][@"commentsPageAds"] count]==0&&[cp[@"data"][@"post"][@"title"] isEqual:@"t"],"Reddit: comment-page ads emptied, content kept");
 NSData *garbage=[@"not json but AdPost marker here........" dataUsingEncoding:NSUTF8StringEncoding];
 REQUIRE(MYBRedditFilterResponse(garbage)==garbage,"Reddit: unparseable data is passed through");
 NSData *tiny=[NSData dataWithBytes:"AdPost" length:6];REQUIRE(MYBRedditFilterResponse(tiny)==tiny,"Reddit: tiny bodies are passed through");
 // comment-page ads wrapped in an object (newer responses): the ads go, the wrapper and its paging fields stay
 {
  NSDictionary *wrapped=@{@"data":@{@"post":@{@"title":@"t",@"pdpCommentsAds":@{@"adPosts":@[@{@"id":@"t3_ad"}],@"pageInfo":@{@"hasNextPage":@NO}}}}};
  NSData *wi=[NSJSONSerialization dataWithJSONObject:wrapped options:0 error:NULL];
  NSDictionary *wo=[NSJSONSerialization JSONObjectWithData:MYBRedditFilterResponse(wi) options:0 error:NULL];
  REQUIRE([wo[@"data"][@"post"][@"pdpCommentsAds"][@"adPosts"] count]==0&&[wo[@"data"][@"post"][@"pdpCommentsAds"][@"pageInfo"][@"hasNextPage"] isEqual:@NO]&&[wo[@"data"][@"post"][@"title"] isEqual:@"t"],"Reddit: wrapped comment-page ads are emptied, the wrapper, paging and content kept");
  NSData *emptyWrapped=[NSJSONSerialization dataWithJSONObject:@{@"data":@{@"post":@{@"pdpCommentsAds":@{@"adPosts":@[],@"pageInfo":@{}}}}} options:0 error:NULL];
  REQUIRE(MYBRedditFilterResponse(emptyWrapped)==emptyWrapped,"Reddit: an already empty ad wrapper is passed through as the same bytes");
 }
 attempted=0;REQUIRE(MYBRedditInstallHooks(&attempted)==1,"Reddit: session hook installs");

 // ---- reporting: client labels and counts only, server validation, loaded is not effective
 [NSThread sleepForTimeInterval:0.4];NSArray *paths;@synchronized(sent){paths=[sent copy];}
 BOOL sawFeed=NO,leak=NO;for(NSString *x in paths){if([x containsString:@"phase=decisions"]&&[x containsString:@"cat=feed"])sawFeed=YES;if([x containsString:@"http"]||[x containsString:@"://"])leak=YES;}
 REQUIRE(sawFeed,"Reporting: filtered feed ads are reported as a category and a count");REQUIRE(!leak,"Reporting: no URL appears in any report");
 NSDictionary *bundles=@{@"instagram":@[@"com.burbn.instagram"],@"youtube":@[@"com.google.ios.youtube"],@"reddit":@[@"com.reddit.Reddit"],@"tiktok":@[@"com.zhiliaoapp.musically"],@"soundcloud":@[@"com.soundcloud.TouchApp"]};
 NSDictionary *none=MYBAdsSnapshot();REQUIRE([none[@"instagram"][@"state"] isEqual:@"not-observed"],"Reporting: nothing reported means not-observed, not failed");
 NSDictionary *hooksFirst=@{@"module":@"instagram",@"app":@"com.burbn.instagram",@"phase":@"hooks",@"found":@"3",@"attempted":@"12",@"owned":@"0"};
 REQUIRE(!MYBAdsRecordEvent(hooksFirst,bundles,100),"Reporting: hooks before a load report are refused");
 NSDictionary *load=@{@"module":@"instagram",@"app":@"com.burbn.instagram",@"phase":@"loaded",@"av":@"418.2.0",@"arch":@"arm64",@"ver":@"6.11192026-15-RH"};
 REQUIRE(MYBAdsRecordEvent(load,bundles,100),"Reporting: a valid load report is recorded");
 REQUIRE([MYBAdsSnapshot()[@"instagram"][@"state"] isEqual:@"loaded"],"Reporting: loaded, with no hook information, is only 'loaded'");
 NSMutableDictionary *wrongApp=[load mutableCopy];wrongApp[@"app"]=@"com.example.other";REQUIRE(!MYBAdsRecordEvent(wrongApp,bundles,100),"Reporting: a module can only report from its own app");
 NSMutableDictionary *badArch=[load mutableCopy];badArch[@"arch"]=@"x86";REQUIRE(!MYBAdsRecordEvent(badArch,bundles,100),"Reporting: an unknown architecture is refused");
 NSMutableDictionary *badModule=[load mutableCopy];badModule[@"module"]=@"spotify";REQUIRE(!MYBAdsRecordEvent(badModule,bundles,100),"Reporting: an unknown module is refused");
 REQUIRE(MYBAdsRecordEvent(hooksFirst,bundles,101),"Reporting: hooks recorded after load");
 REQUIRE([MYBAdsSnapshot()[@"instagram"][@"state"] isEqual:@"hooks-found"],"Reporting: hooks found but no ad seen is 'hooks-found', not effective");
 NSMutableDictionary *tooMany=[hooksFirst mutableCopy];tooMany[@"found"]=@"13";REQUIRE(!MYBAdsRecordEvent(tooMany,bundles,102),"Reporting: found cannot exceed attempted");
 NSDictionary *dec=@{@"module":@"instagram",@"app":@"com.burbn.instagram",@"phase":@"decisions",@"cat":@"feed:3,story:1"};
 REQUIRE(MYBAdsRecordEvent(dec,bundles,103)&&MYBAdsRecordEvent(dec,bundles,104),"Reporting: decisions accumulate");
 NSDictionary *rec=MYBAdsSnapshot()[@"instagram"];REQUIRE([rec[@"state"] isEqual:@"filtering"]&&[rec[@"decisions"] intValue]==8&&[rec[@"categories"][@"feed"] intValue]==6,"Reporting: filtering state with exact counts");
 NSMutableDictionary *badCat=[dec mutableCopy];badCat[@"cat"]=@"https://x.example:1";REQUIRE(!MYBAdsRecordEvent(badCat,bundles,105),"Reporting: a URL-shaped value is refused");
 NSMutableDictionary *unknownCat=[dec mutableCopy];unknownCat[@"cat"]=@"messages:2";REQUIRE(!MYBAdsRecordEvent(unknownCat,bundles,105),"Reporting: only fixed categories are accepted");
 NSMutableDictionary *hugeCount=[dec mutableCopy];hugeCount[@"cat"]=@"feed:99999999";REQUIRE(!MYBAdsRecordEvent(hugeCount,bundles,105),"Reporting: absurd counts are refused");
 REQUIRE(MYBAdsRecordEvent(load,bundles,200),"Reporting: a new launch reports again");
 REQUIRE([MYBAdsSnapshot()[@"instagram"][@"decisions"] intValue]==0&&[MYBAdsSnapshot()[@"instagram"][@"state"] isEqual:@"loaded"],"Reporting: counts belong to one launch of the app");
 NSData *json=[NSJSONSerialization dataWithJSONObject:MYBAdsSnapshot() options:0 error:NULL];NSString *text=[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
 REQUIRE(json!=nil&&![text containsString:@"http"],"Reporting: the status record is valid JSON and contains no URL");
 if(failures){fprintf(stderr,"%d failure(s)\n",failures);return 1;}
 printf("In-App Ad Blocking checks passed.\n");return 0;}}
