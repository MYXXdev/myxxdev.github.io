#pragma once
// MYbloXX® Message Firewall: THE store. Its own file (never touches the Call Firewall's or Private Calls'), same locked read-merge-write-verify
// cycle they already use (MYBPCLockTake/MYBPCLockGive/MYBPCMerge, all reused as-is since a record here is the exact same {k,d,t,on} shape minus the
// action field neither function actually requires). Two independent lists -- senders and keywords -- in one file, so changing one can never tear
// the file in a way that loses the other, and a switch change is written through the very same lock.
#import <Foundation/Foundation.h>
#import "MYBMessageFirewallRules.h"
#import "MYBMessageFirewallPatterns.h"
#import "MYBPrivateCallsStore.h"

// Which of the three bundled scam-pattern categories (Shared/MYBMessageFirewallPatterns.h) are active. Junk (real scams) defaults on; promotion and
// transaction default off, since neither is actually a scam and deleting one by mistake costs a wanted message, not an unwanted one.
#define MYB_MF_KEY_PATTERNS_JUNK @"MessageFirewallPatternsJunk"
#define MYB_MF_KEY_PATTERNS_PROMOTION @"MessageFirewallPatternsPromotion"
#define MYB_MF_KEY_PATTERNS_TRANSACTION @"MessageFirewallPatternsTransaction"

static inline NSDictionary *MYBMFRead(NSString *file){return MYBPCStoreRead(file);}
static inline NSArray *MYBMFLog(NSString *file,NSString *listKey){id log=[MYBMFRead(file) objectForKey:listKey];return [log isKindOfClass:NSArray.class]?log:[NSArray array];}
static inline NSArray *MYBMFEffective(NSString *file,NSString *listKey){return MYBPCEffective(MYBMFLog(file,listKey),nil);}
static inline BOOL MYBMFSwitchOn(NSString *file){return [[MYBMFRead(file) objectForKey:MYB_MF_KEY_SWITCH] boolValue];}

// Locked read-merge-write-verify for one of the two lists, parameterized by which array key is being changed, so a sender change and a keyword
// change can never race or clobber one another -- the same lock Private Calls and the Call Firewall already use.
static inline BOOL MYBMFMutate(NSString *file,NSString *listKey,NSArray *incoming){
 if(!file.length||!listKey.length)return NO;
 int fd=MYBPCLockTake(file);
 BOOL ok=NO;
 @try{
  NSDictionary *current=MYBMFRead(file);
  NSArray *merged=MYBPCMerge([current objectForKey:listKey],incoming);
  NSMutableDictionary *next=[NSMutableDictionary dictionaryWithDictionary:current];
  [next setObject:merged forKey:listKey];
  if([next writeToFile:file atomically:YES]){
   if(geteuid()==0)chown(file.fileSystemRepresentation,501,501);
   chmod(file.fileSystemRepresentation,0644);
   ok=YES;
  }
 }@catch(NSException *e){(void)e;ok=NO;}
 MYBPCLockGive(fd);
 return ok;
}
static inline BOOL MYBMFSwitchWrite(NSString *file,BOOL on){
 if(!file.length)return NO;
 int fd=MYBPCLockTake(file);
 BOOL ok=NO;
 @try{
  NSMutableDictionary *next=[NSMutableDictionary dictionaryWithDictionary:MYBMFRead(file)];
  [next setObject:[NSNumber numberWithBool:on] forKey:MYB_MF_KEY_SWITCH];
  if([next writeToFile:file atomically:YES]){
   if(geteuid()==0)chown(file.fileSystemRepresentation,501,501);
   chmod(file.fileSystemRepresentation,0644);
   ok=YES;
  }
 }@catch(NSException *e){(void)e;ok=NO;}
 MYBPCLockGive(fd);
 return ok;
}
static inline BOOL MYBMFSetSender(NSString *file,NSString *key,NSString *display,BOOL on,double now){
 if(!key.length)return NO;
 return MYBMFMutate(file,MYB_MF_KEY_SENDERS,[NSArray arrayWithObject:MYBMFRecord(key,display,on,now)]);
}
static inline BOOL MYBMFSetKeyword(NSString *file,NSString *key,NSString *display,BOOL on,double now){
 if(!key.length)return NO;
 return MYBMFMutate(file,MYB_MF_KEY_KEYWORDS,[NSArray arrayWithObject:MYBMFRecord(key,display,on,now)]);
}
static inline BOOL MYBMFPatternCategoryOn(NSString *file,NSString *key,BOOL defaultValue){
 id v=[MYBMFRead(file) objectForKey:key];
 return [v isKindOfClass:NSNumber.class]?[v boolValue]:defaultValue;
}
static inline BOOL MYBMFPatternCategoryWrite(NSString *file,NSString *key,BOOL on){
 if(!file.length)return NO;
 int fd=MYBPCLockTake(file);
 BOOL ok=NO;
 @try{
  NSMutableDictionary *next=[NSMutableDictionary dictionaryWithDictionary:MYBMFRead(file)];
  [next setObject:[NSNumber numberWithBool:on] forKey:key];
  if([next writeToFile:file atomically:YES]){
   if(geteuid()==0)chown(file.fileSystemRepresentation,501,501);
   chmod(file.fileSystemRepresentation,0644);
   ok=YES;
  }
 }@catch(NSException *e){(void)e;ok=NO;}
 MYBPCLockGive(fd);
 return ok;
}
// The categories currently active, as the string labels MYBMFCompiledPatternsMatch expects -- junk defaults on, the other two default off.
static inline NSArray *MYBMFEnabledPatternCategories(NSString *file){
 NSMutableArray *cats=[NSMutableArray array];
 if(MYBMFPatternCategoryOn(file,MYB_MF_KEY_PATTERNS_JUNK,YES))[cats addObject:MYB_MF_PATTERN_JUNK];
 if(MYBMFPatternCategoryOn(file,MYB_MF_KEY_PATTERNS_PROMOTION,NO))[cats addObject:MYB_MF_PATTERN_PROMOTION];
 if(MYBMFPatternCategoryOn(file,MYB_MF_KEY_PATTERNS_TRANSACTION,NO))[cats addObject:MYB_MF_PATTERN_TRANSACTION];
 return cats;
}
