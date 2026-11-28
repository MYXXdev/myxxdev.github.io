#import "../Shared/MYBLoopback.h"
#import "../Shared/MYBWebsiteRules.h"
#import "../Shared/MYBBrowserPolicy.h"
#import "../Shared/MYBVersion.h"
#import "../Shared/MYBAdsReport.h"
#if !defined(MYB_BRIDGE_TESTING)
#import <roothide.h>
#endif
static NSMutableDictionary *browserEvents;
static NSString *bridgeFile(NSString *relative){
#ifdef MYB_BRIDGE_TESTING
 NSString *fixture=NSProcessInfo.processInfo.environment[@"MYB_FIXTURE_ROOT"];if(fixture.length)return [fixture stringByAppendingPathComponent:relative];
#endif
 NSString *path=[@"/" stringByAppendingString:relative];
#if defined(MYB_BRIDGE_TESTING)
 return path;
#else
 // MYbloXX-owned preferences live inside the writable jailbreak root.
 // The stock managed preference path is read-only from RootHide and used
 // for detection only, never for a write.
 if([path hasPrefix:@"/var/Managed Preferences/"])
  return path; // Native process: the actual iOS managed-preferences location.
 return jbroot(path);
#endif
}
#import "../Shared/MYBProxyCheck.h"
static NSDictionary *guardPreferences(void){return [NSDictionary dictionaryWithContentsOfFile:bridgeFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.safariguard.plist")]?:@{};}
// Facts for Status & Diagnostics, all read-only and all taken from what the components actually recorded. Nothing here is
// inferred from an enabled preference, an open port or a running process. No secret, token, credential or full URL is included.
static NSDictionary *bridgePlist(NSString *rel){NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:bridgeFile(rel)];return [d isKindOfClass:NSDictionary.class]?d:@{};}
static NSNumber *bridgeEpoch(id v){return [v isKindOfClass:NSDate.class]?@((long long)[(NSDate *)v timeIntervalSince1970]):nil;}
static NSString *bridgeScrub(id v,NSUInteger max){
 if(![v isKindOfClass:NSString.class])return nil;NSString *t=[v length]>max?[v substringToIndex:max]:v;
 NSRegularExpression *url=[NSRegularExpression regularExpressionWithPattern:@"[a-zA-Z][a-zA-Z0-9+.-]*://\\S+" options:0 error:NULL];
 return [url stringByReplacingMatchesInString:t options:0 range:NSMakeRange(0,t.length) withTemplate:@"[address]"];
}
static NSDictionary *statusExtras(void){
 NSString *base=@"var/mobile/Library/MYbloXX/";
 NSDictionary *state=bridgePlist([base stringByAppendingString:@"State.plist"]),*rt=bridgePlist([base stringByAppendingString:@"RuntimeStatus.plist"]),*su=bridgePlist([base stringByAppendingString:@"StartupRecovery.plist"]),*df=bridgePlist([base stringByAppendingString:@"Defaults.plist"]),*up=bridgePlist([base stringByAppendingString:@"Updates.plist"]),*ac=bridgePlist([base stringByAppendingString:@"AppControlSession.plist"]);
 NSMutableDictionary *o=[NSMutableDictionary dictionary];
 o[@"generatedAt"]=@((long long)[NSDate.date timeIntervalSince1970]);
 o[@"intent"]=@{@"known":@(state[@"enabled"]!=nil),@"enabled":@([state[@"enabled"] boolValue]),@"mode":[state[@"mode"] isKindOfClass:NSString.class]?state[@"mode"]:@""};
 NSMutableDictionary *r=[NSMutableDictionary dictionary];for(NSString *k in @[@"state",@"verification"])if([rt[k] isKindOfClass:NSString.class])r[k]=rt[k];
 if(bridgeEpoch(rt[@"time"]))r[@"publishedAt"]=bridgeEpoch(rt[@"time"]);if(bridgeEpoch(rt[@"verifiedAt"]))r[@"verifiedAt"]=bridgeEpoch(rt[@"verifiedAt"]);
 o[@"pin"]=@{@"enabled":@([bridgePlist([base stringByAppendingString:@"PinState.plist"])[@"enabled"] boolValue])}; // on or off only: no lock state, no attempt counts, nothing secret
 o[@"runtime"]=r;o[@"appControlPaused"]=@([ac[@"active"] boolValue]);
 NSMutableDictionary *s=[NSMutableDictionary dictionary];if([su[@"result"] isKindOfClass:NSString.class])s[@"result"]=su[@"result"];if(su[@"attempts"])s[@"attempts"]=su[@"attempts"];if(su[@"code"])s[@"code"]=su[@"code"];
 if(bridgeScrub(su[@"detail"],200))s[@"detail"]=bridgeScrub(su[@"detail"],200);if([su[@"verification"] isKindOfClass:NSString.class])s[@"verification"]=su[@"verification"];if(bridgeEpoch(su[@"time"]))s[@"at"]=bridgeEpoch(su[@"time"]);o[@"startup"]=s;
 NSMutableDictionary *d=[NSMutableDictionary dictionary];if([df[@"origin"] isKindOfClass:NSString.class])d[@"origin"]=df[@"origin"];if(df[@"version"])d[@"version"]=df[@"version"];if([df[@"outcome"] isKindOfClass:NSString.class])d[@"outcome"]=df[@"outcome"];if([df[@"exceptions"] isKindOfClass:NSArray.class])d[@"exceptions"]=df[@"exceptions"];if(bridgeEpoch(df[@"time"]))d[@"at"]=bridgeEpoch(df[@"time"]);o[@"defaults"]=d;
 NSMutableDictionary *u=[NSMutableDictionary dictionary];u[@"automatic"]=@([up[@"automatic"] boolValue]);u[@"known"]=@(up[@"automatic"]!=nil);if(bridgeEpoch(up[@"lastAttempt"]))u[@"lastAttempt"]=bridgeEpoch(up[@"lastAttempt"]);if(bridgeScrub(up[@"lastResult"],160))u[@"lastResult"]=bridgeScrub(up[@"lastResult"],160);o[@"updates"]=u;
 o[@"services"]=@{@"blockd":@{@"ok":@YES},@"pacd":@{@"reachable":@(MYBProxyReachable(@"127.0.0.1",8787,0.4))}};
 return o;
}
static NSDictionary *browserConfig(void){
 NSDictionary *settings=guardPreferences();NSMutableDictionary *pac=[@{@"active":@NO,@"reason":@"Protection is disabled"} mutableCopy];
 { // The runtime configuration iOS actually reads is authoritative, not stale saved state.
  NSDictionary *runtime=MYBRuntimeStatus();NSString *state=runtime[@"state"];
  NSDictionary *reasons=@{@"disabled":@"Protection is disabled",@"target-missing":@"Runtime configuration is missing",@"target-invalid":@"Runtime configuration is invalid",@"legacy-url":@"Legacy PAC-URL configuration; repair to the inline PAC",@"experiment":@"Inline-PAC experiment is active",@"foreign":@"Managed link is not MYbloXX-owned",@"unverified":@"Runtime configuration could not be verified"};
  pac[@"reason"]=reasons[state]?:@"Managed link is not MYbloXX-owned";
  NSString *script=[runtime[@"script"] isKindOfClass:NSString.class]?runtime[@"script"]:nil;
  if([runtime[@"enabled"] boolValue]&&[script containsString:@"function FindProxyForURL"]){
   NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:bridgeFile(@"var/mobile/Library/MYbloXX/State.plist")];
   NSString *mode=[saved[@"mode"] isKindOfClass:NSString.class]?saved[@"mode"]:@"Default";
   pac[@"active"]=@YES;pac[@"reason"]=@"Configured inline PAC (attribution source)";pac[@"script"]=script;pac[@"mode"]=mode;
  }
 }
 // Domain exceptions (permanent + unexpired temporary) also override Shield's own custom block rules.
 return @{@"version":@MYB_COMPONENT_VERSION,@"rules":settings,@"pac":pac,@"siteExceptions":MYBWebsiteLiveDomains([NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()])};
}
static NSMutableArray *popupTrace;
static NSDictionary *diagnosticSnapshot(void){
 NSMutableDictionary *d=[startupStatus mutableCopy]?:[NSMutableDictionary dictionary];
 NSDictionary *rules=guardPreferences();
 d[@"attribution"]=MYBPeerDiagnostics(); // which app a blocked request came from: scans, how many were answered
 @synchronized(browserEvents){
  d[@"browsers"]=[browserEvents copy]?:@{};
  // One entry per supported browser. "not-observed" means nothing has been reported yet (never launched since
  // install, or not injected) - it is not a confirmed failure. Confirmed conditions have their own states.
  NSMutableDictionary *states=[NSMutableDictionary dictionary];
  for(NSDictionary *b in MYBBrowserTable()){
   NSDictionary *e=browserEvents[b[@"id"]];NSMutableDictionary *flags=[e mutableCopy]?:[NSMutableDictionary dictionary];
   states[b[@"id"]]=@{@"name":b[@"name"],@"state":MYBBrowserDiagnosticState(flags),@"componentVersion":e[@"version"]?:@"unknown",@"lastEvent":e[@"time"]?:@"never",@"popupsAllowed":e[@"popupAllowedCount"]?:@0,@"popupsBlocked":e[@"popupBlockedCount"]?:@0,@"permissionsConsumed":e[@"permissionConsumedCount"]?:@0,@"capabilities":@{@"network":@"system proxy (all apps, independent of injection)",@"popups":b[@"popups"],@"blockedPage":b[@"page"],@"prompts":b[@"prompts"],@"deviceEvidence":b[@"evidence"]}};
  }
  d[@"browserStates"]=states;d[@"popupTrace"]=[popupTrace copy]?:@[];
 }
 d[@"inAppAds"]=MYBAdsSnapshot(); // counts and fixed labels only; see Shared/MYBAdsReport.h
 d[@"bridgeVersion"]=@MYB_COMPONENT_VERSION;d[@"release"]=@MYB_RELEASE_LABEL;d[@"status"]=statusExtras();
 NSMutableDictionary *pac=[browserConfig()[@"pac"] mutableCopy];[pac removeObjectForKey:@"script"];d[@"pacStatus"]=pac?:@{};
 d[@"guardSettings"]=@{@"enabled":@YES,@"blockPopups":@([rules[@"BlockPopups"] boolValue]),@"blockedCount":@([rules[@"Blocked"] isKindOfClass:NSArray.class]?[rules[@"Blocked"] count]:0),@"allowedCount":@([rules[@"Allowed"] isKindOfClass:NSArray.class]?[rules[@"Allowed"] count]:0)};return d;
}
static BOOL boundedToken(NSString *v,NSString *allowed,NSUInteger max){if(![v isKindOfClass:NSString.class]||v.length>max)return NO;NSCharacterSet *ok=[NSCharacterSet characterSetWithCharactersInString:allowed];return [v rangeOfCharacterFromSet:ok.invertedSet].location==NSNotFound;}
static BOOL recordBrowserEvent(NSArray<NSURLQueryItem *> *items){
 NSMutableDictionary *q=[NSMutableDictionary dictionary];for(NSURLQueryItem *item in items)if(item.value.length<=100)q[item.name]=item.value;
 NSString *app=q[@"app"],*phase=q[@"phase"];BOOL probe=[app isEqual:@"mybloxx.networkprobe"];
 // Every name the components can send is listed here; an unknown name is refused, so a new event must be added deliberately.
 NSArray *phases=@[@"loaded",@"hook_enabled",@"proxy_query",@"proxy_resolve",@"navigation_seen",@"bridge_ready",@"bridge_failed",@"blocked_rule",@"blocked_pac",@"redirected",@"js_unavailable",@"js_error",@"ui_fallback",
  @"window_hook_seen",@"popup_allowed",@"popup_blocked",@"permission_consumed",@"host_unsupported",@"shield_off",@"popup_trace"];
 if(!(probe||MYBBrowserInjects(app))||![phases containsObject:phase])return NO;
 NSString *ver=boundedToken(q[@"ver"],@"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-_",40)?q[@"ver"]:@"unknown";
 @synchronized(browserEvents){
  if([phase isEqual:@"popup_trace"]){ // callback order + navigation types; hosts and enums only
   NSString *layer=q[@"layer"],*type=q[@"type"],*tf=q[@"tf"],*sf=q[@"sf"]?:@"nil",*gest=q[@"gest"],*result=q[@"result"],*src=q[@"src"]?:@"",*dst=q[@"dst"]?:@"";
   if(![@[@"nav",@"create",@"create-async"] containsObject:layer]||!boundedToken(type,@"-0123456789",4)||![@[@"nil",@"main",@"sub"] containsObject:tf]||![@[@"nil",@"main",@"sub"] containsObject:sf]||![@[@"-1",@"0",@"1"] containsObject:gest]||![@[@"token",@"policy-allow",@"permission",@"block",@"shield-off"] containsObject:result]||!boundedToken(src,@"abcdefghijklmnopqrstuvwxyz0123456789.-",80)||!boundedToken(dst,@"abcdefghijklmnopqrstuvwxyz0123456789.-",80))return NO;
   if(!popupTrace)popupTrace=[NSMutableArray array];[popupTrace addObject:@{@"app":app,@"time":[NSDate.date description],@"layer":layer,@"navigationType":@([type integerValue]),@"targetFrame":tf,@"sourceFrame":sf,@"gesture":@([gest integerValue]),@"result":result,@"source":src,@"destination":dst,@"componentVersion":ver}];
   while(popupTrace.count>60)[popupTrace removeObjectAtIndex:0];return YES;
  }
  NSMutableDictionary *event=[browserEvents[app] mutableCopy]?:[NSMutableDictionary dictionary];
  event[@"loaded"]=@YES;if([phase hasPrefix:@"blocked_"])event[@"lastBlock"]=phase;event[@"phase"]=phase;event[@"time"]=[NSDate.date description];event[@"version"]=ver;
  if([phase isEqual:@"loaded"])event[@"loaded"]=@YES;
  if([phase isEqual:@"navigation_seen"]){event[@"navigationSeen"]=@YES;event[@"navigation"]=@YES;}
  if([phase isEqual:@"redirected"])event[@"redirected"]=@YES;
  if([phase isEqual:@"window_hook_seen"])event[@"windowHook"]=@YES;
  if([phase isEqual:@"host_unsupported"])event[@"hostUnsupported"]=@YES;
  if([phase isEqual:@"bridge_ready"]){event[@"bridgeReady"]=@YES;event[@"bridgeFailed"]=@NO;}
  if([phase isEqual:@"bridge_failed"]){event[@"bridgeReady"]=@NO;event[@"bridgeFailed"]=@YES;}
  if([phase isEqual:@"shield_off"])event[@"shieldOff"]=@YES;
  if([phase isEqual:@"popup_allowed"]||[phase isEqual:@"popup_blocked"]||[phase isEqual:@"permission_consumed"]){event[@"shieldOff"]=@NO;NSString *k=[phase isEqual:@"popup_allowed"]?@"popupAllowedCount":[phase isEqual:@"popup_blocked"]?@"popupBlockedCount":@"permissionConsumedCount";event[k]=@([event[k] integerValue]+1);}
  if(probe){if([phase isEqual:@"proxy_query"])event[@"proxyQueryObserved"]=@YES;if([phase isEqual:@"proxy_resolve"])event[@"proxyResolveObserved"]=@YES;if([phase isEqual:@"hook_enabled"])event[@"hookEnabled"]=@YES;
   NSString *process=q[@"process"]?:@"",*bundle=q[@"bundle"]?:@"";if(process.length<=80&&bundle.length<=100){event[@"process"]=process;event[@"bundle"]=bundle;event[@"cfnetworkEnabled"]=@([q[@"enabled"] isEqual:@"1"]);event[@"localhostPAC"]=@([q[@"local"] isEqual:@"1"]);}}
  browserEvents[app]=event;
 }
 return YES;
}
