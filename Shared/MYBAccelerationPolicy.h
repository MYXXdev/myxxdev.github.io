#pragma once
#import <Foundation/Foundation.h>
static const double MYBAccelerationMultiplier=100.0;
// Persist only app choices. Legacy master switches and tuning keys no longer
// control the engine. The internal removal gate is not a user preference.
static inline BOOL MYBAppControlServiceEnabled(NSDictionary *prefs){return ![prefs[@"Uninstalling"] boolValue];}
static inline NSDictionary *MYBAppControlChoices(NSDictionary *prefs){
 NSMutableDictionary *choices=[NSMutableDictionary dictionary];
 for(NSString *key in prefs)if([key isKindOfClass:NSString.class]&&[key hasPrefix:@"enabled-"]&&[key length]>8&&[prefs[key] respondsToSelector:@selector(boolValue)])choices[key]=@([prefs[key] boolValue]);
 return choices;
}
