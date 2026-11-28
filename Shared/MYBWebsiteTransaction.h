#import "MYBWebsiteRules.h"
#import "MYBRuleStore.h"
#import "MYBOptions.h"
// Pure file transaction shared by the privileged helper and native fixture tests.
// The supplied context contains only caller-owned constant paths, never HTTP input.
// gate: returns 0 only when MYbloXX protection is really active for expectedMode (owned link + intact
// inline PAC). apply: regenerates and applies the complete effective PAC. recover: re-applies the
// previous state after a failed apply has been rolled back.
static int MYBCommitWebsiteAllow(NSString *domain,NSString *expectedMode,NSDictionary *paths,NSDictionary *legacy,int(^gate)(void),BOOL(^validate)(NSString *),int(^apply)(void),void(^recover)(void),BOOL(^writer)(NSData *,NSString *)){
 if(!MYBValidWebsiteDomain(domain))return 64;
 // The real runtime state is authoritative. Saved state markers may lag behind it and must not
 // reject an exception, but an absent/damaged runtime target must not be reported as protected.
 NSFileManager *fm=NSFileManager.defaultManager;
 if(!([@"Custom" isEqual:expectedMode]||MYBModeIDValid(expectedMode)))return 69;
 int gated=gate?gate():0;if(gated)return gated;
 NSMutableDictionary *web=[[NSDictionary dictionaryWithContentsOfFile:paths[@"website"]] mutableCopy]?:[NSMutableDictionary dictionary];NSMutableArray *domains=[(MYBRuleArray(web[@"domains"])?:@[]) mutableCopy];if(![domains containsObject:domain])[domains addObject:domain];if(domains.count>500)return 64;web[@"domains"]=domains;web[@"revision"]=NSUUID.UUID.UUIDString;
 NSDictionary *oldApplied=[NSDictionary dictionaryWithContentsOfFile:paths[@"applied"]]?:@{};NSMutableDictionary *applied=[MYBEffectiveRules(oldApplied,web) mutableCopy],*draft=[MYBRuleDraft(oldApplied,legacy) mutableCopy];
 for(NSMutableDictionary *d in @[applied,draft]){NSMutableArray *blocked=[(MYBRuleArray(d[@"blocked"])?:@[]) mutableCopy],*allowed=[(MYBRuleArray(d[@"allowed"])?:@[]) mutableCopy];[blocked removeObject:domain];if(![allowed containsObject:domain])[allowed addObject:domain];if(allowed.count>500)return 64;d[@"blocked"]=blocked;d[@"allowed"]=allowed;}
 // Do not mutate MYbloXX Shield when allowing a system PAC site.
 // Its block/allow lists belong to an independent browser protection layer.
 NSString *base=[NSString stringWithContentsOfFile:paths[@"pac"] encoding:NSUTF8StringEncoding error:NULL];
 if(!base.length){
  // The server normally serves PACCurrent first, then the bundled PAC. A
  // missing persistent PAC must not make "Allow Website" fail unnecessarily.
  NSString *fallback=paths[@"pacFallback"];
  base=[NSString stringWithContentsOfFile:fallback encoding:NSUTF8StringEncoding error:NULL];
 }
 NSString *effective=base?MYBWebsitePAC(base,domains):nil;
 if(!effective||!validate(effective))return 65;
 NSMutableArray *keys=[@[@"website",@"applied",@"draft"] mutableCopy];NSMutableArray *values=[@[web,applied,draft] mutableCopy];if(paths[@"archive"]){[keys addObject:@"archive"];[values addObject:MYBEffectiveRules(applied,web)];}NSMutableDictionary *before=[NSMutableDictionary dictionary],*attributes=[NSMutableDictionary dictionary];
 for(NSString *key in keys){NSString *path=paths[key];BOOL dir=NO;if([fm fileExistsAtPath:path isDirectory:&dir]){if(dir)return 73;NSData *bytes=[NSData dataWithContentsOfFile:path];if(!bytes)return 74;before[path]=bytes;attributes[path]=[fm attributesOfItemAtPath:path error:NULL]?:@{};}}
 int rc=0;for(NSUInteger i=0;i<keys.count;i++){NSString *path=paths[keys[i]];NSData *bytes=[NSPropertyListSerialization dataWithPropertyList:values[i] format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];if(!bytes||(writer?!writer(bytes,path):![bytes writeToFile:path atomically:YES])){rc=73;break;}}
 BOOL applyFailed=NO;if(!rc){rc=apply();applyFailed=rc!=0;}if(rc){for(NSString *key in keys){NSString *path=paths[key];NSData *bytes=before[path];if(bytes){[bytes writeToFile:path atomically:YES];NSDictionary *a=attributes[path];for(NSString *attribute in @[NSFileOwnerAccountID,NSFileGroupOwnerAccountID,NSFilePosixPermissions])if(a[attribute])[fm setAttributes:@{attribute:a[attribute]} ofItemAtPath:path error:NULL];}else[fm removeItemAtPath:path error:NULL];}if(applyFailed&&recover)recover();}
 return rc;
}


