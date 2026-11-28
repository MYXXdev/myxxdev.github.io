// Tests for the opt-in discovery collectors: bounded, names only, nothing from content, and off unless switched on.
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../Shared/MYBAdsReport.h"
#import "../Shared/MYBAdSDK.h"
#import "../Shared/MYBAdSDKStatus.h"
#include "../Companions/InAppAds/Facebook/Module.m"
#include "../Companions/InAppAds/AppStore/Module.m"
static int failures=0;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)
static Class make(const char *name,Class sup){Class c=objc_allocateClassPair(sup?:NSObject.class,name,0);objc_registerClassPair(c);return c;}
static void add(Class c,const char *sel,id block,const char *types){class_addMethod(c,sel_registerName(sel),imp_implementationWithBlock(block),types);}
static Class gFake;
__attribute__((ns_returns_retained)) static id fakeInit(id s,SEL c,void *t){return [gFake new];}
int main(void){@autoreleasepool{
 // off unless switched on, and only by a real number
 REQUIRE(!MYBAdsDiscoveryEnabled(nil)&&!MYBAdsDiscoveryEnabled(@{})&&!MYBAdsDiscoveryEnabled(@{@"ads-discovery-until":@"yes"})&&!MYBAdsDiscoveryEnabled(@{@"ads-discovery-until":@0})&&!MYBAdsDiscoveryEnabled(@{@"ads-discovery":@YES}),"discovery is off by default, for a past time, and for the old plain switch");
 {NSTimeInterval n=1000;REQUIRE(MYBAdsDiscoverySessionAt(@{@"ads-discovery-until":@(n+300),@"ads-discovery-session":@"0123abcd"},n)&&!MYBAdsDiscoverySessionAt(@{@"ads-discovery-until":@(n+300)},n)&&!MYBAdsDiscoverySessionAt(@{@"ads-discovery-until":@(n+300),@"ads-discovery-session":@"../etc"},n)&&!MYBAdsDiscoverySessionAt(@{@"ads-discovery-until":@(n+300),@"ads-discovery-session":@7},n)&&!MYBAdsDiscoverySessionAt(@{@"ads-discovery-until":@(n-1),@"ads-discovery-session":@"0123abcd"},n),"a session needs a live end time and a well-formed id");}
 {NSTimeInterval n=1000;REQUIRE(MYBAdsDiscoveryEnabledAt(@{@"ads-discovery-until":@(n+300)},n)&&!MYBAdsDiscoveryEnabledAt(@{@"ads-discovery-until":@(n-1)},n)&&!MYBAdsDiscoveryEnabledAt(@{@"ads-discovery-until":@(n+86400)},n),"a session is on until its end time, and a time more than one session ahead is not believed");}
 // ad-like names: whole word parts only
 for(NSString *n in @[@"IGAdItem",@"AdSlot",@"isAd",@"adInfo",@"loadAds",@"SponsoredLockup",@"ASAdvertCell",@"adUnitID",@"Ad"])REQUIRE(MYBAdsDiscoveryNameLooksAdLike(n),([[@"ad-like: " stringByAppendingString:n] UTF8String]));
 for(NSString *n in @[@"Address",@"Adapter",@"addObject:",@"loadView",@"Header",@"Adjust",@"Advance",@"download",@"UIViewController"])REQUIRE(!MYBAdsDiscoveryNameLooksAdLike(n),([[@"not ad-like: " stringByAppendingString:n] UTF8String]));
 // selectors with signatures, both sides, capped
 Class model=make("MYBDiscSponsoredModel",nil);
 add(model,"placementIndex",^long long(id s){return 3;},"q@:");add(model,"setItem:atIndex:",^(id s,id a,long long b){},"v@:@q");add(model,"unrelated",^(id s){},"v@:");
 add(object_getClass(model),"sponsoredCount",^long long(id s){return 1;},"q@:");
 NSArray *sels=MYBAdsDiscoverySelectors(model,@[@"placement",@"item"],40);
 REQUIRE([sels containsObject:@"-placementIndex q@:"]&&[sels containsObject:@"-setItem:atIndex: v@:@q"]&&[sels containsObject:@"+sponsoredCount q@:"]&&![[sels componentsJoinedByString:@" "] containsString:@"unrelated"],"selectors come with signatures, class side marked +, unrelated ones left out");
 Class many=make("MYBDiscMany",nil);for(int i=0;i<80;i++){char n[32];snprintf(n,sizeof n,"itemNumber%d",i);add(many,n,^(id s){},"v@:");}
 REQUIRE(MYBAdsDiscoverySelectors(many,@[@"item"],25).count==25,"a selector list is capped");
 // the counter is bounded
 MYBAdsDiscoveryCounter *c=[[MYBAdsDiscoveryCounter alloc] initWithCap:5];for(int i=0;i<50;i++)[c note:[NSString stringWithFormat:@"C%d",i]];[c note:@"C0"];
 REQUIRE(c.snapshot.count==6&&[c.snapshot[@"other"] intValue]==45&&[c.snapshot[@"C0"] intValue]==2,"the counter keeps its first names and folds the rest into other");
 // a log line is one bounded JSON object with the module prefix
 NSMutableArray *big=[NSMutableArray array];for(int i=0;i<4000;i++)[big addObject:@"ClassNameClassName"];
 NSString *line=MYBAdsDiscoveryLine(@"x",@{@"big":big});
 REQUIRE([line hasPrefix:@"MYBAdsDiscovery x {"]&&line.length<MYB_ADS_DISCOVERY_MAX_LINE+60&&[line hasSuffix:@"...cut"],"a log line is prefixed and cut to its limit");
 // view walk: counts class names only, never text; the data source and its selectors are found
 Class cell=make("MYBDiscAdCell",nil);add(cell,"text",^id(id s){return @"SECRET-ACCOUNT-TEXT";},"@@:");
 Class list=make("MYBDiscListView",nil),dsClass=make("MYBDiscFeedDataSource",nil);
 add(dsClass,"insertItems:atIndexPaths:",^(id s,id a,id b){},"v@:@@");add(dsClass,"numberOfItemsInSection:",^long long(id s,long long x){return 1;},"q@:q");
 Class winClass=make("MYBDiscWindow",nil);
 __block id dsInst=[dsClass new],cellInst=[cell new],listInst=[list new],win=[winClass new];
 add(winClass,"subviews",^id(id s){return @[listInst];},"@@:");
 add(list,"subviews",^id(id s){return @[cellInst];},"@@:");add(list,"dataSource",^id(id s){return dsInst;},"@@:");
 add(cell,"subviews",^id(id s){return @[];},"@@:");
 NSArray *mine=@[]; // classes made at run time belong to no image (class_getImageName is NULL), so an image filter could never match them; the cap is far above the few ad-like system classes of a Foundation-only process
 NSDictionary *info=MYBFacebookDiscoveryInfo(1,@[win],mine);
 NSString *text=MYBAdsDiscoveryLine(@"facebook",info);
 REQUIRE([info[@"dataSources"][@"MYBDiscFeedDataSource"][@"listView"] isEqual:@"MYBDiscListView"],"Facebook discovery finds the list's data source class");
 REQUIRE([[info[@"dataSources"][@"MYBDiscFeedDataSource"][@"selectors"] componentsJoinedByString:@"|"] containsString:@"-insertItems:atIndexPaths: v@:@@"],"Facebook discovery gives the insertion selector with its full signature");
 REQUIRE([info[@"viewClasses"][@"MYBDiscAdCell"] intValue]==1&&[info[@"adLikeClasses"] containsObject:@"MYBDiscAdCell"],"Facebook discovery counts view classes");
 REQUIRE(![text containsString:@"SECRET-ACCOUNT-TEXT"],"nothing from a view's content is ever collected");
 // model types: recorded only while discovery created the counter
 MYBFacebookModelTypes=[[MYBAdsDiscoveryCounter alloc] initWithCap:10];
 Class post=make("MYBDiscPostModel",nil);add(post,"category",^id(id s){return @"SPONSORED";},"@@:");Class plain=make("MYBDiscPlainModel",nil);
 gFake=post;origPandoInit=(IMP)fakeInit;
 id out=hookPandoInit(nil,NULL,NULL);REQUIRE(out==nil,"discovery does not change what the feed hook does with an ad");
 gFake=plain;
 out=hookPandoInit(nil,NULL,NULL);REQUIRE(out!=nil,"nor with an unclassified unit");
 NSDictionary *types=MYBFacebookModelTypes.snapshot;
 REQUIRE([types[@"MYBDiscPostModel|ad"] intValue]==1&&[types[@"MYBDiscPlainModel|unclassified"] intValue]==1,"model types are counted by class name and how they were classified at creation");
 MYBFacebookModelTypes=nil;
 // App Store: ad-like classes and their selectors, view classes, no content
 Class lockup=make("MYBDiscSearchAdLockup",nil);add(lockup,"impressionMetrics",^id(id s){return nil;},"@@:");
 NSDictionary *as=MYBAppStoreDiscoveryInfo(2,mine,@[win],@"3.0",@"16.5.1");
 REQUIRE([as[@"adLikeClasses"] containsObject:@"MYBDiscSearchAdLockup"]&&[[as[@"classSelectors"][@"MYBDiscSearchAdLockup"][@"selectors"] firstObject] hasPrefix:@"-impressionMetrics"],"App Store discovery lists ad-like classes with their selectors");
 REQUIRE([as[@"os"] isEqual:@"16.5.1"]&&[as[@"appVersion"] isEqual:@"3.0"]&&as[@"viewClasses"][@"MYBDiscAdCell"]&&[as[@"adLikeViews"][@"MYBDiscAdCell"][@"count"] intValue]==1,"App Store discovery records versions and ad-like view classes with counts");
 REQUIRE(![MYBAdsDiscoveryLine(@"appstore",as) containsString:@"SECRET-ACCOUNT-TEXT"],"App Store discovery collects no content");

 // ---- session: pieces from an app, the service's memory-only store, start / stop / clear ----
 {
  NSDictionary *bundles=@{@"facebook":@[@"com.facebook.Facebook"],@"appstore":@[@"com.apple.AppStore"],@"amazon":@[@"com.amazon.Amazon"]};
  NSString *line=MYBAdsDiscoveryLine(@"appstore",@{@"phase":@"started",@"names":@[@"A",@"B"]});
  NSMutableString *big=[NSMutableString string];for(int i=0;i<500;i++)[big appendFormat:@"Cls%d,",i];
  NSString *longLine=MYBAdsDiscoveryLine(@"appstore",@{@"list":big});
  NSArray *paths=MYBAdsDiscoveryPaths(@"appstore",longLine,@"com.apple.AppStore",@"0123abcd",@"aaaa0001");
  REQUIRE(paths.count>=2&&paths.count<=MYB_ADS_DISCOVERY_MAX_CHUNKS,"a long line is sent in several bounded pieces");
  NSMutableArray<NSDictionary *> *queries=[NSMutableArray array];
  for(NSString *path in paths){NSURLComponents *c=[NSURLComponents componentsWithString:[@"http://127.0.0.1" stringByAppendingString:path]];NSMutableDictionary *q=[NSMutableDictionary dictionary];for(NSURLQueryItem *it in c.queryItems)q[it.name]=it.value;[queries addObject:q];REQUIRE([q[@"d"] length]<=MYB_ADS_DISCOVERY_CHUNK,"each piece is within the piece limit");}
  NSTimeInterval now=5000;
  REQUIRE(!MYBAdsDiscoveryAccept(queries[0],bundles,now),"with no session open nothing is accepted");
  NSDictionary *opened=MYBAdsDiscoveryControl(@"start",now);NSString *ses=opened[@"session"];
  REQUIRE([opened[@"until"] doubleValue]==now+MYB_ADS_DISCOVERY_SECONDS&&MYBAdsToken(ses,8,@"0123456789abcdef"),"start opens a session of the fixed length with its own id");
  REQUIRE(!MYBAdsDiscoveryAccept(queries[0],bundles,now+1),"a piece from some other session is refused");
  {NSMutableArray *again=[NSMutableArray array];for(NSString *path in MYBAdsDiscoveryPaths(@"appstore",longLine,@"com.apple.AppStore",@"0123abcd",ses)){NSURLComponents *c=[NSURLComponents componentsWithString:[@"http://127.0.0.1" stringByAppendingString:path]];NSMutableDictionary *q=[NSMutableDictionary dictionary];for(NSURLQueryItem *it in c.queryItems)q[it.name]=it.value;[again addObject:q];}queries=again;}
  {NSMutableDictionary *noSession=[queries[0] mutableCopy];[noSession removeObjectForKey:@"s"];REQUIRE(!MYBAdsDiscoveryAccept(noSession,bundles,now+1),"a piece without a session id is refused");}
  NSMutableDictionary *wrong=[queries[0] mutableCopy];wrong[@"app"]=@"com.example.other";REQUIRE(!MYBAdsDiscoveryAccept(wrong,bundles,now),"a piece must come from the module's own app");
  NSMutableDictionary *badModule=[queries[0] mutableCopy];badModule[@"module"]=@"reddit";REQUIRE(!MYBAdsDiscoveryAccept(badModule,bundles,now),"only the three collectors are accepted");
  NSMutableDictionary *nonAscii=[queries[0] mutableCopy];nonAscii[@"d"]=@"caf\u00e9";REQUIRE(!MYBAdsDiscoveryAccept(nonAscii,bundles,now),"non-ASCII pieces are refused");
  NSMutableDictionary *badId=[queries[0] mutableCopy];badId[@"id"]=@"../etc";REQUIRE(!MYBAdsDiscoveryAccept(badId,bundles,now),"a malformed id is refused");
  for(NSUInteger i=0;i<queries.count;i++)REQUIRE(MYBAdsDiscoveryAccept(queries[i],bundles,now+1),"pieces of a valid line are accepted");
  NSArray *entries=MYBAdsDiscoverySnapshot(now+2)[@"entries"];
  REQUIRE(entries.count==1&&[entries[0][@"line"] isEqual:longLine],"the pieces are put back together as the exact line");
  REQUIRE([MYBAdsDiscoverySnapshot(now+2)[@"active"] boolValue]&&![MYBAdsDiscoverySnapshot(now+MYB_ADS_DISCOVERY_SECONDS+1)[@"active"] boolValue],"a session reports itself finished after its end time");
  REQUIRE(!MYBAdsDiscoveryAccept(queries[0],bundles,now+MYB_ADS_DISCOVERY_SECONDS+1),"after the session ends nothing more is accepted");
  // a URL in a line is refused (content never belongs here)
  NSString *urlLine=@"MYBAdsDiscovery appstore {\"x\":\"https://example.test/a\"}";
  NSArray *up=MYBAdsDiscoveryPaths(@"appstore",urlLine,@"com.apple.AppStore",@"deadbeef",ses);NSURLComponents *uc=[NSURLComponents componentsWithString:[@"http://127.0.0.1" stringByAppendingString:up[0]]];NSMutableDictionary *uq=[NSMutableDictionary dictionary];for(NSURLQueryItem *it in uc.queryItems)uq[it.name]=it.value;
  MYBAdsDiscoveryControl(@"start",now);REQUIRE(!MYBAdsDiscoveryAccept(uq,bundles,now+1),"a line containing a web address is refused");
  // a line that does not start as one collected line is refused
  NSArray *fp=MYBAdsDiscoveryPaths(@"appstore",@"hello",@"com.apple.AppStore",@"cafecafe",ses);NSURLComponents *fc=[NSURLComponents componentsWithString:[@"http://127.0.0.1" stringByAppendingString:fp[0]]];NSMutableDictionary *fq=[NSMutableDictionary dictionary];for(NSURLQueryItem *it in fc.queryItems)fq[it.name]=it.value;
  REQUIRE(!MYBAdsDiscoveryAccept(fq,bundles,now+1),"free text is refused");
  // entry and byte caps
  // Stop and Clear end the session: a report still on its way cannot repopulate, and a new session never accepts an old one's pieces
  {NSDictionary *s1=MYBAdsDiscoveryControl(@"start",now+10);NSString *old=s1[@"session"];
   NSMutableDictionary *late=[queries[0] mutableCopy];late[@"s"]=old;late[@"id"]=@"11112222";
   MYBAdsDiscoveryControl(@"clear",now+11);
   REQUIRE(!MYBAdsDiscoveryAccept(late,bundles,now+12)&&[MYBAdsDiscoverySnapshot(now+12)[@"entries"] count]==0,"after Clear a delayed report is refused and nothing returns");
   NSDictionary *s2=MYBAdsDiscoveryControl(@"start",now+13);REQUIRE(![s2[@"session"] isEqual:old],"a new session has a different id");
   late[@"id"]=@"33334444";REQUIRE(!MYBAdsDiscoveryAccept(late,bundles,now+14),"a report from the earlier session is refused by the later one");
   MYBAdsDiscoveryControl(@"stop",now+15);late[@"s"]=s2[@"session"];late[@"id"]=@"55556666";REQUIRE(!MYBAdsDiscoveryAccept(late,bundles,now+16),"after Stop nothing is accepted");}
  ses=MYBAdsDiscoveryControl(@"start",now)[@"session"];
  MYBAdsDiscoveryControl(@"clear",now);ses=MYBAdsDiscoveryControl(@"start",now)[@"session"];
  for(int k=0;k<40;k++){NSArray *pp=MYBAdsDiscoveryPaths(@"facebook",MYBAdsDiscoveryLine(@"facebook",@{@"k":@(k)}),@"com.facebook.Facebook",[NSString stringWithFormat:@"%08x",k],ses);NSURLComponents *c=[NSURLComponents componentsWithString:[@"http://127.0.0.1" stringByAppendingString:pp[0]]];NSMutableDictionary *q=[NSMutableDictionary dictionary];for(NSURLQueryItem *it in c.queryItems)q[it.name]=it.value;MYBAdsDiscoveryAccept(q,bundles,now+1);}
  REQUIRE([MYBAdsDiscoverySnapshot(now+2)[@"entries"] count]==MYB_ADS_DISCOVERY_MAX_ENTRIES,"the service keeps at most the newest 24 lines");
  MYBAdsDiscoveryControl(@"stop",now+3);REQUIRE([MYBAdsDiscoverySnapshot(now+4)[@"entries"] count]==MYB_ADS_DISCOVERY_MAX_ENTRIES&&![MYBAdsDiscoverySnapshot(now+4)[@"active"] boolValue],"stop ends the session but keeps what was collected");
  MYBAdsDiscoveryControl(@"clear",now+4);REQUIRE([MYBAdsDiscoverySnapshot(now+5)[@"entries"] count]==0,"clear deletes what was collected");
  REQUIRE(![MYBAdsDiscoveryControl(@"explode",now)[@"ok"] boolValue],"an unknown control is refused");
  // the sender
  NSMutableArray *sent=[NSMutableArray array];MYBAdsReportSink=^(NSString *p){@synchronized(sent){[sent addObject:p];}};
  MYBAdsDiscoverySend(@"appstore",line);dispatch_sync(MYBAdsQueue(),^{});
  REQUIRE(sent.count==0,"without a collector session the sender sends nothing");
  // collector lifecycle with a replaceable prefs reader
  {__block NSDictionary *prefs=@{@"ads-discovery-until":@(NSDate.date.timeIntervalSince1970+300),@"ads-discovery-session":@"abcd0001"};
   MYBAdsDiscoveryPrefsReader=^NSDictionary *{return prefs;};
   __block int starts=0;void(^start)(NSString *)=^(NSString *sid){(void)sid;starts++;};
   REQUIRE(MYBAdsDiscoveryEvaluate(@"appstore",start)&&starts==1,"a running session starts the collector");
   REQUIRE(!MYBAdsDiscoveryEvaluate(@"appstore",start)&&starts==1,"the same session starts it only once");
   MYBAdsDiscoverySend(@"appstore",line);dispatch_sync(MYBAdsQueue(),^{});
   REQUIRE(sent.count==1&&[sent[0] containsString:@"s=abcd0001"],"pieces carry the session id");
   prefs=@{@"ads-discovery-until":@(NSDate.date.timeIntervalSince1970+300),@"ads-discovery-session":@"abcd0002"};
   MYBAdsDiscoverySend(@"appstore",line);dispatch_sync(MYBAdsQueue(),^{});
   REQUIRE(sent.count==1,"a collector of an ended session sends nothing once another session has begun");
   REQUIRE(MYBAdsDiscoveryEvaluate(@"appstore",start)&&starts==2,"a new session starts the collector again without restarting the app");
   prefs=@{@"ads-discovery-until":@(NSDate.date.timeIntervalSince1970-1),@"ads-discovery-session":@"abcd0002"};
   MYBAdsDiscoverySend(@"appstore",line);dispatch_sync(MYBAdsQueue(),^{});
   REQUIRE(sent.count==1&&!MYBAdsDiscoveryLive(@"appstore"),"an expired session stops the collector sending");
   prefs=@{};REQUIRE(!MYBAdsDiscoveryEvaluate(@"facebook",start)&&starts==2,"Stop or Clear (no session) starts nothing");
   MYBAdsDiscoveryPrefsReader=nil;}
  MYBAdsReportSink=nil;
  (void)line;
 }

 // ---- Ad Network Blocking: the app itself reports that the library loaded ------------------------------------------------------------------
 {
  MYBAdSDKSeenReset();
  NSDictionary *ok=@{@"app":@"com.example.game",@"installed":@"3",@"attempted":@"8",@"blocked":@"0",@"launch":@"a1b2c3d4",@"t":@"90",@"ver":@"6.11192026-15-RH",@"av":@"1.2.3",@"arch":@"arm64"};
  REQUIRE(MYBAdSDKRecordLoaded(ok,100)&&[MYBAdSDKSeenSnapshot()[@"com.example.game"][@"installed"] integerValue]==3,"a valid report is recorded");
  for(NSString *bad in @[@"com.apple.mobilesafari",@"net.myxxdev.mybloxx",@"__x.y",@"nodots",@"a b.c",@""]){NSMutableDictionary *m=[ok mutableCopy];m[@"app"]=bad;REQUIRE(!MYBAdSDKRecordLoaded(m,100),"system, MYbloXX and malformed apps are refused");}
  {NSMutableDictionary *m=[ok mutableCopy];m[@"installed"]=@"9";m[@"attempted"]=@"8";REQUIRE(!MYBAdSDKRecordLoaded(m,100),"more hooked than attempted is refused");}
  {NSMutableDictionary *m=[ok mutableCopy];m[@"arch"]=@"x86";REQUIRE(!MYBAdSDKRecordLoaded(m,100),"an unknown architecture is refused");}
  {NSMutableDictionary *m=[ok mutableCopy];m[@"installed"]=@"-1";REQUIRE(!MYBAdSDKRecordLoaded(m,100),"a negative count is refused");}
  for(int i=0;i<120;i++){NSMutableDictionary *m=[ok mutableCopy];m[@"app"]=[NSString stringWithFormat:@"com.example.app%d",i];MYBAdSDKRecordLoaded(m,100);}
  REQUIRE(MYBAdSDKSeenSnapshot().count<=96,"at most 96 apps are kept");

  // ---- activation status is tied to the current launch and choice ----
  {
   NSString *V=@"6.11192026-15-RH";
   NSDictionary *r1=@{@"launch":@"a1b2c3d4",@"readAt":@100,@"ver":V,@"installed":@3,@"attempted":@10,@"blocked":@0};
   REQUIRE(MYBAdSDKStatus(YES,50,nil,YES,V)==MYBSDKRestartNeeded,"selected, no report: restart required");
   REQUIRE(MYBAdSDKStatus(YES,50,r1,YES,V)==MYBSDKHooksInstalled,"loaded after the choice: hooks installed, nothing blocked yet");
   REQUIRE(MYBAdSDKStatus(YES,150,r1,YES,V)==MYBSDKRestartNeeded,"a report from before the choice changed is stale: restart required, not Active");
   REQUIRE(MYBAdSDKStatus(YES,100,r1,YES,V)==MYBSDKHooksInstalled,"a launch that read the choices at the moment of the change counts");
   REQUIRE(MYBAdSDKStatus(YES,50,@{@"launch":@"a1b2c3d4",@"readAt":@100,@"ver":@"6.111626-20-RH",@"installed":@3,@"blocked":@9},YES,V)==MYBSDKRestartNeeded,"a library from before an upgrade is stale");
   REQUIRE(MYBAdSDKStatus(YES,50,@{@"readAt":@100,@"ver":V,@"installed":@3},YES,V)==MYBSDKRestartNeeded,"a report with no launch id is not accepted as current");
   REQUIRE(MYBAdSDKStatus(YES,50,@{@"launch":@"a1b2c3d4",@"readAt":@100,@"ver":V,@"installed":@0,@"blocked":@0},YES,V)==MYBSDKLoadedNoSDK,"loaded, no compatible SDK interfaces found");
   REQUIRE(MYBAdSDKStatus(YES,50,@{@"launch":@"a1b2c3d4",@"readAt":@100,@"ver":V,@"installed":@2,@"blocked":@4},YES,V)==MYBSDKBlocking,"ad-load attempts blocked");
   REQUIRE(MYBAdSDKStatus(NO,150,r1,YES,V)==MYBSDKOffStillLoaded&&MYBAdSDKStatus(NO,0,nil,YES,V)==MYBSDKOff,"after deselection a stale report never implies the module is active");
   REQUIRE(MYBAdSDKStatus(YES,50,r1,NO,V)==MYBSDKUnknown,"an unreachable service claims nothing");
   REQUIRE([MYBAdSDKStatusText(MYBAdSDKStatus(NO,150,r1,YES,V),r1) rangeOfString:@"Active"].location==NSNotFound,"deselected text never says Active");
   // server side: launches replace each other only forward; counts only grow within a launch
   MYBAdSDKSeenReset();
   NSDictionary *ok=@{@"app":@"com.example.game",@"installed":@"3",@"attempted":@"8",@"blocked":@"4",@"launch":@"a1b2c3d4",@"t":@"100",@"ver":V,@"av":@"1",@"arch":@"arm64"};
   REQUIRE(MYBAdSDKRecordLoaded(ok,200),"report recorded");
   {NSMutableDictionary *m=[ok mutableCopy];m[@"blocked"]=@"2";REQUIRE(MYBAdSDKRecordLoaded(m,201)&&[MYBAdSDKSeenSnapshot()[@"com.example.game"][@"blocked"] intValue]==4,"a late, lower count of the same launch does not lower it");}
   {NSMutableDictionary *m=[ok mutableCopy];m[@"launch"]=@"ffffffff";m[@"t"]=@"50";REQUIRE(!MYBAdSDKRecordLoaded(m,202)&&[MYBAdSDKSeenSnapshot()[@"com.example.game"][@"launch"] isEqual:@"a1b2c3d4"],"a report from an older launch does not replace a newer one");}
   {NSMutableDictionary *m=[ok mutableCopy];m[@"launch"]=@"ffffffff";m[@"t"]=@"150";m[@"blocked"]=@"0";REQUIRE(MYBAdSDKRecordLoaded(m,203)&&[MYBAdSDKSeenSnapshot()[@"com.example.game"][@"blocked"] intValue]==0,"a newer launch starts its own count");}
   {NSMutableDictionary *m=[ok mutableCopy];m[@"t"]=@"9999999999";REQUIRE(!MYBAdSDKRecordLoaded(m,204),"a launch time in the future is refused");}
   {NSMutableDictionary *m=[ok mutableCopy];[m removeObjectForKey:@"launch"];REQUIRE(!MYBAdSDKRecordLoaded(m,205),"a report from a library without a launch id is refused");}
   {NSDictionary *p=@{@"ads-sdk-com.a.b":@YES,@"ads-sdkat-com.a.b":@123.0};REQUIRE(MYBAdSDKChangedAt(p,@"com.a.b")==123.0&&MYBAdSDKSelected(@{@"ads-sdkat-com.a.b":@YES},@"com.a.b")==NO,"the change time is never read as a choice");}
   MYBAdSDKSeenReset();
  }
  MYBAdSDKSeenReset();
  NSMutableArray *sent=[NSMutableArray array];MYBAdsReportSink=^(NSString *p){@synchronized(sent){[sent addObject:p];}};
  MYBAdSDKReportLoaded(2,8,5,90,@"6.11192026-15-RH");dispatch_sync(MYBAdsQueue(),^{});
  REQUIRE(sent.count==1&&[sent[0] hasPrefix:@"/mybloxx-ads-sdk-loaded?"]&&[sent[0] containsString:@"installed=2"]&&[sent[0] containsString:@"attempted=8"]&&[sent[0] containsString:@"blocked=5"]&&[sent[0] containsString:@"launch="]&&[sent[0] containsString:@"t=90"]&&[sent[0] containsString:@"ver=6.11192026-15-RH"],"the library sends its report through the local service route");
  MYBAdsReportSink=nil;
 }

 if(failures){fprintf(stderr,"%d failure(s)\n",failures);return 1;}
 printf("Discovery collector checks passed.\n");return 0;}}
