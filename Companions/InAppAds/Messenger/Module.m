// MYbloXX In-App Ad Blocking: Messenger. Ads only.
// PROVENANCE: written against interface evidence (FlowReconstructed's published MSGThreadListDataSource inboxRows hook and the
// ads_renderer unit key) and, for the advertisement story bucket, SNMessenger's published story-viewer hook (MIT, copyright
// (c) 2023 - 2025 NguyenASang). No source text is used, but the decisions follow them; see NOTICE.md in usr/share/doc/mybloxx-inappads.
// Removes the advertising rows Messenger itself places in the chat list (an inbox row whose unit key is "ads_renderer").
// Chats, Stories, Notes, People You May Know and everything else in the list are left alone. If the list data source or its methods
// are not present in a given Messenger version, that hook stays off and the app is untouched.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

static IMP origInboxRows,origStories;
static BOOL MYBMessengerRowIsAd(id row){
 Class unitClass=objc_getClass("MSGInboxRowUnit");if(!unitClass||![row isKindOfClass:unitClass])return NO;
 SEL unitSel=sel_registerName("inboxUnit"),keySel=sel_registerName("key");
 if(![row respondsToSelector:unitSel])return NO;
 id unit=((id(*)(id,SEL))objc_msgSend)(row,unitSel);if(!unit||![unit respondsToSelector:keySel])return NO;
 id key=((id(*)(id,SEL))objc_msgSend)(unit,keySel);return [key isKindOfClass:NSString.class]&&[key isEqual:@"ads_renderer"];
}
static NSArray *hookInboxRows(id self_,SEL _cmd){
 NSArray *rows=((NSArray *(*)(id,SEL))origInboxRows)(self_,_cmd);
 NSArray *kept=MYBAdsFilter(rows,^BOOL(id row){return MYBMessengerRowIsAd(row);});
 if(kept!=rows)MYBAdsNoteDecisions(@"messenger",@"feed",rows.count-kept.count);
 return kept;
}
// Story viewer: a bucket whose type is 1 is an advertisement (0 unread, 2 read). Only those are dropped; the list is edited in place as the
// app passes it. The added index paths are kept consistent with the shorter list: the path of a removed ad is dropped and every later
// path moves up by the number of ads removed before it, so real stories added in the same update are still announced. A path that is not a
// two-part item path cannot be adjusted; then none are passed and the viewer reloads instead.
static BOOL MYBMessengerBucketIsAd(id bucket){
 SEL type=sel_registerName("bucketType");
 if(!bucket||![bucket respondsToSelector:type])return NO;
 return ((long long(*)(id,SEL))objc_msgSend)(bucket,type)==1;
}
NSArray *MYBMessengerAdjustedPaths(NSArray *added,NSIndexSet *removed){
 if(!added.count||!removed.count)return added;
 NSMutableArray *out=[NSMutableArray array];
 for(id path in added){
  if(![path isKindOfClass:NSIndexPath.class]||[(NSIndexPath *)path length]!=2)return @[];
  NSUInteger section=[(NSIndexPath *)path indexAtPosition:0],item=[(NSIndexPath *)path indexAtPosition:1];
  if([removed containsIndex:item])continue;
  NSUInteger before=[removed countOfIndexesInRange:NSMakeRange(0,item)];
  NSUInteger parts[2]={section,item-before};[out addObject:[NSIndexPath indexPathWithIndexes:parts length:2]];
 }
 return out;
}
static void hookStories(id self_,SEL _cmd,NSMutableArray *models,id deleted,NSArray *added,id newIndexPath){
 if([models isKindOfClass:NSMutableArray.class]){
  NSIndexSet *ads=[models indexesOfObjectsPassingTest:^BOOL(id model,NSUInteger i,BOOL *stop){return MYBMessengerBucketIsAd(model);}];
  if(ads.count){[models removeObjectsAtIndexes:ads];added=MYBMessengerAdjustedPaths(added,ads);MYBAdsNoteDecisions(@"messenger",@"story",ads.count);}
 }
 ((void(*)(id,SEL,id,id,id,id))origStories)(self_,_cmd,models,deleted,added,newIndexPath);
}
NSUInteger MYBMessengerInstallHooks(NSUInteger *attempted){
 struct H{const char *cls,*sel;IMP imp;IMP *orig;} table[]={
  {"MSGThreadListDataSource","inboxRows",(IMP)hookInboxRows,&origInboxRows},
  {"LSStoryViewerContentController","_updateStoriesWithBucketStoryModels:deletedIndexPaths:addedIndexPaths:newIndexPath:",(IMP)hookStories,&origStories}};
 NSUInteger count=sizeof(table)/sizeof(table[0]),ok=0;
 for(NSUInteger i=0;i<count;i++)if(MYBAdsHookNamed(table[i].cls,table[i].sel,NO,table[i].imp,table[i].orig))ok++;
 if(attempted)*attempted=count;return ok;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_messenger(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"messenger"))return;
  MYBAdsReportLoaded(@"messenger",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBMessengerInstallHooks(&attempted);MYBAdsLogResult("messenger",ok,attempted);MYBAdsReportHooks(@"messenger",ok,attempted,0);
 }
}
#endif
