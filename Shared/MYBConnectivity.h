#pragma once
// Advanced > Connectivity and Extra Privacy Protection: one small preference file each, every switch OFF unless it was turned on.
//   connectivity.plist   PerAppNetworkMenu   shows the stock per-app "Off / WLAN / WLAN & Cellular Data" controls in Settings
//                        KeepHotspotActive   while Personal Hotspot has a connected device, holds a network-activity power assertion
//   privacy.plist        RecentlyDeletedPrivacy  the 3-second hold on Recently Deleted in Photos
//                        PrivateAlbum            five taps on Albums opens the Private Album
//                        PrivateConversations    five taps on the Messages title opens the private list (Messages only)
//                        PrivateConversationsLock  ask for Face ID / passcode first. ...RestoreRequest: a number Settings changes to ask Messages to restore alerts
// A missing file, a missing key or a value that is not a number all mean OFF. Nothing here deletes or changes any Photos data or any
// restriction the system stored: the switches only decide whether the hooks act.
#import <Foundation/Foundation.h>
#import "MYBWebsiteRules.h"
#define MYB_CONN_KEY_NETWORK_MENU @"PerAppNetworkMenu"
#define MYB_CONN_KEY_HOTSPOT @"KeepHotspotActive"
#define MYB_PRIV_KEY_DELETED @"RecentlyDeletedPrivacy"
#define MYB_PRIV_KEY_ALBUM @"PrivateAlbum"
#define MYB_PRIV_KEY_ALBUM_LOCK @"PrivateAlbumLock"
#define MYB_PRIV_KEY_DELETED_LOCK @"RecentlyDeletedLock"
#define MYB_PRIV_KEY_MESSAGES @"PrivateConversations"
#define MYB_PRIV_KEY_MESSAGES_LOCK @"PrivateConversationsLock"
#define MYB_PRIV_KEY_MESSAGES_RESTORE @"PrivateConversationsRestoreRequest"
#define MYB_CONN_NOTIFY "net.myxxdev.mybloxx.connectivity.changed"
#define MYB_PRIV_NOTIFY "net.myxxdev.mybloxx.privacy.changed"
#define MYB_FW_NOTIFY "net.myxxdev.mybloxx.firewall.changed"
static inline NSString *MYBConnPrefsFile(void){return MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.connectivity.plist");}
static inline NSString *MYBPrivPrefsFile(void){return MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.privacy.plist");}
// Call Firewall: its own file, never shared with Private Calls' privacy.plist.
static inline NSString *MYBFirewallPrefsFile(void){return MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.firewall.plist");}
// Written by the tweaks, read by Settings. Separate files per process so two processes never write the same one.
static inline NSString *MYBNetAccessStatusFile(void){return MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.netaccess.status.plist");}
static inline NSString *MYBHotspotStatusFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/HotspotStatus.plist");}
static inline NSString *MYBHotspotLogFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/HotspotSessions.log");}
static inline BOOL MYBConnFlag(NSDictionary *prefs,NSString *key){id value=[prefs objectForKey:key];return [value isKindOfClass:NSNumber.class]&&[value boolValue];}
static inline BOOL MYBConnFlagInFile(NSString *file,NSString *key){return MYBConnFlag([NSDictionary dictionaryWithContentsOfFile:file],key);}
// Read-modify-write: every other key in the file is kept. NO means nothing was changed.
static inline BOOL MYBConnWriteFlag(NSString *file,NSString *key,BOOL on){
 NSMutableDictionary *current=[[NSDictionary dictionaryWithContentsOfFile:file] mutableCopy]?:[NSMutableDictionary dictionary];
 [current setObject:@(on) forKey:key];
 return [current writeToFile:file atomically:YES];
}
// What Personal Hotspot looks like right now, and whether MYbloXX® should be holding. Pure: the same inputs always give the same answer.
//   Hold only while the switch is on, the hotspot is up AND at least one device is connected. Anything unknown (the client count could not
//   be read) is NOT a reason to hold.
static inline BOOL MYBHotspotShouldHold(BOOL switchOn,BOOL hotspotUp,NSInteger clients){return switchOn&&hotspotUp&&clients>0;}
