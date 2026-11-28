#pragma once
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <errno.h>
#import "MYBSupervisionKeys.h"

// Only touch the known original iOS configuration file. Never synthesize
// directories or overwrite a configuration belonging to another owner.
static inline BOOL MYBSupervisionParentSafe(NSString *path) {
 NSString *parent=[path stringByDeletingLastPathComponent];
 struct stat st={0};
 return lstat(parent.fileSystemRepresentation,&st)==0 &&
        S_ISDIR(st.st_mode) && !S_ISLNK(st.st_mode);
}
static inline BOOL MYBSupervisionContainerSafe(NSString *path){
 if(![path.lastPathComponent isEqual:@"CloudConfigurationDetails.plist"]||![path.stringByDeletingLastPathComponent.lastPathComponent isEqual:@"ConfigurationProfiles"])return NO;
 NSString *library=path.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
 if(![library.lastPathComponent isEqual:@"Library"])return NO;
 NSString *group=library.stringByDeletingLastPathComponent;struct stat st;
 NSDictionary *meta=[NSDictionary dictionaryWithContentsOfFile:[group stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
 if(lstat(group.fileSystemRepresentation,&st)==0 && S_ISDIR(st.st_mode) && !S_ISLNK(st.st_mode) && [meta[@"MCMMetadataIdentifier"] isEqual:@"systemgroup.com.apple.configurationprofiles"])return YES;
 // Original MYbloXX/defaults fallback, only at Apple's fixed named group.
 return [group isEqual:@"/var/containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles"] &&
 lstat(group.stringByDeletingLastPathComponent.fileSystemRepresentation,&st)==0 && S_ISDIR(st.st_mode) && !S_ISLNK(st.st_mode);
}
static inline BOOL MYBEnsureSupervisionParent(NSString *path){
 if(MYBSupervisionParentSafe(path))return YES;
 if(!MYBSupervisionContainerSafe(path))return NO;
 NSString *group=path.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
 for(NSString *part in @[group,[group stringByAppendingPathComponent:@"Library"],path.stringByDeletingLastPathComponent]){struct stat st;if(lstat(part.fileSystemRepresentation,&st)==0 && (!S_ISDIR(st.st_mode)||S_ISLNK(st.st_mode)))return NO;}
 return [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:NULL]&&MYBSupervisionParentSafe(path);
}
static inline NSDictionary *MYBSupervisionStatus(NSString *path,NSString *record) {
 NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:path];
 NSDictionary *r=[NSDictionary dictionaryWithContentsOfFile:record];
 BOOL ours=[r[@"owner"] isEqualToString:@"net.myxxdev.mybloxx"];
 BOOL available=[d isKindOfClass:NSDictionary.class] || MYBSupervisionParentSafe(path) || MYBSupervisionContainerSafe(path);
 BOOL enabled=[d[@"IsSupervised"] boolValue];
 return @{@"available":@(available),@"supervised":@(enabled),
          @"owned":@(ours && enabled),
          @"managed":@(MYBSupervisionHasManagementKeys(d)), // an organisation, enrolment or MDM key is present; lets Settings decide without reading the system file itself
          @"creatable":@(!d && MYBSupervisionParentSafe(path)),
          @"parentExists":@(MYBSupervisionParentSafe(path))};
}
// Fresh-install default: turn MYbloXX®'s supervision feature on only where that changes nothing that belongs to someone else. Eligible means the
// device is not supervised, no record of ours exists yet, and the iOS configuration file is absent (and can be created safely) or holds only
// iOS bookkeeping. An organisation, enrolment or MDM key means the device is managed and is left exactly as it is. reason (optional) says why not, in a few words, for the log.
static inline BOOL MYBSupervisionEligibleForDefault(NSString *path,NSString *record,NSString **reason){
 NSString *why=nil;NSFileManager *fm=NSFileManager.defaultManager;struct stat st={0};BOOL exists=lstat(path.fileSystemRepresentation,&st)==0;
 NSDictionary *details=exists?[NSDictionary dictionaryWithContentsOfFile:path]:nil;
 if([fm fileExistsAtPath:record])why=@"a MYbloXX supervision record already exists";
 else if(exists&&![details isKindOfClass:NSDictionary.class])why=@"the iOS configuration file can't be read";
 else if([details[@"IsSupervised"] boolValue])why=@"the device is already supervised";
 else if(MYBSupervisionHasManagementKeys(details))why=@"the device has an organisation or management configuration";
 else if(!exists&&!(MYBSupervisionParentSafe(path)||MYBSupervisionContainerSafe(path)))why=@"the iOS configuration folder is not available";
 if(reason)*reason=why;return why==nil;
}
static inline int MYBChangeSupervision(BOOL enable,NSString *path,NSString *record) {
 NSFileManager *fm=NSFileManager.defaultManager;
 if(enable?!MYBEnsureSupervisionParent(path):!MYBSupervisionParentSafe(path))return 74;
 struct stat st={0};
 BOOL exists=lstat(path.fileSystemRepresentation,&st)==0;
 if(exists && (!S_ISREG(st.st_mode) || S_ISLNK(st.st_mode)))return 73;
 if(!exists && errno!=ENOENT)return 73;
 NSDictionary *original=exists?[NSDictionary dictionaryWithContentsOfFile:path]:nil;
 if(exists && ![original isKindOfClass:NSDictionary.class])return 74;
 NSDictionary *r=[NSDictionary dictionaryWithContentsOfFile:record];
 BOOL ours=[r[@"owner"] isEqualToString:@"net.myxxdev.mybloxx"];
 if(enable) {
  if([original[@"IsSupervised"] boolValue])return ours?0:3;
  if(ours || [fm fileExistsAtPath:record])return 3;
  // Record the original absence/value first, to support exact rollback.
  NSMutableDictionary *backup=[@{@"owner":@"net.myxxdev.mybloxx",
                                 @"createdFile":@(!exists),
                                 @"hadValue":@(original[@"IsSupervised"]!=nil)} mutableCopy];
  if(original[@"IsSupervised"])backup[@"value"]=original[@"IsSupervised"];
  NSError *error=nil;
  [fm createDirectoryAtPath:[record stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
  if(error || ![backup writeToFile:record atomically:YES])return 73;
  NSDictionary *originalAttributes=exists?[fm attributesOfItemAtPath:path error:NULL]:nil;
  NSMutableDictionary *next=original?[original mutableCopy]:[NSMutableDictionary dictionary];
  next[@"IsSupervised"]=@YES;
  if(![next writeToFile:path atomically:YES]) {
   [fm removeItemAtPath:record error:NULL];
   return 73;
  }
  if(exists) {
   for(NSString *key in @[NSFilePosixPermissions,NSFileOwnerAccountID,NSFileGroupOwnerAccountID])
    if(originalAttributes[key])[fm setAttributes:@{key:originalAttributes[key]} ofItemAtPath:path error:NULL];
  } else {
   [fm setAttributes:@{NSFileOwnerAccountID:@0,NSFileGroupOwnerAccountID:@0,NSFilePosixPermissions:@0644} ofItemAtPath:path error:NULL];
  }
  return 0;
 }
 if(!ours || ![original[@"IsSupervised"] boolValue])return 3;
 if([r[@"createdFile"] boolValue]) {
  // Delete only a file created by MYbloXX with exactly our minimal contents.
  if(original.count==1){if(![fm removeItemAtPath:path error:NULL])return 73;}
  else {
   // Apple may have added unrelated configuration after MYbloXX created the
   // file. Revert only our flag rather than deleting those later values.
   NSMutableDictionary *next=[original mutableCopy];[next removeObjectForKey:@"IsSupervised"];
   NSDictionary *attrs=[fm attributesOfItemAtPath:path error:NULL];
   if(![next writeToFile:path atomically:YES])return 73;
   for(NSString *key in @[NSFilePosixPermissions,NSFileOwnerAccountID,NSFileGroupOwnerAccountID])if(attrs[key])[fm setAttributes:@{key:attrs[key]} ofItemAtPath:path error:NULL];
  }
 } else {
  NSMutableDictionary *next=[original mutableCopy];
  if([r[@"hadValue"] boolValue])next[@"IsSupervised"]=r[@"value"]?:@NO;
  else [next removeObjectForKey:@"IsSupervised"];
  if(![next writeToFile:path atomically:YES])return 73;
 }
 [fm removeItemAtPath:record error:NULL];
 return 0;
}

