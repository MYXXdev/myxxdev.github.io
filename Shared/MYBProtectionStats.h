#pragma once
// Protection Center's two all-time counters: calls blocked, messages blocked. Both live processes (callservicesd for
// calls, imagent for messages) are sandboxed and often cannot write ordinary files, so this reuses the exact same
// proven, sandbox-safe mailbox primitive MYBCallServiceChannel.h already uses for its diagnostics report --
// notify_set_state/notify_get_state, kernel-mediated, no filesystem access needed on either side -- just with its
// own two named counters instead of a compressed text blob, since a running total needs nothing fancier than that.
// Only ever a bare count goes through here: never a number, a name, or anything that identifies which call or
// message was blocked, matching the rest of this project's diagnostics.
//
// The increment is a plain read-then-write, not a compare-and-swap: two calls blocked in the same instant could
// occasionally undercount by one. For an all-time, roughly-how-much-has-this-protected-you display figure, that is
// an acceptable, explicitly-chosen tradeoff -- not something a dashboard needs to be exact to the call.
#import <Foundation/Foundation.h>
#import "MYBCallServiceChannel.h"

#define MYB_PS_CALLS_NAME @"net.myxxdev.mybloxx.ps.calls.%u"
#define MYB_PS_MESSAGES_NAME @"net.myxxdev.mybloxx.ps.messages.%u"

static inline void MYBPSBumpCalls(void){MYBCSCSetStateIn(MYB_PS_CALLS_NAME,0,MYBCSCGetStateIn(MYB_PS_CALLS_NAME,0)+1);}
static inline void MYBPSBumpMessages(void){MYBCSCSetStateIn(MYB_PS_MESSAGES_NAME,0,MYBCSCGetStateIn(MYB_PS_MESSAGES_NAME,0)+1);}
static inline uint64_t MYBPSCallsBlocked(void){return MYBCSCGetStateIn(MYB_PS_CALLS_NAME,0);}
static inline uint64_t MYBPSMessagesBlocked(void){return MYBCSCGetStateIn(MYB_PS_MESSAGES_NAME,0);}
