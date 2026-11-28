// MYbloXX In-App Ad Blocking: Reddit. Ads only.
// PROVENANCE: ADAPTED from level3tjg/RedditFilter (MIT, copyright (c) 2025 level3tjg) and its newer fork and101/RedditFilter (MIT, copyright
// (c) 2026 and101, e1b597f: the object-wrapped comment-page ad form; its Home experiment override is NOT adopted): the interception point (the app's GraphQL
// data tasks), the ad markers (AdPost, adPayload, commentsPageAds, commentTreeAds, pdpCommentsAds) and the JSON walk follow its
// NSURLSession hook and filterNode. The MIT notice travels with the package. What differs: promoted entries are removed from the edge
// list instead of being marked hidden, responses without an ad marker are passed through byte for byte, and awards, scores,
// recommendations and auto-collapsing are not touched.
// Intercepts the app's GraphQL data tasks and removes promoted entries from the edge list. Responses without an ad marker
// pass through byte for byte; awards, scores, recommendations and auto-collapsing are not touched.
#import <Foundation/Foundation.h>
#import <string.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

typedef void(^MYBRedditHandler)(NSData *,NSURLResponse *,NSError *);
static IMP origDataTask;

static BOOL MYBRedditNodeIsAd(id node){
 if(![node isKindOfClass:NSDictionary.class])return NO;
 if([node[@"__typename"] isEqual:@"AdPost"])return YES;
 return [node[@"adPayload"] isKindOfClass:NSDictionary.class]; // a feed cell group carrying an ad payload
}
static BOOL MYBRedditWalk(id value,int depth){
 if(depth>6)return NO;BOOL changed=NO;
 if([value isKindOfClass:NSMutableDictionary.class]){
  NSMutableDictionary *dict=value;
  for(NSString *key in @[@"commentsPageAds",@"commentTreeAds",@"pdpCommentsAds"]){
   id list=dict[key];if([list isKindOfClass:NSArray.class]&&[(NSArray *)list count]){dict[key]=@[];changed=YES;MYBAdsNoteDecisions(@"reddit",@"comment",1);}
   // Newer responses wrap the ads in an object holding adPosts; the wrapper and its other fields (paging) stay so the app can still decode it.
   else if([list isKindOfClass:NSMutableDictionary.class]){id posts=list[@"adPosts"];if([posts isKindOfClass:NSArray.class]&&[(NSArray *)posts count]){list[@"adPosts"]=@[];changed=YES;MYBAdsNoteDecisions(@"reddit",@"comment",1);}}
  }
  id edges=dict[@"edges"];
  if([edges isKindOfClass:NSMutableArray.class]){
   NSMutableArray *list=edges;NSIndexSet *ads=[list indexesOfObjectsPassingTest:^BOOL(id edge,NSUInteger i,BOOL *stop){return [edge isKindOfClass:NSDictionary.class]&&MYBRedditNodeIsAd(edge[@"node"]);}];
   if(ads.count){[list removeObjectsAtIndexes:ads];changed=YES;MYBAdsNoteDecisions(@"reddit",@"feed",ads.count);}
  }
  for(id child in [dict allValues])if(MYBRedditWalk(child,depth+1))changed=YES;
 }else if([value isKindOfClass:NSMutableArray.class]){
  for(id child in (NSArray *)value)if(MYBRedditWalk(child,depth+1))changed=YES;
 }
 return changed;
}
// Returns replacement bytes when ads were removed, otherwise the very same NSData.
NSData *MYBRedditFilterResponse(NSData *data){
 if(data.length<16||data.length>8*1024*1024)return data;
 static const char *markers[]={"AdPost","adPayload","commentsPageAds","commentTreeAds","pdpCommentsAds"};BOOL seen=NO;
 for(size_t i=0;i<sizeof(markers)/sizeof(markers[0])&&!seen;i++)seen=memmem(data.bytes,data.length,markers[i],strlen(markers[i]))!=NULL;
 if(!seen)return data;
 id json=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
 if(!json||!MYBRedditWalk(json,0))return data;
 NSData *out=[NSJSONSerialization dataWithJSONObject:json options:0 error:NULL];
 return out?:data;
}
// Known limit, by decision: the first Home page can arrive as a streamed "deferred" query that the app requests without a completion
// handler, so the hook below never sees it. A tweak removes the experiment that triggers that query, but that changes how Home loads for
// every user, not only whether ads appear, and it has not been shown to be needed for ad removal or to leave the feed unchanged. It is
// therefore NOT done here: the feed's loading behaviour is never altered, and ads in that one deferred first page may remain.
static BOOL MYBRedditHost(NSURL *url){
 NSString *host=url.host.lowercaseString;
 return [host hasSuffix:@"reddit.com"]&&([host hasPrefix:@"gql"]||[host hasPrefix:@"oauth"]);
}
static NSURLSessionDataTask *hookDataTask(id self_,SEL _cmd,NSURLRequest *request,MYBRedditHandler handler){
 if(!handler||!MYBRedditHost(request.URL))return ((NSURLSessionDataTask *(*)(id,SEL,id,id))origDataTask)(self_,_cmd,request,handler);
 MYBRedditHandler wrapped=^(NSData *data,NSURLResponse *response,NSError *error){
  if(error){handler(data,response,error);return;}
  handler(MYBRedditFilterResponse(data),response,error);
 };
 return ((NSURLSessionDataTask *(*)(id,SEL,id,id))origDataTask)(self_,_cmd,request,wrapped);
}
NSUInteger MYBRedditInstallHooks(NSUInteger *attempted){
 if(attempted)*attempted=1;
 return MYBAdsHook(NSURLSession.class,@selector(dataTaskWithRequest:completionHandler:),NO,(IMP)hookDataTask,&origDataTask)?1:0;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_reddit(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"reddit"))return;
  MYBAdsReportLoaded(@"reddit",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBRedditInstallHooks(&attempted);MYBAdsLogResult("reddit",ok,attempted);MYBAdsReportHooks(@"reddit",ok,attempted,0);
 }
}
#endif
