// Automatic recovery after a reboot / re-jailbreak. Included into the helper after the apply paths.
//
// Why this exists: a reboot returns iOS to stock networking and the managed inline-PAC target is gone. The restore
// job used to run once (LaunchOnlyOnce), refused to run at all unless an "opt-in" marker file happened to exist,
// restarted configd without checking the result, and never retried when RootHide paths or services were not ready
// yet. Repair did none of those things, which is why Repair worked and the boot path did not.
//
// Now one bounded loop, launched by the restore job (and available as `startuprecover`):
//   * the SAVED intent decides: disabled stays disabled (and a leftover owned configuration is removed);
//   * every attempt takes the shipping operation lock without blocking, so it never competes with Settings, Repair,
//     the watcher's recovery or an update;
//   * the apply uses the same MYBApplyRuntime/inline-PAC path as Repair, only when something is actually missing;
//   * configd is restarted only when something changed, never when protection is already verified;
//   * the result is verified through CFNetwork and published; the outcome goes to StartupRecovery.plist and the log;
//   * a per-boot limit on launches means a persistent failure cannot loop; manual Repair stays the fallback.
#include "../Shared/MYBProfileMigration.h" // MYB_MIGRATE_* codes used below; the code itself is in MYBProfileMigrate.inc
#include "../Shared/MYBStartupPlan.h"
#include <sys/stat.h>
static int MYBMigrateLegacyProfile(BOOL userChose); // defined in MYBProfileMigrate.inc
static int MYBOperationLockTake(void){
 NSString *lockPath=[MYBBootstrapRoot() stringByAppendingPathComponent:@"var/run/mybloxx-operation.lock"];
 int fd=open(lockPath.fileSystemRepresentation,O_CREAT|O_RDWR|O_NOFOLLOW,0600);
 if(fd<0||flock(fd,LOCK_EX|LOCK_NB)!=0){if(fd>=0)close(fd);return -1;}
 return fd;
}
static void MYBStartupPause(unsigned seconds){
#ifdef MYB_HELPER_TESTING
 if(getenv("MYB_TEST_NO_SLEEP"))return;
#endif
 if(seconds)sleep(seconds);
}
static NSString *MYBVerificationNow(void){
#ifdef MYB_HELPER_TESTING
 { const char *forced=getenv("MYB_TEST_VERIFY");if(forced&&MYBRuntimeStatus()[@"state"]&&[MYBRuntimeStatus()[@"state"] isEqual:@"configured"])return [NSString stringWithUTF8String:forced]; }
#endif
 NSDictionary *s=MYBRuntimeStatus();if(![s[@"state"] isEqual:@"configured"])return nil;
 NSString *mode=selectedMode(),*script=mode.length?MYBEffectiveScript(mode):nil;
 CFDictionaryRef proxies=CFNetworkCopySystemProxySettings();NSDictionary *effective=proxies?CFBridgingRelease(proxies):nil;
 return MYBRuntimeVerify(s,script?MYBRuntimeSHA256(script):nil,effective)[@"verification"];
}
static void MYBStartupRecord(NSString *result,int attempts,int rc,NSString *detail,NSString *verification){
 NSString *path=MYBDataPath(@"/var/mobile/Library/MYbloXX/StartupRecovery.plist");if(!path.length)return;
 NSMutableDictionary *r=[@{@"result":result,@"attempts":@(attempts),@"code":@(rc),@"detail":detail?:@"",@"time":[NSDate date]} mutableCopy];
 if(verification)r[@"verification"]=verification;
 [FM() createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 if([r writeToFile:path atomically:YES]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
 logLine([NSString stringWithFormat:@"STARTUP: %@ after %d attempt(s) (code %d)%@",result,attempts,rc,detail.length?[@": " stringByAppendingString:detail]:@""]);
}
static BOOL MYBStartupReady(void){
 if(!MYBEnsureSystemManagedParent())return NO;
 NSString *mode=selectedMode();if(!validMode(mode)&&![mode isEqual:@"Custom"])mode=@"Default";
 return MYBEffectiveScript(mode)!=nil;
}
static int MYBWriteAdsFilter(void); // MYBAdsFilter.inc
static int startupRecover(void){
 {int filter=MYBWriteAdsFilter();if(filter)logLine([NSString stringWithFormat:@"STARTUP: loader filters could not be checked (%d)",filter]);} // after an upgrade or re-jailbreak: rewritten only if different
 MYBShieldRepairOwnership(); // Shield permission files created by root must stay writable by SpringBoard
 // One boot cannot start this more than a few times (launchd restarts it after a failure); after that Repair is the fallback.
 NSString *limitPath=MYBDataPath(@"/var/mobile/Library/MYbloXX/StartupLaunches.plist");int launches=0;
 if(limitPath.length&&!MYBRecoveryTake(limitPath,4,21600,&launches)){MYBStartupRecord(@"gave-up",launches,75,@"launch limit for this boot reached; use Repair MYbloXX®",nil);return 0;}
 int refreshes=0,lastRC=0;NSString *lastVerification=nil;
 for(int attempt=0;attempt<MYB_STARTUP_ATTEMPTS;attempt++){
  MYBStartupPause(MYBStartupDelay(attempt));
  int lock=MYBOperationLockTake();
  if(lock<0){lastRC=75;logLine(@"STARTUP: another MYbloXX® operation is running; waiting");continue;}
  @autoreleasepool{
   NSDictionary *state=loadSavedState();
   BOOL saved=state[@"enabled"]!=nil,intent=[state[@"enabled"] boolValue];
   BOOL appControl=[AppControlSession()[@"active"] boolValue],experiment=MYBExperimentActive();
   NSString *expected=nil;if(intent){NSString *m=selectedMode();if(!validMode(m)&&![m isEqual:@"Custom"])m=@"Default";expected=MYBEffectiveScript(m);}
   NSString *action=saved?MYBIPRecoveryAction(intent,expected):@"ok";
   NSString *verification=(saved&&intent)?MYBVerificationNow():nil;lastVerification=verification;
   NSString *plan=MYBStartupPlan(@{@"saved":@(saved),@"intent":@(intent),@"appControl":@(appControl),@"experiment":@(experiment),@"action":action,@"verification":verification?:@"",@"ready":@(intent?MYBStartupReady():YES),@"refreshes":@(refreshes)});
   int rc=0;
   if([plan isEqual:@"nothing-saved"]){MYBStartupRecord(@"nothing-to-restore",attempt+1,0,@"no saved MYbloXX® configuration",nil);close(lock);return 0;}
   if([plan isEqual:@"defer-appcontrol"]){MYBStartupRecord(@"deferred",attempt+1,0,@"App Control has MYbloXX® paused; its watcher restores it",nil);close(lock);return 0;}
   if([plan isEqual:@"foreign"]){
    // Read-only look: is the occupant a recognised MYbloXX profile (the person can switch it), unresolved, or someone else's? Nothing is removed here.
    int look=(managedOccupied()&&!ownedLink()&&!experiment)?MYBMigrateLegacyProfile(NO):3;
    if(look==MYB_MIGRATE_SWITCH_NEEDED)MYBStartupRecord(@"switch-needed",attempt+1,look,@"an old MYbloXX® profile holds the proxy; open MYbloXX® and choose Switch to Native Protection",nil);
    else if(look==MYB_MIGRATE_UNAVAILABLE)MYBStartupRecord(@"profile-unresolved",attempt+1,look,@"iOS would not say which profile holds the proxy; check VPN & Device Management",nil);
    else MYBStartupRecord(@"not-ours",attempt+1,3,@"the managed configuration belongs to an experiment or another owner; left untouched",nil);
    close(lock);return 0;}
   if([plan isEqual:@"done-disabled"]){MYBStartupRecord(@"disabled",attempt+1,0,@"saved choice is off; nothing applied",nil);close(lock);return 0;}
   if([plan isEqual:@"clean"]){rc=MYBSetPACEnabled(NO);if(!rc)rc=restartConfigd();if(!rc){MYBStartupRecord(@"disabled",attempt+1,0,@"saved choice is off; leftover MYbloXX® configuration removed",nil);MYBPublishRuntimeStatusForce(YES);close(lock);return 0;}lastRC=rc;}
   else if([plan isEqual:@"done-applied"]){MYBPublishRuntimeStatusForce(YES);MYBStartupRecord(@"already-applied",attempt+1,0,@"protection verified",verification);close(lock);return 0;}
   else if([plan isEqual:@"done-unverified"]){MYBPublishRuntimeStatusForce(YES);MYBStartupRecord(@"applied-unverified",attempt+1,0,@"configured, but iOS does not expose the script so the rules cannot be confirmed; not retrying",verification);close(lock);return 0;}
   else if([plan isEqual:@"not-ready"]){lastRC=78;logLine(@"STARTUP: runtime paths or bundled PACs not ready yet");}
   else if([plan isEqual:@"reapply"]){
    NSString *mode=selectedMode();if(!validMode(mode)&&![mode isEqual:@"Custom"])mode=@"Default";
    rc=MYBSetPACEnabled(YES);if(!rc){updateMarkers(mode,YES);rc=saveState(mode,YES);}
    if(!rc){touch(KSystemOptIn);rc=restartConfigd();refreshes++;if(!rc)MYBStartupPause(attempt==0?1:3);}
    lastRC=rc;
   }
   else if([plan isEqual:@"refresh"]){rc=restartConfigd();refreshes++;lastRC=rc;if(!rc)MYBStartupPause(3);}
   else lastRC=69; // "wait": correct on disk, iOS not using it yet
   MYBPublishRuntimeStatusForce(YES);
  }
  close(lock);
 }
 // Re-check once without waiting more: the last refresh may have taken effect just now.
 int lock=MYBOperationLockTake();NSString *final=lock>=0?MYBVerificationNow():nil;if(lock>=0)close(lock);
 if([final isEqual:@"applied"]){MYBStartupRecord(@"restored",MYB_STARTUP_ATTEMPTS,0,@"protection verified",final);return 0;}
 if([final isEqual:@"identity-unavailable"]){MYBStartupRecord(@"applied-unverified",MYB_STARTUP_ATTEMPTS,0,@"configured, but the rules cannot be confirmed on this iOS",final);return 0;}
 MYBStartupRecord(@"gave-up",MYB_STARTUP_ATTEMPTS,lastRC?lastRC:69,@"protection could not be confirmed; use Repair MYbloXX®",final?:lastVerification);
 return lastRC?lastRC:69;
}