// ---- temporary (once / 15 minute) website exceptions ---------------------------------------------
// Only the website file changes: AppliedRules, the draft, the archive and the Shield lists are never
// touched, so a temporary exception can never become a permanent one by accident. The same gate /
// validate / apply / recover discipline as the permanent path applies; the previous file bytes are
// restored byte for byte when anything fails.
static BOOL MYBWebsiteWriteFile(NSDictionary *web,NSString *path,BOOL(^writer)(NSData *,NSString *)){
 NSData *bytes=[NSPropertyListSerialization dataWithPropertyList:web format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
 return bytes&&(writer?writer(bytes,path):[bytes writeToFile:path atomically:YES]);
}
static int MYBCommitWebsiteChange(NSDictionary *newWeb,NSDictionary *paths,int(^gate)(void),BOOL(^validate)(NSString *),int(^apply)(void),void(^recover)(void),BOOL(^writer)(NSData *,NSString *),NSString *expectedMode){
 if(!([@"Custom" isEqual:expectedMode]||MYBModeIDValid(expectedMode)))return 69;
 int gated=gate?gate():0;if(gated)return gated;
 NSString *base=[NSString stringWithContentsOfFile:paths[@"pac"] encoding:NSUTF8StringEncoding error:NULL];
 if(!base.length)base=[NSString stringWithContentsOfFile:paths[@"pacFallback"] encoding:NSUTF8StringEncoding error:NULL];
 NSString *effective=base?MYBWebsitePAC(base,MYBWebsiteLiveDomains(newWeb)):nil;if(!effective||!validate(effective))return 65;
 NSString *path=paths[@"website"];NSData *before=[NSData dataWithContentsOfFile:path];NSDictionary *attrs=before?[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL]:nil;
 if(!MYBWebsiteWriteFile(newWeb,path,writer)){if(before)[before writeToFile:path atomically:YES];return 73;}
 int rc=apply();
 if(rc){
  if(before)[before writeToFile:path atomically:YES];else [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
  for(NSString *a in @[NSFileOwnerAccountID,NSFileGroupOwnerAccountID,NSFilePosixPermissions])if(attrs[a])[NSFileManager.defaultManager setAttributes:@{a:attrs[a]} ofItemAtPath:path error:NULL];
  if(recover)recover();
 }
 return rc;
}
static int MYBCommitWebsiteTemp(NSString *domain,NSString *expectedMode,NSString *duration,NSDictionary *paths,int(^gate)(void),BOOL(^validate)(NSString *),int(^apply)(void),void(^recover)(void),BOOL(^writer)(NSData *,NSString *)){
 if(!MYBValidWebsiteDomain(domain)||![@[@"once",@"temp"] containsObject:duration])return 64;
 NSMutableDictionary *web=[[NSDictionary dictionaryWithContentsOfFile:paths[@"website"]] mutableCopy]?:[NSMutableDictionary dictionary];
 if([(MYBRuleArray(web[@"domains"])?:@[]) containsObject:domain])return 0; // already permanently allowed: nothing temporary to add
 NSMutableArray *temp=[NSMutableArray array];for(NSDictionary *e in MYBWebsiteTempLive(web))if(![e[@"domain"] isEqual:domain])[temp addObject:e];
 if(temp.count>=100)return 64;
 NSMutableDictionary *entry=[@{@"id":NSUUID.UUID.UUIDString,@"domain":domain,@"mode":duration} mutableCopy];MYBClockStamp(entry,[duration isEqual:@"once"]?120.0:900.0);[temp addObject:entry];
 web[@"temp"]=temp;web[@"revision"]=NSUUID.UUID.UUIDString;
 return MYBCommitWebsiteChange(web,paths,gate,validate,apply,recover,writer,expectedMode);
}
// domain==nil removes expired entries only. Returns 0 with *changed=NO when there was nothing to do.
static int MYBCommitWebsiteRevoke(NSString *domain,NSString *expectedMode,NSDictionary *paths,int(^gate)(void),BOOL(^validate)(NSString *),int(^apply)(void),void(^recover)(void),BOOL(^writer)(NSData *,NSString *),BOOL *changed){
 if(changed)*changed=NO;if(domain&&!MYBValidWebsiteDomain(domain))return 64;
 NSMutableDictionary *web=[[NSDictionary dictionaryWithContentsOfFile:paths[@"website"]] mutableCopy];if(!web)return 0;
 NSArray *stored=[web[@"temp"] isKindOfClass:NSArray.class]?web[@"temp"]:@[];NSMutableArray *kept=[NSMutableArray array];
 for(NSDictionary *e in MYBWebsiteTempLive(web))if(!domain||![e[@"domain"] isEqual:domain])[kept addObject:e];
 if(kept.count==stored.count)return 0;
 web[@"temp"]=kept;web[@"revision"]=NSUUID.UUID.UUIDString;if(changed)*changed=YES;
 return MYBCommitWebsiteChange(web,paths,gate,validate,apply,recover,writer,expectedMode);
}
