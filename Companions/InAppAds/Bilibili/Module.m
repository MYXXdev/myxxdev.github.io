// MYbloXX In-App Ad Blocking: Bilibili. Ads only.
// PROVENANCE: written against interface evidence from two MIT tweaks, cxz/BiliBiliTweak (copyright (c) 2025 cxz, 9062479) and its sibling
// BiliBiliMApp (37b8d31): the feed address, the card-type and field names of commercial feed cards, the three search ad card types, and the
// search response class and its documented protobuf initialiser. No source text is copied. The choice of what counts as an ad follows it, and
// is narrower: those tweaks also remove popups, banners, live-room panels, "related game" and goods cards, a rating prompt and more, none of
// which is an advertising decision, and none of which is done here. Home-feed and search results are otherwise returned untouched.
//
// Two places, each switched off by itself if the app does not match:
//   1. The home feed response (app.bilibili.com/x/v2/feed/index, read through the app's BFCRequest completion handler): cards of type
//      cm_v1 and cm_v2 (commercial), cm_double_v7 and cm_double_v9 cards that carry ad_info, and banner items whose is_ad is true.
//   2. Search results: items whose card type is video_ad, picture_ad or brand_ad_giant are taken out of the response model right after it is
//      decoded.
// A response without any of those is passed on as the same bytes.
#import <Foundation/Foundation.h>
#import <string.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#import "../../../Shared/MYBAdsSignature.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

typedef void(^MYBBilibiliDone)(NSData *,NSURLResponse *,NSError *);
static IMP origRequestInit,origSearchInit;

