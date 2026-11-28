#import <Foundation/Foundation.h>
#import <roothide.h>
#import <notify.h>
#import "../Shared/MYBSupervision.h"
#import "../Shared/MYBEffectivePAC.h"
#import "../Shared/MYBInlinePAC.h"
#import "../Shared/MYBWebsiteTransaction.h"
#import "../Shared/MYBRuleStore.h"
#import "../Shared/MYBSetupBackup.h"
#import "../Shared/MYBStorage.h"
#import "../Shared/MYBProfiles.h"
#import "../Shared/MYBAppControl.h"
#import "../Shared/MYBRecoveryThrottle.h"
#import "../Shared/MYBHelperArgs.h"
#import <notify.h>
#import "../Shared/MYBUninstall.h"
#import <CFNetwork/CFNetwork.h>
#import <spawn.h>
#import <sys/stat.h>
#import <sys/file.h>
#import <fcntl.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <CommonCrypto/CommonDigest.h>
#import <sys/wait.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <dlfcn.h>
#import <errno.h>
#import <string.h>
#import <signal.h>
#import <stdlib.h>
#import <mach-o/dyld.h>
#import <sys/sysctl.h>
#import "../Shared/MYBProcessRefresh.h"
extern char **environ;
#ifdef MYB_HELPER_TESTING
// Test seams (compiled only into the native helper test, never into the shipped helper): the real helper code runs
// against a fixture root; the three things that touch the live system are injected - configd restarts, the managed
// parent check, and network fetches - so apply FAILURES can be produced on demand.
int gMYBTestRestartResult=0,gMYBTestRestarts=0,gMYBTestWebKitRefreshes=0;
NSString *gMYBTestFilesFolder=nil; // test-only: stands in for the Files app MYbloXX folder
int gMYBTestLockFD=-1;      // the operation lock the real entry point took (the test closes it between invocations)
BOOL gMYBTestPretendRoot=NO; // the test process is not root; the entry point is otherwise unchanged
#define MYB_EUID() (gMYBTestPretendRoot?0:geteuid())
NSData *(^gMYBTestFetch)(NSString *url)=nil;
#endif

