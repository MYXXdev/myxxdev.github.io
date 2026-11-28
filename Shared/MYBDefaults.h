#pragma once
// THE first-install baseline. Fresh-install initialisation, the UI's fallback for a preference that was never saved,
// and Restore Default Settings all read this one definition. Version it: a later release that adds a key adds an
// explicit migration (MYBDefaultsMigrationKeys) that fills only keys that are ABSENT; it never overwrites a saved value,
// including a saved NO.
#import <Foundation/Foundation.h>
#import "MYBRedirectPolicy.h"
#define MYB_DEFAULTS_VERSION 1
// Shield preferences (net.myxxdev.mybloxx.safariguard.plist). `Enabled` is Shield's master gate: Website Rules and
// popup blocking both require it, so one key covers "Shield protection" and "Website Rules".
static inline NSDictionary *MYBDefaultShield(void){
 return @{@"Enabled":@YES,@"BlockPopups":@YES,@"ShowBlocked":@YES,@"PopupMode":@"strict",
          @"RedirectAskAppStore":@YES,@"RedirectAskOtherApps":@NO,@"Blocked":@[],@"Allowed":@[],@"URLs":@[]}; // App Store questions on, other-app questions off; the older RedirectEnabled/RedirectOtherApps keys are no longer written
}
static inline NSDictionary *MYBDefaultProtection(void){return @{@"enabled":@YES,@"mode":@"Default"};}
static inline BOOL MYBDefaultAutomaticUpdates(void){return YES;}
// Control Centre module: shipped enabled (the bundle is installed in its active location). Legacy supervision hiding is
// OFF: a fresh MYbloXX has not touched the device's supervision profile, and the reset returns it to that state.
static inline BOOL MYBDefaultControlCenter(void){return YES;}
static inline BOOL MYBDefaultLegacySupervision(void){return NO;}
// Exit codes of restoredefaults / initdefaults beyond the ordinary failures (which mean "nothing changed").
//   90  applied, but with listed exceptions (see Defaults.plist "exceptions"): NOT a complete fresh-install reset
//   91  applied, then verification failed; the previous settings were put back (rolled back)
//   92  applied, then verification failed and the rollback also failed: settings are mixed; use Repair
#define MYB_DEFAULTS_PARTIAL 90
#define MYB_DEFAULTS_ROLLED_BACK 91
#define MYB_DEFAULTS_MIXED 92
static inline NSString *MYBShieldPopupMode(NSDictionary *saved){
 NSString *v=saved[@"PopupMode"];return [@[@"standard",@"strict"] containsObject:v]?v:MYBDefaultShield()[@"PopupMode"];
}
// Keys a release added after v1 and the value they get on UPGRADE only when absent. (None yet; v1 is the baseline.)
static inline NSDictionary *MYBDefaultsMigrationKeys(int fromVersion){(void)fromVersion;return @{};}
