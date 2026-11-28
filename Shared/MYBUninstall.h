#pragma once
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <errno.h>

static inline NSString *MYBUninstallNormalized(NSString *path){
 if(![path isKindOfClass:NSString.class]||![path hasPrefix:@"/"]||[path containsString:@"//"]||[path hasSuffix:@"/"])return nil;
 for(NSString *part in [path componentsSeparatedByString:@"/"])if([part isEqual:@"."]||[part isEqual:@".."])return nil;
 return [path hasPrefix:@"/private/var/"]?[path substringFromIndex:8]:path;
}
static inline BOOL MYBUninstallOwnedLink(NSString *target,NSArray<NSString *> *known){
 NSString *path=MYBUninstallNormalized(target);if(!path)return NO;
 for(NSString *item in known)if([path isEqual:MYBUninstallNormalized(item)])return YES;
 // Recognize a dangling link to a former LocalStorage UUID after container
 // migration. This exact MYbloXX namespace is the installer-owned live target.
 // The inline-PAC runtime link: exactly /var/tmp/MYbloXX-inlinepac/MYbloXX-pac-<8 hex>.plist.
 NSString *runtime=@"/var/tmp/MYbloXX-inlinepac/MYbloXX-pac-";
 if([path hasPrefix:runtime]&&[path hasSuffix:@".plist"]&&path.length==runtime.length+8+6){
  NSString *hex=[path substringWithRange:NSMakeRange(runtime.length,8)];
  NSCharacterSet *digits=[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
  return [hex rangeOfCharacterFromSet:digits.invertedSet].location==NSNotFound;
 }
 NSString *prefix=@"/var/mobile/Containers/Shared/AppGroup/";
 if(![path hasPrefix:prefix])return NO;
 NSArray *parts=[[path substringFromIndex:prefix.length] componentsSeparatedByString:@"/"];
 return parts.count==4&&[[NSUUID alloc] initWithUUIDString:parts[0]]!=nil&&
 [parts[1] isEqual:@"File Provider Storage"]&&[parts[2] isEqual:@"MYbloXX"]&&
 [parts[3] isEqual:@"MYbloXX.plist"];
}
// Caller supplies only fixed native paths and metadata-verified Files folders.
// Never follow the live symlink while removing it, and never overwrite an
// unrelated managed policy. Keep the previous-policy backup byte-for-byte.
static inline int MYBUninstallDetach(NSString *managed,NSString *backup,NSArray *known,BOOL ownedRegular,BOOL *changed){
 NSFileManager *fm=NSFileManager.defaultManager;struct stat st;BOOL occupied=lstat(managed.fileSystemRepresentation,&st)==0;
 if(!occupied&&errno!=ENOENT)return 73;
 BOOL ours=occupied&&((S_ISLNK(st.st_mode)&&MYBUninstallOwnedLink([fm destinationOfSymbolicLinkAtPath:managed error:NULL],known))||(S_ISREG(st.st_mode)&&ownedRegular));
 if(ours){if(![fm removeItemAtPath:managed error:NULL])return 73;occupied=NO;if(changed)*changed=YES;}
 if(occupied)return 0;
 if(backup.length){struct stat old;if(lstat(backup.fileSystemRepresentation,&old)==0){
   if(!S_ISREG(old.st_mode)&&!S_ISLNK(old.st_mode))return 73;
   if(![fm copyItemAtPath:backup toPath:managed error:NULL])return 73;
   if(changed)*changed=YES;
  }else if(errno!=ENOENT)return 73;
 }
 return 0;
}
static inline int MYBUninstallLiveFiles(NSArray<NSString *> *folders){
 NSFileManager *fm=NSFileManager.defaultManager;
 for(NSString *folder in folders){
  struct stat parent;if(lstat(folder.fileSystemRepresentation,&parent)!=0){if(errno==ENOENT)continue;return 73;}
  if(!S_ISDIR(parent.st_mode)||S_ISLNK(parent.st_mode))return 73;
  NSString *live=[folder stringByAppendingPathComponent:@"MYbloXX.plist"];struct stat st;
  if(lstat(live.fileSystemRepresentation,&st)==0){if(!S_ISREG(st.st_mode)&&!S_ISLNK(st.st_mode))return 73;if(![fm removeItemAtPath:live error:NULL])return 73;}else if(errno!=ENOENT)return 73;
  NSString *readme=[folder stringByAppendingPathComponent:@"README.txt"];
  if(lstat(readme.fileSystemRepresentation,&st)==0&&S_ISREG(st.st_mode)){
   NSString *text=[NSString stringWithContentsOfFile:readme encoding:NSUTF8StringEncoding error:NULL];
   if([text hasPrefix:@"MYbloXX system"]&&![fm removeItemAtPath:readme error:NULL])return 73;
  }
  // MYbloXX-Settings.plist, MYbloXX.pac, .previous files and every other
  // user/backup file are deliberately untouched.
 }
 return 0;
}
