#pragma once
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <dlfcn.h>
#import "MYBModeNames.h"
static inline bool MYBPACExpired(JSContextRef ctx,void *data){(void)ctx;(void)data;return true;}
static inline NSString *MYBEvaluatePAC(NSString *script,NSString *url,NSString *host){
 if(!script.length||script.length>2097152||!host.length)return nil;typedef void(*Limit)(JSContextGroupRef,double,bool(*)(JSContextRef,void *),void *);Limit limit=(Limit)dlsym(RTLD_DEFAULT,"JSContextGroupSetExecutionTimeLimit");if(!limit)return nil;JSContext *c=[JSContext new];limit(JSContextGetGroup(c.JSGlobalContextRef),.04,MYBPACExpired,NULL);
 [c evaluateScript:@"function dnsDomainIs(h,d){return h.slice(-d.length)===d;}function isPlainHostName(h){return h.indexOf('.')<0;}function shExpMatch(s,p){var r='^';for(var i=0;i<p.length;i++){var x=p.charAt(i);r+=x==='*'?'.*':x==='?'?'.':/[\\^$+.[\\]{}()|]/.test(x)?'\\\\'+x:x;}return new RegExp(r+'$').test(s);}"];
 [c evaluateScript:script];if(c.exception)return nil;JSValue *v=[c[@"FindProxyForURL"] callWithArguments:@[url,host]];return !c.exception&&v.isString?v.toString:nil;
}
static inline BOOL MYBBlockedRoute(NSString *route){if(!route.length)return NO;return [@[@"PROXY 127.0.0.1:8021",@"PROXY 127.0.0.1:8788",@"PROXY 8.8.8.8:53"] containsObject:[route stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];}
static inline BOOL MYBHostInRules(NSString *host,id rules){if(![rules isKindOfClass:NSArray.class])return NO;for(id rule in rules)if([rule isKindOfClass:NSString.class]&&([host isEqual:rule]||[host hasSuffix:[@"." stringByAppendingString:rule]]))return YES;return NO;}
// Structured explanation: code is custom-rule | filter-mode | popup-strict | unknown; mode is the filter label for filter-mode.
static inline NSDictionary *MYBBlockExplainWithOptions(NSString *url,NSString *mode,NSString *active,NSString *base,NSDictionary *applied,NSString *guardReason,NSDictionary *optionPACs){
 if([guardReason isEqual:@"custom"])return @{@"code":@"custom-rule"};
 if([guardReason isEqual:@"popup"])return @{@"code":@"popup-strict"};
 NSString *host=[NSURL URLWithString:url].host.lowercaseString;if(!MYBBlockedRoute(MYBEvaluatePAC(active,url,host)))return @{@"code":@"unknown"};
 if([mode isEqual:@"Custom"]&&MYBHostInRules(host,applied[@"blocked"])&&!MYBHostInRules(host,applied[@"allowed"]))return @{@"code":@"custom-rule"};
 NSString *source=([mode isEqual:@"Custom"]||[mode isEqual:@"Default"]||MYBBlockedRoute(MYBEvaluatePAC(base,url,host)))?@"Default":MYBModeName(mode);
 // Several options selected: name the options whose own rules (Default plus that option) block this address.
 NSArray *options=MYBOptionsForModeID(mode);
 if(![source isEqual:@"Default"]&&options.count>1&&optionPACs.count){
  NSMutableArray *names=[NSMutableArray array];
  for(NSString *o in options){NSString *pac=optionPACs[o];if([pac isKindOfClass:NSString.class]&&MYBBlockedRoute(MYBEvaluatePAC(pac,url,host)))[names addObject:MYBOptionLabel(o)];}
  if(names.count)source=[names componentsJoinedByString:@" + "];
 }
 return @{@"code":@"filter-mode",@"mode":source};
}
static inline NSDictionary *MYBBlockExplain(NSString *url,NSString *mode,NSString *active,NSString *base,NSDictionary *applied,NSString *guardReason){return MYBBlockExplainWithOptions(url,mode,active,base,applied,guardReason,nil);}
static inline NSString *MYBBlockAttribution(NSString *url,NSString *mode,NSString *active,NSString *base,NSDictionary *applied,NSString *guardReason){
 NSDictionary *e=MYBBlockExplain(url,mode,active,base,applied,guardReason);NSString *code=e[@"code"];
 if([code isEqual:@"custom-rule"])return @"Blocked by your MYbloXX® rules.";
 if([code isEqual:@"popup-strict"])return @"Blocked by MYbloXX® Shield.";
 if([code isEqual:@"filter-mode"])return [NSString stringWithFormat:@"Blocked by MYbloXX® %@ rules.",e[@"mode"]];
 return @"Blocked by MYbloXX®.";
}
