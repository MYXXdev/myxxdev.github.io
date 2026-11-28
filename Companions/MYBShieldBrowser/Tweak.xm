// MYbloXX Shield, browser component.
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#import "../../Shared/MYBLoopback.h"
#import "../../Shared/MYBBrowserPolicy.h"
#import "../../Shared/MYBVersion.h"
#import "../../Shared/MYBBridgeState.h"
static NSDictionary *rules;
static NSDictionary *bridgeState;
static NSString *bridgeSecret;
static NSArray *siteExceptions;
static NSTimeInterval bridgeTime;
static NSUInteger policyGeneration; // bumped whenever the settings, exceptions or bridge identity change
static void event(NSString *phase){
 static dispatch_queue_t queue;static dispatch_once_t once;dispatch_once(&once,^{queue=dispatch_queue_create("net.myxxdev.mybloxx.browser-events",DISPATCH_QUEUE_SERIAL);});NSString *app=NSBundle.mainBundle.bundleIdentifier?:@"";
 dispatch_async(queue,^{static NSString *last;static NSTimeInterval time;if([phase isEqual:last]&&NSDate.timeIntervalSinceReferenceDate-time<2)return;last=phase;time=NSDate.timeIntervalSinceReferenceDate;NSString *path=[NSString stringWithFormat:@"/mybloxx-browser-event?app=%@&phase=%@&ver=%s",app,phase,MYB_COMPONENT_VERSION];MYBLoopbackGET(MYB_BRIDGE_PORT,path);});
}
static NSString *hostBundle(void){return NSBundle.mainBundle.bundleIdentifier?:@"";}
static BOOL bridgeStale; // the last answer failed: rules/exceptions below are the last good ones, not current
static NSDictionary *bridgeCache;
static NSDictionary *refreshBridge(void){
 if(NSDate.timeIntervalSinceReferenceDate-bridgeTime<2)return bridgeState?:@{};
 NSData *data=MYBLoopbackGET(MYB_BRIDGE_PORT,@"/mybloxx-browser-config");id decoded=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;bridgeTime=NSDate.timeIntervalSinceReferenceDate;
 NSString *name=nil;bridgeCache=MYBBridgeFold(decoded,bridgeCache,&name);
 bridgeState=bridgeCache[@"bridgeState"];rules=bridgeCache[@"rules"];siteExceptions=bridgeCache[@"exceptions"];bridgeSecret=[bridgeCache[@"secret"] length]?bridgeCache[@"secret"]:nil;
 policyGeneration=[bridgeCache[@"generation"] unsignedIntegerValue];bridgeStale=[bridgeCache[@"stale"] boolValue];event(name);
 return bridgeState?:@{};
}
static void reloadRules(void){bridgeTime=0;refreshBridge();}
static BOOL domainMatches(NSString *host,NSArray *list){
 for(id item in list)if([item isKindOfClass:NSString.class] && ([host isEqualToString:item] || [host hasSuffix:[@"." stringByAppendingString:item]]))return YES;
 return NO;
}
// Custom Shield rules. A website exception (permanent or unexpired temporary) for the destination domain wins over
// them, exactly as it wins over the network filter; popup permissions never do.
static BOOL shouldBlock(NSURL *url){
 if(!MYBBrowserSupports(hostBundle(),@"page"))return NO; // browser website rules always apply; there is no switch for them
 NSString *host=url.host.lowercaseString?:@"";
 if(domainMatches(host,rules[@"Allowed"]?:@[])||domainMatches(host,siteExceptions?:@[]))return NO;
 if(domainMatches(host,rules[@"Blocked"]?:@[]))return YES;
 for(id item in rules[@"URLs"])if([item isKindOfClass:NSString.class] && [(NSString *)item length] && [url.absoluteString hasPrefix:item])return YES;
 return NO;
}
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <dlfcn.h>
static bool timeExpired(JSContextRef context,void *unused){(void)context;(void)unused;return true;}
static BOOL pacBlocks(NSURL *url){
 if(![@[@"http",@"https"] containsObject:url.scheme.lowercaseString]||url.absoluteString.length>16384)return NO;
 NSDictionary *pac=refreshBridge()[@"pac"];if(![pac[@"active"] boolValue])return NO;NSString *script=[pac[@"script"] isKindOfClass:NSString.class]?pac[@"script"]:nil;if(!script.length)return NO;
 typedef void(*SetLimit)(JSContextGroupRef,double,bool (*)(JSContextRef,void *),void *);static SetLimit limit=NULL;static dispatch_once_t once;dispatch_once(&once,^{limit=(SetLimit)dlsym(RTLD_DEFAULT,"JSContextGroupSetExecutionTimeLimit");});if(!limit){event(@"js_unavailable");return NO;}
 static JSContext *context;static NSString *cachedScript;
 if(![cachedScript isEqual:script]){context=nil;cachedScript=nil;JSContext *candidate=[JSContext new];limit(JSContextGetGroup(candidate.JSGlobalContextRef),.04,timeExpired,NULL);
 [candidate evaluateScript:@"function dnsDomainIs(h,d){return h.slice(-d.length)===d;} function shExpMatch(s,p){var r='^';for(var i=0;i<p.length;i++){var c=p.charAt(i);r+=c==='*'?'.*':c==='?'?'.':/[\\^$+.[\\]{}()|]/.test(c)?'\\\\'+c:c;}return new RegExp(r+'$').test(s);} function isPlainHostName(h){return h.indexOf('.')<0;}"];
 [candidate evaluateScript:script];if(candidate.exception||![candidate[@"FindProxyForURL"] isObject])return NO;context=candidate;cachedScript=script;}
 context.exception=nil;limit(JSContextGetGroup(context.JSGlobalContextRef),.04,timeExpired,NULL);JSValue *value=[context[@"FindProxyForURL"] callWithArguments:@[[url.scheme.lowercaseString isEqual:@"https"]?[NSString stringWithFormat:@"https://%@/",url.host]:url.absoluteString,url.host.lowercaseString?:@""]];if(context.exception){context=nil;cachedScript=nil;event(@"js_error");return NO;}NSString *route=[[value toString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];return [route isEqual:@"PROXY 127.0.0.1:8021"]||[route isEqual:@"PROXY 127.0.0.1:8788"]||[route isEqual:@"PROXY 8.8.8.8:53"];
}
#import "../../Shared/MYBShield.h"
#import "../../Shared/MYBShieldTheme.h"
#import "../../Shared/MYBShieldSheet.h"
#import "../../Shared/MYBPopupState.h"
#import "../../Shared/MYBDelegateProxies.h"

// ---- local bridge -----------------------------------------------------------------------------
static BOOL localNotice(NSURL *url){return [url.host isEqual:@"127.0.0.1"]&&url.port.integerValue==MYB_BRIDGE_PORT&&[url.path hasPrefix:@"/mybloxx-"];}
static BOOL blockURL(NSURL *url){if(localNotice(url))return NO;refreshBridge();if(shouldBlock(url)){event(@"blocked_rule");return YES;}if(pacBlocks(url)){event(@"blocked_pac");return YES;}return NO;}
// Mutating bridge calls are POST + bridge header + the per-launch secret handed out by the config route.
static NSDictionary *shieldCall(NSString *route,NSDictionary<NSString *,NSString *> *params){
 if(!bridgeSecret.length)return nil;NSURLComponents *c=[NSURLComponents new];NSMutableArray *items=[NSMutableArray array];
 for(NSString *k in params)if(params[k].length)[items addObject:[NSURLQueryItem queryItemWithName:k value:params[k]]];c.queryItems=items;
 NSData *data=MYBLoopbackRequest(MYB_BRIDGE_PORT,@"POST",[route stringByAppendingFormat:@"?%@",c.percentEncodedQuery?:@""],bridgeSecret);
 id decoded=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;return [decoded isKindOfClass:NSDictionary.class]?decoded:nil;
}

// ---- pending website retries --------------------------------------------------------------------
// A blocked navigation is remembered here (in this process) so "Allow" can reopen exactly that request.
// Only plain GET navigations are replayed; anything with a body, or any non-GET method, is not guessed at.
@interface MYBPendingOp:NSObject
@property(nonatomic,weak) WKWebView *view;@property(nonatomic,copy) NSURLRequest *request;@property(nonatomic) NSTimeInterval created;@property(nonatomic) BOOL used;
@end
@implementation MYBPendingOp @end
static NSMutableDictionary<NSString *,MYBPendingOp *> *pendingOps;
static BOOL replayable(NSURLRequest *request){return (!request.HTTPMethod.length||[request.HTTPMethod isEqual:@"GET"])&&!request.HTTPBody&&!request.HTTPBodyStream&&[@[@"http",@"https"] containsObject:request.URL.scheme.lowercaseString];}
static NSString *registerOp(WKWebView *view,NSURLRequest *request){
 if(!replayable(request))return nil;if(!pendingOps)pendingOps=[NSMutableDictionary dictionary];NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
 for(NSString *k in pendingOps.allKeys){MYBPendingOp *o=pendingOps[k];if(now-o.created>600||!o.view||o.used)[pendingOps removeObjectForKey:k];}
 while(pendingOps.count>=16){NSString *oldest=nil;for(NSString *k in pendingOps)if(!oldest||pendingOps[k].created<pendingOps[oldest].created)oldest=k;[pendingOps removeObjectForKey:oldest];}
 uint8_t bytes[8];arc4random_buf(bytes,sizeof(bytes));NSMutableString *ident=[NSMutableString string];for(int i=0;i<8;i++)[ident appendFormat:@"%02x",bytes[i]];
 MYBPendingOp *op=[MYBPendingOp new];op.view=view;op.request=[request copy];op.created=now;pendingOps[ident]=op;return ident;
}
static NSURL *noticeURL(NSURL *blocked,NSURLRequest *request,WKWebView *view){
 NSString *op=request?registerOp(view,request):nil;
 NSURLComponents *url=[NSURLComponents componentsWithString:[NSString stringWithFormat:@"http://127.0.0.1:%d/mybloxx-blocked",MYB_BRIDGE_PORT]];
 NSMutableArray *q=[@[[NSURLQueryItem queryItemWithName:@"host" value:blocked.host?:@"This website"],[NSURLQueryItem queryItemWithName:@"url" value:blocked.absoluteString?:@""],[NSURLQueryItem queryItemWithName:@"reason" value:shouldBlock(blocked)?@"custom":@"pac"],[NSURLQueryItem queryItemWithName:@"app" value:NSBundle.mainBundle.bundleIdentifier?:@""]] mutableCopy];
 if(op){[q addObject:[NSURLQueryItem queryItemWithName:@"op" value:op]];[q addObject:[NSURLQueryItem queryItemWithName:@"replay" value:@"get"]];}
 url.queryItems=q;return url.URL;
}
// mybloxx-retry://<op> is posted by the MYbloXX blocked page after an exception was applied. It is honoured
// only from that page, only once, only within ten minutes, only for the view that was blocked.
static BOOL handleRetry(WKWebView *view,NSURL *url){
 if(![url.scheme isEqual:@"mybloxx-retry"])return NO;NSString *ident=url.host.lowercaseString;
 dispatch_async(dispatch_get_main_queue(),^{
  MYBPendingOp *op=ident.length?pendingOps[ident]:nil;
  if(!op||op.used||op.view!=view||!localNotice(view.URL)||NSDate.timeIntervalSinceReferenceDate-op.created>600)return;
  op.used=YES;reloadRules(); // the PAC/exception list changed: re-read it before judging the replay
  if(!blockURL(op.request.URL))[view loadRequest:op.request];
 });
 return YES;
}

// ---- native "Popup blocked" notice -------------------------------------------------------------
static char bannerKey,opsKey,uiProxyKey,navProxyKey,epochKey;
// ---- resumable popups ---------------------------------------------------------------------------------------
// When a target=_blank link is blocked, the original navigation action is kept so that, once the user allows it, the
// same window can be opened for that same page. It is a one-shot record, valid only for the page, tab and view that
// produced it, for two minutes, and never for script-created windows (window.open): those lose their opener, name and
// features if re-created, so they are NOT replayed and the user is asked to tap the original link again instead.
@interface MYBPendingPopup:NSObject
@property(nonatomic,weak) WKWebView *view;@property(nonatomic,strong) WKNavigationAction *action;@property(nonatomic,copy) NSString *page;
@property(nonatomic) NSUInteger epoch;@property(nonatomic) NSTimeInterval created;@property(nonatomic) BOOL used;
@end
@implementation MYBPendingPopup @end
static NSUInteger viewEpoch(WKWebView *view){return [objc_getAssociatedObject(view,&epochKey) unsignedIntegerValue];}
static void bumpEpoch(WKWebView *view){objc_setAssociatedObject(view,&epochKey,@(viewEpoch(view)+1),OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
static BOOL gReplaying; // true only while an allowed popup is being re-opened: no new prompt may start from inside it
static MYBPopupOps *peekOps(WKWebView *view){return objc_getAssociatedObject(view,&opsKey);}
static MYBPopupOps *opsFor(WKWebView *view){MYBPopupOps *ops=peekOps(view);if(!ops){ops=[MYBPopupOps new];objc_setAssociatedObject(view,&opsKey,ops,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}return ops;}
static void invalidateOps(WKWebView *view){[peekOps(view) invalidate];bumpEpoch(view);}
static UIViewController *topController(UIWindow *window){UIViewController *c=window.rootViewController;while(c.presentedViewController)c=c.presentedViewController;return c;}
static void showBanner(WKWebView *anchor,NSString *title,NSString *detail,BOOL good,NSString *actionTitle,void(^action)(void)){
 UIWindow *window=anchor.window;if(!window)return;
 MYBBannerSlot *slot=objc_getAssociatedObject(window,&bannerKey);if(!slot){slot=[MYBBannerSlot new];objc_setAssociatedObject(window,&bannerKey,slot,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
 __block NSUInteger generation=0;
 UIView *card=[UIView new];card.translatesAutoresizingMaskIntoConstraints=NO;card.backgroundColor=[MYBShieldPanel() colorWithAlphaComponent:.97];card.layer.cornerRadius=MYBShieldCardRadius;card.layer.cornerCurve=kCACornerCurveContinuous;
 card.layer.borderWidth=.5;card.layer.borderColor=MYBShieldHairline().CGColor;card.layer.shadowColor=UIColor.blackColor.CGColor;card.layer.shadowOpacity=.35;card.layer.shadowRadius=18;card.layer.shadowOffset=CGSizeMake(0,6);
 UIColor *tone=good?MYBShieldPositive():MYBShieldDanger();
 UIView *tile=[UIView new];tile.translatesAutoresizingMaskIntoConstraints=NO;tile.backgroundColor=[tone colorWithAlphaComponent:.13];tile.layer.cornerRadius=12;tile.layer.cornerCurve=kCACornerCurveContinuous;tile.layer.borderWidth=.5;tile.layer.borderColor=[tone colorWithAlphaComponent:.32].CGColor;
 UIImageView *icon=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:good?@"checkmark.shield.fill":@"xmark.shield.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold]]];icon.translatesAutoresizingMaskIntoConstraints=NO;icon.tintColor=tone;[tile addSubview:icon];
 UILabel *heading=[UILabel new];heading.text=title;heading.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]];heading.textColor=UIColor.whiteColor;heading.numberOfLines=2;heading.adjustsFontForContentSizeCategory=YES;
 UILabel *sub=[UILabel new];sub.text=detail;sub.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular]];sub.textColor=MYBShieldMuted();sub.numberOfLines=3;sub.lineBreakMode=NSLineBreakByTruncatingMiddle;sub.adjustsFontForContentSizeCategory=YES;
 UIStackView *text=[[UIStackView alloc] initWithArrangedSubviews:@[heading,sub]];text.axis=UILayoutConstraintAxisVertical;text.spacing=2;
 UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[tile,text]];row.translatesAutoresizingMaskIntoConstraints=NO;row.axis=UILayoutConstraintAxisHorizontal;row.spacing=12;row.alignment=UIStackViewAlignmentCenter;
 if(actionTitle.length&&action){UIButtonConfiguration *config=[UIButtonConfiguration plainButtonConfiguration];config.contentInsets=NSDirectionalEdgeInsetsMake(12,10,12,6);config.baseForegroundColor=MYBShieldAccent();UIButton *button=[UIButton buttonWithConfiguration:config primaryAction:nil];[button setTitle:actionTitle forState:UIControlStateNormal];button.titleLabel.font=[UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold]];[button setTitleColor:MYBShieldAccent() forState:UIControlStateNormal];[button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];[button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];button.accessibilityLabel=[actionTitle stringByAppendingString:@" for blocked popup"];
  [button addAction:[UIAction actionWithHandler:^(UIAction *){if([slot clearIfGeneration:generation])[card removeFromSuperview];action();}] forControlEvents:UIControlEventTouchUpInside];[row addArrangedSubview:button];}
 [card addSubview:row];UIView *replaced=[slot installView:card generation:&generation];[replaced removeFromSuperview];[window addSubview:card];
 CGRect area=[anchor convertRect:anchor.bounds toView:window];
 [NSLayoutConstraint activateConstraints:@[
  [tile.widthAnchor constraintEqualToConstant:34],[tile.heightAnchor constraintEqualToConstant:34],[icon.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],[icon.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
  [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],[row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],[row.topAnchor constraintEqualToAnchor:card.topAnchor constant:10],[row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-10],
  [card.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],[card.widthAnchor constraintLessThanOrEqualToConstant:520],[card.leadingAnchor constraintGreaterThanOrEqualToAnchor:window.safeAreaLayoutGuide.leadingAnchor constant:12],[card.trailingAnchor constraintLessThanOrEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-12],
  [card.bottomAnchor constraintEqualToAnchor:window.topAnchor constant:MAX(CGRectGetMaxY(area)-12,120)]]];
 NSLayoutConstraint *wide=[card.widthAnchor constraintEqualToConstant:520];wide.priority=UILayoutPriorityDefaultHigh;wide.active=YES;
 card.isAccessibilityElement=!(actionTitle.length&&action);card.accessibilityLabel=[NSString stringWithFormat:@"%@. %@",title,detail];
 BOOL still=UIAccessibilityIsReduceMotionEnabled();if(!still){card.alpha=0;card.transform=CGAffineTransformMakeTranslation(0,12);[UIView animateWithDuration:.22 animations:^{card.alpha=1;card.transform=CGAffineTransformIdentity;}];}
 UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,card.accessibilityLabel);
 // Dismissal is bound to this banner's generation: a late timer cannot remove (or clear the slot of) a newer banner.
 __weak MYBBannerSlot *weakSlot=slot;__weak UIView *weakCard=card;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((good?3.5:7.0)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  MYBBannerSlot *owner=weakSlot;UIView *c=weakCard;if(!owner||!c||![owner clearIfGeneration:generation])return;
  if(still){[c removeFromSuperview];return;}[UIView animateWithDuration:.2 animations:^{c.alpha=0;} completion:^(BOOL){[c removeFromSuperview];}];});
}
static BOOL replayPendingPopup(MYBPendingPopup *pending){
 WKWebView *view=pending.view;NSURLRequest *request=pending.action.request;BOOL was=pending.used;pending.used=YES; // one attempt, whatever the outcome
 if(MYBPopupReplayCheck(was,view!=nil,view.window!=nil,pending.epoch,view?viewEpoch(view):0,pending.page,view.URL.absoluteString,NSDate.timeIntervalSinceReferenceDate-pending.created,replayable(request))!=MYBReplayOK)return NO;
 id<WKUIDelegate> ui=view.UIDelegate;SEL create=@selector(webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:);
 if(![ui respondsToSelector:create])return NO;
 reloadRules(); // the permission was just saved: judge the replay against the current grants
 gReplaying=YES;WKWebView *created=nil;
 @try{created=[ui webView:view createWebViewWithConfiguration:[view.configuration copy] forNavigationAction:pending.action windowFeatures:[[WKWindowFeatures alloc] init]];}@finally{gReplaying=NO;}
 if(!created)return NO; // the policy (or the browser) declined: nothing is opened, and a one-time grant that was not consumed is still there
 [created loadRequest:request];return YES;
}
static MYBPromptGate *promptGate; // one open permission question at a time; remembers nothing after it is answered
static MYBPromptGate *gate(void){if(!promptGate)promptGate=[MYBPromptGate new];return promptGate;}
// Shown directly when a popup is blocked. Returns NO when it could not be presented (the app is not active, no window, or
// another sheet is already up) so the caller can fall back to the quiet banner; a prompt never stacks on another.
// YES also covers "handled without a question": a duplicate callback of the open attempt, or a second attempt while a
// question is open (that one is refused, never stacked and never allowed).
// Choices: Allow Once, Allow for 15 Minutes, Always Allow, Always Block (saved, revocable in Permissions) and Block This Time,
// which saves nothing. Dismissing the sheet is Block This Time. No outcome leaves any state behind that could stop the next
// independent attempt from asking.
static BOOL presentPopupSheet(WKWebView *view,NSString *source,NSString *dest,NSString *reason,MYBPendingPopup *pending,id attempt){
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive||!view.window)return NO;
 UIViewController *top=topController(view.window);if(!top||top.presentedViewController||top.isBeingDismissed)return NO;
 MYBPromptGateResult gateResult=[gate() beginWithAttempt:attempt fingerprint:[NSString stringWithFormat:@"%@>%@",source?:@"",dest?:@""] now:NSDate.timeIntervalSinceReferenceDate];
 if(gateResult==MYBPromptGateDuplicate){event(@"prompt_duplicate");return YES;}
 if(gateResult==MYBPromptGateBusy){event(@"prompt_busy");return YES;} // refused: already judged, counted in Recent activity, never queued behind the open question
 BOOL known=MYBShieldHost(source)!=nil;
 NSString *what=dest.length?[NSString stringWithFormat:@"%@ tried to open %@.",source.length?source:@"This page",dest]:[NSString stringWithFormat:@"%@ tried to open a new window.",source.length?source:@"This page"];
 NSString *message=[NSString stringWithFormat:@"%@\n%@%@",what,MYBShieldReasonText(reason),known?[NSString stringWithFormat:@"\n\nAllowing popups from %@ does not allow the websites those windows open. Those still follow your blocking rules.",source]:@"\n\nThis page can’t be identified, so a popup permission can’t be saved."];
 MYBShieldSheet *sheet=[MYBShieldSheet new];sheet.heading=@"Popup blocked";sheet.message=message;sheet.dismissOnBackdrop=YES;
 NSMutableArray *facts=[NSMutableArray arrayWithObject:@[@"Page",source.length?source:@"This page"]];if(dest.length)[facts addObject:@[@"Opening",dest]];
 sheet.facts=facts;
 NSMutableArray *actions=[NSMutableArray array];__block BOOL granted=NO;
 if(known){
  for(NSArray *entry in @[@[@"Allow Once",@"once"],@[@"Allow for 15 Minutes",@"temp"],@[@"Always Allow",@"always"],@[@"Always Block",@"block"]]){
   NSString *mode=entry[1];__block BOOL saved=NO;
   MYBShieldAction *a=[MYBShieldAction title:entry[0] detail:nil style:MYBShieldActionSecondary handler:^{NSDictionary *r=shieldCall(@"/mybloxx-shield-grant",@{@"kind":@"popup",@"source":source,@"mode":mode});saved=[r[@"ok"] boolValue];if(saved&&![mode isEqual:@"block"])granted=YES;}];
   // Success has no confirmation step: the sheet closes and the popup is resumed (or the inline note appears). Only a failure shows a message.
   a.result=^NSDictionary *{return saved?nil:@{@"ok":@NO,@"title":@"Couldn’t save the permission",@"message":@"Nothing was changed. Try again."};};
   [actions addObject:a];
  }
  ((MYBShieldAction *)actions.firstObject).style=MYBShieldActionPrimary;
 }
 [actions addObject:[MYBShieldAction title:@"Block This Time" detail:nil style:MYBShieldActionCancel handler:nil]]; // saves nothing
 sheet.actions=actions;
 __weak WKWebView *weakView=view;
 sheet.onGone=^{
  [gate() finish]; // after every outcome, dismissal and failure: the next attempt asks again
  WKWebView *v=weakView;if(!granted)return;
  BOOL resumed=pending&&replayPendingPopup(pending);
  if(!resumed&&v)showBanner(v,@"Allowed",@"Tap the original link again.",YES,nil,nil);
  if(resumed)event(@"popup_resumed");
 };
 BOOL shown=[MYBShieldSheet present:sheet from:top completion:^(BOOL ok){if(!ok){[gate() finish];}}];
 if(!shown)[gate() finish]; // presentation failed: nothing is left open
 return shown;
}
static void showPopupOptions(WKWebView *view,NSString *source,NSString *dest,NSString *reason,MYBPendingPopup *pending,id attempt){
 if(!presentPopupSheet(view,source,dest,reason,pending,attempt))event(@"sheet_unavailable");
}
// A popup that a saved Always Block refused: no question; the quiet notice is always shown.
static void noticeSavedBlock(WKWebView *view,NSString *source,NSString *dest){
 if(gReplaying)return;
 dispatch_async(dispatch_get_main_queue(),^{
  NSString *detail=dest.length?[NSString stringWithFormat:@"%@ → %@",source.length?source:@"This page",dest]:[NSString stringWithFormat:@"%@ is set to Always Block",source.length?source:@"This page"];
  showBanner(view,MYBShieldTitle(@"popup"),detail,NO,nil,nil);
 });
}
static void noticeBlockedPopup(WKWebView *view,NSString *source,NSString *dest,NSString *reason,MYBPendingPopup *pending,id attempt){
 if(gReplaying)return; // a replay that is refused again is silent: the user already chose
 dispatch_async(dispatch_get_main_queue(),^{
  if(presentPopupSheet(view,source,dest,reason,pending,attempt))return; // asked, or recognised as the same attempt / refused while a question is open
  // The sheet could not be shown (another sheet is up, the app is inactive or locked): the quiet banner, never a second sheet.
  NSString *detail=dest.length?[NSString stringWithFormat:@"%@ → %@",source.length?source:@"This page",dest]:[NSString stringWithFormat:@"%@ tried to open a new window",source.length?source:@"This page"];
  showBanner(view,MYBShieldTitle(@"popup"),detail,NO,@"Options",^{showPopupOptions(view,source,dest,reason,pending,attempt);});
 });
}

