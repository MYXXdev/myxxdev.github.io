// Bridge failure and stale settings: the last good policy is kept but marked stale, the generation always moves on a
// failure (so no one-shot popup token issued under the old policy can be spent), and recovery is reported honestly.
#import <Foundation/Foundation.h>
#import "../Shared/MYBBridgeState.h"
#import "../Shared/MYBPopupState.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){printf("FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static NSDictionary *Answer(NSString *secret,NSArray *exceptions,BOOL popups){return @{@"rules":@{@"Enabled":@YES,@"BlockPopups":@(popups)},@"bridgeSecret":secret,@"siteExceptions":exceptions};}
int main(void){@autoreleasepool{
 NSString *ev=nil;
 NSDictionary *s=MYBBridgeFold(Answer(@"s1",@[],YES),nil,&ev);
 CHECK([ev isEqual:@"bridge_ready"]&&![s[@"stale"] boolValue]&&[s[@"generation"] integerValue]==1&&[s[@"secret"] isEqual:@"s1"],"first answer: ready, generation 1");
 NSDictionary *again=MYBBridgeFold(Answer(@"s1",@[],YES),s,&ev);CHECK([again[@"generation"] integerValue]==1,"an identical answer does not change the generation");
 NSDictionary *ex=MYBBridgeFold(Answer(@"s1",@[@"a.example"],YES),again,&ev);CHECK([ex[@"generation"] integerValue]==2,"a changed exception list changes the generation");
 NSDictionary *sec=MYBBridgeFold(Answer(@"s2",@[@"a.example"],YES),ex,&ev);CHECK([sec[@"generation"] integerValue]==3&&[sec[@"secret"] isEqual:@"s2"],"a new bridge secret changes the generation");
 NSDictionary *off=MYBBridgeFold(Answer(@"s2",@[@"a.example"],NO),sec,&ev);CHECK([off[@"generation"] integerValue]==4&&![off[@"rules"][@"BlockPopups"] boolValue],"a settings change (popups off) changes the generation");
 // failure: stale, last good kept, generation always advances
 NSDictionary *f1=MYBBridgeFold(nil,sec,&ev);
 CHECK([ev isEqual:@"bridge_failed"]&&[f1[@"stale"] boolValue]&&[f1[@"rules"][@"BlockPopups"] boolValue]&&[f1[@"exceptions"] isEqual:@[@"a.example"]]&&[f1[@"secret"] isEqual:@"s2"]&&f1[@"bridgeState"]==nil,"failure keeps the last good policy, marks it stale and reports bridge_failed");
 CHECK([f1[@"generation"] integerValue]==[sec[@"generation"] integerValue]+1,"failure changes the generation");
 NSDictionary *f2=MYBBridgeFold(@[@"not",@"a",@"dictionary"],f1,&ev);CHECK([ev isEqual:@"bridge_failed"]&&[f2[@"generation"] integerValue]==[f1[@"generation"] integerValue]+1&&[f2[@"stale"] boolValue],"a malformed answer is a failure, and every failure moves the generation");
 // a one-shot token issued before the failure cannot be spent after it
 { MYBPopupOps *ops=[MYBPopupOps new];NSUInteger g=[sec[@"generation"] unsignedIntegerValue];[ops rememberAllowedURL:@"https://x.example/" type:5 policy:g];
   CHECK(![ops consumeURL:@"https://x.example/" type:5 policy:[f1[@"generation"] unsignedIntegerValue]],"a token from before the bridge failure is refused afterwards");
   [ops rememberAllowedURL:@"https://x.example/" type:5 policy:g];CHECK([ops consumeURL:@"https://x.example/" type:5 policy:g],"control: the same token is accepted while the policy is unchanged"); }
 // recovery
 NSDictionary *r=MYBBridgeFold(Answer(@"s2",@[@"a.example"],NO),f2,&ev);
 CHECK([ev isEqual:@"bridge_ready"]&&![r[@"stale"] boolValue]&&[r[@"generation"] integerValue]==[f2[@"generation"] integerValue]+1,"recovery clears stale and starts a new generation");
 // failure before any good answer: empty policy, stale, no secret
 NSDictionary *cold=MYBBridgeFold(nil,nil,&ev);CHECK([cold[@"stale"] boolValue]&&[cold[@"rules"] isEqual:@{}]&&[cold[@"secret"] isEqual:@""]&&[cold[@"generation"] integerValue]==1,"cold failure: empty policy, stale, no secret");
 if(failures){printf("%d bridge-state check(s) FAILED\n",failures);return 1;}
 printf("Bridge failure and stale-settings checks passed.\n");
}return 0;}
