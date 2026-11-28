// App Control "Preparing App" decisions: acknowledgement, stale results, rapid switching, cancel, failure, bounded wait.
#import <Foundation/Foundation.h>
#import "../Shared/MYBAppPrep.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){printf("FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{
 MYBAppPrep *p=[[MYBAppPrep alloc] initWithLimit:10];
 CHECK(p.state==MYBPrepIdle,"starts idle");
 NSUInteger t=[p beginForApp:@"com.example.a" now:100];
 CHECK(p.state==MYBPrepPreparing&&[p.app isEqual:@"com.example.a"],"begin enters Preparing for that app");
 CHECK([p completeToken:t code:0 foreground:@"com.example.a"]==MYBPrepReady,"helper success while still in front: Ready");
 CHECK([p completeToken:t code:0 foreground:@"com.example.a"]==MYBPrepSuperseded,"a second acknowledgement for the same token changes nothing");
 // helper failure while still in front is reported with its code
 t=[p beginForApp:@"com.example.a" now:200];
 CHECK([p completeToken:t code:73 foreground:@"com.example.a"]==MYBPrepFailed&&p.failureCode==73,"helper failure in front: Failed with the helper's code");
 // failure for an app the person already left is never shown
 t=[p beginForApp:@"com.example.a" now:300];
 CHECK([p completeToken:t code:73 foreground:@"__none__"]==MYBPrepSuperseded,"failure after leaving the app is not reported");
 // rapid switching: only the newest token counts
 NSUInteger a=[p beginForApp:@"com.example.a" now:400],b=[p beginForApp:@"com.example.b" now:401];
 CHECK([p completeToken:a code:0 foreground:@"com.example.b"]==MYBPrepSuperseded,"stale token from the first app is ignored");
 CHECK(p.state==MYBPrepPreparing,"the newer preparation is still waiting after a stale result");
 CHECK([p completeToken:b code:0 foreground:@"com.example.b"]==MYBPrepReady,"the newest token completes");
 // cancel: a late acknowledgement is ignored
 t=[p beginForApp:@"com.example.a" now:500];[p cancel];
 CHECK(p.state==MYBPrepCancelled&&[p completeToken:t code:0 foreground:@"com.example.a"]==MYBPrepSuperseded&&p.state==MYBPrepCancelled,"cancel holds against a late acknowledgement");
 // device locked or Home before the acknowledgement
 t=[p beginForApp:@"com.example.a" now:600];
 CHECK([p completeToken:t code:0 foreground:@"__none__"]==MYBPrepSuperseded,"lock or Home before acknowledgement supersedes it");
 // bounded wait
 t=[p beginForApp:@"com.example.a" now:700];
 CHECK(![p expiredAt:709.9]&&[p expireAt:709.9]==MYBPrepPreparing,"not expired inside the limit");
 CHECK([p expiredAt:710.5]&&[p expireAt:710.5]==MYBPrepFailed&&p.failureCode==124,"overdue preparation fails with timeout (124), it does not wait forever");
 CHECK([p completeToken:t code:0 foreground:@"com.example.a"]==MYBPrepSuperseded,"an acknowledgement after the timeout does not resurrect it");
 // retry gets a new token
 NSUInteger r=[p beginForApp:@"com.example.a" now:800];CHECK(r>t,"retry uses a new token");
 CHECK([p expireAt:900]==MYBPrepFailed,"expire on a never-answered retry");
 [p reset];CHECK(p.state==MYBPrepIdle,"reset returns to idle");
 if(failures){printf("%d failure(s)\n",failures);return 1;}
 printf("App Control preparation logic OK\n");return 0;}}
