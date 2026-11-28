#pragma once
#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE && !defined(MYB_RULE_TESTING)
#import <roothide.h>
#endif
static inline NSString *MYBRuleFile(NSString *relative){
#ifdef MYB_RULE_TESTING
 NSString *fixture=NSProcessInfo.processInfo.environment[@"MYB_FIXTURE_ROOT"];if(fixture.length)return [fixture stringByAppendingPathComponent:relative];
#endif
 NSString *plain=[@"/" stringByAppendingString:relative];
#if !TARGET_OS_IPHONE || defined(MYB_RULE_TESTING)
 return plain;
#else
 // The native helper and PAC daemon share the same writable RootHide data.
 // Never read original iOS files through the read-only /rootfs alias.
 return jbroot(plain);
#endif
}
#import "MYBClock.h"
static inline NSString *MYBWebsiteFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/WebsiteAllows.plist");}
static inline NSString *MYBDraftFile(void){return MYBRuleFile(@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.ruledraft.plist");}
static inline BOOL MYBValidWebsiteDomain(NSString *s){
 if(![s isKindOfClass:NSString.class]||s.length>253||![s containsString:@"."]||![s isEqual:s.lowercaseString])return NO;
 NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-"].invertedSet;
 for(NSString *part in [s componentsSeparatedByString:@"."])if(!part.length||part.length>63||[part hasPrefix:@"-"]||[part hasSuffix:@"-"]||[part rangeOfCharacterFromSet:bad].location!=NSNotFound)return NO;
 return YES;
}
// A wildcard rule: letters, digits, hyphens, dots and "*" (any characters). It must end in a fixed name of at least two labels, so one rule
// can never match a whole top-level domain: "ads*.example.com" and "track-*.cdn.net" are fine, "*.com" and "*.co.uk" are refused.
static inline BOOL MYBRuleIsWildcard(NSString *s){return [s isKindOfClass:NSString.class]&&[s containsString:@"*"];}
static inline BOOL MYBValidWildcardRule(NSString *s){
 if(![s isKindOfClass:NSString.class]||s.length>253||![s isEqual:s.lowercaseString]||![s containsString:@"*"])return NO;
 NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-.*"].invertedSet;
 if([s rangeOfCharacterFromSet:bad].location!=NSNotFound||[s containsString:@"**"])return NO;
 NSArray *parts=[s componentsSeparatedByString:@"."];if(parts.count<3)return NO;
 for(NSString *part in parts)if(!part.length||part.length>63)return NO;
 NSString *tld=parts.lastObject,*sld=parts[parts.count-2];
 return tld.length>=2&&![tld containsString:@"*"]&&sld.length>=3&&![sld containsString:@"*"]&&![tld hasPrefix:@"-"]&&![tld hasSuffix:@"-"]&&![sld hasPrefix:@"-"]&&![sld hasSuffix:@"-"];
}
// One entry of a Custom Rules list: a plain domain (which includes its subdomains) or a wildcard.
static inline BOOL MYBValidRuleEntry(NSString *s){return MYBRuleIsWildcard(s)?MYBValidWildcardRule(s):MYBValidWebsiteDomain(s);}
// The PAC condition for one entry.
static inline NSString *MYBRuleEntryTerm(NSString *d){
 if(MYBRuleIsWildcard(d))return [NSString stringWithFormat:@"(shExpMatch(h,\"%@\")||shExpMatch(h,\"*.%@\"))",d,d];
 return [NSString stringWithFormat:@"(h===\"%@\"||dnsDomainIs(h,\".%@\"))",d,d];
}
static inline NSArray *MYBRuleArray(id value){
 if(![value isKindOfClass:NSArray.class]||[value count]>20000)return nil;NSMutableArray *a=[NSMutableArray array];for(id s in value){if(!MYBValidRuleEntry(s))return nil;if(![a containsObject:s])[a addObject:s];}return a;
}
// Temporary (once / 15 minute) website exceptions live beside the permanent list and never enter it:
// they are never written into AppliedRules/draft/archive/Shield lists, never backed up, and never survive a reboot.
static inline NSArray *MYBWebsiteTempLive(NSDictionary *web){
 NSArray *items=[web[@"temp"] isKindOfClass:NSArray.class]?web[@"temp"]:@[];NSMutableArray *out=[NSMutableArray array];
 for(NSDictionary *e in items){if(![e isKindOfClass:NSDictionary.class]||!MYBValidWebsiteDomain(e[@"domain"])||![@[@"once",@"temp"] containsObject:e[@"mode"]]||!MYBClockLive(e))continue;if(out.count<100)[out addObject:e];}return out;
}
static inline NSArray *MYBWebsiteLiveDomains(NSDictionary *web){
 NSMutableArray *all=[(MYBRuleArray(web[@"domains"])?:@[]) mutableCopy];for(NSDictionary *e in MYBWebsiteTempLive(web))if(![all containsObject:e[@"domain"]])[all addObject:e[@"domain"]];return all;
}
static inline NSArray *MYBWebsiteDomains(void){NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()];return MYBRuleArray(d[@"domains"])?:@[];}
static inline NSString *MYBWebsitePAC(NSString *base,NSArray *domains){
 if(!domains.count)return base;
 if(!MYBRuleArray(domains))return nil;
 NSRegularExpression *fn=[NSRegularExpression regularExpressionWithPattern:@"function\\s+FindProxyForURL\\s*\\(" options:0 error:NULL];if([fn numberOfMatchesInString:base options:0 range:NSMakeRange(0,base.length)]!=1)return nil;
 NSMutableArray *terms=[NSMutableArray array];for(NSString *d in domains)[terms addObject:[NSString stringWithFormat:@"(h===\"%@\"||dnsDomainIs(h,\".%@\"))",d,d]];
 NSString *renamed=[fn stringByReplacingMatchesInString:base options:0 range:NSMakeRange(0,base.length) withTemplate:@"function MYBWebsiteBaseFindProxyForURL("];
 return [renamed stringByAppendingFormat:@"\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();if(%@)return \"DIRECT\";return MYBWebsiteBaseFindProxyForURL(url,host);}\n",[terms componentsJoinedByString:@"||"]];
}
// Custom MYbloXX rules apply to the local PAC regardless of the selected
// base blocking mode. Shield rules live in a SEPARATE plist.
// The original PAC file is never modified or replaced.
static inline NSString *MYBUserRulesPAC(NSString *base,NSArray *blocked,NSArray *allowed) {
 NSArray *b=MYBRuleArray(blocked),*a=MYBRuleArray(allowed);
 if(!base.length || !b || !a)return nil;
 if(!b.count && !a.count)return base;
 NSRegularExpression *fn=[NSRegularExpression regularExpressionWithPattern:@"function\\s+FindProxyForURL\\s*\\(" options:0 error:NULL];
 if([fn numberOfMatchesInString:base options:0 range:NSMakeRange(0,base.length)]!=1)return nil;
 NSMutableArray *allowTerms=[NSMutableArray array],*blockTerms=[NSMutableArray array];
 for(NSString *d in a)[allowTerms addObject:MYBRuleEntryTerm(d)];
 for(NSString *d in b)[blockTerms addObject:MYBRuleEntryTerm(d)];
 NSString *renamed=[fn stringByReplacingMatchesInString:base options:0 range:NSMakeRange(0,base.length) withTemplate:@"function MYBUserBaseFindProxyForURL("];
 NSMutableString *wrapper=[NSMutableString stringWithString:@"\nfunction FindProxyForURL(url,host){var h=host.toLowerCase();"];
 if(allowTerms.count)[wrapper appendFormat:@"if(%@)return \"DIRECT\";",[allowTerms componentsJoinedByString:@"||"]];
 if(blockTerms.count)[wrapper appendFormat:@"if(%@)return \"PROXY 127.0.0.1:8788\";",[blockTerms componentsJoinedByString:@"||"]];
 [wrapper appendString:@"return MYBUserBaseFindProxyForURL(url,host);}\n"];
 return [renamed stringByAppendingString:wrapper];
}
static inline NSDictionary *MYBRuleDraft(NSDictionary *applied,NSDictionary *legacy){
 NSDictionary *stored=[NSDictionary dictionaryWithContentsOfFile:MYBDraftFile()];if(MYBRuleArray(stored[@"blocked"])&&MYBRuleArray(stored[@"allowed"]))return stored;
 NSMutableDictionary *d=[NSMutableDictionary dictionary];for(NSString *key in @[@"blocked",@"allowed"]){NSString *old=legacy[[key isEqual:@"blocked"]?@"MYB2-block":@"MYB2-allow"];NSArray *items=[old isKindOfClass:NSString.class]?(old.length?[old componentsSeparatedByString:@","]:@[]):nil;d[key]=MYBRuleArray(items)?:MYBRuleArray(applied[key])?:@[];}return d;
}
// Caller snapshots these files before using this inside the Custom Apply transaction.
static inline BOOL MYBTrimWebsiteAllows(NSArray *allowed,NSString *websitePath,NSString *guardPath){
 NSMutableDictionary *web=[[NSDictionary dictionaryWithContentsOfFile:websitePath] mutableCopy];if(!web)return YES;
 NSMutableArray *kept=[NSMutableArray array],*removed=[NSMutableArray array];for(NSString *d in (MYBRuleArray(web[@"domains"])?:@[])){if([allowed containsObject:d])[kept addObject:d];else[removed addObject:d];}
 NSMutableDictionary *guard=[[NSDictionary dictionaryWithContentsOfFile:guardPath] mutableCopy]?:[NSMutableDictionary dictionary];NSMutableArray *ga=[(guard[@"Allowed"]?:@[]) mutableCopy],*gb=[(guard[@"Blocked"]?:@[]) mutableCopy],*added=[(web[@"guardAdded"]?:@[]) mutableCopy],*taken=[(web[@"guardRemoved"]?:@[]) mutableCopy];
 for(NSString *d in removed){if([added containsObject:d])[ga removeObject:d];if([taken containsObject:d]&&![gb containsObject:d])[gb addObject:d];[added removeObject:d];[taken removeObject:d];}
 web[@"domains"]=kept;web[@"guardAdded"]=added;web[@"guardRemoved"]=taken;web[@"revision"]=NSUUID.UUID.UUIDString;guard[@"Allowed"]=ga;guard[@"Blocked"]=gb;
 return [web writeToFile:websitePath atomically:YES]&&[guard writeToFile:guardPath atomically:YES];
}

