// Bulk Custom Rules: preview, normalisation, conflicts, limits and undo (Shared/MYBBulkRules.h). The one-transaction apply and its
// rollback are the existing `localcustom` action, covered by tests/helper-real-native.m and tests/rule-store-native.m.
#import <Foundation/Foundation.h>
#import "../Shared/MYBBulkRules.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static NSString *N(NSString *raw){NSString *w=nil;return MYBBulkNormalize(raw,&w);}
static NSString *Why(NSString *raw){NSString *w=nil;(void)MYBBulkNormalize(raw,&w);return w;}
int main(void){@autoreleasepool{
 // normalisation
 CHECK([N(@"Example.COM")isEqual:@"example.com"],"case is folded");
 CHECK([N(@"https://ads.example.com/path?q=1#x")isEqual:@"ads.example.com"],"an address becomes its host");
 CHECK([N(@"http://example.com:8080/x")isEqual:@"example.com"],"a port is dropped");
 CHECK([N(@"||tracker.example.org^")isEqual:@"tracker.example.org"],"an Adblock-style entry is read");
 CHECK([N(@"*.example.com")isEqual:@"example.com"]&&[N(@".example.com")isEqual:@"example.com"]&&[N(@"example.com.")isEqual:@"example.com"],"wildcard, leading dot and trailing dot are dropped");
 CHECK([N(@"  spaced.example.com  ")isEqual:@"spaced.example.com"],"spaces are trimmed");
 CHECK(N(@"")==nil&&Why(@"")==nil,"an empty entry is ignored without a reason");
 CHECK(N(@"1.2.3.4")==nil&&[Why(@"1.2.3.4") containsString:@"IP"],"an IP address is refused");
 CHECK(N(@"localhost")==nil&&N(@"nodot")==nil,"a name without a dot is refused");
 CHECK(N(@"a b.com")==nil&&N(@"a_b.com")==nil&&N(@"-a.com")==nil&&N(@"a-.com")==nil&&N(@"a..com")==nil,"bad characters and labels are refused");
 CHECK(N(@"user@example.com")==nil&&N(@"ftp://example.com")==nil,"a user name or another scheme is refused");
 CHECK(N(@"bücher.example")==nil&&[Why(@"bücher.example") containsString:@"xn--"],"non-ASCII names are refused with the xn-- hint");
 CHECK(N([[@"" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0] stringByAppendingString:@".com"])==nil,"a label over 63 characters is refused");
 NSMutableString *longName=[NSMutableString string];for(int i=0;i<30;i++)[longName appendString:@"abcdefgh."];[longName appendString:@"com"];CHECK(N(longName)==nil,"a name over 253 characters is refused");
 // tokens: lines, commas, hosts files, comments
 NSUInteger comments=0;NSArray *t=MYBBulkTokens(@"# a comment\n! another\n// third\n0.0.0.0 one.example.com two.example.com\n127.0.0.1\tthree.example.com # trailing\nfour.example.com, five.example.com;six.example.com\r\nseven.example.com\r\n\r\n",&comments);
 CHECK(comments==3,"three comment lines are counted and ignored");
 CHECK([t isEqual:(@[@"one.example.com",@"two.example.com",@"three.example.com",@"four.example.com",@"five.example.com",@"six.example.com",@"seven.example.com"])],"hosts lines, commas, semicolons and CRLF are all read");
 // plan: adds, existing, duplicates, conflicts, invalid
 NSArray *blocked=@[@"old-block.com",@"shared.com"],*allowed=@[@"old-allow.com"];
 NSDictionary *p=MYBBulkPlan(@"new1.com\nNEW2.com\nnew1.com\nold-block.com\nold-allow.com\nbad entry\n1.2.3.4\nhttps://new3.com/x\n",NO,blocked,allowed);
 CHECK([p[@"add"] isEqual:(@[@"new1.com",@"new2.com",@"new3.com"])],"new domains are added in order, normalised, once");
 CHECK([p[@"duplicates"] integerValue]==1,"a repeat inside the text is counted");
 CHECK([p[@"existing"] isEqual:@[@"old-block.com"]],"a domain already in the list is reported, not added again");
 CHECK([p[@"conflicts"] isEqual:@[@"old-allow.com"]],"a domain in the other list is a conflict and is skipped, never moved");
 CHECK([p[@"invalid"] count]==3&&[p[@"toAllow"] boolValue]==NO,"unusable entries are listed with reasons ('bad', 'entry' and the IP)");
 CHECK([p[@"blockedAfter"] isEqual:(@[@"old-block.com",@"shared.com",@"new1.com",@"new2.com",@"new3.com"])]&&[p[@"allowedAfter"] isEqual:allowed],"the resulting lists change only the chosen list");
 NSDictionary *pa=MYBBulkPlan(@"gets-allowed.com\nold-block.com\n",YES,blocked,allowed);
 CHECK([pa[@"add"] isEqual:@[@"gets-allowed.com"]]&&[pa[@"conflicts"] isEqual:@[@"old-block.com"]]&&[pa[@"allowedAfter"] isEqual:(@[@"old-allow.com",@"gets-allowed.com"])]&&[pa[@"blockedAfter"] isEqual:blocked],"an Allow import adds to Allowed and leaves Blocked alone");
 // limit
 NSMutableString *big=[NSMutableString string];for(int i=0;i<700;i++)[big appendFormat:@"host%d.example.com\n",i];
 NSDictionary *pl=MYBBulkPlan(big,NO,@[],@[]);
 CHECK([pl[@"add"] count]==700&&[pl[@"overflow"] integerValue]==0,"a few hundred domains are all accepted");
 NSDictionary *pl2=MYBBulkPlan(big,NO,[pl[@"blockedAfter"] subarrayWithRange:NSMakeRange(0,495)],@[]);
 CHECK([pl2[@"add"] count]==205&&[pl2[@"blockedAfter"] count]==700,"existing entries are kept and only new ones are added");
 NSMutableString *huge=[NSMutableString string];while(huge.length<=MYB_BULK_MAX_INPUT)[huge appendString:@"aaaaaaaaaa.example.com\n"];
 NSDictionary *ph=MYBBulkPlan(huge,NO,@[],@[]);CHECK([ph[@"tooLarge"] boolValue]&&[ph[@"add"] count]==0&&[MYBBulkSummary(ph) containsString:@"too large"],"oversized text is refused whole");
 CHECK([MYBBulkPlan((id)@1,NO,@[],@[])[@"tooLarge"] boolValue],"a non-text input is refused");
 // summary wording: counts, a few examples, no em dash
 NSString *sum=MYBBulkSummary(p);
 CHECK([sum containsString:@"3 new domains will be added to Blocked."]&&[sum containsString:@"1 already in Blocked."]&&[sum containsString:@"old-allow.com"]&&[sum containsString:@"not valid"],"the preview says what is added and what is skipped");
 CHECK([sum rangeOfString:@"—"].location==NSNotFound,"no em dash in the preview");
 NSDictionary *none=MYBBulkPlan(@"old-block.com\n",NO,blocked,allowed);CHECK([MYBBulkSummary(none) hasPrefix:@"Nothing new to add to Blocked."],"nothing new is said plainly");
 NSMutableString *manyBad=[NSMutableString string];for(int i=0;i<30;i++)[manyBad appendFormat:@"bad%d\n",i];
 NSString *bs=MYBBulkSummary(MYBBulkPlan(manyBad,NO,@[],@[]));CHECK([bs containsString:@"30 not valid"]&&[bs containsString:@"and more"]&&[[bs componentsSeparatedByString:@"Needs a dot"] count]<=MYB_BULK_EXAMPLES+1+0,"only a few skipped entries are named");
 CHECK([MYBBulkCSV(@[@"a.com",@"b.com"]) isEqual:@"a.com,b.com"]&&[MYBBulkCSV(@[]) isEqual:@""],"the helper's CSV form");
 // undo
 NSDictionary *rec=MYBBulkUndoRecord(blocked,allowed,p);
 CHECK(MYBBulkUndoAvailable(rec,p[@"blockedAfter"],p[@"allowedAfter"]),"undo is available right after an import");
 CHECK(!MYBBulkUndoAvailable(rec,@[@"old-block.com",@"shared.com",@"new1.com",@"new2.com"],allowed),"undo is refused once the rules have changed since the import");
 CHECK(!MYBBulkUndoAvailable(rec,blocked,allowed),"undo is not offered when the rules are back to where they were");
 CHECK(!MYBBulkUndoAvailable(nil,blocked,allowed)&&!MYBBulkUndoAvailable(@{},blocked,allowed),"no record, no undo");
 CHECK(!MYBBulkUndoAvailable(MYBBulkUndoRecord(blocked,allowed,none),blocked,allowed),"an import that added nothing has nothing to undo");
 if(failures)fprintf(stderr,"%d bulk-rules check(s) FAILED\n",failures);else printf("Bulk rules checks passed\n");
 return failures?1:0;
}}
