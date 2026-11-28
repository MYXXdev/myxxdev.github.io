#pragma once
#import <Foundation/Foundation.h>
// What Settings may say about Ad Network Blocking for one app. A report from the library is an observation of ONE process launch; it describes the
// present only if that launch started after the choice last changed and ran this exact library version. Otherwise it is history and says nothing
// about protection now.
//   MYBSDKOff              switched off, and no earlier launch is on record
//   MYBSDKOffStillLoaded   switched off, but a launch that loaded the library is on record: if the app is still open, close it to unload it
//   MYBSDKRestartNeeded    switched on, but no launch since the change (or since the library was upgraded) has reported: reopen the app
//   MYBSDKLoadedNoSDK      loaded for the current choice; no compatible ad SDK interface was found in the app
//   MYBSDKHooksInstalled   loaded for the current choice; entry points are hooked; no ad load has been answered yet
//   MYBSDKBlocking         loaded for the current choice; ad loads have been answered "no ad" (count in the report)
//   MYBSDKUnknown          the service could not be asked, so nothing is claimed
typedef NS_ENUM(NSInteger,MYBSDKState){MYBSDKOff=0,MYBSDKOffStillLoaded,MYBSDKRestartNeeded,MYBSDKLoadedNoSDK,MYBSDKHooksInstalled,MYBSDKBlocking,MYBSDKUnknown};
#define MYB_ADSDK_CHANGED_PREFIX @"ads-sdkat-" // + bundle id: wall time of the last change of this app's choice (a different prefix from "ads-sdk-": never read as a choice)
static inline double MYBAdSDKChangedAt(NSDictionary *prefs,NSString *bundle){
 id v=[prefs isKindOfClass:NSDictionary.class]&&[bundle isKindOfClass:NSString.class]?prefs[[MYB_ADSDK_CHANGED_PREFIX stringByAppendingString:bundle]]:nil;
 return [v isKindOfClass:NSNumber.class]?[v doubleValue]:0;
}
// report: the record the service holds for this app (nil when none); reachable: whether the service answered at all.
static inline MYBSDKState MYBAdSDKStatus(BOOL selected,double changedAt,NSDictionary *report,BOOL reachable,NSString *currentVersion){
 if(!reachable)return MYBSDKUnknown;
 BOOL current=[report isKindOfClass:NSDictionary.class]&&[report[@"launch"] length]&&[report[@"readAt"] doubleValue]>=changedAt&&[report[@"ver"] isEqual:currentVersion];
 if(!selected)return report?MYBSDKOffStillLoaded:MYBSDKOff;
 if(!current)return MYBSDKRestartNeeded;
 if([report[@"blocked"] longLongValue]>0)return MYBSDKBlocking;
 return [report[@"installed"] longLongValue]>0?MYBSDKHooksInstalled:MYBSDKLoadedNoSDK;
}
static inline NSString *MYBAdSDKStatusText(MYBSDKState s,NSDictionary *report){
 switch(s){
  case MYBSDKOff:return @"Off";
  case MYBSDKOffStillLoaded:return @"Off. If the app is still open, close it to unload the library";
  case MYBSDKRestartNeeded:return @"On. Close and reopen the app to apply";
  case MYBSDKLoadedNoSDK:return @"Loaded for your current choice. No compatible ad SDK found in the app";
  case MYBSDKHooksInstalled:return [NSString stringWithFormat:@"Loaded for your current choice. %@ ad entry points hooked, no ad load blocked yet",report[@"installed"]];
  case MYBSDKBlocking:return [NSString stringWithFormat:@"Active. %@ ad entry points hooked, %@ ad loads answered no ad",report[@"installed"],report[@"blocked"]];
  case MYBSDKUnknown:return @"On. The service is not reachable, so loading cannot be checked";
 }
 return @"";
}
