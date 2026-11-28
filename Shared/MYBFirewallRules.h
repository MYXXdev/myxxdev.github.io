#pragma once
// MYbloXX® Call Firewall: the pure rules. General-purpose call blocking, built next to Private Calls and sharing its proven number-matching code
// (MYBPrivateCalls.h: MYBPCKey, MYBPCRecord, MYBPCMerge, MYBPCKeyIsInternational, the region table) but keeping an entirely separate list and switch.
// A number can be private AND listed in the Firewall at once; the two features never share state and either can be on while the other is off.
// No UIKit, no hooks, no file access, no private classes, so this runs in Settings, the incoming-call component and the desktop tests alike.
#import <Foundation/Foundation.h>
#import "MYBPrivateCalls.h"

#define MYB_FW_KEY_SWITCH @"FirewallOn"                    // firewall.plist, OFF until turned on in MYbloXX® Settings
#define MYB_FW_KEY_LOG @"FirewallLog"                       // firewall.plist: per-number records, same shape as a Private Calls record
#define MYB_FW_KEY_ALLOWLIST @"FirewallAllowListMode"       // when YES: only entries whose action is "allow" ring; everything else gets the default action
#define MYB_FW_KEY_DEFAULT_ACTION @"FirewallDefaultAction"  // applied in Allow List Mode to a number that is not on the list at all
#define MYB_FW_KEY_UNKNOWN_ACTION @"FirewallUnknownAction"  // applied to a call with no caller ID at all; empty/nil = no rule
#define MYB_FW_KEY_INTL_BLOCK @"FirewallInternationalOn"
#define MYB_FW_KEY_INTL_ACTION @"FirewallInternationalAction"
#define MYB_FW_KEY_RANGES @"FirewallRanges"                 // array of {prefix: "+234", a: "decline"}
#define MYB_FW_ACTION_ALLOW @"allow"                        // not a block action: always lets the call ring, and is what Allow List Mode looks for
#define MYB_FW_MAX_RANGES 60
// Mikey's own bulk "Known Junk Callers" dataset (Shared/MYBJunkCallers.h, ~1.1M numbers, matched by binary search, never kept here as records) --
// off by default since it is a large aggregated list, not hand-reviewed the way the Call Firewall's own rules are. Consulted only as a last-resort
// fallback, after every one of the rules above has had nothing to say, so an explicit entry, a range, Allow List Mode or International Block always
// takes precedence over it.
#define MYB_FW_KEY_JUNKCALLERS_ON @"FirewallJunkCallersOn"
#define MYB_FW_KEY_JUNKCALLERS_ACTION @"FirewallJunkCallersAction"

// An action string valid for a Firewall record: mute/decline/hangup (MYBPrivateCalls.h) or allow (ring normally; only meaningful in Allow List Mode,
// but kept as a real choice everywhere so a number can be exempted from a blanket rule like International Block without being removed from the list).
static inline NSString *MYBFWNormalizeAction(id action){
 if([action isEqual:MYB_FW_ACTION_ALLOW])return MYB_FW_ACTION_ALLOW;
 if([action isEqual:MYB_PC_ACTION_DECLINE])return MYB_PC_ACTION_DECLINE;
 if([action isEqual:MYB_PC_ACTION_HANGUP])return MYB_PC_ACTION_HANGUP;
 return MYB_PC_ACTION_MUTE;
}
static inline NSString *MYBFWActionName(id action){
 if([action isEqual:MYB_FW_ACTION_ALLOW])return @"Allow";
 return MYBPCActionName(action);
}
// A record is the same shape Private Calls uses ({k,d,a,t,on}), so MYBPCMerge, MYBPCStoreLog and friends all work unchanged on the Firewall's own file.
static inline NSDictionary *MYBFWRecord(NSString *key,NSString *display,NSString *action,BOOL on,double now){
 return [NSDictionary dictionaryWithObjectsAndKeys:key,@"k",display?:@"",@"d",MYBFWNormalizeAction(action),@"a",[NSNumber numberWithDouble:now],@"t",[NSNumber numberWithBool:on],@"on",nil];
}

