#pragma once
// The profile service (ManagedConfiguration, class MCProfileConnection), shared by the helper and by the Settings component.
// Which process may use it matters: the helper has no com.apple.managedconfiguration.profiled-access entitlement and is denied, while
// the Settings component has it. Every call checks the exact method signature first and says nothing when it does not match.
#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import <dlfcn.h>
#import <objc/message.h>
static id MYBProfileService(void){
 static id svc;static dispatch_once_t once;dispatch_once(&once,^{
  dlopen("/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration",RTLD_NOW|RTLD_LOCAL);
  Class c=NSClassFromString(@"MCProfileConnection");SEL shared=NSSelectorFromString(@"sharedConnection");
  if(c&&[c respondsToSelector:shared])svc=((id(*)(Class,SEL))objc_msgSend)(c,shared);});
 return svc;
}
// YES only when the selector exists AND its signature is exactly object-returning/void with the expected argument kinds.
static BOOL MYBSignatureIs(id svc,SEL sel,const char *ret,NSArray<NSString *> *args){
 if(![svc respondsToSelector:sel])return NO;NSMethodSignature *sig=[svc methodSignatureForSelector:sel];
 if(!sig||sig.numberOfArguments!=args.count+2||strcmp(sig.methodReturnType,ret)!=0)return NO;
 for(NSUInteger i=0;i<args.count;i++){const char *t=[sig getArgumentTypeAtIndex:i+2];if(strncmp(t,args[i].UTF8String,args[i].length)!=0)return NO;}
 return YES;
}
static NSArray *MYBServiceList(void){
 id svc=MYBProfileService();SEL s=NSSelectorFromString(@"installedProfileIdentifiers");
 if(!svc||!MYBSignatureIs(svc,s,"@",@[]))return nil;
 id r=((id(*)(id,SEL))objc_msgSend)(svc,s);return [r isKindOfClass:NSArray.class]?r:nil;
}
static NSDictionary *MYBServiceDescribe(NSString *identifier){
 id svc=MYBProfileService();if(!svc)return nil;
 // 1. the profile data, from the selectors the system header declares (the old "profileDataForIdentifier:" does not exist).
 for(NSString *name in @[@"installedProfileDataWithIdentifier:",@"installedSystemProfileDataWithIdentifier:",@"installedUserProfileDataWithIdentifier:"]){
  SEL s=NSSelectorFromString(name);if(!MYBSignatureIs(svc,s,"@",@[@"@"]))continue;
  id data=((id(*)(id,SEL,id))objc_msgSend)(svc,s,identifier);if(![data isKindOfClass:NSData.class])continue;
  NSDictionary *p=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];if(![p isKindOfClass:NSDictionary.class])continue;
  NSMutableArray *payloads=[NSMutableArray array];
  for(NSDictionary *c in ([p[@"PayloadContent"] isKindOfClass:NSArray.class]?p[@"PayloadContent"]:@[]))if([c isKindOfClass:NSDictionary.class])[payloads addObject:@{@"type":c[@"PayloadType"]?:@"",@"pacURL":c[@"ProxyPACURL"]?:@"",@"proxyType":c[@"ProxyType"]?:@""}];
  return @{@"identifier":p[@"PayloadIdentifier"]?:@"",@"uuid":p[@"PayloadUUID"]?:@"",@"displayName":p[@"PayloadDisplayName"]?:@"",@"organization":p[@"PayloadOrganization"]?:@"",@"payloads":payloads};
 }
 // 2. the data is not handed out: ask for the profile OBJECT and read only its identity (identifier, UUID, organisation). Without the
 // payload this is identity evidence, not a content check; the classifier treats it that way.
 SEL o=NSSelectorFromString(@"installedProfileWithIdentifier:");
 if(MYBSignatureIs(svc,o,"@",@[@"@"])){
  id prof=((id(*)(id,SEL,id))objc_msgSend)(svc,o,identifier);
  if(prof&&[prof respondsToSelector:NSSelectorFromString(@"identifier")]&&[prof respondsToSelector:NSSelectorFromString(@"UUID")]&&[prof respondsToSelector:NSSelectorFromString(@"organization")]){
   id i=[prof valueForKey:@"identifier"],u=[prof valueForKey:@"UUID"],g=[prof valueForKey:@"organization"],d=[prof respondsToSelector:NSSelectorFromString(@"displayName")]?[prof valueForKey:@"displayName"]:@"";
   if([i isKindOfClass:NSString.class]&&[u isKindOfClass:NSString.class])return @{@"identifier":i,@"uuid":u,@"displayName":[d isKindOfClass:NSString.class]?d:@"",@"organization":[g isKindOfClass:NSString.class]?g:@""};
  }
 }
 return nil;
}
static void MYBServiceRemove(NSString *identifier){
 id svc=MYBProfileService();SEL s=NSSelectorFromString(@"removeProfileWithIdentifier:completion:");
 if(!svc||!MYBSignatureIs(svc,s,"v",@[@"@",@"@?"]))return; // unavailable: the confirmation below then fails and nothing is applied
 dispatch_semaphore_t done=dispatch_semaphore_create(0);
 void(^completion)(void *,void *)=^(__unused void *a,__unused void *b){dispatch_semaphore_signal(done);}; // a "finished" signal only
 ((void(*)(id,SEL,id,id))objc_msgSend)(svc,s,identifier,completion);
 dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,20*NSEC_PER_SEC));
}
// The system's effective proxy configuration no longer uses this PAC address. Other proxy settings are irrelevant and untouched.
__attribute__((unused)) static BOOL MYBEffectiveProxyClear(NSString *pac){
 CFDictionaryRef proxies=CFNetworkCopySystemProxySettings();NSDictionary *effective=proxies?CFBridgingRelease(proxies):nil;
 if(!effective)return NO; // cannot observe: not confirmed
 NSString *url=[effective[(__bridge NSString *)kCFProxyAutoConfigurationURLKey] description];
 NSString *key=@"ProxyAutoConfigURLString";NSString *u2=[effective[key] description];
 return !(pac.length&&([url isEqual:pac]||[u2 isEqual:pac]));
}

// The PAC address the system is using right now (nil: none, or it cannot say).
static inline NSString *MYBEffectivePACNow(void){
 CFDictionaryRef px=CFNetworkCopySystemProxySettings();NSDictionary *d=px?CFBridgingRelease(px):nil;
 NSString *u=[d[(__bridge NSString *)kCFProxyAutoConfigurationURLKey] description]?:[d[@"ProxyAutoConfigURLString"] description];return u.length?u:nil;
}
