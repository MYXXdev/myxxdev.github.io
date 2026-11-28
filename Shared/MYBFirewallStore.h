#pragma once
// MYbloXX® Call Firewall: THE store. Its own file (FirewallStore.h never touches PrivateCallsLog or vice versa), same locked read-merge-write-verify
// cycle Private Calls uses (MYBPCLockTake/MYBPCLockGive, MYBPCMerge, MYBPCStoreLog -- all reused as-is from MYBPrivateCallsStore.h since a Firewall
// record is the exact same {k,d,a,t,on} shape). Settings (switch, Allow List Mode, default/unknown/international actions, ranges) live in the same
// file alongside the list, written through the same lock so a number and a setting changed together can never be torn apart.
#import <Foundation/Foundation.h>
#import "MYBFirewallRules.h"
#import "MYBPrivateCallsStore.h"

static inline NSDictionary *MYBFWSettingsDefaults(void){
 return [NSDictionary dictionaryWithObjectsAndKeys:
  [NSNumber numberWithBool:NO],MYB_FW_KEY_SWITCH,
  [NSNumber numberWithBool:NO],MYB_FW_KEY_ALLOWLIST,
  MYB_PC_ACTION_DECLINE,MYB_FW_KEY_DEFAULT_ACTION,
  @"",MYB_FW_KEY_UNKNOWN_ACTION,
  [NSNumber numberWithBool:NO],MYB_FW_KEY_INTL_BLOCK,
  MYB_PC_ACTION_DECLINE,MYB_FW_KEY_INTL_ACTION,
  [NSArray array],MYB_FW_KEY_RANGES,
  [NSNumber numberWithBool:NO],MYB_FW_KEY_JUNKCALLERS_ON,
  MYB_PC_ACTION_DECLINE,MYB_FW_KEY_JUNKCALLERS_ACTION,nil];
}
// Every Firewall setting, defaulted so a caller never has to nil-check. The list itself is read separately (MYBPCStoreLog / MYBPCEffective).
static inline NSDictionary *MYBFWSettingsRead(NSString *file){
 NSDictionary *stored=MYBPCStoreRead(file);
 NSMutableDictionary *out=[MYBFWSettingsDefaults() mutableCopy];
 for(NSString *k in out.allKeys){id v=[stored objectForKey:k];if(v)[out setObject:v forKey:k];}
 return out;
}
static inline NSArray *MYBFWEntries(NSString *file){return MYBPCEffective(MYBPCStoreLog(file),nil);}
static inline NSDictionary *MYBFWEntryForKey(NSString *file,NSString *key){return MYBPCEntryForKey(MYBFWEntries(file),key);}

// Changes one or more settings in the same locked write MYBPCStoreMutateEx already uses for the list, so a setting change can never race a number
// being added or removed. Only the keys actually passed are touched; everything else in the file (including the list) is left exactly as it was.
static inline BOOL MYBFWSettingsWrite(NSString *file,NSDictionary *changes){
 if(!file.length||!changes.count)return NO;
 int fd=MYBPCLockTake(file);
 BOOL ok=NO;
 @try{
  NSMutableDictionary *next=[NSMutableDictionary dictionaryWithDictionary:MYBPCStoreRead(file)];
  [next addEntriesFromDictionary:changes];
  if([next writeToFile:file atomically:YES]){
   if(geteuid()==0)chown(file.fileSystemRepresentation,501,501);
   chmod(file.fileSystemRepresentation,0644);
   NSDictionary *back=MYBPCStoreRead(file);
   ok=YES;
   for(NSString *k in changes)if(![[back objectForKey:k] isEqual:[changes objectForKey:k]])ok=NO;
  }
 }@catch(NSException *e){ok=NO;}
 MYBPCLockGive(fd);
 return ok;
}
// Add, change or remove one number. YES only when the store itself shows it afterwards (the same verify-by-readback MYBPCStoreSet uses).
static inline BOOL MYBFWStoreSet(NSString *file,NSString *key,NSString *display,NSString *action,BOOL on,double now){
 if(!key.length)return NO;
 NSDictionary *rec=MYBFWRecord(key,display,action,on,now);
 if(!MYBPCStoreMutateEx(file,[NSArray arrayWithObject:rec],NO,NO))return NO;
 NSDictionary *back=MYBPCRecordForKey(MYBPCStoreLog(file),key);
 return back&&[[back objectForKey:@"on"] boolValue]==on&&[[back objectForKey:@"t"] doubleValue]>=now-0.001;
}
// Replaces the whole range-rule list in one write. Capped the same way the per-number list is, so a long press on "add" cannot grow the file forever.
static inline BOOL MYBFWRangesWrite(NSString *file,NSArray *ranges){
 NSMutableArray *clean=[NSMutableArray array];
 for(id r in ranges){
  NSDictionary *v=[r isKindOfClass:NSDictionary.class]?MYBFWValidRange([r objectForKey:@"prefix"],[r objectForKey:@"a"]):nil;
  if(v)[clean addObject:v];
  if(clean.count>=MYB_FW_MAX_RANGES)break;
 }
 return MYBFWSettingsWrite(file,[NSDictionary dictionaryWithObject:clean forKey:MYB_FW_KEY_RANGES]);
}