// ---- popup policy (both interception layers share it) -------------------------------------------
// Layer 1: decidePolicyForNavigationAction with targetFrame==nil (target=_blank links, WebKit asks this first).
// Layer 2: WKUIDelegate createWebView (window.open() and script-created windows; no navigation action is sent for the source view).
// One operation is judged once: the navigation layer's ALLOW is handed to the matching createWebView as a single-use
// token (never a URL/time cache), so a one-time permission is consumed once and the user is never asked twice.
static int userGesture(WKNavigationAction *action){
 @try{if([action respondsToSelector:NSSelectorFromString(@"_isUserInitiated")])return [[action valueForKey:@"_isUserInitiated"] boolValue]?1:0;}@catch(NSException *e){}
 return -1; // not exposed: Standard then cannot tell, and does not treat "unknown" as "unwanted"
}
// One judgement of one new-window attempt: policy verdict, then (when blocked) a one-time/timed/standing permission
// for the source website, then the notice. Nothing here is cached by URL or time.
static BOOL popupDecide(WKWebView *view,WKNavigationAction *action,int layerKind,NSString **kind){
 NSURL *dest=action.request.URL;
 BOOL http=[@[@"http",@"https"] containsObject:dest.scheme.lowercaseString];
 BOOL destBlocked=http&&blockURL(dest);
 MYBPopupVerdict verdict=MYBShieldPopupVerdict(rules,userGesture(action),destBlocked);
 if(verdict==MYBPopupAllow){*kind=@"policy-allow";return YES;}
 NSString *source=view.URL.host.lowercaseString;if(!source.length)source=action.sourceFrame.request.URL.host.lowercaseString;source=MYBShieldHost(source)?:@"";
 NSString *destHost=http?(MYBShieldHost(dest.host)?:@""):@"";
 NSString *reason=verdict==MYBPopupBlockStrict?@"popup-strict":verdict==MYBPopupBlockNoGesture?@"popup-nogesture":@"popup-destination";
 NSDictionary *answer=shieldCall(@"/mybloxx-shield-check",@{@"kind":@"popup",@"source":source,@"dest":destHost,@"reason":reason}); // consumes a one-time grant; records the attempt if refused
 if([answer[@"allowed"] boolValue]){*kind=@"permission";event(@"permission_consumed");return YES;}
 if([answer[@"blocked"] boolValue]){*kind=@"saved-block";event(@"popup_saved_block");noticeSavedBlock(view,source,destHost);return NO;} // Always Block: refused without asking
 *kind=@"block";event(@"popup_blocked");
 MYBPendingPopup *pending=nil;
 if(layerKind==0&&!gReplaying&&replayable(action.request)){pending=[MYBPendingPopup new];pending.view=view;pending.action=action;pending.page=view.URL.absoluteString;pending.epoch=viewEpoch(view);pending.created=NSDate.timeIntervalSinceReferenceDate;}
 noticeBlockedPopup(view,source,destHost,reason,pending,action);return NO;
}
// fromNavigation: the navigation delegate's new-window callback (target=_blank). Otherwise the UI delegate's
// createWebView (the callback for target=_blank AND window.open). For target=_blank WebKit makes both calls for one
// operation; the first one's ALLOW is handed to the second as a single-use token, so the operation is judged once.
// Callback ordering and navigation types are recorded (no URLs, tokens or secrets: layer, navigation type, frame kind,
// gesture flag, verdict and host names only) so the real iOS behaviour can be read from the bridge's popupTrace.
static void traceCallback(NSString *layer,WKWebView *view,WKNavigationAction *action,NSString *result){
 static NSTimeInterval windowStart;static int count;NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
 if(now-windowStart>10){windowStart=now;count=0;}if(++count>30)return;
 NSString *(^h)(NSString *)=^NSString *(NSString *host){return MYBShieldHost(host.lowercaseString)?:@"";};
 NSString *tf=action.targetFrame==nil?@"nil":action.targetFrame.mainFrame?@"main":@"sub",*sf=action.sourceFrame==nil?@"nil":action.sourceFrame.mainFrame?@"main":@"sub";
 NSString *path=[NSString stringWithFormat:@"/mybloxx-browser-event?app=%@&phase=popup_trace&layer=%@&type=%ld&tf=%@&sf=%@&gest=%d&result=%@&src=%@&dst=%@&ver=%s",hostBundle(),layer,(long)action.navigationType,tf,sf,userGesture(action),result,h(view.URL.host),h(action.request.URL.host),MYB_COMPONENT_VERSION];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{MYBLoopbackGET(MYB_BRIDGE_PORT,path);});
}
// layer: 0 navigation-policy (target=_blank), 1 public createWebView, 2 private async createWebView. Which of them
// WebKit really calls on a given iOS, and in what order, is recorded in the trace rather than assumed.
static BOOL popupAllowed(WKWebView *view,WKNavigationAction *action,int layerKind){
 if(!MYBBrowserSupports(hostBundle(),@"popups"))return YES;
 BOOL fromNavigation=layerKind==0;NSString *layer=layerKind==0?@"nav":layerKind==1?@"create":@"create-async";
 refreshBridge();if(![rules[@"BlockPopups"] boolValue]){invalidateOps(view);event(@"shield_off");traceCallback(layer,view,action,@"shield-off");return YES;}
 NSString *url=action.request.URL.absoluteString?:@"";NSInteger type=action.navigationType;MYBPopupOps *ops=opsFor(view);
 if(!fromNavigation&&[ops consumeURL:url type:type policy:policyGeneration]){traceCallback(layer,view,action,@"token");return YES;}
 NSString *kind=@"block";BOOL allowed=popupDecide(view,action,layerKind,&kind);
 if(fromNavigation&&allowed)[ops rememberAllowedURL:url type:type policy:policyGeneration];else [ops invalidate];
 if(allowed&&[kind isEqual:@"policy-allow"])event(@"popup_allowed");
 traceCallback(layer,view,action,allowed?kind:@"block");
 return allowed;
}

