#pragma once
// Is a MYbloXX® profile installed on this iPhone, and can it be removed? One answer for every screen, so the status, the Legacy Mode
// page, the supervision message and the welcome screen never disagree. It covers both kinds: the profiles this tweak hands to iOS
// (Legacy Mode) and the original MYbloXX® profiles a person installed by hand before the tweak existed. Both carry the project's
// identifier namespace or its organisation, so recognising them needs no profile contents.
// Only the Settings process may ask iOS for profiles; anywhere else the answer is "unknown" and nothing is guessed.
#import <Foundation/Foundation.h>
#import "MYBProfileService.h"

static inline BOOL MYBProfileIsMYbloXXOrganisation(NSString *org){
 if(![org isKindOfClass:NSString.class])return NO;
 return [[org stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] hasPrefix:@"MYXXdev"];
}
// YES for an identifier that belongs to the project's namespace.
static inline BOOL MYBProfileIdentifierIsMYbloXX(NSString *identifier){return [identifier isKindOfClass:NSString.class]&&[identifier hasPrefix:@"net.myxxdev."];}
// {known: Bool, installed: Bool, identifier: String}. known is NO when iOS would not list profiles to this process.
// The slow part is asking iOS, so MYBInstalledMYbloXXProfile never waits for it: it answers from the last result (or "not known yet") and refreshes in
// the background, then posts MYBProfileStateChanged on the main queue when the answer changed. Settings opens instantly and corrects itself a moment later.
static NSDictionary *gMYBProfileCache;static double gMYBProfileCacheAt;static BOOL gMYBProfileRefreshing;
static inline NSDictionary *MYBInstalledMYbloXXProfileSync(void){
 NSArray *list=MYBServiceList();NSDictionary *result;
 if(!list)result=@{@"known":@NO,@"installed":@NO,@"identifier":@""};
 else{
  NSString *found=nil;
  for(id item in list){
   if(![item isKindOfClass:NSString.class])continue;
   if(MYBProfileIdentifierIsMYbloXX(item)){found=item;break;}
   NSDictionary *d=MYBServiceDescribe(item);
   NSString *name=[d[@"displayName"] isKindOfClass:NSString.class]?d[@"displayName"]:@"";
   if(MYBProfileIsMYbloXXOrganisation(d[@"organization"])||[name.lowercaseString containsString:@"mybloxx"]){found=item;break;}
  }
  result=@{@"known":@YES,@"installed":@(found!=nil),@"identifier":found?:@""};
 }
 return result;
}
#define MYBProfileStateChanged @"MYBProfileStateChanged"
static inline NSDictionary *MYBInstalledMYbloXXProfile(void){
 static NSLock *lock;static dispatch_once_t once;dispatch_once(&once,^{lock=[NSLock new];});
 [lock lock];double now=NSDate.date.timeIntervalSince1970;NSDictionary *hit=gMYBProfileCache;
 BOOL stale=!hit||now-gMYBProfileCacheAt>3||now<gMYBProfileCacheAt;BOOL start=stale&&!gMYBProfileRefreshing;if(start)gMYBProfileRefreshing=YES;
 [lock unlock];
 if(start)dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
  NSDictionary *fresh=MYBInstalledMYbloXXProfileSync();
  [lock lock];BOOL changed=![fresh isEqual:gMYBProfileCache];gMYBProfileCache=fresh;gMYBProfileCacheAt=NSDate.date.timeIntervalSince1970;gMYBProfileRefreshing=NO;[lock unlock];
  if(changed)dispatch_async(dispatch_get_main_queue(),^{[NSNotificationCenter.defaultCenter postNotificationName:MYBProfileStateChanged object:nil];});
 });
 return hit?:@{@"known":@NO,@"installed":@NO,@"identifier":@""};
}
static inline void MYBForgetInstalledMYbloXXProfile(void){gMYBProfileCache=nil;} // the next call reads iOS again
// Removes every MYbloXX® profile, then reads iOS again. Blocks up to ~20 s per profile, so call it off the main queue.
// removed: at least one profile was taken away. gone: nothing MYbloXX® is installed any more.
static inline void MYBRemoveMYbloXXProfiles(BOOL *removed,BOOL *gone){
 BOOL did=NO;
 for(NSString *i in (MYBServiceList()?:@[])){
  if(![i isKindOfClass:NSString.class])continue;
  BOOL ours=MYBProfileIdentifierIsMYbloXX(i);
  if(!ours){NSDictionary *d=MYBServiceDescribe(i);ours=MYBProfileIsMYbloXXOrganisation(d[@"organization"])||[[d[@"displayName"] description].lowercaseString containsString:@"mybloxx"];}
  if(!ours)continue;
  MYBServiceRemove(i);did=YES;
 }
 usleep(400000);
 NSArray *after=MYBServiceList();BOOL clear=YES;
 for(NSString *i in (after?:@[]))if(MYBProfileIdentifierIsMYbloXX(i))clear=NO;
 MYBForgetInstalledMYbloXXProfile();
 if(removed)*removed=did;if(gone)*gone=after!=nil&&clear;
}
