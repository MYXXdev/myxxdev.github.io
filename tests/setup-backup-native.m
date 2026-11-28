#import "../Shared/MYBSetupBackup.h"
static void require(BOOL ok,const char *s){if(!ok){fprintf(stderr,"FAIL: %s\n",s);exit(1);}}
int main(int argc,char **argv){@autoreleasepool{
 require(argc==2,"bundled PAC source");NSFileManager *fm=NSFileManager.defaultManager;NSString *bundle=[NSString stringWithUTF8String:argv[1]],*root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
 NSMutableDictionary *pacs=[NSMutableDictionary dictionary];for(NSString *mode in MYBSetupModes())pacs[mode]=[NSData dataWithContentsOfFile:[bundle stringByAppendingPathComponent:[mode stringByAppendingString:@".pac"]]];
 NSMutableDictionary *setup=[@{@"format":@"net.myxxdev.mybloxx.setup",@"version":@1,@"created":[NSDate dateWithTimeIntervalSince1970:1000000],@"protection":@{@"enabled":@YES,@"mode":@"blockXXX"},@"rules":@{@"blocked":@[@"blocked.example"],@"allowed":@[@"allowed.example"]},@"shield":@{@"Enabled":@YES,@"BlockPopups":@YES,@"ShowBlocked":@NO,@"Blocked":@[@"shield-blocked.example"],@"Allowed":@[@"shield-allowed.example"],@"URLs":@[@"https://example.com/path"],@"RedirectEnabled":@YES,@"RedirectApps":@{@"test.app":@YES}},@"speedyAds":@{@"Enabled":@YES,@"enabled-test.app":@YES,@"test.app-BlockAds":@NO,@"test.app-VideoRate":@4,@"test.app-CompressTimers":@YES},@"preferences":@{@"MYB2-proxy":@"http://proxy.example:8080"},@"automaticUpdates":@YES,@"components":@{@"YouTopia":@YES,@"ControlCenter":@NO},@"legacySupervision":@{@"enabled":@NO},@"pacs":pacs} mutableCopy];
 BOOL(^validate)(NSData *)=^BOOL(NSData *data){return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] containsString:@"function FindProxyForURL"];};
 require(MYBSetupValid(setup,validate),"complete setup includes every section");
 // Older backups (before Shield permissions / popup mode / other-app redirects) stay valid and restorable.
 {
  NSMutableDictionary *older=[setup mutableCopy];[older removeObjectForKey:@"shieldPermissions"];older[@"shield"]=@{@"Enabled":@YES,@"BlockPopups":@YES,@"ShowBlocked":@YES,@"Blocked":@[@"a.example"],@"Allowed":@[],@"URLs":@[],@"RedirectEnabled":@YES,@"RedirectApps":@{@"com.apple.mobilesafari":@YES}};
  require(MYBSetupValid(older,validate),"a backup without the Shield permissions section and without PopupMode is still valid");
  require([MYBShieldValidatedPermanent(older[@"shieldPermissions"]) isEqual:@[]],"a missing section means 'no change', never a parse failure");
  NSMutableDictionary *newer=[older mutableCopy];newer[@"shield"]=@{@"Enabled":@YES,@"PopupMode":@"standard",@"RedirectOtherApps":@YES};newer[@"shieldPermissions"]=@[@{@"kind":@"popup",@"source":@"site.example"},@{@"kind":@"appstore",@"source":@"com.example.app"},@{@"kind":@"appredirect",@"source":@"com.a.b",@"dest":@"com.c.d"}];
  require(MYBSetupValid(newer,validate),"a current backup with standing permissions is valid");
  NSMutableDictionary *bad2=[newer mutableCopy];bad2[@"shield"]=@{@"PopupMode":@"lenient"};require(!MYBSetupValid(bad2,validate),"unknown popup mode rejected");
  bad2=[newer mutableCopy];bad2[@"shieldPermissions"]=@[@{@"kind":@"popup",@"source":@"bad host with spaces"}];require(!MYBSetupValid(bad2,validate),"malformed permission rejected");
  bad2=[newer mutableCopy];bad2[@"shieldPermissions"]=@[@{@"kind":@"appredirect",@"source":@"com.a.b"}];require(!MYBSetupValid(bad2,validate),"app-to-app permission without a destination rejected");
  bad2=[newer mutableCopy];bad2[@"shieldPermissions"]=@{@"kind":@"popup"};require(!MYBSetupValid(bad2,validate),"wrong container type rejected");
  bad2=[newer mutableCopy];bad2[@"shield"]=@{@"RedirectOtherApps":@"yes"};require(!MYBSetupValid(bad2,validate),"non-boolean toggle rejected");
  for(NSDictionary *g in newer[@"shieldPermissions"])require(![g objectForKey:@"mode"]&&![g objectForKey:@"wallExpiry"],"exported entries carry no mode or expiry (only standing permissions exist in a backup)");
 }
 NSData *serialized=[NSPropertyListSerialization dataWithPropertyList:setup format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];NSDictionary *roundtrip=[NSPropertyListSerialization propertyListWithData:serialized options:0 format:NULL error:NULL];require([roundtrip isEqual:setup],"entire setup round-trips without losing PAC bytes or settings");
 NSMutableDictionary *bad=[setup mutableCopy];bad[@"version"]=@99;require(!MYBSetupValid(bad,validate),"unknown format version rejected");bad=[setup mutableCopy];bad[@"protection"]=@{@"mode":@"../../bad",@"enabled":@YES};require(!MYBSetupValid(bad,validate),"backup cannot supply file paths as modes");bad=[setup mutableCopy];NSMutableDictionary *broken=[pacs mutableCopy];[broken removeObjectForKey:@"blockApple"];bad[@"pacs"]=broken;require(!MYBSetupValid(bad,validate),"incomplete base PAC set rejected");bad=[setup mutableCopy];bad[@"shield"]=@{@"Blocked":@[@"bad;domain.example"]};require(!MYBSetupValid(bad,validate),"corrupt Shield rules rejected before applying");bad=[setup mutableCopy];bad[@"speedyAds"]=@{@"test.app-VideoRate":@[]};require(!MYBSetupValid(bad,validate),"corrupt per-app settings rejected");
 bad=[setup mutableCopy];bad[@"preferences"]=@{@"MYB2-proxy":@1};require(!MYBSetupValid(bad,validate),"wrong proxy preference type rejected");
 bad=[setup mutableCopy];bad[@"legacySupervision"]=@{@"enabled":@YES,@"record":@{@"owner":@"net.myxxdev.mybloxx",@"hadValue":@NO,@"createdFile":@YES},@"device":@"same-device-token",@"fingerprint":@"0000000000000000000000000000000000000000000000000000000000000000"};require(MYBSetupValid(bad,validate),"MYbloXX-owned supervision recovery record preserved");
 NSString *settings=[root stringByAppendingPathComponent:@"MYbloXX-Settings.plist"],*pacFile=[root stringByAppendingPathComponent:@"MYbloXX.pac"];
 NSString *base=[[NSString alloc] initWithData:pacs[@"blockXXX"] encoding:NSUTF8StringEncoding],*live=MYBSetupLivePAC(base,setup[@"rules"]);
 require(live && [live containsString:@"blocked.example"] && [live containsString:@"allowed.example"] && ![live containsString:@"PROXY 127.0.0.1:8021"],"live PAC includes manual edits and actual serving transport");
 require(MYBWriteSetupExport(setup,live,settings,pacFile,nil)==0,"two public export files saved");NSData *beforeSettings=[NSData dataWithContentsOfFile:settings],*beforePAC=[NSData dataWithContentsOfFile:pacFile];
 __block int writes=0;int rc=MYBWriteSetupExport(bad,@"changed",settings,pacFile,^BOOL(NSData *d,NSString *p){if(++writes==2)return NO;return [d writeToFile:p atomically:YES];});require(rc==73 && [[NSData dataWithContentsOfFile:settings] isEqual:beforeSettings] && [[NSData dataWithContentsOfFile:pacFile] isEqual:beforePAC],"failed export retains previous settings and PAC together");
 NSString *old=[root stringByAppendingPathComponent:@"PAC-old"],*pointer=[root stringByAppendingPathComponent:@"PACCurrent"];[fm createDirectoryAtPath:old withIntermediateDirectories:YES attributes:nil error:NULL];[fm createSymbolicLinkAtPath:pointer withDestinationPath:old error:NULL];
 NSMutableDictionary *values=[NSMutableDictionary dictionary];for(NSString *key in @[@"protection",@"rules",@"shield",@"speedyAds",@"preferences",@"components",@"legacySupervision"]){NSString *p=[root stringByAppendingPathComponent:[key stringByAppendingString:@".plist"]];[@{@"old":@YES} writeToFile:p atomically:YES];values[p]=setup[key];}
 NSString *sideEffect=[root stringByAppendingPathComponent:@"owned-supervision-record.plist"];
 rc=MYBRestoreSetupFiles(setup,root,values,@[sideEffect],validate,^int{[@{@"sideEffect":@YES} writeToFile:sideEffect atomically:YES];return 75;});require(rc==75 && ![fm fileExistsAtPath:sideEffect] && [[fm destinationOfSymbolicLinkAtPath:pointer error:NULL] isEqual:old],"failed restore rolls back PAC pointer and side-effect files");for(NSString *p in values)require([[NSDictionary dictionaryWithContentsOfFile:p][@"old"] boolValue],"every settings section rolls back on activation failure");
 rc=MYBRestoreSetupFiles(setup,root,values,@[sideEffect],validate,^int{for(NSString *name in pacs)require([[NSData dataWithContentsOfFile:[pointer stringByAppendingPathComponent:[name stringByAppendingString:@".pac"]]] isEqual:pacs[name]],"restored PAC files retain category-specific bytes");return 0;});require(rc==0,"full restore succeeds offline");for(NSString *p in values)require([[NSDictionary dictionaryWithContentsOfFile:p] isEqual:values[p]],"all sections restored exactly");
 NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:settings];require([MYBRecoveredRules(nil,saved[@"rules"],@{},@{}) isEqual:setup[@"rules"]],"manual rules recover from the single Settings file after reinstall");
 NSString *activeComponent=[root stringByAppendingPathComponent:@"Feature.bundle"],*inactiveComponent=[root stringByAppendingPathComponent:@"Stored/Feature.bundle"],*stash=[root stringByAppendingPathComponent:@"quarantine/Feature.bundle"];
 [fm createDirectoryAtPath:activeComponent withIntermediateDirectories:YES attributes:nil error:NULL];[fm createDirectoryAtPath:inactiveComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 [@"new package" writeToFile:[activeComponent stringByAppendingPathComponent:@"binary"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];[@"old disabled" writeToFile:[inactiveComponent stringByAppendingPathComponent:@"binary"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 require(MYBStashDuplicateComponent(activeComponent,inactiveComponent,stash)==0 && ![fm fileExistsAtPath:inactiveComponent],"reinstall duplicates are quarantined instead of blocking restoration");
 require([[NSString stringWithContentsOfFile:[activeComponent stringByAppendingPathComponent:@"binary"] encoding:NSUTF8StringEncoding error:NULL] isEqual:@"new package"],"current packaged companion retained");
 require([fm moveItemAtPath:activeComponent toPath:inactiveComponent error:NULL],"saved disabled state applies despite old duplicate");
 require([fm moveItemAtPath:inactiveComponent toPath:activeComponent error:NULL] && MYBRestoreComponentStash(inactiveComponent,stash)==0,"failed restore can recover original active and disabled copies");
 require([[NSString stringWithContentsOfFile:[inactiveComponent stringByAppendingPathComponent:@"binary"] encoding:NSUTF8StringEncoding error:NULL] isEqual:@"old disabled"],"duplicate rollback preserves original component bytes");
 // ---- format 2: settings only; rules are generated on the device, so a restore never installs an older backup's rules ----
 {
  NSMutableDictionary *v2=[setup mutableCopy];v2[@"version"]=@2;v2[@"pacs"]=@{};v2[@"protection"]=@{@"enabled":@YES,@"mode":@"allowY+blockXXX",@"summary":@"Default + allowY! + noXXX"};
  require(MYBSetupValid(v2,validate),"format 2 without any PAC is valid");
  NSMutableDictionary *w=[v2 mutableCopy];w[@"protection"]=@{@"enabled":@YES,@"mode":@"allowY+blockXXX",@"summary":@"Default + noApple"};require(!MYBSetupValid(w,validate),"a summary that does not match the saved combination is refused");
  w=[v2 mutableCopy];w[@"protection"]=@{@"enabled":@NO,@"mode":@"blockAdSense+blockSocials+blockXXX"};require(MYBSetupValid(w,validate)&&![w[@"protection"][@"enabled"] boolValue],"every combination can be saved, off state included");
  w=[v2 mutableCopy];w[@"pacs"]=@{@"Default":pacs[@"Default"]};require(!MYBSetupValid(w,validate),"format 2 does not accept a partial set of mode PACs");
  NSMutableDictionary *legacy=[NSMutableDictionary dictionary];for(NSString *n in @[@"Default",@"allowY",@"blockAdSense",@"blockApple",@"blockSocials",@"blockXXX",@"MYbloXX",@"MYbloXXTest",@"MYbloXXallowFB",@"MYbloXXallowY",@"MYbloXXnoApple",@"MYbloXXnoFB",@"MYbloXXnoSocials",@"MYbloXXnoXXX"])legacy[n]=pacs[n];
  w=[setup mutableCopy];w[@"pacs"]=legacy;w[@"version"]=@1;w[@"protection"]=@{@"enabled":@YES,@"mode":@"blockXXX"};require(MYBSetupValid(w,validate),"a format 1 backup with the historical PAC set is still readable");
  w[@"version"]=@2;require(!MYBSetupValid(w,validate),"the historical PAC set is not a format 2 shape");
  w=[v2 mutableCopy];w[@"pacs"]=@{@"Custom":pacs[@"Default"]};w[@"protection"]=@{@"enabled":@YES,@"mode":@"Custom"};require(MYBSetupValid(w,validate),"a Proxy Override backup carries only the Custom PAC");
  w=[v2 mutableCopy];w[@"protection"]=@{@"enabled":@YES,@"mode":@"Custom"};require(!MYBSetupValid(w,validate),"a Custom mode without its PAC is refused");
  // restore of a format 2 backup keeps the rules that are current on the device and only replaces the Proxy Override
  NSString *cur=[root stringByAppendingPathComponent:@"PAC-current"];[fm createDirectoryAtPath:cur withIntermediateDirectories:YES attributes:nil error:NULL];
  [@"// MYbloXX\nfunction FindProxyForURL(u,h){return 'DIRECT';}//newer-rules" writeToFile:[cur stringByAppendingPathComponent:@"Default.pac"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  [@"// MYbloXX\nfunction FindProxyForURL(u,h){return 'DIRECT';}//old-override" writeToFile:[cur stringByAppendingPathComponent:@"Custom.pac"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  [fm removeItemAtPath:pointer error:NULL];[fm createSymbolicLinkAtPath:pointer withDestinationPath:cur error:NULL];
  rc=MYBRestoreSetupFiles(v2,root,values,@[],validate,^int{
   NSString *def=[NSString stringWithContentsOfFile:[pointer stringByAppendingPathComponent:@"Default.pac"] encoding:NSUTF8StringEncoding error:NULL];
   require([def containsString:@"newer-rules"],"restore keeps the current rules instead of an old backup's");
   require(![fm fileExistsAtPath:[pointer stringByAppendingPathComponent:@"Custom.pac"]],"a backup without a Proxy Override removes the old override");return 0;});
  require(rc==0,"format 2 restore succeeds");
 }
 [fm removeItemAtPath:root error:NULL];puts("Full setup validation, all-section round-trip, live PAC export, offline restore and rollback checks passed");return 0;
}}
