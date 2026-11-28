#pragma once
// Full-signature matching for run-time method replacement: shared by the rule tables and the ad SDK module.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdlib.h>
// A signature is one character per type, return type first, then self, _cmd and each argument ("v@:@@q"). Block arguments (@?) count as @.
static inline char MYBAdsTypeChar(const char *encoding){
 while(*encoding&&strchr("rnNoORV",*encoding))encoding++; // qualifiers (const, in, out...) are not part of the type
 return *encoding;
}
// True when the method's argument count, return type and every argument type are exactly those of sig. BOOL may be encoded B or c.
static inline BOOL MYBAdsSignatureMatches(Method method,const char *sig){
 if(!method||!sig||!sig[0])return NO;
 size_t want=strlen(sig);if(method_getNumberOfArguments(method)+1!=want)return NO;
 char *ret=method_copyReturnType(method);char got=ret?MYBAdsTypeChar(ret):0;free(ret);
 if(got!=sig[0]&&!(sig[0]=='B'&&got=='c'))return NO;
 for(unsigned i=0;i<want-1;i++){
  char *arg=method_copyArgumentType(method,i);char a=arg?MYBAdsTypeChar(arg):0;free(arg);
  char w=sig[i+1];if(a!=w&&!(w=='B'&&a=='c'))return NO;
 }
 return YES;
}
