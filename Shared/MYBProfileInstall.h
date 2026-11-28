#pragma once
// Profile installation core, shared by the helper (which talks to iOS) and by tests (which use stand-in connections).
//
// How a bundled .mobileconfig reaches the iOS installer:
//   1. STAGE: the helper reads the bundled profile and queues it with iOS's own profile service (MCProfileConnection):
//        -queueFileDataForProfileInstallation:originalFileName:outError:   (preferred; file-style, shows under Profile Downloaded)
//        -queueProfileDataForInstallation:outError:                        (fallback)
//      Both are private APIs. Their iOS 10 runtime-header signatures are public (JaviSoto/iOS10-Runtime-Headers); the iOS 16.5.1 ones
//      have NOT been verified on a device, so a method is called only when its type encoding matches an accepted shape, and anything else
//      reports "unavailable" and the app falls back to Save to Files / Copy Link.
//   2. OPEN: only after staging succeeded does the app open the Settings page that shows the downloaded profile. iOS then shows its own
//      review and Install screens: staging is never reported as installed.
//   3. STATUS: installed state is read back from iOS. The identifier alone is NOT enough: all six Legacy Mode profiles share one identifier
//      (net.myxxdev.mybloxx), so a different profile (or an older build of the same one) with that identifier is not the requested
//      configuration. A profile counts as Installed only when iOS reports the same identifier AND the same PayloadUUID, and the bundled
//      file is the one MYbloXX staged (its SHA-256 was recorded at staging). Same identifier with another UUID is "Different Version
//      Installed"; a matching UUID that cannot be tied to the current bundled file is "Installed, Not Verified". Three different claims are kept
//      apart: identifier + UUID match observed ("Installed, Not Verified" when nothing else supports it), submitted bundled version recorded
//      ("Installed, Contents Not Checked"), and installed payload verified ("Installed": only when the installed data could be read and
//      compared, MYBProfilePayloadVerdict).
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>
#import <unistd.h>

#define MYB_PROFILE_PENDING_SECONDS 900.0 // a staged profile that was never installed is forgotten after 15 minutes

