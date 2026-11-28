// Desktop test of Shared/MYBMessageFirewallRules.h, MYBMessageFirewallStore.h, MYBMessageFirewallList.h and MYBMessageFirewallPatterns.h (pure logic,
// file store, wire format, and the 54 bundled scam regexes -- no UIKit, no hooks). Avoids object literals/subscripting like the other desktop tests,
// but exercises real NSRegularExpression compilation, so it needs the real Foundation/ICU this project's CI runs on (not the legacy GNUstep runtime).
#import <Foundation/Foundation.h>
#import "../Shared/MYBMessageFirewallStore.h"
#import "../Shared/MYBMessageFirewallList.h"

static int fails=0,checks=0;
#define CHECK(c,m) do{checks++;if(!(c)){fails++;printf("FAIL: %s (line %d)\n",m,__LINE__);}}while(0)

static NSString *TempFile(void){return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"myb-mf-test-%d.plist",arc4random()]];}

int main(void){@autoreleasepool{
 // ---- sender key normalization: phone numbers go through MYBPCKey, everything else falls back to "h:"+lowercase ----
 CHECK([MYBMFSenderKey(@"6123456789",@"US") isEqualToString:MYBPCKey(@"6123456789",@"US")],"sender key: a phone-shaped string normalizes exactly like Private Calls does");
 CHECK([MYBMFSenderKey(@"Friend@Example.com",nil) isEqualToString:@"h:friend@example.com"],"sender key: an email handle lowercases and gets the h: prefix");
 CHECK([MYBMFSenderKey(@"  bob@imessage.test  ",nil) isEqualToString:@"h:bob@imessage.test"],"sender key: a handle is trimmed before normalizing");
 CHECK(MYBMFSenderKey(@"",nil)==nil,"sender key: an empty string is refused");
 CHECK(MYBMFSenderKey(nil,nil)==nil,"sender key: nil is refused without crashing");
 CHECK(![MYBMFSenderKey(@"6123456789",@"US") hasPrefix:@"h:"],"sender key: a phone key never carries the handle prefix");

 // ---- display: a handle key shows the original text back, a phone key goes through the same formatter Private Calls uses ----
 CHECK([MYBMFDisplaySender(@"h:bob@imessage.test",nil) isEqualToString:@"bob@imessage.test"],"display: a handle key strips its h: prefix for display");
 NSString *phoneKey=MYBPCKey(@"6123456789",@"US");
 CHECK([MYBMFDisplaySender(phoneKey,@"US") isEqualToString:MYBPCFormat(phoneKey,@"US")],"display: a phone key formats the same way Private Calls does");

 // ---- keyword normalization: trimmed, lowercased, inner whitespace collapsed ----
 CHECK([MYBMFKeywordKey(@"  Free   Prize  ") isEqualToString:@"free prize"],"keyword key: trimmed, lowercased, inner whitespace collapsed to one space");
 CHECK(MYBMFKeywordKey(@"   ")==nil,"keyword key: whitespace-only is refused");
 CHECK(MYBMFKeywordKey(@"")==nil,"keyword key: empty string is refused");
 NSMutableString *tooLong=[NSMutableString string];for(int i=0;i<90;i++)[tooLong appendString:@"a"];
 CHECK(MYBMFKeywordKey(tooLong)==nil,"keyword key: an unreasonably long phrase is refused");

 // ---- text matching: case-insensitive substring, any one keyword is enough ----
 NSArray *kw=[NSArray arrayWithObjects:@"free prize",@"click here",nil];
 CHECK(MYBMFTextMatches(@"You WON a FREE PRIZE today!",kw),"text match: case-insensitive, matches anywhere in the body");
 CHECK(!MYBMFTextMatches(@"Hey, lunch at noon?",kw),"text match: an ordinary message matches nothing");
 CHECK(!MYBMFTextMatches(nil,kw),"text match: nil body never crashes and never matches");
 CHECK(!MYBMFTextMatches(@"free prize",[NSArray array]),"text match: an empty keyword list never matches");

 // ---- the one decision: switch gates everything; a sender match or a keyword match either one is enough ----
 NSArray *senders=[NSArray arrayWithObject:@"h:spammer@example.com"];
 NSArray *keywords=[NSArray arrayWithObject:@"lottery"];
 CHECK(MYBMFShouldBlock(YES,[NSArray arrayWithObject:@"h:spammer@example.com"],senders,@"hi",keywords),"decide: a listed sender is blocked regardless of message text");
 CHECK(!MYBMFShouldBlock(NO,[NSArray arrayWithObject:@"h:spammer@example.com"],senders,@"hi",keywords),"decide: the master switch off means nothing is ever blocked");
 CHECK(MYBMFShouldBlock(YES,[NSArray arrayWithObject:@"h:friend@example.com"],senders,@"you won the lottery",keywords),"decide: an unlisted sender is still blocked by a keyword match");
 CHECK(!MYBMFShouldBlock(YES,[NSArray arrayWithObject:@"h:friend@example.com"],senders,@"lunch at noon?",keywords),"decide: an unlisted sender with ordinary text is never blocked");
 CHECK(!MYBMFShouldBlock(YES,[NSArray array],senders,@"hi",keywords),"decide: no sender identifiers at all and no keyword match means nothing is blocked");

 // ---- store round-trip: senders and keywords live independently in the same file ----
 NSString *file=TempFile();
 CHECK(MYBMFSetSender(file,@"h:spammer@example.com",@"Spammer",YES,100),"store: add one sender");
 CHECK(MYBMFEffective(file,MYB_MF_KEY_SENDERS).count==1,"store: the sender reads back as active");
 CHECK(MYBMFSetKeyword(file,@"lottery",@"lottery",YES,100),"store: add one keyword");
 CHECK(MYBMFEffective(file,MYB_MF_KEY_SENDERS).count==1&&MYBMFEffective(file,MYB_MF_KEY_KEYWORDS).count==1,"store: sender list and keyword list never clobber one another");
 CHECK(MYBMFSetSender(file,@"h:spammer@example.com",@"Spammer",NO,101),"store: remove the sender");
 CHECK(MYBMFEffective(file,MYB_MF_KEY_SENDERS).count==0,"store: a removed sender is no longer active");
 CHECK(MYBMFEffective(file,MYB_MF_KEY_KEYWORDS).count==1,"store: removing a sender leaves the keyword list untouched");
 CHECK(!MYBMFSwitchOn(file),"store: the switch starts off");
 CHECK(MYBMFSwitchWrite(file,YES),"store: turn the switch on");
 CHECK(MYBMFSwitchOn(file),"store: the switch reads back on");
 [NSFileManager.defaultManager removeItemAtPath:file error:NULL];

 // ---- publish / parse round-trip (the live channel's own wire format, the exact text imagent's hook reads) ----
 NSString *file2=TempFile();
 MYBMFSwitchWrite(file2,YES);
 MYBMFSetSender(file2,@"h:spammer@example.com",@"",YES,0);
 MYBMFSetKeyword(file2,@"lottery",@"",YES,0);
 NSString *text=MYBMFPublishedText(file2);
 NSMutableArray *parsedSenders=nil,*parsedKeywords=nil,*parsedCategories=nil;
 BOOL sw=MYBMFParsePublished(text,&parsedSenders,&parsedKeywords,&parsedCategories);
 CHECK(sw,"publish/parse: the switch survives the round trip");
 CHECK(parsedSenders.count==1&&[[parsedSenders objectAtIndex:0] isEqualToString:@"h:spammer@example.com"],"publish/parse: the sender key survives the round trip");
 CHECK(parsedKeywords.count==1&&[[parsedKeywords objectAtIndex:0] isEqualToString:@"lottery"],"publish/parse: the keyword survives the round trip");
 CHECK(parsedCategories.count==1&&[parsedCategories containsObject:MYB_MF_PATTERN_JUNK],"publish/parse: the default pattern category (junk on, the rest off) survives the round trip");
 [NSFileManager.defaultManager removeItemAtPath:file2 error:NULL];

 // ---- pattern category settings: junk defaults on, promotion/transaction default off, each independently writable ----
 NSString *file3=TempFile();
 NSArray *defaultCats=MYBMFEnabledPatternCategories(file3);
 CHECK(defaultCats.count==1&&[defaultCats containsObject:MYB_MF_PATTERN_JUNK],"pattern settings: a fresh file has only Junk on by default");
 CHECK(MYBMFPatternCategoryWrite(file3,MYB_MF_KEY_PATTERNS_PROMOTION,YES),"pattern settings: turn Promotion on");
 NSArray *afterPromo=MYBMFEnabledPatternCategories(file3);
 CHECK(afterPromo.count==2&&[afterPromo containsObject:MYB_MF_PATTERN_JUNK]&&[afterPromo containsObject:MYB_MF_PATTERN_PROMOTION],"pattern settings: Promotion turns on without disturbing Junk");
 CHECK(MYBMFPatternCategoryWrite(file3,MYB_MF_KEY_PATTERNS_JUNK,NO),"pattern settings: turn Junk off");
 NSArray *afterJunkOff=MYBMFEnabledPatternCategories(file3);
 CHECK(afterJunkOff.count==1&&[afterJunkOff containsObject:MYB_MF_PATTERN_PROMOTION],"pattern settings: turning Junk off leaves Promotion untouched");
 [NSFileManager.defaultManager removeItemAtPath:file3 error:NULL];

 // ---- bundled scam patterns: the real data, compiled for real, matched against a real scam phrase and a real ordinary one ----
 NSArray *bundled=MYBMFBundledPatterns();
 CHECK(bundled.count==54,"bundled patterns: all 54 rules are present");
 NSUInteger junkCount=0,promoCount=0,txnCount=0;
 for(NSDictionary *e in bundled){
  NSString *cat=[e objectForKey:@"category"];
  if([cat isEqualToString:MYB_MF_PATTERN_JUNK])junkCount++;
  else if([cat isEqualToString:MYB_MF_PATTERN_PROMOTION])promoCount++;
  else if([cat isEqualToString:MYB_MF_PATTERN_TRANSACTION])txnCount++;
 }
 CHECK(junkCount==48,"bundled patterns: 48 rules are categorized junk");
 CHECK(promoCount==4,"bundled patterns: 4 rules are categorized promotion");
 CHECK(txnCount==2,"bundled patterns: 2 rules are categorized transaction");
 NSArray *compiled=MYBMFCompileBundledPatterns();
 CHECK(compiled.count==54,"bundled patterns: every one of the 54 regexes compiles successfully (none silently dropped)");
 NSArray *junkOnly=[NSArray arrayWithObject:MYB_MF_PATTERN_JUNK];
 CHECK(MYBMFCompiledPatternsMatch(@"Your Apple ID has been locked due to unusual activity. Verify now at apple-id-verify-secure.com to restore access.",compiled,junkOnly),"bundled patterns: a real fake-Apple-ID-lock scam text is caught by the Junk category");
 CHECK(!MYBMFCompiledPatternsMatch(@"Hey, are we still on for dinner tonight at 7?",compiled,junkOnly),"bundled patterns: an ordinary personal text is never flagged");
 CHECK(!MYBMFCompiledPatternsMatch(@"Your Apple ID has been locked due to unusual activity. Verify now at apple-id-verify-secure.com to restore access.",compiled,[NSArray array]),"bundled patterns: no match at all when no category is enabled, even against real scam text");

 printf("%d checks, %d failed\n",checks,fails);
 return fails?1:0;
}}
