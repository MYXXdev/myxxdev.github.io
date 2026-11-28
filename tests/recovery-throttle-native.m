#import <Foundation/Foundation.h>
#define MYB_SHIELD_TESTING 1
double gMYBShieldWall=0,gMYBShieldMono=0;NSString *gMYBShieldBoot=nil;
#import "../Shared/MYBRecoveryThrottle.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static void Clock(double wall,double mono,NSString *boot){gMYBShieldWall=wall;gMYBShieldMono=mono;gMYBShieldBoot=boot;}
// One simulated "something deleted the target" event: the watcher asks for a recovery; if allowed, the recovery
// succeeds (re-creates the target and restarts configd). Returns whether configd was restarted.
static BOOL Deletion(NSString *path){return MYBRecoveryTake(path,3,600,NULL);}
int main(void){@autoreleasepool{
 NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@"/InlineRecovery.plist"]];
 Clock(1000000,5000,@"boot-A");
 int restarts=0;for(int i=0;i<30;i++)if(Deletion(path))restarts++;
 CHECK(restarts==3,"a target deleted 30 times causes only 3 successful recoveries (restarts) in the window");
 CHECK([NSFileManager.defaultManager fileExistsAtPath:path],"the counter survives a successful recovery (it is not deleted)");
 Clock(1000000+300,5000+300,@"boot-A");CHECK(!Deletion(path),"still limited inside the 10-minute window");
 Clock(1000000-86400,5000+400,@"boot-A");CHECK(!Deletion(path),"moving the wall clock back does not reopen the window");
 Clock(1000000+601,5000+601,@"boot-A");restarts=0;for(int i=0;i<30;i++)if(Deletion(path))restarts++;
 CHECK(restarts==3,"after the window ends a new window allows 3 more, no more");
 Clock(1000000+605,5000+605,@"boot-B");restarts=0;for(int i=0;i<10;i++)if(Deletion(path))restarts++;
 CHECK(restarts==3,"a new boot starts a fresh bounded window");
 int n=0;Clock(2000000,9000,@"boot-C");MYBRecoveryTake(path,3,600,&n);CHECK(n==1,"attempt count reported");
 [NSFileManager.defaultManager removeItemAtPath:path.stringByDeletingLastPathComponent error:NULL];
 if(failures){fprintf(stderr,"%d recovery throttle check(s) FAILED\n",failures);return 1;}
 printf("Recovery throttle checks passed (repeated successful recreations are bounded).\n");
}return 0;}
