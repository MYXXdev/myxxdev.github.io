#pragma once
#import <Foundation/Foundation.h>
// App Control "Preparing App" state. Pure logic (no UI, no I/O) so it can be tested without SpringBoard.
//
// When a selected app comes to the foreground, MYbloXX has to pause its own blocking for that app. The helper does that
// off the main thread and reports back when it has finished (the helper's exit status is the acknowledgement: the proxy
// change was applied and iOS networking was refreshed). This object only decides what a late, stale or failed
// acknowledgement means, so rapid switching, cancelling, locking and helper failure behave predictably.
//
// It does not prevent requests the app makes before that acknowledgement. The app is already running when SpringBoard
// reports it in the foreground, and freezing an app or SpringBoard to wait is deliberately not done.
typedef NS_ENUM(NSInteger,MYBPrepState){MYBPrepIdle=0,MYBPrepPreparing,MYBPrepReady,MYBPrepFailed,MYBPrepCancelled,MYBPrepSuperseded};
@interface MYBAppPrep : NSObject
@property(nonatomic,readonly) MYBPrepState state;
@property(nonatomic,readonly,copy) NSString *app;
@property(nonatomic,readonly) NSUInteger token;
@property(nonatomic,readonly) int failureCode;
@property(nonatomic,readonly) NSTimeInterval limit; // the wait is bounded; after this the state is Failed (code 124)
- (instancetype)initWithLimit:(NSTimeInterval)limit;
// Starts (or restarts) preparation of `app`. Returns the token the matching completion must present.
- (NSUInteger)beginForApp:(NSString *)app now:(NSTimeInterval)now;
// Applies the helper's result. `foreground` is the app that is in front now ("__none__" for Home or a locked device).
// Returns the resulting state; a completion for an old token, or for an app that is no longer in front, changes nothing
// the person sees (Superseded) and never reports a failure for an app they already left.
- (MYBPrepState)completeToken:(NSUInteger)token code:(int)code foreground:(NSString *)foreground;
- (BOOL)expiredAt:(NSTimeInterval)now;      // true while Preparing and the limit has passed
- (MYBPrepState)expireAt:(NSTimeInterval)now; // moves an overdue Preparing to Failed (124)
- (void)cancel;                              // the person chose Cancel: a late acknowledgement is ignored
- (void)reset;
@end
@implementation MYBAppPrep{NSTimeInterval _started;}
- (instancetype)initWithLimit:(NSTimeInterval)limit{if((self=[super init])){_limit=limit>0?limit:10;_app=@"__none__";}return self;}
- (NSUInteger)beginForApp:(NSString *)app now:(NSTimeInterval)now{_token++;_app=[app copy]?:@"__none__";_state=MYBPrepPreparing;_failureCode=0;_started=now;return _token;}
- (MYBPrepState)completeToken:(NSUInteger)token code:(int)code foreground:(NSString *)foreground{
 if(token!=_token||_state!=MYBPrepPreparing)return MYBPrepSuperseded;
 if(![foreground isEqual:_app]){_state=MYBPrepSuperseded;return _state;}
 if(code==0){_state=MYBPrepReady;_failureCode=0;}else{_state=MYBPrepFailed;_failureCode=code;}
 return _state;
}
- (BOOL)expiredAt:(NSTimeInterval)now{return _state==MYBPrepPreparing&&now-_started>_limit;}
- (MYBPrepState)expireAt:(NSTimeInterval)now{if([self expiredAt:now]){_state=MYBPrepFailed;_failureCode=124;}return _state;}
- (void)cancel{if(_state==MYBPrepPreparing)_state=MYBPrepCancelled;}
- (void)reset{_state=MYBPrepIdle;_app=@"__none__";_failureCode=0;}
@end
