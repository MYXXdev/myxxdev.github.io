#pragma once
#import "MYBWatch.h"
#import "MYBRuleStore.h"
#import "MYBOptions.h"
#import "MYBTransport.h"
#import "MYBShield.h"
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
static inline NSArray *MYBHistoricalNames(void){return @[@"MYbloXX",@"MYbloXXTest",@"MYbloXXallowFB",@"MYbloXXallowY",@"MYbloXXnoApple",@"MYbloXXnoFB",@"MYbloXXnoSocials",@"MYbloXXnoXXX"];}
static inline NSArray *MYBSetupModes(void){return [MYBModeIDs() arrayByAddingObjectsFromArray:@[@"MYbloXX",@"MYbloXXTest",@"MYbloXXallowFB",@"MYbloXXallowY",@"MYbloXXnoApple",@"MYbloXXnoFB",@"MYbloXXnoSocials",@"MYbloXXnoXXX"]];}
// Backup format 2 keeps settings only: the rules themselves are generated on the device from the canonical rules, so the
// mode PACs are not part of a backup. The only PAC a backup may carry is the user's Proxy Override ("Custom"). Format 1
// backups (which embedded the historical PACs) stay readable; their mode PACs are ignored on restore. A COMPLETE set of mode
// PACs is accepted only from the factory reset path, which installs the bundled rules.
static inline BOOL MYBSetupHasAllModes(NSDictionary *pacs){for(NSString *name in MYBSetupModes())if(!pacs[name])return NO;return YES;}
static inline BOOL MYBSetupHasLegacySet(NSDictionary *pacs){for(NSString *name in @[@"Default",@"allowY",@"blockAdSense",@"blockApple",@"blockSocials",@"blockXXX"])if(!pacs[name])return NO;for(NSString *name in MYBHistoricalNames())if(!pacs[name])return NO;return YES;}
static inline NSString *MYBSetupLivePAC(NSString *base,NSDictionary *rules){if([base hasPrefix:@"function FindProxyForURL(url,host){return \"PROXY "]||[base hasPrefix:@"// MYbloXX Proxy Override\n"])return base;NSString *text=MYBUserRulesPAC(base,rules[@"blocked"],rules[@"allowed"]);return text?MYBWatchWrap(MYBTransportPACText(text),MYBWatchStoredMillis()):nil;}
static inline BOOL MYBSetupBool(id value){return [value isKindOfClass:NSNumber.class] && ([value isEqual:@0] || [value isEqual:@1]);}
static inline BOOL MYBSetupScalarDictionary(id value,NSUInteger limit){
 if(![value isKindOfClass:NSDictionary.class] || [value count]>limit)return NO;
 for(id key in value){id v=value[key];if(![key isKindOfClass:NSString.class]||[key length]>512)return NO;if(![v isKindOfClass:NSNumber.class] && !([v isKindOfClass:NSString.class]&&[v length]<=2048))return NO;}
 return YES;
}
static inline BOOL MYBSetupShieldValid(id value){
 if(![value isKindOfClass:NSDictionary.class] || [value count]>32)return NO;
 for(NSString *key in @[@"Blocked",@"Allowed"])if(value[key]&&!MYBRuleArray(value[key]))return NO;
 for(NSString *key in @[@"Enabled",@"BlockPopups",@"ShowBlocked",@"RedirectEnabled",@"RedirectOtherApps",@"RedirectAskAppStore",@"RedirectAskOtherApps"])if(value[key]&&!MYBSetupBool(value[key]))return NO;
 if(value[@"PopupMode"]&&![@[@"standard",@"strict"] containsObject:value[@"PopupMode"]])return NO;
 NSArray *urls=value[@"URLs"];if(urls && (![urls isKindOfClass:NSArray.class]||urls.count>20000))return NO;
 for(id text in urls){if(![text isKindOfClass:NSString.class]||[text length]>2048)return NO;NSURLComponents *u=[NSURLComponents componentsWithString:text];if(![@[@"http",@"https"] containsObject:u.scheme]||!u.host.length||u.user.length||u.password.length)return NO;}
 NSDictionary *apps=value[@"RedirectApps"];if(apps && (![apps isKindOfClass:NSDictionary.class]||apps.count>5000))return NO;
 for(id key in apps)if(![key isKindOfClass:NSString.class]||[key length]>255||!MYBSetupBool(apps[key]))return NO;
 NSSet *known=[NSSet setWithArray:@[@"Blocked",@"Allowed",@"URLs",@"Enabled",@"BlockPopups",@"ShowBlocked",@"RedirectEnabled",@"RedirectApps",@"RedirectOtherApps",@"RedirectAskAppStore",@"RedirectAskOtherApps",@"PopupMode"]];
 for(NSString *key in value)if(![known containsObject:key])return NO;
 return YES;
}
static inline BOOL MYBSetupValid(id value,BOOL(^validatePAC)(NSData *)){
 if(![value isKindOfClass:NSDictionary.class]||![value[@"format"] isEqual:@"net.myxxdev.mybloxx.setup"]||!([value[@"version"] isEqual:@1]||[value[@"version"] isEqual:@2]))return NO;
 NSDictionary *protection=value[@"protection"],*components=value[@"components"],*supervision=value[@"legacySupervision"],*pacs=value[@"pacs"];
 if(![protection isKindOfClass:NSDictionary.class]||!([@"Custom" isEqual:protection[@"mode"]]||MYBModeIDValid(protection[@"mode"]))||!MYBSetupBool(protection[@"enabled"]))return NO;
 // The saved summary, when present, must be the one the identifier stands for (a hand-edited mismatch is refused).
 if(protection[@"summary"]&&(![protection[@"summary"] isKindOfClass:NSString.class]||(MYBModeIDValid(protection[@"mode"])&&![protection[@"summary"] isEqual:MYBModeSummary(protection[@"mode"])])))return NO;
 if(!MYBValidRuleDictionary(value[@"rules"])||!MYBSetupShieldValid(value[@"shield"])||!MYBSetupScalarDictionary(value[@"speedyAds"],10000)||!MYBSetupScalarDictionary(value[@"preferences"],64)||!MYBSetupBool(value[@"automaticUpdates"]))return NO;
 for(NSString *key in value[@"preferences"])if(![key hasPrefix:@"MYB2-"])return NO;
 if(value[@"preferences"][@"MYB2-proxy"] && ![value[@"preferences"][@"MYB2-proxy"] isKindOfClass:NSString.class])return NO;
 if(value[@"shieldPermissions"]&&!MYBShieldValidatedPermanent(value[@"shieldPermissions"]))return NO;
 if(![components isKindOfClass:NSDictionary.class]||!MYBSetupBool(components[@"ControlCenter"]))return NO;
 if(![supervision isKindOfClass:NSDictionary.class]||!MYBSetupBool(supervision[@"enabled"]))return NO;
 if([supervision[@"enabled"] boolValue]){
  NSDictionary *record=supervision[@"record"];
  if(![record isKindOfClass:NSDictionary.class]||![record[@"owner"] isEqual:@"net.myxxdev.mybloxx"]||!MYBSetupBool(record[@"hadValue"])||![supervision[@"device"] isKindOfClass:NSString.class]||[supervision[@"device"] length]>255)return NO;
  if(![supervision[@"fingerprint"] isKindOfClass:NSString.class]||[supervision[@"fingerprint"] length]!=64||[supervision[@"fingerprint"] rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet].location!=NSNotFound)return NO;
  for(NSString *key in @[@"createdFile",@"value"])if(record[key]&&!MYBSetupBool(record[key]))return NO;
 }
 if(pacs&&![pacs isKindOfClass:NSDictionary.class])return NO;
 NSUInteger total=0;NSSet *names=[NSSet setWithArray:[MYBSetupModes() arrayByAddingObject:@"Custom"]];
 BOOL v2=[value[@"version"] isEqual:@2];
 if(pacs.count){
  BOOL customOnly=pacs.count==1&&pacs[@"Custom"];
  // version 2: Custom only, or the complete bundled set (factory reset); version 1: the historical set (+Custom) or complete.
  if(!customOnly&&!MYBSetupHasAllModes(pacs)&&(v2||!MYBSetupHasLegacySet(pacs)))return NO;
  for(NSString *name in pacs){NSData *data=pacs[name];if(![names containsObject:name]||![data isKindOfClass:NSData.class]||data.length>2*1024*1024||!validatePAC(data))return NO;total+=data.length;}
 }
 if(total>30*1024*1024)return NO;
 // An active historical Custom mode always needs a restorable source.
 return ![protection[@"mode"] isEqual:@"Custom"] || pacs[@"Custom"]!=nil;
}
// Snapshot fixed caller-owned paths, including side-effect files. No paths
// supplied by a backup document are accepted here.
static inline int MYBSetupFileTransaction(NSDictionary *values,NSArray *watch,int(^apply)(void)){
 NSFileManager *fm=NSFileManager.defaultManager;NSMutableDictionary *before=[NSMutableDictionary dictionary],*attributes=[NSMutableDictionary dictionary];
 NSSet *paths=[NSSet setWithArray:[values.allKeys arrayByAddingObjectsFromArray:watch]];
 for(NSString *path in paths){struct stat st;if(lstat(path.fileSystemRepresentation,&st)==0){if(!S_ISREG(st.st_mode))return 73;NSData *bytes=[NSData dataWithContentsOfFile:path];if(!bytes)return 74;before[path]=bytes;attributes[path]=[fm attributesOfItemAtPath:path error:NULL]?:@{};}else if(errno!=ENOENT)return 73;}
 int rc=0;
 for(NSString *path in values){if(![fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL]){rc=73;break;}NSData *bytes=[NSPropertyListSerialization dataWithPropertyList:values[path] format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];if(!bytes||![bytes writeToFile:path atomically:YES]){rc=73;break;}}
 if(!rc && apply)rc=apply();
 if(rc)for(NSString *path in paths){NSData *data=before[path];if(data){[data writeToFile:path atomically:YES];for(NSString *key in @[NSFilePosixPermissions,NSFileOwnerAccountID,NSFileGroupOwnerAccountID])if(attributes[path][key])[fm setAttributes:@{key:attributes[path][key]} ofItemAtPath:path error:NULL];}else[fm removeItemAtPath:path error:NULL];}
 return rc;
}
static inline int MYBRestoreSetupFiles(NSDictionary *setup,NSString *root,NSDictionary *values,NSArray *watch,BOOL(^validate)(NSData *),int(^apply)(void)){
 if(!MYBSetupValid(setup,validate))return 65;
 NSFileManager *fm=NSFileManager.defaultManager;NSString *stage=[root stringByAppendingPathComponent:[@"Restore-" stringByAppendingString:NSUUID.UUID.UUIDString]];
 if(![fm createDirectoryAtPath:stage withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:NULL])return 73;
 NSString *pointer=[root stringByAppendingPathComponent:@"PACCurrent"],*previous=[fm destinationOfSymbolicLinkAtPath:pointer error:NULL],*next=[root stringByAppendingPathComponent:@"PACCurrent.restore-next"];
 // Complete set (factory reset): install it as the generation. Otherwise the restored generation is the CURRENT rules with only
 // the user's Proxy Override replaced, so a restore never downgrades the rules to an older backup's.
 NSDictionary *pacs=setup[@"pacs"];BOOL full=pacs.count&&MYBSetupHasAllModes(pacs);
 if(!full&&previous.length&&[fm fileExistsAtPath:previous])for(NSString *entry in [fm contentsOfDirectoryAtPath:previous error:NULL])
  if([entry hasSuffix:@".pac"]&&![entry isEqual:@"Custom.pac"]&&![fm copyItemAtPath:[previous stringByAppendingPathComponent:entry] toPath:[stage stringByAppendingPathComponent:entry] error:NULL]){[fm removeItemAtPath:stage error:NULL];return 73;}
 for(NSString *name in pacs)if((full||[name isEqual:@"Custom"])&&![pacs[name] writeToFile:[stage stringByAppendingPathComponent:[name stringByAppendingString:@".pac"]] atomically:YES]){[fm removeItemAtPath:stage error:NULL];return 73;}
 struct stat st;if(lstat(pointer.fileSystemRepresentation,&st)==0 && !S_ISLNK(st.st_mode)){[fm removeItemAtPath:stage error:NULL];return 73;}
 [fm removeItemAtPath:next error:NULL];
 if(![fm createSymbolicLinkAtPath:next withDestinationPath:stage error:NULL]||rename(next.fileSystemRepresentation,pointer.fileSystemRepresentation)!=0){[fm removeItemAtPath:next error:NULL];[fm removeItemAtPath:stage error:NULL];return 73;}
 int rc=MYBSetupFileTransaction(values,watch,apply);
 if(rc){[fm removeItemAtPath:pointer error:NULL];if(previous)[fm createSymbolicLinkAtPath:pointer withDestinationPath:previous error:NULL];[fm removeItemAtPath:stage error:NULL];}
 return rc;
}
static inline NSString *MYBPublicFilesFolder(void){
 NSString *root=@"/var/mobile/Containers/Shared/AppGroup";
 for(NSString *entry in [NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:NULL]){
  NSString *group=[root stringByAppendingPathComponent:entry];NSDictionary *meta=[NSDictionary dictionaryWithContentsOfFile:[group stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
  if([meta[@"MCMMetadataIdentifier"] isEqual:@"group.com.apple.FileProvider.LocalStorage"])return [group stringByAppendingPathComponent:@"File Provider Storage/MYbloXX"];
 }return nil;
}
static inline int MYBWriteSetupExport(NSDictionary *setup,NSString *live,NSString *settingsFile,NSString *pacFile,BOOL(^writer)(NSData *,NSString *)){
 NSData *settings=[NSPropertyListSerialization dataWithPropertyList:setup format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL],*pac=[live dataUsingEncoding:NSUTF8StringEncoding];
 if(!settings||!pac)return 65;
 NSFileManager *fm=NSFileManager.defaultManager;NSMutableDictionary *before=[NSMutableDictionary dictionary];NSArray *paths=@[settingsFile,pacFile],*bytes=@[settings,pac];
 for(NSString *path in paths){struct stat st;if(lstat(path.fileSystemRepresentation,&st)==0){if(!S_ISREG(st.st_mode))return 73;NSData *d=[NSData dataWithContentsOfFile:path];if(!d)return 74;before[path]=d;}else if(errno!=ENOENT)return 73;}
 for(NSUInteger i=0;i<paths.count;i++)if(writer?!writer(bytes[i],paths[i]):![bytes[i] writeToFile:paths[i] atomically:YES]){for(NSString *path in paths){if(before[path])[before[path] writeToFile:path atomically:YES];else[fm removeItemAtPath:path error:NULL];}return 73;}
 return 0;
}
// Package upgrades install the active copy. Preserve it and quarantine a
// stale disabled duplicate until restore succeeds; keep both on failure.
static inline int MYBStashDuplicateComponent(NSString *active,NSString *inactive,NSString *stash){
 NSFileManager *fm=NSFileManager.defaultManager;
 if(![fm fileExistsAtPath:active]||![fm fileExistsAtPath:inactive])return 0;
 if([fm fileExistsAtPath:stash]||![fm createDirectoryAtPath:stash.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL])return 73;
 return [fm moveItemAtPath:inactive toPath:stash error:NULL]?0:73;
}
static inline int MYBRestoreComponentStash(NSString *inactive,NSString *stash){
 NSFileManager *fm=NSFileManager.defaultManager;if(![fm fileExistsAtPath:stash])return 0;
 if([fm fileExistsAtPath:inactive])return 73;
 return [fm moveItemAtPath:stash toPath:inactive error:NULL]?0:73;
}
