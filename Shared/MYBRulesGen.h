#pragma once
// Local generation of every blocking mode from canonical rules. rules/generate.js (a byte-for-byte twin of rules/generate.py,
// proven by tests/gen-parity.js) runs in JavaScriptCore. The generator and its runtime text come from the installed package and
// are never downloaded; only the rules data (canonical.json) can come from an update. Pure functions, no I/O except reading
// the generator files, so the native tests exercise the shipping code.
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "MYBOptions.h"
#import "MYBPACStamp.h"
// Every file name a complete generation has: 32 option identifiers plus the historical standalone names (byte copies).
static inline NSArray<NSString *> *MYBHistoricalPACNames(void){return @[@"MYbloXX",@"MYbloXXTest",@"MYbloXXallowFB",@"MYbloXXallowY",@"MYbloXXnoApple",@"MYbloXXnoFB",@"MYbloXXnoSocials",@"MYbloXXnoXXX"];}
static inline NSArray<NSString *> *MYBGeneratedPACNames(void){return [MYBModeIDs() arrayByAddingObjectsFromArray:MYBHistoricalPACNames()];}
static inline NSString *MYBRulesRoute(JSContext *c,NSString *url,NSString *host){
 JSValue *f=c[@"FindProxyForURL"];if(!f.isObject)return nil;JSValue *v=[f callWithArguments:@[url,host]];return c.exception||!v.isString?nil:v.toString;
}
// A generated PAC must evaluate and make the decisions no rules update may change. Returns nil when sound, else a plain reason.
static inline NSString *MYBPACSelfCheck(NSData *pac,NSString *modeID){
 NSString *text=[[NSString alloc] initWithData:pac encoding:NSUTF8StringEncoding];
 if(!text.length||text.length>2*1024*1024)return @"the generated PAC is empty or too large";
 JSContext *c=[JSContext new];__block BOOL threw=NO;c.exceptionHandler=^(JSContext *x,JSValue *e){(void)x;(void)e;threw=YES;};
 [c evaluateScript:text];if(threw)return @"the generated PAC does not evaluate";
 NSString *block=@"PROXY 127.0.0.1:8021",*allow=@"DIRECT";
 NSArray *options=MYBOptionsForModeID(modeID)?:@[];
 NSArray *must=@[@[@"ads.doubleclick.net",block],@[@"github.com",allow],@[@"raw.githubusercontent.com",allow],@[@"login.microsoftonline.com",allow],@[@"example.com",allow]];
 for(NSArray *p in must){NSString *r=MYBRulesRoute(c,[NSString stringWithFormat:@"https://%@/",p[0]],p[0]);if(![r isEqual:p[1]])return [NSString stringWithFormat:@"the generated PAC gives %@ for %@",r?:@"no answer",p[0]];}
 if(![options containsObject:@"blockApple"]){NSString *r=MYBRulesRoute(c,@"https://www.apple.com/",@"www.apple.com");if(![r isEqual:allow])return @"the generated PAC blocks Apple without noApple";}
 return nil;
}
// canonical -> {name: NSData} for every name in MYBGeneratedPACNames(), or nil with a reason. Nothing is written anywhere.
static inline NSDictionary<NSString *,NSData *> *MYBGenerateModePACs(NSData *canonical,NSString *generatorDirectory,NSString **why){
#define MYB_GEN_FAIL(...) do{if(why)*why=(__VA_ARGS__);return nil;}while(0)
 NSString *canon=canonical.length&&canonical.length<=2*1024*1024?[[NSString alloc] initWithData:canonical encoding:NSUTF8StringEncoding]:nil;
 NSString *script=[NSString stringWithContentsOfFile:[generatorDirectory stringByAppendingPathComponent:@"generate.js"] encoding:NSUTF8StringEncoding error:NULL];
 NSString *runtime=[NSString stringWithContentsOfFile:[generatorDirectory stringByAppendingPathComponent:@"runtime.txt"] encoding:NSUTF8StringEncoding error:NULL];
 if(!canon.length){MYB_GEN_FAIL(@"the rules file is empty, unreadable or too large");}
 if(!script.length||!runtime.length){MYB_GEN_FAIL(@"the rule generator is missing from the package");}
 JSContext *c=[JSContext new];__block NSString *thrown=nil;c.exceptionHandler=^(JSContext *x,JSValue *e){(void)x;thrown=e.toString;};
 [c evaluateScript:script];if(thrown||![c[@"MYBGenerate"] isObject]){MYB_GEN_FAIL(@"the rule generator could not start");}
 NSString *reason=[c[@"MYBValidateCanonical"] callWithArguments:@[canon]].toString;
 if(thrown){MYB_GEN_FAIL(@"the rule validator failed");}
 if(reason.length&&![reason isEqual:@"undefined"]){MYB_GEN_FAIL([@"the rules were rejected: " stringByAppendingString:reason]);}
 NSString *json=[c[@"MYBGenerate"] callWithArguments:@[canon,runtime]].toString;
 if(thrown||!json.length){MYB_GEN_FAIL(@"the rule generator failed");}
 NSDictionary *files=[NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
 if(![files isKindOfClass:NSDictionary.class]){MYB_GEN_FAIL(@"the generated rules could not be read");}
 NSMutableDictionary *out=[NSMutableDictionary dictionary];NSArray *names=MYBGeneratedPACNames();
 // A historical name is a byte copy of the combination it points to; it is checked against that combination.
 NSDictionary *parsed=[NSJSONSerialization JSONObjectWithData:[canon dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
 // The rules date is part of the release: the validator checks its shape, and every generated file must carry exactly that date.
 long long releaseStamp=[parsed isKindOfClass:NSDictionary.class]?MYBCanonicalStamp(parsed[@"stamp"]):0;
 if(!releaseStamp){MYB_GEN_FAIL(@"the rules have a missing or invalid UTC date");}
 NSDictionary *aliases=[parsed isKindOfClass:NSDictionary.class]&&[parsed[@"aliases"] isKindOfClass:NSDictionary.class]?parsed[@"aliases"]:@{};
 if(files.count!=names.count){MYB_GEN_FAIL(@"the generator produced an unexpected set of files");}
 for(NSString *name in names){
  NSString *text=files[[name stringByAppendingString:@".pac"]];if(![text isKindOfClass:NSString.class]){MYB_GEN_FAIL([@"the generator did not produce " stringByAppendingString:name]);}
  NSData *data=[text dataUsingEncoding:NSUTF8StringEncoding];
  NSString *bad=MYBPACSelfCheck(data,MYBModeIDValid(name)?name:(MYBModeIDValid(aliases[name])?aliases[name]:@"Default"));if(bad){MYB_GEN_FAIL([NSString stringWithFormat:@"%@: %@",name,bad]);}
  if(MYBPACStamp(data)!=releaseStamp||!MYBPACEngineCurrent(data)){MYB_GEN_FAIL([NSString stringWithFormat:@"%@: the generated PAC does not carry the rules date",name]);}
  out[name]=data;
 }
 return out;
}
#undef MYB_GEN_FAIL
// The Default file's header stamp is the generation's identity (same rule the older per-file updater used).
static inline long long MYBGenerationStamp(NSDictionary<NSString *,NSData *> *files){return MYBPACStamp(files[@"Default"]);}
