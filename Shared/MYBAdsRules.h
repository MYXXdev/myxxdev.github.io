#pragma once
// Rule tables for the in-app ad modules whose whole job is to switch off named, advertising-only methods.
//
// A rule names one class, one selector, whether it is a class method, and the method's FULL expected signature as one character per
// type, return type first, then self, _cmd and each argument (for example "v@:@@q" is a void method taking two objects and a long long):
//   v void  @ object  B BOOL  d double  q long long  Q unsigned long long  i int  I unsigned int  f float  c char
// The first character also says what the replacement answers: 'v' does nothing, '@' answers nil, 'B' answers NO, 'd' answers 0.
// A rule is installed only when the method exists on that class (instance or class side, as stated) and its real argument count and every
// argument and return type match the stated signature, so a renamed or reshaped method leaves the app untouched; nothing is guessed. The original is never called, so nothing is half-run. The replacement ignores the method's
// arguments, which is safe for any argument list on arm64 (the caller owns its argument registers).
// counted: YES for calls that stand for an ad request, load or placement being refused (reported to Status); NO for display plumbing
// such as a row height, which is applied on every layout and would make the count meaningless.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "MYBInAppAds.h"
#import "MYBAdsReport.h"
#import "MYBAdsSignature.h"

typedef struct{const char *cls;const char *sel;const char *sig;BOOL classMethod;BOOL counted;const char *category;}MYBAdsRule;

static inline IMP MYBAdsRuleReplacement(const MYBAdsRule *rule,NSString *module){
 NSString *category=[NSString stringWithUTF8String:rule->category?:"slot"];BOOL counted=rule->counted;
 switch(rule->sig[0]){
  case 'v':return imp_implementationWithBlock(^(id self_){if(counted)MYBAdsNoteDecisions(module,category,1);});
  case '@':return imp_implementationWithBlock(^id(id self_){if(counted)MYBAdsNoteDecisions(module,category,1);return nil;});
  case 'B':return imp_implementationWithBlock(^BOOL(id self_){if(counted)MYBAdsNoteDecisions(module,category,1);return NO;});
  case 'd':return imp_implementationWithBlock(^double(id self_){return 0.0;});
 }
 return NULL;
}
static inline NSMutableSet<NSString *> *MYBAdsInstalledRules(void){static NSMutableSet *set;static dispatch_once_t once;dispatch_once(&once,^{set=[NSMutableSet set];});return set;}
// Installs every rule whose class and method exist with the stated signature. Returns how many were installed in this pass; *attempted is
// the table size. A rule already installed by an earlier pass is skipped, so a second pass never stacks a second replacement.
static inline NSUInteger MYBAdsInstallRules(NSString *module,const MYBAdsRule *rules,NSUInteger count,NSUInteger *attempted){
 NSUInteger ok=0;
 for(NSUInteger i=0;i<count;i++){
  Class cls=objc_getClass(rules[i].cls);if(!cls)continue;
  SEL sel=sel_registerName(rules[i].sel);
  Class target=rules[i].classMethod?object_getClass(cls):cls;
  Method method=rules[i].classMethod?class_getClassMethod(cls,sel):class_getInstanceMethod(cls,sel);
  if(!MYBAdsSignatureMatches(method,rules[i].sig))continue;
  NSString *key=[NSString stringWithFormat:@"%p|%s|%d",(void *)cls,rules[i].sel,rules[i].classMethod];
  @synchronized(MYBAdsInstalledRules()){
   if([MYBAdsInstalledRules() containsObject:key])continue;
   IMP replacement=MYBAdsRuleReplacement(&rules[i],module);if(!replacement)continue;
   class_replaceMethod(target,sel,replacement,method_getTypeEncoding(method));
   [MYBAdsInstalledRules() addObject:key];ok++;
  }
 }
 if(attempted)*attempted=count;
 return ok;
}