// The delegate proxies live in Shared/MYBDelegateProxies.h (testable without a device); the decisions are injected below.
static void windowHookSeen(void){event(@"window_hook_seen");}
// ---- navigation ------------------------------------------------------------------------------
static BOOL cancelNavigation(WKWebView *view,WKNavigationAction *action){
 NSURL *url=action.request.URL;if(handleRetry(view,url))return YES;
 if(action.targetFrame==nil){ // a new-window navigation (target=_blank): popup policy only; the new window's own navigation is judged on its own
  event(@"navigation_seen");
  if(!objc_getAssociatedObject(view,&uiProxyKey))event(@"host_unsupported"); // this view has no UI delegate: window.open() cannot reach our hook here
  return !popupAllowed(view,action,0);
 }
 BOOL top=action.targetFrame.mainFrame;if(!top)return shouldBlock(url);
 invalidateOps(view); // a main-frame navigation ends any pending hand-offevent(@"navigation_seen");
 if(!blockURL(url))return NO;
 NSURLRequest *request=action.request;dispatch_async(dispatch_get_main_queue(),^{[view loadRequest:[NSURLRequest requestWithURL:noticeURL(url,request,view)]];});return YES;
}
%hook WKWebView
- (void)setNavigationDelegate:(id<WKNavigationDelegate>)delegate {
 if(!delegate || [delegate isKindOfClass:MYBSafariDelegate.class]){%orig;return;}
 invalidateOps(self);MYBSafariDelegate *proxy=[MYBSafariDelegate new];proxy.target=delegate;
 objc_setAssociatedObject(self,&navProxyKey,proxy,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 %orig(proxy);
}
- (void)setUIDelegate:(id<WKUIDelegate>)delegate {
 if(!delegate || [delegate isKindOfClass:MYBSafariUIDelegate.class]){%orig;return;}
 invalidateOps(self);MYBSafariUIDelegate *proxy=[MYBSafariUIDelegate new];proxy.target=delegate;
 objc_setAssociatedObject(self,&uiProxyKey,proxy,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 %orig(proxy);
}
- (WKNavigation *)loadRequest:(NSURLRequest *)request {
 if(!gReplaying)bumpEpoch(self);event(@"navigation_seen");if(blockURL(request.URL)){event(@"redirected");return %orig([NSURLRequest requestWithURL:noticeURL(request.URL,request,self)]);}return %orig;
}
%end
%group MYBLegacyRequest
%hook WKWebView
- (WKNavigation *)_loadRequest:(NSURLRequest *)request shouldOpenExternalURLs:(BOOL)allow {
 event(@"navigation_seen");if(blockURL(request.URL)){event(@"redirected");return %orig([NSURLRequest requestWithURL:noticeURL(request.URL,request,self)],NO);}return %orig;
}
%end
%end
%group MYBPolicyRequest
%hook WKWebView
- (WKNavigation *)_loadRequest:(NSURLRequest *)request shouldOpenExternalURLsPolicy:(NSInteger)policy {
 event(@"navigation_seen");if(blockURL(request.URL)){event(@"redirected");return %orig([NSURLRequest requestWithURL:noticeURL(request.URL,request,self)],0);}return %orig;
}
%end
%end
%ctor {
 if(!MYBBrowserInjects(hostBundle()))return; // the injection filter in MYBShieldBrowser.plist lists exactly these browsers
 gMYBPopupGate=popupAllowed;gMYBNavCancel=cancelNavigation;gMYBWindowHookSeen=windowHookSeen;
 event(@"loaded");dispatch_async(dispatch_get_main_queue(),^{reloadRules();});int token=0;
 notify_register_dispatch("net.myxxdev.mybloxx.safariguard.changed",&token,dispatch_get_main_queue(),^(int unused){(void)unused;reloadRules();});
 %init;
 if(class_getInstanceMethod(WKWebView.class,NSSelectorFromString(@"_loadRequest:shouldOpenExternalURLs:")))%init(MYBLegacyRequest);
 if(class_getInstanceMethod(WKWebView.class,NSSelectorFromString(@"_loadRequest:shouldOpenExternalURLsPolicy:")))%init(MYBPolicyRequest);
}
