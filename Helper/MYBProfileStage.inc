// Profile staging and status, run by the helper (it has the entitlements the app lacks). See Shared/MYBProfileInstall.h for the mechanism.
// The record the app reads lives next to the other MYbloXX preference files. It carries a profile identifier, a state and a time: no
// profile contents.
#import "../Shared/MYBProfileInstall.h"
#import <dlfcn.h>
static NSString *ProfileInstallRecordPath(void){return MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.profileinstall.plist");}
// Diagnostic notes for the profile flows, kept in one small text file the person can copy from Troubleshooting. Identifiers, method
// shapes, outcomes and error codes only: no profile contents beyond MYbloXX\u2019s own published PAC address, no passcodes, no unrelated profiles.
static NSString *MYBProfileDiagPath(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/ProfileDiagnostics.txt");}
static void MYBProfileDiagNote(NSString *line){
 NSString *path=MYBProfileDiagPath();if(!path.length||!line.length)return;
 [FM() createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *old=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]?:@"";
 if(old.length>20000)old=[old substringFromIndex:old.length-12000];
 NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"yyyy-MM-dd HH:mm:ss";
 NSString *text=[old stringByAppendingFormat:@"%@ %@\n",[f stringFromDate:NSDate.date],line];
 if([text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
}
static id ProfileConnection(void){
 dlopen("/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration",RTLD_LAZY);
 Class cls=NSClassFromString(@"MCProfileConnection");SEL shared=sel_registerName("sharedConnection");
 if(!cls||![cls respondsToSelector:shared])return nil;
 return ((id(*)(id,SEL))objc_msgSend)(cls,shared);
}
// Only the bundled profile folders and plain names are accepted: an argument can never point anywhere else.
static NSString *BundledProfilePath(NSString *folder,NSString *name){
 if(![@[@"dns",@"profiles"] containsObject:folder?:@""])return nil;
 if(!name.length||name.length>48||[name rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"] invertedSet]].location!=NSNotFound)return nil;
 NSString *dir=[MYBBootstrapRoot() stringByAppendingPathComponent:[@"usr/share/mybloxx/" stringByAppendingString:folder]];
 NSString *path=[[dir stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"mobileconfig"];
 return [FM() fileExistsAtPath:path]?path:nil;
}
static int writeProfileRecord(NSDictionary *record){
 NSString *path=ProfileInstallRecordPath();if(!path)return 73;
 [FM() createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
 BOOL ok=[record writeToFile:path atomically:YES];
 if(ok){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}
 return ok?0:73;
}
// Exit 0: staged (accepted by iOS, not confirmed). 2: unavailable, 3: restricted, 4: failed, 5: profile file invalid,
// 6: another profile is waiting in Settings, 7: iOS cannot say whether one is, 8: staged but the helper could not open the installer (the app opens it). 6 and 7 changed nothing; only an explicit "replace" argument,
// sent after the person chose it, stages over a waiting profile.
static int stageBundledProfile(NSString *folder,NSString *name,BOOL replaceOther){
 NSString *path=BundledProfilePath(folder,name);NSData *data=path?[NSData dataWithContentsOfFile:path]:nil;
 NSString *identifier=MYBProfileIdentifier(data);NSDictionary *info=MYBProfileInfo(data);
 NSDictionary *result=MYBProfileStage(ProfileConnection(),data,[name stringByAppendingString:@".mobileconfig"],replaceOther);
 NSString *state=result[@"state"];
 NSMutableDictionary *record=[@{@"state":state,@"folder":folder?:@"",@"name":name?:@"",@"at":@([[NSDate date] timeIntervalSince1970]),@"detail":result[@"detail"]?:@""} mutableCopy];
 if(identifier)record[@"identifier"]=identifier;
 if(info){record[@"uuid"]=info[@"uuid"];record[@"key"]=info[@"key"];record[@"digest"]=info[@"digest"];} // identifies this exact profile; the identifier alone is shared by all six Legacy profiles
 if(result[@"api"])record[@"api"]=result[@"api"];
 for(NSString *k in @[@"category",@"errorText",@"attempts",@"route"])if(result[k])record[k]=result[k];
 if(result[@"errorDomain"]){record[@"errorDomain"]=result[@"errorDomain"];record[@"errorCode"]=result[@"errorCode"];}
 logLine([NSString stringWithFormat:@"PROFILE: stage %@/%@ -> %@ api=%@ error=%@/%@",folder,name,state,result[@"api"]?:@"-",result[@"errorDomain"]?:@"-",result[@"errorCode"]?:@"-"]);
 MYBProfileDiagNote([NSString stringWithFormat:@"[helper] stage %@/%@ -> %@ category=%@ api=%@ error=%@/%@ attempts=%@",folder,name,state,result[@"category"]?:@"-",result[@"api"]?:@"-",result[@"errorDomain"]?:@"-",result[@"errorCode"]?:@"-",result[@"attempts"]?:@"-"]);
 if([state isEqual:@"pendingother"])return 6;  // nothing was handed to iOS and nothing changed: no record is written
 if([state isEqual:@"pendingunknown"])return 7;
 if(info&&[state isEqual:@"staged"]){ // remember which bundled file was handed to iOS, so a later check can tell it from an older one
  NSMutableDictionary *old=[[NSDictionary dictionaryWithContentsOfFile:ProfileInstallRecordPath()] mutableCopy];NSMutableDictionary *digests=[old[@"stagedDigests"] mutableCopy]?:[NSMutableDictionary dictionary];
  digests[info[@"key"]]=info[@"digest"];record[@"stagedDigests"]=digests;if(old[@"checks"])record[@"checks"]=old[@"checks"];
 }else{NSDictionary *old=[NSDictionary dictionaryWithContentsOfFile:ProfileInstallRecordPath()];if(old[@"stagedDigests"])record[@"stagedDigests"]=old[@"stagedDigests"];if(old[@"checks"])record[@"checks"]=old[@"checks"];}
 int wrote=writeProfileRecord(record);
 if(wrote)return wrote;
 if([state isEqual:@"staged"]){
  // iOS accepted the profile: open Apple's own install screen for it. 8 = staged but this process could not open it (the app then tries its own routes).
  NSDictionary *nav=MYBOpenProfileInstallerSensitive();
  logLine([NSString stringWithFormat:@"PROFILE: installer navigation opened=%@ detail=%@ url=%@",nav[@"opened"],nav[@"detail"]?:@"-",nav[@"url"]?:@"-"]);
  MYBProfileDiagNote([NSString stringWithFormat:@"installer navigation: opened=%@ detail=%@ url=%@",nav[@"opened"],nav[@"detail"]?:@"-",nav[@"url"]?:@"-"]);
  return [nav[@"opened"] boolValue]?0:8;
 }
 if([state isEqual:@"pendingother"])return 6;
 if([state isEqual:@"pendingunknown"])return 7;
 if([state isEqual:@"unavailable"])return 2;
 if([state isEqual:@"restricted"])return 3;
 if([state isEqual:@"invalid"])return 5;
 return 4;
}
// Reads installed state back from iOS and stores it beside the staging record, so the menu can show it.
static int checkBundledProfile(NSString *folder,NSString *name){
 NSString *path=BundledProfilePath(folder,name);NSData *bundled=path?[NSData dataWithContentsOfFile:path]:nil;NSDictionary *info=bundled?MYBProfileInfo(bundled):nil;
 NSMutableDictionary *record=[[NSDictionary dictionaryWithContentsOfFile:ProfileInstallRecordPath()] mutableCopy]?:[NSMutableDictionary dictionary];
 NSMutableDictionary *checks=[record[@"checks"] mutableCopy]?:[NSMutableDictionary dictionary];
 NSMutableDictionary *staged=[record[@"stagedDigests"] mutableCopy]?:[NSMutableDictionary dictionary];
 NSString *state=info?MYBProfileVerifiedStateFor(ProfileConnection(),info,staged[info[@"key"]],bundled):@"unknown";
 if(info)checks[info[@"key"]]=@{@"state":state,@"at":@([[NSDate date] timeIntervalSince1970])};
 [record removeObjectForKey:@"checks_legacy"];
 record[@"checks"]=checks;
 if(([state isEqual:@"installed"]||[state isEqual:@"matched"])&&[record[@"key"] isEqual:info[@"key"]])record[@"state"]=state; // only this exact profile, never another one sharing the identifier; "installed" = payload verified, "matched" = identity match + recorded submission
 return writeProfileRecord(record);
}
