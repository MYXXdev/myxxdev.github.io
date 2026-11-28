#pragma once
// MYbloXX® Private Calls: THE store. One list of records, in the privacy preference file (PrivateCallsLog). Settings, Phone and the incoming-call
// component all read that file. It is changed in exactly one way: MYBPCStoreMutate (lock, read, merge, atomic write, read back, verify).
//   - Settings and the root helper call it directly.
//   - Phone calls it directly when its sandbox allows. When it does not, Phone puts the request in its own preferences (the only place it may write)
//     and tells the root helper, which applies it through the same function. Phone shows success only after reading the record back from the store.
// A reset leaves a small stamp (time only). A request or an old r18 record that is older than the stamp is dropped, so nothing comes back.
// Plain Foundation + POSIX, so the desktop tests run this exact code on temporary files.
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <math.h>
#include "MYBPrivateCalls.h"

static inline NSDictionary *MYBPCStoreRead(NSString *file){
 NSDictionary *d=file.length?[NSDictionary dictionaryWithContentsOfFile:file]:nil;
 return [d isKindOfClass:NSDictionary.class]?d:[NSDictionary dictionary];
}
static inline NSArray *MYBPCStoreLog(NSString *file){
 id log=[MYBPCStoreRead(file) objectForKey:MYB_PC_KEY_LOG];
 return [log isKindOfClass:NSArray.class]?log:[NSArray array];
}
static inline double MYBPCResetStamp(NSString *stampFile){
 NSDictionary *d=stampFile.length?[NSDictionary dictionaryWithContentsOfFile:stampFile]:nil;
 id at=[d isKindOfClass:NSDictionary.class]?[d objectForKey:@"at"]:nil;
 return [at isKindOfClass:NSNumber.class]?[at doubleValue]:0;
}
// Records newer than the reset stamp only.
static inline NSArray *MYBPCAfterReset(NSArray *records,double stamp){
 NSMutableArray *out=[NSMutableArray array];
 if(![records isKindOfClass:NSArray.class])return out;
 for(id r in records)if(MYBPCRecordValid(r)&&[[r objectForKey:@"t"] doubleValue]>stamp)[out addObject:r];
 return out;
}
static inline BOOL MYBPCSameRecord(NSDictionary *a,NSDictionary *b){
 return a&&b&&fabs([[a objectForKey:@"t"] doubleValue]-[[b objectForKey:@"t"] doubleValue])<0.001&&[[a objectForKey:@"on"] isEqual:[b objectForKey:@"on"]]&&[MYBPCNormalizeAction([a objectForKey:@"a"]) isEqual:MYBPCNormalizeAction([b objectForKey:@"a"])];
}
static inline NSDictionary *MYBPCRecordForKey(NSArray *log,NSString *key){
 for(id r in log)if(MYBPCRecordValid(r)&&[[r objectForKey:@"k"] isEqual:key])return r;
 return nil;
}
// Every record of "wanted" is now covered by the store: the store holds that record or a newer one for the key.
static inline BOOL MYBPCStoreCovers(NSArray *storeLog,NSArray *wanted){
 for(id w in wanted){
  if(!MYBPCRecordValid(w))continue;
  NSDictionary *h=MYBPCRecordForKey(storeLog,[w objectForKey:@"k"]);
  if(!h||[[h objectForKey:@"t"] doubleValue]<[[w objectForKey:@"t"] doubleValue])return NO;
 }
 return YES;
}
// Merge "incoming" records into the store. Returns YES only when the file was written and the read-back shows the merged result.
// version: also mark the store as migrated (2). Never throws away a number: the merged list is built from what is in the file right now.
static inline int MYBPCLockTake(NSString *file){
 int fd=open([file stringByAppendingString:@".lock"].fileSystemRepresentation,O_CREAT|O_RDWR,0666);   // best effort: a process that cannot open it still writes atomically
 if(fd>=0){fchmod(fd,0666);flock(fd,LOCK_EX);}
 return fd;
}
static inline void MYBPCLockGive(int fd){if(fd>=0){flock(fd,LOCK_UN);close(fd);}}
// turnSwitchOn: Private Calls has no Settings page of its own (it only turns on from inside Phone), so the moment a number is actually made private,
// the master switch is turned on in the very same locked write. Without this a number could sit in the list while nothing was ever matching calls
// against it.
static inline BOOL MYBPCStoreMutateEx(NSString *file,NSArray *incoming,BOOL markMigrated,BOOL turnSwitchOn){
 if(!file.length)return NO;
 int fd=MYBPCLockTake(file);
 BOOL ok=NO;
 @try{
  NSDictionary *current=MYBPCStoreRead(file);
  NSArray *merged=MYBPCMerge([current objectForKey:MYB_PC_KEY_LOG],incoming);
  NSMutableDictionary *next=[NSMutableDictionary dictionaryWithDictionary:current];
  [next setObject:merged forKey:MYB_PC_KEY_LOG];
  if(markMigrated)[next setObject:[NSNumber numberWithInt:2] forKey:MYB_PC_KEY_VERSION];
  if(turnSwitchOn)[next setObject:[NSNumber numberWithBool:YES] forKey:MYB_PC_KEY_SWITCH];
  if([next writeToFile:file atomically:YES]){
   if(geteuid()==0){chown(file.fileSystemRepresentation,501,501);}
   chmod(file.fileSystemRepresentation,0644);
   NSArray *back=MYBPCStoreLog(file);
   ok=[back count]==[merged count];
   for(NSDictionary *m in merged)if(ok&&!MYBPCSameRecord(MYBPCRecordForKey(back,[m objectForKey:@"k"]),m))ok=NO;
   if(ok&&markMigrated)ok=[[MYBPCStoreRead(file) objectForKey:MYB_PC_KEY_VERSION] intValue]==2;
   if(ok&&turnSwitchOn)ok=[[MYBPCStoreRead(file) objectForKey:MYB_PC_KEY_SWITCH] boolValue];
  }
 }@catch(NSException *e){ok=NO;}
 MYBPCLockGive(fd);
 return ok;
}
static inline BOOL MYBPCStoreMutate(NSString *file,NSArray *incoming,BOOL markMigrated){
 return MYBPCStoreMutateEx(file,incoming,markMigrated,NO);
}
// Add, change or remove one number. YES only when the store itself shows it afterwards. Turning an entry on also turns the master switch on, since
// Private Calls has no Settings switch of its own any more: making a number private is the only thing that enables the feature.
static inline BOOL MYBPCStoreSet(NSString *file,NSString *key,NSString *display,NSString *action,BOOL on,double now,NSDictionary **recordOut){
 if(!key.length)return NO;
 NSDictionary *rec=MYBPCRecord(key,display,action,on,now);
 if(recordOut)*recordOut=rec;
 if(!MYBPCStoreMutateEx(file,[NSArray arrayWithObject:rec],NO,on))return NO;
 NSDictionary *back=MYBPCRecordForKey(MYBPCStoreLog(file),key);
 return back&&[[back objectForKey:@"on"] boolValue]==on&&[[back objectForKey:@"t"] doubleValue]>=now-0.001;
}
// Root helper / Settings: bring in Phone's pending requests and the r18 Phone list. Safe to repeat: merging the same records again changes nothing.
// "queue" and "oldLog" come from Phone's preferences; both are filtered by the reset stamp. Returns the number of records offered (0 = nothing to do).
static inline int MYBPCApplyPending(NSString *file,NSString *stampFile,NSArray *queue,NSArray *oldLog,BOOL *failed){
 double stamp=MYBPCResetStamp(stampFile);
 NSMutableArray *offer=[NSMutableArray array];
 [offer addObjectsFromArray:MYBPCAfterReset(queue,stamp)];
 [offer addObjectsFromArray:MYBPCAfterReset(oldLog,stamp)];
 BOOL migrated=[[MYBPCStoreRead(file) objectForKey:MYB_PC_KEY_VERSION] intValue]>=2;
 if(!offer.count&&migrated)return 0;
 if(offer.count&&MYBPCStoreCovers(MYBPCStoreLog(file),offer)&&migrated)return 0;
 BOOL ok=MYBPCStoreMutate(file,offer,YES);
 if(failed)*failed=!ok;
 return ok?(int)offer.count:0;
}
// Restore Defaults: the store goes (switch off, no rules) and the stamp records when, so older requests and r18 records cannot return.
static inline BOOL MYBPCResetStore(NSString *file,NSString *stampFile,double now){
 NSDictionary *stamp=[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:now] forKey:@"at"];
 if(stampFile.length&&![stamp writeToFile:stampFile atomically:YES])return NO;
 if(stampFile.length){if(geteuid()==0)chown(stampFile.fileSystemRepresentation,501,501);chmod(stampFile.fileSystemRepresentation,0644);}
 NSMutableDictionary *d=[NSMutableDictionary dictionaryWithDictionary:MYBPCStoreRead(file)];
 [d removeObjectForKey:MYB_PC_KEY_LOG];[d removeObjectForKey:MYB_PC_KEY_VERSION];[d removeObjectForKey:MYB_PC_KEY_SWITCH];
 return [[NSFileManager defaultManager] fileExistsAtPath:file]?([d count]?[d writeToFile:file atomically:YES]:[[NSFileManager defaultManager] removeItemAtPath:file error:NULL]):YES;
}
