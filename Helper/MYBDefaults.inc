#include "../Shared/MYBDefaults.h"
// First-install defaults and Restore Default Settings. Both build the SAME baseline (Shared/MYBDefaults.h) and apply it
// through the transactional setup restore (restoreSetupDictionary): saved files, components, update schedule and the
// runtime are replaced together and rolled back together, and success is reported only when the saved intent and the
// runtime configuration agree. A saved backup in the Files app is archived first and never overwritten.
static NSString *DefaultsRecordPath(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/Defaults.plist");}
static NSDictionary *MYBDefaultsSetup(void){
 NSDictionary *snap=SetupSnapshot();if(!snap)return nil;
 NSMutableDictionary *d=[snap mutableCopy],*pacs=[NSMutableDictionary dictionary];
 for(NSString *name in MYBSetupModes()){NSData *data=[NSData dataWithContentsOfFile:BundledPAC(name)];if(!data||!SyntaxValid(data))return nil;pacs[name]=data;} // bundled rules only; no Custom PAC
 d[@"pacs"]=pacs;d[@"protection"]=MYBDefaultProtection();d[@"rules"]=@{@"blocked":@[],@"allowed":@[]};
 d[@"shield"]=MYBDefaultShield();d[@"shieldPermissions"]=@[];d[@"speedyAds"]=@{};d[@"preferences"]=@{}; // preferences hold Proxy Override
 d[@"automaticUpdates"]=@(MYBDefaultAutomaticUpdates());
 d[@"components"]=@{@"ControlCenter":@(MYBDefaultControlCenter())}; // every component is stated, none inherited
 d[@"legacySupervision"]=@{@"enabled":@(MYBDefaultLegacySupervision())};
 return d;
}
// Keeps the user's saved settings backup: copied (never moved) into Files/MYbloXX/Backups before anything replaces it.
static int MYBArchiveSettingsBackup(NSString *label){
 NSString *src=SetupSettingsFile();if(!src.length||![FM() fileExistsAtPath:src])return 0;
 NSString *folder=MYBFilesFolder();if(!MYBFilesFolderIsSafe(folder))return 78;
 NSString *dir=[folder stringByAppendingPathComponent:@"Backups"];struct stat st;
 if(lstat(dir.fileSystemRepresentation,&st)==0){if(!S_ISDIR(st.st_mode)||S_ISLNK(st.st_mode))return 78;}
 else{if(![FM() createDirectoryAtPath:dir withIntermediateDirectories:NO attributes:nil error:NULL])return 78;chown(dir.fileSystemRepresentation,501,501);}
 NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"yyyyMMdd-HHmmss";f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
 NSString *name=[NSString stringWithFormat:@"MYbloXX-Settings before %@ %@.plist",label,[f stringFromDate:[NSDate date]]],*dst=[dir stringByAppendingPathComponent:name];
 if(![FM() copyItemAtPath:src toPath:dst error:NULL])return 74;
 chown(dst.fileSystemRepresentation,501,501);chmod(dst.fileSystemRepresentation,0644);
 // Keep the newest ten automatic archives; anything else in the folder is the user's and is never touched.
 NSMutableArray *ours=[NSMutableArray array];for(NSString *n in [FM() contentsOfDirectoryAtPath:dir error:NULL])if([n hasPrefix:@"MYbloXX-Settings before "]&&[n hasSuffix:@".plist"])[ours addObject:n];
 [ours sortUsingSelector:@selector(compare:)];while(ours.count>10){[FM() removeItemAtPath:[dir stringByAppendingPathComponent:ours.firstObject] error:NULL];[ours removeObjectAtIndex:0];}
 return 0;
}
static void MYBDefaultsRecord(NSString *origin,BOOL needsRespring,NSString *note){
 NSMutableDictionary *r=[@{@"version":@(MYB_DEFAULTS_VERSION),@"origin":origin,@"time":[NSDate date],@"needsRespring":@(needsRespring)} mutableCopy];if(note)r[@"note"]=note;
 [FM() createDirectoryAtPath:DefaultsRecordPath().stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 if([r writeToFile:DefaultsRecordPath() atomically:YES]){chown(DefaultsRecordPath().fileSystemRepresentation,501,501);chmod(DefaultsRecordPath().fileSystemRepresentation,0644);}
}
// Transient and user-facing history that a reset clears; nothing outside MYbloXX's own data folder is named here.
static int MYBWriteAdsFilter(void); // MYBAdsFilter.inc
static void MYBClearTransientState(void){
 NSString *root=MYBDataPath(@"/var/mobile/Library/MYbloXX");
 for(NSString *n in @[@"ShieldActivity.plist",@"InlineRecovery.plist",@"StartupLaunches.plist",@"StartupRecovery.plist",@"AppControlStatus.plist"])[FM() removeItemAtPath:[root stringByAppendingPathComponent:n] error:NULL];
 // Temporary and one-time Shield grants die with the reset (standing ones were replaced by the transaction).
 MYBShieldRepairOwnership();
 if(![FM() fileExistsAtPath:MYBShieldPermissionsFile()])return;
 MYBShieldReplacePermanent(MYBShieldPermissionsFile(),@[]);
}
// Agreement check: what was saved, what is installed and what the runtime is doing must say the same thing. `setup` is
// the baseline that was applied (after any exceptions were folded in), so an exception is judged against what it
// actually became, not against the ideal.
static int MYBDefaultsAgree(NSDictionary *setup){
#ifdef MYB_HELPER_TESTING
 if(getenv("MYB_TEST_FORCE_DISAGREE"))return 73; // fault injection: the verification step fails after everything committed
#endif
 NSDictionary *state=loadSavedState();BOOL wantOn=[setup[@"protection"][@"enabled"] boolValue];
 if([state[@"enabled"] boolValue]!=wantOn||![selectedMode() isEqual:setup[@"protection"][@"mode"]])return 73;
 if(wantOn){if(!ownedLink()||![MYBRuntimeStatus()[@"state"] isEqual:@"configured"])return 73;}
 else if(ownedLink()&&MYBActiveFlag())return 73; // "left off" must really be off; a foreign link must be untouched
 if([FM() fileExistsAtPath:SetupCCPath(YES)]!=[setup[@"components"][@"ControlCenter"] boolValue])return 73;
 if([UpdateState()[@"automatic"] boolValue]!=[setup[@"automaticUpdates"] boolValue])return 73;
 NSDictionary *shield=[NSDictionary dictionaryWithContentsOfFile:SetupShieldPrefs()];
 for(NSString *k in @[@"Enabled",@"BlockPopups",@"ShowBlocked"])if([shield[k] boolValue]!=[setup[@"shield"][k] boolValue])return 73;
 if(MYBRedirectAskAppStore(shield)!=MYBRedirectAskAppStore(setup[@"shield"])||MYBRedirectAskOtherApps(shield)!=MYBRedirectAskOtherApps(setup[@"shield"]))return 73; // the two redirect switches, by their effective value
 if(![shield[@"PopupMode"] isEqual:setup[@"shield"][@"PopupMode"]])return 73;
 return 0;
}
// Applies the baseline. Things that can legitimately prevent a part of it must not block the rest, and each one is
// REPORTED, never hidden. `exceptions` receives a code per part that was NOT applied:
//   protection-left-off      another proxy configuration owns the managed slot (rc 3): it is left untouched
//   controlcenter-unavailable the Control Centre bundle is not installed (rc 74)
//   supervision-unchanged    supervision cannot be changed safely here (rc 78)
static int MYBApplyDefaultsSetup(NSMutableDictionary *setup,NSMutableArray *exceptions){
 int rc=0;
 for(int pass=0;pass<5;pass++){
  rc=restoreSetupDictionary(setup);if(!rc)break;
  if(rc==3&&[setup[@"protection"][@"enabled"] boolValue]){NSMutableDictionary *p=[setup[@"protection"] mutableCopy];p[@"enabled"]=@NO;setup[@"protection"]=p;[exceptions addObject:@"protection-left-off"];continue;}
  if(rc==74){NSMutableDictionary *c=[setup[@"components"] mutableCopy];BOOL cc=[FM() fileExistsAtPath:SetupCCPath(YES)];
   if(cc!=[c[@"ControlCenter"] boolValue]){c[@"ControlCenter"]=@(cc);[exceptions addObject:@"controlcenter-unavailable"];}
   setup[@"components"]=c;continue;}
  if(rc==78&&![exceptions containsObject:@"supervision-unchanged"]){NSDictionary *sup=MYBSupervisionStatus(SupervisionPath(),SupervisionRecord());setup[@"legacySupervision"]=@{@"enabled":@([sup[@"owned"] boolValue])};[exceptions addObject:@"supervision-unchanged"];continue;}
  break;
 }
 return rc;
}
static void MYBDefaultsOutcome(NSString *origin,NSString *outcome,NSArray *exceptions,NSString *note,BOOL respring){
 MYBDefaultsRecord(origin,respring,note);
 NSMutableDictionary *r=[[NSDictionary dictionaryWithContentsOfFile:DefaultsRecordPath()] mutableCopy]?:[NSMutableDictionary dictionary];
 r[@"outcome"]=outcome;if(exceptions.count)r[@"exceptions"]=exceptions;else [r removeObjectForKey:@"exceptions"];
 if([r writeToFile:DefaultsRecordPath() atomically:YES]){chown(DefaultsRecordPath().fileSystemRepresentation,501,501);chmod(DefaultsRecordPath().fileSystemRepresentation,0644);}
}
static int restoreDefaults(void){
 if(MYBExperimentActive())return 3;
 NSDictionary *prior=SetupSnapshot(); // what a rollback returns to
 int archived=MYBArchiveSettingsBackup(@"Restore Defaults");if(archived)return archived;
 NSMutableDictionary *setup=[MYBDefaultsSetup() mutableCopy];if(!setup)return 65;
 NSMutableArray *exceptions=[NSMutableArray array];int rc=MYBApplyDefaultsSetup(setup,exceptions);
 // A failure here is the transaction's own: it already put everything back (settings, components, runtime).
 if(rc){logLine([NSString stringWithFormat:@"DEFAULTS: restore failed (%d); the transaction rolled back to the previous settings",rc]);return rc;}
 for(NSString *dir in @[@"PACCurrent",@"PAC"])[FM() removeItemAtPath:[MYBDataPath([@"/var/mobile/Library/MYbloXX/" stringByAppendingString:dir]) stringByAppendingPathComponent:@"Custom.pac"] error:NULL]; // Proxy Override PAC: either directory
 [FM() removeItemAtPath:PACFile(@"Custom") error:NULL];
 int agree=MYBDefaultsAgree(setup);
 if(agree){
  // Committed but not verified. Put the previous settings back if possible; otherwise say the state is mixed.
  logLine(@"DEFAULTS: baseline written but the saved state and runtime disagree; attempting rollback");
  int back=prior&&MYBSetupValid(prior,^BOOL(NSData *d){return SyntaxValid(d);})?restoreSetupDictionary(prior):65;
#ifdef MYB_HELPER_TESTING
  if(getenv("MYB_TEST_ROLLBACK_FAIL"))back=73; // fault injection: the rollback itself fails
#endif
  if(!back){MYBDefaultsOutcome(@"reset-rolled-back",@"rolled-back",nil,@"Verification failed; previous settings restored",NO);MYBPublishRuntimeStatusForce(YES);logLine(@"DEFAULTS: rolled back to the previous settings");return MYB_DEFAULTS_ROLLED_BACK;}
  MYBDefaultsOutcome(@"reset-mixed",@"mixed",nil,@"Verification failed and rollback failed",NO);MYBPublishRuntimeStatusForce(YES);
  logLine([NSString stringWithFormat:@"DEFAULTS: rollback failed (%d); settings are mixed, Repair is needed",back]);return MYB_DEFAULTS_MIXED;
 }
 MYBClearTransientState(); // only after the reset is verified; a rolled-back reset keeps the user's history
 [FM() removeItemAtPath:MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.inappads.plist") error:NULL]; // In-App Ad Blocking returns to on for every app
 // Advanced > Connectivity and Extra Privacy Protection: every switch returns to off. Nothing stored by iOS or Photos is touched, and the Private Album's items stay.
 if(!MYBPCResetStore(MYBPCStoreFile(),MYBPCStampFile(),[[NSDate date] timeIntervalSince1970]))logLine(@"DEFAULTS: Private Calls rules could not be cleared; run Restore Defaults again");
 for(NSString *name in @[@"connectivity",@"privacy"])[FM() removeItemAtPath:MYBDataPath([NSString stringWithFormat:@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.%@.plist",name]) error:NULL];
 notify_post("net.myxxdev.mybloxx.connectivity.changed");notify_post("net.myxxdev.mybloxx.privacy.changed");
 {int filter=MYBWriteAdsFilter();if(filter)logLine([NSString stringWithFormat:@"DEFAULTS: loader filters could not be reset (%d); Repair MYbloXX®",filter]);} // the loader lists follow the reset (catalogue apps only)
 MYBDefaultsOutcome(@"reset",exceptions.count?@"partial":@"complete",exceptions,exceptions.count?@"Restored with exceptions":@"Restored by the user",NO);MYBPublishRuntimeStatusForce(YES);
 logLine([NSString stringWithFormat:@"DEFAULTS: baseline restored%@; backups kept",exceptions.count?[@" with exceptions: " stringByAppendingString:[exceptions componentsJoinedByString:@","]]:@""]);
 return exceptions.count?MYB_DEFAULTS_PARTIAL:0;
}
// Earlier builds could leave MYbloXX data behind without ever recording that the baseline was applied (an interrupted or
// failed first initialisation, or a build that predates it). That partial state was then mistaken for a configured
// installation, so the baseline never ran. Components read an ABSENT switch as off, so absent keys are the evidence: they
// mean the setting was never chosen. This fills ONLY keys that are absent. A saved value, true or false, is the user's
// (or an earlier release's) deliberate state and is never touched.
static int MYBFillAbsentDefaults(NSArray<NSString *> **filledOut){
 NSMutableArray *filled=[NSMutableArray array];
 NSDictionary *savedState=loadSavedState()?:@{};
 NSMutableDictionary *shield=[([NSDictionary dictionaryWithContentsOfFile:SetupShieldPrefs()]?:@{}) mutableCopy];
 NSDictionary *baseline=MYBDefaultShield();
 for(NSString *key in @[@"Enabled",@"BlockPopups",@"ShowBlocked",@"PopupMode"])if(!shield[key]){shield[key]=baseline[key];[filled addObject:[@"shield." stringByAppendingString:key]];}
 // The two redirect switches: an install that still has only the older keys keeps exactly what they did (nothing widened); a fresh one gets the baseline.
 {BOOL storeAbsent=![shield[MYB_REDIRECT_KEY_STORE] isKindOfClass:NSNumber.class],otherAbsent=![shield[MYB_REDIRECT_KEY_OTHER] isKindOfClass:NSNumber.class];
  if(storeAbsent||otherAbsent){MYBRedirectMaterialize(shield);if(storeAbsent)[filled addObject:@"shield.RedirectAskAppStore"];if(otherAbsent)[filled addObject:@"shield.RedirectAskOtherApps"];}}
 BOOL enabledAbsent=!savedState[@"enabled"],modeAbsent=![savedState[@"mode"] isKindOfClass:NSString.class];
 if(enabledAbsent)[filled addObject:@"protection.enabled"];if(modeAbsent)[filled addObject:@"protection.mode"];
 BOOL updatesAbsent=!UpdateState()[@"automatic"];if(updatesAbsent)[filled addObject:@"updates.automatic"];
 if(filledOut)*filledOut=filled;
 if(!filled.count)return 0;
 if(MYBExperimentActive())return 3;
 NSMutableDictionary *setup=[SetupSnapshot() mutableCopy];if(!setup)return 65;
 setup[@"shield"]=shield;
 NSMutableDictionary *protection=[setup[@"protection"] mutableCopy]?:[NSMutableDictionary dictionary];
 if(enabledAbsent)protection[@"enabled"]=MYBDefaultProtection()[@"enabled"];if(modeAbsent)protection[@"mode"]=MYBDefaultProtection()[@"mode"];setup[@"protection"]=protection;
 if(updatesAbsent)setup[@"automaticUpdates"]=@(MYBDefaultAutomaticUpdates());
 int archived=MYBArchiveSettingsBackup(@"completing defaults");if(archived)return archived;
 NSDictionary *updatesBefore=[UpdateState() copy];// the restore transaction rewrites this record; completing defaults must not drop its revision or freshness stamps
 NSMutableArray *exceptions=[NSMutableArray array];int rc=MYBApplyDefaultsSetup(setup,exceptions);if(rc)return rc;
 if(updatesBefore.count){NSMutableDictionary *kept=[updatesBefore mutableCopy];kept[@"automatic"]=@([setup[@"automaticUpdates"] boolValue]);if(!SaveUpdates(kept))return 73;}
 int agree=MYBDefaultsAgree(setup);if(agree)return MYB_DEFAULTS_MIXED;
 if(exceptions.count)logLine([@"DEFAULTS: completed absent defaults with exceptions: " stringByAppendingString:[exceptions componentsJoinedByString:@","]]);
 return exceptions.count?MYB_DEFAULTS_PARTIAL:0;
}
// Install/upgrade entry. Genuine first install = no earlier MYbloXX state of any kind. An upgrade records itself and
// changes nothing.
// Browser website rules no longer have an on/off switch (see MYBShieldNormalizedRules). Runs on every install and every restore: it only
// rewrites the two retired keys, never the rules, and remembers (once) that rules had been Off so Pop-Up Control can say what changed.
static void MYBMigrateBrowserRules(void){
 NSString *path=SetupShieldPrefs();NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:path];if(!saved)return;
 BOOL off=NO;NSDictionary *next=MYBShieldNormalizedRules(saved,&off);
 if(off)MYBNoteBrowserRulesWereOff();
 if(next==saved)return;
 if([next writeToFile:path atomically:YES]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);logLine(off?@"RULES: browser website rules were Off; they now always apply (rules kept)":@"RULES: retired blocked-page notice key normalised");}
}
static int initDefaults(void){
 MYBMigrateBrowserRules();
 NSDictionary *record=[NSDictionary dictionaryWithContentsOfFile:DefaultsRecordPath()];int have=[record[@"version"] intValue];
 if(have>=MYB_DEFAULTS_VERSION)return 0;
 NSString *root=MYBDataPath(@"/var/mobile/Library/MYbloXX"),*prefs=MYBDataPath(@"/var/mobile/Library/Preferences");BOOL prior=NO;
 for(NSString *p in @[[root stringByAppendingPathComponent:@"State.plist"],[root stringByAppendingPathComponent:@"Updates.plist"],[root stringByAppendingPathComponent:@"ManualRules.plist"],[root stringByAppendingPathComponent:@"AppliedRules.plist"],[root stringByAppendingPathComponent:@"ShieldPermissions.plist"],
   [prefs stringByAppendingPathComponent:@"net.myxxdev.mybloxx.safariguard.plist"],[prefs stringByAppendingPathComponent:@"net.myxxdev.mybloxx.speedyads.plist"],[prefs stringByAppendingPathComponent:@"net.myxxdev.mybloxx.user.plist"],[prefs stringByAppendingPathComponent:@"net.myxxdev.mybloxx.adcontrol.plist"]])
  if([FM() fileExistsAtPath:p]){prior=YES;break;}
 if(prior){
  NSDictionary *add=MYBDefaultsMigrationKeys(have);(void)add; // v1: nothing to add
  if(!have){
   // No record that the baseline ever ran: complete whatever was never chosen, leave everything that was.
   NSArray<NSString *> *filled=nil;int fill=MYBFillAbsentDefaults(&filled);
   if(fill&&fill!=MYB_DEFAULTS_PARTIAL){logLine([NSString stringWithFormat:@"DEFAULTS: could not complete unset defaults (%d); existing settings unchanged; will retry on the next install or Repair",fill]);return fill;}
   MYBDefaultsOutcome(filled.count?@"upgrade-completed":@"upgrade",@"complete",nil,filled.count?[@"Unset defaults completed: " stringByAppendingString:[filled componentsJoinedByString:@", "]]:@"Existing settings preserved",NO);
   if(filled.count){MYBPublishRuntimeStatusForce(YES);logLine([@"DEFAULTS: earlier install had no baseline record; filled only unset keys: " stringByAppendingString:[filled componentsJoinedByString:@","]]);printf("MYbloXX®: completed settings that were never chosen (%lu). Your saved choices were kept.\n",(unsigned long)filled.count);}
   else logLine(@"DEFAULTS: earlier install had no baseline record and nothing was unset; existing choices preserved");
   return fill;
  }
  MYBDefaultsRecord(@"upgrade-migrated",NO,@"Existing settings preserved");
  logLine([NSString stringWithFormat:@"DEFAULTS: upgrade from defaults v%d; existing choices preserved",have]);return 0;
 }
 if(MYBExperimentActive()){logLine(@"DEFAULTS: inline-PAC experiment active; first-install defaults deferred");return 3;}
 int archived=MYBArchiveSettingsBackup(@"fresh install");if(archived)return archived;
NSMutableDictionary *setup=[MYBDefaultsSetup() mutableCopy];if(!setup)return 65;
 // Supervision (fresh installs only; an upgrade never reaches this line, so an explicit choice is never overridden). Eligible and unmanaged devices get it on.
 NSString *supervisionWhy=nil;BOOL supervisionOn=MYBSupervisionEligibleForDefault(SupervisionPath(),SupervisionRecord(),&supervisionWhy);
 setup[@"legacySupervision"]=@{@"enabled":@(supervisionOn)};
 logLine(supervisionOn?@"DEFAULTS: supervision feature turned on by default (device eligible and unmanaged)":[@"DEFAULTS: supervision feature left off: " stringByAppendingString:supervisionWhy?:@"not eligible"]);
 NSMutableArray *exceptions=[NSMutableArray array];int rc=MYBApplyDefaultsSetup(setup,exceptions);
 if(rc){logLine([NSString stringWithFormat:@"DEFAULTS: first-install defaults not applied (%d); nothing was changed; will retry on the next install or Repair",rc]);return rc;}
 int agree=MYBDefaultsAgree(setup);
 if(agree){MYBDefaultsOutcome(@"fresh-unverified",@"unverified",exceptions,@"Written; runtime disagrees",NO);logLine(@"DEFAULTS: first-install defaults written but the saved state and runtime disagree; Repair is needed");printf("MYbloXX®: defaults were written but could not be verified. Use Repair MYbloXX.\n");return MYB_DEFAULTS_MIXED;}
 MYBClearTransientState();
 MYBDefaultsOutcome(@"fresh",exceptions.count?@"partial":@"complete",exceptions,exceptions.count?@"First installation, with exceptions":@"First installation",NO);MYBPublishRuntimeStatusForce(YES);
 if(exceptions.count){logLine([@"DEFAULTS: first-install baseline applied with exceptions: " stringByAppendingString:[exceptions componentsJoinedByString:@","]]);printf("MYbloXX®: defaults applied, except: %s. See Status & Diagnostics.\n",[[exceptions componentsJoinedByString:@", "] UTF8String]);return MYB_DEFAULTS_PARTIAL;}
 logLine(@"DEFAULTS: first-install baseline applied");
 printf("MYbloXX®: first-install defaults applied (protection, Shield, App Redirect Protection, automatic updates).\n");return 0;
}
