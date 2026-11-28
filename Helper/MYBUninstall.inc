// Called by prerm before dpkg removes the native helper. This runs under the
// same operation lock and native filesystem view as enable/disable.
static NSArray *UninstallFilesFolders(void){
 NSString *root=@"/var/mobile/Containers/Shared/AppGroup";NSError *error=nil;
 NSArray *entries=[FM() contentsOfDirectoryAtPath:root error:&error];if(!entries)return nil;
 NSMutableArray *folders=[NSMutableArray array];
 for(NSString *entry in entries){
  if([entry hasPrefix:@"."]||![entry isEqual:entry.lastPathComponent])continue;
  NSString *group=[root stringByAppendingPathComponent:entry];struct stat st;
  // Match installation discovery: RootHide can expose an AppGroup via an
  // alias. Follow that group alias, then verify its MCM identifier and the
  // non-symlink Files storage/folder before touching fixed live filenames.
  if(stat(group.fileSystemRepresentation,&st)!=0||!S_ISDIR(st.st_mode))continue;
  NSDictionary *meta=[NSDictionary dictionaryWithContentsOfFile:[group stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
  if(![meta[@"MCMMetadataIdentifier"] isEqual:@"group.com.apple.FileProvider.LocalStorage"])continue;
  NSString *storage=[group stringByAppendingPathComponent:@"File Provider Storage"];
  if(lstat(storage.fileSystemRepresentation,&st)!=0){if(errno==ENOENT)continue;return nil;}
  if(!S_ISDIR(st.st_mode)||S_ISLNK(st.st_mode))return nil;
  [folders addObject:[storage stringByAppendingPathComponent:@"MYbloXX"]];
 }
 return folders;
}
static int UninstallPreserveMissingExports(NSArray *folders){
 // Existing backups and the last exported PAC must not be overwritten.
 for(NSString *folder in folders){struct stat st;if(lstat(folder.fileSystemRepresentation,&st)!=0)continue;
  if(!S_ISDIR(st.st_mode)||S_ISLNK(st.st_mode))return 73;
  NSString *settings=[folder stringByAppendingPathComponent:@"MYbloXX-Settings.plist"],*pac=[folder stringByAppendingPathComponent:@"MYbloXX.pac"];
  BOOL missingSettings=lstat(settings.fileSystemRepresentation,&st)!=0&&errno==ENOENT;
  BOOL missingPAC=lstat(pac.fileSystemRepresentation,&st)!=0&&errno==ENOENT;
  if(!missingSettings&&!missingPAC)continue;
  NSDictionary *snapshot=SetupSnapshot();if(!snapshot)return 65;
  if(missingSettings&&![snapshot writeToFile:settings atomically:YES])return 73;
  if(missingPAC){NSString *selected=snapshot[@"protection"][@"mode"];NSData *data=[selected isEqual:@"Custom"]?snapshot[@"pacs"][@"Custom"]:[NSData dataWithContentsOfFile:PACFile(selected)];if(!data||!SyntaxValid(data))data=[NSData dataWithContentsOfFile:BundledPAC(selected)];NSString *live=MYBSetupLivePAC([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],snapshot[@"rules"]);
   if(!live||![live writeToFile:pac atomically:YES encoding:NSUTF8StringEncoding error:NULL])return 73;
  }
  for(NSString *path in @[settings,pac]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
 }
 return 0;
}
static int uninstallNativeConfiguration(void){
 NSArray *folders=UninstallFilesFolders();if(!folders){logLine(@"UNINSTALL: cannot inspect native Files storage; cleanup stopped");return 78;}
 int rc=UninstallPreserveMissingExports(folders);if(rc)return rc;
 BOOL hadLease=[AppControlSession()[@"active"] boolValue]||[loadSavedState()[@"enabled"] boolValue]||occupiedNoFollow(KSystemOptIn);
 // Clear the temporary lease before notifying the loaded SpringBoard tweak.
 // In-flight/retried events then see disabled preferences and no active lease.
 if(!AppControlSave(@{@"active":@NO}))return 73;
 NSMutableDictionary *speedy=[AppControlPrefs() mutableCopy];speedy[@"Uninstalling"]=@YES;
 if(![speedy writeToFile:SetupSpeedyPrefs() atomically:YES])return 73;
 chown(SetupSpeedyPrefs().fileSystemRepresentation,501,501);chmod(SetupSpeedyPrefs().fileSystemRepresentation,0644);
 notify_post("net.myxxdev.mybloxx.speedyads.changed");
 NSMutableArray *targets=[NSMutableArray arrayWithObjects:@"/var/mobile/Media/MYbloXX/ActiveConfiguration.plist",nil];
 for(NSString *folder in folders)[targets addObject:[folder stringByAppendingPathComponent:@"MYbloXX.plist"]];
 for(NSString *name in @[@"MYbloXX.plist",@"ActiveConfiguration.plist"])[targets addObject:[MYBRoot() stringByAppendingPathComponent:name]];
 NSString *currentLink=[FM() destinationOfSymbolicLinkAtPath:ManagedPath() error:NULL];
 BOOL ownPolicy=MYBUninstallOwnedLink(currentLink,targets);
 // A retained backup from a prior uninstall is not a new adoption lease.
 // Do not resurrect it on a later fresh install which never enabled MYbloXX.
 NSString *backup=(hadLease||ownPolicy)?KPreviousManaged:nil;
 NSString *priorLink=backup?[FM() destinationOfSymbolicLinkAtPath:backup error:NULL]:nil;
 if(MYBUninstallOwnedLink(priorLink,targets))backup=nil;
 BOOL changed=NO;
 rc=MYBUninstallDetach(ManagedPath(),backup,targets,NO,&changed);if(rc)return rc;
 // Remove the generated runtime configuration (recorded targets, the protected directory, the journal).
 if(!MYBIPCleanupFiles(KInlineJournal))logLine(@"UNINSTALL: some inline runtime files could not be proven to be MYbloXX®'s and were left in place");
 [FM() removeItemAtPath:MYBDataPath(@"/var/mobile/Library/MYbloXX/InlineRecovery.plist") error:NULL];
 if(changed){rc=restartConfigd();if(rc)return rc;}
 // An App Control pause can have already detached the link. Still restore a
 // prior adopted policy, and never re-enable MYbloXX during removal.
 [FM() removeItemAtPath:KSystemOptIn error:NULL];
 rc=MYBUninstallLiveFiles(folders);if(rc)return rc;
 migrateSupervisionRecord();NSDictionary *record=[NSDictionary dictionaryWithContentsOfFile:SupervisionRecord()];
 if([record[@"owner"] isEqual:@"net.myxxdev.mybloxx"]){
  NSString *archive=[MYBDataPath(@"/var/mobile/Library/MYbloXX/Backups") stringByAppendingPathComponent:@"Supervision-before-uninstall.plist"];
  [FM() createDirectoryAtPath:archive.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
  if(![FM() fileExistsAtPath:archive]&&![FM() copyItemAtPath:SupervisionRecord() toPath:archive error:NULL])return 73;
  NSDictionary *state=MYBSupervisionStatus(SupervisionPath(),SupervisionRecord());
  if([state[@"supervised"] boolValue]){rc=MYBChangeSupervision(NO,SupervisionPath(),SupervisionRecord());if(rc)return rc;signalNamedProcess("profiled",SIGKILL,NO);}
  else [FM() removeItemAtPath:SupervisionRecord() error:NULL];
 }
 for(NSString *path in @[@"/var/mobile/Media/MYbloXX/ActiveConfiguration.plist",jbroot(@"/var/mobile/Media/MYbloXX/ActiveConfiguration.plist"),[MYBRoot() stringByAppendingPathComponent:@"MYbloXX.plist"],[MYBRoot() stringByAppendingPathComponent:@"ActiveConfiguration.plist"]]){struct stat st;if(lstat(path.fileSystemRepresentation,&st)==0){if(!S_ISREG(st.st_mode)&&!S_ISLNK(st.st_mode))return 73;if(![FM() removeItemAtPath:path error:NULL])return 73;}}
 // dpkg removes the installed payload. Remove runtime relocations which dpkg
 // cannot track after a user disabled a companion or Control Center module.
 for(NSString *path in @[[MYBBootstrapRoot() stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries/YouTopia.dylib"],[MYBBootstrapRoot() stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries/YouTopia.plist"],[MYBBootstrapRoot() stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries/YouTopia.disabled"],[MYBBootstrapRoot() stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries/MYbloXX-WAO.dylib"],[MYBBootstrapRoot() stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries/MYbloXX-WAO.plist"],[MYBBootstrapRoot() stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries/MYbloXX-WAO.disabled"],[MYBBootstrapRoot() stringByAppendingPathComponent:@"usr/share/mybloxx/modules/YouTopia.dylib"],SetupCCPath(NO),[MYBRoot() stringByAppendingPathComponent:@"YouTopia.enabled"],[MYBRoot() stringByAppendingPathComponent:@"YouTopia.disabled"],[MYBRoot() stringByAppendingPathComponent:@"Status/LegacySpoofed"]]){
  if(occupiedNoFollow(path)&&![FM() removeItemAtPath:path error:NULL])return 73;
 }
 for(NSString *name in @[@"State.plist",@"AppControlSession.plist",@"AppControlStatus.plist",@"Status/Active",@"B25SystemPACOptIn"]){NSString *path=MYBDataPath([@"/var/mobile/Library/MYbloXX" stringByAppendingPathComponent:name]);if(occupiedNoFollow(path)&&![FM() removeItemAtPath:path error:NULL])return 73;}
 // User rules, PAC stores and all backups remain inert and recoverable.
 logLine(@"UNINSTALL: native policy detached, live Files plist removed, backups and last PAC retained");
 return 0;
}
