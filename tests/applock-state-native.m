// Focused check of Shared/MYBAppLockState.h: unlock bound to one activation, cancel/failure/stale results, device lock mid-prompt, eligibility (GNU runtime friendly).
#import "../Shared/MYBAppLockState.h"
static int fails=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL %s\n",m);fails++;}}while(0)
int main(void){@autoreleasepool{
 MYBLockState s=MYBLockInit();
 CHECK(!MYBLockIsOpen(&s),"starts locked");
 unsigned long t=MYBLockBeginPrompt(&s);CHECK(t!=0,"a prompt starts");
 CHECK(MYBLockBeginPrompt(&s)==0,"a second prompt cannot start while one is showing");
 CHECK(MYBLockFinish(&s,t,1)&&MYBLockIsOpen(&s),"success with the live ticket unlocks");
 CHECK(MYBLockBeginPrompt(&s)==0,"no prompt when already unlocked");
 // cancel and failure leave it locked and allow a retry
 MYBLockActivate(&s);t=MYBLockBeginPrompt(&s);CHECK(!MYBLockFinish(&s,t,0)&&!MYBLockIsOpen(&s),"cancel or failure keeps the cover");
 unsigned long retry=MYBLockBeginPrompt(&s);CHECK(retry!=0,"retry is possible after a failure");
 // stale completion: prompt started, app left and re-entered, old result arrives
 MYBLockActivate(&s);unsigned long old=MYBLockBeginPrompt(&s);MYBLockLeave(&s);MYBLockActivate(&s);
 CHECK(!MYBLockFinish(&s,old,1)&&!MYBLockIsOpen(&s),"a stale success from an earlier visit is ignored");
 unsigned long fresh=MYBLockBeginPrompt(&s);CHECK(fresh!=0&&fresh!=old,"the new visit gets its own ticket");
 CHECK(MYBLockFinish(&s,fresh,1)&&MYBLockIsOpen(&s),"the new visit can unlock");
 // device locks during a prompt
 MYBLockActivate(&s);t=MYBLockBeginPrompt(&s);MYBLockLeave(&s);CHECK(!MYBLockFinish(&s,t,1)&&!MYBLockIsOpen(&s),"device lock during a prompt: late success does not unlock");
 // leaving relocks an open app (default: lock again when leaving)
 MYBLockActivate(&s);t=MYBLockBeginPrompt(&s);MYBLockFinish(&s,t,1);MYBLockLeave(&s);CHECK(!MYBLockIsOpen(&s),"leaving an unlocked app locks it again");
 // rapid switching: many activations, only the last prompt counts
 unsigned long tickets[5];for(int i=0;i<5;i++){MYBLockActivate(&s);tickets[i]=MYBLockBeginPrompt(&s);}
 int opened=0;for(int i=0;i<5;i++)opened+=MYBLockFinish(&s,tickets[i],1);CHECK(opened==1&&MYBLockIsOpen(&s),"rapid switching: only the newest prompt can unlock");
 CHECK(!MYBLockFinish(&s,0,1),"ticket zero never unlocks");
 CHECK(!MYBLockEligible(@"com.apple.Preferences")&&!MYBLockEligible(@"com.apple.mobilephone")&&!MYBLockEligible(@"com.apple.InCallService")&&!MYBLockEligible(@"com.apple.springboard"),"Settings, phone and system UI are never selectable");
 CHECK(!MYBLockEligible(@"org.coolstar.SileoStore")&&!MYBLockEligible(@"com.opa334.Dopamine")&&!MYBLockEligible(@"net.myxxdev.mybloxx"),"recovery and MYbloXX routes are never selectable");
 CHECK(MYBLockEligible(@"com.apple.mobilesafari")&&MYBLockEligible(@"com.burbn.instagram")&&!MYBLockEligible(@"")&&!MYBLockEligible(nil),"ordinary apps are eligible; empty is not");
 if(fails){fprintf(stderr,"%d failed\n",fails);return 1;}puts("applock-state-native ok");return 0;}}
