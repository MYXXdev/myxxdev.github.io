// Delegate proxies that sit in front of a browser's own WKUIDelegate / WKNavigationDelegate. They forward everything
// the host implements, unchanged, and put exactly one decision in front of new-window and navigation callbacks.
// The decisions are injected (gMYBPopupGate / gMYBNavCancel) so the forwarding behaviour can be tested with a fake
// host delegate; the tweak installs the real decisions in its constructor.
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/message.h>
typedef BOOL(*MYBPopupGateFn)(WKWebView *,WKNavigationAction *,int); // YES = allow the new window; layer 1 sync, 2 async
typedef BOOL(*MYBNavCancelFn)(WKWebView *,WKNavigationAction *);     // YES = cancel the navigation
static MYBPopupGateFn gMYBPopupGate=NULL;
static MYBNavCancelFn gMYBNavCancel=NULL;
static void (*gMYBWindowHookSeen)(void)=NULL;
@interface MYBSafariUIDelegate : NSObject <WKUIDelegate>
@property(nonatomic,weak) id target;
@end
@implementation MYBSafariUIDelegate
- (BOOL)respondsToSelector:(SEL)selector{return [super respondsToSelector:selector] || [self.target respondsToSelector:selector];}
- (id)forwardingTargetForSelector:(SEL)selector{return [self.target respondsToSelector:selector]?self.target:[super forwardingTargetForSelector:selector];}
- (WKWebView *)webView:(WKWebView *)view createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)features{
 if(gMYBWindowHookSeen)gMYBWindowHookSeen();
 if(gMYBPopupGate&&!gMYBPopupGate(view,action,1))return nil; // nil: no window is created, so no empty tab is left behind
 id<WKUIDelegate> target=self.target;
 return [target respondsToSelector:_cmd]?[target webView:view createWebViewWithConfiguration:configuration forNavigationAction:action windowFeatures:features]:nil;
}
// WebKit prefers this asynchronous form when the delegate has it. Implemented so that a Safari that only has one
// of the two forms is covered either way; the request is bridged to whichever form the real delegate offers.
- (void)_webView:(WKWebView *)view createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)features completionHandler:(void (^)(WKWebView *))completion{
 if(gMYBWindowHookSeen)gMYBWindowHookSeen();
 if(gMYBPopupGate&&!gMYBPopupGate(view,action,2)){completion(nil);return;}
 id target=self.target;SEL asyncForm=_cmd,syncForm=@selector(webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:);
 if([target respondsToSelector:asyncForm]){((void(*)(id,SEL,id,id,id,id,id))objc_msgSend)(target,asyncForm,view,configuration,action,features,completion);return;}
 if([target respondsToSelector:syncForm]){completion([(id<WKUIDelegate>)target webView:view createWebViewWithConfiguration:configuration forNavigationAction:action windowFeatures:features]);return;}
 completion(nil);
}
@end


@interface MYBSafariDelegate : NSObject <WKNavigationDelegate>
@property(nonatomic,weak) id<WKNavigationDelegate> target;
@end
@implementation MYBSafariDelegate
- (BOOL)respondsToSelector:(SEL)selector{return [super respondsToSelector:selector] || [self.target respondsToSelector:selector];}
- (id)forwardingTargetForSelector:(SEL)selector{return [self.target respondsToSelector:selector]?self.target:[super forwardingTargetForSelector:selector];}
- (void)webView:(WKWebView *)view decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))handler {
 if(gMYBNavCancel&&gMYBNavCancel(view,action)){handler(WKNavigationActionPolicyCancel);return;}
 if([self.target respondsToSelector:_cmd])[self.target webView:view decidePolicyForNavigationAction:action decisionHandler:handler];else handler(WKNavigationActionPolicyAllow);
}
- (void)webView:(WKWebView *)view decidePolicyForNavigationAction:(WKNavigationAction *)action preferences:(WKWebpagePreferences *)preferences decisionHandler:(void (^)(WKNavigationActionPolicy, WKWebpagePreferences *))handler API_AVAILABLE(ios(13.0)) {
 if(gMYBNavCancel&&gMYBNavCancel(view,action)){handler(WKNavigationActionPolicyCancel,preferences);return;}
 if([self.target respondsToSelector:_cmd])[self.target webView:view decidePolicyForNavigationAction:action preferences:preferences decisionHandler:handler];
 else if([self.target respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) [self.target webView:view decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy){handler(policy,preferences);}];
 else handler(WKNavigationActionPolicyAllow,preferences);
}
@end
