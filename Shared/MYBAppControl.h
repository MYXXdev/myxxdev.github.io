#pragma once
#import <Foundation/Foundation.h>
#import "MYBAccelerationPolicy.h"
static inline BOOL MYBAppControlSelected(NSDictionary *prefs,NSString *app){
 return MYBAppControlServiceEnabled(prefs)&&app.length&&![app hasPrefix:@"__"]&&![app isEqual:@"com.apple.springboard"]&&![app isEqual:@"com.apple.Preferences"]&&[prefs[[@"enabled-" stringByAppendingString:app]] boolValue];
}
static inline BOOL MYBAppControlBypassed(NSDictionary *session){return [session[@"active"] boolValue]&&![session[@"manualOverride"] boolValue];}
static inline NSDictionary *MYBAppControlPlan(NSDictionary *prefs,NSDictionary *previous,BOOL enabled,NSString *mode,NSString *app,NSDate *now){
 BOOL selected=MYBAppControlSelected(prefs,app),active=[previous[@"active"] boolValue];
 if(!selected)return @{@"action":active?@"restore":@"none",@"session":previous?:@{}};
 NSMutableDictionary *next=active?[previous mutableCopy]:[@{@"active":@YES,@"previousEnabled":@(enabled),@"previousMode":mode?:@"Default"} mutableCopy];
 next[@"app"]=app;next[@"lastSeen"]=now;
 return @{@"action":[next[@"manualOverride"] boolValue]?@"hold":@"bypass",@"session":next};
}
static inline BOOL MYBAppControlExpired(NSDictionary *session,NSDate *now){
 if(![session[@"active"] boolValue])return NO;NSDate *last=session[@"lastSeen"];
 return ![last isKindOfClass:NSDate.class]||[now timeIntervalSinceDate:last]>45||[now timeIntervalSinceDate:last]<0;
}
