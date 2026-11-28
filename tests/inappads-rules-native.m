// Behaviour tests for the rule-table ad modules (Threads, Gmail) and the shared rule installer, on real Objective-C classes built at run time.
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../Shared/MYBAdsReport.h"
#include "../Companions/InAppAds/Threads/Module.m"
#include "../Companions/InAppAds/Gmail/Module.m"
#include "../Companions/InAppAds/Douban/Module.m"
#include "../Companions/InAppAds/QQMusic/Module.m"
#include "../Companions/InAppAds/Sogou/Module.m"
#include "../Companions/InAppAds/WeChat/Module.m"
static int failures=0;
#define REQUIRE(c,...) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",(__VA_ARGS__));failures++;}}while(0) // the message may be a bracketed expression containing commas
static Class make(const char *name){Class c=objc_allocateClassPair(NSObject.class,name,0);objc_registerClassPair(c);return c;}
static void add(Class c,const char *sel,id block,const char *types){class_addMethod(c,sel_registerName(sel),imp_implementationWithBlock(block),types);}

// Every rule of a table, exercised on a class built to its exact signature (original answers YES / an object / counts a call), plus one
// rule per table whose signature is deliberately wrong.
static void checkTable(const char *label,NSString *module,const MYBAdsRule *rules,NSUInteger n,NSUInteger (*install)(NSUInteger *)){
 NSUInteger att=0;
 REQUIRE(install(&att)==0&&att==n,[[NSString stringWithFormat:@"%s: nothing installs while the app's classes are absent",label] UTF8String]);
 __block int originals=0;
 for(NSUInteger i=0;i<n;i++){
  Class c=objc_getClass(rules[i].cls);if(!c)c=make(rules[i].cls);
  Class t=rules[i].classMethod?object_getClass(c):c;char r=rules[i].sig[0];
  if(r=='B')add(t,rules[i].sel,^BOOL(id s){originals++;return YES;},rules[i].sig);
  else if(r=='@')add(t,rules[i].sel,^id(id s){originals++;return @"ad";},rules[i].sig);
  else if(r=='d')add(t,rules[i].sel,^double(id s){originals++;return 50;},rules[i].sig);
  else add(t,rules[i].sel,^(id s){originals++;},rules[i].sig);
 }
 NSUInteger ok=install(&att);
 REQUIRE(ok==n&&att==n,[[NSString stringWithFormat:@"%s: all %lu rules install on exact signatures",label,(unsigned long)n] UTF8String]);
 for(NSUInteger i=0;i<n;i++){
  Class c=objc_getClass(rules[i].cls);id target=rules[i].classMethod?(id)c:[c new];SEL sel=sel_registerName(rules[i].sel);char r=rules[i].sig[0];
  if(r=='B')REQUIRE(((BOOL(*)(id,SEL))objc_msgSend)(target,sel)==NO,[[NSString stringWithFormat:@"%s: %s answers NO",label,rules[i].sel] UTF8String]);
  else if(r=='@')REQUIRE(((id(*)(id,SEL))objc_msgSend)(target,sel)==nil,[[NSString stringWithFormat:@"%s: %s answers nil",label,rules[i].sel] UTF8String]);
  else if(r=='d')REQUIRE(((double(*)(id,SEL))objc_msgSend)(target,sel)==0,"height is zero");
  else ((void(*)(id,SEL))objc_msgSend)(target,sel);
 }
 REQUIRE(originals==0,[[NSString stringWithFormat:@"%s: no original ad method runs",label] UTF8String]);
 REQUIRE(install(&att)==0,[[NSString stringWithFormat:@"%s: a second pass adds nothing",label] UTF8String]);
}
int main(void){@autoreleasepool{
 // nothing present: nothing installed, nothing breaks
 NSUInteger attempted=0;
 REQUIRE(MYBThreadsInstallHooks(&attempted)==0&&attempted==6,"Threads: with the app's classes absent no rule installs, six are attempted");
 REQUIRE(MYBGmailInstallHooks(&attempted)==0&&attempted==4,"Gmail: with the app's classes absent no rule installs, four are attempted");
 // Threads: three classes, one of the methods reshaped (returns BOOL instead of void)
 __block int started=0,processed=0,inserted=0,received=0,delivered=0,fetched=0;
 Class mgr=make("_TtC15IGBCNAdsManager15IGBCNAdsManager");
 add(mgr,"startNewAdDeliveryWithSurfaceDelegate:sessionId:analyticsModule:",^(id s,id a,id b,id c){started++;},"v@:@@@");
 add(mgr,"processSponsoredItems:projectedItems:analyticsModule:",^(id s,id a,id b,id c){processed++;},"v@:@@@");
 Class handler=make("_TtC15IGBCNAdsManager37BCNMainFeedAdsInsertionSurfaceHandler");
 add(handler,"adInsertionHandler:shouldTryToInsertSponsoredItem:atInsertionIndex:focusedIndex:insertionContext:",^(id s,id a,id b,long long i,long long f,id c){inserted++;},"v@:@@qq@");
 add(handler,"receivedSponsoredItems:intentAwareData:",^(id s,id a,id b){received++;},"v@:@@");
 add(handler,"adPlatformDidDeliverSponsoredItem:atAdRequestIndex:",^BOOL(id s,id a,long long i){delivered++;return YES;},"B@:@q");
 Class fetcher=make("IGAdFetcherManager");
 add(fetcher,"adFetcher:didReturnAdsResponse:paginationInfo:requestMetadata:isFromCache:adRequestExtraInfo:",^(id s,id a,id b,id c,id d,BOOL e,id f){fetched++;},"v@:@@@@B@");
 NSUInteger ok=MYBThreadsInstallHooks(&attempted);
 REQUIRE(attempted==6&&ok==5,"Threads: five rules install; the reshaped (BOOL) method is left alone");
 ((void(*)(id,SEL,id,id,id))objc_msgSend)([mgr new],sel_registerName("startNewAdDeliveryWithSurfaceDelegate:sessionId:analyticsModule:"),nil,nil,nil);
 ((void(*)(id,SEL,id,id,id))objc_msgSend)([mgr new],sel_registerName("processSponsoredItems:projectedItems:analyticsModule:"),nil,nil,nil);
 ((void(*)(id,SEL,id,id))objc_msgSend)([handler new],sel_registerName("receivedSponsoredItems:intentAwareData:"),nil,nil);
 ((void(*)(id,SEL,id,long long,long long,id))objc_msgSend)([handler new],sel_registerName("adInsertionHandler:shouldTryToInsertSponsoredItem:atInsertionIndex:focusedIndex:insertionContext:"),nil,0,0,nil);
 REQUIRE(started==0&&processed==0&&received==0&&inserted==0,"Threads: the ad request, sponsored items and insertion calls do nothing");
 BOOL d=((BOOL(*)(id,SEL,id,long long))objc_msgSend)([handler new],sel_registerName("adPlatformDidDeliverSponsoredItem:atAdRequestIndex:"),nil,0);
 REQUIRE(d==YES&&delivered==1,"Threads: a method whose type changed still runs its original");
 ((void(*)(id,SEL,id,id,id,id,BOOL,id))objc_msgSend)([fetcher new],sel_registerName("adFetcher:didReturnAdsResponse:paginationInfo:requestMetadata:isFromCache:adRequestExtraInfo:"),nil,nil,nil,nil,NO,nil);
 REQUIRE(fetched==0,"Threads: the ad fetcher response is dropped");
 // a second pass installs nothing new and never stacks a second replacement
 REQUIRE(MYBThreadsInstallHooks(&attempted)==0,"Threads: a second install pass adds nothing");
 // Gmail: class methods answering heights; instance method of the same name must not be touched
 Class ads=make("AdsCell"),impl=make("GBTAdsCellImpl");
 Class adsMeta=object_getClass(ads),implMeta=object_getClass(impl);
 add(adsMeta,"heightForObject:width:expansionState:",^double(id s,id o,double w,id e){return 88;},"d@:@d@");
 add(adsMeta,"heightForObject:width:",^double(id s,id o,double w){return 88;},"d@:@d");
 add(implMeta,"heightForObject:width:",^double(id s,id o,double w){return 88;},"d@:@d");
 add(implMeta,"heightForObject:width:expansionState:",^float(id s,id o,double w,id e){return 88;},"f@:@d@"); // reshaped: float
 ok=MYBGmailInstallHooks(&attempted);
 REQUIRE(attempted==4&&ok==3,"Gmail: three rules install; the float-returning method is left alone");
 double h1=((double(*)(id,SEL,id,double,id))objc_msgSend)(ads,sel_registerName("heightForObject:width:expansionState:"),nil,300,nil);
 double h2=((double(*)(id,SEL,id,double))objc_msgSend)(ads,sel_registerName("heightForObject:width:"),nil,300);
 double h3=((double(*)(id,SEL,id,double))objc_msgSend)(impl,sel_registerName("heightForObject:width:"),nil,300);
 float h4=((float(*)(id,SEL,id,double,id))objc_msgSend)(impl,sel_registerName("heightForObject:width:expansionState:"),nil,300,nil);
 REQUIRE(h1==0&&h2==0&&h3==0,"Gmail: ad rows take no height");
 REQUIRE(h4==88.0f,"Gmail: the reshaped method keeps its original answer");

 checkTable("Douban",@"douban",kDoubanRules,sizeof(kDoubanRules)/sizeof(kDoubanRules[0]),MYBDoubanInstallHooks);
 checkTable("QQ Music",@"qqmusic",kQQMusicRules,sizeof(kQQMusicRules)/sizeof(kQQMusicRules[0]),MYBQQMusicInstallHooks);
 checkTable("Sogou",@"sogou",kSogouRules,sizeof(kSogouRules)/sizeof(kSogouRules[0]),MYBSogouInstallHooks);
 checkTable("WeChat",@"wechat",kWeChatRules,sizeof(kWeChatRules)/sizeof(kWeChatRules[0]),MYBWeChatInstallHooks);
 // ---- the shared installer itself: full-signature validation, instance vs class, inherited methods, duplicates
 {
  Class base=make("MYBRuleBase"),child=objc_allocateClassPair(base,"MYBRuleChild",0);objc_registerClassPair(child);
  __block int calls=0;
  add(base,"ok:with:",^(id s,id a,long long b){calls++;},"v@:@q");           // matches "v@:@q"
  add(base,"wrongCount:",^(id s,id a){calls++;},"v@:@");                    // table says two arguments: count mismatch
  add(base,"wrongType:",^(id s,long long a){calls++;},"v@:q");              // table says object argument: type mismatch
  add(base,"classOnly",^(id s){calls++;},"v@:");                            // instance method; table says class method
  add(object_getClass(base),"instanceOnly",^(id s){calls++;},"v@:");        // class method; table says instance method
  add(base,"flag",^BOOL(id s){calls++;return YES;},"c@:");                  // BOOL encoded as c
  add(base,"flag2",^BOOL(id s){calls++;return YES;},"c@:");
  add(base,"retObj",^id(id s){calls++;return @"x";},"@@:");
  add(base,"retVoidShape",^(id s){calls++;},"v@:");                         // table says object return: type mismatch
  const MYBAdsRule table[]={
   {"MYBRuleBase","ok:with:","v@:@q",NO,NO,"slot"},{"MYBRuleBase","wrongCount:","v@:@@",NO,NO,"slot"},{"MYBRuleBase","wrongType:","v@:@",NO,NO,"slot"},
   {"MYBRuleBase","classOnly","v@:",YES,NO,"slot"},{"MYBRuleBase","instanceOnly","v@:",NO,NO,"slot"},{"MYBRuleBase","flag","B@:",NO,NO,"slot"},
   {"MYBRuleBase","retObj","@@:",NO,NO,"slot"},{"MYBRuleBase","retVoidShape","@@:",NO,NO,"slot"},{"MYBRuleBase","missing","v@:",NO,NO,"slot"},
   {"NoSuchClass","ok:with:","v@:@q",NO,NO,"slot"}};
  NSUInteger n=sizeof(table)/sizeof(table[0]),att=0,done=MYBAdsInstallRules(@"threads",table,n,&att);
  REQUIRE(att==n&&done==3,"installer: only exact signatures install (matching void, BOOL-as-c and object rules); count, type, instance/class, return and missing all skipped");
  ((void(*)(id,SEL,id,long long))objc_msgSend)([base new],sel_registerName("ok:with:"),nil,1);
  ((void(*)(id,SEL,id))objc_msgSend)([base new],sel_registerName("wrongCount:"),nil);
  ((void(*)(id,SEL,long long))objc_msgSend)([base new],sel_registerName("wrongType:"),1);
  REQUIRE(calls==2,"installer: the matching rule is neutralised, the two mismatched ones still run their originals");
  REQUIRE(((BOOL(*)(id,SEL))objc_msgSend)([base new],sel_registerName("flag"))==NO&&((id(*)(id,SEL))objc_msgSend)([base new],sel_registerName("retObj"))==nil,"installer: BOOL answers NO and object answers nil");
  REQUIRE(((BOOL(*)(id,SEL))objc_msgSend)([base new],sel_registerName("flag2"))==YES,"installer: a method not in the table is untouched");
  ((void(*)(id,SEL))objc_msgSend)([base new],sel_registerName("retVoidShape")); // the original returns nothing, so its return register is not inspected
  REQUIRE(calls==4,"installer: a mismatched return type keeps the original (2 mismatched originals, the untouched flag2, then this one)");
  // duplicate installation
  REQUIRE(MYBAdsInstallRules(@"threads",table,n,&att)==0,"installer: a second pass installs nothing and does not stack replacements");
  // inherited method: a rule on the subclass replaces it on the subclass only; the base keeps its original
  __block int inherited=0;add(base,"shared",^(id s){inherited++;},"v@:");
  const MYBAdsRule sub[]={{"MYBRuleChild","shared","v@:",NO,NO,"slot"}};
  REQUIRE(MYBAdsInstallRules(@"threads",sub,1,&att)==1,"installer: an inherited method is found through the subclass");
  ((void(*)(id,SEL))objc_msgSend)([child new],sel_registerName("shared"));
  REQUIRE(inherited==0,"installer: the subclass instance no longer runs the inherited original");
  ((void(*)(id,SEL))objc_msgSend)([base new],sel_registerName("shared"));
  REQUIRE(inherited==1,"installer: the base class keeps its own method");
  REQUIRE(MYBAdsInstallRules(@"threads",sub,1,&att)==0,"installer: the same inherited rule is not installed twice");
  // class methods
  Class meta=object_getClass(base);__block int classCalls=0;add(meta,"classSide",^(id s){classCalls++;},"v@:");
  const MYBAdsRule cm[]={{"MYBRuleBase","classSide","v@:",YES,NO,"slot"},{"MYBRuleBase","classSide","v@:",NO,NO,"slot"}};
  REQUIRE(MYBAdsInstallRules(@"threads",cm,2,&att)==1,"installer: a class-method rule installs on the class side only");
  ((void(*)(id,SEL))objc_msgSend)(base,sel_registerName("classSide"));
  REQUIRE(classCalls==0,"installer: the class method is neutralised");
 }
 if(failures){fprintf(stderr,"%d failure(s)\n",failures);return 1;}
 printf("Threads and Gmail rule-table module checks passed.\n");return 0;}}