// A range rule is a plain phone-number prefix ("+234", "+1900", "900"): any key beginning with it (after normalizing to "+") matches. The longest
// matching prefix wins, so a more specific rule (a full area code) can override a broader one (a whole country).
static inline NSString *MYBFWNormalizedPrefix(NSString *prefix){
 if(![prefix isKindOfClass:NSString.class])return nil;
 NSMutableString *digits=[NSMutableString string];
 for(NSUInteger i=0;i<prefix.length;i++){unichar c=[prefix characterAtIndex:i];if(c>='0'&&c<='9')[digits appendFormat:@"%C",c];}
 return digits.length?[@"+" stringByAppendingString:digits]:nil;
}
static inline NSDictionary *MYBFWValidRange(NSString *prefix,NSString *action){
 NSString *norm=MYBFWNormalizedPrefix(prefix);
 if(!norm||norm.length<2||norm.length>16)return nil;
 return [NSDictionary dictionaryWithObjectsAndKeys:norm,@"prefix",MYBFWNormalizeAction(action),@"a",nil];
}
static inline NSDictionary *MYBFWRangeMatch(NSArray *ranges,NSString *key){
 if(![key isKindOfClass:NSString.class]||![key hasPrefix:@"+"]||![ranges isKindOfClass:NSArray.class])return nil;
 NSDictionary *best=nil;NSUInteger bestLen=0;
 for(id r in ranges){
  if(![r isKindOfClass:NSDictionary.class])continue;
  NSString *prefix=[r objectForKey:@"prefix"];
  if(![prefix isKindOfClass:NSString.class]||!prefix.length)continue;
  if([key hasPrefix:prefix]&&prefix.length>bestLen){best=r;bestLen=prefix.length;}
 }
 return best;
}

// ---- the one decision for an incoming call ------------------------------------------------------------------------------------------------
// Order, when the call is not on the list at all: Allow List Mode (everything not explicitly allowed gets the default action) overrides every other
// blanket rule, since "only these numbers ring" is meant to be absolute. Otherwise: no caller ID at all -> the Unknown rule; then a number-range
// match; then International Block. A number explicitly on the list always wins over every blanket rule, "allow" included, so one exception never
// has to wait on the others being configured correctly.
typedef enum { MYBFWNothing = 0, MYBFWDoMute = 1, MYBFWDoDecline = 2, MYBFWDoHangup = 3 } MYBFWDecision;
static inline MYBFWDecision MYBFWFromAction(NSString *action){
 NSString *a=MYBFWNormalizeAction(action);
 if([a isEqual:MYB_FW_ACTION_ALLOW])return MYBFWNothing;
 if([a isEqual:MYB_PC_ACTION_DECLINE])return MYBFWDoDecline;
 if([a isEqual:MYB_PC_ACTION_HANGUP])return MYBFWDoHangup;
 return MYBFWDoMute;
}
static inline MYBFWDecision MYBFWDecide(NSDictionary *settings,NSDictionary *entry,NSString *key,BOOL unknownCaller,
  BOOL switchOn,BOOL incoming,BOOL answeredOrConnected,BOOL ordinaryPhoneCall,BOOL emergency,BOOL alreadyHandled,BOOL otherCallActive){
 if(!switchOn||!incoming||answeredOrConnected||!ordinaryPhoneCall||emergency||alreadyHandled)return MYBFWNothing;
 MYBFWDecision decision=MYBFWNothing;
 BOOL allowListOn=[[settings objectForKey:MYB_FW_KEY_ALLOWLIST] boolValue];
 if(entry){
  decision=MYBFWFromAction([entry objectForKey:@"a"]);           // an explicit entry, "allow" included, always wins
 }else if(allowListOn){
  decision=MYBFWFromAction([settings objectForKey:MYB_FW_KEY_DEFAULT_ACTION]);
 }else{
  if(unknownCaller){
   NSString *unk=[settings objectForKey:MYB_FW_KEY_UNKNOWN_ACTION];
   if([unk isKindOfClass:NSString.class]&&unk.length)decision=MYBFWFromAction(unk);
  }
  if(decision==MYBFWNothing&&key.length){
   NSDictionary *range=MYBFWRangeMatch([settings objectForKey:MYB_FW_KEY_RANGES],key);
   if(range)decision=MYBFWFromAction([range objectForKey:@"a"]);
  }
  if(decision==MYBFWNothing&&[[settings objectForKey:MYB_FW_KEY_INTL_BLOCK] boolValue]&&MYBPCKeyIsInternational(key)){
   NSString *ia=[settings objectForKey:MYB_FW_KEY_INTL_ACTION];
   if([ia isKindOfClass:NSString.class]&&ia.length)decision=MYBFWFromAction(ia);
  }
 }
 if(decision==MYBFWDoHangup&&otherCallActive)decision=MYBFWDoDecline;  // same reasoning as Private Calls: answering would put the other call on hold
 if(decision==MYBFWDoMute&&otherCallActive)decision=MYBFWNothing;      // the call-waiting tone is not the ringtone; muting it does nothing useful
 return decision;
}
