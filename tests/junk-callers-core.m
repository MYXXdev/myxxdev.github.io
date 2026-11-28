// Desktop test of Shared/MYBJunkCallers.h: the pure binary-search matcher against a small synthetic in-memory buffer, then an integration check
// against the real compiled dataset (layout/usr/share/mybloxx/junk-callers/JunkCallers.dat, built by tools/generate-junk-callers.py from Mikey's
// own tools/data/junk-callers-source.txt) to confirm the actual shipped file is well-formed, sorted, and a real entry from it is found.
#import <Foundation/Foundation.h>
#import "../Shared/MYBJunkCallers.h"

static int fails=0,checks=0;
#define CHECK(c,m) do{checks++;if(!(c)){fails++;printf("FAIL: %s (line %d)\n",m,__LINE__);}}while(0)

int main(void){@autoreleasepool{
 // ---- MYBJCPaddedDigits: normalizes a phone key to the fixed record width, refuses anything that isn't a plain digit string or won't fit ----
 CHECK([MYBJCPaddedDigits(@"+14155551234") isEqualToString:@"000014155551234"],"padded digits: a real key zero-pads on the left to 15 chars");
 CHECK([MYBJCPaddedDigits(@"14155551234") isEqualToString:@"000014155551234"],"padded digits: works the same with no leading +");
 CHECK(MYBJCPaddedDigits(@"+1abc5551234")==nil,"padded digits: refuses anything with a non-digit character");
 CHECK(MYBJCPaddedDigits(@"+1234567890123456")==nil,"padded digits: refuses a digit string longer than the fixed record width");
 CHECK(MYBJCPaddedDigits(nil)==nil,"padded digits: nil never crashes");
 CHECK(MYBJCPaddedDigits(@"")==nil,"padded digits: an empty string is refused");

 // ---- MYBJCBufferContains: classic binary search over a small synthetic sorted buffer, built by hand the same way the generator would ----
 NSArray *sample = [NSArray arrayWithObjects:@"000000000000100",@"000000000000200",@"000000000000300",@"000014155551234",@"999999999999999",nil];
 NSMutableData *buf = [NSMutableData data];
 for (NSString *s in sample) [buf appendData:[s dataUsingEncoding:NSASCIIStringEncoding]];
 const char *records = (const char *)buf.bytes;
 size_t count = sample.count;
 CHECK(MYBJCBufferContains(records,count,@"000000000000100"),"buffer search: finds the first record");
 CHECK(MYBJCBufferContains(records,count,@"999999999999999"),"buffer search: finds the last record");
 CHECK(MYBJCBufferContains(records,count,@"000014155551234"),"buffer search: finds a record in the middle");
 CHECK(!MYBJCBufferContains(records,count,@"000000000000150"),"buffer search: a number between two real entries is never a false match");
 CHECK(!MYBJCBufferContains(records,count,@"000000000000099"),"buffer search: a number just below the first entry is never a false match");
 CHECK(!MYBJCBufferContains(NULL,0,@"000000000000100"),"buffer search: an empty/missing buffer never crashes and never matches");
 CHECK(!MYBJCBufferContains(records,count,@"12345"),"buffer search: a wrong-length key is refused before any comparison");

 // ---- MYBJCIsListed: the combined padded-digits + search path, exactly what the hook calls per incoming call ----
 CHECK(MYBJCIsListed(records,count,@"+14155551234"),"is-listed: a real E.164 key is normalized and found");
 CHECK(!MYBJCIsListed(records,count,@"+19995550000"),"is-listed: an unlisted number is never a false positive");
 CHECK(!MYBJCIsListed(records,count,@"not-a-number"),"is-listed: garbage input never crashes and never matches");

 // ---- integration: the real shipped dataset loads, is well-formed, sorted, and actually contains a known real entry ----
 NSString *root = [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@".."];
 NSString *datasetPath = [[root stringByAppendingPathComponent:@"layout/usr/share/mybloxx/junk-callers/JunkCallers.dat"] stringByStandardizingPath];
 const char *realRecords = NULL; size_t realCount = 0;
 BOOL loaded = MYBJCLoad(datasetPath,&realRecords,&realCount);
 CHECK(loaded,"real dataset: loads successfully from the path the generator writes to");
 CHECK(realCount > 1000000,"real dataset: the loaded record count is in the expected range (Mikey's international source has 1,109,746 unique entries)");
 if (loaded && realCount > 0) {
  CHECK(MYBJCIsListed(realRecords,realCount,@"+49191011"),"real dataset: the first entry in the source file is found");
  CHECK(MYBJCIsListed(realRecords,realCount,@"+499912568741596"),"real dataset: the last entry in the source file is found");
  CHECK(!MYBJCIsListed(realRecords,realCount,@"+15555550123"),"real dataset: an arbitrary number not in the source file is not a false positive");
  // sortedness: compare every adjacent pair directly over the mapped buffer, exactly as the binary search relies on
  BOOL sorted = YES;
  for (size_t i = 1; i < realCount && sorted; i++) if (memcmp(realRecords+(i-1)*MYB_JC_RECORD_LEN, realRecords+i*MYB_JC_RECORD_LEN, MYB_JC_RECORD_LEN) > 0) sorted = NO;
  CHECK(sorted,"real dataset: every record is in ascending order (the binary search's one hard requirement)");
 }

 printf("%d checks, %d failed\n",checks,fails);
 return fails?1:0;
}}
