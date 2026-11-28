// Desktop test of Shared/MYBFirewallRules.h, MYBFirewallStore.h and MYBFirewallWire.h (pure logic + file store; no UIKit, no hooks, no CFPreferences).
// Plain Foundation: no object literals, no subscripting, so this runs under the older GNUstep runtime the other desktop tests already use.
#import <Foundation/Foundation.h>
#import "../Shared/MYBFirewallStore.h"
#import "../Shared/MYBFirewallWire.h"

static int fails=0,checks=0;
#define CHECK(c,m) do{checks++;if(!(c)){fails++;printf("FAIL: %s (line %d)\n",m,__LINE__);}}while(0)

static NSString *TempFile(void){return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"myb-fw-test-%d.plist",arc4random()]];}
static NSArray *Arr(id a,id b){return [NSArray arrayWithObjects:a,b,nil];}
static NSMutableDictionary *MutCopy(NSDictionary *d){return [d mutableCopy];}

int main(void){@autoreleasepool{
 // ---- range matching ----
 NSDictionary *v=MYBFWValidRange(@"+234",MYB_PC_ACTION_DECLINE);
 CHECK([[v objectForKey:@"prefix"] isEqualToString:@"+234"],"range prefix normalized with +");
 CHECK([[MYBFWValidRange(@"234",MYB_PC_ACTION_DECLINE) objectForKey:@"prefix"] isEqualToString:@"+234"],"range prefix gets + when missing");
 CHECK(MYBFWValidRange(@"",MYB_PC_ACTION_DECLINE)==nil,"empty prefix refused");
 CHECK(MYBFWValidRange(@"+",MYB_PC_ACTION_DECLINE)==nil,"bare + refused (too short to mean anything)");
 NSArray *ranges=Arr(MYBFWValidRange(@"+1",MYB_PC_ACTION_MUTE),MYBFWValidRange(@"+1900",MYB_PC_ACTION_HANGUP));
 CHECK([[MYBFWRangeMatch(ranges,@"+19005551234") objectForKey:@"a"] isEqualToString:@"hangup"],"longest prefix wins (+1900 over +1)");
 CHECK([[MYBFWRangeMatch(ranges,@"+14155550123") objectForKey:@"a"] isEqualToString:@"mute"],"shorter prefix still matches when the longer one does not");
 CHECK(MYBFWRangeMatch(ranges,@"+34612345678")==nil,"no match for an unrelated country code");
 CHECK(MYBFWRangeMatch(ranges,@"n:ES:612345678")==nil,"range rules only ever apply to keys with a country code");

 // ---- decision order: explicit entry always wins, Allow List Mode is absolute next, then unknown/range/international ----
 NSDictionary *base=MYBFWSettingsDefaults();
 #define ARGS1 YES,YES,NO,YES,NO,NO,NO   // switchOn,incoming,answeredOrConnected,ordinaryPhoneCall,emergency,alreadyHandled,otherCallActive
 CHECK(MYBFWDecide(base,nil,@"+34612345678",NO,ARGS1)==MYBFWNothing,"nothing configured: a plain call rings");
 NSDictionary *allowed=MYBFWRecord(@"+34612345678",@"",MYB_FW_ACTION_ALLOW,YES,0);
 NSMutableDictionary *s1=MutCopy(base);
 [s1 setObject:[NSNumber numberWithBool:YES] forKey:MYB_FW_KEY_ALLOWLIST];
 [s1 setObject:MYB_PC_ACTION_DECLINE forKey:MYB_FW_KEY_DEFAULT_ACTION];
 CHECK(MYBFWDecide(s1,allowed,@"+34612345678",NO,ARGS1)==MYBFWNothing,"Allow List Mode: the allowed number still rings");
 CHECK(MYBFWDecide(s1,nil,@"+34699999999",NO,ARGS1)==MYBFWDoDecline,"Allow List Mode: a number with no entry gets the default action");
 NSDictionary *blocked=MYBFWRecord(@"+34611111111",@"",MYB_PC_ACTION_HANGUP,YES,0);
 CHECK(MYBFWDecide(s1,blocked,@"+34611111111",NO,ARGS1)==MYBFWDoHangup,"an explicit block entry still applies even inside Allow List Mode");
 NSMutableDictionary *s2=MutCopy(base);
 [s2 setObject:MYB_PC_ACTION_DECLINE forKey:MYB_FW_KEY_UNKNOWN_ACTION];
 CHECK(MYBFWDecide(s2,nil,nil,YES,ARGS1)==MYBFWDoDecline,"no caller ID at all: the Unknown rule applies");
 CHECK(MYBFWDecide(s2,nil,@"+34612345678",NO,ARGS1)==MYBFWNothing,"Unknown rule never touches a call that does have a caller ID");
 NSMutableDictionary *s3=MutCopy(base);
 [s3 setObject:[NSArray arrayWithObject:MYBFWValidRange(@"+234",MYB_PC_ACTION_DECLINE)] forKey:MYB_FW_KEY_RANGES];
 CHECK(MYBFWDecide(s3,nil,@"+2348012345678",NO,ARGS1)==MYBFWDoDecline,"a range rule applies to a matching number with no entry");
 CHECK(MYBFWDecide(s3,nil,@"+15551234567",NO,ARGS1)==MYBFWNothing,"a range rule leaves every other number alone");
 NSMutableDictionary *s4=MutCopy(base);
 [s4 setObject:[NSNumber numberWithBool:YES] forKey:MYB_FW_KEY_INTL_BLOCK];
 [s4 setObject:MYB_PC_ACTION_MUTE forKey:MYB_FW_KEY_INTL_ACTION];
 CHECK(MYBFWDecide(s4,nil,@"+2348012345678",NO,ARGS1)==MYBFWDoMute,"International Block applies to a number with a foreign country code");
 CHECK(MYBFWDecide(s4,nil,@"n:ES:612345678",NO,ARGS1)==MYBFWNothing,"International Block never touches a national-only key (no settled country code)");
 NSMutableDictionary *s5=MutCopy(base);
 [s5 setObject:[NSArray arrayWithObject:MYBFWValidRange(@"+234",MYB_PC_ACTION_HANGUP)] forKey:MYB_FW_KEY_RANGES];
 [s5 setObject:[NSNumber numberWithBool:YES] forKey:MYB_FW_KEY_INTL_BLOCK];
 [s5 setObject:MYB_PC_ACTION_MUTE forKey:MYB_FW_KEY_INTL_ACTION];
 CHECK(MYBFWDecide(s5,nil,@"+2348012345678",NO,ARGS1)==MYBFWDoHangup,"a specific range rule outranks the broader International Block");
 // call-waiting / already-busy reasoning, same as Private Calls
 CHECK(MYBFWDecide(s1,blocked,@"+34611111111",NO,YES,YES,NO,YES,NO,NO,YES)==MYBFWDoDecline,"Hang up becomes Decline when another call is already active");
 NSDictionary *muted=MYBFWRecord(@"+34622222222",@"",MYB_PC_ACTION_MUTE,YES,0);
 CHECK(MYBFWDecide(base,muted,@"+34622222222",NO,YES,YES,NO,YES,NO,NO,YES)==MYBFWNothing,"Mute does nothing useful with another call active, so it is skipped");
 CHECK(MYBFWDecide(base,nil,@"+34612345678",NO,NO,YES,NO,YES,NO,NO,NO)==MYBFWNothing,"switch off: nothing happens regardless of every other rule");
 CHECK(MYBFWDecide(base,blocked,@"+34611111111",NO,YES,YES,YES,YES,NO,NO,NO)==MYBFWNothing,"a call already answered or connected is never touched");
 CHECK(MYBFWDecide(base,blocked,@"+34611111111",NO,YES,YES,NO,YES,YES,NO,NO)==MYBFWNothing,"an emergency call is never touched");

 // ---- store round-trip ----
 NSString *file=TempFile();
 CHECK(MYBFWStoreSet(file,@"+34612345678",@"Spam",MYB_PC_ACTION_DECLINE,YES,100),"store: add one number");
 CHECK([[MYBFWEntryForKey(file,@"+34612345678") objectForKey:@"a"] isEqualToString:@"decline"],"store: the entry reads back with the action it was given");
 CHECK(MYBFWStoreSet(file,@"+34612345678",@"Spam",MYB_PC_ACTION_MUTE,YES,101),"store: change the same number's action");
 CHECK([[MYBFWEntryForKey(file,@"+34612345678") objectForKey:@"a"] isEqualToString:@"mute"],"store: the newer write wins");
 CHECK(MYBFWStoreSet(file,@"+34612345678",@"Spam",MYB_PC_ACTION_MUTE,NO,102),"store: remove the number");
 CHECK(MYBFWEntryForKey(file,@"+34612345678")==nil,"store: a removed number is no longer an active entry");
 NSMutableDictionary *switchAndAllow=[NSMutableDictionary dictionary];
 [switchAndAllow setObject:[NSNumber numberWithBool:YES] forKey:MYB_FW_KEY_SWITCH];
 [switchAndAllow setObject:[NSNumber numberWithBool:YES] forKey:MYB_FW_KEY_ALLOWLIST];
 CHECK(MYBFWSettingsWrite(file,switchAndAllow),"settings: write switch + allow-list together");
 NSDictionary *read=MYBFWSettingsRead(file);
 CHECK([[read objectForKey:MYB_FW_KEY_SWITCH] boolValue],"settings: switch persisted");
 CHECK([[read objectForKey:MYB_FW_KEY_ALLOWLIST] boolValue],"settings: allow-list mode persisted alongside it");
 CHECK([[read objectForKey:MYB_FW_KEY_DEFAULT_ACTION] isEqualToString:MYB_PC_ACTION_DECLINE],"settings: an untouched key keeps its default");
 NSDictionary *goodRange=[NSDictionary dictionaryWithObjectsAndKeys:@"+234",@"prefix",MYB_PC_ACTION_DECLINE,@"a",nil];
 NSDictionary *secondGoodRange=[NSDictionary dictionaryWithObjectsAndKeys:@"1900",@"prefix",MYB_PC_ACTION_MUTE,@"a",nil];
 NSDictionary *badRange=[NSDictionary dictionaryWithObjectsAndKeys:@"bad",@"prefix",MYB_PC_ACTION_MUTE,@"a",nil];   // no digits at all: not a usable prefix
 CHECK(MYBFWRangesWrite(file,[NSArray arrayWithObjects:goodRange,secondGoodRange,badRange,nil]),"ranges: write accepts a mixed batch");
 NSArray *storedRanges=[MYBFWSettingsRead(file) objectForKey:MYB_FW_KEY_RANGES];
 CHECK(storedRanges.count==2,"ranges: the two valid prefixes are kept and the non-numeric one is dropped");
 [NSFileManager.defaultManager removeItemAtPath:file error:NULL];

 // ---- publish / parse round-trip (the live channel's own wire format) ----
 NSString *file2=TempFile();
 MYBFWStoreSet(file2,@"+34612345678",@"",MYB_PC_ACTION_DECLINE,YES,0);
 NSMutableDictionary *settingsToWrite=[NSMutableDictionary dictionary];
 [settingsToWrite setObject:[NSNumber numberWithBool:YES] forKey:MYB_FW_KEY_SWITCH];
 [settingsToWrite setObject:[NSNumber numberWithBool:YES] forKey:MYB_FW_KEY_INTL_BLOCK];
 [settingsToWrite setObject:MYB_PC_ACTION_MUTE forKey:MYB_FW_KEY_INTL_ACTION];
 MYBFWSettingsWrite(file2,settingsToWrite);
 MYBFWRangesWrite(file2,[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"+234",@"prefix",MYB_PC_ACTION_HANGUP,@"a",nil]]);
 NSString *text=MYBFWPublishedText(file2);
 NSArray *parsedEntries=nil;
 NSDictionary *parsedSettings=MYBFWParsePublished(text,&parsedEntries);
 CHECK([[parsedSettings objectForKey:MYB_FW_KEY_SWITCH] boolValue],"publish/parse: switch survives the round trip");
 CHECK([[parsedSettings objectForKey:MYB_FW_KEY_INTL_BLOCK] boolValue],"publish/parse: international block survives the round trip");
 CHECK([[parsedSettings objectForKey:MYB_FW_KEY_INTL_ACTION] isEqualToString:@"mute"],"publish/parse: international action survives the round trip");
 NSArray *parsedRanges=[parsedSettings objectForKey:MYB_FW_KEY_RANGES];
 CHECK(parsedRanges.count==1,"publish/parse: the range rule survives the round trip");
 CHECK([[(NSDictionary *)[parsedRanges objectAtIndex:0] objectForKey:@"prefix"] isEqualToString:@"+234"],"publish/parse: the range prefix is unchanged");
 CHECK(parsedEntries.count==1&&[[(NSDictionary *)[parsedEntries objectAtIndex:0] objectForKey:@"k"] isEqualToString:@"+34612345678"],"publish/parse: the listed number survives the round trip");
 [NSFileManager.defaultManager removeItemAtPath:file2 error:NULL];

 printf("%d checks, %d failed\n",checks,fails);
 return fails?1:0;
}}
