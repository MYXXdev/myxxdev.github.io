// Bilibili: the feed filter removes only commercial cards and flagged banner items, the search filter removes only the three ad types, every
// other card, field and order survives, and the hooks install only with the exact method signatures. Stand-in classes; not the real app.
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../Shared/MYBAdsReport.h"
#include "../Companions/InAppAds/Bilibili/Module.m"
static int failures=0;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)

@interface BAPIPolymerAppSearchV1Item:NSObject @property(copy) NSString *goto_p;@end
@implementation BAPIPolymerAppSearchV1Item @end
@interface BAPIPolymerAppSearchV1SearchAllResponse:NSObject @property(retain) NSMutableArray *itemArray;@end
@implementation BAPIPolymerAppSearchV1SearchAllResponse
- (id)initWithData:(id)data extensionRegistry:(id)registry error:(NSError **)error{
 if((self=[super init])){_itemArray=[NSMutableArray array];for(NSString *t in data){BAPIPolymerAppSearchV1Item *i=[BAPIPolymerAppSearchV1Item new];i.goto_p=t;[_itemArray addObject:i];}}
 return self;
}
@end
static NSURL *gSeenURL;static BOOL gSeenFiltered;
@interface BFCRequest:NSObject @end
@implementation BFCRequest
- (id)initWithRequest:(NSURLRequest *)r taskType:(unsigned long long)t priority:(long long)p progressHandler:(void(^)(long long,long long,long long))ph metricsHandler:(void(^)(id))mh completionHandler:(void(^)(NSData *,NSURLResponse *,NSError *))ch{
 if((self=[super init])){gSeenURL=r.URL;if(ch){NSData *raw=[NSJSONSerialization dataWithJSONObject:@{@"data":@{@"items":@[@{@"card_type":@"cm_v1"},@{@"card_type":@"small_cover_v2",@"title":@"keep"}]}} options:0 error:NULL];ch(raw,nil,nil);}}
 return self;
}
@end
static NSData *J(id o){return [NSJSONSerialization dataWithJSONObject:o options:0 error:NULL];}
static NSArray *Items(NSData *d){return [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL][@"data"][@"items"];}
int main(void){@autoreleasepool{
 REQUIRE(MYBBilibiliIsFeedURL([NSURL URLWithString:@"https://app.bilibili.com/x/v2/feed/index?build=1"])&&!MYBBilibiliIsFeedURL([NSURL URLWithString:@"https://app.bilibili.com/x/v2/feed/index/other"])&&!MYBBilibiliIsFeedURL([NSURL URLWithString:@"https://api.bilibili.com/x/v2/feed/index"])&&!MYBBilibiliIsFeedURL(nil),"only the exact home feed address is filtered");
 // feed
 NSDictionary *feed=@{@"code":@0,@"data":@{@"config":@{@"x":@1},@"items":@[
  @{@"card_type":@"small_cover_v2",@"title":@"A",@"card_goto":@"special_s"},
  @{@"card_type":@"cm_v1",@"ad_info":@{@"id":@1}},
  @{@"card_type":@"cm_v2"},
  @{@"card_type":@"cm_double_v9",@"ad_info":@{@"id":@2}},
  @{@"card_type":@"cm_double_v9",@"title":@"no ad info"},
  @{@"card_type":@"cm_double_v7",@"ad_info":[NSNull null]},
  @{@"card_type":@"banner_v8",@"banner_item":@[@{@"id":@1}]},
  @{@"card_type":@"banner_ipad_v8",@"banner_item":@[@{@"id":@2,@"is_ad":@YES},@{@"id":@3,@"is_ad":@NO},@{@"id":@4}]},
  @{@"card_type":@"banner_ipad_v8",@"banner_item":@[@{@"id":@5,@"is_ad":@YES}]},
  @{@"card_type":@"small_cover_v9",@"card_goto":@"live"}]},@"ttl":@5};
 NSData *in=J(feed);NSData *out=MYBBilibiliFilterFeed(in);
 NSArray *kept=Items(out);NSMutableArray *types=[NSMutableArray array];for(NSDictionary *c in kept)[types addObject:c[@"card_type"]];
 REQUIRE([types isEqual:(@[@"small_cover_v2",@"cm_double_v9",@"cm_double_v7",@"banner_v8",@"banner_ipad_v8",@"small_cover_v9"])],"only commercial cards are removed, every other card stays in order");
 REQUIRE([[kept[1] objectForKey:@"title"] isEqual:@"no ad info"]&&[kept[0][@"card_goto"] isEqual:@"special_s"]&&[kept[5][@"card_goto"] isEqual:@"live"],"a card without ad_info, a special card and a live card are kept");
 REQUIRE([kept[3][@"banner_item"] count]==1&&[kept[4][@"banner_item"] count]==2&&[kept[4][@"banner_item"][0][@"id"] intValue]==3,"only banner items flagged is_ad true go; false or missing flags stay");
 NSDictionary *whole=[NSJSONSerialization JSONObjectWithData:out options:0 error:NULL];
 REQUIRE([whole[@"code"] intValue]==0&&[whole[@"ttl"] intValue]==5&&[whole[@"data"][@"config"][@"x"] intValue]==1,"every other field of the response survives");
 NSData *clean=J(@{@"data":@{@"items":@[@{@"card_type":@"small_cover_v2"}]}});
 REQUIRE(MYBBilibiliFilterFeed(clean)==clean,"a response with no ad is passed on as the same bytes");
 NSData *odd=J(@{@"data":@{@"items":@"not an array",@"card_type":@"cm_v1"}});REQUIRE(MYBBilibiliFilterFeed(odd)==odd,"an unexpected shape is passed through");
 NSData *junk=[@"not json at all but long enough card_type" dataUsingEncoding:NSUTF8StringEncoding];REQUIRE(MYBBilibiliFilterFeed(junk)==junk&&MYBBilibiliFilterFeed(nil)==nil,"junk and nil are passed through");
 // search
 BAPIPolymerAppSearchV1SearchAllResponse *resp=[[BAPIPolymerAppSearchV1SearchAllResponse alloc] initWithData:@[@"video",@"video_ad",@"related_search",@"picture_ad",@"user",@"brand_ad_giant",@"special_s"] extensionRegistry:nil error:NULL];
 MYBBilibiliFilterSearch(resp);NSMutableArray *left=[NSMutableArray array];for(BAPIPolymerAppSearchV1Item *i in resp.itemArray)[left addObject:i.goto_p];
 REQUIRE([left isEqual:(@[@"video",@"related_search",@"user",@"special_s"])],"only the three ad card types leave search results; related searches and special cards stay");
 BAPIPolymerAppSearchV1SearchAllResponse *none=[[BAPIPolymerAppSearchV1SearchAllResponse alloc] initWithData:@[@"video"] extensionRegistry:nil error:NULL];NSMutableArray *same=none.itemArray;MYBBilibiliFilterSearch(none);
 REQUIRE(none.itemArray==same,"a response with no ad keeps the very same array");
 MYBBilibiliFilterSearch(nil);MYBBilibiliFilterSearch(@"not a model");REQUIRE(YES,"nil and unrelated objects are ignored");
 // hooks: exact signatures, both installed, duplicate install does nothing, behaviour through the hooks
 NSUInteger attempted=0;REQUIRE(MYBBilibiliInstallHooks(&attempted)==2&&attempted==2,"both hooks install against matching signatures");
 REQUIRE(MYBBilibiliInstallHooks(&attempted)==0,"a second install adds nothing");
 BFCRequest *req=[[BFCRequest alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://app.bilibili.com/x/v2/feed/index"]] taskType:0 priority:0 progressHandler:nil metricsHandler:nil completionHandler:^(NSData *d,NSURLResponse *r,NSError *e){gSeenFiltered=Items(d).count==1;}];
 REQUIRE(req&&gSeenFiltered,"the feed request's completion handler receives the filtered response");
 gSeenFiltered=NO;BFCRequest *other=[[BFCRequest alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://app.bilibili.com/x/v2/other"]] taskType:0 priority:0 progressHandler:nil metricsHandler:nil completionHandler:^(NSData *d,NSURLResponse *r,NSError *e){gSeenFiltered=Items(d).count==2;}];
 REQUIRE(other&&gSeenFiltered,"any other request is left exactly as it was");
 BAPIPolymerAppSearchV1SearchAllResponse *viaHook=[[BAPIPolymerAppSearchV1SearchAllResponse alloc] initWithData:@[@"video",@"video_ad"] extensionRegistry:nil error:NULL];
 REQUIRE(viaHook.itemArray.count==1,"the search model is filtered as soon as it is decoded");
 // a different signature leaves the hook off
 Class wrong=objc_allocateClassPair(NSObject.class,"BAPIPolymerAppSearchV1SearchAllResponseX",0);objc_registerClassPair(wrong);
 class_addMethod(wrong,sel_registerName("initWithData:extensionRegistry:error:"),imp_implementationWithBlock(^id(id s,id d){return s;}),"@@:@");
 REQUIRE(!MYBBilibiliHook("BAPIPolymerAppSearchV1SearchAllResponseX","initWithData:extensionRegistry:error:","@@:@@^",(IMP)hookSearchInit,&origSearchInit),"a method with another argument count is not hooked");
 REQUIRE(!MYBBilibiliHook("NoSuchClass","x","@@:",(IMP)hookSearchInit,&origSearchInit),"a missing class is not hooked");
 if(failures){fprintf(stderr,"%d failure(s)\n",failures);return 1;}
 printf("Bilibili checks passed.\n");return 0;}}
