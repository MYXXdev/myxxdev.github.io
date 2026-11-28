#pragma once
// State used by the Safari popup guard, kept free of UIKit/WebKit so it is tested natively.
#import <Foundation/Foundation.h>

// ---- banner ownership --------------------------------------------------------------------------------------
// One slot per window. It OWNS the visible banner (strong reference), so nothing can message a freed view, and every
// dismissal path is tied to the generation that created it, so a late timer or tap from an old banner can never
// remove or clear a newer one.
@interface MYBBannerSlot : NSObject
@property(nonatomic,strong) id view;
@property(nonatomic,assign) NSUInteger generation;
// Installs a new banner. Returns the banner it replaced (the caller removes it from the screen) and the new generation.
- (id)installView:(id)view generation:(NSUInteger *)generation;
// Clears the slot only if `generation` is still the current one. YES means the caller owns the removal.
- (BOOL)clearIfGeneration:(NSUInteger)generation;
@end
@implementation MYBBannerSlot
- (id)installView:(id)view generation:(NSUInteger *)generation{
 id old=self.view;self.view=view;self.generation+=1;if(generation)*generation=self.generation;return old;
}
- (BOOL)clearIfGeneration:(NSUInteger)generation{
 if(!self.view||self.generation!=generation)return NO;self.view=nil;return YES;
}
@end

// ---- one decision per operation ------------------------------------------------------------------------------
// WebKit can ask about one new-window operation twice (navigation delegate for a target=_blank link, then the UI
// delegate's createWebView). The navigation layer's ALLOW is carried to that one matching createWebView as a
// single-use token. There is no time window: a token is consumed by the first matching callback, and is dropped by
// any other callback, any navigation on the view, delegate replacement, or any change of the policy generation
// (settings, permissions, exceptions). Separate attempts - including repeated window.open() calls to the same
// address - never match a token, so each is judged (and each consumes its own one-time permission) separately.
@interface MYBPopupOps : NSObject
- (void)rememberAllowedURL:(NSString *)url type:(NSInteger)type policy:(NSUInteger)policy;
- (BOOL)consumeURL:(NSString *)url type:(NSInteger)type policy:(NSUInteger)policy;
- (void)invalidate;
- (BOOL)hasPending;
@end
@implementation MYBPopupOps{NSString *_url;NSInteger _type;NSUInteger _policy;BOOL _pending;}
- (void)rememberAllowedURL:(NSString *)url type:(NSInteger)type policy:(NSUInteger)policy{_url=[url copy];_type=type;_policy=policy;_pending=YES;}
- (BOOL)consumeURL:(NSString *)url type:(NSInteger)type policy:(NSUInteger)policy{
 BOOL match=_pending&&_policy==policy&&_type==type&&[_url isEqualToString:url?:@""];
 _pending=NO;_url=nil;return match;
}
- (void)invalidate{_pending=NO;_url=nil;}
- (BOOL)hasPending{return _pending;}
@end

// ---- resuming an allowed popup --------------------------------------------------------------------------------------
// A blocked target=_blank link is kept so that Allow can open that same window. It is valid only while it is still the
// same operation: not used before, the view alive and on screen, no main-frame navigation or reload since (epoch), still
// the same page, within two minutes, and a plain request (GET without a body). Anything else is NOT replayed; the caller
// then shows the short "tap the original link again" note instead. The decision is pure so it is tested natively.
typedef NS_ENUM(NSInteger,MYBReplayVerdict){MYBReplayOK=0,MYBReplayUsed,MYBReplayViewGone,MYBReplayNavigated,MYBReplayOtherPage,MYBReplayExpired,MYBReplayNotReplayable};
#define MYB_REPLAY_SECONDS 120
static inline MYBReplayVerdict MYBPopupReplayCheck(BOOL used,BOOL viewAlive,BOOL onScreen,NSUInteger epochThen,NSUInteger epochNow,NSString *pageThen,NSString *pageNow,NSTimeInterval age,BOOL plainRequest){
 if(used)return MYBReplayUsed;
 if(!viewAlive||!onScreen)return MYBReplayViewGone;
 if(epochThen!=epochNow)return MYBReplayNavigated;
 if(!pageThen.length||![pageThen isEqualToString:pageNow?:@""])return MYBReplayOtherPage;
 if(age<0||age>MYB_REPLAY_SECONDS)return MYBReplayExpired;
 return plainRequest?MYBReplayOK:MYBReplayNotReplayable;
}

// ---- one permission question per attempt ------------------------------------------------------------------------
// The gate decides whether a blocked new-window attempt may open the permission sheet. It holds NO memory of earlier
// answers: nothing is remembered about a site after a choice, a dismissal, a navigation or a failed presentation, so
// the next independent attempt always asks again (unless a saved Allow or Block permission applies, which is judged
// elsewhere). It only separates three situations:
//   Proceed    no question is open; this attempt opens one
//   Duplicate  another callback of the attempt that is already being asked or was just answered (same WebKit action
//              object, or the same site+target while its question is still open): silently the same attempt
//   Busy       a different attempt arrives while a question is open: it is refused, never stacked or queued
// An open question that never reports back (a sheet torn down by the system) goes stale after two minutes.
typedef NS_ENUM(NSInteger,MYBPromptGateResult){MYBPromptGateProceed=0,MYBPromptGateDuplicate,MYBPromptGateBusy};
#define MYB_PROMPT_STALE_SECONDS 120
@interface MYBPromptGate : NSObject
- (MYBPromptGateResult)beginWithAttempt:(id)attempt fingerprint:(NSString *)fingerprint now:(NSTimeInterval)now;
- (void)finish;
- (BOOL)inFlight;
@end
@implementation MYBPromptGate{BOOL _open;NSString *_fingerprint;NSTimeInterval _started;__weak id _openAttempt;__weak id _lastAttempt;}
- (MYBPromptGateResult)beginWithAttempt:(id)attempt fingerprint:(NSString *)fingerprint now:(NSTimeInterval)now{
 if(_open&&(now<_started||now-_started>MYB_PROMPT_STALE_SECONDS))[self finish]; // an open question nobody answered
 if(_open){
  if((attempt&&attempt==_openAttempt)||[_fingerprint isEqualToString:fingerprint?:@""])return MYBPromptGateDuplicate;
  return MYBPromptGateBusy;
 }
 if(attempt&&attempt==_lastAttempt)return MYBPromptGateDuplicate; // a late repeat callback for an attempt that was just answered
 _open=YES;_fingerprint=[fingerprint copy]?:@"";_started=now;_openAttempt=attempt;return MYBPromptGateProceed;
}
- (void)finish{if(_open)_lastAttempt=_openAttempt;_open=NO;_fingerprint=nil;_openAttempt=nil;}
- (BOOL)inFlight{return _open;}
@end
