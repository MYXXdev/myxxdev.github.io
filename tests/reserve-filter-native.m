// MYXX Reserve: which apps the adjusted battery percentage may load in.
#import <Foundation/Foundation.h>
#include "../Shared/MYBAdsFilter.h"
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{int failures=0;
 {NSSet *apps=[NSSet setWithObjects:@"com.apple.mobilesafari",@"com.example.game",@"com.apple.UIKit",@"bad id",nil];
  NSArray *off=MYBReserveDisplayBundles(NO,apps),*on=MYBReserveDisplayBundles(YES,apps);
  CHECK([off isEqual:@[@"com.apple.springboard"]],"adjusted percentage off: SpringBoard only, nothing in apps");
  CHECK([on containsObject:@"com.apple.springboard"]&&[on containsObject:@"com.example.game"]&&[on containsObject:@"com.apple.mobilesafari"]&&![on containsObject:@"com.apple.UIKit"]&&![on containsObject:@"bad id"]&&on.count==3,"adjusted percentage on: SpringBoard plus the installed apps, never UIKit, malformed ids dropped");
  NSMutableSet *many=[NSMutableSet set];for(int i=0;i<700;i++)[many addObject:[NSString stringWithFormat:@"com.example.app%d",i]];
  CHECK([MYBReserveDisplayBundles(YES,many) isEqual:@[@"com.apple.springboard"]],"too many apps for one filter: SpringBoard only");}
 if(failures)return 1;printf("Reserve filter checks passed.\n");}return 0;}
