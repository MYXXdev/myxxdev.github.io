#pragma once
// Hands the private list to the call service. The call service may not read the preference file and its preference cache is stale after a direct file write,
// so whoever changes or loads the list (Settings, Phone, SpringBoard) publishes it into a system notification mailbox the call service reads fresh on every
// incoming call. Content: the switch, then every number on the list (key and action). Publishing the same content again changes nothing.
#import <Foundation/Foundation.h>
#import "MYBPrivateCallsStore.h"
#import "MYBCallServiceChannel.h"
static inline void MYBCSLPublish(NSString *file){
 @autoreleasepool{
  if(!file.length)return;
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:file];
  if(![prefs isKindOfClass:NSDictionary.class]){
   if([NSFileManager.defaultManager fileExistsAtPath:file])return;   // exists but cannot be read here: publish nothing rather than an empty list
   prefs=@{};
  }
  id sw=prefs[MYB_PC_KEY_SWITCH];
  NSMutableString *text=[NSMutableString stringWithFormat:@"sw=%d\n",([sw isKindOfClass:NSNumber.class]&&[sw boolValue])?1:0];
  for(NSDictionary *e in MYBPCEffective(MYBPCStoreLog(file),nil)){
   NSString *k=e[@"k"],*a=e[@"a"];
   if([k isKindOfClass:NSString.class]&&k.length)[text appendFormat:@"%@\t%@\n",k,[a isKindOfClass:NSString.class]&&a.length?a:MYB_PC_ACTION_MUTE];
  }
  MYBCSCPublishIn(MYB_CSL_NAME,text);
  id old=CFBridgingRelease(CFPreferencesCopyValue(MYB_CSL_LIVE_KEY,MYB_CSL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
  if(![old isEqual:text]){
   CFPreferencesSetValue(MYB_CSL_LIVE_KEY,(__bridge CFPropertyListRef)text,MYB_CSL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
   CFPreferencesSynchronize(MYB_CSL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
  }
 }
}
