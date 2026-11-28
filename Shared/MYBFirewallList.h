#pragma once
// Hands the Firewall's list and settings to the call service, the exact same way MYBCallServiceList.h already does for Private Calls: a system
// notification mailbox (the call service may not read the preference file) plus a live write through the preference service itself (a direct file
// write leaves callservicesd's own cached copy stale until a userspace reboot; writing through CFPreferences does not). Its own domain and mailbox
// name, so the two features' live channels can never collide or overwrite one another. The actual text format lives in MYBFirewallWire.h, which has
// no CFPreferences or notify.h dependency and so is what the desktop tests exercise directly.
#import <Foundation/Foundation.h>
#import "MYBFirewallWire.h"
#import "MYBCallServiceChannel.h"
#define MYB_FWL_NAME @"net.myxxdev.mybloxx.fwl.%u"
#define MYB_FWL_NEED "net.myxxdev.mybloxx.fwl.need"
#define MYB_FWL_LIVE_DOMAIN CFSTR("net.myxxdev.mybloxx.firewall.live")
#define MYB_FWL_LIVE_KEY CFSTR("List")

static inline void MYBFWLPublish(NSString *file){
 @autoreleasepool{
  if(!file.length)return;
  if(![NSFileManager.defaultManager fileExistsAtPath:file]){
   NSDictionary *empty=MYBFWSettingsDefaults();
   if(![empty writeToFile:file atomically:YES])return;
  }
  NSString *text=MYBFWPublishedText(file);
  MYBCSCPublishIn(MYB_FWL_NAME,text);
  id old=CFBridgingRelease(CFPreferencesCopyValue(MYB_FWL_LIVE_KEY,MYB_FWL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
  if(![old isEqual:text]){
   CFPreferencesSetValue(MYB_FWL_LIVE_KEY,(__bridge CFPropertyListRef)text,MYB_FWL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
   CFPreferencesSynchronize(MYB_FWL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
  }
 }
}
static inline NSString *MYBFWLReadPublished(void){
 id live=CFBridgingRelease(CFPreferencesCopyValue(MYB_FWL_LIVE_KEY,MYB_FWL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
 if([live isKindOfClass:NSString.class]&&[(NSString *)live length])return live;
 return MYBCSCReadFrom(MYB_FWL_NAME);
}
