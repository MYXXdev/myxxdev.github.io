#pragma once
// Limits automatic runtime recovery (re-creating the inline-PAC target and restarting configd).
// Every attempt counts, successful or not: if something keeps deleting the target, recoveries stop after
// `limit` attempts per window instead of restarting configd forever. The window is bound to this boot and to
// both clocks (see MYBClock.h), so changing the system clock cannot extend it.
#import "MYBClock.h"
static inline BOOL MYBRecoveryTake(NSString *path,int limit,double window,int *attemptsOut){
 NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:path];NSMutableDictionary *record=[saved mutableCopy];
 if(!record||!MYBClockLive(record)){record=[NSMutableDictionary dictionary];record[@"count"]=@0;MYBClockStamp(record,window);}
 int count=[record[@"count"] intValue];if(attemptsOut)*attemptsOut=count;
 if(count>=limit)return NO;
 record[@"count"]=@(count+1);if(attemptsOut)*attemptsOut=count+1;
 [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 return [record writeToFile:path atomically:YES];
}
