#import "../Shared/MYBPopupState.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
// Stand-in for a banner view: counts removals so double removal / removal of the wrong banner is visible.
@interface FakeView:NSObject @property(nonatomic,assign) int removed;@end @implementation FakeView @end
int main(void){@autoreleasepool{
 // ---- banner lifetime ----
 MYBBannerSlot *slot=[MYBBannerSlot new];NSUInteger g1=0,g2=0,g3=0;
 FakeView *a=[FakeView new],*b=[FakeView new],*c=[FakeView new];
 CHECK([slot installView:a generation:&g1]==nil,"first banner replaces nothing");
 // timer fires for banner A: it clears and the caller removes it
 CHECK([slot clearIfGeneration:g1]&&slot.view==nil,"timer dismissal clears the slot");
 CHECK(![slot clearIfGeneration:g1],"a second (late) dismissal of the same banner is a no-op");
 // repeated popup after dismissal: the slot holds no stale pointer, a new banner installs cleanly
 id replaced=[slot installView:b generation:&g2];CHECK(replaced==nil&&slot.view==b&&g2>g1,"new banner after dismissal installs; nothing stale is returned");
 // a new popup arrives while B is visible: B is returned for removal, C is current
 replaced=[slot installView:c generation:&g3];CHECK(replaced==b&&slot.view==c,"replacement hands back the old banner exactly once");
 // B's delayed timer / tap fires late: must not clear or remove C
 CHECK(![slot clearIfGeneration:g2]&&slot.view==c,"a delayed dismissal from an older banner cannot clear a newer one");
 CHECK([slot clearIfGeneration:g3]&&slot.view==nil,"the current banner's own dismissal works");
 // many repeated popups, dismissals interleaved with timers
 for(int i=0;i<200;i++){NSUInteger g=0;FakeView *v=[FakeView new];[slot installView:v generation:&g];if(i%3==0)CHECK([slot clearIfGeneration:g],"dismiss");if(i%5==0)[slot clearIfGeneration:g-1];}
 CHECK(YES,"200 repeated installs and mixed dismissals did not crash");
 // the slot owns the view strongly: it stays valid after the creator's reference is gone
 NSUInteger gx=0;@autoreleasepool{[slot installView:[FakeView new] generation:&gx];}
 CHECK(slot.view!=nil&&[slot.view isKindOfClass:FakeView.class],"slot keeps the banner alive (no dangling association)");
 slot.view=nil;
 // ---- one decision per operation ----
 MYBPopupOps *ops=[MYBPopupOps new];NSString *u=@"https://ads.example/x";
 // target=_blank: navigation layer allowed it; the matching createWebView is the same operation
 [ops rememberAllowedURL:u type:0 policy:7];
 CHECK([ops consumeURL:u type:0 policy:7],"navigation allow is handed to the matching createWebView");
 CHECK(![ops consumeURL:u type:0 policy:7],"the token is single use: a second same-URL attempt is a separate operation");
 // three window.open() calls to the same URL: no token ever exists, each is judged separately
 int free=0;for(int i=0;i<3;i++)if([ops consumeURL:u type:-1 policy:7])free++;CHECK(free==0,"repeated same-URL window.open calls are never pre-authorised");
 // a token that nobody consumed does not authorise a later, different kind of attempt (window.open is a different navigation type)
 [ops rememberAllowedURL:u type:0 policy:7];CHECK(![ops consumeURL:u type:-1 policy:7],"a window.open does not consume a link's token");
 CHECK(![ops consumeURL:u type:0 policy:7],"and the mismatch dropped the stale token");
 // different URL
 [ops rememberAllowedURL:u type:0 policy:7];CHECK(![ops consumeURL:@"https://other.example/" type:0 policy:7]&&![ops hasPending],"different URL does not match and clears");
 // policy change between the two callbacks
 [ops rememberAllowedURL:u type:0 policy:7];CHECK(![ops consumeURL:u type:0 policy:8],"a settings/permission change invalidates the decision");
 // navigation / delegate replacement
 [ops rememberAllowedURL:u type:0 policy:7];[ops invalidate];CHECK(![ops consumeURL:u type:0 policy:7]&&![ops hasPending],"invalidate (navigation or delegate change) drops the token");
 // a newer allow replaces an older, unconsumed one
 [ops rememberAllowedURL:@"https://a.example/" type:0 policy:1];[ops rememberAllowedURL:@"https://b.example/" type:0 policy:1];
 CHECK(![ops consumeURL:@"https://a.example/" type:0 policy:1],"only the latest operation's token exists");
 // ---- resuming an allowed popup: only the same operation, once
 {NSString *page=@"https://site.example/a";
  CHECK(MYBPopupReplayCheck(NO,YES,YES,3,3,page,page,5,YES)==MYBReplayOK,"the same page, tab and operation is resumed");
  CHECK(MYBPopupReplayCheck(YES,YES,YES,3,3,page,page,5,YES)==MYBReplayUsed,"a pending popup is resumed at most once");
  CHECK(MYBPopupReplayCheck(NO,NO,NO,3,3,page,page,5,YES)==MYBReplayViewGone,"a closed tab is not resumed");
  CHECK(MYBPopupReplayCheck(NO,YES,NO,3,3,page,page,5,YES)==MYBReplayViewGone,"a tab that is no longer on screen is not resumed");
  CHECK(MYBPopupReplayCheck(NO,YES,YES,3,4,page,page,5,YES)==MYBReplayNavigated,"a navigation or reload since the block ends it");
  CHECK(MYBPopupReplayCheck(NO,YES,YES,3,3,page,@"https://site.example/b",5,YES)==MYBReplayOtherPage,"a different page is never given the old popup");
  CHECK(MYBPopupReplayCheck(NO,YES,YES,3,3,page,nil,5,YES)==MYBReplayOtherPage&&MYBPopupReplayCheck(NO,YES,YES,3,3,nil,nil,5,YES)==MYBReplayOtherPage,"an unknown page is never resumed");
  CHECK(MYBPopupReplayCheck(NO,YES,YES,3,3,page,page,MYB_REPLAY_SECONDS+1,YES)==MYBReplayExpired&&MYBPopupReplayCheck(NO,YES,YES,3,3,page,page,-1,YES)==MYBReplayExpired,"an expired or clock-skewed record is not resumed");
  CHECK(MYBPopupReplayCheck(NO,YES,YES,3,3,page,page,5,NO)==MYBReplayNotReplayable,"a request with a body or a non-GET method is not guessed at");
 }
 if(failures){fprintf(stderr,"%d popup state check(s) FAILED\n",failures);return 1;}
 printf("Popup state checks passed (banner ownership, single-use decisions).\n");
}return 0;}
