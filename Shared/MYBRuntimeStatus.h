// MYBRuntimeStatus.h: read-only view of the temporary inline-PAC runtime configuration.
//
// The managed link at /var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist
// points at a root-owned plist inside a protected directory under /private/var/tmp.
// iOS (configd) reads that plist directly: the PAC script is embedded as
// ProxyAutoConfigJavaScript, there is no PAC URL and no local server involved.
//
// Everything here is read-only and safe to use from unprivileged processes (Settings,
// Control Centre, blockd). Only the privileged helper (MYBInlinePAC.h) ever changes it.
//
// Two different questions are answered separately and never conflated:
//   CONFIGURED  (state "configured", enabled=YES): the managed link is MYbloXX-owned AND its target exists,
//               is a root-owned regular file, parses, and carries a complete inline PAC with fallback
//               disabled. This is a statement about files on disk only.
//   APPLIED     (MYBRuntimeProtection == "applied"): the privileged helper has additionally confirmed that
//               the script on disk is the expected effective PAC for the saved mode and rules (SHA-256
//               identity) AND that the system's effective proxy settings (what CFNetwork reads) carry that
//               same script. Only the helper can do this check; unprivileged readers only ever see its
//               published, time-limited result, so reading status is cheap.
// A link whose temporary target has disappeared is NOT protection.
#ifndef MYB_RUNTIME_STATUS_H
#define MYB_RUNTIME_STATUS_H
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <unistd.h>
#import <CommonCrypto/CommonDigest.h>

#define MYB_IP_DIR_NAME @"MYbloXX-inlinepac"
#define MYB_IP_PREFIX @"MYbloXX-pac-"
#define MYB_IP_SUFFIX @".plist"
// Upper bound for an inline script. Device evidence so far covers the tiny PAC and one full PAC of about
// 64.5 KB; the larger limit here is a safety cap, not a claim that every mode was tested up to it.
#define MYB_IP_MAX_SCRIPT (512*1024)

#ifdef MYB_INLINE_TESTING
static NSString *gMYBIPDirOverride=nil,*gMYBIPManagedOverride=nil,*gMYBIPExperimentOverride=nil;
static int gMYBIPOwnerOverride=-1;
#endif
static inline NSString *MYBIPDir(void){
#ifdef MYB_INLINE_TESTING
 if(gMYBIPDirOverride)return gMYBIPDirOverride;
#endif
 return @"/private/var/tmp/MYbloXX-inlinepac";
}
static inline NSString *MYBIPManagedPath(void){
#ifdef MYB_INLINE_TESTING
 if(gMYBIPManagedOverride)return gMYBIPManagedOverride;
#endif
 return @"/var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist";
}
static inline uid_t MYBIPOwnerUID(void){
#ifdef MYB_INLINE_TESTING
 if(gMYBIPOwnerOverride>=0)return (uid_t)gMYBIPOwnerOverride;
#endif
 return 0;
}

