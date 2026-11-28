#pragma once
#import <Foundation/Foundation.h>
static inline BOOL MYBStorageAllowed(NSString *path){
 if(![path isKindOfClass:NSString.class]||![path isEqual:path.stringByStandardizingPath])return NO;
 for(NSString *root in @[@"/var/mobile/Library/MYbloXX",@"/var/mobile/Library/Preferences",@"/var/containers"])
  if([path isEqual:root]||[path hasPrefix:[root stringByAppendingString:@"/"]])return YES;
 return NO;
}
#define MYBUpdateMinimumInterval (23*3600)
static inline BOOL MYBUpdateDue(NSDictionary *state,NSDate *now){
 if(![state[@"automatic"] boolValue])return NO;NSDate *last=state[@"lastAutomaticAttempt"];
 if(![last isKindOfClass:NSDate.class])return YES;
 // launchd fires StartInterval 86400 about 86400 s after the PREVIOUS START, while lastAutomaticAttempt is written a moment after that start; an exact 24 h test would skip every other day. 23 h absorbs the jitter and still means at most one check per day.
 NSTimeInterval elapsed=[now timeIntervalSinceDate:last];return elapsed<0||elapsed>=MYBUpdateMinimumInterval;
}
static inline BOOL MYBSaveUpdateState(NSString *root,NSDictionary *state,NSError **error){
 if(!root.length)return NO;
 NSFileManager *fm=NSFileManager.defaultManager;
 if(![fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:error])return NO;
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:state format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
 return data&&[data writeToFile:[root stringByAppendingPathComponent:@"Updates.plist"] options:NSDataWritingAtomic error:error];
}

