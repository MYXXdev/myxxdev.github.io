#pragma once
// The Firewall's wire format: settings + list packed into one block of text, and parsed back out of it. Plain Foundation only (no CFPreferences, no
// notify.h), so the exact same code that builds and reads the live channel's payload also runs in the desktop tests. MYBFirewallList.h is the thin
// layer on top of this that actually publishes it (the same split MYBPrivateCallsStore.h / MYBCallServiceList.h already use for Private Calls).
#import <Foundation/Foundation.h>
#import "MYBFirewallStore.h"

// One line per setting, then one "range" line per range rule, then one "entry" line per listed number. Parsed back by MYBFWParsePublished below.
static inline NSString *MYBFWPublishedText(NSString *file){
 NSDictionary *settings=MYBFWSettingsRead(file);
 NSMutableString *text=[NSMutableString string];
 [text appendFormat:@"sw=%d\n",[[settings objectForKey:MYB_FW_KEY_SWITCH] boolValue]?1:0];
 [text appendFormat:@"allow=%d\n",[[settings objectForKey:MYB_FW_KEY_ALLOWLIST] boolValue]?1:0];
 [text appendFormat:@"default=%@\n",MYBFWNormalizeAction([settings objectForKey:MYB_FW_KEY_DEFAULT_ACTION])];
 NSString *unk=[settings objectForKey:MYB_FW_KEY_UNKNOWN_ACTION];
 [text appendFormat:@"unknown=%@\n",unk.length?MYBFWNormalizeAction(unk):@""];
 [text appendFormat:@"intl=%d\n",[[settings objectForKey:MYB_FW_KEY_INTL_BLOCK] boolValue]?1:0];
 [text appendFormat:@"intlaction=%@\n",MYBFWNormalizeAction([settings objectForKey:MYB_FW_KEY_INTL_ACTION])];
 [text appendFormat:@"junkcallers=%d\n",[[settings objectForKey:MYB_FW_KEY_JUNKCALLERS_ON] boolValue]?1:0];
 [text appendFormat:@"junkcallersaction=%@\n",MYBFWNormalizeAction([settings objectForKey:MYB_FW_KEY_JUNKCALLERS_ACTION])];
 for(NSDictionary *r in [settings objectForKey:MYB_FW_KEY_RANGES])
  if([r isKindOfClass:NSDictionary.class])[text appendFormat:@"range\t%@\t%@\n",[r objectForKey:@"prefix"],MYBFWNormalizeAction([r objectForKey:@"a"])];
 for(NSDictionary *e in MYBPCEffective(MYBPCStoreLog(file),nil)){
  NSString *k=[e objectForKey:@"k"];
  if([k isKindOfClass:NSString.class]&&k.length)[text appendFormat:@"entry\t%@\t%@\n",k,MYBFWNormalizeAction([e objectForKey:@"a"])];
 }
 return text;
}
// The call service side: settings dict + list of records, from whichever copy of the published text it could read (live domain, then mailbox).
static inline NSDictionary *MYBFWParsePublished(NSString *text,NSArray **entriesOut){
 NSMutableDictionary *settings=[MYBFWSettingsDefaults() mutableCopy];
 [settings setObject:[NSMutableArray array] forKey:MYB_FW_KEY_RANGES];   // defaults hands back an immutable array; replace it before appending ranges into it
 NSMutableArray *entries=[NSMutableArray array];
 for(NSString *line in [text componentsSeparatedByString:@"\n"]){
  if(!line.length)continue;
  if([line hasPrefix:@"sw="])[settings setObject:[NSNumber numberWithBool:[[line substringFromIndex:3] isEqual:@"1"]] forKey:MYB_FW_KEY_SWITCH];
  else if([line hasPrefix:@"allow="])[settings setObject:[NSNumber numberWithBool:[[line substringFromIndex:6] isEqual:@"1"]] forKey:MYB_FW_KEY_ALLOWLIST];
  else if([line hasPrefix:@"default="])[settings setObject:[line substringFromIndex:8] forKey:MYB_FW_KEY_DEFAULT_ACTION];
  else if([line hasPrefix:@"unknown="])[settings setObject:[line substringFromIndex:8] forKey:MYB_FW_KEY_UNKNOWN_ACTION];
  else if([line hasPrefix:@"intl="])[settings setObject:[NSNumber numberWithBool:[[line substringFromIndex:5] isEqual:@"1"]] forKey:MYB_FW_KEY_INTL_BLOCK];
  else if([line hasPrefix:@"intlaction="])[settings setObject:[line substringFromIndex:11] forKey:MYB_FW_KEY_INTL_ACTION];
  else if([line hasPrefix:@"junkcallers="])[settings setObject:[NSNumber numberWithBool:[[line substringFromIndex:12] isEqual:@"1"]] forKey:MYB_FW_KEY_JUNKCALLERS_ON];
  else if([line hasPrefix:@"junkcallersaction="])[settings setObject:[line substringFromIndex:18] forKey:MYB_FW_KEY_JUNKCALLERS_ACTION];
  else if([line hasPrefix:@"range\t"]){
   NSArray *parts=[line componentsSeparatedByString:@"\t"];
   if(parts.count>=3){NSDictionary *v=MYBFWValidRange([parts objectAtIndex:1],[parts objectAtIndex:2]);if(v)[(NSMutableArray *)[settings objectForKey:MYB_FW_KEY_RANGES] addObject:v];}
  }else if([line hasPrefix:@"entry\t"]){
   NSArray *parts=[line componentsSeparatedByString:@"\t"];
   if(parts.count>=3&&[[parts objectAtIndex:1] length])[entries addObject:MYBFWRecord([parts objectAtIndex:1],@"",[parts objectAtIndex:2],YES,0)];
  }
 }
 if(entriesOut)*entriesOut=entries;
 return settings;
}
