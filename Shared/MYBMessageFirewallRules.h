#pragma once
// MYbloXX® Message Firewall: the pure rules. Blocks a text by its sender's identifier (a phone number, normalized the exact same proven way Private
// Calls and the Call Firewall already do, or an iMessage/email handle compared as trimmed lowercase text) or by a plain keyword/phrase appearing
// anywhere in its body. No UIKit, no hooks, no file access, no private classes, so the exact same code runs in Settings, the message component and
// the desktop tests. Its own file and switch: a sender or a word can be blocked for messages without touching the Call Firewall or Private Calls at all.
#import <Foundation/Foundation.h>
#import "MYBPrivateCalls.h"

#define MYB_MF_KEY_SWITCH @"MessageFirewallOn"           // msgfirewall.plist, OFF until turned on in Settings
#define MYB_MF_KEY_SENDERS @"MessageFirewallSenders"     // array of {k,d,t,on} records, same shape Private Calls uses minus the action
#define MYB_MF_KEY_KEYWORDS @"MessageFirewallKeywords"   // array of {k,d,t,on} records; k is the lowercased, whitespace-collapsed keyword/phrase
#define MYB_MF_MAX_KEYWORDS 200

// A record for this file: {k: key, d: display text, t: seconds since 1970, on: BOOL}. No action -- a message is only ever blocked or not -- but the
// shape stays compatible with MYBPCMerge/MYBPCRecordValid/MYBPCEffective (none of which require the 'a' field), so the exact same proven
// locked-read-merge-write-verify cycle Private Calls and the Call Firewall use is reused here unchanged.
static inline NSDictionary *MYBMFRecord(NSString *key,NSString *display,BOOL on,double now){
 return [NSDictionary dictionaryWithObjectsAndKeys:key,@"k",display?:@"",@"d",[NSNumber numberWithDouble:now],@"t",[NSNumber numberWithBool:on],@"on",nil];
}
// A sender identifier key: a phone number normalizes exactly the way Private Calls/the Call Firewall already do (MYBPCKey); anything else (an
// iMessage handle, an email address) is compared as trimmed, lowercased text, prefixed so it can never collide with a phone key.
static inline NSString *MYBMFSenderKey(NSString *raw,NSString *region){
 if(![raw isKindOfClass:NSString.class])return nil;
 NSString *trimmed=[raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(!trimmed.length)return nil;
 NSString *phone=MYBPCKey(trimmed,region);
 if(phone)return phone;
 if(trimmed.length>120)return nil;
 return [@"h:" stringByAppendingString:trimmed.lowercaseString];
}
static inline NSString *MYBMFDisplaySender(NSString *key,NSString *region){
 if([key hasPrefix:@"h:"])return [key substringFromIndex:2];
 return MYBPCFormat(key,region);
}
// A keyword key: trimmed, lowercased, inner whitespace collapsed to single spaces, so "  Hello   There " and "hello there" are the same rule.
static inline NSString *MYBMFKeywordKey(NSString *raw){
 if(![raw isKindOfClass:NSString.class])return nil;
 NSString *trimmed=[raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(!trimmed.length||trimmed.length>80)return nil;
 NSArray *words=[trimmed componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 NSMutableArray *kept=[NSMutableArray array];
 for(NSString *w in words)if(w.length)[kept addObject:w];
 if(!kept.count)return nil;
 return [[kept componentsJoinedByString:@" "] lowercaseString];
}
// Whether a message's plain text contains a keyword, case-insensitively, as a substring -- not a whole-word requirement, so "spam" also catches
// "spammer". For an auto-delete feature a near-miss costs far less than a missed match, so the broader direction is the safer one.
static inline BOOL MYBMFTextMatches(NSString *plainText,NSArray<NSString *> *keywords){
 if(![plainText isKindOfClass:NSString.class]||!plainText.length||!keywords.count)return NO;
 NSString *low=plainText.lowercaseString;
 for(NSString *k in keywords)if(k.length&&[low rangeOfString:k].location!=NSNotFound)return YES;
 return NO;
}
// The one decision for an incoming text: blocked when the switch is on and either one of the sender's own identifier forms is on the senders list,
// or its text matches a keyword. senderKeys: every identifier form the message carries for its sender, already normalized -- any one matching is enough.
static inline BOOL MYBMFShouldBlock(BOOL switchOn,NSArray<NSString *> *senderKeys,NSArray<NSString *> *blockedSenders,NSString *plainText,NSArray<NSString *> *keywords){
 if(!switchOn)return NO;
 for(NSString *key in senderKeys)if(key.length&&[blockedSenders containsObject:key])return YES;
 return MYBMFTextMatches(plainText,keywords);
}
