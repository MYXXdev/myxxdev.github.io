#import <Foundation/Foundation.h>
#import "../Shared/MYBOptions.h"
#import "../Shared/MYBModeNames.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{
 NSArray *ids=MYBModeIDs();CHECK(ids.count==32&&[NSSet setWithArray:ids].count==32,"32 distinct identifiers");
 for(NSString *i in ids)CHECK(MYBModeIDValid(i)&&[MYBModeIDForOptions(MYBOptionsForModeID(i))isEqual:i],"every identifier round-trips");
 CHECK([MYBModeIDForOptions(@[])isEqual:@"Default"],"no option is Default");
 for(NSString *o in MYBOptionOrder())CHECK([MYBModeIDForOptions(@[o])isEqual:o]&&MYBModeIDValid(o),"a single option keeps its historical identifier");
 CHECK([MYBModeIDForOptions(@[@"blockXXX",@"allowY",@"allowY"])isEqual:@"allowY+blockXXX"],"order and duplicates are normalised");
 CHECK([MYBModeIDForOptions([NSSet setWithObjects:@"blockAdSense",@"bogus",nil])isEqual:@"blockAdSense"],"unknown options are ignored");
 for(NSString *bad in @[@"",@"blockXXX+allowY",@"allowY+allowY",@"allowY+",@"+allowY",@"Default+allowY",@"allowY+bogus",@"../Default",@"allowY/..",@"Custom",@"MYbloXX"])CHECK(!MYBModeIDValid(bad),"malformed identifier rejected");
 CHECK(!MYBModeIDValid((id)@42)&&!MYBModeIDValid(nil),"non-strings rejected");
 CHECK([MYBModeSummary(@"Default")isEqual:@"Default"]&&[MYBModeSummary(@"blockAdSense+blockXXX")isEqual:@"Default + blockAdSense + noXXX"],"summary reads Default + options");
 CHECK([MYBModeName(@"allowY+blockApple")isEqual:@"Default + allowY! + noApple"]&&[MYBModeName(@"blockXXX")isEqual:@"noXXX"],"display names");
 // saved-mode migration: identity for current ids, history and labels mapped, junk refused, nothing guessed
 for(NSString *i in ids)CHECK([MYBMigrateModeID(i)isEqual:i],"a current identifier migrates to itself");
 NSDictionary *hist=@{@"MYbloXX":@"Default",@"MYbloXXTest":@"Default",@"MYbloXXallowFB":@"Default",@"MYbloXXnoFB":@"Default",@"MYbloXXallowY":@"allowY",@"MYbloXXnoApple":@"blockApple",@"MYbloXXnoSocials":@"blockSocials",@"MYbloXXnoXXX":@"blockXXX",
  @"noXXX":@"blockXXX",@"allowY!":@"allowY",@"noApple":@"blockApple",@"noSocials":@"blockSocials",@"blockXXX+allowY":@"allowY+blockXXX",@"noXXX, allowY!":@"allowY+blockXXX",@"Default + blockAdSense + noXXX":@"blockAdSense+blockXXX",@" Default ":@"Default",@"Custom":@"Custom"};
 for(NSString *k in hist)CHECK([MYBMigrateModeID(k)isEqual:hist[k]],"historical value maps to its current identifier");
 for(id bad in @[@"",@"../Default",@"allowY+bogus",@"Safari",@"blockXXX/../x",@42,[NSNull null]])CHECK(MYBMigrateModeID(bad)==nil,"unknown or hostile saved mode is refused");
 CHECK(MYBMigrateModeID([@"" stringByPaddingToLength:200 withString:@"a" startingAtIndex:0])==nil,"overlong saved mode refused");
 if(failures){fprintf(stderr,"%d option check(s) FAILED\n",failures);return 1;}
 printf("Option identifier checks passed.\n");
}return 0;}