// Exactly <dir>/MYbloXX-pac-<8 lowercase hex>.plist and nothing else.
static inline BOOL MYBIPShapeOK(NSString *path){
 if(![path isKindOfClass:NSString.class]||path.length>1024||[path containsString:@".."])return NO;
 NSString *dir=MYBIPDir();
 while(dir.length>1&&[dir hasSuffix:@"/"])dir=[dir substringToIndex:dir.length-1];
 if(![path hasPrefix:[dir stringByAppendingString:@"/"]])return NO;
 NSString *name=[path substringFromIndex:dir.length+1];
 if([name containsString:@"/"])return NO;
 NSUInteger pl=MYB_IP_PREFIX.length,sl=MYB_IP_SUFFIX.length;
 if(name.length!=pl+8+sl||![name hasPrefix:MYB_IP_PREFIX]||![name hasSuffix:MYB_IP_SUFFIX])return NO;
 for(NSUInteger i=0;i<8;i++){unichar c=[name characterAtIndex:pl+i];if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')))return NO;}
 return YES;
}
// The B50 (and earlier) transport: a link to the Files-app MYbloXX.plist with a PAC URL.
static inline BOOL MYBIPLegacyFilesDestination(NSString *dest){
 if(![dest isKindOfClass:NSString.class])return NO;
 return ([dest hasPrefix:@"/private/var/mobile/Containers/Shared/AppGroup/"]||[dest hasPrefix:@"/var/mobile/Containers/Shared/AppGroup/"])&&
  [dest hasSuffix:@"/File Provider Storage/MYbloXX/MYbloXX.plist"]&&![dest containsString:@".."];
}
// The device experiment (inlinepac*) used these names; production never adopts them.
static inline BOOL MYBIPExperimentDestination(NSString *dest){
 if(![dest isKindOfClass:NSString.class])return NO;
 NSString *name=dest.lastPathComponent;
 return [name hasPrefix:@"MYbloXX.inlinepac-"]||[dest hasPrefix:@"/private/var/run/MYbloXX.inlinepac-"];
}
typedef NS_ENUM(int,MYBIPLinkKind){MYBIPLinkAbsent=0,MYBIPLinkOwned,MYBIPLinkLegacy,MYBIPLinkExperiment,MYBIPLinkForeign,MYBIPLinkNotSymlink,MYBIPLinkError};
static inline MYBIPLinkKind MYBIPClassifyLink(NSString **destOut){
 struct stat st;const char *p=MYBIPManagedPath().fileSystemRepresentation;
 if(destOut)*destOut=nil;
 if(lstat(p,&st)!=0)return errno==ENOENT?MYBIPLinkAbsent:MYBIPLinkError;
 if(!S_ISLNK(st.st_mode))return MYBIPLinkNotSymlink;
 char buf[PATH_MAX];ssize_t n=readlink(p,buf,sizeof buf-1);
 if(n<0)return MYBIPLinkError;
 buf[n]=0;NSString *dest=[NSString stringWithUTF8String:buf];
 if(!dest)return MYBIPLinkForeign;
 if(destOut)*destOut=dest;
 if(MYBIPShapeOK(dest))return MYBIPLinkOwned;
 if(MYBIPExperimentDestination(dest))return MYBIPLinkExperiment;
 if(MYBIPLegacyFilesDestination(dest))return MYBIPLinkLegacy;
 return MYBIPLinkForeign;
}
// The exact proxy dictionary configd needs. No ProxyAutoConfigURLString, no fallback:
// if the script could not be evaluated, traffic must not silently bypass protection.
static inline NSDictionary *MYBIPInlineProxies(NSString *script){
 return @{@"BypassAllowed":@1,@"FallBackAllowed":@0,@"HTTPEnable":@0,@"HTTPSEnable":@0,@"HTTPProxyType":@2,
  @"ProxyAutoConfigEnable":@1,@"ProxyAutoConfigJavaScript":script};
}
// YES only for a complete, fallback-free inline PAC and no other proxy mechanism.
static inline BOOL MYBIPProxiesValid(NSDictionary *p,NSString **scriptOut){
 if(![p isKindOfClass:NSDictionary.class])return NO;
 NSString *script=p[@"ProxyAutoConfigJavaScript"];
 if(![script isKindOfClass:NSString.class]||script.length<20||script.length>MYB_IP_MAX_SCRIPT||![script containsString:@"function FindProxyForURL"])return NO;
 if(![p[@"ProxyAutoConfigEnable"] boolValue]||[p[@"FallBackAllowed"] boolValue])return NO;
 if(p[@"ProxyAutoConfigURLString"]||[p[@"HTTPEnable"] boolValue]||[p[@"HTTPSEnable"] boolValue])return NO;
 if([p[@"HTTPProxy"] isKindOfClass:NSString.class]||[p[@"HTTPSProxy"] isKindOfClass:NSString.class])return NO;
 if(scriptOut)*scriptOut=script;
 return YES;
}
// Read-only status. state is one of:
//  disabled        no managed link at all
//  configured      owned link + intact inline PAC target on disk (NOT proof the system applies it)
//  target-missing  owned link, but the temporary target is gone (NOT protection)
//  target-invalid  owned link, target is not a root-owned regular file with a valid inline PAC
//  legacy-url      B50-style link to the Files plist with a PAC URL (needs migration)
//  experiment      the device experiment owns the link; production refuses to touch it
//  foreign         someone else's managed configuration
//  unverified      the caller's sandbox cannot read the target (use MYBRuntimeStatusMirrored)
//  error           the link could not be inspected
static inline NSString *MYBRuntimeSHA256(NSString *text){
 NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding];unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);
 NSMutableString *out=[NSMutableString string];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[out appendFormat:@"%02x",h[i]];return out;
}
static inline NSDictionary *MYBRuntimeStatus(void){
 NSString *dest=nil;MYBIPLinkKind kind=MYBIPClassifyLink(&dest);
 switch(kind){
  case MYBIPLinkAbsent:return @{@"state":@"disabled",@"enabled":@NO};
  case MYBIPLinkLegacy:return @{@"state":@"legacy-url",@"enabled":@NO,@"destination":dest?:@""};
  case MYBIPLinkExperiment:return @{@"state":@"experiment",@"enabled":@NO,@"destination":dest?:@""};
  case MYBIPLinkForeign:case MYBIPLinkNotSymlink:return @{@"state":@"foreign",@"enabled":@NO,@"destination":dest?:@""};
  case MYBIPLinkError:return @{@"state":@"error",@"enabled":@NO};
  case MYBIPLinkOwned:break;
 }
 struct stat st;
 if(lstat(dest.fileSystemRepresentation,&st)!=0){
  if(errno==EACCES||errno==EPERM)return @{@"state":@"unverified",@"enabled":@NO,@"destination":dest};
  return @{@"state":@"target-missing",@"enabled":@NO,@"destination":dest};
 }
 if(!S_ISREG(st.st_mode)||st.st_uid!=MYBIPOwnerUID()||(st.st_mode&(S_IWGRP|S_IWOTH)))return @{@"state":@"target-invalid",@"enabled":@NO,@"destination":dest,@"detail":@"not a root-owned regular file"};
 NSData *data=[NSData dataWithContentsOfFile:dest];
 if(!data&&(errno==EACCES||errno==EPERM))return @{@"state":@"unverified",@"enabled":@NO,@"destination":dest};
 NSDictionary *root=data?[NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL]:nil;
 NSString *script=nil;
 if(![root isKindOfClass:NSDictionary.class]||!MYBIPProxiesValid(root[@"Proxies"],&script))
  return @{@"state":@"target-invalid",@"enabled":@NO,@"destination":dest,@"detail":@"not a complete inline PAC"};
 return @{@"state":@"configured",@"enabled":@YES,@"destination":dest,@"script":script,@"scriptSHA256":MYBRuntimeSHA256(script)};
}
static inline BOOL MYBRuntimeEnabled(void){return [MYBRuntimeStatus()[@"enabled"] boolValue];}
// ---- verified application (privileged) ---------------------------------------------------
// structural: MYBRuntimeStatus(); expectedSHA: SHA-256 of the effective PAC the saved mode and rules should
// produce; effective: the system's effective proxy settings (CFNetworkCopySystemProxySettings). Result "verification":
//   applied              script identity matches AND the system reports that inline PAC enabled
//   identity-unavailable the system reports an inline PAC enabled but does not expose the script, so identity
//                        cannot be confirmed (shown as such, never as "applied")
//   stale                the file on disk is not the expected effective PAC (rules or mode changed)
//   not-applied          the file is fine but the system is not using an inline PAC at all (or a different one)
//   unchecked            nothing to verify (not configured) or no expectation could be built
static inline NSDictionary *MYBRuntimeVerify(NSDictionary *structural,NSString *expectedSHA,NSDictionary *effective){
 if(![structural[@"state"] isEqual:@"configured"]||!expectedSHA.length)return @{@"verification":@"unchecked"};
 if(![structural[@"scriptSHA256"] isEqual:expectedSHA])return @{@"verification":@"stale"};
 if(![effective isKindOfClass:NSDictionary.class]||![effective[@"ProxyAutoConfigEnable"] boolValue]||[effective[@"ProxyAutoConfigURLString"] length])return @{@"verification":@"not-applied"};
 NSString *js=effective[@"ProxyAutoConfigJavaScript"];
 if(![js isKindOfClass:NSString.class]||!js.length)return @{@"verification":@"identity-unavailable"};
 return @{@"verification":[MYBRuntimeSHA256(js) isEqual:expectedSHA]?@"applied":@"not-applied"};
}
// What the UI may claim. Only "applied" is full, verified protection.
//   applied | applied-unidentified | configured (on disk, not yet confirmed) | stale | not-applied | <structural state>
static inline NSString *MYBRuntimeProtection(NSDictionary *status){
 NSString *state=status[@"state"];if(![state isEqual:@"configured"])return state?:@"error";
 NSString *v=status[@"verification"];
 if([v isEqual:@"applied"])return @"applied";if([v isEqual:@"identity-unavailable"])return @"applied-unidentified";
 if([v isEqual:@"stale"])return @"stale";if([v isEqual:@"not-applied"])return @"not-applied";
 return @"configured";
}
// Unprivileged, possibly sandboxed readers (Settings): structural state is read directly when possible; otherwise,
// and for the verification result in every case, they use the record the root helper/watcher publishes
// (state + verification + time) while it is fresh. Reading never performs verification itself.
static inline NSDictionary *MYBRuntimeStatusMirrored(NSString *mirrorPath){
 NSDictionary *direct=MYBRuntimeStatus();
 NSDictionary *m=mirrorPath.length?[NSDictionary dictionaryWithContentsOfFile:mirrorPath]:nil;
 NSDate *time=[m[@"time"] isKindOfClass:NSDate.class]?m[@"time"]:nil,*checked=[m[@"verifiedAt"] isKindOfClass:NSDate.class]?m[@"verifiedAt"]:nil;
 NSString *mstate=[m[@"state"] isKindOfClass:NSString.class]?m[@"state"]:nil;
 NSTimeInterval age=time?[[NSDate date] timeIntervalSinceDate:time]:1e9,vage=checked?[[NSDate date] timeIntervalSinceDate:checked]:1e9;
 NSMutableDictionary *out;
 if([direct[@"state"] isEqual:@"unverified"]){
  if(!mstate||age<0||age>90||[mstate isEqual:@"unverified"])return @{@"state":@"unverified",@"enabled":@NO,@"destination":direct[@"destination"]?:@""};
  // Only trust the mirror for a link that still points where the mirror says it verified.
  if(m[@"destination"]&&![m[@"destination"] isEqual:direct[@"destination"]])return @{@"state":@"unverified",@"enabled":@NO};
  out=[@{@"state":mstate,@"enabled":@([mstate isEqual:@"configured"]),@"destination":direct[@"destination"]?:@"",@"mirrored":@YES} mutableCopy];
 }else out=[direct mutableCopy];
 // The verification is only meaningful for the same configuration, and only while recent (the watcher refreshes it).
 if(time)out[@"mirrorAge"]=@(age);if(checked)out[@"verifiedAge"]=@(vage);
 if([out[@"state"] isEqual:@"configured"]&&[m[@"destination"] isEqual:out[@"destination"]]&&vage>=0&&vage<180&&[m[@"verification"] isKindOfClass:NSString.class])out[@"verification"]=m[@"verification"];
 return out;
}
#endif