static BOOL MYBBilibiliTruthy(id value){return [value isKindOfClass:NSNumber.class]?[value boolValue]:([value isKindOfClass:NSString.class]&&([value isEqual:@"1"]||[[value lowercaseString] isEqual:@"true"]));}
static BOOL MYBBilibiliCardIsAd(NSDictionary *card){
 NSString *type=[card[@"card_type"] isKindOfClass:NSString.class]?card[@"card_type"]:nil;
 if([type isEqual:@"cm_v1"]||[type isEqual:@"cm_v2"])return YES;
 if([type isEqual:@"cm_double_v7"]||[type isEqual:@"cm_double_v9"])return card[@"ad_info"]&&![card[@"ad_info"] isKindOfClass:NSNull.class];
 return NO;
}
// Whether this is the home feed request: exact host and path, so no other Bilibili request is ever touched.
BOOL MYBBilibiliIsFeedURL(NSURL *url){return [url.host.lowercaseString isEqual:@"app.bilibili.com"]&&[url.path isEqual:@"/x/v2/feed/index"];}
// Removes ad cards from a feed response. Returns the same object when nothing was removed.
NSData *MYBBilibiliFilterFeed(NSData *data){
 if(data.length<16||data.length>4*1024*1024||!memmem(data.bytes,data.length,"card_type",9))return data;
 id json=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
 NSMutableDictionary *body=[json isKindOfClass:NSMutableDictionary.class]&&[json[@"data"] isKindOfClass:NSMutableDictionary.class]?json[@"data"]:nil;
 NSMutableArray *items=[body[@"items"] isKindOfClass:NSMutableArray.class]?body[@"items"]:nil;if(!items)return data;
 NSUInteger removed=0;NSMutableIndexSet *drop=[NSMutableIndexSet indexSet];
 for(NSUInteger i=0;i<items.count;i++){
  NSMutableDictionary *card=[items[i] isKindOfClass:NSMutableDictionary.class]?items[i]:nil;if(!card)continue;
  if(MYBBilibiliCardIsAd(card)){[drop addIndex:i];removed++;continue;}
  NSMutableArray *banners=[card[@"banner_item"] isKindOfClass:NSMutableArray.class]?card[@"banner_item"]:nil;
  if(banners.count){
   NSIndexSet *ads=[banners indexesOfObjectsPassingTest:^BOOL(id b,NSUInteger k,BOOL *stop){return [b isKindOfClass:NSDictionary.class]&&MYBBilibiliTruthy(b[@"is_ad"]);}];
   if(ads.count){[banners removeObjectsAtIndexes:ads];removed+=ads.count;if(!banners.count)[drop addIndex:i];} // a banner card left empty goes with its ads
  }
 }
 if(!removed)return data;
 [items removeObjectsAtIndexes:drop];
 MYBAdsNoteDecisions(@"bilibili",@"feed",removed);
 return [NSJSONSerialization dataWithJSONObject:json options:0 error:NULL]?:data;
}
static NSSet<NSString *> *MYBBilibiliSearchAdTypes(void){return [NSSet setWithArray:@[@"video_ad",@"picture_ad",@"brand_ad_giant"]];}
// The search response model: takes the ad items out of itemArray, keeps every other item in its order.
void MYBBilibiliFilterSearch(id response){
 SEL get=sel_registerName("itemArray"),set=sel_registerName("setItemArray:");
 if(!response||![response respondsToSelector:get]||![response respondsToSelector:set])return;
 NSArray *items=((id(*)(id,SEL))objc_msgSend)(response,get);if(![items isKindOfClass:NSArray.class]||!items.count)return;
 SEL goto_p=sel_registerName("goto_p");NSMutableArray *kept=[NSMutableArray arrayWithCapacity:items.count];
 for(id item in items){
  id type=[item respondsToSelector:goto_p]?((id(*)(id,SEL))objc_msgSend)(item,goto_p):nil;
  if([type isKindOfClass:NSString.class]&&[MYBBilibiliSearchAdTypes() containsObject:type])continue;
  [kept addObject:item];
 }
 if(kept.count==items.count)return;
 ((void(*)(id,SEL,id))objc_msgSend)(response,set,kept);
 MYBAdsNoteDecisions(@"bilibili",@"slot",items.count-kept.count);
}
static id hookRequestInit(id self_,SEL _cmd,NSURLRequest *request,unsigned long long type,long long priority,id progress,id metrics,MYBBilibiliDone done){
 MYBBilibiliDone use=done;
 if(done&&MYBBilibiliIsFeedURL(request.URL))use=^(NSData *data,NSURLResponse *response,NSError *error){done(error?data:MYBBilibiliFilterFeed(data),response,error);};
 return ((id(*)(id,SEL,id,unsigned long long,long long,id,id,id))origRequestInit)(self_,_cmd,request,type,priority,progress,metrics,use);
}
static id hookSearchInit(id self_,SEL _cmd,id data,id registry,NSError **error){
 id result=((id(*)(id,SEL,id,id,NSError **))origSearchInit)(self_,_cmd,data,registry,error);
 MYBBilibiliFilterSearch(result);
 return result;
}
// Installs a hook only where the class exists and the method has exactly the expected signature.
static BOOL MYBBilibiliHook(const char *cls,const char *sel,const char *sig,IMP replacement,IMP *original){
 Class c=objc_getClass(cls);if(!c)return NO;
 return MYBAdsSignatureMatches(class_getInstanceMethod(c,sel_registerName(sel)),sig)&&MYBAdsHook(c,sel_registerName(sel),NO,replacement,original);
}
NSUInteger MYBBilibiliInstallHooks(NSUInteger *attempted){
 NSUInteger ok=0;
 if(MYBBilibiliHook("BFCRequest","initWithRequest:taskType:priority:progressHandler:metricsHandler:completionHandler:","@@:@Qq@@@",(IMP)hookRequestInit,&origRequestInit))ok++;
 if(MYBBilibiliHook("BAPIPolymerAppSearchV1SearchAllResponse","initWithData:extensionRegistry:error:","@@:@@^",(IMP)hookSearchInit,&origSearchInit))ok++;
 if(attempted)*attempted=2;return ok;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_bilibili(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"bilibili"))return;
  MYBAdsReportLoaded(@"bilibili",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBBilibiliInstallHooks(&attempted);MYBAdsLogResult("bilibili",ok,attempted);MYBAdsReportHooks(@"bilibili",ok,attempted,0);
 }
}
#endif
