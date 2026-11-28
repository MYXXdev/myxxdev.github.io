#pragma once
#import <Foundation/Foundation.h>
// The pending App Redirect / App Store attempt that a Shield prompt is about.
//
// WHAT CAN AND CANNOT BE RESUMED. The interception point is SBMainWorkspace -_canExecuteTransitionRequest:forExecution:. Shield ends the
// attempt there with -declineWithReason:. A declined SBMainWorkspaceTransitionRequest is finished; SpringBoard offers no continuation to run it
// later, and re-opening the URL from SpringBoard would be a NEW attempt with a different originator (the source app would be lost, which is what
// the permission is bound to). The Shield prompt therefore passes a resume block that opens the same URL again (only when iOS handed over the URL); without a URL the person sees "Allowed. Try again." and
// taps the link again. That tap is a new attempt: it is let through only because source, destination and scheme match the saved one-time permission (MYBShield.h), which it then consumes. The resume seam below exists so that, if a continuation is
// ever verified on a device, it runs at most once, only after a saved permission, only for the same source/destination/scheme.
//
// State machine (each attempt id moves forward only):  pending -> allowed (saved) | failed (not saved) | cancelled | stale (older than the window)
//                                                       allowed -> resumed (only when a resume block exists and ran)
// A second finish for the same id, or a finish for an unknown id, does nothing and reports MYBPendingNone.
typedef NS_ENUM(NSInteger,MYBPendingOutcome){
 MYBPendingNone=0,          // unknown, already finished, or cancelled: nothing happens, nothing is written
 MYBPendingTryAgain,        // saved; the original attempt cannot be resumed here -> "Allowed. Try again."
 MYBPendingResumed,         // saved; the resume block ran exactly once
 MYBPendingNotSaved,        // the save failed: nothing allowed, nothing resumed
 MYBPendingStale            // too old: nothing allowed
};
#define MYB_PENDING_WINDOW 120.0
#define MYB_PENDING_MAX 8
static inline NSMutableDictionary *MYBPendingStore(void){static NSMutableDictionary *s;static dispatch_once_t o;dispatch_once(&o,^{s=[NSMutableDictionary dictionary];});return s;}
static inline NSString *MYBPendingKey(NSString *source,NSString *dest,NSString *scheme){return [NSString stringWithFormat:@"%@|%@|%@",source?:@"",dest?:@"",scheme?:@""];}
// Registers an attempt. Returns NO (and registers nothing) when the same source/destination/scheme is already pending: a concurrent duplicate
// shares the one prompt instead of creating a second grantable attempt. Old entries are dropped; the table is bounded.
static inline BOOL MYBPendingBegin(NSMutableDictionary *store,NSString *attempt,NSString *source,NSString *dest,NSString *scheme,double now){
 if(!attempt.length||!source.length)return NO;
 @synchronized(store){
  for(NSString *k in [store allKeys]){NSDictionary *e=store[k];if(now-[e[@"t"] doubleValue]>MYB_PENDING_WINDOW*2||[e[@"state"] isEqual:@"done"])[store removeObjectForKey:k];}
  NSString *key=MYBPendingKey(source,dest,scheme);
  for(NSDictionary *e in store.allValues)if([e[@"key"] isEqual:key]&&[e[@"state"] isEqual:@"pending"])return NO;
  if(store.count>=MYB_PENDING_MAX||store[attempt])return NO;
  store[attempt]=[@{@"key":key,@"t":@(now),@"state":@"pending",@"source":source,@"dest":dest?:@"",@"scheme":scheme?:@""} mutableCopy];
  return YES;
 }
}
// Pending AND still inside the window: checked BEFORE a permission is written, so a stale attempt never saves anything.
static inline BOOL MYBPendingIsPending(NSMutableDictionary *store,NSString *attempt,double now){@synchronized(store){NSDictionary *e=store[attempt];double age=now-[e[@"t"] doubleValue];return [e[@"state"] isEqual:@"pending"]&&age>=0&&age<=MYB_PENDING_WINDOW;}}
// Ends the attempt without allowing anything (prompt dismissed, screen locked, the person chose nothing).
static inline void MYBPendingCancel(NSMutableDictionary *store,NSString *attempt){@synchronized(store){NSMutableDictionary *e=store[attempt];if([e[@"state"] isEqual:@"pending"])e[@"state"]=@"done";}}
// saved: whether the permission was written AND read back. resume: optional continuation, run at most once and only after a saved permission.
static inline MYBPendingOutcome MYBPendingFinish(NSMutableDictionary *store,NSString *attempt,BOOL saved,double now,dispatch_block_t resume){
 dispatch_block_t run=nil;MYBPendingOutcome out=MYBPendingNone;
 @synchronized(store){
  NSMutableDictionary *e=store[attempt];if(![e[@"state"] isEqual:@"pending"])return MYBPendingNone;
  e[@"state"]=@"done"; // claimed before anything else runs: a second finish, or a resume that re-enters, finds it finished
  double age=now-[e[@"t"] doubleValue];
  if(age<0||age>MYB_PENDING_WINDOW)out=MYBPendingStale;
  else if(!saved)out=MYBPendingNotSaved;
  else if(resume){out=MYBPendingResumed;run=resume;}
  else out=MYBPendingTryAgain;
 }
 if(run)run();
 return out;
}
static inline NSString *MYBPendingMessage(MYBPendingOutcome o,NSString *from,NSString *to,NSString *duration){
 switch(o){
  case MYBPendingTryAgain:return [NSString stringWithFormat:@"Allowed. Try again. %@ may open %@ %@. Return to %@ and tap the link again: the original tap could not be resumed, so nothing has opened yet.",from,to,duration,from];
  case MYBPendingResumed:return [NSString stringWithFormat:@"Allowed. The request was passed on so %@ can open %@ %@. If it does not open, tap the link again.",from,to,duration];
  case MYBPendingStale:return @"This request expired. Nothing was allowed. Tap the link again to be asked again.";
  case MYBPendingNotSaved:return @"The permission could not be saved. Nothing was allowed.";
  default:return @"Nothing was allowed.";
 }
}
