#pragma once
// The decision logic of the one-presentation-flow-per-screen rule (Preferences/MYBDesign.m), kept free of UIKit so the rules are tested natively
// (tests/sheet-flow-native.m). UIKit code only carries out what this says.
//   * One DECISION sheet (confirm / choose / input) is on screen or queued at a time; a second request waits, a duplicate title is ignored.
//   * While a decision is up, STATUS updates (progress / result / message) are held, and only the latest is shown afterwards.
//   * When a decision has gone, the next waiting decision goes first; a held status is shown only when nothing else is waiting.
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,MYBFlowAction){MYBFlowPresentNow=0,MYBFlowQueue,MYBFlowIgnore,MYBFlowShowStatus,MYBFlowHoldStatus,MYBFlowNextDecision,MYBFlowShowHeld,MYBFlowIdle};
@interface MYBSheetFlowModel : NSObject
@property(copy) NSString *active;                      // title of the decision on screen or about to be, nil when none
@property(strong) NSMutableArray<NSString *> *queue;   // titles of decisions waiting, FIFO
@property BOOL held;                                   // a status update is waiting for the decision to leave
- (MYBFlowAction)requestDecision:(NSString *)title;
- (MYBFlowAction)requestStatus;
- (MYBFlowAction)decisionGone;
- (void)dropHeld;
@end
@implementation MYBSheetFlowModel
- (instancetype)init{if((self=[super init]))_queue=[NSMutableArray array];return self;}
- (MYBFlowAction)requestDecision:(NSString *)title{
 title=title?:@"";
 if(title.length&&([self.active isEqual:title]||[self.queue containsObject:title]))return MYBFlowIgnore;
 if(self.active){[self.queue addObject:title];return MYBFlowQueue;}
 self.active=title;return MYBFlowPresentNow;
}
- (MYBFlowAction)requestStatus{if(self.active){self.held=YES;return MYBFlowHoldStatus;}return MYBFlowShowStatus;}
- (MYBFlowAction)decisionGone{
 if(!self.active)return MYBFlowIdle; // a second "gone" for the same sheet changes nothing
 self.active=nil;
 if(self.queue.count){NSString *next=self.queue.firstObject;[self.queue removeObjectAtIndex:0];self.active=next;return MYBFlowNextDecision;}
 if(self.held){self.held=NO;return MYBFlowShowHeld;}
 return MYBFlowIdle;
}
- (void)dropHeld{self.held=NO;}
@end
