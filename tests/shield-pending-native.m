#import <Foundation/Foundation.h>
#define MYB_RULE_TESTING 1
#define MYB_SHIELD_TESTING 1
double gMYBShieldWall=0,gMYBShieldMono=0;NSString *gMYBShieldBoot=nil;
#import "../Shared/MYBShield.h"
#import "../Shared/MYBShieldPending.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static void Clock(double w,double m){gMYBShieldWall=w;gMYBShieldMono=m;gMYBShieldBoot=@"boot-A";}
// Mirrors the prompt's Allow handler: age check, save, finish.
static MYBPendingOutcome Allow(NSMutableDictionary *st,NSString *perm,NSString *attempt,NSString *mode,double now,BOOL saveWorks,dispatch_block_t resume,NSDictionary **grant){
 NSDictionary *g=nil;
 if(MYBPendingIsPending(st,attempt,now)&&saveWorks)g=MYBShieldAddGrantFor(perm,@"appredirect",@"com.apple.mobilesafari",@"com.example.app",mode,@"exampleapp",attempt);
 if(grant)*grant=g;
 return MYBPendingFinish(st,attempt,g!=nil,now,resume);
}
int main(void){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",root.UTF8String,1);
 NSString *perm=MYBShieldPermissionsFile();Clock(1000000,5000);
 NSString *S=@"com.apple.mobilesafari",*D=@"com.example.app",*SC=@"exampleapp";
 NSMutableDictionary *st=[NSMutableDictionary dictionary];

 // 1. successful save, no continuation available: "Allowed. Try again."; the grant is bound to that attempt and still unconsumed
 CHECK(MYBPendingBegin(st,@"A1",S,D,SC,100),"attempt registered");
 CHECK(!MYBPendingBegin(st,@"A2",S,D,SC,101),"a concurrent duplicate of the same source/destination/scheme shares the prompt");
 NSDictionary *g=nil;MYBPendingOutcome o=Allow(st,perm,@"A1",@"once",102,YES,nil,&g);
 CHECK(o==MYBPendingTryAgain&&g!=nil,"saved, cannot resume -> try again");
 CHECK([MYBPendingMessage(o,@"Safari",@"Example",@"once") hasPrefix:@"Allowed. Try again."],"the message says Allowed. Try again.");
 CHECK([MYBShieldAllowsScheme(perm,@"appredirect",S,D,SC,YES) isEqual:@"once"],"the retry tap is the one that consumes the permission");
 CHECK(MYBShieldAllowsScheme(perm,@"appredirect",S,D,@"otherscheme",NO)==nil,"a different scheme is not covered");
 CHECK(MYBShieldAllowsScheme(perm,@"appredirect",S,D,SC,YES)==nil,"a third attempt is not allowed: the once grant is used up");

 // 2. second independent attempt prompts again after Allow Once
 CHECK(MYBPendingBegin(st,@"B1",S,D,SC,110),"a new independent attempt registers (prompts again)");
 MYBPendingCancel(st,@"B1");

 // 3. failed save: nothing allowed, nothing resumed
 __block int resumed=0;
 CHECK(MYBPendingBegin(st,@"C1",S,D,SC,120),"attempt");
 o=Allow(st,perm,@"C1",@"once",121,NO,^{resumed++;},&g);
 CHECK(o==MYBPendingNotSaved&&g==nil&&resumed==0,"failed save: not allowed, no continuation");
 CHECK(MYBShieldAllowsScheme(perm,@"appredirect",S,D,SC,NO)==nil,"failed save leaves nothing granted");

 // 4. cancelled and stale attempts
 CHECK(MYBPendingBegin(st,@"D1",S,D,SC,130),"attempt");
 MYBPendingCancel(st,@"D1");
 o=Allow(st,perm,@"D1",@"once",131,YES,^{resumed++;},&g);
 CHECK(o==MYBPendingNone&&g==nil&&resumed==0,"cancelled attempt: nothing saved, nothing resumed");
 CHECK(MYBPendingBegin(st,@"E1",S,D,SC,140),"attempt");
 o=Allow(st,perm,@"E1",@"always",140+MYB_PENDING_WINDOW+1,YES,^{resumed++;},&g);
 CHECK(o==MYBPendingStale&&g==nil&&resumed==0,"stale attempt saves nothing even for Always");
 CHECK(!MYBPendingIsPending(st,@"nope",150),"an unknown attempt is not pending");

 // 5. resume seam: runs once, only after a saved permission, never on replay or re-entry
 CHECK(MYBPendingBegin(st,@"F1",S,D,SC,160),"attempt");
 __block NSMutableDictionary *stRef=st;
 o=Allow(st,perm,@"F1",@"once",161,YES,^{resumed++;MYBPendingFinish(stRef,@"F1",YES,162,^{resumed+=10;});},&g);
 CHECK(o==MYBPendingResumed&&resumed==1,"the continuation ran exactly once; a re-entrant finish did nothing");
 CHECK(Allow(st,perm,@"F1",@"once",163,YES,^{resumed++;},NULL)==MYBPendingNone&&resumed==1,"replaying the same attempt neither saves nor runs again");

 // 6. concurrent distinct attempts: only the finished one is affected
 dispatch_group_t grp=dispatch_group_create();__block int tryAgain=0,none=0;NSMutableDictionary *cs=[NSMutableDictionary dictionary];
 CHECK(MYBPendingBegin(cs,@"G1",S,D,SC,200),"attempt");
 for(int i=0;i<16;i++)dispatch_group_async(grp,dispatch_get_global_queue(0,0),^{MYBPendingOutcome r=MYBPendingFinish(cs,@"G1",YES,201,nil);@synchronized(cs){if(r==MYBPendingTryAgain)tryAgain++;else if(r==MYBPendingNone)none++;}});
 dispatch_group_wait(grp,DISPATCH_TIME_FOREVER);
 CHECK(tryAgain==1&&none==15,"sixteen concurrent finishes: exactly one wins");

 // 7. Always Allow permits later matching attempts; a different destination is not covered
 CHECK(MYBPendingBegin(st,@"H1",S,D,SC,300),"attempt");
 o=Allow(st,perm,@"H1",@"always",301,YES,nil,&g);
 CHECK(o==MYBPendingTryAgain,"always saved");
 CHECK([MYBShieldAllowsScheme(perm,@"appredirect",S,D,SC,YES) isEqual:@"always"]&&[MYBShieldAllowsScheme(perm,@"appredirect",S,D,SC,YES) isEqual:@"always"],"Always Allow permits every later matching attempt");
 CHECK(MYBShieldAllowsScheme(perm,@"appredirect",S,@"com.other.app",SC,YES)==nil,"another destination still asks");


 // 9. How the retry matches and consumes a one-time approval (the retry is a NEW attempt: no attempt id is compared)
 {
  NSString *pr=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",pr.UTF8String,1);NSString *pm=MYBShieldPermissionsFile();Clock(5000000,70000);
  NSMutableDictionary *ps=[NSMutableDictionary dictionary];
  CHECK(MYBShieldAllowsScheme(pm,@"appredirect",S,D,SC,YES)==nil,"first attempt: nothing saved, so it prompts");
  CHECK(MYBPendingBegin(ps,@"P1",S,D,SC,100),"the prompt registers its attempt");
  NSDictionary *g1=nil;CHECK(Allow(ps,pm,@"P1",@"once",101,YES,nil,&g1)==MYBPendingTryAgain&&[g1[@"attempt"] isEqual:@"P1"],"Allow Once saves one retry approval (attempt id kept as a label)");
  CHECK(MYBShieldAllowsScheme(pm,@"appredirect",S,D,SC,NO)!=nil,"a peek (can-it-run check) does not consume it");
  CHECK(MYBShieldAllowsScheme(pm,@"appredirect",@"org.mozilla.ios.Firefox",D,SC,YES)==nil,"another source app cannot consume it");
  CHECK(MYBShieldAllowsScheme(pm,@"appredirect",S,@"com.other.app",SC,YES)==nil,"another destination cannot consume it");
  CHECK(MYBShieldAllowsScheme(pm,@"appredirect",S,D,@"otherscheme",YES)==nil&&MYBShieldAllowsScheme(pm,@"appredirect",S,D,nil,YES)==nil,"another scheme, or an unobservable one, cannot consume it");
  CHECK(MYBShieldAllowsScheme(pm,@"appstore",S,nil,SC,YES)==nil,"another kind cannot consume it");
  CHECK(MYBShieldLiveGrants(pm).count==1,"the failed matches left it untouched");
  // concurrent retries: exactly one wins
  dispatch_group_t cg=dispatch_group_create();__block int won=0,lost=0;NSLock *lk=[NSLock new];
  for(int i=0;i<16;i++)dispatch_group_async(cg,dispatch_get_global_queue(0,0),^{NSString *r=MYBShieldAllowsScheme(pm,@"appredirect",S,D,SC,YES);[lk lock];if(r)won++;else lost++;[lk unlock];});
  dispatch_group_wait(cg,DISPATCH_TIME_FOREVER);
  CHECK(won==1&&lost==15,"sixteen concurrent retries: the approval is consumed exactly once");
  CHECK(MYBShieldAllowsScheme(pm,@"appredirect",S,D,SC,YES)==nil,"a further independent attempt finds nothing and prompts again");
  // expiry
  CHECK(MYBPendingBegin(ps,@"P2",S,D,SC,200),"attempt");CHECK(Allow(ps,pm,@"P2",@"once",201,YES,nil,&g1)==MYBPendingTryAgain,"saved");
  Clock(5000000+MYB_SHIELD_ONCE_SECONDS+1,70000+MYB_SHIELD_ONCE_SECONDS+1);
  CHECK(MYBShieldAllowsScheme(pm,@"appredirect",S,D,SC,YES)==nil,"an expired approval never allows a redirect");
  Clock(5000000,70000);
  // failed consumption write refuses the retry (checked in shield-policy-native: the file is read-only there); here: failed save leaves nothing
  CHECK(MYBPendingBegin(ps,@"P3",S,@"com.example.three",SC,300),"attempt");
  CHECK(Allow(ps,pm,@"P3",@"once",301,NO,nil,&g1)==MYBPendingNotSaved&&MYBShieldAllowsScheme(pm,@"appredirect",S,@"com.example.three",SC,YES)==nil,"a failed save never allows a redirect");
 }
 // 8. bounded table
 NSMutableDictionary *bs=[NSMutableDictionary dictionary];int ok=0;for(int i=0;i<20;i++)if(MYBPendingBegin(bs,[NSString stringWithFormat:@"X%d",i],S,[NSString stringWithFormat:@"com.example.a%d",i],SC,400))ok++;
 CHECK(ok==MYB_PENDING_MAX,"pending attempts are bounded");
 if(failures){fprintf(stderr,"%d failure(s)\n",failures);return 1;}
 printf("Shield pending-attempt tests passed.\n");return 0;}}