// The top-level PayloadIdentifier of a profile, or nil when the data is not a profile.
static inline NSString *MYBProfileIdentifier(NSData *data){
 if(!data.length||data.length>2*1024*1024)return nil;
 id plist=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
 if(![plist isKindOfClass:NSDictionary.class]||![plist[@"PayloadType"] isEqual:@"Configuration"])return nil;
 NSString *identifier=plist[@"PayloadIdentifier"];
 return [identifier isKindOfClass:NSString.class]&&identifier.length&&identifier.length<=200?identifier:nil;
}
// Who a bundled profile is: identifier, top-level PayloadUUID (upper case), SHA-256 of the file, and the key identifier|uuid that tells the
// six profiles sharing one identifier apart. nil when the data is not a usable profile.
static inline NSString *MYBProfileDigest(NSData *data){
 unsigned char out[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,out);
 NSMutableString *hex=[NSMutableString string];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",out[i]];return hex;
}
static inline NSDictionary *MYBProfileInfo(NSData *data){
 NSString *identifier=MYBProfileIdentifier(data);if(!identifier)return nil;
 id plist=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
 NSString *uuid=[plist[@"PayloadUUID"] isKindOfClass:NSString.class]?[plist[@"PayloadUUID"] uppercaseString]:nil;
 if(!uuid.length||![[NSUUID alloc] initWithUUIDString:uuid])return nil;
 return @{@"identifier":identifier,@"uuid":uuid,@"digest":MYBProfileDigest(data),@"key":[NSString stringWithFormat:@"%@|%@",identifier,uuid]};
}
// A method's type encoding with the stack offsets removed ("@40@0:8@16" becomes "@@:@").
static inline NSString *MYBProfileEncoding(Class cls,SEL sel){
 Method m=class_getInstanceMethod(cls,sel);if(!m)return nil;
 const char *enc=method_getTypeEncoding(m);if(!enc)return nil;
 NSMutableString *out=[NSMutableString string];
 for(const char *p=enc;*p;p++)if(*p<'0'||*p>'9')[out appendFormat:@"%c",*p];
 return out;
}
// The one shape a stage method may have: it returns an object, its last argument is NSError ** (or an object) and the earlier ones are
// objects. That is the shape both methods have in the iOS 10 runtime headers (the only published signatures). Methods that return void,
// BOOL or char are NOT accepted: a void method has no result to judge, and a BOOL method's meaning has no source, so calling either and
// reporting "staged" would be a guess. They are reported as unavailable, never called.
static inline BOOL MYBProfileEncodingOK(NSString *enc,NSUInteger args){
 if(!enc)return NO;
 NSString *tail=args==3?@"@:@@":@"@:@";
 for(NSString *e in @[@"^@",@"@"]){if([enc isEqualToString:[NSString stringWithFormat:@"@%@%@",tail,e]])return YES;}
 return NO;
}
// Whether iOS already holds another downloaded profile waiting to be reviewed: none | other | unknown.
// popProfileDataFromHeadOfInstallationQueue removes the profile it returns, so it is never used. Two NON-destructive readers are recognised, each
// only when its exact encoding matches: a synchronous peek supplied by name (tests, or one verified on a device) and the asynchronous
// -peekProfileDataFromPurgatoryForDeviceType:withCompletion: declared by the iOS 16 service protocol (MCXPCProtocol). The latter is called
// only on an object whose class has exactly that method shape; its device-type argument is 0 (this device) and the answer is recorded as
// evidence. A waiting profile that is byte-identical to the one being staged is not "another" profile.
static inline NSArray<NSString *> *MYBProfileVerifiedPeekSelectors(void){return @[];}
static inline NSString *MYBProfilePeekAsyncState(id connection,NSData *ours){
 SEL sel=sel_registerName("peekProfileDataFromPurgatoryForDeviceType:withCompletion:");
 if(![@"v@:Q@?" isEqualToString:MYBProfileEncoding(object_getClass(connection),sel)?:@""])return nil;
 __block NSData *got=nil;__block NSError *err=nil;dispatch_semaphore_t sem=dispatch_semaphore_create(0);
 void(^cb)(NSData *,NSError *)=^(NSData *d,NSError *e){got=d;err=e;dispatch_semaphore_signal(sem);};
 ((void(*)(id,SEL,unsigned long long,id))objc_msgSend)(connection,sel,0ULL,cb);
 if(dispatch_semaphore_wait(sem,dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC))!=0||err)return @"unknown";
 if(![got isKindOfClass:NSData.class]||!got.length)return @"none";
 return (ours&&[got isEqualToData:ours])?@"none":@"other";
}
// The synchronous peek the class itself has on iOS 16.5.1 (peekProfileDataFromPurgatoryForDeviceType: returns an object; the device-type argument is
// 0, this device). Non-destructive. An answer that is not NSData or nil is "unknown".
static inline NSString *MYBProfilePeekSyncState(id connection,NSData *ours){
 SEL sel=sel_registerName("peekProfileDataFromPurgatoryForDeviceType:");
 if(![@"@@:Q" isEqualToString:MYBProfileEncoding(object_getClass(connection),sel)?:@""])return nil;
 id got=((id(*)(id,SEL,unsigned long long))objc_msgSend)(connection,sel,0ULL);
 if(!got)return @"none";
 if(![got isKindOfClass:NSData.class])return @"unknown";
 if(![(NSData *)got length])return @"none";
 return (ours&&[(NSData *)got isEqualToData:ours])?@"none":@"other";
}
static inline NSString *MYBProfilePendingStateOurs(id connection,NSArray<NSString *> *peekSelectors,NSData *ours){
 if(!connection)return @"unknown";
 for(NSString *name in peekSelectors){
  SEL sel=NSSelectorFromString(name);
  if(![@"@@:" isEqualToString:MYBProfileEncoding(object_getClass(connection),sel)?:@""])continue;
  id pending=((id(*)(id,SEL))objc_msgSend)(connection,sel);
  return pending?@"other":@"none";
 }
 return MYBProfilePeekSyncState(connection,ours)?:MYBProfilePeekAsyncState(connection,ours)?:@"unknown";
}
static inline NSString *MYBProfilePendingStateWith(id connection,NSArray<NSString *> *peekSelectors){return MYBProfilePendingStateOurs(connection,peekSelectors,nil);}
// The stage routes, in the order they are tried. A route is called ONLY when the connection's method has exactly one of its listed type
// encodings; anything else is never called. The five selectors come from: the Settings-side acceptance methods used by an existing Settings
// pane (chelaxian/ios.ratu.sh, DPCRootListController), the iOS 16 service protocol's asynchronous queue method (MCXPCProtocol), and the two
// iOS 10 runtime-header methods. Which of them the real iOS 16.5.1 client class offers, and whether this caller may use them, is established
// only by the device diagnostics, never assumed here.
static inline NSArray<NSDictionary *> *MYBProfileStageRoutes(void){
 return @[
  // The class's own queue method that takes transitionToUI (shape seen on iOS 16.5.1: @@:@@@B^@). With transitionToUI YES the service is
  // asked to go straight to the install screen instead of posting the "Profile Downloaded" alert. Device evidence is still needed that it does.
  @{@"id":@"uiDirect",@"sel":@"_queueDataForAcceptance:originalFileName:originatingBundleID:transitionToUI:outError:",@"enc":@[@"@@:@@@B^@",@"@@:@@@c^@"]},
  @{@"id":@"acceptBundle",@"sel":@"queueFileDataForAcceptance:originalFileName:forBundleID:outError:",@"enc":@[@"@@:@@@^@",@"@@:@@@@"]},
  @{@"id":@"accept",@"sel":@"queueFileDataForAcceptance:originalFileName:outError:",@"enc":@[@"@@:@@^@",@"@@:@@@"]},
  @{@"id":@"async",@"sel":@"queueProfileDataForInstallation:originalFileName:originatingBundleID:transitionToUI:completion:",@"enc":@[@"v@:@@@B@?",@"v@:@@@c@?"]},
  @{@"id":@"fileInstall",@"sel":@"queueFileDataForProfileInstallation:originalFileName:outError:",@"enc":@[@"@@:@@^@",@"@@:@@@"]},
  @{@"id":@"dataInstall",@"sel":@"queueProfileDataForInstallation:outError:",@"enc":@[@"@@:@^@",@"@@:@@"]}];
}
static inline NSString *MYBProfileErrorCategory(NSError *e){
 NSString *t=[(e.localizedDescription?:@"") lowercaseString];
 if([t containsString:@"restrict"]||[t containsString:@"not allowed"]||[t containsString:@"disallow"])return @"restricted";
 if([t containsString:@"entitlement"]||[t containsString:@"lacks permission"]||[t containsString:@"profiled-access"]||([(e.domain?:@"") isEqual:@"MCXPCErrorDomain"]&&e.code==39000))return @"denied";
 return @"error";
}
// One call of one route. Returns @{ok, category, errorDomain, errorCode, errorText}. transitionToUI is NO: MYbloXX opens Apple's install screen
// itself after staging succeeded (MYBOpenProfileInstallerSensitive); whether transitionToUI:YES would do that for us is a device question.
static inline NSDictionary *MYBProfileStageAttempt(id connection,NSDictionary *route,NSString *enc,NSData *data,NSString *name){
 SEL sel=sel_registerName([route[@"sel"] UTF8String]);NSString *rid=route[@"id"],*bundle=@"com.apple.Preferences";
 if([rid isEqual:@"uiDirect"]){
  __unsafe_unretained NSError *uiError=nil;
  id uiResult=((id(*)(id,SEL,id,id,id,BOOL,void *))objc_msgSend)(connection,sel,data,name,bundle,YES,(void *)&uiError);
  NSError *uiFail=uiError;
  if(uiFail)return @{@"ok":@NO,@"category":MYBProfileErrorCategory(uiFail),@"errorDomain":uiFail.domain?:@"",@"errorCode":@(uiFail.code),@"errorText":uiFail.localizedDescription?:@""};
  return uiResult?@{@"ok":@YES}:@{@"ok":@NO,@"category":@"nilresult"};
 }
 if([rid isEqual:@"async"]){
  __block NSError *err=nil;dispatch_semaphore_t sem=dispatch_semaphore_create(0);
  void(^cb)(NSString *,unsigned long long,NSError *)=^(__unused NSString *a,__unused unsigned long long b,NSError *e){err=e;dispatch_semaphore_signal(sem);};
  ((void(*)(id,SEL,id,id,id,BOOL,id))objc_msgSend)(connection,sel,data,name,bundle,NO,cb);
  if(dispatch_semaphore_wait(sem,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC))!=0)return @{@"ok":@NO,@"category":@"timeout"};
  if(err)return @{@"ok":@NO,@"category":MYBProfileErrorCategory(err),@"errorDomain":err.domain?:@"",@"errorCode":@(err.code),@"errorText":err.localizedDescription?:@""};
  return @{@"ok":@YES};
 }
 BOOL errorPointer=[enc hasSuffix:@"^@"];
 __unsafe_unretained NSError *error=nil; // an out-parameter filled by iOS; read once, right after the call
 void *errArg=errorPointer?(void *)&error:NULL;id result=nil;
 if([rid isEqual:@"acceptBundle"])result=((id(*)(id,SEL,id,id,id,void *))objc_msgSend)(connection,sel,data,name,bundle,errArg);
 else if([rid isEqual:@"dataInstall"])result=((id(*)(id,SEL,id,void *))objc_msgSend)(connection,sel,data,errArg);
 else result=((id(*)(id,SEL,id,id,void *))objc_msgSend)(connection,sel,data,name,errArg);
 NSError *failure=error;
 if(failure)return @{@"ok":@NO,@"category":MYBProfileErrorCategory(failure),@"errorDomain":failure.domain?:@"",@"errorCode":@(failure.code),@"errorText":failure.localizedDescription?:@""};
 if(!result)return @{@"ok":@NO,@"category":@"nilresult"}; // an object-returning method that returned nil with no error did not accept the profile
 return @{@"ok":@YES};
}
// Outcome of staging. state: staged | pendingother | pendingunknown | unavailable | restricted | failed | invalid. category (why, when not staged):
// noservice | noroute | denied | restricted | error | nilresult | timeout. "attempts" lists every route tried with its outcome.
// A waiting profile is never replaced unless replaceOther is YES, which only an explicit choice by the person may set.
// "staged" means iOS accepted the call without an error; Apple offers no readback of the queue, so it is reported with confirmed=NO.
static inline NSDictionary *MYBProfileStageWithPeek(id connection,NSData *data,NSString *fileName,BOOL replaceOther,NSArray<NSString *> *peekSelectors){
 if(!MYBProfileIdentifier(data))return @{@"state":@"invalid",@"detail":@"The profile file is missing or damaged."};
 if(!connection)return @{@"state":@"unavailable",@"category":@"noservice",@"detail":@"iOS did not hand MYbloXX® the profile service (MCProfileConnection)."};
 Class cls=object_getClass(connection);
 NSMutableArray *usable=[NSMutableArray array],*shapes=[NSMutableArray array];
 for(NSDictionary *route in MYBProfileStageRoutes()){
  NSString *enc=MYBProfileEncoding(cls,sel_registerName([route[@"sel"] UTF8String]));
  [shapes addObject:[NSString stringWithFormat:@"%@=%@",route[@"id"],enc?:@"absent"]];
  if(enc&&[route[@"enc"] containsObject:enc])[usable addObject:@{@"route":route,@"enc":enc}];
 }
 if(!usable.count)return @{@"state":@"unavailable",@"category":@"noroute",@"detail":@"The profile service is present, but none of the install methods MYbloXX® knows has the exact expected shape. Nothing was called.",@"api":[shapes componentsJoinedByString:@" "]};
 NSString *pending=MYBProfilePendingStateOurs(connection,peekSelectors,data);
 if(!replaceOther&&[pending isEqual:@"other"])return @{@"state":@"pendingother",@"detail":@"Another profile is already waiting in Settings."};
 if(!replaceOther&&[pending isEqual:@"unknown"])return @{@"state":@"pendingunknown",@"detail":@"iOS cannot say whether another profile is already waiting in Settings."};
 NSString *name=fileName.length?fileName:@"MYbloXX.mobileconfig";
 NSMutableArray *log=[NSMutableArray array];NSDictionary *last=nil;NSString *lastApi=nil;BOOL sawRestricted=NO;
 for(NSDictionary *u in usable){
  NSDictionary *route=u[@"route"];NSString *api=[route[@"sel"] componentsSeparatedByString:@":"].firstObject;
  NSDictionary *r=MYBProfileStageAttempt(connection,route,u[@"enc"],data,name);
  [log addObject:[NSString stringWithFormat:@"%@:%@%@",route[@"id"],[r[@"ok"] boolValue]?@"ok":(r[@"category"]?:@"failed"),r[@"errorCode"]?[NSString stringWithFormat:@"(%@ %@)",r[@"errorDomain"],r[@"errorCode"]]:@""]];
  if([r[@"ok"] boolValue])return @{@"state":@"staged",@"api":api,@"route":route[@"id"],@"confirmed":@NO,@"attempts":[log componentsJoinedByString:@"; "],@"detail":@"iOS accepted the profile. It offers no way to confirm it is waiting; Settings shows it if it is."};
  last=r;lastApi=api;if([r[@"category"] isEqual:@"restricted"])sawRestricted=YES;
 }
 NSString *cat=sawRestricted?@"restricted":(last[@"category"]?:@"error");
 NSMutableDictionary *out=[@{@"state":sawRestricted?@"restricted":@"failed",@"category":cat,@"api":lastApi?:@"",@"attempts":[log componentsJoinedByString:@"; "],@"detail":sawRestricted?@"This iPhone restricts installing profiles.":@"iOS did not accept the profile."} mutableCopy];
 if(last[@"errorDomain"]){out[@"errorDomain"]=last[@"errorDomain"];out[@"errorCode"]=last[@"errorCode"];}
 if(last[@"errorText"])out[@"errorText"]=last[@"errorText"];
 return out;
}
static inline NSDictionary *MYBProfileStage(id connection,NSData *data,NSString *fileName,BOOL replaceOther){
 return MYBProfileStageWithPeek(connection,data,fileName,replaceOther,MYBProfileVerifiedPeekSelectors());
}
// Installed state of a profile by identifier: installed | notinstalled | unknown.
static inline NSString *MYBProfileInstalledState(id connection,NSString *identifier){
 if(!connection||!identifier.length)return @"unknown";
 SEL sel=sel_registerName("installedProfileWithIdentifier:");
 if(![@[@"@@:@"] containsObject:MYBProfileEncoding(object_getClass(connection),sel)?:@""])return @"unknown";
 id profile=((id(*)(id,SEL,id))objc_msgSend)(connection,sel,identifier);
 return profile?@"installed":@"notinstalled";
}
// Installed state of THIS bundled profile: installed | different | unverified | notinstalled | unknown.
//   notinstalled  iOS holds no profile with the identifier
//   different     one is installed but its PayloadUUID is not this profile's (another Legacy profile, or an older build), or MYbloXX staged
//                 a different bundled file for this profile than the current one
//   unverified    same identifier and PayloadUUID, but nothing ties the installed payload to the current bundled file (installed from
//                 Files, an older release or another way), or iOS would not give the UUID
//   matched       same identifier, same PayloadUUID (an identity match OBSERVED), and the file MYbloXX submitted for this profile is the current bundled
//                 one (a submission RECORDED). The installed contents were not read, so this does not prove what iOS installed.
//   installed     the installed PAYLOAD was read from iOS and contains everything the current bundled profile specifies (VERIFIED)
//   unknown       iOS would not answer the identifier lookup
// stagedDigest is the SHA-256 recorded when MYbloXX last staged this profile (nil if never).
static inline NSString *MYBProfileInstalledStateFor(id connection,NSDictionary *info,NSString *stagedDigest){
 NSString *base=MYBProfileInstalledState(connection,info[@"identifier"]);
 if(![base isEqual:@"installed"])return base;
 SEL sel=sel_registerName("installedProfileWithIdentifier:");
 id profile=((id(*)(id,SEL,id))objc_msgSend)(connection,sel,info[@"identifier"]);
 SEL uuidSel=sel_registerName("UUID");
 if(![@"@@:" isEqualToString:MYBProfileEncoding(object_getClass(profile),uuidSel)?:@""])return @"unverified";
 id uuid=((id(*)(id,SEL))objc_msgSend)(profile,uuidSel);
 NSString *text=[uuid isKindOfClass:NSString.class]?[uuid uppercaseString]:([uuid isKindOfClass:NSUUID.class]?[(NSUUID *)uuid UUIDString]:nil);
 if(!text.length)return @"unverified";
 if(![text isEqualToString:info[@"uuid"]])return @"different";
 if(!stagedDigest.length)return @"unverified";
 return [stagedDigest isEqualToString:info[@"digest"]]?@"matched":@"different";
}
// Reads the INSTALLED profile's data through the service and compares it with the bundled profile. same | different | unreadable.
// "same" means every identifier, UUID and setting the bundled profile specifies is present with the same value in the installed one (iOS may
// add keys of its own, so extra keys are ignored); the payload count must match. Only a readable answer can be "same" or "different": a service
// that will not hand the data out is "unreadable", never a guess in either direction.
static inline BOOL MYBProfileDictCovers(NSDictionary *installed,NSDictionary *bundled){
 for(NSString *k in bundled){
  id want=bundled[k],have=installed[k];if(!have)return NO;
  if([want isKindOfClass:NSString.class]&&[have isKindOfClass:NSString.class]&&([k isEqual:@"PayloadUUID"]||[k hasSuffix:@"UUID"])){if([(NSString *)want caseInsensitiveCompare:have]!=NSOrderedSame)return NO;continue;}
  if(![want isEqual:have])return NO;
 }
 return YES;
}
static inline BOOL MYBProfilePayloadCovers(NSDictionary *installed,NSDictionary *bundled){
 if(![installed isKindOfClass:NSDictionary.class]||![bundled isKindOfClass:NSDictionary.class])return NO;
 NSMutableDictionary *top=[bundled mutableCopy];[top removeObjectForKey:@"PayloadContent"];
 if(!MYBProfileDictCovers(installed,top))return NO;
 NSArray *want=bundled[@"PayloadContent"],*have=installed[@"PayloadContent"];
 want=[want isKindOfClass:NSArray.class]?want:@[];have=[have isKindOfClass:NSArray.class]?have:@[];
 if(want.count!=have.count)return NO;
 for(NSDictionary *w in want){
  BOOL found=NO;for(NSDictionary *h in have)if([h isKindOfClass:NSDictionary.class]&&MYBProfileDictCovers(h,w)){found=YES;break;}
  if(!found)return NO;
 }
 return YES;
}
static inline NSDictionary *MYBProfileDecodePlist(NSData *data){
 if(!data.length||data.length>2*1024*1024)return nil;
 id plist=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
 if([plist isKindOfClass:NSDictionary.class])return plist;
 // A signed profile wraps the plist: take the XML document out of it.
 NSData *open=[@"<?xml" dataUsingEncoding:NSASCIIStringEncoding],*close=[@"</plist>" dataUsingEncoding:NSASCIIStringEncoding];
 NSRange a=[data rangeOfData:open options:0 range:NSMakeRange(0,data.length)],b=[data rangeOfData:close options:NSDataSearchBackwards range:NSMakeRange(0,data.length)];
 if(a.location==NSNotFound||b.location==NSNotFound||b.location<a.location)return nil;
 plist=[NSPropertyListSerialization propertyListWithData:[data subdataWithRange:NSMakeRange(a.location,b.location+b.length-a.location)] options:NSPropertyListImmutable format:NULL error:NULL];
 return [plist isKindOfClass:NSDictionary.class]?plist:nil;
}
static inline NSString *MYBProfilePayloadVerdict(id connection,NSString *identifier,NSData *bundled){
 if(!connection||!identifier.length)return @"unreadable";
 NSDictionary *want=MYBProfileDecodePlist(bundled);if(!want)return @"unreadable";
 for(NSString *name in @[@"installedProfileDataWithIdentifier:",@"installedSystemProfileDataWithIdentifier:",@"installedUserProfileDataWithIdentifier:"]){
  SEL sel=NSSelectorFromString(name);
  if(![@"@@:@" isEqualToString:MYBProfileEncoding(object_getClass(connection),sel)?:@""])continue;
  id data=((id(*)(id,SEL,id))objc_msgSend)(connection,sel,identifier);
  if(![data isKindOfClass:NSData.class])continue;
  NSDictionary *have=MYBProfileDecodePlist(data);if(!have)continue;
  return MYBProfilePayloadCovers(have,want)?@"same":@"different";
 }
 return @"unreadable";
}
// The strongest state available: identity state, upgraded to "installed" only by a verified payload, or to "different" by a readable payload
// that does not match. An unreadable payload leaves the identity-based state exactly as it was.
static inline NSString *MYBProfileVerifiedStateFor(id connection,NSDictionary *info,NSString *stagedDigest,NSData *bundled){
 NSString *state=MYBProfileInstalledStateFor(connection,info,stagedDigest);
 if(![@[@"matched",@"unverified",@"different"] containsObject:state])return state;
 NSString *verdict=MYBProfilePayloadVerdict(connection,info[@"identifier"],bundled);
 if([verdict isEqual:@"same"])return @"installed";
 if([verdict isEqual:@"different"])return @"different";
 return state;
}
static inline NSString *MYBProfileStatusLabel(NSString *state){
 if([state isEqual:@"installed"])return @"Installed";
 if([state isEqual:@"matched"])return @"Installed, Contents Not Checked";
 if([state isEqual:@"different"])return @"Different Version Installed";
 if([state isEqual:@"unverified"])return @"Installed, Not Verified";
 if([state isEqual:@"notinstalled"])return @"Not Installed";
 return @"Unable to Check";
}
// One plain sentence per state, so nothing claims more than was observed.
static inline NSString *MYBProfileStateExplanation(NSString *state){
 if([state isEqual:@"installed"])return @"iOS gave MYbloXX\u00ae the installed profile and its contents match this version.";
 if([state isEqual:@"matched"])return @"iOS reports a profile with this name and ID, and MYbloXX\u00ae submitted this version. iOS would not let MYbloXX\u00ae read what is installed, so the contents were not compared.";
 if([state isEqual:@"unverified"])return @"iOS reports a profile with this name, but nothing confirms it is this version.";
 if([state isEqual:@"different"])return @"A different MYbloXX\u00ae profile or version is installed.";
 if([state isEqual:@"notinstalled"])return @"iOS does not list this profile.";
 return @"iOS did not answer.";
}
// The record kept between taps and across Settings restarts. One profile at a time: a second tap for the same profile while it is
// pending only reopens the installer; a different profile replaces it (iOS holds one downloaded profile at a time).
static inline BOOL MYBProfilePendingFresh(NSDictionary *record,NSTimeInterval now){
 if(![record isKindOfClass:NSDictionary.class])return NO;
 NSNumber *at=record[@"at"];if(![at isKindOfClass:NSNumber.class])return NO;
 NSString *state=record[@"state"];if(![state isEqual:@"staged"])return NO;
 return now-at.doubleValue>=0&&now-at.doubleValue<MYB_PROFILE_PENDING_SECONDS;
}
// The pages that show a downloaded profile, tried in order. The first is the profile-install page, the second the Device Management list.
static inline NSArray<NSString *> *MYBProfileInstallerURLs(void){
 return @[@"prefs:root=General&path=ManagedConfigurationList/PurgatoryInstallation",@"prefs:root=General&path=ManagedConfigurationList"];
}
// What a profile row shows: the installed check, except that a profile MYbloXX staged within the pending window and that iOS does not yet
// report as installed shows "Accepted, Not Confirmed". Only the record for this same profile (same identifier and PayloadUUID) counts, never
// another profile that happens to share the identifier. "Accepted, Not Confirmed" is never shown as, or mistaken for, Installed.
static inline NSString *MYBProfileDisplayLabel(NSString *checkState,NSDictionary *record,NSString *key,NSTimeInterval now){
if(![@[@"installed",@"matched"] containsObject:checkState?:@""]&&key.length&&[record[@"key"] isEqual:key]&&MYBProfilePendingFresh(record,now))return @"Accepted, Not Confirmed";
 return MYBProfileStatusLabel(checkState);
}

