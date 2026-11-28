// Replacing a hand-installed standalone MYbloXX profile with native protection (action "migrateprofile").
// The decision logic is Shared/MYBProfileMigration.h (tested with a fake system); this file binds it to the real one.
//
// AUDIT OF THE PRIVATE SERVICE (ManagedConfiguration, class MCProfileConnection). Nothing here is documented by Apple and the
// signatures differ between iOS versions, so:
//   * a selector is used only when its method signature matches what is expected (argument count, object/block argument types);
//     otherwise the result is "unavailable" and the person removes the profile in Settings. Nothing is called with guessed types.
//   * only removeProfileWithIdentifier:completion: is used. The installationType variant is NOT used: its integer argument is not
//     known, and a wrong value could target a different install type.
//   * the completion block is declared with spare arguments and never dereferenced: it is only a "finished" signal. Its arguments
//     are not interpreted, because their meaning is not known.
//   * selector availability does not prove this process is allowed to remove a profile, and a callback does not prove it worked.
//     Success is decided ONLY by observing the result: the service no longer lists the profile, the managed-proxy file is gone, and
//     the system's effective proxy settings no longer use the profile's PAC address, all within a bounded wait.
// Unrelated profiles and payloads are never described or removed (identifier + organisation + payload shape must all match).
#import <objc/message.h>
#import <CFNetwork/CFNetwork.h>
#import "../Shared/MYBProfileMigration.h"

