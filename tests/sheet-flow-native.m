// The one-presentation-flow rule (Shared/MYBSheetFlowModel.h): status sheets never dismiss or cover a decision, decisions never stack, a repeated
// tap is absorbed, and what was held while a decision was up is shown afterwards. The Legacy/DNS profile paths use this through MYBDesign.m.
#import <Foundation/Foundation.h>
#import "../Shared/MYBSheetFlowModel.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{
 MYBSheetFlowModel *f=[MYBSheetFlowModel new];
 // The reproduced device case: the profile options (Save to Files / Copy Link) are up, then an Apply / progress / success update arrives.
 CHECK([f requestDecision:@"Profile Ready. Settings Did Not Open"]==MYBFlowPresentNow,"the delivery options are presented");
 CHECK([f requestStatus]==MYBFlowHoldStatus&&f.held,"a status update (Applied, progress, success) is held while the options are up");
 CHECK([f requestStatus]==MYBFlowHoldStatus,"a second status update is held too (latest wins, nothing is shown)");
 CHECK([f decisionGone]==MYBFlowShowHeld&&!f.held&&f.active==nil,"after the options have gone the held status is shown, once");
 CHECK([f decisionGone]==MYBFlowIdle,"a repeated gone notification changes nothing");
 CHECK([f requestStatus]==MYBFlowShowStatus,"with no decision up, a status is shown straight away");
 // Decisions never stack and are awaited in order.
 f=[MYBSheetFlowModel new];
 CHECK([f requestDecision:@"Get noXXX"]==MYBFlowPresentNow,"first decision presented");
 CHECK([f requestDecision:@"Get noXXX"]==MYBFlowIgnore,"a repeated tap on the same row is ignored");
 CHECK([f requestDecision:@"Replace a Waiting Profile?"]==MYBFlowQueue&&f.queue.count==1,"a different decision waits instead of stacking");
 CHECK([f requestDecision:@"Replace a Waiting Profile?"]==MYBFlowIgnore&&f.queue.count==1,"and is not queued twice");
 CHECK([f requestStatus]==MYBFlowHoldStatus,"status held behind two decisions");
 CHECK([f decisionGone]==MYBFlowNextDecision&&[f.active isEqual:@"Replace a Waiting Profile?"]&&f.held,"the next decision starts only after the first has gone; the status keeps waiting");
 CHECK([f decisionGone]==MYBFlowShowHeld&&f.queue.count==0,"the held status appears once nothing is waiting");
 // Cancellation returns to a sensible state: cancelling (the sheet goes) leaves nothing active and nothing stuck.
 f=[MYBSheetFlowModel new];[f requestDecision:@"Get DNS"];CHECK([f decisionGone]==MYBFlowIdle&&f.active==nil&&!f.held,"cancel leaves the screen free for the next action");
 CHECK([f requestDecision:@"Get DNS"]==MYBFlowPresentNow,"and the same question can be asked again afterwards");
 // PIN or another flow taking over drops a stale held status.
 f=[MYBSheetFlowModel new];[f requestDecision:@"x"];[f requestStatus];[f dropHeld];CHECK([f decisionGone]==MYBFlowIdle,"a dropped status is never shown later");
 // Prerequisite change then delivery: progress (status) is requested BEFORE the options, the options win, and the later result waits.
 f=[MYBSheetFlowModel new];
 CHECK([f requestStatus]==MYBFlowShowStatus,"prerequisite progress is shown");
 CHECK([f requestDecision:@"Profile Ready. Settings Did Not Open"]==MYBFlowPresentNow,"the options are presented even though a status sheet was showing (it is removed first by the UI)");
 CHECK([f requestStatus]==MYBFlowHoldStatus,"a late success from the prerequisite step cannot cover them");
 if(failures){fprintf(stderr,"%d sheet-flow check(s) FAILED\n",failures);return 1;}
 printf("Sheet flow checks passed.\n");
}return 0;}
