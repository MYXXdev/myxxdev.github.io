// Behaviour tests for the YouTube Music, X and Messenger In-App Ad Blocking modules, run on real Objective-C classes built at run time
// (the apps themselves are not available to CI). A separate program from inappads-native.m because the YouTube module's test already
// registers some of the InnerTube class names this one needs.
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../Shared/MYBAdsReport.h"
#include "../Companions/InAppAds/YouTubeMusic/Module.m"
#include "../Companions/InAppAds/X/Module.m"
#include "../Companions/InAppAds/Messenger/Module.m"
static int failures=0;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)
static Class make(const char *name,Class sup){Class c=objc_allocateClassPair(sup?:NSObject.class,name,0);objc_registerClassPair(c);return c;}
static void add(Class c,const char *sel,id block,const char *types){class_addMethod(c,sel_registerName(sel),imp_implementationWithBlock(block),types);}
int main(void){@autoreleasepool{
 MYBAdsReportSink=^(NSString *path){(void)path;};
 // ---- YouTube Music: ad lists and ad requests only
 {
  Class resp=make("YTIPlayerResponse",nil);
  add(resp,"playerAdsArray",^id(id s){return [NSMutableArray arrayWithObjects:@"ad1",@"ad2",nil];},"@@:");
    add(resp,"adIntroRenderer",^id(id s){return @"intro";},"@@:");
  add(resp,"isMonetized",^BOOL(id s){return YES;},"B@:");
  add(resp,"playabilityStatus",^id(id s){return @"playable";},"@@:"); // must stay untouched
  add(resp,"streamingData",^id(id s){return @"streams";},"@@:");add(resp,"videoDetails",^id(id s){return @"details";},"@@:");
  add(resp,"isPlayable",^BOOL(id s){return YES;},"B@:");
  __block int decorated=0;Class dec=make("YTAdsInnerTubeContextDecorator",nil);add(dec,"decorateContext:",^(id s,id c){decorated++;},"v@:@");
  NSUInteger attempted=0,ok=MYBYouTubeMusicInstallHooks(&attempted);
  REQUIRE(attempted==4&&ok==4,"YouTube Music: the hooks present are installed, absent classes are skipped without error");
  id r=[resp new];
  REQUIRE([((id(*)(id,SEL))objc_msgSend)(r,sel_registerName("playerAdsArray")) count]==0,"YouTube Music: the player ad list comes back empty");
  REQUIRE(!((BOOL(*)(id,SEL))objc_msgSend)(r,sel_registerName("isMonetized")),"YouTube Music: a monetised response is reported as not monetised");
  REQUIRE(((id(*)(id,SEL))objc_msgSend)(r,sel_registerName("adIntroRenderer"))==nil,"YouTube Music: the ad lead-in is removed");
  REQUIRE([((id(*)(id,SEL))objc_msgSend)(r,sel_registerName("playabilityStatus")) isEqual:@"playable"],"YouTube Music: playback state is untouched");
  REQUIRE([((id(*)(id,SEL))objc_msgSend)(r,sel_registerName("streamingData")) isEqual:@"streams"]&&[((id(*)(id,SEL))objc_msgSend)(r,sel_registerName("videoDetails")) isEqual:@"details"]&&((BOOL(*)(id,SEL))objc_msgSend)(r,sel_registerName("isPlayable")),"YouTube Music: streams, video details and playability are untouched by the monetised change");
  ((void(*)(id,SEL,id))objc_msgSend)([dec new],sel_registerName("decorateContext:"),@"ctx");REQUIRE(decorated==0,"YouTube Music: the app is told not to request ads");
  REQUIRE(MYBYouTubeMusicInstallHooks(&attempted)==0,"YouTube Music: installing twice does not wrap a second time");
 }
 // ---- X: only items marked promoted
 {
  Class promoted=make("MYBTestXPost",nil);add(promoted,"isPromoted",^BOOL(id s){return YES;},"B@:");
  Class plain=make("MYBTestXPlain",nil);add(plain,"isPromoted",^BOOL(id s){return NO;},"B@:");
  Class trend=make("MYBTestXTrend",nil);add(trend,"scribeItem",^id(id s){return @{@"promoted_id":@"1"};},"@@:");
  Class otherTrend=make("MYBTestXTrend2",nil);add(otherTrend,"scribeItem",^id(id s){return @{@"trend_id":@"1"};},"@@:");
  Class cellC=make("MYBTestCell",nil);add(cellC,"setHidden:",^(id s,BOOL v){objc_setAssociatedObject(s,"h",@(v),OBJC_ASSOCIATION_RETAIN);},"v@:c");
  Class list=make("TFNItemsDataViewController",nil);
  add(list,"tableViewCellForItem:atIndexPath:",^id(id s,id item,id path){return [cellC new];},"@@:@@");
  add(list,"tableView:heightForRowAtIndexPath:",^double(id s,id t,id path){return 44.0;},"d@:@@");
  add(list,"itemAtIndexPath:",^id(id s,id path){return [path isEqual:@"p"]?[promoted new]:[path isEqual:@"t"]?[trend new]:[plain new];},"@@:@");
  Class status=make("TFNTwitterStatus",nil);add(status,"isPromoted",^BOOL(id s){return [objc_getAssociatedObject(s,"p") boolValue];},"B@:");add(status,"isCardHidden",^BOOL(id s){return [objc_getAssociatedObject(s,"c") boolValue];},"B@:");
  Class account=make("TFNTwitterAccount",nil);add(account,"isVideoDynamicAdEnabled",^BOOL(id s){return YES;},"B@:");
  NSUInteger attempted=0,ok=MYBXInstallHooks(&attempted);REQUIRE(attempted==4&&ok==4,"X: all four hooks install when the classes have their methods");
  {
   id promotedStatus=[status new],ordinaryStatus=[status new],alreadyHidden=[status new];objc_setAssociatedObject(promotedStatus,"p",@YES,OBJC_ASSOCIATION_RETAIN);objc_setAssociatedObject(alreadyHidden,"c",@YES,OBJC_ASSOCIATION_RETAIN);
   BOOL (*flag)(id,SEL)=(BOOL(*)(id,SEL))objc_msgSend;SEL ch=sel_registerName("isCardHidden");
   REQUIRE(flag(promotedStatus,ch),"X: a promoted post's card is hidden");
   REQUIRE(!flag(ordinaryStatus,ch),"X: an ordinary post's card keeps the app's answer (shown)");
   REQUIRE(flag(alreadyHidden,ch),"X: a card the app already hides stays hidden");
   REQUIRE(!flag([account new],sel_registerName("isVideoDynamicAdEnabled")),"X: dynamic video ads are reported disabled");
  }
  id c=[list new];
  id (*cellFor)(id,SEL,id,id)=(id(*)(id,SEL,id,id))objc_msgSend;double (*height)(id,SEL,id,id)=(double(*)(id,SEL,id,id))objc_msgSend;
  id hiddenCell=cellFor(c,sel_registerName("tableViewCellForItem:atIndexPath:"),[promoted new],@"p");
  REQUIRE([objc_getAssociatedObject(hiddenCell,"h") boolValue],"X: a promoted post's row is hidden");
  id keptCell=cellFor(c,sel_registerName("tableViewCellForItem:atIndexPath:"),[plain new],@"x");
  REQUIRE(objc_getAssociatedObject(keptCell,"h")==nil,"X: an ordinary post's row is untouched");
  REQUIRE(objc_getAssociatedObject(cellFor(c,sel_registerName("tableViewCellForItem:atIndexPath:"),[trend new],@"t"),"h")!=nil,"X: a promoted trend is hidden");
  REQUIRE(objc_getAssociatedObject(cellFor(c,sel_registerName("tableViewCellForItem:atIndexPath:"),[otherTrend new],@"x"),"h")==nil,"X: an ordinary trend is untouched");
  SEL hs=sel_registerName("tableView:heightForRowAtIndexPath:");
  REQUIRE(height(c,hs,nil,@"p")==0&&height(c,hs,nil,@"t")==0,"X: a promoted row leaves no gap");
  REQUIRE(height(c,hs,nil,@"x")==44.0,"X: an ordinary row keeps its height");
 }
 // ---- X without the controller: nothing installs and nothing breaks
 REQUIRE(MYBAdsHookNamed("NoSuchXClass","tableViewCellForItem:atIndexPath:",NO,(IMP)hookCellForItem,NULL)==NO,"X: a missing class leaves the hook off");
 // ---- Messenger: only ad rows
 {
  Class row=make("MSGInboxRowUnit",nil);
  add(row,"inboxUnit",^id(id s){return objc_getAssociatedObject(s,"u");},"@@:");
  Class keyed=make("MYBTestKeyed",nil);add(keyed,"key",^id(id s){return objc_getAssociatedObject(s,"k");},"@@:");
  id (^mkRow)(NSString *)=^id(NSString *k){id u=[keyed new];objc_setAssociatedObject(u,"k",k,OBJC_ASSOCIATION_RETAIN);id r=[row new];objc_setAssociatedObject(r,"u",u,OBJC_ASSOCIATION_RETAIN);return r;};
  Class impostor=make("MYBTestImpostor",nil);add(impostor,"inboxUnit",^id(id s){return nil;},"@@:");
  id adRow=mkRow(@"ads_renderer"),chatRow=mkRow(@"thread_renderer"),storyRow=mkRow(@"montage_renderer"),pymkRow=mkRow(@"pymk");id other=[impostor new];
  Class ds=make("MSGThreadListDataSource",nil);NSArray *mixed=@[chatRow,adRow,storyRow,pymkRow,other];
  add(ds,"inboxRows",^id(id s){return mixed;},"@@:");
  NSUInteger attempted=0,ok=MYBMessengerInstallHooks(&attempted);
  REQUIRE(attempted==2&&ok==1,"Messenger: with only the chat list present one of two hooks installs");
  Class plugin=make("MSGInboxAdsUserScopedPlugin",nil);__block int fetched=0;add(plugin,"MSGInboxAdsUnitFetcher_MSGFetchInboxUnit:",^id(id s,id r){fetched++;return @"unit";},"@@:@");
  Class viewer=make("LSStoryViewerContentController",nil);__block NSArray *seenModels=nil,*seenAdded=nil;__block int viewerCalls=0;
  add(viewer,"_updateStoriesWithBucketStoryModels:deletedIndexPaths:addedIndexPaths:newIndexPath:",^(id s,NSMutableArray *m,id d,NSArray *a,id n){viewerCalls++;seenModels=[m copy];seenAdded=a;},"v@:@@@@");
  Class bucket=make("MYBTestBucket",nil);add(bucket,"bucketType",^long long(id s){return [objc_getAssociatedObject(s,"t") longLongValue];},"q@:");
  id (^mkBucket)(int)=^id(int t){id b=[bucket new];objc_setAssociatedObject(b,"t",@(t),OBJC_ASSOCIATION_RETAIN);return b;};
  id unread=mkBucket(0),adBucket=mkBucket(1),readBucket=mkBucket(2),unread2=mkBucket(0);
  ok=MYBMessengerInstallHooks(&attempted);REQUIRE(attempted==2&&ok==1,"Messenger: the story-viewer hook installs once the class exists");
  // the inbox ad-unit fetcher is deliberately not hooked: its callers' expectations of a nil answer are unverified
  REQUIRE([((id(*)(id,SEL,id))objc_msgSend)([plugin new],sel_registerName("MSGInboxAdsUnitFetcher_MSGFetchInboxUnit:"),@"req") isEqual:@"unit"]&&fetched==1,"Messenger: the inbox ad-unit fetcher is left untouched and still answers");
  SEL upd=sel_registerName("_updateStoriesWithBucketStoryModels:deletedIndexPaths:addedIndexPaths:newIndexPath:");
  NSIndexPath *(^P)(NSUInteger,NSUInteger)=^NSIndexPath *(NSUInteger sec,NSUInteger item){NSUInteger parts[2]={sec,item};return [NSIndexPath indexPathWithIndexes:parts length:2];};
  // [unread, ad, read, unread2]: paths 1 (the ad), 2 and 3 were added; after the ad is removed they are 1 and 2
  NSMutableArray *buckets=[NSMutableArray arrayWithObjects:unread,adBucket,readBucket,unread2,nil];
  ((void(*)(id,SEL,id,id,id,id))objc_msgSend)([viewer new],upd,buckets,nil,(@[P(0,1),P(0,2),P(0,3)]),nil);
  REQUIRE([seenModels isEqualToArray:(@[unread,readBucket,unread2])],"Messenger: only the advertisement story bucket is dropped; unread and read stories stay in order");
  REQUIRE(seenAdded.count==2&&[seenAdded[0] isEqual:P(0,1)]&&[seenAdded[1] isEqual:P(0,2)],"Messenger: real stories added in the same update are still announced, at their shifted positions");
  REQUIRE(viewerCalls==1,"Messenger: the app's own update callback still runs exactly once");
  ((void(*)(id,SEL,id,id,id,id))objc_msgSend)([viewer new],upd,[NSMutableArray arrayWithObjects:unread,adBucket,nil],nil,(@[@"odd"]),nil);
  REQUIRE(seenAdded.count==0&&viewerCalls==2,"Messenger: index paths that cannot be adjusted are not passed on, and the callback still runs");
  NSArray *kept=@[P(0,0),P(0,1)];
  ((void(*)(id,SEL,id,id,id,id))objc_msgSend)([viewer new],upd,[NSMutableArray arrayWithObjects:unread,readBucket,nil],nil,kept,nil);
  REQUIRE([seenModels isEqualToArray:(@[unread,readBucket])]&&seenAdded==kept,"Messenger: a story list with no advertisement is passed through, added index paths untouched");
  NSArray *out=((NSArray *(*)(id,SEL))objc_msgSend)([ds new],sel_registerName("inboxRows"));
  REQUIRE(out.count==4&&![out containsObject:adRow],"Messenger: the ad row is removed");
  REQUIRE([out containsObject:chatRow]&&[out containsObject:storyRow]&&[out containsObject:pymkRow]&&[out containsObject:other],"Messenger: chats, Stories, suggestions and unknown rows stay");
 }
 // ---- the catalogue and report modules know the new modules and their bundles
 REQUIRE([MYBAdsEntry(@"youtubemusic")[@"bundles"] isEqual:@[@"com.google.ios.youtubemusic"]]&&[MYBAdsEntry(@"x")[@"bundles"] isEqual:@[@"com.atebits.Tweetie2"]]&&[MYBAdsEntry(@"messenger")[@"bundles"] isEqual:@[@"com.facebook.Messenger"]],"catalogue: narrow bundle filters for the three new modules");
 REQUIRE(MYBAdsModuleEnabled(@{@"ads-youtube":@NO},@"youtubemusic")&&!MYBAdsModuleEnabled(@{@"ads-youtubemusic":@NO},@"youtubemusic")&&MYBAdsModuleEnabled(@{@"ads-x":@YES},@"x"),"switches: each module has its own switch and is on by default");
 if(failures){fprintf(stderr,"%d failure(s)\n",failures);return 1;}
 printf("YouTube Music, X and Messenger module checks passed.\n");return 0;}}
