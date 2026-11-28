#pragma once
// MYbloXX® Safari Cleanup rules. Narrow, named page elements are hidden with CSS only: nothing is ever clicked, accepted or dismissed for you, and a site that
// needs a consent choice keeps its own controls reachable through the exception list and the Pause switch. Rules come from this file's built-in set, or from an
// optional rules file that is validated first; a bad file never replaces the last working set.
#import <Foundation/Foundation.h>
#define MYB_CLEANUP_MAX_SELECTORS 80
#define MYB_CLEANUP_MAX_LENGTH 120
static inline NSArray *MYBCleanupCategories(void){return [NSArray arrayWithObjects:@"cookies",@"openInApp",@"chat",@"newsletter",nil];}
static inline NSDictionary *MYBCleanupDefaultRules(void){
 return [NSDictionary dictionaryWithObjectsAndKeys:
  [NSArray arrayWithObjects:@"#onetrust-banner-sdk",@"#onetrust-consent-sdk",@"#CybotCookiebotDialog",@"#CybotCookiebotDialogBodyUnderlay",@"#truste-consent-track",@"#cookie-law-info-bar",@"#cookieNotice",@".cc-window.cc-banner",@".cc-window.cc-floating",@"#didomi-host",@"#qc-cmp2-container",@".osano-cm-window",@"#usercentrics-root",nil],@"cookies",
  [NSArray arrayWithObjects:@"#smartbanner",@".smartbanner",@".smart-banner",@".app-banner",@".open-in-app-banner",@"#open-in-app",nil],@"openInApp",
  [NSArray arrayWithObjects:@"#intercom-container",@".intercom-lightweight-app",@"#drift-widget-container",@"#hubspot-messages-iframe-container",@"#crisp-chatbox",nil],@"chat",
  [NSArray arrayWithObjects:@".newsletter-popup",@"#newsletter-popup",@".popup-newsletter",nil],@"newsletter",nil];
}
// A selector is accepted only if it is short, plain ASCII and cannot close a rule or start another one.
static inline BOOL MYBCleanupSelectorOK(NSString *selector){
 if(![selector isKindOfClass:NSString.class]||selector.length<2||selector.length>MYB_CLEANUP_MAX_LENGTH)return NO;
 NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#.-_[]=\"'*^$~|:>+ "];
 if([selector rangeOfCharacterFromSet:allowed.invertedSet].location!=NSNotFound)return NO;
 if([selector rangeOfString:@"{"].location!=NSNotFound)return NO;
 NSString *first=[selector substringToIndex:1];return [first isEqualToString:@"#"]||[first isEqualToString:@"."]||[first isEqualToString:@"["]||isalpha([selector characterAtIndex:0]);
}
// Whole-file validation: every category known, every selector acceptable, sensible sizes. Returns the cleaned dictionary, or nil for any problem.
static inline NSDictionary *MYBCleanupValidate(id raw){
 if(![raw isKindOfClass:NSDictionary.class])return nil;
 NSDictionary *cats=[(NSDictionary *)raw objectForKey:@"categories"];if(![cats isKindOfClass:NSDictionary.class]||!cats.count)return nil;
 NSMutableDictionary *out=[NSMutableDictionary dictionary];
 for(NSString *key in cats){
  if(![MYBCleanupCategories() containsObject:key])return nil;
  NSArray *list=[cats objectForKey:key];if(![list isKindOfClass:NSArray.class]||list.count>MYB_CLEANUP_MAX_SELECTORS)return nil;
  for(id item in list)if(!MYBCleanupSelectorOK(item))return nil;
  [out setObject:list forKey:key];
 }
 return out;
}
// Chooses the rule set: a valid update (then remembered as the last working set), else the last working set, else the built-in rules. source: update / last-working / built-in.
static inline NSDictionary *MYBCleanupLoad(NSString *updatePath,NSString *lastGoodPath,NSString **source){
 NSData *data=updatePath?[NSData dataWithContentsOfFile:updatePath]:nil;
 if(data.length&&data.length<100000){
  NSDictionary *ok=MYBCleanupValidate([NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]);
  if(ok){[data writeToFile:lastGoodPath atomically:YES];if(source)*source=@"update";return ok;}
 }
 NSData *good=lastGoodPath?[NSData dataWithContentsOfFile:lastGoodPath]:nil;
 NSDictionary *kept=good.length?MYBCleanupValidate([NSJSONSerialization JSONObjectWithData:good options:0 error:NULL]):nil;
 if(kept){if(source)*source=(data.length?@"last-working":@"update");return kept;}
 if(source)*source=@"built-in";return MYBCleanupDefaultRules();
}
// Typed or pasted text becomes a bare host: "https://www.Example.com/a?b" -> "example.com". nil when it is not a plausible host.
static inline NSString *MYBCleanupHost(NSString *input){
 NSString *t=[[input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];if(!t.length)return nil;
 NSRange scheme=[t rangeOfString:@"://"];if(scheme.location!=NSNotFound)t=[t substringFromIndex:scheme.location+3];
 for(NSString *stop in [NSArray arrayWithObjects:@"/",@"?",@"#",nil]){NSRange r=[t rangeOfString:stop];if(r.location!=NSNotFound)t=[t substringToIndex:r.location];}
 if([t hasPrefix:@"www."])t=[t substringFromIndex:4];
 if(t.length<3||t.length>253||[t rangeOfString:@"."].location==NSNotFound)return nil;
 NSCharacterSet *ok=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"];
 if([t rangeOfCharacterFromSet:ok.invertedSet].location!=NSNotFound||[t hasPrefix:@"."]||[t hasSuffix:@"."]||[t hasPrefix:@"-"])return nil;
 return t;
}
static inline BOOL MYBCleanupFlag(NSDictionary *config,NSString *key){id v=[config objectForKey:key];return [v isKindOfClass:NSNumber.class]&&[v boolValue];}
static inline BOOL MYBCleanupPaused(NSDictionary *config,double now){id v=[config objectForKey:@"CleanupPausedUntil"];return [v isKindOfClass:NSNumber.class]&&[v doubleValue]>now;}
static inline NSArray *MYBCleanupExceptions(NSDictionary *config){
 NSMutableArray *out=[NSMutableArray array];id raw=[config objectForKey:@"CleanupExceptions"];
 if([raw isKindOfClass:NSArray.class])for(id item in raw){NSString *h=[item isKindOfClass:NSString.class]?MYBCleanupHost(item):nil;if(h&&![out containsObject:h])[out addObject:h];}
 return out;
}
// The WebKit content-rule list: one css-display-none rule for the switched-on categories, skipping every excepted site (and its subdomains). nil = nothing to apply.
static inline NSString *MYBCleanupRuleJSON(NSDictionary *rules,NSDictionary *config,double now){
 if(MYBCleanupPaused(config,now))return nil;
 NSDictionary *switches=[NSDictionary dictionaryWithObjectsAndKeys:@"CleanupCookies",@"cookies",@"CleanupOpenInApp",@"openInApp",@"CleanupChat",@"chat",@"CleanupNewsletter",@"newsletter",nil];
 NSMutableArray *selectors=[NSMutableArray array];
 for(NSString *cat in MYBCleanupCategories())if(MYBCleanupFlag(config,[switches objectForKey:cat]))for(NSString *s in [rules objectForKey:cat])if(![selectors containsObject:s])[selectors addObject:s];
 if(!selectors.count)return nil;
 NSMutableDictionary *trigger=[NSMutableDictionary dictionaryWithObject:@".*" forKey:@"url-filter"];
 NSMutableArray *skip=[NSMutableArray array];for(NSString *h in MYBCleanupExceptions(config))[skip addObject:[@"*" stringByAppendingString:h]];
 if(skip.count)[trigger setObject:skip forKey:@"unless-domain"];
 NSDictionary *action=[NSDictionary dictionaryWithObjectsAndKeys:@"css-display-none",@"type",[selectors componentsJoinedByString:@", "],@"selector",nil];
 NSArray *list=[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:trigger,@"trigger",action,@"action",nil]];
 NSData *json=[NSJSONSerialization dataWithJSONObject:list options:0 error:NULL];
 return json?[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]:nil;
}
