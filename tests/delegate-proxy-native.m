// Delegate forwarding: the proxies in front of a browser's own delegates must (a) put exactly one decision in front of
// each new-window / navigation callback, (b) never call the host when the decision is "block", (c) forward unchanged
// when allowed, and (d) behave for hosts that implement only some of the callbacks. Uses fake host delegates.
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "../Shared/MYBDelegateProxies.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){printf("FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static int gateCalls,gateLayer,navCalls,hookSeen;static BOOL gateAllow=YES,navCancel=NO;
static BOOL Gate(WKWebView *v,WKNavigationAction *a,int layer){(void)v;(void)a;gateCalls++;gateLayer=layer;return gateAllow;}
static BOOL Nav(WKWebView *v,WKNavigationAction *a){(void)v;(void)a;navCalls++;return navCancel;}
static void Hook(void){hookSeen++;}
static id sentinel;
@interface SyncHost:NSObject<WKUIDelegate>@property int created,closed;@end
@implementation SyncHost
-(WKWebView *)webView:(WKWebView *)v createWebViewWithConfiguration:(WKWebViewConfiguration *)c forNavigationAction:(WKNavigationAction *)a windowFeatures:(WKWindowFeatures *)f{(void)v;(void)c;(void)a;(void)f;self.created++;return (WKWebView *)sentinel;}
-(void)webViewDidClose:(WKWebView *)v{(void)v;self.closed++;}
@end
@interface AsyncHost:NSObject @property int created;@end
@implementation AsyncHost
-(void)_webView:(WKWebView *)v createWebViewWithConfiguration:(WKWebViewConfiguration *)c forNavigationAction:(WKNavigationAction *)a windowFeatures:(WKWindowFeatures *)f completionHandler:(void(^)(WKWebView *))h{(void)v;(void)c;(void)a;(void)f;self.created++;h((WKWebView *)sentinel);}
@end
@interface EmptyHost:NSObject<WKUIDelegate> @end
@implementation EmptyHost @end
@interface NavHost:NSObject<WKNavigationDelegate>@property int modern,legacy;@end
@implementation NavHost
-(void)webView:(WKWebView *)v decidePolicyForNavigationAction:(WKNavigationAction *)a preferences:(WKWebpagePreferences *)p decisionHandler:(void(^)(WKNavigationActionPolicy,WKWebpagePreferences *))h{(void)v;(void)a;self.modern++;h(WKNavigationActionPolicyAllow,p);}
@end
@interface LegacyNavHost:NSObject<WKNavigationDelegate>@property int legacy;@end
@implementation LegacyNavHost
-(void)webView:(WKWebView *)v decidePolicyForNavigationAction:(WKNavigationAction *)a decisionHandler:(void(^)(WKNavigationActionPolicy))h{(void)v;(void)a;self.legacy++;h(WKNavigationActionPolicyAllow);}
@end
static void Reset(void){gateCalls=0;gateLayer=0;navCalls=0;hookSeen=0;gateAllow=YES;navCancel=NO;}
int main(void){@autoreleasepool{
 gMYBPopupGate=Gate;gMYBNavCancel=Nav;gMYBWindowHookSeen=Hook;sentinel=[NSObject new];
 WKWebViewConfiguration *cfg=nil;WKWindowFeatures *feat=nil;
 // ---- UI delegate, synchronous form ----
 { SyncHost *host=[SyncHost new];MYBSafariUIDelegate *p=[MYBSafariUIDelegate new];p.target=host;
  Reset();gateAllow=NO;
  CHECK([p webView:nil createWebViewWithConfiguration:cfg forNavigationAction:nil windowFeatures:feat]==nil&&host.created==0,"blocked: no window created and the host is never asked");
  CHECK(gateCalls==1&&gateLayer==1&&hookSeen==1,"blocked: exactly one decision (layer 1), hook observed");
  Reset();
  CHECK([p webView:nil createWebViewWithConfiguration:cfg forNavigationAction:nil windowFeatures:feat]==(WKWebView *)sentinel&&host.created==1&&gateCalls==1,"allowed: forwarded once, host's window returned, one decision");
  CHECK([p respondsToSelector:@selector(webViewDidClose:)]&&![p respondsToSelector:@selector(webViewDidFinishNavigation:)],"selectors the host implements are answered; others are not claimed");
  [(id)p webViewDidClose:nil];CHECK(host.closed==1,"unrelated delegate calls reach the host unchanged");
  EmptyHost *empty=[EmptyHost new];p.target=empty;Reset();
  CHECK([p webView:nil createWebViewWithConfiguration:cfg forNavigationAction:nil windowFeatures:feat]==nil&&gateCalls==1,"host without a create handler: allowed decision yields no window, no crash");
 }
 // ---- UI delegate, asynchronous (private) form ----
 { MYBSafariUIDelegate *p=[MYBSafariUIDelegate new];AsyncHost *async=[AsyncHost new];SyncHost *sync=[SyncHost new];
  __block int done;__block id got;
  void(^run)(void)=^{done=0;got=nil;[p _webView:nil createWebViewWithConfiguration:cfg forNavigationAction:nil windowFeatures:feat completionHandler:^(WKWebView *w){done++;got=w;}];};
  p.target=async;Reset();gateAllow=NO;run();CHECK(done==1&&got==nil&&async.created==0&&gateLayer==2&&gateCalls==1,"async blocked: completion(nil) exactly once, host not asked");
  Reset();run();CHECK(done==1&&got==sentinel&&async.created==1&&gateCalls==1,"async allowed: forwarded to the host's async form once");
  p.target=sync;Reset();run();CHECK(done==1&&got==sentinel&&sync.created==1&&gateCalls==1,"async allowed, host has only the sync form: bridged, one decision");
  p.target=[EmptyHost new];Reset();run();CHECK(done==1&&got==nil&&gateCalls==1,"async allowed, host has neither: completion(nil) exactly once");
 }
 // ---- navigation delegate ----
 { NavHost *host=[NavHost new];MYBSafariDelegate *p=[MYBSafariDelegate new];p.target=host;
  __block int done;__block WKNavigationActionPolicy policy;
  Reset();navCancel=YES;done=0;[p webView:nil decidePolicyForNavigationAction:nil preferences:nil decisionHandler:^(WKNavigationActionPolicy x,WKWebpagePreferences *w){(void)w;done++;policy=x;}];
  CHECK(done==1&&policy==WKNavigationActionPolicyCancel&&host.modern==0&&navCalls==1,"cancelled: handler called once with Cancel, host not asked");
  Reset();done=0;[p webView:nil decidePolicyForNavigationAction:nil preferences:nil decisionHandler:^(WKNavigationActionPolicy x,WKWebpagePreferences *w){(void)w;done++;policy=x;}];
  CHECK(done==1&&policy==WKNavigationActionPolicyAllow&&host.modern==1&&navCalls==1,"allowed: forwarded once, one decision");
  LegacyNavHost *legacy=[LegacyNavHost new];p.target=legacy;Reset();done=0;[p webView:nil decidePolicyForNavigationAction:nil preferences:nil decisionHandler:^(WKNavigationActionPolicy x,WKWebpagePreferences *w){(void)w;done++;policy=x;}];
  CHECK(done==1&&policy==WKNavigationActionPolicyAllow&&legacy.legacy==1,"host with only the legacy form is bridged");
  p.target=nil;Reset();done=0;[p webView:nil decidePolicyForNavigationAction:nil preferences:nil decisionHandler:^(WKNavigationActionPolicy x,WKWebpagePreferences *w){(void)w;done++;policy=x;}];
  CHECK(done==1&&policy==WKNavigationActionPolicyAllow,"host without any policy method: allowed");
  Reset();navCancel=YES;done=0;[p webView:nil decidePolicyForNavigationAction:nil decisionHandler:^(WKNavigationActionPolicy x){done++;policy=x;}];CHECK(done==1&&policy==WKNavigationActionPolicyCancel,"legacy-signature entry also cancels once");
 }
 if(failures){printf("%d delegate-proxy check(s) FAILED\n",failures);return 1;}
 printf("Delegate proxy checks passed (one decision per callback, forwarding, async bridging, partial hosts).\n");
}return 0;}