// Opens Apple's own profile review/install screen for the profile that is already staged. This is the navigation Apple's profile service
// uses itself (the Install button of the "Profile Downloaded" alert): the constant kMCSettingsURLProfilePurgatoryInstallation exported by
// ManagedConfiguration, opened with -[LSApplicationWorkspace openSensitiveURL:withOptions:]. It stages nothing: staging is a separate step.
// The constant is read from the framework at run time (its value is Apple's, not a hardcoded prefs URL) and the selector is called only when
// its encoding is the expected BOOL-returning, two-object-argument shape. Returns @{opened, url, detail}; "opened" means the system accepted
// the request, nothing more.
static inline NSDictionary *MYBOpenProfileInstallerSensitive(void){
 void *image=dlopen("/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration",RTLD_LAZY);
 CFStringRef *symbol=image?(CFStringRef *)dlsym(image,"kMCSettingsURLProfilePurgatoryInstallation"):NULL;
 if(!symbol||!*symbol)return @{@"opened":@NO,@"detail":@"constant-missing"};
 NSString *text=(__bridge NSString *)*symbol;NSURL *url=[text isKindOfClass:NSString.class]?[NSURL URLWithString:text]:nil;
 if(!url)return @{@"opened":@NO,@"detail":@"constant-not-a-url"};
 Class cls=NSClassFromString(@"LSApplicationWorkspace");SEL shared=sel_registerName("defaultWorkspace"),open=sel_registerName("openSensitiveURL:withOptions:");
 if(!cls||![cls respondsToSelector:shared])return @{@"opened":@NO,@"url":text,@"detail":@"workspace-missing"};
 id workspace=((id(*)(id,SEL))objc_msgSend)(cls,shared);
 NSString *enc=workspace?MYBProfileEncoding(object_getClass(workspace),open):nil;
 if(![@[@"B@:@@",@"c@:@@"] containsObject:enc?:@""])return @{@"opened":@NO,@"url":text,@"detail":[@"selector-shape=" stringByAppendingString:enc?:@"none"]};
 BOOL ok=((BOOL(*)(id,SEL,id,id))objc_msgSend)(workspace,open,url,nil);
 return @{@"opened":@(ok),@"url":text,@"detail":ok?@"accepted":@"refused"};
}

