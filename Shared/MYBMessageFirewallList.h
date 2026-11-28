#pragma once
// Hands the Message Firewall's switch and both lists to imagent, the exact same way MYBFirewallList.h already does for the Call Firewall and
// callservicesd: a system notification mailbox, plus a live write through the preference service itself. On-device testing (r53/r54) confirmed
// imagent's sandbox refuses the plain mailbox and a plain file write, but allows CFPreferences into a domain -- so the live domain write is what
// this channel actually depends on; the mailbox is kept only as a harmless, zero-cost second attempt. Its own domain and mailbox name, so this can
// never collide with the Call Firewall's or Private Calls' own live channels. The text format is plain Foundation only (no CFPreferences, no
// notify.h), so the exact same parsing code runs in the desktop tests.
#import <Foundation/Foundation.h>
#import "MYBMessageFirewallStore.h"
#import "MYBCallServiceChannel.h"
#define MYB_MFL_NAME @"net.myxxdev.mybloxx.mfl.%u"
#define MYB_MFL_LIVE_DOMAIN CFSTR("net.myxxdev.mybloxx.msgfirewall.live")
#define MYB_MFL_LIVE_KEY CFSTR("List")

// One "sw=" line, one line per bundled-pattern category flag, then one "sender"/"keyword" line per entry. Parsed back by MYBMFParsePublished below.
// The category flags travel through this same live channel (never read from the plist file directly) for the same reason the switch and lists do:
// imagent's sandbox refuses a plain file read, so this is the one path proven to reach it.
static inline NSString *MYBMFPublishedText(NSString *file){
 NSMutableString *text=[NSMutableString string];
 [text appendFormat:@"sw=%d\n",MYBMFSwitchOn(file)?1:0];
 [text appendFormat:@"junk=%d\n",MYBMFPatternCategoryOn(file,MYB_MF_KEY_PATTERNS_JUNK,YES)?1:0];
 [text appendFormat:@"promo=%d\n",MYBMFPatternCategoryOn(file,MYB_MF_KEY_PATTERNS_PROMOTION,NO)?1:0];
 [text appendFormat:@"txn=%d\n",MYBMFPatternCategoryOn(file,MYB_MF_KEY_PATTERNS_TRANSACTION,NO)?1:0];
 for(NSDictionary *e in MYBMFEffective(file,MYB_MF_KEY_SENDERS)){NSString *k=[e objectForKey:@"k"];if([k isKindOfClass:NSString.class]&&k.length)[text appendFormat:@"sender\t%@\n",k];}
 for(NSDictionary *e in MYBMFEffective(file,MYB_MF_KEY_KEYWORDS)){NSString *k=[e objectForKey:@"k"];if([k isKindOfClass:NSString.class]&&k.length)[text appendFormat:@"keyword\t%@\n",k];}
 return text;
}
static inline void MYBMFLPublish(NSString *file){
 @autoreleasepool{
  if(!file.length)return;
  NSString *text=MYBMFPublishedText(file);
  MYBCSCPublishIn(MYB_MFL_NAME,text);
  id old=CFBridgingRelease(CFPreferencesCopyValue(MYB_MFL_LIVE_KEY,MYB_MFL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
  if(![old isEqual:text]){
   CFPreferencesSetValue(MYB_MFL_LIVE_KEY,(__bridge CFPropertyListRef)text,MYB_MFL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
   CFPreferencesSynchronize(MYB_MFL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
  }
 }
}
static inline NSString *MYBMFLReadPublished(void){
 id live=CFBridgingRelease(CFPreferencesCopyValue(MYB_MFL_LIVE_KEY,MYB_MFL_LIVE_DOMAIN,kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
 if([live isKindOfClass:NSString.class]&&[(NSString *)live length])return live;
 return MYBCSCReadFrom(MYB_MFL_NAME);
}
// Pure text parsing, no CFPreferences or notify.h dependency, so this half runs unchanged in the desktop tests. patternCategoriesOut comes back as
// the string labels MYBMFCompiledPatternsMatch expects directly, so the hook never has to re-derive them from the raw junk/promo/txn flags.
static inline BOOL MYBMFParsePublished(NSString *text,NSMutableArray **sendersOut,NSMutableArray **keywordsOut,NSMutableArray **patternCategoriesOut){
 BOOL sw=NO;
 NSMutableArray *senders=[NSMutableArray array],*keywords=[NSMutableArray array],*categories=[NSMutableArray array];
 for(NSString *line in [text componentsSeparatedByString:@"\n"]){
  if(!line.length)continue;
  if([line hasPrefix:@"sw="])sw=[[line substringFromIndex:3] isEqual:@"1"];
  else if([line hasPrefix:@"junk="]){if([[line substringFromIndex:5] isEqual:@"1"])[categories addObject:MYB_MF_PATTERN_JUNK];}
  else if([line hasPrefix:@"promo="]){if([[line substringFromIndex:6] isEqual:@"1"])[categories addObject:MYB_MF_PATTERN_PROMOTION];}
  else if([line hasPrefix:@"txn="]){if([[line substringFromIndex:4] isEqual:@"1"])[categories addObject:MYB_MF_PATTERN_TRANSACTION];}
  else if([line hasPrefix:@"sender\t"]){NSString *k=[line substringFromIndex:7];if(k.length)[senders addObject:k];}
  else if([line hasPrefix:@"keyword\t"]){NSString *k=[line substringFromIndex:8];if(k.length)[keywords addObject:k];}
 }
 if(sendersOut)*sendersOut=senders;
 if(keywordsOut)*keywordsOut=keywords;
 if(patternCategoriesOut)*patternCategoriesOut=categories;
 return sw;
}

// The hook's own report-back channel -- one shared place for these names so the hook (Companions/MYBMessageFirewall/Tweak.m) and the Settings
// screen that reads them back (Preferences/MYBFirewallController.m) can never drift apart. CFPreferences into imagent's own domain is the one path
// confirmed reliable on-device (r53-r55); the mailbox is kept only as a harmless, zero-cost second attempt, same as the hook's own comment says.
#define MYB_MFH_OWN_DOMAIN CFSTR("com.apple.imagent")
#define MYB_MFH_OWN_KEY CFSTR("MYBMessageFirewallReport")
#define MYB_MFH_NAME @"net.myxxdev.mybloxx.mfh.%u"
// Reads the hook's own self-report: did it find the class/method, did the method's shape match, did it install, and (once any message has been
// checked) what it has seen since. Returns nil if the hook has never reported in at all -- which, on its own, is itself a diagnosis: either the
// dylib never loaded into imagent, or it loaded before CFPreferences was able to write back (vanishingly unlikely; Report() runs synchronously
// right after InstallHook resolves, success or failure).
static inline NSString *MYBMFHReadReport(void){
 id value=CFBridgingRelease(CFPreferencesCopyAppValue(MYB_MFH_OWN_KEY,MYB_MFH_OWN_DOMAIN));
 if([value isKindOfClass:NSString.class]&&[(NSString *)value length])return value;
 NSString *box=MYBCSCReadFrom(MYB_MFH_NAME);
 return box.length?box:nil;
}
