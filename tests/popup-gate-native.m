#import <Foundation/Foundation.h>
#import "../Shared/MYBPopupState.h"
// The permission question gate: one question per attempt, no memory after an answer, nothing stacked.
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{
 MYBPromptGate *g=[MYBPromptGate new];NSTimeInterval t=1000;
 id a1=[NSObject new],a2=[NSObject new],a3=[NSObject new];
 CHECK([g beginWithAttempt:a1 fingerprint:@"s>d" now:t]==MYBPromptGateProceed&&g.inFlight,"first attempt asks");
 // 4. duplicate callbacks of one attempt produce one prompt
 CHECK([g beginWithAttempt:a1 fingerprint:@"s>d" now:t]==MYBPromptGateDuplicate,"the same WebKit action object is the same attempt");
 CHECK([g beginWithAttempt:a2 fingerprint:@"s>d" now:t+.01]==MYBPromptGateDuplicate,"the second delegate layer's callback for the same site and target is the same attempt");
 // 9. rapid different attempt while open: refused, never stacked
 CHECK([g beginWithAttempt:a3 fingerprint:@"s>other" now:t+.02]==MYBPromptGateBusy,"a different attempt while a question is open is refused, not stacked");
 // 1. Block This Time then the same link again asks again
 [g finish];CHECK(!g.inFlight,"an outcome closes the question");
 CHECK([g beginWithAttempt:[NSObject new] fingerprint:@"s>d" now:t+5]==MYBPromptGateProceed,"Block This Time: the same URL asked again is a new attempt and asks");
 // 2. dismissal then retry asks again (finish is the dismissal path)
 [g finish];CHECK([g beginWithAttempt:[NSObject new] fingerprint:@"s>d" now:t+6]==MYBPromptGateProceed,"dismissing the sheet: the retry asks");
 // late repeat callback for an attempt that was just answered is not a new question
 id late=[NSObject new];[g finish];CHECK([g beginWithAttempt:late fingerprint:@"x>y" now:t+7]==MYBPromptGateProceed,"fresh attempt asks");[g finish];
 CHECK([g beginWithAttempt:late fingerprint:@"x>y" now:t+7.1]==MYBPromptGateDuplicate,"a late repeat of an attempt that was just answered does not ask twice");
 CHECK([g beginWithAttempt:[NSObject new] fingerprint:@"x>y" now:t+8]==MYBPromptGateProceed,"a later independent attempt to the same URL asks");
 // 8. a question nobody answered (sheet torn down, failed presentation without finish) cannot stay stuck
 CHECK([g beginWithAttempt:[NSObject new] fingerprint:@"x>y" now:t+8.5]==MYBPromptGateDuplicate,"still open: same attempt");
 CHECK([g beginWithAttempt:[NSObject new] fingerprint:@"z>w" now:t+8+MYB_PROMPT_STALE_SECONDS+1]==MYBPromptGateProceed,"a stale open question is cleared and the next attempt asks");
 [g finish];
 // clock moving backwards cannot pin the gate shut
 [g beginWithAttempt:[NSObject new] fingerprint:@"m>n" now:t+500];CHECK([g beginWithAttempt:[NSObject new] fingerprint:@"o>p" now:t]==MYBPromptGateProceed,"a clock that moved back clears the open question");
 // 9. rapid attempts: exactly one question open at any time
 [g finish];int opened=0;for(int i=0;i<20;i++)if([g beginWithAttempt:[NSObject new] fingerprint:[NSString stringWithFormat:@"p>%d",i] now:t+1000+i*.001]==MYBPromptGateProceed)opened++;
 CHECK(opened==1,"twenty rapid different attempts open exactly one question");
 if(failures){fprintf(stderr,"%d popup gate check(s) FAILED\n",failures);return 1;}
 printf("Popup permission gate checks passed.\n");
}return 0;}
