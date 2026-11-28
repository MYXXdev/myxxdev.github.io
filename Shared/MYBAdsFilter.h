#pragma once
// Which processes load the shared In-App Ad Blocking dylib (MYBInAppAds.dylib).
//
// The loader reads the dylib's filter plist (MYBInAppAds.plist, beside the dylib) when a process starts. A filter that names com.apple.UIKit
// loads the library into EVERY process that links UIKit, whether or not anything in it is wanted there: an early return in the constructor
// prevents hooks, not the load. The supported alternative is a static filter that names exactly the processes that need it. This file builds
// that filter: the catalogue apps plus exactly the apps the person switched on under Ad Network Blocking. The root helper writes it (action
// "adsfilter") when a switch changes and after an install or upgrade. com.apple.UIKit is never in it.
#import <Foundation/Foundation.h>
#import "MYBInAppAds.h"
#import "MYBAdSDK.h"
#import "MYBAppControl.h"
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>
#define MYB_ADS_FILTER_MAX 600
static inline BOOL MYBAdsFilterBundleValid(NSString *b){
 if(![b isKindOfClass:NSString.class]||b.length<3||b.length>200||![b containsString:@"."])return NO;
 if([b hasPrefix:@"com.apple."]||[b hasPrefix:@"net.myxxdev."]||[b hasPrefix:@"__"])return NO;
 NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"].invertedSet;
 return [b rangeOfCharacterFromSet:bad].location==NSNotFound;
}
// The apps switched on under Ad Network Blocking, read from the saved preferences (same rule the dylib applies, MYBAdSDKSelected).
static inline NSArray<NSString *> *MYBAdsFilterSelectedApps(NSDictionary *prefs){
 NSMutableSet *out=[NSMutableSet set];
 if([prefs isKindOfClass:NSDictionary.class])for(NSString *key in prefs){
  if(![key isKindOfClass:NSString.class]||![key hasPrefix:MYB_ADSDK_PREFIX])continue;
  NSString *bundle=[key substringFromIndex:MYB_ADSDK_PREFIX.length];
  if(MYBAdsFilterBundleValid(bundle)&&MYBAdSDKSelected(prefs,bundle))[out addObject:bundle];
 }
 return [[out allObjects] sortedArrayUsingSelector:@selector(compare:)];
}
// Catalogue bundle ids (exact apps) + selected apps, unique and sorted. Returns nil when it would exceed the bound.
static inline NSArray<NSString *> *MYBAdsFilterBundles(NSDictionary *prefs){
 NSMutableSet *all=[NSMutableSet set];
 for(NSDictionary *entry in MYBAdsCatalogue())for(NSString *b in entry[@"bundles"])if([b isKindOfClass:NSString.class])[all addObject:b];
 [all addObjectsFromArray:MYBAdsFilterSelectedApps(prefs)];
 [all removeObject:@"com.apple.UIKit"]; // never: it loads the library into every UIKit process
 if(all.count>MYB_ADS_FILTER_MAX)return nil;
 return [[all allObjects] sortedArrayUsingSelector:@selector(compare:)];
}
// Selected apps are kept only if they are really installed. `installed` is the set of bundle identifiers found on the device, or nil when the
// device could not be inspected: then the selection is used as it is (the person's switch is not discarded because a scan failed) and the
// caller records that nothing was verified. Catalogue apps stay: they are a fixed, known list, and an app that is not installed simply never loads it.
static inline NSArray<NSString *> *MYBAdsFilterBundlesInstalled(NSDictionary *prefs,NSSet<NSString *> *installed){
 NSMutableSet *all=[NSMutableSet set];
 for(NSDictionary *entry in MYBAdsCatalogue())for(NSString *b in entry[@"bundles"])if([b isKindOfClass:NSString.class])[all addObject:b];
 for(NSString *b in MYBAdsFilterSelectedApps(prefs))if(!installed||[installed containsObject:b])[all addObject:b];
 // Every installed app is on unless the person switched it off (MYBAdSDKSelected), so apps installed later are covered as soon as the list is refreshed.
 for(NSString *b in installed)if(MYBAdsFilterBundleValid(b)&&MYBAdSDKSelected(prefs,b))[all addObject:b];
 [all removeObject:@"com.apple.UIKit"];
 if(all.count>MYB_ADS_FILTER_MAX)return nil;
 return [[all allObjects] sortedArrayUsingSelector:@selector(compare:)];
}
// Selected apps that were dropped because they are not installed (shown in diagnostics).
static inline NSArray<NSString *> *MYBAdsFilterDroppedApps(NSDictionary *prefs,NSSet<NSString *> *installed){
 if(!installed)return @[];NSMutableArray *out=[NSMutableArray array];for(NSString *b in MYBAdsFilterSelectedApps(prefs))if(![installed containsObject:b])[out addObject:b];return out;
}
static inline NSData *MYBAdsFilterPlist(NSArray<NSString *> *bundles){
 if(![bundles isKindOfClass:NSArray.class]||!bundles.count)return nil;
 return [NSPropertyListSerialization dataWithPropertyList:@{@"Filter":@{@"Bundles":bundles}} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
}
// A filter on disk is acceptable only if it is exactly what the current preferences call for.
static inline BOOL MYBAdsFilterMatches(NSData *onDisk,NSDictionary *prefs){
 NSData *want=MYBAdsFilterPlist(MYBAdsFilterBundles(prefs));if(!want||!onDisk)return NO;
 NSDictionary *a=[NSPropertyListSerialization propertyListWithData:onDisk options:0 format:NULL error:NULL],*b=[NSPropertyListSerialization propertyListWithData:want options:0 format:NULL error:NULL];
 return [a isKindOfClass:NSDictionary.class]&&[a isEqual:b];
}

// ---- Speedy Ads (App Control acceleration): the same rule. Its library used to name com.apple.UIKit too. ---------------------------------
// It is wanted only in the apps the person selected in App Control ("enabled-<bundle id>" in the speedyads preferences, honouring the same
// service switch the library applies). With nothing selected the filter names one identifier that no app has, so the library loads nowhere.
#define MYB_NO_APP_SENTINEL @"net.myxxdev.mybloxx.no-app-selected"
static inline BOOL MYBLoaderBundleSyntax(NSString *b){
 if(![b isKindOfClass:NSString.class]||b.length<3||b.length>200||![b containsString:@"."])return NO;
 NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"].invertedSet;
 return [b rangeOfCharacterFromSet:bad].location==NSNotFound;
}
static inline NSArray<NSString *> *MYBSpeedyFilterBundles(NSDictionary *prefs){
 NSMutableSet *out=[NSMutableSet set];
 if([prefs isKindOfClass:NSDictionary.class])for(NSString *key in prefs){
  if(![key isKindOfClass:NSString.class]||![key hasPrefix:@"enabled-"]||key.length<=8)continue;
  NSString *bundle=[key substringFromIndex:8];
  if(MYBLoaderBundleSyntax(bundle)&&MYBAppControlSelected(prefs,bundle))[out addObject:bundle];
 }
 if(!out.count)return @[MYB_NO_APP_SENTINEL];
 if(out.count>MYB_ADS_FILTER_MAX)return nil;
 return [[out allObjects] sortedArrayUsingSelector:@selector(compare:)];
}
// App Lock and Private Previews: only the apps the person chose (locked or preview-hidden), a sentinel when none. Never com.apple.UIKit.
static inline NSArray<NSString *> *MYBCoverFilterBundles(NSDictionary *cfg){
 NSMutableSet *out=[NSMutableSet set];
 if([cfg isKindOfClass:NSDictionary.class])for(NSString *key in @[@"AppLockApps",@"AppLockPreviewApps"]){
  NSArray *l=cfg[key];if(![l isKindOfClass:NSArray.class])continue;
  for(id b in l)if(MYBLoaderBundleSyntax(b)&&![b hasPrefix:@"com.apple.Preferences"]&&![b isEqual:@"com.apple.springboard"])[out addObject:b];
 }
 if(!out.count)return @[MYB_NO_APP_SENTINEL];
 if(out.count>MYB_ADS_FILTER_MAX)return nil;
 return [[out allObjects] sortedArrayUsingSelector:@selector(compare:)];
}
// MYXX Reserve adjusted percentage: SpringBoard always; the installed apps (so the in-app status bar matches) only while the person has the adjusted percentage on.
// Never com.apple.UIKit. Too many apps for one filter: SpringBoard only (the caller logs it).
static inline NSArray<NSString *> *MYBReserveDisplayBundles(BOOL spoofOn,NSSet<NSString *> *installed){
 NSMutableSet *out=[NSMutableSet setWithObject:@"com.apple.springboard"];
 if(spoofOn)for(NSString *b in installed)if(MYBLoaderBundleSyntax(b)&&![b isEqual:@"com.apple.UIKit"])[out addObject:b];
 if(out.count>MYB_ADS_FILTER_MAX)return @[@"com.apple.springboard"];
 return [[out allObjects] sortedArrayUsingSelector:@selector(compare:)];
}
static inline BOOL MYBFilterDataMatches(NSData *onDisk,NSData *want){
 if(!want||!onDisk)return NO;
 NSDictionary *a=[NSPropertyListSerialization propertyListWithData:onDisk options:0 format:NULL error:NULL],*b=[NSPropertyListSerialization propertyListWithData:want options:0 format:NULL error:NULL];
 return [a isKindOfClass:NSDictionary.class]&&[a isEqual:b];
}

// ---- writing a filter safely ----------------------------------------------------------------------------------------------------------
// The new filter is written to a side file, flushed, given the right owner and mode, moved over the old one in one step and read back (contents,
// mode and owner). Any failure removes the side file and leaves the previous filter exactly as it was. MYBAdsFilterFault lets tests make each
// step fail. Returns 0 on success (or when the filter is already right), 71 no data, 72 folder missing, 73 write/replace failed, 74 read-back mismatch.
static int MYBAdsFilterFault; // 0 none, 1 write fails, 2 replace fails, 3 contents wrong after replace, 4 mode wrong after replace
static inline int MYBAdsFilterWriteFile(NSString *folder,NSString *name,NSData *data,uid_t owner,gid_t group,void(^log)(NSString *)){
 NSString *path=[folder stringByAppendingPathComponent:name],*tmp=[path stringByAppendingString:@".new"];
 if(!data){if(log)log(@"too many apps selected; left as it was");return 71;}
 BOOL isDir=NO;if(![NSFileManager.defaultManager fileExistsAtPath:folder isDirectory:&isDir]||!isDir){if(log)log(@"the loader folder is missing; nothing written");return 72;}
 if(MYBFilterDataMatches([NSData dataWithContentsOfFile:path],data)){
  struct stat st;if(stat(path.fileSystemRepresentation,&st)==0&&(st.st_mode&07777)==0644)return 0; // already right, including its mode
 }
 unlink(tmp.fileSystemRepresentation); // a side file left by an interrupted earlier write
 int fd=MYBAdsFilterFault==1?-1:open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_TRUNC,0644);
 if(fd<0){if(log)log(@"could not create the new filter");return 73;}
 BOOL wrote=write(fd,data.bytes,data.length)==(ssize_t)data.length&&fsync(fd)==0;close(fd);
 if(!wrote){unlink(tmp.fileSystemRepresentation);if(log)log(@"could not write the new filter");return 73;}
 if(geteuid()==0)chown(tmp.fileSystemRepresentation,owner,group);
 chmod(tmp.fileSystemRepresentation,0644);
 if(MYBAdsFilterFault==2||rename(tmp.fileSystemRepresentation,path.fileSystemRepresentation)!=0){unlink(tmp.fileSystemRepresentation);if(log)log(@"could not replace the filter");return 73;}
 if(MYBAdsFilterFault==4)chmod(path.fileSystemRepresentation,0666);
 NSData *back=MYBAdsFilterFault==3?[NSData dataWithBytes:"x" length:1]:[NSData dataWithContentsOfFile:path];
 struct stat st;BOOL modeOK=stat(path.fileSystemRepresentation,&st)==0&&(st.st_mode&07777)==0644&&(geteuid()!=0||(st.st_uid==owner&&st.st_gid==group));
 if(!MYBFilterDataMatches(back,data)||!modeOK){if(log)log(@"the filter on disk is not what was written");return 74;}
 if(log)log(@"written");return 0;
}
// A plain-language report for one device session: what the filter holds, whether each selected app is in it, and what is missing.
static inline NSString *MYBAdsFilterReport(NSDictionary *prefs,NSData *onDisk,NSSet<NSString *> *installed,NSDictionary<NSString *,NSDictionary *> *loaded,NSString *mode){
 NSMutableString *out=[NSMutableString string];
 NSDictionary *plist=onDisk?[NSPropertyListSerialization propertyListWithData:onDisk options:0 format:NULL error:NULL]:nil;
 NSArray *inFilter=[plist[@"Filter"][@"Bundles"] isKindOfClass:NSArray.class]?plist[@"Filter"][@"Bundles"]:nil;
 [out appendFormat:@"Loader filter: %@%@\n",inFilter?[NSString stringWithFormat:@"%lu apps",(unsigned long)inFilter.count]:@"not readable",mode.length?[@", mode " stringByAppendingString:mode]:@""];
 [out appendFormat:@"Names com.apple.UIKit: %@\n",[inFilter containsObject:@"com.apple.UIKit"]?@"YES (wrong)":@"no"];
 [out appendFormat:@"Matches the saved choices: %@\n",onDisk&&MYBAdsFilterPlist(MYBAdsFilterBundlesInstalled(prefs,installed))&&MYBFilterDataMatches(onDisk,MYBAdsFilterPlist(MYBAdsFilterBundlesInstalled(prefs,installed)))?@"yes":@"NO"];
 for(NSString *b in MYBAdsFilterSelectedApps(prefs)){
  BOOL listed=[inFilter containsObject:b],seen=loaded[b]!=nil;
  [out appendFormat:@"%@: selected; %@; in filter: %@; %@\n",b,installed?([installed containsObject:b]?@"installed":@"NOT installed"):@"installed state unknown",listed?@"yes":@"NO",seen?@"library has loaded in it (reported by the app)":@"library not seen loading yet"];
 }
 for(NSString *b in MYBAdsFilterDroppedApps(prefs,installed))[out appendFormat:@"%@: selected but not installed, left out of the filter\n",b];
 return out;
}