static NSString *MYBRoot(void) {
 static NSString *cached=nil;
 static dispatch_once_t once;
 dispatch_once(&once,^{
  uint32_t size=0;
  _NSGetExecutablePath(NULL,&size);
  if(size>0 && size<32768) {
   char *buf=calloc((size_t)size+1,1);
   if(buf && _NSGetExecutablePath(buf,&size)==0) {
    NSString *path=[NSString stringWithUTF8String:buf];
    cached=[[path stringByStandardizingPath] stringByDeletingLastPathComponent];
   }
   free(buf);
  }
 });
 return cached?:@"/var/jb/usr/sbin/MYXXdev/MYbloXX";
}
static NSString *MYBBootstrapRoot(void) {
#ifdef MYB_HELPER_TESTING
 if(getenv("MYB_TEST_BOOTSTRAP"))return @(getenv("MYB_TEST_BOOTSTRAP"));
#endif
 NSString *dir=MYBRoot();
 NSRange r=[dir rangeOfString:@"/usr/sbin/MYXXdev/MYbloXX" options:NSBackwardsSearch];
 if(r.location!=NSNotFound){ NSString *root=[dir substringToIndex:r.location];return root.length?root:@"/"; }
 return @"/var/jb";
}
static NSFileManager *FM(void);
static void logLine(NSString *s);
static NSString *ManagedPath(void) {
 // Original MYbloXX system-visible managed preferences entry.
 // RootHide helper accesses original iOS via /rootfs/private/var, not its own /private/var.
 return @"/var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist";
}
// Original MYbloXX B5 Files-app location. Resolve the current LocalStorage
// AppGroup by its metadata identifier; never hardcode a UUID or jailbroken
// bootstrap location.
// Resolve the actual Files / On My iPhone AppGroup by Apple's metadata.
// B27 accidentally required "File Provider Storage" to exist *before*
// activation. The original B5 installer discovered the AppGroup, then
// created MYbloXX under its storage. Don't hardcode the randomized UUID.
static NSString *MYBFilesFolder(void) {
#ifdef MYB_HELPER_TESTING
 if(gMYBTestFilesFolder)return gMYBTestFilesFolder;
#endif
 NSString *containerRoot=@"/var/mobile/Containers/Shared/AppGroup";
 NSError *listError=nil;
 NSArray<NSString *> *entries=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:containerRoot error:&listError];
 if(!entries) {
  logLine([NSString stringWithFormat:@"FILES_DISCOVERY: AppGroup directory unavailable: %@",listError.localizedDescription]);
  return nil;
 }
 for(NSString *entry in entries) {
  if([entry hasPrefix:@"."])continue;
  NSString *group=[containerRoot stringByAppendingPathComponent:entry];
  NSString *meta=[group stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
  NSDictionary *metadata=[NSDictionary dictionaryWithContentsOfFile:meta];
  if(![metadata isKindOfClass:NSDictionary.class])continue;
  NSString *identifier=metadata[@"MCMMetadataIdentifier"];
  if(![identifier isKindOfClass:NSString.class] ||
     ![identifier isEqualToString:@"group.com.apple.FileProvider.LocalStorage"])continue;
  NSString *storage=[group stringByAppendingPathComponent:@"File Provider Storage"];
  struct stat st;
  if(lstat(storage.fileSystemRepresentation,&st)==0 && (!S_ISDIR(st.st_mode)||S_ISLNK(st.st_mode))) {
   logLine([NSString stringWithFormat:@"FILES_DISCOVERY: unsafe provider storage %@",storage]);
   return nil;
  }
  return [storage stringByAppendingPathComponent:@"MYbloXX"];
 }
 logLine([NSString stringWithFormat:@"FILES_DISCOVERY: LocalStorage AppGroup not found among %lu entries",(unsigned long)entries.count]);
 return nil;
}
static BOOL MYBFilesFolderIsSafe(NSString *folder) {
#ifdef MYB_HELPER_TESTING
 if(gMYBTestFilesFolder&&[folder isEqual:gMYBTestFilesFolder]){struct stat tst;return !(lstat(folder.fileSystemRepresentation,&tst)==0&&!S_ISDIR(tst.st_mode));}
#endif
 if(![folder hasPrefix:@"/var/mobile/Containers/Shared/AppGroup/"] ||
    ![folder hasSuffix:@"/File Provider Storage/MYbloXX"])return NO;
 struct stat st;
 if(lstat(folder.fileSystemRepresentation,&st)==0 && !S_ISDIR(st.st_mode))return NO;
 return YES;
}
static void MYBMakeFilesUserAccessible(void) {
 NSString *folder=MYBFilesFolder();
 if(!MYBFilesFolderIsSafe(folder))return;
 chown(folder.fileSystemRepresentation,501,501);
 NSString *plist=[folder stringByAppendingPathComponent:@"MYbloXX.plist"];
 NSString *readme=[folder stringByAppendingPathComponent:@"README.txt"];
 chown(plist.fileSystemRepresentation,501,501);
 chmod(plist.fileSystemRepresentation,0644);
 chown(readme.fileSystemRepresentation,501,501);
 chmod(readme.fileSystemRepresentation,0644);
}
static NSString *MYBFilesPlist(void) {
 NSString *folder=MYBFilesFolder();
 return folder?[folder stringByAppendingPathComponent:@"MYbloXX.plist"]:nil;
}
static void MYBMakeFilesUserAccessible(void);
static BOOL MYBFilesFolderIsSafe(NSString *folder);
static BOOL MYBEnsureSystemManagedParent(void) {
#ifdef MYB_HELPER_TESTING
 return YES;
#endif
 // This is a NATIVE Objective-C process, not a procursus shell under
 // libvroot. The original iOS directory is /var/Managed Preferences/mobile.
 // RootHide bootstrap commands instead expose that as /rootfs/var/... .
 // Never prepend /rootfs to native paths or install a bootstrap-local link.
 NSString *bootstrap=jbroot(@"/");
 NSString *managed=ManagedPath();
 if(![bootstrap containsString:@"/.jbroot-"] ||
    ![managed isEqualToString:@"/var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist"]){
  logLine(@"STOCK_PATH_CHECK: not the expected native managed-preferences path");
  return NO;
 }
 struct stat parentSt={0};
 NSString *parent=[managed stringByDeletingLastPathComponent];
 if(lstat(parent.fileSystemRepresentation,&parentSt)!=0 ||
    !S_ISDIR(parentSt.st_mode) || S_ISLNK(parentSt.st_mode)){
  logLine([NSString stringWithFormat:@"STOCK_PATH_CHECK: native parent missing/unsafe %@ errno=%d",parent,errno]);
  return NO;
 }
 // A bootstrap-side /var/Managed Preferences directory must not be
 // mistaken for proof that iOS can see the symlink. Test the exact native
 // path and report the resulting link separately.
 logLine([NSString stringWithFormat:@"STOCK_PATH_CHECK nativeManaged=%@ parentDev=%llu parentIno=%llu bootstrap=%@",
  managed,(unsigned long long)parentSt.st_dev,(unsigned long long)parentSt.st_ino,bootstrap]);
 return YES;
}
static NSString *MYBDataPath(NSString *logical) {
 // MYbloXX-owned state/logs belong in RootHide's writable jailbreak storage.
 // /rootfs/private/var/mobile/Library is NOT a writable preference area.
 if(!MYBStorageAllowed(logical))return nil;
 return jbroot(logical);
}
#define KStatus MYBDataPath(@"/var/mobile/Library/MYbloXX/Status")
#define KState MYBDataPath(@"/var/mobile/Library/MYbloXX/State.plist")
#define KLegacyPlist MYBFilesPlist()
#define KInlineJournal MYBDataPath(@"/var/mobile/Library/MYbloXX/InlineRuntime.plist")
#define KLog MYBDataPath(@"/var/mobile/Library/MYbloXX/control.log")
#define KSystemOptIn MYBDataPath(@"/var/mobile/Library/MYbloXX/B25SystemPACOptIn")
static NSFileManager *FM(void) {return [NSFileManager defaultManager];}
static NSString *selectedMode(void);
static void updateMarkers(NSString *mode,BOOL active);
static int saveState(NSString *mode,BOOL enabled);
static BOOL SyntaxValid(NSData *data);
static void logLine(NSString *s) {
 NSString *dir=[KLog stringByDeletingLastPathComponent];
 [FM() createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *line=[NSString stringWithFormat:@"%@ %@\n",[NSDate date],s];
 if(![FM() fileExistsAtPath:KLog])[FM() createFileAtPath:KLog contents:[NSData data] attributes:nil];
 NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:KLog];
 if(h) { @try { [h seekToEndOfFile];[h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];[h closeFile]; } @catch(__unused NSException *e) {} }
 fprintf(stderr,"%s\n",s.UTF8String);
}
static int errorCode(NSString *where,NSError *e,int code) {
 logLine([NSString stringWithFormat:@"%@: %@",where,e.localizedDescription?:@"error"]);return code;
}
// A managed link MYbloXX may manage: its own inline-PAC runtime link, or the B50 link to the
// Files-app plist (migrated on first use). Anything else belongs to someone else.
static BOOL ownedLink(void) {
 MYBIPLinkKind kind=MYBIPClassifyLink(NULL);
 return kind==MYBIPLinkOwned||kind==MYBIPLinkLegacy;
}
// "Active" is real protection only: an owned link AND an intact inline PAC target.
static BOOL MYBActiveFlag(void) {return MYBRuntimeEnabled();}
// Safe install-time preparation: make sure the Files-app MYbloXX folder (settings backups and
// the exported PAC) exists. It no longer holds any system configuration.
static int MYBPrepareFilesStorage(void) {
 NSString *files=MYBFilesFolder();
 if(!files.length || !MYBFilesFolderIsSafe(files)){
  logLine(@"FILES_PREPARE: verified LocalStorage AppGroup not found");
  return 78;
 }
 NSError *folderError=nil;
 if(![FM() createDirectoryAtPath:files withIntermediateDirectories:YES attributes:nil error:&folderError]){
  logLine([NSString stringWithFormat:@"FILES_PREPARE: failed to create Files folder: %@",folderError]);
  return 73;
 }
 MYBMakeFilesUserAccessible();
 return 0;
}
// Compatibility command for old installers: only prepares the Files folder.
static int MYBInstallDisabledLink(void) {
 return MYBPrepareFilesStorage();
}
static BOOL managedOccupied(void) {
 struct stat st;return lstat(MYBIPManagedPath().fileSystemRepresentation,&st)==0;
}
// One-time migration from B14-B17 RootHide bootstrap-local state to the
// real iOS data partition. This corrects status/UI disagreement after
// rejailbreaking without resetting a user's existing enabled preference.
static void migrateOldBootstrapState(void) {
 NSString *legacy=jbroot(@"/var/mobile/Library/MYbloXX");
 NSString *real=MYBDataPath(@"/var/mobile/Library/MYbloXX/State.plist");
 real=[real stringByDeletingLastPathComponent];
 if([legacy isEqualToString:real])return;
 NSFileManager *fm=FM();
 NSError *err=nil;
 if(![fm fileExistsAtPath:legacy])return;
 [fm createDirectoryAtPath:real withIntermediateDirectories:YES attributes:nil error:&err];
 if(err){logLine([NSString stringWithFormat:@"State migration directory: %@",err]);return;}
 for(NSString *name in @[@"State.plist",@"ActiveConfiguration.plist",@"control.log"]) {
   NSString *from=[legacy stringByAppendingPathComponent:name];
   NSString *to=[real stringByAppendingPathComponent:name];
   if(![fm fileExistsAtPath:from] || [fm fileExistsAtPath:to])continue;
   NSError *copyError=nil;
   if([fm copyItemAtPath:from toPath:to error:&copyError])
     logLine([NSString stringWithFormat:@"Migrated previous RootHide data: %@",name]);
   else logLine([NSString stringWithFormat:@"Couldn't migrate %@: %@",name,copyError]);
 }
 NSString *fromStatus=[legacy stringByAppendingPathComponent:@"Status"];
 NSString *toStatus=[real stringByAppendingPathComponent:@"Status"];
 if([fm fileExistsAtPath:fromStatus] && ![fm fileExistsAtPath:toStatus]){
   NSError *copyError=nil;
   if([fm copyItemAtPath:fromStatus toPath:toStatus error:&copyError])
     logLine(@"Migrated original RootHide status markers");
   else logLine([NSString stringWithFormat:@"Status migration: %@",copyError]);
 }
}
static NSDictionary *loadSavedState(void) {
 NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:KState];
 return [state isKindOfClass:[NSDictionary class]]?state:@{};
}
static int saveState(NSString *mode,BOOL enabled) {
 NSError *error=nil;
 if(![FM() createDirectoryAtPath:[KState stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error])
   return errorCode(@"Cannot create persistent state folder",error,73);
 NSMutableDictionary *state=[loadSavedState() mutableCopy];
 state[@"enabled"]=@(enabled);
 if(mode.length)state[@"mode"]=mode;
 state[@"lastUpdated"]=[NSDate date];
 if(![state writeToFile:KState atomically:YES])
   return errorCode(@"Cannot persist MYbloXX® preferences",nil,73);
 return 0;
}

static NSString *PACDirectory(void) {
 NSString *current=MYBDataPath(@"/var/mobile/Library/MYbloXX/PACCurrent");
 if([FM() fileExistsAtPath:current])return current;
 return MYBDataPath(@"/var/mobile/Library/MYbloXX/PAC");
}
static NSString *PACFile(NSString *mode) {
 return [PACDirectory() stringByAppendingPathComponent:[mode stringByAppendingString:@".pac"]];
}
static NSString *BundledPAC(NSString *mode) {
 return [MYBBootstrapRoot() stringByAppendingPathComponent:
   [NSString stringWithFormat:@"usr/share/mybloxx/pacs/%@.pac",mode]];
}
static BOOL filePACValid(NSString *filename) {
 NSData *data=[NSData dataWithContentsOfFile:filename options:0 error:NULL];
 if(data.length<100 || data.length>2*1024*1024)return NO;
 NSString *script=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
 return [script containsString:@"function FindProxyForURL"];
}
static NSArray<NSString *> *modes(void) {
 return MYBModeIDs(); // Default plus every combination of the five options (Shared/MYBOptions.h)
}
static BOOL validMode(NSString *m) {return [modes() containsObject:m];}
static NSString *selectedMode(void) {
 for(NSString *m in modes())if([FM() fileExistsAtPath:[KStatus stringByAppendingPathComponent:m]])return m;
 NSString *saved=MYBMigrateModeID(loadSavedState()[@"mode"]);
 if(saved.length)return saved;
 return @"Default";
}
// Saved-mode migration: a mode saved by an earlier release (historical PAC name, label, unordered set) is rewritten once as
// its current identifier. Only the mode key changes; the enabled/off intent is carried over exactly as it was.
static int migrateSavedMode(void){
 NSDictionary *state=loadSavedState();id raw=state[@"mode"];if(![raw isKindOfClass:NSString.class])return 0;
 NSString *to=MYBMigrateModeID(raw);
 if(!to.length){logLine([NSString stringWithFormat:@"MODE_MIGRATION: saved mode %@ is not recognised; Default is used until a mode is chosen",[raw length]>40?[raw substringToIndex:40]:raw]);return 0;}
 if([to isEqual:raw])return 0;
 int rc=saveState(to,[state[@"enabled"] boolValue]);
 logLine([NSString stringWithFormat:@"MODE_MIGRATION: saved mode %@ is now %@ (%@)",raw,to,rc?@"not saved":@"saved"]);return rc;
}
static BOOL touch(NSString *path) {
 return [FM() createFileAtPath:path contents:[NSData data] attributes:nil];
}
static void updateMarkers(NSString *mode,BOOL active) {
 [FM() createDirectoryAtPath:KStatus withIntermediateDirectories:YES attributes:nil error:NULL];
 for(NSString *m in [modes() arrayByAddingObjectsFromArray:@[@"Custom",@"Proxy",@"Legacy"]])[FM() removeItemAtPath:[KStatus stringByAppendingPathComponent:m] error:NULL];
 if(mode)touch([KStatus stringByAppendingPathComponent:mode]);
 if(active)touch([KStatus stringByAppendingPathComponent:@"Active"]);
 else [FM() removeItemAtPath:[KStatus stringByAppendingPathComponent:@"Active"] error:NULL];
}
// ---- inline-PAC runtime (the single privileged apply path) ------------------------------------
// Durable intent lives in State.plist (enabled + mode), the rules files and PAC sets. The
// effective PAC is regenerated from them on demand and embedded in a temporary runtime plist.
static NSString *MYBEffectiveScript(NSString *mode) {
 if(!(validMode(mode)||[mode isEqual:@"Custom"]))return nil;
 NSString *root=MYBDataPath(@"/var/mobile/Library/MYbloXX");
 if(!root.length)return nil;
 NSString *script=MYBEffectivePACText(mode,@[
  [root stringByAppendingPathComponent:@"PACCurrent"],
  [root stringByAppendingPathComponent:@"PAC"],
  [MYBBootstrapRoot() stringByAppendingPathComponent:@"usr/share/mybloxx/pacs"]],
  [root stringByAppendingPathComponent:@"AppliedRules.plist"],MYBWebsiteFile());
 if(!script||!SyntaxValid([script dataUsingEncoding:NSUTF8StringEncoding]))return nil;
 return script;
}
// The B50 Files-app plist and README are generated files that nothing references any more.
static void MYBRetireLegacyFilesConfig(void) {
 if(MYBIPClassifyLink(NULL)==MYBIPLinkLegacy)return;
 NSString *folder=MYBFilesFolder();
 if(!folder.length||!MYBFilesFolderIsSafe(folder))return;
 NSString *plist=[folder stringByAppendingPathComponent:@"MYbloXX.plist"];
 struct stat st;
 if(lstat(plist.fileSystemRepresentation,&st)==0&&S_ISREG(st.st_mode)){
  NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:plist];
  NSDictionary *p=[root[@"Proxies"] isKindOfClass:NSDictionary.class]?root[@"Proxies"]:nil;
  NSString *url=[p[@"ProxyAutoConfigURLString"] isKindOfClass:NSString.class]?p[@"ProxyAutoConfigURLString"]:@"";
  // Only MYbloXX's own localhost PAC configuration is ever removed.
  if(p&&[url hasPrefix:@"http://127.0.0.1:8787/"]){
   unlink(plist.fileSystemRepresentation);
   NSString *readme=[folder stringByAppendingPathComponent:@"README.txt"];
   NSString *text=[NSString stringWithContentsOfFile:readme encoding:NSUTF8StringEncoding error:NULL];
   if([text hasPrefix:@"MYbloXX system"])unlink(readme.fileSystemRepresentation);
   unlink([plist stringByAppendingString:@".previous"].fileSystemRepresentation);
   logLine(@"INLINE_PAC: retired the obsolete Files-app PAC-URL configuration");
  }
 }
}
// Build and apply the effective PAC for `mode`. Replaces whatever owned configuration exists
// (including the B50 URL link) in one journaled, verified transaction.
// The device experiment (inlinepac*) keeps its own state; while it is active production must not
// touch the managed link at all.
static BOOL MYBExperimentActive(void) {
 NSString *path=MYBDataPath(@"/var/mobile/Library/MYbloXX/InlinePACExperiment/state.plist");
 NSDictionary *state=path?[NSDictionary dictionaryWithContentsOfFile:path]:nil;
 if(![state isKindOfClass:NSDictionary.class])return NO;
 return [state[@"active"] boolValue]||[state[@"linkExperimental"] boolValue];
}
// Root-verified status for sandboxed readers (Settings). Written after every command and by the watcher.
// Publishes what Settings may show. Structural state is cheap and written every time. The verification
// (expected-rule identity + the system's effective proxy settings) builds the effective PAC, so it is only redone
// when forced (a helper command just ran), when the last result is older than 60 s, or - while it is not yet
// "applied" - every 8 s so a fresh apply is confirmed promptly. Settings only ever reads this record.
static void MYBPublishRuntimeStatusForce(BOOL force) {
 NSString *path=MYBDataPath(@"/var/mobile/Library/MYbloXX/RuntimeStatus.plist");if(!path.length)return;
 NSDictionary *s=MYBRuntimeStatus(),*previous=[NSDictionary dictionaryWithContentsOfFile:path]?:@{};
 NSMutableDictionary *record=[@{@"state":s[@"state"]?:@"error",@"destination":s[@"destination"]?:@"",@"time":[NSDate date]} mutableCopy];
 if([s[@"state"] isEqual:@"configured"]){
  NSDate *last=[previous[@"verifiedAt"] isKindOfClass:NSDate.class]?previous[@"verifiedAt"]:nil;NSTimeInterval age=last?[[NSDate date] timeIntervalSinceDate:last]:1e9;
  BOOL same=[previous[@"destination"] isEqual:s[@"destination"]],applied=[previous[@"verification"] isEqual:@"applied"];
  if(force||!same||age<0||age>60||(!applied&&age>8)){
   NSString *mode=selectedMode(),*script=mode.length?MYBEffectiveScript(mode):nil;
   CFDictionaryRef proxies=CFNetworkCopySystemProxySettings();NSDictionary *effective=proxies?CFBridgingRelease(proxies):nil;
   NSDictionary *v=MYBRuntimeVerify(s,script?MYBRuntimeSHA256(script):nil,effective);
   record[@"verification"]=v[@"verification"];record[@"verifiedAt"]=[NSDate date];
  }else if(previous[@"verification"]){record[@"verification"]=previous[@"verification"];record[@"verifiedAt"]=previous[@"verifiedAt"];}
 }
 [FM() createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 { struct stat dst;if(stat(path.stringByDeletingLastPathComponent.fileSystemRepresentation,&dst)==0&&(dst.st_mode&0005)!=0005)chmod(path.stringByDeletingLastPathComponent.fileSystemRepresentation,(dst.st_mode&07777)|0755); } // the sandboxed reader must be able to traverse to the record
 if([record writeToFile:path atomically:YES]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);notify_post("net.myxxdev.mybloxx.statuschanged");}
}
static void MYBPublishRuntimeStatus(void){MYBPublishRuntimeStatusForce(NO);}
static int MYBApplyRuntime(NSString *mode) {
 if(MYBExperimentActive()){logLine(@"INLINE_PAC: the inline-PAC experiment is active; run its rollback before using MYbloXX®");return 3;}
 if(!MYBEnsureSystemManagedParent())return 78;
 NSString *script=MYBEffectiveScript(mode);
 if(!script){logLine([NSString stringWithFormat:@"INLINE_PAC: no valid effective PAC for %@; protection not applied",mode]);return 69;}
 NSString *why=nil;
 int rc=MYBIPApply(script,mode,KInlineJournal,KLegacyPlist,&why);
 if(rc){logLine([NSString stringWithFormat:@"INLINE_PAC: apply %@ rc=%d: %@",mode,rc,why?:@""]);return rc==2?3:73;}
 MYBRetireLegacyFilesConfig();
 logLine([NSString stringWithFormat:@"INLINE_PAC: applied %@ (%lu bytes) as a verified inline PAC",mode,(unsigned long)script.length]);
 return 0;
}
static int MYBRemoveRuntime(void) {
 NSString *why=nil;
 int rc=MYBIPDetach(KInlineJournal,&why);
 if(rc){logLine([NSString stringWithFormat:@"INLINE_PAC: detach rc=%d: %@",rc,why?:@""]);return rc==2?3:73;}
 MYBRetireLegacyFilesConfig();
 return 0;
}
// Enable/disable the protection. Enable regenerates the selected mode's effective PAC.
static int MYBSetPACEnabled(BOOL enable) {
 if(!MYBEnsureSystemManagedParent())return 78;
 if(!enable)return MYBRemoveRuntime();
 NSString *mode=selectedMode();
 if(!validMode(mode)&&![mode isEqual:@"Custom"])mode=@"Default";
 return MYBApplyRuntime(mode);
}
// Rules, exceptions, updates and restores call this: when MYbloXX's link is installed the
// new effective PAC is applied; when protection is off or paused nothing is written.
static int MYBReapplyIfLinked(void) {
 if(!ownedLink())return 0;
 return MYBSetPACEnabled(YES);
}
static int configure(NSString *mode) {
 if(!validMode(mode))return 64;
 if([@[@"Custom",@"Proxy"] containsObject:mode]) {
  logLine(@"Custom and Proxy are not selectable modes; use Custom Rules or Proxy Override.");
  return 79;
 }
 if(managedOccupied()&&!ownedLink()){
  logLine(@"An unrelated managed proxy configuration exists. Refusing to replace it.");return 3;
 }
 int rc=MYBApplyRuntime(mode);
 if(rc)return rc;
 updateMarkers(mode,YES);
 int stateRC=saveState(mode,YES);
 if(stateRC)return stateRC;
 logLine([NSString stringWithFormat:@"Activated %@ inline PAC",mode]);return 0;
}

