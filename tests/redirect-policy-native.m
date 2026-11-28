// Focused check of Shared/MYBRedirectPolicy.h (no object subscripting so it also builds with the GNU runtime).
#import "../Shared/MYBRedirectPolicy.h"
static int fails=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL %s\n",m);fails++;}}while(0)
static BOOL apps(NSString *b){return [b hasPrefix:@"org."]||[b hasPrefix:@"com.google"]||[b hasPrefix:@"com.apple.mobilesafari"]||[b hasPrefix:@"com.apple.Maps"]||[b hasPrefix:@"com.apple.AppStore"]||[b isEqual:@"test.app"];}
int main(void){@autoreleasepool{
 NSDictionary *none=@{};
 // fresh install: store on, other off
 CHECK(MYBRedirectAskAppStore(none)&&!MYBRedirectAskOtherApps(none),"fresh defaults: App Store on, other apps off");
 // legacy effective choices
 NSDictionary *bothOn=@{@"RedirectEnabled":@YES,@"RedirectOtherApps":@YES},*storeOnly=@{@"RedirectEnabled":@YES,@"RedirectOtherApps":@NO},*masterOff=@{@"RedirectEnabled":@NO,@"RedirectOtherApps":@YES},*bothOff=@{@"RedirectEnabled":@NO,@"RedirectOtherApps":@NO};
 CHECK(MYBRedirectAskAppStore(bothOn)&&MYBRedirectAskOtherApps(bothOn),"old both on stays both on");
 CHECK(MYBRedirectAskAppStore(storeOnly)&&!MYBRedirectAskOtherApps(storeOnly),"old App Store on, Other Apps off stays exactly that");
 CHECK(!MYBRedirectAskAppStore(masterOff)&&!MYBRedirectAskOtherApps(masterOff),"old master off: both off (Other Apps was ignored while it was off)");
 CHECK(!MYBRedirectAskAppStore(bothOff)&&!MYBRedirectAskOtherApps(bothOff),"old both off stays off");
 // touching one switch never changes the other
 NSArray *olds=@[none,bothOn,storeOnly,masterOff,bothOff];
 for(NSDictionary *old in olds){
  for(int on=0;on<2;on++){
   NSMutableDictionary *a=[old mutableCopy];BOOL otherBefore=MYBRedirectAskOtherApps(old),storeBefore=MYBRedirectAskAppStore(old);
   MYBRedirectSetAskAppStore(a,on);CHECK(MYBRedirectAskAppStore(a)==(BOOL)on&&MYBRedirectAskOtherApps(a)==otherBefore,"setting App Store leaves other apps as it was");
   NSMutableDictionary *b=[old mutableCopy];MYBRedirectSetAskOtherApps(b,on);CHECK(MYBRedirectAskOtherApps(b)==(BOOL)on&&MYBRedirectAskAppStore(b)==storeBefore,"setting other apps leaves App Store as it was");
   id e1=[a objectForKey:@"RedirectEnabled"],e0=[old objectForKey:@"RedirectEnabled"],o1=[a objectForKey:@"RedirectOtherApps"],o0=[old objectForKey:@"RedirectOtherApps"];
   CHECK((e1==e0||[e1 isEqual:e0])&&(o1==o0||[o1 isEqual:o0]),"older keys are never rewritten");
  }
  NSMutableDictionary *m=[old mutableCopy];BOOL s=MYBRedirectAskAppStore(old),o=MYBRedirectAskOtherApps(old);MYBRedirectMaterialize(m);
  CHECK(MYBRedirectAskAppStore(m)==s&&MYBRedirectAskOtherApps(m)==o,"materialising an upgrade keeps the effective choice");
 }
 { // an explicit new key beats the old ones, a single new key does not drag the other along
  NSDictionary *mixed=@{@"RedirectEnabled":@NO,@"RedirectAskAppStore":@YES};
  CHECK(MYBRedirectAskAppStore(mixed)&&!MYBRedirectAskOtherApps(mixed),"new App Store key wins, other apps still follows the old master");
 }
 // classification: App Store
 NSString *safari=@"com.apple.mobilesafari",*ff=@"org.mozilla.ios.Firefox",*store=@"com.apple.AppStore",*kit=@"com.apple.ios.StoreKitUIService",*yt=@"com.google.ios.youtube";
 BOOL(^isApp)(NSString *)=^BOOL(NSString *b){return apps(b);};
 #define D(s,src,tr,dst,ex) MYBRedirectDecide(s,src,tr,dst,ex,isApp)
 CHECK(D(none,safari,MYBSourceProcess,store,YES)==MYBRedirectAppStore,"an app opening the App Store is covered");
 CHECK(D(none,ff,MYBSourceProcess,kit,YES)==MYBRedirectAppStore,"StoreKit UI service counts as the App Store");
 CHECK(D(none,@"com.apple.springboard",MYBSourceProcess,store,YES)==MYBRedirectNone,"App Store from the Home Screen works normally");
 CHECK(D(none,@"com.apple.Spotlight",MYBSourceProcess,store,YES)==MYBRedirectNone,"Spotlight is system UI");
 CHECK(D(none,safari,MYBSourceNone,store,YES)==MYBRedirectNone,"an unidentified sender is left alone");
 CHECK(D(none,safari,MYBSourceProcess,store,NO)==MYBRedirectNone,"a screen change without an open request is left alone");
 CHECK(D(none,store,MYBSourceProcess,yt,YES)==MYBRedirectNone&&D(bothOn,store,MYBSourceProcess,yt,YES)==MYBRedirectNone,"Open inside the App Store is a normal launch");
 CHECK(D(none,safari,MYBSourceFront,store,YES)==MYBRedirectAppStore,"App Store may use the corroborated app in front");
 CHECK(D(none,@"com.example.notinstalled",MYBSourceProcess,store,YES)==MYBRedirectNone,"a source that is not an installed app is left alone");
 NSDictionary *storeOff=@{@"RedirectAskAppStore":@NO,@"RedirectAskOtherApps":@YES};
 CHECK(D(storeOff,safari,MYBSourceProcess,store,YES)==MYBRedirectNone,"App Store switch off: App Store left alone");
 // classification: other apps
 NSDictionary *linksOn=@{@"RedirectAskAppStore":@NO,@"RedirectAskOtherApps":@YES};
 CHECK(D(linksOn,safari,MYBSourceProcess,yt,YES)==MYBRedirectApp,"verified app-to-app link is covered when the switch is on");
 CHECK(D(linksOn,safari,MYBSourceBroker,yt,YES)==MYBRedirectApp,"LaunchServices open naming the app counts");
 CHECK(D(linksOn,safari,MYBSourceFront,yt,YES)==MYBRedirectNone,"the app that happened to be in front is not enough for other apps");
 CHECK(D(linksOn,safari,MYBSourceNone,yt,YES)==MYBRedirectNone,"a daemon sender is not an app");
 CHECK(D(none,safari,MYBSourceProcess,yt,YES)==MYBRedirectNone,"other apps are off by default");
 CHECK(D(linksOn,safari,MYBSourceProcess,@"com.apple.mobilephone",YES)==MYBRedirectNone&&D(linksOn,safari,MYBSourceProcess,@"com.apple.InCallService",YES)==MYBRedirectNone,"calls are left alone");
 CHECK(D(linksOn,safari,MYBSourceProcess,@"com.apple.Preferences",YES)==MYBRedirectNone&&D(linksOn,@"com.apple.Preferences",MYBSourceProcess,yt,YES)==MYBRedirectNone,"Settings is left alone either way");
 CHECK(D(linksOn,@"com.apple.springboard",MYBSourceProcess,yt,YES)==MYBRedirectNone,"launches from SpringBoard are left alone");
 CHECK(D(linksOn,safari,MYBSourceProcess,@"com.apple.springboard",YES)==MYBRedirectNone,"a move to SpringBoard is never intercepted");
 CHECK(D(linksOn,safari,MYBSourceProcess,@"com.example.notinstalled",YES)==MYBRedirectNone,"a destination that is not an installed app is left alone");
 CHECK(D(linksOn,safari,MYBSourceProcess,safari,YES)==MYBRedirectNone,"moves within one app are never touched");
 // independence in the decision itself
 NSDictionary *both=@{@"RedirectAskAppStore":@YES,@"RedirectAskOtherApps":@YES};
 CHECK(D(both,safari,MYBSourceProcess,store,YES)==MYBRedirectAppStore&&D(both,safari,MYBSourceProcess,yt,YES)==MYBRedirectApp,"both on covers both");
 CHECK(D(masterOff,safari,MYBSourceProcess,store,YES)==MYBRedirectNone&&D(masterOff,safari,MYBSourceProcess,yt,YES)==MYBRedirectNone,"old master off covers nothing");
 CHECK(D(storeOnly,safari,MYBSourceProcess,yt,YES)==MYBRedirectNone&&D(storeOnly,safari,MYBSourceProcess,store,YES)==MYBRedirectAppStore,"old mixed state is not widened");
 // prompt plan
 __block int rate=0;BOOL(^yes)(void)=^BOOL{rate++;return YES;};
 CHECK(MYBRedirectPlanFor(NO,YES,nil,@"k",yes)==MYBPromptLeaveAlone&&rate==0,"locked: leave alone");
 CHECK(MYBRedirectPlanFor(YES,NO,nil,@"k",yes)==MYBPromptUnavailable&&rate==0,"no way to show a sheet: unavailable (request is not declined)");
 CHECK(MYBRedirectPlanFor(YES,YES,@"k",@"k",yes)==MYBPromptSuppressed&&rate==0,"same attempt already being asked: suppressed");
 CHECK(MYBRedirectPlanFor(YES,YES,@"other",@"k",yes)==MYBPromptUnavailable&&rate==0,"a different attempt while a sheet is open is not declined");
 CHECK(MYBRedirectPlanFor(YES,YES,nil,@"k",yes)==MYBPromptShow&&rate==1,"otherwise ask");
 // outcomes
 CHECK(MYBRedirectOutcomeForReason(@"block-this-time")==MYBOutcomeBlocked&&MYBRedirectOutcomeForReason(@"appstore")==MYBOutcomeBlocked,"block this time is a blocked event");
 CHECK(MYBRedirectOutcomeForReason(@"permission-saved-temp")==MYBOutcomeSaved&&MYBRedirectOutcomeForReason(@"allowed-reopen-failed")==MYBOutcomeSaved,"saved permission is distinct");
 CHECK(MYBRedirectOutcomeForReason(@"allowed-released")==MYBOutcomeContinued&&![[MYBRedirectOutcomeTitle(MYBOutcomeContinued) lowercaseString] containsString:@"opened"],"no event claims an open");
 for(NSString *r in @[@"appstore",@"block-this-time",@"allowed-released",@"permission-saved-once",@"prompt-unavailable"])CHECK(![[MYBRedirectReasonText(r) lowercaseString] containsString:@"opened it"],"wording never claims an open");
 CHECK(MYBRedirectKindIsRedirect(@"appstore")&&MYBRedirectKindIsRedirect(@"appredirect")&&!MYBRedirectKindIsRedirect(@"popup")&&!MYBRedirectKindIsRedirect(@"website"),"popups and websites are not redirects");
 // the older combined mapping still reads as before
 CHECK(MYBRedirectProtectionState(storeOnly)==MYBRedirectProtectionAppStoreOnly&&MYBRedirectProtectionState(masterOff)==MYBRedirectProtectionOff,"legacy mapping unchanged");
 if(fails){fprintf(stderr,"%d failures\n",fails);return 1;}printf("redirect policy ok\n");
}return 0;}
