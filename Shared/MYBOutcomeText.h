#pragma once
// Plain-language results for Restore Default Settings and Proxy Override. Pure functions of the helper’s exit code and
// the recorded outcome, so every message is checked against what the transaction actually did (tests/outcome-native.m).
// Rule: "your previous settings are unchanged" is said ONLY for failures that happen before anything is committed or that
// the transaction rolled back itself. A helper that was killed or timed out (124/125) may have stopped half-way, so those
// never claim "unchanged".
#import <Foundation/Foundation.h>
static inline NSString *MYBExceptionText(NSString *code){
 if([code isEqual:@"protection-left-off"])return @"Another proxy or VPN configuration is installed, so MYbloXX® left it alone and protection is OFF. Remove that configuration (Settings > General > VPN & Device Management, or your Wi-Fi proxy setting), then turn MYbloXX® on.";
 if([code isEqual:@"controlcenter-unavailable"])return @"The Control Centre module is not installed on this iPhone, so it was left as it was.";
 if([code isEqual:@"supervision-unchanged"])return @"The supervision message setting could not be changed safely here, so it was left as it was.";
 return @"One part could not be applied.";
}
// outcome: kind "success" | "partial" | "failed"; title and detail are the alert text.
static inline NSDictionary *MYBResetOutcome(int rc,NSDictionary *record,BOOL resprings){
 NSArray *ex=[record[@"exceptions"] isKindOfClass:NSArray.class]?record[@"exceptions"]:@[];
 if(rc==0)return @{@"kind":@"success",@"title":@"Defaults Restored",@"detail":resprings?@"MYbloXX® is back to the fresh-install setup. Respring once so the change reaches apps. Your backups in Files were kept.":@"MYbloXX® is back to the fresh-install setup. Your backups in Files were kept."};
 if(rc==90){NSMutableArray *lines=[NSMutableArray array];for(NSString *c in ex)[lines addObject:MYBExceptionText(c)];
  return @{@"kind":@"partial",@"title":@"Defaults Partly Restored",@"detail":[@"This is not a complete fresh-install reset. Everything that could be reset was. " stringByAppendingString:[lines componentsJoinedByString:@" "]]};}
 if(rc==91)return @{@"kind":@"failed",@"title":@"Couldn’t Restore Defaults",@"detail":@"The new settings could not be confirmed as working, so MYbloXX® put your previous settings back. Your rules, exceptions and recent activity are as they were."};
 if(rc==92)return @{@"kind":@"failed",@"title":@"Defaults Need Repair",@"detail":@"The reset was applied but could not be confirmed, and going back also failed, so your settings are now a mix. Use Repair MYbloXX®, then check Status & Diagnostics. Your backups in Files were kept."};
 if(rc==124||rc==125)return @{@"kind":@"failed",@"title":@"Reset Didn’t Finish",@"detail":@"The reset did not report a result, so MYbloXX® can’t say what was changed. Check Status & Diagnostics, and use Repair MYbloXX® if protection looks wrong. Your backups in Files were kept."};
 if(rc==75)return @{@"kind":@"failed",@"title":@"MYbloXX® Is Busy",@"detail":@"Another MYbloXX® operation is running. Nothing was changed. Try again in a moment."};
 if(rc==3)return @{@"kind":@"failed",@"title":@"Couldn’t Restore Defaults",@"detail":@"An inline-PAC experiment is active. Nothing was changed. Roll the experiment back first."};
 return @{@"kind":@"failed",@"title":@"Couldn’t Restore Defaults",@"detail":[NSString stringWithFormat:@"Your previous settings are still in place; nothing was changed. (error %d)",rc]};
}
// Proxy Override result. 94 = apply failed AND the previous configuration could not be fully restored.
static inline NSDictionary *MYBProxyOutcome(int rc){
 if(rc==0)return @{@"kind":@"success",@"title":@"Proxy Override On",@"detail":@"All traffic now goes through your proxy. MYbloXX® filtering and exceptions do not apply until you return to MYbloXX® Filtering."};
 if(rc==94)return @{@"kind":@"failed",@"title":@"Proxy Needs Repair",@"detail":@"The proxy could not be applied and your previous setup could not be fully restored. Use Repair MYbloXX®, then check Status & Diagnostics."};
 if(rc==3)return @{@"kind":@"failed",@"title":@"Couldn’t Apply the Proxy",@"detail":@"Another proxy configuration is installed on this iPhone, so MYbloXX® left it alone. Nothing was changed. Remove it first."};
 if(rc==64)return @{@"kind":@"failed",@"title":@"Check the Proxy Address",@"detail":@"Use http://host:port with no username, password or path. Nothing was changed."};
 if(rc==124||rc==125)return @{@"kind":@"failed",@"title":@"Proxy Change Didn’t Finish",@"detail":@"The change did not report a result, so MYbloXX® can’t say what was changed. Use Repair MYbloXX® if your internet looks wrong."};
 return @{@"kind":@"failed",@"title":@"Couldn’t Apply the Proxy",@"detail":[NSString stringWithFormat:@"The proxy could not be applied, and your previous working setup was restored. (error %d)",rc]};
}