static BOOL SyntaxValid(NSData *data);
static int restartConfigd(void);
static int configureManual(NSString *kind,NSString *input){
 if(![kind isEqual:@"proxy"])return 79;
 NSURLComponents *url=[NSURLComponents componentsWithString:input];
 NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_:[]"].invertedSet;
 if(![url.scheme.lowercaseString isEqual:@"http"]||!url.host.length||url.host.length>253||url.port.integerValue<1||url.port.integerValue>65535||url.user.length||url.password.length||url.query.length||url.fragment.length||(url.path.length&&![url.path isEqual:@"/"])||[url.host rangeOfCharacterFromSet:bad].location!=NSNotFound)return 64;
 if(managedOccupied()&&!ownedLink())return 3;
 NSString *host=url.host;if([host containsString:@":"]&&![host hasPrefix:@"["])host=[NSString stringWithFormat:@"[%@]",host];
 NSString *script=[NSString stringWithFormat:@"function FindProxyForURL(url,host){return \"PROXY %@:%ld\";}\n",host,(long)url.port.integerValue];
 NSData *pac=[script dataUsingEncoding:NSUTF8StringEncoding];if(!SyntaxValid(pac))return 65;
 NSString *custom=PACFile(@"Custom");BOOL linked=ownedLink();NSString *oldMode=selectedMode();BOOL wasEnabled=[loadSavedState()[@"enabled"] boolValue];
 NSMutableDictionary *prior=[NSMutableDictionary dictionary];for(NSString *path in @[custom,KState]){NSData *data=[NSData dataWithContentsOfFile:path];if(data)prior[path]=data;}
 if(![FM() createDirectoryAtPath:custom.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL])return 73;
 int rc=[pac writeToFile:custom atomically:YES]?0:73;
 if(!rc)rc=MYBApplyRuntime(@"Custom");
 if(!rc){updateMarkers(@"Custom",YES);rc=saveState(@"Custom",YES);}
 // The new configuration only counts once the system has been told about it. A failed configd restart used to leave the
 // override installed while reporting an error; now it is treated like any other failed apply and undone.
 if(!rc){touch(KSystemOptIn);rc=restartConfigd();}
 if(rc){
  for(NSString *path in @[custom,KState]){if(prior[path])[prior[path] writeToFile:path atomically:YES];else[FM() removeItemAtPath:path error:NULL];}
  // Return the runtime to exactly what it was: previous mode, or detached.
  int back=0;
  if(linked)back=MYBApplyRuntime(validMode(oldMode)||[oldMode isEqual:@"Custom"]?oldMode:@"Default");else back=MYBRemoveRuntime();
  updateMarkers(oldMode,linked&&wasEnabled);
  if(!back)restartConfigd(); // best effort: tell the system about the restored configuration too
  // Reconcile: the previous configuration must actually be back (owned link and its PAC, or no MYbloXX link at all).
  NSString *restoredMode=validMode(oldMode)||[oldMode isEqual:@"Custom"]?oldMode:@"Default";
  BOOL restored=linked?(ownedLink()&&(!wasEnabled||[MYBIPRecoveryAction(YES,MYBEffectiveScript(restoredMode)) isEqual:@"ok"])):!ownedLink();
  if(back||!restored){logLine([NSString stringWithFormat:@"PROXY_OVERRIDE: apply failed (%d) and the previous configuration could not be fully restored (%d); use Repair",rc,back]);return 94;}
  logLine([NSString stringWithFormat:@"PROXY_OVERRIDE: apply failed (%d); the previous configuration was restored",rc]);
  return rc;
 }
 chown(custom.fileSystemRepresentation,501,501);chmod(custom.fileSystemRepresentation,0644);return 0;
}

