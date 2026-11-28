// Entire setup backup: public paths are fixed, backup content never supplies paths.
static NSString *SetupSettingsFile(void){NSString *folder=MYBFilesFolder();return folder?[folder stringByAppendingPathComponent:@"MYbloXX-Settings.plist"]:nil;}
static NSString *SetupLiveFile(void){NSString *folder=MYBFilesFolder();return folder?[folder stringByAppendingPathComponent:@"MYbloXX.pac"]:nil;}
static NSString *SetupStatusFile(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/BackupStatus.plist");}
static NSString *SetupUserPrefs(void){return MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.user.plist");}
static NSString *SetupShieldPrefs(void){return MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist");}
static NSString *MYBTipsPrefsPath(void){return MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.tips.plist");}
static void MYBNoteBrowserRulesWereOff(void){
 NSMutableDictionary *tips=[([NSDictionary dictionaryWithContentsOfFile:MYBTipsPrefsPath()]?:@{}) mutableCopy];
 if(tips[@"BrowserRulesWereOff"])return; // already told, or already dismissed
 tips[@"BrowserRulesWereOff"]=@YES;
 NSString *path=MYBTipsPrefsPath();if([tips writeToFile:path atomically:YES]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
}
static NSString *SetupSpeedyPrefs(void){return MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist");}
static NSString *SetupCCPath(BOOL active){return [MYBBootstrapRoot() stringByAppendingPathComponent:active?@"Library/ControlCenter/Bundles/MYbloXXCC2.bundle":@"usr/share/mybloxx/modules/MYbloXXCC2.bundle"];}
static NSString *SetupDeviceToken(void){return MYBFilesFolder().stringByDeletingLastPathComponent.stringByDeletingLastPathComponent.lastPathComponent?:@"";}
static NSString *SetupSupervisionFingerprint(void){
 NSData *data=[NSData dataWithContentsOfFile:SupervisionPath()];if(!data)return @"";unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);NSMutableString *hex=[NSMutableString string];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",digest[i]];return hex;
}
static NSDictionary *SetupReadUserPrefs(void){
 NSDictionary *stored=[NSDictionary dictionaryWithContentsOfFile:SetupUserPrefs()]?:[NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/Preferences/com.apple.Preferences.plist")];NSMutableDictionary *prefs=[NSMutableDictionary dictionary];
 for(NSString *key in stored)if([key hasPrefix:@"MYB2-"]&&![@[@"MYB2-block",@"MYB2-allow"] containsObject:key]&&([stored[key] isKindOfClass:NSString.class]||[stored[key] isKindOfClass:NSNumber.class]))prefs[key]=stored[key];return prefs;
}
static void SetupStatus(int rc,NSString *message){
 NSMutableDictionary *state=[[NSDictionary dictionaryWithContentsOfFile:SetupStatusFile()] mutableCopy]?:[NSMutableDictionary dictionary];state[@"lastResult"]=message;state[@"lastCode"]=@(rc);state[@"lastAttempt"]=[NSDate date];if(!rc){state[@"initialized"]=@YES;state[@"lastSuccess"]=[NSDate date];}
 [FM() createDirectoryAtPath:SetupStatusFile().stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];[state writeToFile:SetupStatusFile() atomically:YES];chown(SetupStatusFile().fileSystemRepresentation,501,501);chmod(SetupStatusFile().fileSystemRepresentation,0644);
}
// The saved selection: the identifier (what is applied) and its summary (what the dashboard shows), so a restore, a diagnostic
// and a reader of the settings file all describe the same combination.
static NSDictionary *MYBSetupProtection(BOOL active,NSString *mode){NSString *summary=MYBModeSummary(mode);return summary?@{@"enabled":@(active),@"mode":mode,@"summary":summary}:@{@"enabled":@(active),@"mode":mode};}
static NSDictionary *SetupSnapshot(void){
 // Format 2: settings only. The rules are generated on the device, so no mode PAC is saved; only a Proxy Override ("Custom") is.
 NSMutableDictionary *pacs=[NSMutableDictionary dictionary];
 {NSData *data=[NSData dataWithContentsOfFile:PACFile(@"Custom")];if(data&&SyntaxValid(data))pacs[@"Custom"]=data;}
 // The saved preference is the intent (a temporarily missing runtime file does not change what the user chose).
 BOOL active=[loadSavedState()[@"enabled"] boolValue];if([AppControlSession()[@"active"] boolValue])active=[AppControlSession()[@"previousEnabled"] boolValue];NSString *mode=selectedMode();
 NSDictionary *rules=MYBEffectiveRules([NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/MYbloXX/AppliedRules.plist")],[NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()]);
 NSDictionary *supervision=MYBSupervisionStatus(SupervisionPath(),SupervisionRecord());
 NSMutableDictionary *legacy=[@{@"enabled":@([supervision[@"owned"] boolValue])} mutableCopy];if([supervision[@"owned"] boolValue]){legacy[@"record"]=[NSDictionary dictionaryWithContentsOfFile:SupervisionRecord()]?:@{};legacy[@"device"]=SetupDeviceToken();legacy[@"fingerprint"]=SetupSupervisionFingerprint();}
 NSDictionary *speedy=[NSDictionary dictionaryWithContentsOfFile:SetupSpeedyPrefs()]?:[NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.adcontrol.plist")]?:@{};
 return @{@"format":@"net.myxxdev.mybloxx.setup",@"version":@2,@"created":[NSDate date],@"build":@"RC3-shield",@"transport":@"inline-pac",@"protection":MYBSetupProtection(active,mode),@"rules":rules,@"shield":[NSDictionary dictionaryWithContentsOfFile:SetupShieldPrefs()]?:@{},@"shieldPermissions":MYBShieldExportPermanent(MYBShieldPermissionsFile()),@"speedyAds":speedy,@"preferences":SetupReadUserPrefs(),@"automaticUpdates":@([UpdateState()[@"automatic"] boolValue]),@"components":@{@"ControlCenter":@([FM() fileExistsAtPath:SetupCCPath(YES)])},@"legacySupervision":legacy,@"pacs":pacs};
}
// Legacy profiles are installed straight from the app now, so they no longer need a copy in the Files app. Earlier releases left a Profiles
// folder there: remove the profile files MYbloXX® put in it, and the folder itself once it is empty. Anything else in it is left alone.
static void removeExportedLegacyProfiles(void){
 NSString *folder=[MYBFilesFolder() stringByAppendingPathComponent:@"Profiles"];struct stat st;
 if(!folder.length||lstat(folder.fileSystemRepresentation,&st)!=0||!S_ISDIR(st.st_mode)||S_ISLNK(st.st_mode))return;
 for(NSString *name in MYBLegacyProfileNames())[FM() removeItemAtPath:[folder stringByAppendingPathComponent:[name stringByAppendingString:@".mobileconfig"]] error:NULL];
 rmdir(folder.fileSystemRepresentation);
}
static int exportSetup(BOOL explicitSave){
 if(!MYBFilesFolderIsSafe(MYBFilesFolder()))return 78;
 NSDictionary *setup=SetupSnapshot();if(!MYBSetupValid(setup,^BOOL(NSData *data){return SyntaxValid(data);})){SetupStatus(65,@"Backup not updated: one or more sections are invalid");return 65;}
 // The exported live PAC is the selected mode from the active generation (bundled rules if that file is unreadable).
 NSString *saveMode=setup[@"protection"][@"mode"];NSData *data=[saveMode isEqual:@"Custom"]?setup[@"pacs"][@"Custom"]:[NSData dataWithContentsOfFile:PACFile(saveMode)];
 if(![saveMode isEqual:@"Custom"]&&(!data||!SyntaxValid(data)))data=[NSData dataWithContentsOfFile:BundledPAC(saveMode)];
 if(!data||!SyntaxValid(data)){SetupStatus(65,@"Backup not updated: the selected rules could not be read");return 65;}
 NSString *base=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];NSString *live=MYBSetupLivePAC(base,setup[@"rules"]);if(!live)return 65;
 // A surviving backup after a clean reinstall must not be overwritten by defaults.
 NSDictionary *status=[NSDictionary dictionaryWithContentsOfFile:SetupStatusFile()];
 if(!explicitSave && [FM() fileExistsAtPath:SetupSettingsFile()] && ![status[@"initialized"] boolValue]){SetupStatus(82,@"Saved setup found. Restore it or choose Back Up Now before replacing it.");return 82;}
 int rc=MYBWriteSetupExport(setup,live,SetupSettingsFile(),SetupLiveFile(),nil);
 if(!rc){removeExportedLegacyProfiles();for(NSString *path in @[SetupSettingsFile(),SetupLiveFile()]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
  // Migration from earlier releases: its separate public manual-rule archive is now inside Settings.
  NSString *legacy=[MYBFilesFolder() stringByAppendingPathComponent:@"ManualRules.plist"];if(MYBValidRuleDictionary([NSDictionary dictionaryWithContentsOfFile:legacy]))[FM() removeItemAtPath:legacy error:NULL];
 }
 SetupStatus(rc,rc?@"Backup update failed; previous saved setup retained":@"All settings and the effective PAC are up to date");return rc;
}
static int MYBWriteAdsFilter(void); // MYBAdsFilter.inc: loader filters follow the restored app choices
static int restoreSetupDictionary(NSDictionary *setup);
static int restoreSetup(NSString *file){
if(!file.length)return 78;struct stat st;if(lstat(file.fileSystemRepresentation,&st)!=0 || !S_ISREG(st.st_mode))return 65;NSDictionary *attrs=[FM() attributesOfItemAtPath:file error:NULL];if([attrs[NSFileSize] unsignedLongLongValue]>48*1024*1024)return 65;
 return restoreSetupDictionary([NSDictionary dictionaryWithContentsOfFile:file]);
}
// One transactional apply for a saved backup AND for Restore Default Settings: files, components, schedule and the
// runtime are rebuilt together and rolled back together.
static int restoreSetupDictionary(NSDictionary *setup){
 if(!MYBSetupValid(setup,^BOOL(NSData *data){return SyntaxValid(data);}))return 65;
 { // A backup made before browser rules lost their switch can carry Enabled=NO. Restore must not bring that back.
  BOOL rulesWereOff=NO;NSDictionary *shield=MYBShieldNormalizedRules(setup[@"shield"],&rulesWereOff);
  if(shield!=setup[@"shield"]){NSMutableDictionary *fixed=[setup mutableCopy];fixed[@"shield"]=shield;setup=fixed;}
  if(rulesWereOff)MYBNoteBrowserRulesWereOff();
 }
 BOOL wantActive=[setup[@"protection"][@"enabled"] boolValue],oldLink=ownedLink(),oldActive=oldLink&&MYBActiveFlag();NSString *oldMode=selectedMode(),*mode=setup[@"protection"][@"mode"];
 if(wantActive && managedOccupied()&&!oldLink)return 3;
 BOOL oldCC=[FM() fileExistsAtPath:SetupCCPath(YES)],wantCC=[setup[@"components"][@"ControlCenter"] boolValue];
 if(oldCC!=wantCC && ![FM() fileExistsAtPath:SetupCCPath(oldCC)])return 74;
 NSDictionary *sup=MYBSupervisionStatus(SupervisionPath(),SupervisionRecord());BOOL oldSup=[sup[@"owned"] boolValue],wantSup=[setup[@"legacySupervision"][@"enabled"] boolValue];
 BOOL recoverOwnership=wantSup&&!oldSup&&[sup[@"supervised"] boolValue]&&[setup[@"legacySupervision"][@"device"] isEqual:SetupDeviceToken()]&&[setup[@"legacySupervision"][@"fingerprint"] isEqual:SetupSupervisionFingerprint()];
 if(wantSup!=oldSup && (![sup[@"available"] boolValue]||([sup[@"supervised"] boolValue]&&!oldSup&&!recoverOwnership)))return 78;
 NSMutableDictionary *state=[loadSavedState() mutableCopy];state[@"mode"]=mode;state[@"enabled"]=@(wantActive);
 NSDictionary *updates=@{@"automatic":setup[@"automaticUpdates"],@"lastAttempt":[NSDate date],@"revision":@"restored",@"lastResult":@"PACs restored from saved setup"};
 NSMutableDictionary *values=[@{KState:state,MYBDataPath(@"/var/mobile/Library/MYbloXX/AppliedRules.plist"):setup[@"rules"],MYBDraftFile():setup[@"rules"],ManualRulesArchive():setup[@"rules"],MYBWebsiteFile():@{@"domains":@[],@"revision":NSUUID.UUID.UUIDString},SetupShieldPrefs():setup[@"shield"],SetupSpeedyPrefs():MYBAppControlChoices(setup[@"speedyAds"]),SetupUserPrefs():setup[@"preferences"],UpdateStatePath():updates,AppControlSessionPath():@{@"active":@NO}} mutableCopy];
 if(recoverOwnership)values[SupervisionRecord()]=setup[@"legacySupervision"][@"record"];
 NSMutableArray *watch=[@[MYBShieldPermissionsFile(),KSystemOptIn] mutableCopy];if(wantSup!=oldSup){[watch addObject:SupervisionPath()];[watch addObject:SupervisionRecord()];}
 NSString *componentStash=[UpdateRoot() stringByAppendingPathComponent:[@"ComponentRestore-" stringByAppendingString:NSUUID.UUID.UUIDString]];
 NSString *ccStash=[componentStash stringByAppendingPathComponent:@"MYbloXXCC2.bundle"];
 __block BOOL changedCC=NO;
 int rc=MYBRestoreSetupFiles(setup,UpdateRoot(),values,watch,^BOOL(NSData *data){return SyntaxValid(data);},^int{
  // Standing Shield permissions only. A backup without this section (older version) leaves them as they are;
  // temporary and one-time grants and temporary website exceptions are never part of a backup.
  if(setup[@"shieldPermissions"]){NSArray *standing=MYBShieldValidatedPermanent(setup[@"shieldPermissions"]);if(!standing||!MYBShieldReplacePermanent(MYBShieldPermissionsFile(),standing))return 73;}
  int result=MYBStashDuplicateComponent(SetupCCPath(YES),SetupCCPath(NO),ccStash);if(result)return result;
  if(oldCC!=wantCC){result=setCCModule(wantCC?@"on":@"off");if(result)return result;changedCC=YES;}
  if(wantSup!=oldSup){result=setLegacySupervision(wantSup);if(result)return result;}
  // The runtime is rebuilt from the restored canonical data; nothing from the backup is ever linked.
  updateMarkers(mode,wantActive);
  result=wantActive?MYBSetPACEnabled(YES):(ownedLink()?MYBSetPACEnabled(NO):0);if(result)return result;
  if(wantActive)touch(KSystemOptIn);
  return restartConfigd();
 });
 if(rc){if(changedCC)setCCModule(oldCC?@"on":@"off");int ccRollback=MYBRestoreComponentStash(SetupCCPath(NO),ccStash);if(ccRollback)logLine(@"RESTORE: component duplicate rollback needs repair; quarantined originals retained");else [FM() removeItemAtPath:componentStash error:NULL];updateMarkers(oldMode,oldActive);if(oldLink)MYBApplyRuntime(validMode(oldMode)||[oldMode isEqual:@"Custom"]?oldMode:@"Default");else if(ownedLink())MYBRemoveRuntime();restartConfigd();if(wantSup!=oldSup)signalNamedProcess("profiled",SIGKILL,NO);SetupStatus(rc,@"Restore failed; previous setup retained");return rc;}
 [FM() removeItemAtPath:componentStash error:NULL];
 chown(MYBShieldPermissionsFile().fileSystemRepresentation,501,501);for(NSString *path in values){if([path isEqual:SupervisionRecord()])continue;chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}MYBMakeFilesUserAccessible();
 notify_post("net.myxxdev.mybloxx.safariguard.changed");notify_post("net.myxxdev.mybloxx.speedyads.changed");writeSupervisionStatus();
 {int filter=MYBWriteAdsFilter();if(filter)logLine([NSString stringWithFormat:@"RESTORE: setup applied, but the loader filters could not be updated (%d); Repair MYbloXX®",filter]);}
 int backup=exportSetup(YES);if(backup)logLine(@"RESTORE: setup applied, but refreshed export could not be saved");return 0;
}
