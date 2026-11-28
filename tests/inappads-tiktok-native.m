// TikTok module: compiled with ARC like the rest of the shared dylib. An ad model must actually be freed (not leaked), a kept one must survive.
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#import <objc/message.h>
#include "../Companions/InAppAds/TikTok/Module.m"
static int failures=0;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)
static int deallocs=0;
@interface MYBProbe:NSObject @end
@implementation MYBProbe
-(void)dealloc{deallocs++;}
@end
// Initialisers hand the object back owned. The fakes and the test's own calls say so, so ARC keeps every count honest.
typedef __attribute__((ns_returns_retained)) id (*MYBInitCall)(id,SEL);
typedef __attribute__((ns_returns_retained)) id (*MYBInitDictCall)(id,SEL,id,NSError **);
__attribute__((ns_returns_retained)) static id fakeInit(id s,SEL c){return s;}
__attribute__((ns_returns_retained)) static id fakeInitDict(id s,SEL c,id d,NSError **e){objc_setAssociatedObject(s,"t",d[@"t"],OBJC_ASSOCIATION_RETAIN);objc_setAssociatedObject(s,"probe",[MYBProbe new],OBJC_ASSOCIATION_RETAIN);return s;}

int main(void){@autoreleasepool{
 NSUInteger attempted=0;REQUIRE(MYBTikTokInstallHooks(&attempted)==0&&attempted==2,"TikTok: no class, no hooks");
 Class aweme=objc_allocateClassPair(NSObject.class,"AWEAwemeModel",0);objc_registerClassPair(aweme);
 class_addMethod(aweme,sel_registerName("isAds"),imp_implementationWithBlock(^BOOL(id s){return NO;}),"B@:");
 class_addMethod(aweme,sel_registerName("adType"),imp_implementationWithBlock(^long(id s){return [objc_getAssociatedObject(s,"t") longValue];}),"q@:");
 class_addMethod(aweme,sel_registerName("init"),(IMP)fakeInit,"@@:");
 class_addMethod(aweme,sel_registerName("initWithDictionary:error:"),(IMP)fakeInitDict,"@@:@^@");
 REQUIRE(MYBTikTokInstallHooks(&attempted)==2,"TikTok: both initialisers hooked");
 id organic=((MYBInitDictCall)objc_msgSend)([aweme alloc],sel_registerName("initWithDictionary:error:"),@{@"t":@0},NULL);
 REQUIRE(organic!=nil,"TikTok: a normal video is kept");
@autoreleasepool{
 id ad=((MYBInitDictCall)objc_msgSend)([aweme alloc],sel_registerName("initWithDictionary:error:"),@{@"t":@1},NULL);
 REQUIRE(ad==nil,"TikTok: an ad video is never returned");}
 REQUIRE(deallocs==1,"TikTok: the rejected ad model was freed exactly once (no leak, no double release)");
 id plain=((MYBInitCall)objc_msgSend)([aweme alloc],sel_registerName("init"));REQUIRE(plain!=nil,"TikTok: plain init keeps a normal video");
 REQUIRE(!MYBTikTokAwemeIsAd(nil)&&!MYBTikTokAwemeIsAd(@"x"),"TikTok: unknown objects are not ads");
 // Douyin names the same decision differently: each of its three ad selectors marks a model as an ad, and only when answering YES
 for(NSString *name in @[@"checkIsAd",@"isHardAdModel",@"isHardAd"]){
  Class k=objc_allocateClassPair(NSObject.class,[[@"MYBDouyin_" stringByAppendingString:name] UTF8String],0);objc_registerClassPair(k);
  class_addMethod(k,sel_registerName(name.UTF8String),imp_implementationWithBlock(^BOOL(id s){return [objc_getAssociatedObject(s,"y") boolValue];}),"B@:");
  id yes=[k new],no=[k new];objc_setAssociatedObject(yes,"y",@YES,OBJC_ASSOCIATION_RETAIN);objc_setAssociatedObject(no,"y",@NO,OBJC_ASSOCIATION_RETAIN);
  REQUIRE(MYBTikTokAwemeIsAd(yes)&&!MYBTikTokAwemeIsAd(no),[[@"Douyin: " stringByAppendingString:name] UTF8String]);
 }
 if(failures)return 1;printf("TikTok ad module checks passed.\n");return 0;}}
