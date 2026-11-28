#include "../Shared/MYBPin.h"
#include "../Shared/MYBPACDecision.h"
// noXXX PIN protection in the privileged helper (see Shared/MYBPin.h for the design and its honest limits).
// Everything secret lives in a root-only folder: the PIN record, the device secret and the one-use authorisations. The only file
// Settings and the status page can read is PinState.plist, which says whether a PIN is set and until when attempts are locked.
static NSString *PinFolder(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/Protected");}
static NSString *PinRecordPath(void){return [PinFolder() stringByAppendingPathComponent:@"NoXXXPin.plist"];}
static NSString *PinSecretPath(void){return [PinFolder() stringByAppendingPathComponent:@"DeviceSecret"];}
static NSString *PinGrantsPath(void){return [PinFolder() stringByAppendingPathComponent:@"Authorisations.plist"];}
static NSString *PinPublicStatePath(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/PinState.plist");}
static BOOL PinPrepareFolder(void){
 NSString *f=PinFolder();if(!f.length)return NO;struct stat st;
 if(lstat(f.fileSystemRepresentation,&st)==0){if(!S_ISDIR(st.st_mode)||S_ISLNK(st.st_mode))return NO;}
 else if(![FM() createDirectoryAtPath:f withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL])return NO;
 chown(f.fileSystemRepresentation,0,0);chmod(f.fileSystemRepresentation,0700);return YES;
}
static BOOL PinWriteSecret(NSData *data,NSString *path){
 if(!data||![data writeToFile:path atomically:YES])return NO;chown(path.fileSystemRepresentation,0,0);chmod(path.fileSystemRepresentation,0600);return YES;
}
static NSData *PinDeviceSecret(BOOL create){
 NSData *secret=[NSData dataWithContentsOfFile:PinSecretPath()];if(secret.length==32)return secret;
 if(!create||!PinPrepareFolder())return nil;secret=MYBPinRandom(32);return PinWriteSecret(secret,PinSecretPath())?secret:nil;
}
static NSMutableDictionary *PinRecord(void){NSDictionary *r=[NSDictionary dictionaryWithContentsOfFile:PinRecordPath()];return [r[@"verifier"] isKindOfClass:NSData.class]?[r mutableCopy]:nil;}
static BOOL PinConfigured(void){return PinRecord()!=nil;}
static void PinPublishState(void){
 NSMutableDictionary *record=PinRecord();double left=record?MYBPinLockRemaining(record):0;
 NSDictionary *state=@{@"enabled":@(record!=nil),@"lockedFor":@((NSInteger)ceil(left)),@"updated":[NSDate date]}; // nothing secret: no verifier, no counts
 NSString *path=PinPublicStatePath();[FM() createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 if([state writeToFile:path atomically:YES]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
}
// Up to 16 bytes from standard input, one line: the PIN never travels in an argument list another process could read.
static NSString *PinReadLine(void){
 char buffer[18]={0};size_t used=0;
 while(used<sizeof(buffer)-1){char c;ssize_t n=read(0,&c,1);if(n<=0||c=='\n')break;if(c!='\r')buffer[used++]=c;}
 return used?[NSString stringWithUTF8String:buffer]:@"";
}
static int PinResultCode(MYBPinResult result){
 switch(result){case MYBPinOK:return 0;case MYBPinWrong:return MYB_PIN_EXIT_REQUIRED;case MYBPinLocked:return MYB_PIN_EXIT_LOCKED;case MYBPinBadFormat:return MYB_PIN_EXIT_FORMAT;case MYBPinNotSet:return MYB_PIN_EXIT_NOTSET;}
 return MYB_PIN_EXIT_REQUIRED;
}
// Checks a PIN against the stored record and saves the updated throttle. Prints the seconds to wait when locked.
static int PinCheck(NSString *pin,BOOL quiet){
 NSMutableDictionary *record=PinRecord();if(!record)return MYB_PIN_EXIT_NOTSET;
 NSData *secret=PinDeviceSecret(NO);if(!secret){logLine(@"PIN: the device secret is missing; the PIN cannot be checked");return MYB_PIN_EXIT_REQUIRED;}
 double retry=0;MYBPinResult result=MYBPinVerify(record,pin,secret,&retry);
 if(result!=MYBPinBadFormat&&result!=MYBPinNotSet){if(![record writeToFile:PinRecordPath() atomically:YES])return 73;chown(PinRecordPath().fileSystemRepresentation,0,0);chmod(PinRecordPath().fileSystemRepresentation,0600);}
 if(result==MYBPinLocked&&!quiet)printf("locked=%ld\n",(long)ceil(retry));
 PinPublishState();
 if(result!=MYBPinOK)logLine([NSString stringWithFormat:@"PIN: attempt refused (%@)",result==MYBPinLocked?@"locked":result==MYBPinWrong?@"wrong":@"malformed"]);
 return PinResultCode(result);
}
static NSMutableArray *PinGrantsLoad(void){return MYBPinGrantsLive([NSArray arrayWithContentsOfFile:PinGrantsPath()]);}
static BOOL PinGrantsSave(NSArray *grants){if(!PinPrepareFolder())return NO;if(![grants writeToFile:PinGrantsPath() atomically:YES])return NO;chown(PinGrantsPath().fileSystemRepresentation,0,0);chmod(PinGrantsPath().fileSystemRepresentation,0600);return YES;}
// pinauth <scope>: PIN on standard input; on success one scope-bound, one-use, two-minute authorisation is recorded.
static int pinAuthorise(NSString *scope){
 if(!MYBPinScopeValid(scope))return 64;
 int rc=PinCheck(PinReadLine(),NO);if(rc)return rc;
 return PinGrantsSave(MYBPinGrantIssue(PinGrantsLoad(),scope))?0:73;
}
// The guarded operation uses the authorisation: exactly once, for exactly this scope.
static int pinRequire(NSString *scope){
 NSMutableArray *live=PinGrantsLoad();BOOL ok=MYBPinGrantConsume(live,scope);
 PinGrantsSave(live);
 if(!ok)logLine([NSString stringWithFormat:@"PIN: %@ needs the noXXX PIN; nothing was changed",[scope hasPrefix:@"allow:"]?@"allowing a site":scope]);
 return ok?0:MYB_PIN_EXIT_REQUIRED;
}
// pinset: [current PIN, when one exists] then the new PIN, each on its own line of standard input.
static int pinSet(void){
 BOOL existing=PinConfigured();
 if(existing){int rc=PinCheck(PinReadLine(),NO);if(rc)return rc;}
 NSString *fresh=PinReadLine();if(!MYBPinFormatValid(fresh))return MYB_PIN_EXIT_FORMAT;
 NSData *secret=PinDeviceSecret(YES);if(!secret)return 73;
 NSDictionary *record=MYBPinRecordNew(fresh,secret,MYB_PIN_ITERATIONS);if(!record||!PinPrepareFolder()||![record writeToFile:PinRecordPath() atomically:YES])return 73;
 chown(PinRecordPath().fileSystemRepresentation,0,0);chmod(PinRecordPath().fileSystemRepresentation,0600);
 PinGrantsSave(@[]);PinPublishState();logLine(existing?@"PIN: the noXXX PIN was changed":@"PIN: a noXXX PIN was set");return 0;
}
static int pinRemove(void){
 if(!PinConfigured())return MYB_PIN_EXIT_NOTSET;
 int rc=PinCheck(PinReadLine(),NO);if(rc)return rc;
 [FM() removeItemAtPath:PinRecordPath() error:NULL];[FM() removeItemAtPath:PinGrantsPath() error:NULL];[FM() removeItemAtPath:PinSecretPath() error:NULL];
 PinPublishState();logLine(@"PIN: the noXXX PIN was removed");return 0;
}
static int pinStatusPrint(void){
 NSMutableDictionary *record=PinRecord();printf("enabled=%d locked=%ld\n",record?1:0,(long)ceil(record?MYBPinLockRemaining(record):0));PinPublishState();return 0;
}
// ---- guards -------------------------------------------------------------------------------------------------------
static BOOL PinEnabledFlag(void){return [loadSavedState()[@"enabled"] boolValue];}
// Engine-2 rules carry a "compact" section (RAGGR host rules, family patterns, words) that blocks in EVERY mode alike, so it is
// never what noXXX adds; but where it also matches an adult host it would make "blocked without noXXX" true and drop the PIN.
// The noXXX question is therefore answered on the base rules alone: the active generation's own canonical.json without its
// compact section, generated by the installed engine. That is exactly the rule set the PIN judged before compact rules existed.
// No compact section, no stored rules file, or rules that do not generate: the installed PAC files are compared as before.
static NSDictionary<NSString *,NSData *> *PinBaseRulePACs(void){
 NSData *canonical=[NSData dataWithContentsOfFile:StoredCanonicalPath([PACDirectory() stringByResolvingSymlinksInPath])];
 id parsed=canonical.length?[NSJSONSerialization JSONObjectWithData:canonical options:NSJSONReadingMutableContainers error:NULL]:nil;
 if(![parsed isKindOfClass:NSMutableDictionary.class]||!parsed[@"compact"])return nil;
 [parsed removeObjectForKey:@"compact"];
 NSData *base=[NSJSONSerialization dataWithJSONObject:parsed options:0 error:NULL];NSString *why=nil;
 NSDictionary<NSString *,NSData *> *pacs=base.length?MYBGenerateModePACs(base,GeneratorDirectory(),&why):nil;
 if(!pacs)logLine([@"PIN: base rules did not generate; comparing installed PACs (" stringByAppendingString:[(why?:@"unknown") stringByAppendingString:@")"]]);
 return pacs;
}
static NSString *PinRulesText(NSDictionary<NSString *,NSData *> *base,NSString *mode){
 NSData *data=base?base[mode]:nil;
 return data?[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]:[NSString stringWithContentsOfFile:PACFile(mode) encoding:NSUTF8StringEncoding error:NULL];
}
// A host noXXX is the reason for blocking: the selected mode blocks it and the same mode WITHOUT noXXX does not.
static BOOL PinHostProtected(NSString *host){
 NSString *mode=selectedMode();if(!MYBPinProtectedNow(PinConfigured(),PinEnabledFlag(),mode)||!host.length)return NO;
 NSMutableArray *rest=[MYBOptionsForModeID(mode) mutableCopy];[rest removeObject:@"blockXXX"];
 NSDictionary<NSString *,NSData *> *base=PinBaseRulePACs();
 NSString *with=PinRulesText(base,mode),*without=PinRulesText(base,MYBModeIDForOptions(rest));
 if(!with.length||!without.length)return YES; // cannot tell: treat as protected rather than open a hole
 for(NSString *name in @[host,[@"www." stringByAppendingString:host]]){
  NSString *url=[NSString stringWithFormat:@"https://%@/",name];
  if(MYBBlockedRoute(MYBEvaluatePAC(with,url,name))&&!MYBBlockedRoute(MYBEvaluatePAC(without,url,name)))return YES;
 }
 return NO;
}
static BOOL PinAnyHostProtected(NSArray *hosts){for(id h in hosts)if([h isKindOfClass:NSString.class]&&PinHostProtected([h lowercaseString]))return YES;return NO;
}
// Returns 0 when the change may go ahead, otherwise MYB_PIN_EXIT_REQUIRED (and nothing has changed).
static int pinGuardChange(NSString *scope,BOOL newEnabled,NSString *newMode){
 if(!MYBPinChangeWeakens(PinConfigured(),PinEnabledFlag(),selectedMode(),newEnabled,newMode))return 0;
 return pinRequire(scope);
}
static int pinGuardProtected(NSString *scope){
 if(!MYBPinProtectedNow(PinConfigured(),PinEnabledFlag(),selectedMode()))return 0;return pinRequire(scope);
}
static int pinGuardAllowSite(NSString *host){
 if(!PinHostProtected(host))return 0;return pinRequire(MYBPinAllowScope(host));
}
// localcustom: only entries that are NEW in the Allow list and that noXXX is what blocks need the PIN.
static int pinGuardRules(NSString *blockedCSV,NSString *allowedCSV){
 (void)blockedCSV;if(!MYBPinProtectedNow(PinConfigured(),PinEnabledFlag(),selectedMode()))return 0;
 NSDictionary *applied=[NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/MYbloXX/AppliedRules.plist")];NSArray *old=[applied[@"allowed"] isKindOfClass:NSArray.class]?applied[@"allowed"]:@[];
 NSMutableArray *added=[NSMutableArray array];for(NSString *h in [allowedCSV componentsSeparatedByString:@","])if(h.length&&![old containsObject:h])[added addObject:h];
 if(!PinAnyHostProtected(added))return 0;return pinRequire(@"rules");
}
