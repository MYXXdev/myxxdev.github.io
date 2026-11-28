// Loader filters (Shared/MYBAdsFilter.h): the shared dylibs load only where they are wanted, never through com.apple.UIKit.
#import <Foundation/Foundation.h>
#import "../Shared/MYBAdsFilter.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{
 NSArray *base=MYBAdsFilterBundles(@{});
 CHECK(base.count>=20&&![base containsObject:@"com.apple.UIKit"],"the shipped filter is the catalogue apps and never com.apple.UIKit");
 CHECK([base containsObject:@"com.google.ios.youtube"]&&[base containsObject:@"tv.danmaku.bilianime"]&&[base containsObject:@"com.apple.AppStore"],"catalogue apps (including discovery-only App Store) stay in the filter");
 NSArray *sel=MYBAdsFilterBundles(@{@"ads-sdk-com.example.game":@YES,@"ads-sdk-com.example.off":@NO});
 CHECK([sel containsObject:@"com.example.game"]&&![sel containsObject:@"com.example.off"]&&sel.count==base.count+1,"exactly the apps switched on are added");
 CHECK([MYBAdsFilterBundles(@{@"ads-sdk-com.apple.mobilesafari":@YES,@"ads-sdk-net.myxxdev.x":@YES,@"ads-sdk-__x.y":@YES,@"ads-sdk-bad id!":@YES,@"ads-sdk-nodots":@YES}) isEqual:base],"system apps, MYbloXX's own, malformed ids and non-booleans are never added");
 CHECK([MYBAdsFilterBundles(@{@"ads-sdk-com.example.game":@"yes"}) isEqual:base],"only a real boolean YES selects an app");
 NSMutableDictionary *many=[NSMutableDictionary dictionary];for(int i=0;i<200;i++)many[[NSString stringWithFormat:@"ads-sdk-com.example.a%d",i]]=@YES;
 CHECK(MYBAdsFilterBundles(many)==nil,"an unbounded selection is refused rather than written");
 NSData *plist=MYBAdsFilterPlist(sel);NSDictionary *back=[NSPropertyListSerialization propertyListWithData:plist options:0 format:NULL error:NULL];
 CHECK([back[@"Filter"][@"Bundles"] isEqual:sel]&&[back[@"Filter"] count]==1,"the file is a plain loader filter (Filter/Bundles) and nothing more");
 CHECK(MYBAdsFilterMatches(plist,@{@"ads-sdk-com.example.game":@YES})&&!MYBAdsFilterMatches(plist,@{}),"a filter on disk is accepted only if it matches the preferences");
 CHECK(MYBAdsFilterPlist(@[])==nil&&MYBAdsFilterPlist(nil)==nil,"an empty list is never written");
 // Speedy Ads (App Control)
 NSArray *none=MYBSpeedyFilterBundles(@{});CHECK(none.count==1&&[none[0] isEqual:MYB_NO_APP_SENTINEL],"nothing selected: one identifier no app has, so it loads nowhere");
 NSArray *ac=MYBSpeedyFilterBundles(@{@"enabled-com.example.a":@YES,@"enabled-com.example.b":@NO,@"enabled-com.apple.springboard":@YES,@"enabled-__x.y":@YES});
 CHECK([ac isEqual:@[@"com.example.a"]],"only the apps selected in App Control (never SpringBoard) load it");
 CHECK([MYBSpeedyFilterBundles(@{@"enabled-com.example.a":@YES,@"Uninstalling":@YES}) isEqual:@[MYB_NO_APP_SENTINEL]],"while uninstalling the service switch is off and nothing is loaded");
 CHECK(![ac containsObject:@"com.apple.UIKit"],"Speedy Ads never names com.apple.UIKit");

 // ---- installed apps only; add and remove a selected app -----------------------------------------------------------------------------
 {
  NSDictionary *prefs=@{@"ads-sdk-com.example.game":@YES,@"ads-sdk-com.example.gone":@YES};
  NSSet *installed=[NSSet setWithObjects:@"com.example.game",@"com.example.other",nil];
  NSArray *f=MYBAdsFilterBundlesInstalled(prefs,installed);
  CHECK([f containsObject:@"com.example.game"]&&![f containsObject:@"com.example.gone"],"a selected app that is not installed is left out");
  CHECK([MYBAdsFilterDroppedApps(prefs,installed) isEqual:@[@"com.example.gone"]],"and is reported as dropped");
  CHECK([MYBAdsFilterBundlesInstalled(prefs,nil) containsObject:@"com.example.gone"]&&[MYBAdsFilterDroppedApps(prefs,nil) count]==0,"when the device could not be inspected the selection is used as saved");
  CHECK(![MYBAdsFilterBundlesInstalled(@{@"ads-sdk-com.example.other":@NO},installed) containsObject:@"com.example.other"],"removing a selection removes the app from the filter");
  CHECK(![MYBAdsFilterBundlesInstalled(@{@"ads-sdk-com.apple.mobilesafari":@YES},[NSSet setWithObject:@"com.apple.mobilesafari"]) containsObject:@"com.apple.mobilesafari"],"a system app is never added even if installed");
 }
 // ---- writing: atomic, correct mode, interrupted and failed writes leave the old filter ----------------------------------------------
 {
  NSString *dir=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
  NSString *file=[dir stringByAppendingPathComponent:@"F.plist"];NSMutableArray *log=[NSMutableArray array];void(^lg)(NSString *)=^(NSString *m){[log addObject:m];};
  NSData *v1=MYBAdsFilterPlist(@[@"com.example.a",@"com.example.b"]),*v2=MYBAdsFilterPlist(@[@"com.example.a",@"com.example.c"]);
  CHECK(MYBAdsFilterWriteFile(dir,@"F.plist",v1,getuid(),getgid(),lg)==0&&[[NSData dataWithContentsOfFile:file] isEqual:v1],"a first write succeeds and is read back");
  struct stat st;stat(file.fileSystemRepresentation,&st);CHECK((st.st_mode&07777)==0644,"the filter is 0644");
  for(int fault=1;fault<=4;fault++){
   MYBAdsFilterFault=fault;int rc=MYBAdsFilterWriteFile(dir,@"F.plist",v2,getuid(),getgid(),lg);MYBAdsFilterFault=0;
   CHECK(rc==(fault==3||fault==4?74:73),"each failing step is reported with its own code");
   if(fault<=2)CHECK([[NSData dataWithContentsOfFile:file] isEqual:v1]&&![NSFileManager.defaultManager fileExistsAtPath:[file stringByAppendingString:@".new"]],"a failed or interrupted write keeps the previous filter and leaves no side file");
   // a mismatching result is repaired by the next write, which rewrites the filter and its mode
   CHECK(MYBAdsFilterWriteFile(dir,@"F.plist",v1,getuid(),getgid(),lg)==0&&[[NSData dataWithContentsOfFile:file] isEqual:v1],"the next write restores the right contents");stat(file.fileSystemRepresentation,&st);CHECK((st.st_mode&07777)==0644,"and the right mode");
  }
  [@"stale" writeToFile:[file stringByAppendingString:@".new"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
  CHECK(MYBAdsFilterWriteFile(dir,@"F.plist",v2,getuid(),getgid(),lg)==0&&[[NSData dataWithContentsOfFile:file] isEqual:v2]&&![NSFileManager.defaultManager fileExistsAtPath:[file stringByAppendingString:@".new"]],"a side file left by an interrupted write is discarded");
  chmod(file.fileSystemRepresentation,0600);CHECK(MYBAdsFilterWriteFile(dir,@"F.plist",v2,getuid(),getgid(),lg)==0,"correct contents but wrong mode is rewritten");stat(file.fileSystemRepresentation,&st);CHECK((st.st_mode&07777)==0644,"mode is back to 0644");
  CHECK(MYBAdsFilterWriteFile(dir,@"F.plist",nil,getuid(),getgid(),lg)==71&&MYBAdsFilterWriteFile([dir stringByAppendingString:@"/missing"],@"F.plist",v1,getuid(),getgid(),lg)==72,"no data and a missing folder are refused without touching anything");
  [NSFileManager.defaultManager removeItemAtPath:dir error:NULL];
 }
 // ---- the report ----------------------------------------------------------------------------------------------------------------------
 {
  NSDictionary *prefs=@{@"ads-sdk-com.example.game":@YES};NSSet *inst=[NSSet setWithObject:@"com.example.game"];
  NSData *good=MYBAdsFilterPlist(MYBAdsFilterBundlesInstalled(prefs,inst));
  NSString *r=MYBAdsFilterReport(prefs,good,inst,@{},@"0644");
  CHECK([r containsString:@"Names com.apple.UIKit: no"]&&[r containsString:@"Matches the saved choices: yes"]&&[r containsString:@"in filter: yes"]&&[r containsString:@"library not seen loading yet"],"the report says the app is in the filter but has not been seen loading");
  r=MYBAdsFilterReport(prefs,good,inst,@{@"com.example.game":@{}},@"0644");CHECK([r containsString:@"library has loaded in it"],"and says so once the app reported");
  r=MYBAdsFilterReport(prefs,MYBAdsFilterPlist(@[@"com.apple.UIKit"]),inst,@{},nil);CHECK([r containsString:@"YES (wrong)"]&&[r containsString:@"NO"],"a UIKit or stale filter is called out");
 }
 if(failures){fprintf(stderr,"%d ads-filter check(s) FAILED\n",failures);return 1;}
 printf("Loader filter checks passed.\n");
}return 0;}
