#pragma once
// Decision logic for automatic recovery after a reboot / re-jailbreak. Pure, so the retry behaviour and the
// "never override what the user chose" rules are tested without a device.
//
//  inputs   saved        a saved intent exists (the helper has ever configured MYbloXX)
//           intent       the saved enabled/disabled choice
//           appControl   App Control has MYbloXX temporarily paused (its own watcher restores it)
//           experiment   the inline-PAC experiment owns the managed configuration
//           action       MYBIPRecoveryAction(): ok | reapply | blocked | orphan-clean
//           verification applied | identity-unavailable | stale | not-applied | nil (CFNetwork check result)
//           ready        runtime paths, bundled PACs and the managed parent are usable now
//           refreshes    configd refreshes already tried in this run
//  result   nothing-saved | defer-appcontrol | foreign | clean | done-disabled | not-ready | reapply | refresh | wait | done-applied | done-unverified
static inline NSString *MYBStartupPlan(NSDictionary *in){
 if(![in[@"saved"] boolValue])return @"nothing-saved";
 if([in[@"experiment"] boolValue])return @"foreign";
 if([in[@"appControl"] boolValue])return @"defer-appcontrol";
 NSString *action=in[@"action"],*v=in[@"verification"];
 if(![in[@"intent"] boolValue])return [action isEqual:@"orphan-clean"]?@"clean":@"done-disabled";
 if([action isEqual:@"blocked"])return @"foreign";
 if(![in[@"ready"] boolValue])return @"not-ready";
 if([action isEqual:@"reapply"])return @"reapply";
 if([v isEqual:@"applied"])return @"done-applied";
 // The configuration is installed and structurally correct, but iOS does not expose the script, so it can never be
 // confirmed. That is a final answer, not a reason to retry: retrying cannot change it.
 if([v isEqual:@"identity-unavailable"])return @"done-unverified";
 // Structurally correct but iOS is not using it yet: nudge configd, at most twice, then keep waiting for it.
 return [in[@"refreshes"] intValue]<2?@"refresh":@"wait";
}
// Seconds to wait before attempt n (0-based): quick at first (services are usually seconds away), then backing off.
static inline unsigned MYBStartupDelay(int attempt){static const unsigned d[]={0,5,10,15,30,45,60,60,90,120};return attempt<0?0:(attempt<10?d[attempt]:120);}
#define MYB_STARTUP_ATTEMPTS 10