// Turning native protection on while a hand-installed MYbloXX profile may hold the proxy. 3 = something else holds it or the profile is not
// positively ours; 76 = this iOS does not let MYbloXX® remove profiles; 80/81 = nothing was removed or removal was not confirmed;
// 82 = the profile was removed but native protection did not come up (the saved choice is kept).
static inline NSDictionary *MYBProfileOutcome(int rc){
 if(rc==78)return @{@"kind":@"failed",@"title":@"Old MYbloXX\u00ae Profile Found",@"detail":@"A MYbloXX\u00ae profile you installed earlier is holding the proxy, so native protection cannot start. Choose Switch to Native Protection and MYbloXX\u00ae removes that profile and turns native protection on. Your options, rules and permissions are kept. Nothing has been changed yet."};
 if(rc==0)return @{@"kind":@"success",@"title":@"Native Protection Is On",@"detail":@"MYbloXX® is blocking natively again."};
 if(rc==82)return @{@"kind":@"failed",@"title":@"Profile Removed, Protection Is Not On",@"detail":@"The old MYbloXX® profile was removed, but native protection could not be turned on. Your choice is saved. Use Repair MYbloXX® to finish, then check Status & Diagnostics."};
 if(rc==81)return @{@"kind":@"failed",@"title":@"Profile Still Active",@"detail":@"MYbloXX® asked iOS to remove the old profile, but iOS did not confirm it in time, so nothing else was changed. Remove it in Settings > General > VPN & Device Management, then try again."};
 if(rc==80)return @{@"kind":@"failed",@"title":@"Nothing Was Changed",@"detail":@"MYbloXX® could not save its recovery information first, so it did not touch the profile. Free some space or run Repair MYbloXX®, then try again."};
 if(rc==76)return @{@"kind":@"failed",@"title":@"Remove the Profile in Settings",@"detail":@"MYbloXX® could not read what this profile contains (or remove it) on this iOS, so it cannot be sure it is safe to replace. Open VPN & Device Management, remove the MYbloXX® profile if it is listed, then use Check Again. Nothing was changed."};
 if(rc==3)return @{@"kind":@"failed",@"title":@"A Profile Is Still Installed",@"detail":@"A proxy profile is installed that MYbloXX® will not remove for you. Other profiles (DNS, VPN, work or school) are never touched. Open VPN & Device Management to review it, then use Check Again. Nothing was changed."};
 if(rc==75)return @{@"kind":@"failed",@"title":@"MYbloXX® Is Busy",@"detail":@"Another MYbloXX® operation is running. Nothing was changed. Try again in a moment."};
 return @{@"kind":@"failed",@"title":@"Couldn’t Turn Protection On",@"detail":[NSString stringWithFormat:@"Nothing more was changed (error %d). Open Status & Diagnostics to see why.",rc]};
}