static NSArray<NSString *> *validateDomainList(NSString *input) {
 NSMutableArray<NSString *> *result=[NSMutableArray array];
 if(input.length>25400)return nil;
 NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
 for(NSString *raw in [input componentsSeparatedByString:@","]) {
   NSString *domain=[[raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
   if(!domain.length)continue;
   if(domain.length>253 || [domain hasPrefix:@"."] || [domain hasSuffix:@"."] || [domain containsString:@".."] || [domain rangeOfString:@"."].location==NSNotFound ||
      [domain rangeOfCharacterFromSet:[allowed invertedSet]].location!=NSNotFound)return nil;
   if(![result containsObject:domain])[result addObject:domain];
   if(result.count>20000)return nil;
 }
 return result;
}
static NSString *pacTest(NSArray<NSString *> *domains,NSString *outcome) {
 NSMutableArray *terms=[NSMutableArray array];
 for(NSString *domain in domains) {
   [terms addObject:[NSString stringWithFormat:@"(h===\"%@\"||dnsDomainIs(h,\".%@\"))",domain,domain]];
 }
 if(!terms.count)return @"";
 return [NSString stringWithFormat:@"if(%@)return %@;",[terms componentsJoinedByString:@"||"],outcome];
}
static BOOL SyntaxValid(NSData *data);
static NSString *customPACScript(NSString *base,NSArray *blocked,NSArray *allowed){
 if(!blocked.count && !allowed.count)return base;
 NSRegularExpression *declaration=[NSRegularExpression regularExpressionWithPattern:@"function\\s+FindProxyForURL\\s*\\(" options:0 error:NULL];
 if([declaration numberOfMatchesInString:base options:0 range:NSMakeRange(0,base.length)]!=1)return nil;
 NSString *renamed=[declaration stringByReplacingMatchesInString:base options:0 range:NSMakeRange(0,base.length) withTemplate:@"function MYBBaseFindProxyForURL("];
 NSString *rules=[pacTest(allowed,@"\"DIRECT\"") stringByAppendingString:pacTest(blocked,@"\"PROXY 127.0.0.1:8021\"")];
 NSString *wrapper=[NSString stringWithFormat:@"\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();%@return MYBBaseFindProxyForURL(url,host); }\n",rules];
 return [renamed stringByAppendingString:wrapper];
}
static __attribute__((unused)) int generateCustomPAC(NSString *blockCSV,NSString *allowCSV) {
 NSArray *blocked=validateDomainList(blockCSV);
 NSArray *allowed=validateDomainList(allowCSV);
 if(!blocked || !allowed) {
   logLine(@"Custom rules must contain valid DNS domain names without URL protocols; empty lists are allowed.");
   return 64;
 }
 NSError *err=nil;
 NSString *original=filePACValid(PACFile(@"Default"))?PACFile(@"Default"):BundledPAC(@"Default");
 NSData *data=[NSData dataWithContentsOfFile:original options:0 error:&err];
 if(!data || data.length<100 || data.length>2*1024*1024)
   return errorCode(@"Local Default PAC missing or invalid (no internet download attempted)",err,69);
 NSString *text=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
 NSString *updated=customPACScript(text,blocked,allowed);
 if(!updated || !SyntaxValid([updated dataUsingEncoding:NSUTF8StringEncoding])){logLine(@"Custom PAC generation failed validation; prior rules retained");return 65;}
 [FM() createDirectoryAtPath:PACDirectory() withIntermediateDirectories:YES attributes:nil error:&err];
 NSString *output=PACFile(@"Custom");
 if(![updated writeToFile:output atomically:YES encoding:NSUTF8StringEncoding error:&err])
   return errorCode(@"Cannot save custom PAC",err,73);
 chown(output.fileSystemRepresentation,501,501);
 chmod(output.fileSystemRepresentation,0644);
 logLine([NSString stringWithFormat:@"Generated %@ with %lu blocked and %lu allowed domains",output,(unsigned long)blocked.count,(unsigned long)allowed.count]);
 return 0;
}
static NSString *ManualRulesArchive(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/ManualRules.plist");}
static int recoverManualRules(void){
 NSString *archive=ManualRulesArchive();if(!archive.length)return 78;
 NSString *appliedPath=MYBDataPath(@"/var/mobile/Library/MYbloXX/AppliedRules.plist");
 NSDictionary *applied=[NSDictionary dictionaryWithContentsOfFile:appliedPath];
 NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:archive];
 if(!MYBValidRuleDictionary(saved)){
  NSString *folder=MYBFilesFolder();NSDictionary *setup=folder?[NSDictionary dictionaryWithContentsOfFile:[folder stringByAppendingPathComponent:@"MYbloXX-Settings.plist"]]:nil;
  if([setup[@"format"] isEqual:@"net.myxxdev.mybloxx.setup"] && MYBValidRuleDictionary(setup[@"rules"]))saved=setup[@"rules"];
  else if(folder)saved=[NSDictionary dictionaryWithContentsOfFile:[folder stringByAppendingPathComponent:@"ManualRules.plist"]];
 }
 NSDictionary *legacy=[NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/Preferences/com.apple.Preferences.plist")];
 NSDictionary *rules=MYBRecoveredRules(applied,saved,legacy,[NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()]);
 // Website exceptions are now represented in the same visible global lists.
 NSDictionary *web=@{@"domains":@[],@"revision":NSUUID.UUID.UUIDString};
 NSDictionary *values=@{appliedPath:rules,MYBDraftFile():rules,archive:rules,MYBWebsiteFile():web};
 int rc=MYBWriteRuleFiles(values,nil,nil);
 if(!rc)for(NSString *path in values){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
 return rc;
}
static int restartConfigd(void);
// Apply every custom-rule edit atomically. The PAC server layers these
// rules over ALL standard blocking modes; Shield settings are unrelated.
static int applyUserRules(NSString *blockCSV,NSString *allowCSV) {
 NSArray *blocked=validateDomainList(blockCSV),*allowed=validateDomainList(allowCSV);
 if(!blocked || !allowed || blocked.count>20000 || allowed.count>20000)return 64;
 for(NSString *domain in blocked)if([allowed containsObject:domain])return 64;
 NSString *base=filePACValid(PACFile(@"Default"))?PACFile(@"Default"):BundledPAC(@"Default");
 NSString *script=[NSString stringWithContentsOfFile:base encoding:NSUTF8StringEncoding error:NULL];
 NSString *combined=MYBUserRulesPAC(script,blocked,allowed);
 if(!combined || !SyntaxValid([combined dataUsingEncoding:NSUTF8StringEncoding])) {
  logLine(@"CUSTOM_RULES: cannot validate global overlay against Default PAC");
  return 65;
 }
 NSString *applied=MYBDataPath(@"/var/mobile/Library/MYbloXX/AppliedRules.plist");
 NSString *draft=MYBDraftFile();
 NSString *archive=ManualRulesArchive();if(!archive.length)return 78;
 NSArray *paths=@[applied,draft,MYBWebsiteFile(),archive];
 NSMutableDictionary *old=[NSMutableDictionary dictionary];
 for(NSString *path in paths){
  NSData *bytes=[NSData dataWithContentsOfFile:path];
  if(bytes)old[path]=bytes;
  if(![FM() createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL])return 73;
 }
 BOOL linked=ownedLink();
 NSDictionary *rules=@{@"blocked":blocked,@"allowed":allowed};
 int rc=0;
 for(NSString *path in paths) {
  NSDictionary *content=[path isEqualToString:MYBWebsiteFile()]?@{@"domains":@[],@"revision":NSUUID.UUID.UUIDString}:rules;
  if(![content writeToFile:path atomically:YES]){rc=73;break;}
  chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);
 }
 // One apply path: the complete effective PAC is regenerated and re-embedded.
 if(!rc && linked)rc=MYBReapplyIfLinked();
 if(!rc && linked)rc=restartConfigd();
 if(rc){
  for(NSString *path in paths) {
   NSData *bytes=old[path];
   if(bytes)[bytes writeToFile:path atomically:YES];
   else [FM() removeItemAtPath:path error:NULL];
  }
  if(linked){MYBReapplyIfLinked();restartConfigd();}
  logLine([NSString stringWithFormat:@"CUSTOM_RULES: failed rc=%d, rolled back previous rules",rc]);
  return rc;
 }
 logLine([NSString stringWithFormat:@"CUSTOM_RULES: applied %lu blocked, %lu allowed, selected mode preserved",(unsigned long)blocked.count,(unsigned long)allowed.count]);
 return 0;
}

static int setCCModule(NSString *state) {
 if(![@[@"on",@"off"] containsObject:state])return 64;
 NSString *stored=[MYBBootstrapRoot() stringByAppendingPathComponent:@"usr/share/mybloxx/modules/MYbloXXCC2.bundle"];
 NSString *active=[MYBBootstrapRoot() stringByAppendingPathComponent:@"Library/ControlCenter/Bundles/MYbloXXCC2.bundle"];
 BOOL enable=[state isEqualToString:@"on"];
 NSString *source=enable?stored:active;
 NSString *dest=enable?active:stored;
 if(![FM() fileExistsAtPath:source]) {
   if([FM() fileExistsAtPath:dest])return 0;
   logLine(@"Control Center module bundle not installed");return 74;
 }
 if([FM() fileExistsAtPath:dest])return 73;
 NSError *err=nil;
 [FM() createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&err];
 if(err)return errorCode(@"Cannot create CC module folder",err,73);
 if(![FM() moveItemAtPath:source toPath:dest error:&err])return errorCode(@"Cannot change CC module activation",err,73);
 logLine(@"MYbloXX® Control Center module state changed. Respring required; no respring forced.");
 return 0;
}
static int signalNamedProcess(const char *name,int signalNumber,BOOL mandatory);
#define KPreviousManaged MYBDataPath(@"/var/mobile/Library/MYbloXX/PreviousManagedConfiguration.plist")
static BOOL occupiedNoFollow(NSString *path) {
 struct stat st;
 return lstat(path.fileSystemRepresentation,&st)==0;
}
static BOOL restorePreviousManaged(NSString *managed) {
 if(!occupiedNoFollow(KPreviousManaged))return YES;
 if(occupiedNoFollow(managed)){
   logLine(@"Refusing to restore previous managed policy over an existing configuration");
   return NO;
 }
 NSError *error=nil;
 if(![FM() moveItemAtPath:KPreviousManaged toPath:managed error:&error]){
   logLine([NSString stringWithFormat:@"Backup restoration failed: %@",error.localizedDescription]);
   return NO;
 }
 logLine(@"Restored the previous managed policy from its backup");
 return YES;
}
static int adoptManagedConfiguration(void) {
 if(!MYBEnsureSystemManagedParent())return 78;
 NSString *managed=ManagedPath();
 if(ownedLink()) {
   logLine(@"MYbloXX® already owns the active proxy configuration");
   return 0;
 }
 NSError *error=nil;
 BOOL hadOtherConfiguration=managedOccupied();
 if(hadOtherConfiguration) {
   // A development experiment or a foreign owner is never adopted or replaced.
   NSString *dest=[FM() destinationOfSymbolicLinkAtPath:managed error:NULL];
   if(MYBIPExperimentDestination(dest)){logLine(@"The inline-PAC experiment owns the managed link; run its rollback first");return 3;}
   if(occupiedNoFollow(KPreviousManaged)) {
     logLine(@"A previous managed-profile backup exists while another policy is active. Refusing to replace either.");
     return 73;
   }
   if(![FM() copyItemAtPath:managed toPath:KPreviousManaged error:&error])
     return errorCode(@"Cannot back up existing managed profile",error,73);
   if(![FM() removeItemAtPath:managed error:&error])
     return errorCode(@"Could not remove managed profile after backup",error,73);
   logLine(@"Saved the user's pre-existing managed policy before applying MYbloXX®");
 }
 NSString *mode=selectedMode();
 if(!validMode(mode)&&![mode isEqual:@"Custom"])mode=@"Default";
 int applied=MYBApplyRuntime(mode);
 if(applied) {
   BOOL recovered=restorePreviousManaged(managed);
   logLine([NSString stringWithFormat:@"MYbloXX® activation failed; previous profile rollback %@",recovered?@"succeeded":@"FAILED"]);
   return applied;
 }
 updateMarkers(mode,YES);
 int rc=saveState(mode,YES);
 if(rc)return rc;
 logLine(@"Explicit managed-profile repair complete: prior policy backed up and MYbloXX® activated");
 return 0;
}
static int disable(void) {
 // Remove only our own link; restore a previously adopted configuration.
 if(ownedLink()) {
  int rc=MYBSetPACEnabled(NO);
  if(rc)return rc;
  if(!restorePreviousManaged(ManagedPath()))return 73;
 } else if(managedOccupied()){
  logLine(@"Refusing to disable another owner's managed configuration");
  return 3;
 }
 [FM() removeItemAtPath:[KStatus stringByAppendingPathComponent:@"Active"] error:NULL];
 int stateRC=saveState(nil,NO);
 if(stateRC)return stateRC;
 logLine(@"Disabled MYbloXX® (managed link and runtime configuration removed)");return 0;
}

// Install/upgrade: bring a B50 URL setup (or a damaged runtime) to the inline transport without
// changing what the user chose. Never touches an experiment or someone else's configuration.
static int migrateInlineRuntime(void) {
 if(MYBExperimentActive()){logLine(@"MIGRATE: the inline-PAC experiment is active; production left untouched");return 3;}
 NSString *dest=nil;MYBIPLinkKind kind=MYBIPClassifyLink(&dest);
 if(kind==MYBIPLinkExperiment||kind==MYBIPLinkForeign||kind==MYBIPLinkNotSymlink||kind==MYBIPLinkError){
  logLine([NSString stringWithFormat:@"MIGRATE: managed configuration is not MYbloXX®'s (%@); left untouched",dest?:@"unreadable"]);
  return kind==MYBIPLinkError?73:0;
 }
 NSDictionary *state=loadSavedState();
 BOOL want=[state[@"enabled"] boolValue];
 if(kind==MYBIPLinkLegacy){
  NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:KLegacyPlist];
  if([root[@"Proxies"][@"ProxyAutoConfigEnable"] boolValue])want=YES;
 }
 if([[NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/MYbloXX/AppControlSession.plist")][@"active"] boolValue]){
  // App Control has paused protection; its own restore path re-applies it.
  MYBRetireLegacyFilesConfig();return 0;
 }
 int rc=0;
 if(kind==MYBIPLinkLegacy||kind==MYBIPLinkOwned){
  NSString *mode=selectedMode();if(!validMode(mode)&&![mode isEqual:@"Custom"])mode=@"Default";
  if(want){
   NSString *expected=MYBEffectiveScript(mode);
   NSString *action=MYBIPRecoveryAction(YES,expected);
   if(![action isEqual:@"ok"]||kind==MYBIPLinkLegacy){rc=MYBApplyRuntime(mode);if(!rc){updateMarkers(mode,YES);rc=saveState(mode,YES);}if(!rc)rc=restartConfigd();}
  } else {rc=MYBRemoveRuntime();if(!rc)rc=restartConfigd();}
 } else MYBRetireLegacyFilesConfig();
 if(!rc)logLine([NSString stringWithFormat:@"MIGRATE: inline transport ready (enabled=%d)",want]);
 return rc;
}
static int restartConfigd(void) {
#ifdef MYB_HELPER_TESTING
 gMYBTestRestarts++;logLine(@"Restart requested (test seam)");return gMYBTestRestartResult;
#endif
 logLine([NSString stringWithFormat:@"Restart requested: uid=%d euid=%d", (int)getuid(), (int)geteuid()]);
 // Resolve Apple's process-query APIs at runtime, avoiding dependency on a command-line shell.
 void *lib = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOW);
 if (!lib) lib = RTLD_DEFAULT;
 int (*listAll)(void *,int) = dlsym(lib,"proc_listallpids");
 int (*procName)(int,void *,unsigned int) = dlsym(lib,"proc_name");
 if (listAll && procName) {
   int estimatedCount=listAll(NULL,0);
   if(estimatedCount>0 && estimatedCount<262144) {
     int capacity=(estimatedCount+128)*(int)sizeof(pid_t);
     pid_t *pids=calloc(1,(size_t)capacity);
     if(pids) {
       int count=listAll(pids,capacity);
       int countPids=count>0?count:0;
       BOOL found=NO;
       int lastError=0;
       for(int i=0;i<countPids;i++) {
         if(pids[i]<=1 || pids[i]==getpid()) continue;
         char name[128]={0};
         if(procName(pids[i],name,sizeof(name))<=0 || strcmp(name,"configd")!=0)continue;
         found=YES;
         pid_t target=pids[i];
         if(kill(target,SIGKILL)==0) {
           logLine([NSString stringWithFormat:@"Sent SIGKILL to configd PID=%d (euid=%d)",(int)target,(int)geteuid()]);
           free(pids);
           return 0;
         }
         lastError=errno;
         logLine([NSString stringWithFormat:@"Direct configd kill(%d) failed: errno=%d (%s)",(int)target,lastError,strerror(lastError)]);
       }
       free(pids);
       if(found && lastError)logLine(@"Trying command-line killall after direct configd signal failed");
       if(!found)logLine(@"Native process enumeration did not find configd");
     }
   } else logLine([NSString stringWithFormat:@"Native process enumeration returned %d process slots",estimatedCount]);
 } else logLine(@"Native process enumeration API unavailable");
 // Fall back to native killall utility when process APIs cannot enumerate configd.
 NSArray<NSString *> *paths=@[
 [MYBBootstrapRoot() stringByAppendingPathComponent:@"usr/bin/killall"],
 [MYBBootstrapRoot() stringByAppendingPathComponent:@"bin/killall"],
 @"/usr/bin/killall",@"/bin/killall",
 @"/rootfs/usr/bin/killall",@"/var/jb/usr/bin/killall",@"/var/jb/bin/killall"];
 for(NSString *path in paths) {
   if(access(path.fileSystemRepresentation,X_OK)!=0)continue;
   pid_t pid=0;
   const char *args[]={"killall","-9","configd",NULL};
   int err=posix_spawn(&pid,path.fileSystemRepresentation,NULL,NULL,(char *const *)args,environ);
   if(err) {logLine([NSString stringWithFormat:@"Spawn %@ failed: %d (%s)",path,err,strerror(err)]);continue;}
   int status=0;
   if(waitpid(pid,&status,0)<0) {logLine([NSString stringWithFormat:@"Wait for %@ failed: %s",path,strerror(errno)]);continue;}
   int rc=WIFEXITED(status)?WEXITSTATUS(status):128;
   logLine([NSString stringWithFormat:@"%@ exit code=%d euid=%d",path,rc,(int)geteuid()]);
   if(rc==0)return 0;
 }
 logLine(@"Could not verify configd restart. Proxy change may be written but NOT active.");
 return 75;
}

static int signalNamedProcess(const char *name,int signalNumber,BOOL mandatory) {
 void *lib=dlopen("/usr/lib/libSystem.B.dylib",RTLD_NOW);
 if(!lib)lib=RTLD_DEFAULT;
 int (*listAll)(void *,int)=dlsym(lib,"proc_listallpids");
 int (*procName)(int,void *,unsigned int)=dlsym(lib,"proc_name");
 if(!listAll || !procName){logLine(@"Process enumeration unavailable");return mandatory?75:0;}
 int estimated=listAll(NULL,0);
 if(estimated<1 || estimated>262144){logLine(@"Process enumeration failed");return mandatory?75:0;}
 int capacity=(estimated+128)*(int)sizeof(pid_t);
 pid_t *pids=calloc(1,(size_t)capacity);
 if(!pids)return mandatory?71:0;
 int count=listAll(pids,capacity);
 BOOL seen=NO;
 BOOL signaled=NO;
 int error=0;
 for(int i=0;i<count;i++){
  pid_t pid=pids[i];
  if(pid<=1 || pid==getpid())continue;
  char label[128]={0};
  if(procName(pid,label,sizeof(label))<=0 || strcmp(label,name)!=0)continue;
  seen=YES;
  if(kill(pid,signalNumber)==0) {signaled=YES;logLine([NSString stringWithFormat:@"Signal %d sent to %s PID %d",signalNumber,name,pid]);}
  else {error=errno;logLine([NSString stringWithFormat:@"Signal %d to %s failed: %d",signalNumber,name,error]);}
 }
 free(pids);
 if(!seen)logLine([NSString stringWithFormat:@"%@ was not running; skipped",[NSString stringWithUTF8String:name]]);
 return ((mandatory && !signaled) || (seen && !signaled && error))?75:0;
}
static int fullNetworkRefresh(void) {
 // Preserve iOS 14 refresh sequence; keep regular PAC switching on proven configd path.
 int rc=restartConfigd();
 int optionalFailures=0;
 if(signalNamedProcess("mDNSResponder",SIGKILL,NO))optionalFailures++;
 if(signalNamedProcess("CFNetworkAgent",SIGHUP,NO))optionalFailures++;
 if(signalNamedProcess("mDNSResponderHelper",SIGHUP,NO))optionalFailures++;
 logLine([NSString stringWithFormat:@"Full network refresh configd=%d optionalSignalsNotSent=%d",rc,optionalFailures]);
 // Missing optional daemons on newer iOS should not make a successful
 // configd refresh look like a complete failure.
 return rc;
}
static int cellularRefresh(void) {
 // The original MYbloXX used SIGHUP rather than SIGKILL for CommCenter.
 return signalNamedProcess("CommCenter",SIGHUP,YES);
}


static int requestRespring(void) {
 NSArray<NSString *> *tools=@[@"/var/jb/usr/bin/sbreload",@"/var/jb/bin/sbreload"];
 for(NSString *path in tools){
   if(access(path.fileSystemRepresentation,X_OK)!=0)continue;
   const char *args[]={"sbreload",NULL};
   pid_t pid=0;
   int err=posix_spawn(&pid,path.fileSystemRepresentation,NULL,NULL,(char *const *)args,environ);
   if(err==0){
     logLine(@"Requested sbreload to apply injected-module changes");
     int status=0;waitpid(pid,&status,0);
     return WIFEXITED(status)?WEXITSTATUS(status):0;
   }
 }
 logLine(@"sbreload not present. Attempting direct SpringBoard respring.");
 return signalNamedProcess("SpringBoard",SIGTERM,YES);
}
static NSString *SupervisionPath(void){
 // iOS may store system groups under a UUID instead of the bundle identifier.
 // Discover the original group by MobileContainerManager metadata; never
 // generate a configuration-profiles directory just to enable this feature.
 NSString *direct=@"/var/containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles/CloudConfigurationDetails.plist";
 // RootHide may expose native system groups only through its rootfs view.
 // Prefer an existing, metadata-verified group; do not invent a bootstrap copy.
 for(NSString *root in @[@"/rootfs/var/containers/Shared/SystemGroup",@"/var/containers/Shared/SystemGroup"]){
  NSString *named=[root stringByAppendingPathComponent:@"systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles/CloudConfigurationDetails.plist"];
  if(MYBSupervisionParentSafe(named))return named;
  for(NSString *entry in [FM() contentsOfDirectoryAtPath:root error:NULL]){
   NSString *group=[root stringByAppendingPathComponent:entry];
   NSDictionary *meta=[NSDictionary dictionaryWithContentsOfFile:[group stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
   if(![meta[@"MCMMetadataIdentifier"] isEqual:@"systemgroup.com.apple.configurationprofiles"])continue;
   NSString *candidate=[group stringByAppendingPathComponent:@"Library/ConfigurationProfiles/CloudConfigurationDetails.plist"];
   if(MYBSupervisionParentSafe(candidate)||MYBSupervisionContainerSafe(candidate))return candidate;
  }
 }

 return direct; // unavailable, report exact native path; never create parents
}
static NSString *SupervisionRecord(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/Supervision.plist");}
static void migrateSupervisionRecord(void){
 NSString *marker=[MYBRoot() stringByAppendingPathComponent:@"Status/LegacySpoofed"],*backup=[MYBRoot() stringByAppendingPathComponent:@"Backups/CloudConfigurationDetails.MYbloXX.plist"];
 if(![FM() fileExistsAtPath:SupervisionRecord()]&&[FM() fileExistsAtPath:marker]){NSDictionary *old=[NSDictionary dictionaryWithContentsOfFile:backup];if(old){NSMutableDictionary *r=[@{@"owner":@"net.myxxdev.mybloxx",@"hadValue":@(old[@"IsSupervised"]!=nil)} mutableCopy];if(old[@"IsSupervised"])r[@"value"]=old[@"IsSupervised"];[r writeToFile:SupervisionRecord() atomically:YES];}}
}
static int writeSupervisionStatus(void){
 migrateSupervisionRecord();
 NSString *path=MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.supervision.plist");
 NSError *error=nil;
 [FM() createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
 if(error)return errorCode(@"SUPERVISION: status folder missing",error,73);
 NSMutableDictionary *status=[MYBSupervisionStatus(SupervisionPath(),SupervisionRecord()) mutableCopy];status[@"path"]=SupervisionPath();status[@"euid"]=@(geteuid());status[@"reason"]=[status[@"available"] boolValue]?@"Native supervision settings are accessible.":@"The native configuration-profiles store could not be accessed. Use Repair MYbloXX®, then reopen this page.";
 logLine([NSString stringWithFormat:@"SUPERVISION: path=%@ available=%@ supervised=%@ owned=%@ parentExists=%@",SupervisionPath(),status[@"available"],status[@"supervised"],status[@"owned"],status[@"parentExists"]]);
 BOOL ok=[status writeToFile:path atomically:YES];
 if(ok){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
 return ok?0:73;
}
static int setLegacySupervision(BOOL enable){migrateSupervisionRecord();int rc=MYBChangeSupervision(enable,SupervisionPath(),SupervisionRecord());if(!rc)signalNamedProcess("profiled",SIGKILL,NO);writeSupervisionStatus();return rc;}
__attribute__((unused)) static void tryPrivilege(void) {
 // RootHide: the privilege patch may require platformization before setuid.
 // This is the same entitlement-plus-setuid sequence used by the earlier helper.
 const char *libs[] = {NULL, NULL, "/usr/lib/libjailbreak.dylib", NULL};
 NSString *primary=[MYBBootstrapRoot() stringByAppendingPathComponent:@"usr/lib/libjailbreak.dylib"];
 NSString *alternate=[MYBBootstrapRoot() stringByAppendingPathComponent:@"lib/libjailbreak.dylib"];
 libs[0]=primary.fileSystemRepresentation;
 libs[1]=alternate.fileSystemRepresentation;
 if(geteuid()!=0){setgid(0);setuid(0);}
 for(int i=0;libs[i];i++) {
  void *handle=dlopen(libs[i],RTLD_NOW|RTLD_LOCAL);
  if(!handle)continue;
  void (*entitle)(pid_t,uint32_t)=(void (*)(pid_t,uint32_t))dlsym(handle,"jb_oneshot_entitle_now");
  void (*fix)(pid_t)=(void (*)(pid_t))dlsym(handle,"jb_oneshot_fix_setuid_now");
  if(entitle)entitle(getpid(),2);
  if(fix)fix(getpid());
  if(getegid()!=0)setgid(0);
  if(geteuid()!=0)setuid(0);
  if(geteuid()==0)break;
 }
 if(geteuid()!=0){setgid(0);setuid(0);}
 logLine([NSString stringWithFormat:@"Privilege status: uid=%d euid=%d",getuid(),geteuid()]);
}
#include "MYBProfileStage.inc"
#include "MYBUpdates.inc"
#include "MYBPin.inc"
#include "MYBRuleTest.inc"


static NSDictionary *MYBWebsitePaths(NSString *mode,NSString *archive){
 NSMutableDictionary *paths=[@{@"website":MYBWebsiteFile(),@"applied":MYBDataPath(@"/var/mobile/Library/MYbloXX/AppliedRules.plist"),@"draft":MYBDraftFile(),@"guard":MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist"),@"state":KState,@"pac":PACFile(mode),@"pacFallback":BundledPAC(mode)} mutableCopy];
 if(archive.length)paths[@"archive"]=archive;return paths;
}
static void MYBFinishWebsiteFiles(NSDictionary *paths){
 for(NSString *key in @[@"website",@"applied",@"draft",@"archive"]){NSString *path=paths[key];if(!path)continue;chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
 MYBMakeFilesUserAccessible();notify_post("net.myxxdev.mybloxx.safariguard.changed");
}
static int allowWebsite(NSString *domain,NSString *mode,NSString *duration){
 if(duration.length&&![@[@"once",@"temp",@"always"] containsObject:duration])return 64;
 BOOL temporary=[@[@"once",@"temp"] containsObject:duration];
 NSString *archive=ManualRulesArchive();if(!archive.length&&!temporary)return 78;
 NSDictionary *paths=MYBWebsitePaths(mode,archive);
 NSDictionary *legacy=[NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/Preferences/com.apple.Preferences.plist")]?:@{};
 int(^gate)(void)=^int{
   // Exceptions apply to protection that is really enforced for the chosen mode.
   if(!ownedLink()||!MYBActiveFlag())return ownedLink()?69:3;
   return [selectedMode() isEqual:mode]?0:69;
  };
 BOOL(^validate)(NSString *)=^BOOL(NSString *script){return SyntaxValid([script dataUsingEncoding:NSUTF8StringEncoding]);};
 int(^apply)(void)=^int{int applied=MYBReapplyIfLinked();return applied?applied:restartConfigd();};
 void(^recover)(void)=^{MYBReapplyIfLinked();restartConfigd();};
 int rc=temporary?MYBCommitWebsiteTemp(domain,mode,duration,paths,gate,validate,apply,recover,nil)
                 :MYBCommitWebsiteAllow(domain,mode,paths,legacy,gate,validate,apply,recover,nil);
 if(!rc){
  logLine([NSString stringWithFormat:@"WEBSITE_ALLOW: installed %@ exception %@ for mode %@",temporary?duration:@"permanent",domain,mode]);
  MYBFinishWebsiteFiles(paths);
 } else {
  logLine([NSString stringWithFormat:@"WEBSITE_ALLOW: failed code=%d for %@ mode=%@, owned=%d active=%d pac=%@ bundled=%@",rc,domain,mode,ownedLink(),MYBActiveFlag(),paths[@"pac"],paths[@"pacFallback"]]);
 }
 return rc;
}
// Revokes one temporary exception, or (domain==nil) drops expired ones. Expiry is also enforced when the PAC is
// generated, so a late prune only delays removing the text from the live PAC; it can never extend an exception.
static int revokeWebsite(NSString *domain){
 NSString *mode=selectedMode();if(!validMode(mode)&&![mode isEqual:@"Custom"])mode=@"Default";
 NSDictionary *paths=MYBWebsitePaths(mode,nil);BOOL linked=ownedLink()&&MYBActiveFlag();BOOL changed=NO;
 int rc=MYBCommitWebsiteRevoke(domain,mode,paths,^int{return 0;},^BOOL(NSString *script){return SyntaxValid([script dataUsingEncoding:NSUTF8StringEncoding]);},
  ^int{if(!linked)return 0;int applied=MYBReapplyIfLinked();return applied?applied:restartConfigd();},^{if(linked){MYBReapplyIfLinked();restartConfigd();}},nil,&changed);
 if(!rc&&changed){logLine([NSString stringWithFormat:@"WEBSITE_ALLOW: revoked %@",domain?:@"expired temporary exceptions"]);MYBFinishWebsiteFiles(paths);}
 return rc;
}

#include "MYBPrivateCalls.inc"
#include "MYBAppControl.inc"
#include "MYBStartup.inc"
#include "MYBSetup.inc"
#include "MYBDefaults.inc"
#include "MYBProfileMigrate.inc"
#include "MYBAdsFilter.inc"
#include "MYBUninstall.inc"
#include "MYBPACView.inc"

// Retired transient configd experiment; private RootHide plist prototype.

static int MYBRun(int argc,char **argv) {
 @autoreleasepool {
  { // one strict, table-driven check of argc/argv (Shared/MYBHelperArgs.h); nothing runs, and no privilege is used, if it fails
   NSString *refusal=nil;
   if(!MYBHelperArgsValid(argc,(const char *const *)argv,^BOOL(NSString *m){return validMode(m);},&refusal)){
    logLine([NSString stringWithFormat:@"Usage error (64): %@. Usage: MYXXdev™ <action> [arguments]; website: allowwebsite DOMAIN MODE [once|temp|always]",refusal?:@"malformed invocation"]);
    return MYB_HELPER_EXIT_USAGE;
   }
  }
  NSString *action=[NSString stringWithUTF8String:argv[1]];
  NSString *mode=argc>=3?[NSString stringWithUTF8String:argv[2]]:nil;
  NSString *value=argc>=4?[NSString stringWithUTF8String:argv[3]]:nil;
  NSString *duration=argc==5?[NSString stringWithUTF8String:argv[4]]:nil;
  BOOL appFocus=[action isEqual:@"appfocus"];
  BOOL website=[action isEqual:@"allowwebsite"],revokeSite=[action isEqual:@"revokewebsite"];
  BOOL isMode=[@[@"mode",@"selectmode"] containsObject:action];
  BOOL generate=[action isEqualToString:@"generate"];
  BOOL localCustom=[action isEqualToString:@"localcustom"];
  BOOL ccModule=[action isEqualToString:@"ccmodule"];
   if([action isEqualToString:@"diagnose"]) {
   logLine([NSString stringWithFormat:@"Native helper launched: uid=%d euid=%d; mode=%@",getuid(),geteuid(),selectedMode()]);return 0;
  }
  if([action isEqualToString:@"status"]) {
   printf("mode=%s active=%d euid=%d\n",selectedMode().UTF8String,
      (ownedLink()&&MYBActiveFlag())?1:0,geteuid());
   return 0;
  }
  if([action isEqual:@"testrule"]){
   // Evaluation is isolated from Settings and runs as mobile, with a hard
   // timeout; a malformed future PAC cannot hang the Settings process.
   setgid(501);setuid(501);alarm(3);int result=testPACDomain(mode);alarm(0);return result;
  }
#ifndef MYB_HELPER_TESTING
  tryPrivilege();
#define MYB_EUID() geteuid()
#endif
  if(MYB_EUID()==0)migrateOldBootstrapState();
  if(MYB_EUID()!=0) {
   logLine([NSString stringWithFormat:@"Root access unavailable (uid=%d euid=%d); no changes made",getuid(),geteuid()]);
   return 77;
  }
  if([action isEqual:@"pacview"])return MYBPACViewSnapshot(); // read-only snapshot for the PAC Script screen; changes no system state
  if([action isEqual:@"statuspublish"])return 0; // read-only: main() publishes a fresh verification after every run; takes no lock, changes nothing
  if([action isEqual:@"pcapply"])return MYBPCApplyNow(); // Private Calls: merge Phone's pending requests into the one store
  if([action isEqual:@"appwatch"])return appControlWatch();
  if([action isEqual:@"startuprecover"]||[action isEqual:@"restore"])return startupRecover(); // takes the operation lock itself, once per attempt
  int operationLock=MYBOperationLockTake();
  if(operationLock<0)return 75;
#ifdef MYB_HELPER_TESTING
  gMYBTestLockFD=operationLock;
#endif
  // The process owns the descriptor until exit, including configd refresh.
  if([action isEqual:@"appcontrolmigrate"]){NSDictionary *choices=MYBAppControlChoices(AppControlPrefs());NSString *path=MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist");if(![choices writeToFile:path atomically:YES])return 73;chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);notify_post("net.myxxdev.mybloxx.speedyads.changed");return 0;}
  if([action isEqual:@"pinauth"])return pinAuthorise(mode);
  if([action isEqual:@"pinset"])return pinSet();
  if([action isEqual:@"pinremove"])return pinRemove();
  if([action isEqual:@"pinstatus"])return pinStatusPrint();
  // noXXX PIN: operations that would weaken noXXX need a one-use authorisation made with the PIN (nothing changes without it).
  if([@[@"restorebackup",@"restoreimport",@"restoredefaults"] containsObject:action]){int gate=pinGuardProtected(@"restore");if(gate)return gate;}
  if([action isEqual:@"disable"]){int gate=pinGuardChange(@"disable",NO,selectedMode());if(gate)return gate;}
  // Legacy Mode: a standalone profile is applied by iOS itself and can never ask for the PIN, so preparing one is refused without a
  // one-use "disable" authorisation whenever ANY PIN is set (stricter than a plain disable, which only needs it while noXXX is protecting).
  if(([action isEqual:@"legacyprepare"]||[action isEqual:@"legacypreflight"])&&PinConfigured()){int gate=pinRequire(@"disable");if(gate)return gate;}
  if([action isEqual:@"legacypreflight"])return 0; // only the PIN check: native protection stays on until the profile is installed
  if([@[@"custom",@"proxy"] containsObject:action]){int gate=pinGuardProtected(@"override");if(gate)return gate;}
  if(isMode){BOOL willBeOn=[action isEqual:@"mode"]?YES:PinEnabledFlag();int gate=pinGuardChange(@"mode",willBeOn,mode);if(gate)return gate;}
  if(website){int gate=pinGuardAllowSite(mode.lowercaseString);if(gate)return gate;}
  if(localCustom){int gate=pinGuardRules(mode,value);if(gate)return gate;}
  if([action isEqual:@"uninstall"])return uninstallNativeConfiguration();
  if(appFocus)return appControlFocus(mode);
  if([action isEqual:@"runtimecheck"])return runtimeCheck();
  if([action isEqual:@"migrateinline"])return migrateInlineRuntime();
  if([action isEqualToString:@"preparefiles"]){int prepared=MYBPrepareFilesStorage();if(prepared)return prepared;prepared=recoverManualRules();if(prepared)return prepared;return [FM() fileExistsAtPath:SetupSettingsFile()]?0:exportSetup(YES);}
  if([action isEqualToString:@"recoverrules"])return recoverManualRules();
  if([action isEqualToString:@"backupfiles"])return exportSetup(YES);
  if([action isEqualToString:@"syncfiles"]){if(!MYBAppControlServiceEnabled(AppControlPrefs())&&[AppControlSession()[@"active"] boolValue]){int restored=appControlFocus(@"__none__");if(restored)return restored;}return exportSetup(NO);}
  if([action isEqualToString:@"restorebackup"])return restoreSetup(SetupSettingsFile());
  if([action isEqualToString:@"restoreimport"])return restoreSetup(MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.restore-import.plist"));
  if([action isEqualToString:@"restoredefaults"])return restoreDefaults();
  if([action isEqualToString:@"initdefaults"])return initDefaults();
  if([action isEqualToString:@"adsfilter"])return MYBWriteAdsFilter();
  if([action isEqualToString:@"installlink"])return MYBInstallDisabledLink();
  if(website)return allowWebsite(mode,value,duration);
  if(revokeSite)return revokeWebsite(mode);
  if([action isEqual:@"pruneexpired"])return revokeWebsite(nil);
  if([action isEqual:@"supervisionstatus"])return writeSupervisionStatus();
  if([action isEqual:@"profilestage"])return stageBundledProfile(mode,value,[duration isEqual:@"replace"]);
  if([action isEqual:@"profilestatus"])return checkBundledProfile(mode,value);
  if([action isEqual:@"profilediag"])return MYBProfileDiagnostics();
  if([action isEqual:@"settingsrefresh"])return signalNamedProcess("Preferences",SIGKILL,YES);
  if([action isEqual:@"connectionreset"]){int network=fullNetworkRefresh();int cellular=cellularRefresh();return network?network:cellular;}
  if([action isEqual:@"repair"]){
   MYBShieldRepairOwnership();{int filter=MYBWriteAdsFilter();if(filter)logLine([NSString stringWithFormat:@"REPAIR: loader filters could not be checked (%d)",filter]);}
   // The saved preference is the intent; the runtime configuration is rebuilt to match it.
   BOOL active=[loadSavedState()[@"enabled"] boolValue];
   // Error 3 used to end here whenever a hand-installed MYbloXX profile held the proxy. A recognised standalone profile is replaced
   // (see MYBProfileMigrate.inc); anything else that holds the proxy is still left alone and reported.
   if(managedOccupied() && !ownedLink()){int m=MYBMigrateLegacyProfile(NO);if(m==MYB_MIGRATE_APPLY_FAILED||m==MYB_MIGRATE_SWITCH_NEEDED||m==MYB_MIGRATE_UNAVAILABLE)return m;if(m!=0||(managedOccupied()&&!ownedLink()))return 3;}
   NSString *liveMode=selectedMode();
   int repaired=active?MYBSetPACEnabled(YES):MYBSetPACEnabled(NO);
   if(repaired)return repaired;
   updateMarkers(liveMode,active);
   int stateResult=saveState(liveMode,active);
   if(stateResult)return stateResult;
   logLine([NSString stringWithFormat:@"REPAIR: rebuilt the %@ inline PAC (%@); full network refresh requested",active?@"enabled":@"disabled",liveMode]);
   int networkRC=fullNetworkRefresh();
   // Repair is an explicit, user-confirmed deep refresh, unlike everyday
   // Enable/Disable. Ask iOS radio/network daemons to refresh as well.
   int wifiRC=signalNamedProcess("wifid",SIGHUP,NO);
   int cellRC=signalNamedProcess("CommCenter",SIGHUP,NO);
   logLine([NSString stringWithFormat:@"REPAIR: network=%d wifiSignal=%d cellularSignal=%d",networkRC,wifiRC,cellRC]);
   return networkRC;
  }
  if([action isEqual:@"systemcheck"]){
   // A detached configuration is the original MYbloXX off state.
   if(!ownedLink())return [loadSavedState()[@"enabled"] boolValue]?69:0;
   // Real protection: an intact target whose embedded PAC equals the PAC the current settings generate.
   NSDictionary *status=MYBRuntimeStatus();
   if(![status[@"enabled"] boolValue])return 69;
   NSString *expected=MYBEffectiveScript(selectedMode());
   return (expected&&[status[@"script"] isEqual:expected])?0:69;
  }
  if([action isEqual:@"updatepolicy"])return setUpdatePolicy([mode isEqual:@"on"]);
  if([action isEqual:@"updatecheck"] || [action isEqual:@"updateauto"])return updatePACs([action isEqual:@"updateauto"]);
  if([action isEqual:@"refreshbundled"])return refreshBundledPACs();
  if([action isEqual:@"updaterollback"])return rollbackPACs();
  // Watch everything: a time-limited switch that lets the Activity list see allowed websites too. It only writes or removes an end
  // time and then rebuilds the PAC through the ordinary reconfigure path, so it can never change what is blocked. Nothing happens
  // while protection is off. The PAC itself stops offering the watch service when the time is up.
  if([action isEqual:@"watch"]){
   NSString *marker=MYBWatchFile();BOOL watchOn=[mode isEqual:@"on"];BOOL protectionOn=[loadSavedState()[@"enabled"] boolValue];
   if(watchOn&&!protectionOn)return 69;
   if(watchOn){
    long seconds=value.intValue>0?MIN(3600,MAX(60,value.intValue)):600;long long until=(long long)((NSDate.date.timeIntervalSince1970+seconds)*1000);
    [FM() createDirectoryAtPath:marker.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    if(![[NSString stringWithFormat:@"%lld",until] writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:NULL])return 73;
    chown(marker.fileSystemRepresentation,501,501);chmod(marker.fileSystemRepresentation,0644);
   }else{
    if(![FM() fileExistsAtPath:marker])return 0;
    [FM() removeItemAtPath:marker error:NULL];
   }
   if(!protectionOn)return 0;
   action=@"reconfigure";
  }
  int rc=0;
  // What was protecting the device before this action: if the change is applied but the network service cannot then be restarted,
  // the previous protection is put back rather than leaving a failed (and possibly weaker) change in place.
  NSString *priorMode=selectedMode();BOOL wasProtected=[loadSavedState()[@"enabled"] boolValue]&&ownedLink();NSData *priorState=[NSData dataWithContentsOfFile:KState];
  if(isMode){
   if([action isEqual:@"selectmode"] && ![loadSavedState()[@"enabled"] boolValue]){
    // Select offline without enabling protection; discard an old manual URL
    // so Enable applies this newly selected standard mode.
    updateMarkers(mode,NO);return saveState(mode,NO);
   }
   rc=configure(mode);
  }
  else if([action isEqualToString:@"migrateprofile"])rc=MYBMigrateLegacyProfile(YES);
  else if([action isEqualToString:@"custom"] || [action isEqualToString:@"proxy"])rc=configureManual(action,mode);
  else if(localCustom)rc=applyUserRules(mode,value);
  else if(generate){logLine(@"Generating custom PAC remains gated; current selected local PAC is preserved");rc=79;}
  else if(ccModule)rc=setCCModule(mode);
  else if([action isEqualToString:@"enable"] || [action isEqualToString:@"reconfigure"]) {
    NSString *wanted=selectedMode();
    if(!validMode(wanted)&&![wanted isEqual:@"Custom"])wanted=@"Default";
    // A hand-installed standalone MYbloXX profile is replaced here (and only such a profile). Any other occupant keeps the old refusal.
    if(managedOccupied() && !ownedLink()){int m=MYBMigrateLegacyProfile(NO);rc=(m==MYB_MIGRATE_APPLY_FAILED||m==MYB_MIGRATE_SWITCH_NEEDED||m==MYB_MIGRATE_UNAVAILABLE)?m:3;if(m==0&&!managedOccupied())rc=ownedLink()?0:MYBApplyRuntime(wanted);}
    else rc=MYBApplyRuntime(wanted);
    if(!rc){updateMarkers(wanted,YES);rc=saveState(wanted,YES);}
  }
  else if([action isEqualToString:@"disable"])rc=disable();
  else if([action isEqualToString:@"legacyprepare"]){
   // Native protection is turned off BEFORE the Legacy profile is handed to iOS, because iOS refuses to install a proxy profile while
   // MYbloXX's own managed link is in place. If the install is cancelled or never happens, the watch loop turns it back on
   // (MYBLegacyRevertCheck); Settings also does so as soon as it sees the profile is not installed.
   BOOL wasOn=[loadSavedState()[@"enabled"] boolValue];
   rc=disable();
   if(rc==0&&wasOn)[@{@"until":[NSDate dateWithTimeIntervalSinceNow:900]} writeToFile:MYBDataPath(@"/var/mobile/Library/MYbloXX/LegacyRevert.plist") atomically:YES];
  }
  if([action isEqualToString:@"adopt"]) {
    int adopted=adoptManagedConfiguration();
    if(adopted)return adopted;
    touch(KSystemOptIn);
    return restartConfigd();
  }
  if([action isEqualToString:@"localhealth"])return MYBEffectiveScript(@"Default")?0:69;
  if([action isEqualToString:@"respring"])return requestRespring();
  if([action isEqualToString:@"spoof"])return setLegacySupervision(YES);
  if([action isEqualToString:@"unspoof"])return setLegacySupervision(NO);
  if([action isEqualToString:@"fullreset"])return fullNetworkRefresh();
  if([action isEqualToString:@"cellularreset"])return cellularRefresh();
  if(rc==0 && [@[@"enable",@"reconfigure",@"mode",@"custom"] containsObject:action] && [loadSavedState()[@"enabled"] boolValue] && MYBActiveFlag() && ownedLink())
    touch(KSystemOptIn);
  if(rc==0 && ![action isEqualToString:@"proxy"] && ![action isEqualToString:@"custom"] && !ccModule && !generate && !localCustom){
   rc=restartConfigd();
   if(rc&&wasProtected&&priorMode.length&&!([action isEqualToString:@"disable"]||[action isEqualToString:@"legacyprepare"])&&(isMode||[action isEqualToString:@"enable"]||[action isEqualToString:@"reconfigure"])&&![selectedMode() isEqual:priorMode]){
    int back=MYBApplyRuntime(priorMode);if(!back){updateMarkers(priorMode,YES);back=(priorState&&[priorState writeToFile:KState atomically:YES])?0:saveState(priorMode,YES);} // the saved state goes back byte for byte
    logLine([NSString stringWithFormat:@"ROLLBACK: %@ could not be activated (code %d); the previous protection was restored (%d)",action,rc,back]);
   }
  }
  return rc;
 }
}



// ---- WebKit Networking refresh after a committed change (engine and rules: Shared/MYBProcessRefresh.h) ------------------------------
__attribute__((unused)) static NSNumber *MYBProcessStart(int pid){
 int mib[4]={CTL_KERN,KERN_PROC,KERN_PROC_PID,pid};struct kinfo_proc info;size_t size=sizeof(info);memset(&info,0,sizeof(info));
 if(sysctl(mib,4,&info,&size,NULL,0)!=0||size<sizeof(info)||info.kp_proc.p_pid!=pid)return nil;
 struct timeval t=info.kp_proc.p_un.__p_starttime;return @((long long)t.tv_sec*1000000LL+t.tv_usec);
}
__attribute__((unused)) static MYBProcessRefreshEnv *MYBRealRefreshEnv(void){
 MYBProcessRefreshEnv *e=[MYBProcessRefreshEnv new];e.steps=10; // 10 x 100 ms: one second at most before force-ending a survivor
 void *lib=dlopen("/usr/lib/libSystem.B.dylib",RTLD_NOW);if(!lib)lib=RTLD_DEFAULT;
 int (*listAll)(void *,int)=dlsym(lib,"proc_listallpids");int (*pidPath)(int,void *,unsigned int)=dlsym(lib,"proc_pidpath");
 e.list=^NSArray *{
  if(!listAll||!pidPath)return @[];int estimated=listAll(NULL,0);if(estimated<1||estimated>262144)return @[];
  int capacity=(estimated+128)*(int)sizeof(pid_t);pid_t *pids=calloc(1,(size_t)capacity);if(!pids)return @[];
  int count=listAll(pids,capacity);NSMutableArray *out=[NSMutableArray array];
  for(int i=0;i<count;i++){
   pid_t pid=pids[i];if(pid<=1||pid==getpid())continue;char path[1024]={0};
   if(pidPath(pid,path,sizeof(path))<=0)continue;NSString *p=[NSString stringWithUTF8String:path];if(!p||!MYBRefreshMatchesPath(p))continue;
   NSNumber *start=MYBProcessStart(pid);if(start)[out addObject:@{@"pid":@(pid),@"start":start,@"path":p}];
  }
  free(pids);return out;};
 e.startOf=^NSNumber *(int pid){return MYBProcessStart(pid);};
 e.signal=^int(int pid,int sig){return kill(pid,sig)==0?0:errno;};
 e.wait=^{usleep(100000);};return e;
}
// Once per helper process (one process is one transaction under the operation lock), on a background queue, bounded in time.
static void MYBRefreshWebKitAfterCommit(void){
 static BOOL done=NO;if(done)return;done=YES; // coalesced: overlapping requests inside one process collapse into one
#ifdef MYB_HELPER_TESTING
 gMYBTestWebKitRefreshes++;logLine(@"WebKit Networking refresh requested (test seam)");return;
#else
 dispatch_semaphore_t finished=dispatch_semaphore_create(0);
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{MYBRefreshWebKitNetworking(MYBRealRefreshEnv(),^(NSString *line){logLine(line);});dispatch_semaphore_signal(finished);});
 if(dispatch_semaphore_wait(finished,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))!=0)logLine(@"WEBKIT_REFRESH: still running after 5 s; the change itself is already committed");
#endif
}
// What the device is actually enforcing: the effective runtime PAC, the saved on/off intent and whether MYbloXX's link is installed.
// A refresh is only worth interrupting browsers for when this changed, so an update check that found nothing, an expiry sweep that
// found nothing expired, or an enable that was already on never touches the browser's network process.
static NSString *MYBRefreshFingerprint(void){
 NSDictionary *status=MYBRuntimeStatus();NSString *script=[status[@"script"] isKindOfClass:NSString.class]?status[@"script"]:@"";
 return MYBRuntimeSHA256([NSString stringWithFormat:@"%d|%@|%@",ownedLink()?1:0,[loadSavedState()[@"enabled"] description]?:@"",script]);
}
// Actions that may change what traffic is blocked or how it is routed. Appearance changes, diagnostics, status and reads are NOT in this list.
static BOOL MYBActionChangesProtection(NSString *action){
 return [@[@"enable",@"disable",@"legacyprepare",@"migrateprofile",@"mode",@"selectmode",@"reconfigure",@"localcustom",@"allowwebsite",@"revokewebsite",@"pruneexpired",@"updatecheck",@"updateauto",@"updaterollback",@"watch",@"custom",@"proxy",@"repair",@"restorebackup",@"restoreimport",@"restoredefaults",@"startuprecover",@"restore",@"fullreset",@"connectionreset",@"uninstall"] containsObject:action];
}

int main(int argc,char **argv){@autoreleasepool{
 NSString *beforeAction=(argc>=2&&MYBActionChangesProtection([NSString stringWithUTF8String:argv[1]]))?MYBRefreshFingerprint():nil;
 int rc=MYBRun(argc,argv);
 if(MYB_EUID()==0)MYBPublishRuntimeStatusForce(YES);
 if(!rc && argc>=2){
  NSString *action=[NSString stringWithUTF8String:argv[1]];
  NSArray *changes=@[@"enable",@"disable",@"legacyprepare",@"migrateprofile",@"mode",@"selectmode",@"reconfigure",@"localcustom",@"allowwebsite",@"revokewebsite",@"pruneexpired",@"ccmodule",@"updatepolicy",@"updatecheck",@"updateauto",@"updaterollback",@"spoof",@"unspoof",@"custom",@"proxy",@"repair"];
  AppControlNoteManual(action);
  if(beforeAction&&![beforeAction isEqual:MYBRefreshFingerprint()])MYBRefreshWebKitAfterCommit(); // once, and only when what is enforced actually changed
  if([changes containsObject:action]){int backup=exportSetup(NO);if(backup)logLine([NSString stringWithFormat:@"FILES_BACKUP: settings applied; export not updated (%d)",backup]);}
 }
 return rc;
}}
