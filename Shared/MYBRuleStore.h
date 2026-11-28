#pragma once
#include <stdio.h>
#import "MYBWebsiteRules.h"
// Runtime rules take precedence over drafts and legacy Settings defaults.
static inline BOOL MYBValidRuleDictionary(NSDictionary *d){return [d isKindOfClass:NSDictionary.class] && MYBRuleArray(d[@"blocked"]) && MYBRuleArray(d[@"allowed"]);}
// Live view used only to GENERATE the PAC: permanent exceptions plus unexpired temporary ones.
// MYBEffectiveRules below stays permanent-only because it is also what gets persisted.
static inline NSDictionary *MYBEffectiveRules(NSDictionary *applied,NSDictionary *website);
static inline NSDictionary *MYBEffectiveRulesLive(NSDictionary *applied,NSDictionary *website){
 NSMutableDictionary *web=[website mutableCopy]?:[NSMutableDictionary dictionary];NSMutableArray *domains=[(MYBRuleArray(web[@"domains"])?:@[]) mutableCopy];
 for(NSDictionary *e in MYBWebsiteTempLive(website))if(![domains containsObject:e[@"domain"]])[domains addObject:e[@"domain"]];web[@"domains"]=domains;
 return MYBEffectiveRules(applied,web);
}
static inline NSDictionary *MYBEffectiveRules(NSDictionary *applied,NSDictionary *website){
 NSMutableArray *blocked=[(MYBRuleArray(applied[@"blocked"])?:@[]) mutableCopy];
 NSMutableArray *allowed=[(MYBRuleArray(applied[@"allowed"])?:@[]) mutableCopy];
 for(NSString *domain in (MYBRuleArray(website[@"domains"])?:@[]))if(![allowed containsObject:domain])[allowed addObject:domain];
 // Existing website exceptions already override exact custom blocks at runtime.
 [blocked removeObjectsInArray:allowed];
 return @{@"blocked":blocked,@"allowed":allowed};
}
static inline NSDictionary *MYBLegacyRules(NSDictionary *legacy){
 NSMutableDictionary *rules=[NSMutableDictionary dictionary];
 for(NSString *key in @[@"blocked",@"allowed"]){
  NSString *csv=legacy[[key isEqual:@"blocked"]?@"MYB2-block":@"MYB2-allow"];
  NSArray *items=[csv isKindOfClass:NSString.class]&&csv.length?[csv.lowercaseString componentsSeparatedByString:@","]:@[];
  rules[key]=MYBRuleArray(items)?:@[];
 }
 return MYBEffectiveRules(rules,@{});
}
static inline NSDictionary *MYBRecoveredRules(NSDictionary *applied,NSDictionary *archive,NSDictionary *legacy,NSDictionary *website){
 NSDictionary *base=MYBValidRuleDictionary(applied)?applied:(MYBValidRuleDictionary(archive)?archive:MYBLegacyRules(legacy));
 return MYBEffectiveRules(base,website);
}
// Writes and rollback are shared by recovery, factory reset and native tests.
static inline int MYBWriteRuleFiles(NSDictionary *values,int(^apply)(void),BOOL(^writer)(NSData *,NSString *)){
 NSFileManager *fm=NSFileManager.defaultManager;
 NSMutableDictionary *before=[NSMutableDictionary dictionary],*attributes=[NSMutableDictionary dictionary];
 for(NSString *path in values){
  BOOL directory=NO;
  if([fm fileExistsAtPath:path isDirectory:&directory]){
   if(directory)return 73;
   NSData *bytes=[NSData dataWithContentsOfFile:path];if(!bytes)return 74;before[path]=bytes;attributes[path]=[fm attributesOfItemAtPath:path error:NULL]?:@{};
  }
  if(![fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL])return 73;
 }
 int rc=0;
 for(NSString *path in values){
  NSData *bytes=[NSPropertyListSerialization dataWithPropertyList:values[path] format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
  if(!bytes || (writer?!writer(bytes,path):![bytes writeToFile:path atomically:YES])){rc=73;break;}
 }
 if(!rc && apply)rc=apply();
 if(rc){for(NSString *path in values){NSData *bytes=before[path];if(bytes){[bytes writeToFile:path atomically:YES];for(NSString *key in @[NSFileOwnerAccountID,NSFileGroupOwnerAccountID,NSFilePosixPermissions])if(attributes[path][key])[fm setAttributes:@{key:attributes[path][key]} ofItemAtPath:path error:NULL];}else [fm removeItemAtPath:path error:NULL];}}
 return rc;
}
// Factory means bundled bytes for every named mode, never a downloaded or
// generated PAC. Custom is reset to Default. No old generation is selectable.
static inline int MYBFactoryPACReset(NSString *bundled,NSString *root,NSArray *names,NSDictionary *values,BOOL(^validate)(NSData *),int(^activate)(void)){
 NSFileManager *fm=NSFileManager.defaultManager;
 NSString *stage=[root stringByAppendingPathComponent:[@"Factory-" stringByAppendingString:NSUUID.UUID.UUIDString]];
 if(![fm createDirectoryAtPath:stage withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:NULL])return 73;
 for(NSString *name in [names arrayByAddingObject:@"Custom"]){
  NSString *source=[bundled stringByAppendingPathComponent:[([name isEqual:@"Custom"]?@"Default":name) stringByAppendingString:@".pac"]];
  NSData *bytes=[NSData dataWithContentsOfFile:source];
  if(!bytes || !validate(bytes) || ![bytes writeToFile:[stage stringByAppendingPathComponent:[name stringByAppendingString:@".pac"]] atomically:YES]){[fm removeItemAtPath:stage error:NULL];return 65;}
 }
 NSString *pointer=[root stringByAppendingPathComponent:@"PACCurrent"];
 NSString *previous=[fm destinationOfSymbolicLinkAtPath:pointer error:NULL];
 if([fm fileExistsAtPath:pointer] && !previous){[fm removeItemAtPath:stage error:NULL];return 73;}
 NSString *next=[root stringByAppendingPathComponent:@"PACCurrent.factory-next"];
 [fm removeItemAtPath:next error:NULL];
 if(![fm createSymbolicLinkAtPath:next withDestinationPath:stage error:NULL] || rename(next.fileSystemRepresentation,pointer.fileSystemRepresentation)!=0){[fm removeItemAtPath:next error:NULL];[fm removeItemAtPath:stage error:NULL];return 73;}
 int rc=MYBWriteRuleFiles(values,activate,nil);
 if(rc){
  [fm removeItemAtPath:pointer error:NULL];if(previous)[fm createSymbolicLinkAtPath:pointer withDestinationPath:previous error:NULL];
  [fm removeItemAtPath:stage error:NULL];return rc;
 }
 // Discard every old MYbloXX generation only after the whole reset succeeds.
 for(NSString *name in [fm contentsOfDirectoryAtPath:root error:NULL]){
  NSString *path=[root stringByAppendingPathComponent:name];
  if(![path isEqual:stage] && ([name isEqual:@"PAC"] || [name hasPrefix:@"PAC-"] || [name hasPrefix:@"Factory-"] || [name hasPrefix:@"Restore-"]))[fm removeItemAtPath:path error:NULL];
 }
 return 0;
}
