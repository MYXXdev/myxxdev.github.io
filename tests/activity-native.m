#import <Foundation/Foundation.h>
#define MYB_RULE_TESTING 1
#define MYB_SHIELD_TESTING 1
double gMYBShieldWall=0,gMYBShieldMono=0;NSString *gMYBShieldBoot=nil;
#import "../Shared/MYBActivityLog.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",root.UTF8String,1);
 gMYBShieldWall=1000000;gMYBShieldMono=5000;gMYBShieldBoot=@"boot-A";
 NSString *file=MYBActivityFile();
 CHECK(MYBActivityEnabled(),"always on");
 CHECK([MYBActivityHost(@"Ads.Example.COM:443")isEqual:@"ads.example.com"],"port dropped, lowercased");
 CHECK(MYBActivityHost(@"https://x.example/path")==nil,"a URL is not a host");
 CHECK(MYBActivityHost(@"[::1]:443")==nil,"IPv6 literal rejected");
 CHECK(MYBActivityHost(@"nodots")==nil,"single label rejected");
 CHECK(MYBActivityHost(@"a..b.com")==nil,"empty label rejected");
 CHECK(MYBActivityHost(@"a b.com")==nil,"space rejected");
 MYBActivityMerge(file,@{@"a.example.com":@{@"b":@3,@"a":@1,@"apps":@{@"Alpha":@{@"b":@2,@"a":@1},@"Beta":@{@"b":@1,@"a":@0}}},@"b.example.com":@{@"b":@1,@"a":@0,@"apps":@{@"Unknown app":@{@"b":@1,@"a":@0}}}},@{@"Alpha":@"com.example.alpha"},1000000);
 gMYBShieldWall=1000100;MYBActivityMerge(file,@{@"a.example.com":@{@"b":@2,@"a":@0,@"apps":@{@"Alpha":@{@"b":@2,@"a":@0}}}},nil,1000100);
 NSArray *list=MYBActivityList(file,1000200);
 CHECK(list.count==2&&[list[0][@"host"] isEqual:@"a.example.com"]&&[list[0][@"b"] integerValue]==5&&[list[0][@"a"] integerValue]==1,"blocked and allowed counts add up, newest first");
 NSDictionary *apps=list[0][@"apps"];CHECK([apps[@"Alpha"][@"b"] integerValue]==4&&[apps[@"Alpha"][@"a"] integerValue]==1&&[apps[@"Beta"][@"b"] integerValue]==1,"per-app blocked and allowed counts add up");
 NSArray *byApp=MYBActivityApps(list);CHECK(byApp.count==3&&[byApp[0][@"name"] isEqual:@"Alpha"]&&[byApp[0][@"sites"] integerValue]==1&&[byApp[0][@"b"] integerValue]==4,"apps summarised busiest first");
 CHECK([MYBActivityAppIDs(file)[@"Alpha"] isEqual:@"com.example.alpha"],"bundle id kept for the icon");
 CHECK([list[0][@"first"] doubleValue]==1000000&&[list[0][@"last"] doubleValue]==1000100,"first and last kept");
 CHECK(MYBActivityList(file,1000000+MYB_ACTIVITY_MAX_AGE+500).count==0,"entries older than 24 hours are not listed");
 MYBActivityMerge(file,@{@"c.example.com":@{@"b":@1,@"a":@0,@"apps":@{@"Alpha":@{@"b":@1,@"a":@0}}}},nil,1000000+MYB_ACTIVITY_MAX_AGE+500);
 CHECK(MYBActivityList(file,1000000+MYB_ACTIVITY_MAX_AGE+600).count==1,"old entries pruned on write");
 MYBActivityPrune(file,1000000+MYB_ACTIVITY_MAX_AGE*3);
 CHECK(![NSFileManager.defaultManager fileExistsAtPath:file],"prune removes the file once everything is older than 24 hours");
 MYBActivityMerge(file,@{@"a.example.com":@{@"b":@1,@"a":@0,@"apps":@{@"Alpha":@{@"b":@1,@"a":@0}}}},nil,1500000);
 NSMutableDictionary<NSString *,NSDictionary *> *many=[NSMutableDictionary dictionary];for(int i=0;i<400;i++)many[[NSString stringWithFormat:@"h%d.example.com",i]]=@{@"b":@1,@"a":@0,@"apps":@{@"Alpha":@{@"b":@1,@"a":@0}}};
 MYBActivityMerge(file,many,nil,2000000);
 CHECK(MYBActivityList(file,2000001).count==MYB_ACTIVITY_MAX_HOSTS,"capped at 300 hosts");
 NSString *raw=[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:NULL];
 CHECK(MYBActivityClear(file)&&![NSFileManager.defaultManager fileExistsAtPath:file],"Clear List Now deletes the list");
 if(failures){fprintf(stderr,"%d failures\n",failures);return 1;}puts("Activity log native checks passed.");
}return 0;}
