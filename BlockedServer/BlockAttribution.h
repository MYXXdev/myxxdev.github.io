#import "../Shared/MYBPACDecision.h"
#import "../Shared/MYBShield.h"
// Explains a blocked website navigation. Returns the reason code and the human wording separately so
// the page can distinguish "a rule you added", "the active blocking mode" and "unknown".
static NSDictionary *blockedExplanation(NSString *raw,NSArray<NSURLQueryItem *> *items){
 NSString *url=websiteURL(raw);if(!url)return @{@"code":@"unknown"};NSString *via=nil;for(NSURLQueryItem *i in items)if([i.name isEqual:@"reason"])via=i.value;
 NSString *guardReason=nil;NSDictionary *guard=guardPreferences();NSString *host=[NSURL URLWithString:url].host.lowercaseString;NSString *app=nil;for(NSURLQueryItem *i in items)if([i.name isEqual:@"app"])app=i.value;
 if([app isEqual:@"com.apple.mobilesafari"]&&!MYBHostInRules(host,guard[@"Allowed"])){
  BOOL custom=MYBHostInRules(host,guard[@"Blocked"]);for(id prefix in guard[@"URLs"])if([prefix isKindOfClass:NSString.class]&&[prefix length]&&[url hasPrefix:prefix])custom=YES;
  if([via isEqual:@"custom"]&&custom)guardReason=@"custom";
 }
 NSDictionary *pac=browserConfig()[@"pac"];if(guardReason)return MYBBlockExplain(url,nil,nil,nil,nil,guardReason);if(![pac[@"active"] boolValue])return @{@"code":@"unknown"};
 // Base PAC for attribution comes from the active inline runtime's mode file, not from a local server.
 // The active generation (PACCurrent, which rule updates replace) comes first; the bundled rules are the fallback.
 NSString *(^rulesFile)(NSString *)=^NSString *(NSString *name){NSString *t=[NSString stringWithContentsOfFile:bridgeFile([@"var/mobile/Library/MYbloXX/PACCurrent/" stringByAppendingString:name]) encoding:NSUTF8StringEncoding error:NULL];return t?:[NSString stringWithContentsOfFile:bridgeFile([@"usr/share/mybloxx/pacs/" stringByAppendingString:name]) encoding:NSUTF8StringEncoding error:NULL];};
 NSString *base=rulesFile(@"Default.pac");NSMutableDictionary *optionPACs=[NSMutableDictionary dictionary];
 for(NSString *o in MYBOptionsForModeID(pac[@"mode"])?:@[]){NSString *t=rulesFile([o stringByAppendingString:@".pac"]);if(t)optionPACs[o]=t;}
 NSDictionary *applied=[NSDictionary dictionaryWithContentsOfFile:bridgeFile(@"var/mobile/Library/MYbloXX/AppliedRules.plist")];
 return MYBBlockExplainWithOptions(url,pac[@"mode"],pac[@"script"],base,applied,nil,optionPACs);
}
static NSString *blockedReasonText(NSDictionary *e){
 NSString *code=e[@"code"];
 if([code isEqual:@"custom-rule"])return @"A rule you added blocks this website.";
 if([code isEqual:@"filter-mode"])return [NSString stringWithFormat:@"The active MYbloXX® blocking mode (%@) blocks this website.",e[@"mode"]];
 return @"MYbloXX® protection blocks this website.";
}