static NSString *MYBMigrationPath(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/ProfileMigration.plist");}
// Durable: written to a temporary file, flushed to disk, renamed over the record, and the directory is flushed too.
static BOOL MYBMigrationWriteDurable(NSDictionary *d){
 NSString *path=MYBMigrationPath();if(!path.length)return NO;
 NSMutableDictionary *m=[d mutableCopy];m[@"updated"]=[NSDate date];
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:m format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];if(!data)return NO;
 [FM() createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *tmp=[path stringByAppendingString:@".tmp"];
 int fd=open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_TRUNC|O_NOFOLLOW,0600);if(fd<0)return NO;
 BOOL ok=write(fd,data.bytes,data.length)==(ssize_t)data.length&&fcntl(fd,F_FULLFSYNC)!=-1;close(fd);
 if(!ok||rename(tmp.fileSystemRepresentation,path.fileSystemRepresentation)!=0){unlink(tmp.fileSystemRepresentation);return NO;}
 int dfd=open(path.stringByDeletingLastPathComponent.fileSystemRepresentation,O_RDONLY);if(dfd>=0){fcntl(dfd,F_FULLFSYNC);close(dfd);}
 return YES;
}
#import "../Shared/MYBProfileService.h" // list / describe / remove / effective proxy: shared with the Settings component
static MYBMigrationEnv *MYBRealMigrationEnv(void){
 MYBMigrationEnv *e=[MYBMigrationEnv new];
 e.list=^NSArray *{return MYBServiceList();};e.describe=^NSDictionary *(NSString *i){return MYBServiceDescribe(i);};
 e.effectivePAC=^NSString *{CFDictionaryRef px=CFNetworkCopySystemProxySettings();NSDictionary *d=px?CFBridgingRelease(px):nil;NSString *u=[d[(__bridge NSString *)kCFProxyAutoConfigurationURLKey] description]?:[d[@"ProxyAutoConfigURLString"] description];return u.length?u:nil;};
 e.remove=^(NSString *i){MYBServiceRemove(i);};e.managedGone=^BOOL{return (BOOL)!managedOccupied();};e.effectiveClear=^BOOL(NSString *p){return MYBEffectiveProxyClear(p);};
 e.record=^BOOL(NSDictionary *d){return MYBMigrationWriteDurable(d);};e.loadRecord=^NSDictionary *{NSString *p=MYBMigrationPath();return p.length?[NSDictionary dictionaryWithContentsOfFile:p]:nil;};
 e.apply=^int(NSString *mode){int rc=MYBApplyRuntime(mode);if(!rc){updateMarkers(mode,YES);rc=saveState(mode,YES);}return rc;};
 e.owned=^BOOL{return ownedLink();};e.wait=^{usleep(500000);};e.steps=20;
 NSDictionary *saved=loadSavedState();e.savedEnabled=saved[@"enabled"]?[saved[@"enabled"] boolValue]:YES;
 NSString *mode=selectedMode();if(!validMode(mode)&&![mode isEqual:@"Custom"])mode=@"Default";e.mode=mode;
 return e;
}
// userChose NO: read-only inspection (Enable, Repair, startup). It never removes a profile; a recognised one returns MYB_MIGRATE_SWITCH_NEEDED.
// userChose YES: only the explicit "migrateprofile" action after the person chose Switch to Native Protection.
static int MYBMigrateLegacyProfile(BOOL userChose){
 int rc=MYBMigrationRun(MYBRealMigrationEnv(),userChose,^(NSString *line){logLine(line);MYBProfileDiagNote(line);});
 MYBProfileDiagNote([NSString stringWithFormat:@"MIGRATE result=%d userChose=%d",rc,userChose]);return rc;
}
// Action "profilediag": a read-only probe. It lists what this iOS offers (method shapes, enumeration, how each MYbloXX-identified profile is
// read and classified, the live proxy) and removes, installs and changes nothing. Everything goes to ProfileDiagnostics.txt.
static NSString *MYBDiagShape(id svc,NSString *name){NSString *e=svc?MYBProfileEncoding(object_getClass(svc),NSSelectorFromString(name)):nil;return [NSString stringWithFormat:@"%@=%@",name,e?:@"absent"];}
static int MYBProfileDiagnostics(void){
 id svc=MYBProfileService();
 MYBProfileDiagNote([NSString stringWithFormat:@"--- profile probe, iOS %@, service=%@",NSProcessInfo.processInfo.operatingSystemVersionString,svc?NSStringFromClass([svc class]):@"none"]);
 for(NSString *n in @[@"installedProfileIdentifiers",@"installedProfileDataWithIdentifier:",@"installedSystemProfileDataWithIdentifier:",@"installedUserProfileDataWithIdentifier:",@"installedProfileWithIdentifier:",@"removeProfileWithIdentifier:completion:",@"removeProfileWithIdentifier:",@"queueFileDataForProfileInstallation:originalFileName:outError:",@"queueProfileDataForInstallation:outError:"])MYBProfileDiagNote(MYBDiagShape(svc,n));
 for(NSString *l in MYBProfileProbeLines(@"helper"))MYBProfileDiagNote(l);
 NSArray *ids=MYBServiceList();
 MYBProfileDiagNote([NSString stringWithFormat:@"enumeration: %@",ids?[NSString stringWithFormat:@"%lu profile(s)",(unsigned long)ids.count]:@"unavailable"]);
 for(NSString *ident in ids?:@[]){
  if(![MYBLegacyProfileKnownIdentifiers() containsObject:ident])continue; // unrelated profiles are counted above, never described
  NSDictionary *p=MYBServiceDescribe(ident);
  BOOL readable=[p[@"payloads"] isKindOfClass:NSArray.class];
  NSString *live=nil;{CFDictionaryRef px=CFNetworkCopySystemProxySettings();NSDictionary *d=px?CFBridgingRelease(px):nil;live=[d[(__bridge NSString *)kCFProxyAutoConfigurationURLKey] description];}
  MYBProfileKind kind=p?MYBClassifyProfile(p):MYBProfileForeign;
  NSString *types=@"-";if(readable){NSMutableArray *t=[NSMutableArray array];for(NSDictionary *c in p[@"payloads"])[t addObject:[c[@"type"] description]?:@"?"];types=[t componentsJoinedByString:@","];}
  MYBProfileDiagNote([NSString stringWithFormat:@"MYbloXX-identified profile %@: described=%d contentsReadable=%d org=%@ uuid=%@ payloadTypes=%@ kind=%ld(0 foreign,1 standalone,2 ambiguous,3 candidate) knownPAC=%d",ident,p?1:0,readable,p[@"organization"]?:@"-",p[@"uuid"]?:@"-",types,(long)kind,readable?MYBProfileKnownPACAddress([[p[@"payloads"] firstObject][@"pacURL"] description]):0]);
  MYBProfileDiagNote([NSString stringWithFormat:@"effective proxy PAC %@ (a known MYbloXX address: %d)",MYBProfileKnownPACAddress(live)?live:(live.length?@"[another address, not recorded]":@"none"),MYBProfileKnownPACAddress(live)]);
 }
 NSDictionary *nav=nil;{void *im=dlopen("/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration",RTLD_LAZY);CFStringRef *sym=im?(CFStringRef *)dlsym(im,"kMCSettingsURLProfilePurgatoryInstallation"):NULL;
  Class ws=NSClassFromString(@"LSApplicationWorkspace");id w=(ws&&[ws respondsToSelector:NSSelectorFromString(@"defaultWorkspace")])?((id(*)(id,SEL))objc_msgSend)(ws,NSSelectorFromString(@"defaultWorkspace")):nil;
  nav=@{@"constant":(sym&&*sym)?(__bridge NSString *)*sym:@"absent",@"openSensitive":w?(MYBProfileEncoding(object_getClass(w),NSSelectorFromString(@"openSensitiveURL:withOptions:"))?:@"absent"):@"no-workspace"};}
 MYBProfileDiagNote([NSString stringWithFormat:@"installer navigation: constant=%@ openSensitiveURL:withOptions:=%@ (not opened by this probe)",nav[@"constant"],nav[@"openSensitive"]]);
 MYBProfileDiagNote([NSString stringWithFormat:@"state: managedOccupied=%d ownedLink=%d",managedOccupied()?1:0,ownedLink()?1:0]);
 return 0;
}