// What the person is told when staging did not work: the real failure category, never a guess about the iOS version.
// `who` names the process the call was made from ("helper" or "Settings"). Returns @{title, detail}.
static inline NSDictionary *MYBProfileFailureMessage(NSDictionary *r,NSString *who){
 NSString *cat=r[@"category"]?:@"error",*code=r[@"errorCode"]?[NSString stringWithFormat:@" (%@ %@)",r[@"errorDomain"]?:@"",r[@"errorCode"]]:@"";
 NSString *text=[r[@"errorText"] length]?[NSString stringWithFormat:@" iOS said: %@",r[@"errorText"]]:@"";
 NSString *title,*detail;
 if([cat isEqual:@"noservice"]){title=@"Profile Service Not Found";detail=[NSString stringWithFormat:@"iOS did not hand the %@ the profile service, so nothing was sent.",who];}
 else if([cat isEqual:@"noroute"]){title=@"No Matching Install Method";detail=[NSString stringWithFormat:@"The profile service is there, but none of the install methods MYbloXX® knows has the exact expected shape for the %@. Nothing was called.",who];}
 else if([cat isEqual:@"denied"]){title=@"iOS Denied Access to the Profile Service";detail=[NSString stringWithFormat:@"The call from the %@ was made and iOS refused that caller%@.%@",who,code,text];}
 else if([cat isEqual:@"restricted"]){title=@"Profile Installation Restricted";detail=@"This iPhone restricts installing profiles. If your own restrictions cause this, change them in Settings > Screen Time.";}
 else if([cat isEqual:@"timeout"]){title=@"iOS Did Not Answer";detail=[NSString stringWithFormat:@"The profile service did not answer the %@ in time, so the profile may not be waiting.",who];}
 else if([cat isEqual:@"nilresult"]){title=@"iOS Did Not Accept the Profile";detail=[NSString stringWithFormat:@"The call from the %@ returned nothing and no error, so MYbloXX® does not treat the profile as accepted.",who];}
 else{title=@"iOS Refused the Profile";detail=[NSString stringWithFormat:@"The call from the %@ failed%@.%@",who,code,text];}
 return @{@"title":title,@"detail":[detail stringByAppendingString:@" Help & Repair can check and repair it."]};
}
// A read-only probe of this process's view of the profile service, as lines of text: who is calling, which MCProfileConnection methods
// related to queueing, acceptance, the purgatory or installation exist and their exact encodings, which stage routes would be called, and
// what the non-destructive peek says. It stages, installs and removes nothing and records no profile contents.
static inline NSArray<NSString *> *MYBProfileProbeLines(NSString *who){
 NSMutableArray *lines=[NSMutableArray array];
 void *sec=dlsym(RTLD_DEFAULT,"SecTaskCreateFromSelf");void *copy=dlsym(RTLD_DEFAULT,"SecTaskCopyValueForEntitlement");NSMutableArray *ent=[NSMutableArray array];
 if(sec&&copy){
  CFTypeRef task=((CFTypeRef(*)(CFAllocatorRef))sec)(kCFAllocatorDefault);
  if(task){for(NSString *k in @[@"com.apple.managedconfiguration.profiled-access",@"platform-application",@"com.apple.private.security.no-sandbox",@"com.apple.private.managedconfiguration.profiled-access"]){
    CFTypeRef v=((CFTypeRef(*)(CFTypeRef,CFStringRef,CFErrorRef *))copy)(task,(__bridge CFStringRef)k,NULL);[ent addObject:[NSString stringWithFormat:@"%@=%@",k,v?@"yes":@"no"]];if(v)CFRelease(v);}CFRelease(task);}
 }
 [lines addObject:[NSString stringWithFormat:@"[%@] caller: process=%@ uid=%d euid=%d entitlements: %@",who,NSProcessInfo.processInfo.processName,getuid(),geteuid(),ent.count?[ent componentsJoinedByString:@", "]:@"unreadable"]];
 dlopen("/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration",RTLD_LAZY);
 Class cls=NSClassFromString(@"MCProfileConnection");SEL shared=sel_registerName("sharedConnection");
 id conn=(cls&&[cls respondsToSelector:shared])?((id(*)(id,SEL))objc_msgSend)(cls,shared):nil;
 [lines addObject:[NSString stringWithFormat:@"[%@] MCProfileConnection class=%d sharedConnection=%d",who,cls?1:0,conn?1:0]];
 if(!conn)return lines;
 unsigned int n=0;Method *list=class_copyMethodList(cls,&n);NSMutableArray *hits=[NSMutableArray array];
 for(unsigned int i=0;i<n;i++){NSString *name=NSStringFromSelector(method_getName(list[i]));NSString *low=name.lowercaseString;
  if([low containsString:@"queue"]||[low containsString:@"acceptance"]||[low containsString:@"purgatory"]||[low containsString:@"peek"]||[low containsString:@"installprofile"]||[low containsString:@"transitiontoui"]){
   const char *e=method_getTypeEncoding(list[i]);NSMutableString *flat=[NSMutableString string];for(const char *q=e?e:"";*q;q++)if(*q<'0'||*q>'9')[flat appendFormat:@"%c",*q];[hits addObject:[NSString stringWithFormat:@"%@ %@",name,flat]];}}
 free(list);[hits sortUsingSelector:@selector(compare:)];
 [lines addObject:[NSString stringWithFormat:@"[%@] related methods on the class (%lu): %@",who,(unsigned long)hits.count,hits.count?[[hits subarrayWithRange:NSMakeRange(0,MIN(hits.count,30))] componentsJoinedByString:@" | "]:@"none"]];
 NSMutableArray *shapes=[NSMutableArray array];
 for(NSDictionary *route in MYBProfileStageRoutes()){NSString *enc=MYBProfileEncoding(cls,sel_registerName([route[@"sel"] UTF8String]));[shapes addObject:[NSString stringWithFormat:@"%@=%@%@",route[@"id"],enc?:@"absent",(enc&&[route[@"enc"] containsObject:enc])?@" (would be called)":(enc?@" (shape mismatch: not called)":@"")]];}
 [lines addObject:[NSString stringWithFormat:@"[%@] stage routes: %@",who,[shapes componentsJoinedByString:@"; "]]];
 NSString *peekEnc=MYBProfileEncoding(cls,sel_registerName("peekProfileDataFromPurgatoryForDeviceType:withCompletion:"));
 NSString *peek=peekEnc?MYBProfilePeekAsyncState(conn,nil):nil;
 NSString *syncEnc=MYBProfileEncoding(cls,sel_registerName("peekProfileDataFromPurgatoryForDeviceType:"));
 [lines addObject:[NSString stringWithFormat:@"[%@] queue peek (sync): encoding=%@ answer=%@",who,syncEnc?:@"absent",syncEnc?MYBProfilePeekSyncState(conn,nil):@"n/a"]];
 [lines addObject:[NSString stringWithFormat:@"[%@] queue peek: encoding=%@ answer=%@",who,peekEnc?:@"absent",peek?:(peekEnc?@"not called (shape mismatch)":@"n/a")]];
 return lines;
}
