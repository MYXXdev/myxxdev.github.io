// Writes the loader filters (action "adsfilter") so a library loads only where it is wanted, never through com.apple.UIKit:
//  * MYBInAppAds.plist: the catalogue apps plus exactly the apps switched on under Ad Network Blocking;
//  * MYBSpeedyAds.plist: exactly the apps selected in App Control (a sentinel when none).
// Each file is replaced atomically and read back; on any failure the previous filter is left in place and the result says so.
// Shared/MYBAdsFilter.h holds the rules (tests/ads-filter-native.m).
#include "../Shared/MYBAdsFilter.h"
static NSString *MYBLoaderFolder(void){return [MYBBootstrapRoot() stringByAppendingPathComponent:@"Library/MobileSubstrate/DynamicLibraries"];}
static int MYBWriteOneFilter(NSString *name,NSData *data){
 return MYBAdsFilterWriteFile(MYBLoaderFolder(),name,data,0,0,^(NSString *what){logLine([NSString stringWithFormat:@"ADSFILTER: %@: %@",name,what]);});
}
// Every bundle identifier found in an installed app's Info.plist (user apps and system apps), or nil if neither location could be read.
static NSSet<NSString *> *MYBInstalledBundleIDs(void){
 NSMutableSet *out=[NSMutableSet set];BOOL scanned=NO;
 NSString *user=@"/var/containers/Bundle/Application";
 NSArray *dirs=[FM() contentsOfDirectoryAtPath:user error:NULL];if(dirs){scanned=YES;
  for(NSString *d in dirs){NSString *base=[user stringByAppendingPathComponent:d];
   for(NSString *app in [FM() contentsOfDirectoryAtPath:base error:NULL])if([app hasSuffix:@".app"]){
    NSString *bid=[NSDictionary dictionaryWithContentsOfFile:[[base stringByAppendingPathComponent:app] stringByAppendingPathComponent:@"Info.plist"]][@"CFBundleIdentifier"];
    if(MYBAdsFilterBundleValid(bid))[out addObject:bid];}}}
 return scanned&&out.count?out:nil;
}
// Apps for the Reserve percentage: user apps, system apps in /Applications and jailbreak apps; nil if nothing could be listed.
static NSSet<NSString *> *MYBAllInstalledBundleIDs(void){
 NSMutableSet *out=[NSMutableSet setWithSet:MYBInstalledBundleIDs()?:[NSSet set]];BOOL scanned=out.count>0;
 for(NSString *root in @[@"/Applications",[MYBBootstrapRoot() stringByAppendingPathComponent:@"Applications"]]){
  NSArray *apps=[FM() contentsOfDirectoryAtPath:root error:NULL];if(apps)scanned=YES;
  for(NSString *app in apps)if([app hasSuffix:@".app"]){
   NSString *bid=[NSDictionary dictionaryWithContentsOfFile:[[root stringByAppendingPathComponent:app] stringByAppendingPathComponent:@"Info.plist"]][@"CFBundleIdentifier"];
   if(MYBAdsFilterBundleValid(bid))[out addObject:bid];}}
 return scanned&&out.count?out:nil;
}
static NSDictionary *MYBReadPrefsFile(NSString *logical){NSString *p=MYBDataPath(logical);return p.length?[NSDictionary dictionaryWithContentsOfFile:p]:nil;} // missing file: nothing selected
static int MYBWriteAdsFilter(void){
 NSDictionary *ads=MYBReadPrefsFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.inappads.plist")?:@{};
 NSDictionary *speedy=MYBReadPrefsFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist")?:@{};
 NSArray *speedyBundles=MYBSpeedyFilterBundles(speedy);
 NSSet *installed=MYBInstalledBundleIDs();if(!installed)logLine(@"ADSFILTER: installed apps could not be listed; the selection is used as saved");
 NSArray *coverBundles=MYBCoverFilterBundles(MYBReadPrefsFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.applock.plist")?:@{});
 NSDictionary *reserve=MYBReadPrefsFile(@"/var/mobile/Library/Preferences/com.myxxdev.reserve.plist")?:@{};
 BOOL spoofOn=[reserve[@"spoofPercent"] boolValue]&&(reserve[@"enabled"]==nil||[reserve[@"enabled"] boolValue]);
 NSSet *allApps=spoofOn?MYBAllInstalledBundleIDs():nil;if(spoofOn&&!allApps)logLine(@"ADSFILTER: apps could not be listed; the adjusted percentage stays in SpringBoard only");
 int d=MYBWriteOneFilter(@"MYXXReserveDisplay.plist",MYBAdsFilterPlist(MYBReserveDisplayBundles(spoofOn,allApps)));
 int a=MYBWriteOneFilter(@"MYBInAppAds.plist",MYBAdsFilterPlist(MYBAdsFilterBundlesInstalled(ads,installed)));
 int b=MYBWriteOneFilter(@"MYBSpeedyAds.plist",speedyBundles?MYBAdsFilterPlist(speedyBundles):nil);
 int c=MYBWriteOneFilter(@"MYBPrivacyCover.plist",coverBundles?MYBAdsFilterPlist(coverBundles):nil);
 return a?a:(b?b:(c?c:d));
}
