#pragma once
// App Switch Control history: what it did for the person, in plain events. This is NOT the raw foreground trace (that stays in
// Status & Diagnostics for support). A foreground change that did not pause or resume blocking is never recorded here.
//   paused        blocking was paused for the whole phone because a selected app came to the front
//   resumed       blocking was switched back on after that app was left (or the phone was locked)
//   failed        MYbloXX® couldn't pause blocking for the app
//   resume-failed MYbloXX® couldn't switch blocking back on
// Local, capped at 40 events, app identifier and time only. Never part of backups or reports.
#import <Foundation/Foundation.h>
#import "MYBShield.h"
#define MYB_APPSWITCH_MAX 40
static inline NSString *MYBAppSwitchFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/AppSwitchActivity.plist");}
static inline BOOL MYBAppSwitchKindValid(NSString *kind){return [@[@"paused",@"resumed",@"failed",@"resume-failed"] containsObject:kind];}
static inline void MYBAppSwitchRecord(NSString *path,NSString *kind,NSString *bundle,NSString *name){
 if(!MYBAppSwitchKindValid(kind)||!MYBShieldBundleValid(bundle))return;
 NSString *label=[name isKindOfClass:NSString.class]&&name.length&&name.length<=60?name:@"";
 int lock=MYBShieldLock(path);if(lock<0)return;
 NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:path];NSMutableArray *items=[([root[@"items"] isKindOfClass:NSArray.class]?root[@"items"]:@[]) mutableCopy];
 [items insertObject:@{@"kind":kind,@"app":bundle,@"name":label,@"time":@(MYBShieldWall())} atIndex:0];
 while(items.count>MYB_APPSWITCH_MAX)[items removeLastObject];
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"version":@1,@"items":items} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
 if(data&&[data writeToFile:path atomically:YES])MYBShieldHandOver(path,0644);
 MYBShieldUnlock(lock);
}
static inline NSArray *MYBAppSwitchEvents(NSString *path){NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:path];return [root[@"items"] isKindOfClass:NSArray.class]?root[@"items"]:@[];}
static inline BOOL MYBAppSwitchClear(NSString *path){int lock=MYBShieldLock(path);if(lock<0)return NO;[NSFileManager.defaultManager removeItemAtPath:path error:NULL];MYBShieldUnlock(lock);return YES;}
static inline NSString *MYBAppSwitchTitle(NSString *kind){
 return [kind isEqual:@"paused"]?@"Paused blocking":[kind isEqual:@"resumed"]?@"Resumed blocking":[kind isEqual:@"failed"]?@"Couldn’t pause blocking":[kind isEqual:@"resume-failed"]?@"Couldn’t resume blocking":@"App Switch Control";
}
