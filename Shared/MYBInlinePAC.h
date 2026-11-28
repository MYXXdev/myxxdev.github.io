#pragma once
// MYBInlinePAC.h: the single privileged transaction that applies or removes the inline PAC.
//
//  durable intent      State.plist (enabled + mode), rules, exceptions   <- source of truth
//  generated content   MYBEffectivePACText(...)                          <- regenerated on demand
//  runtime config      <MYBIPDir()>/MYbloXX-pac-<8hex>.plist + managed link  <- disposable
//
// The temporary target path is never a source of truth. A small journal (InlineRuntime.plist
// in MYbloXX's own durable storage) records the exact target name BEFORE it is created so
// that a crash at any step is recoverable and so that only files this code created are ever
// deleted. Callers hold the helper's operation lock around every call.
//
// Safety rules (design from the inline-PAC experiment; device evidence so far covers the tiny PAC and one full
// PAC of about 64.5 KB - not every PAC mode):
//  * the temporary parent must be a real root-owned directory (sticky if group/world writable);
//    the system parent is never chmod/chown'ed;
//  * the MYbloXX child directory is created root-owned 0755 and refused if anything else;
//  * the target is created O_EXCL|O_NOFOLLOW 0644 root:wheel and never flagged immutable/append-only,
//    so iOS boot cleanup can remove it;
//  * a target is removed only if it has the recorded name AND the recorded identity (inode,
//    birth time, SHA-256), never anything else;
//  * the managed link is replaced only when it is absent, MYbloXX-owned or the legacy B50 link;
//    a foreign configuration or an active experiment is refused untouched.
#import "MYBRuntimeStatus.h"
#import <CommonCrypto/CommonDigest.h>
#import <fcntl.h>
#import <sys/time.h>
#ifdef __APPLE__
#import <sys/mount.h>
#import <sys/sysctl.h>
#define MYB_ST_FLAGS(st) ((st).st_flags)
#define MYB_ST_BIRTH(st) ((st).st_birthtimespec)
#define MYB_PROTECTIVE_FLAGS (UF_IMMUTABLE|SF_IMMUTABLE|UF_APPEND|SF_APPEND)
#else
// Linux is used only to run the unit tests locally; the device build is always Apple.
#import <sys/statfs.h>
#define MYB_ST_FLAGS(st) (0)
#define MYB_ST_BIRTH(st) ((st).st_ctim)
#define MYB_PROTECTIVE_FLAGS (0x1)
#endif

// Test-only fault injection: a non-zero return fails that step; -999 simulates a crash.
#ifdef MYB_INLINE_TESTING
static int (*gMYBIPFault)(int step)=NULL;
#define MYB_IP_STEP(n) do{int f_=gMYBIPFault?gMYBIPFault(n):0;if(f_==-999)return 99;if(f_){if(why)*why=[NSString stringWithFormat:@"injected failure at step %d",n];return 3;}}while(0)
#else
#define MYB_IP_STEP(n) do{}while(0)
#endif

static inline NSString *MYBIPHex(NSData *d){
 unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);
 NSMutableString *s=[NSMutableString string];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[s appendFormat:@"%02x",h[i]];return s;
}
static inline NSString *MYBIPBootSession(void){
#ifdef __APPLE__
 char buf[96]={0};size_t n=sizeof buf-1;
 return sysctlbyname("kern.bootsessionuuid",buf,&n,NULL,0)==0?@(buf):@"";
#else
 return @"test";
#endif
}
static inline BOOL MYBIPSyncDir(NSString *dir){
 int fd=open(dir.fileSystemRepresentation,O_RDONLY|O_DIRECTORY|O_NOFOLLOW);if(fd<0)return NO;
 BOOL ok=fsync(fd)==0;close(fd);return ok;
}
// ---- protected directory -------------------------------------------------------------
static inline BOOL MYBIPParentSafe(NSString **why){
 NSString *parent=[MYBIPDir() stringByDeletingLastPathComponent];struct stat st;
 if(lstat(parent.fileSystemRepresentation,&st)!=0||!S_ISDIR(st.st_mode)||st.st_uid!=MYBIPOwnerUID()){if(why)*why=@"temporary parent is missing, a symlink, or not owned by root";return NO;}
 if((st.st_mode&(S_IWGRP|S_IWOTH))&&!(st.st_mode&S_ISVTX)){if(why)*why=@"writable temporary parent lacks the sticky bit";return NO;}
 return YES;
}
static inline BOOL MYBIPDirSafe(NSString **why){
 if(!MYBIPParentSafe(why))return NO;
 struct stat st;NSString *d=MYBIPDir();
 if(lstat(d.fileSystemRepresentation,&st)!=0){if(why)*why=[NSString stringWithFormat:@"cannot inspect runtime directory (errno %d)",errno];return NO;}
 if(!S_ISDIR(st.st_mode)){if(why)*why=@"runtime directory is a symlink or file";return NO;}
 if(st.st_uid!=MYBIPOwnerUID()){if(why)*why=@"runtime directory is not owned by root";return NO;}
 if(st.st_mode&(S_IWGRP|S_IWOTH)){if(why)*why=@"runtime directory is group/world writable";return NO;}
 #ifdef __APPLE__
 struct statfs fs;if(statfs(d.fileSystemRepresentation,&fs)==0&&(fs.f_flags&MNT_RDONLY)){if(why)*why=@"runtime directory is read-only";return NO;}
#endif
 return YES;
}
static inline BOOL MYBIPEnsureDir(NSString **why){
 if(!MYBIPParentSafe(why))return NO;
 NSString *parent=[MYBIPDir() stringByDeletingLastPathComponent];
 int fd=open(parent.fileSystemRepresentation,O_RDONLY|O_DIRECTORY|O_NOFOLLOW);
 if(fd<0){if(why)*why=@"cannot open temporary parent";return NO;}
 struct stat st;BOOL safe=fstat(fd,&st)==0&&S_ISDIR(st.st_mode)&&st.st_uid==MYBIPOwnerUID()&&(!(st.st_mode&(S_IWGRP|S_IWOTH))||(st.st_mode&S_ISVTX));
 if(!safe){close(fd);if(why)*why=@"temporary parent changed during inspection";return NO;}
 int rc=mkdirat(fd,MYBIPDir().lastPathComponent.fileSystemRepresentation,0755);int e=errno;
 BOOL synced=(rc!=0&&e==EEXIST)||(rc==0&&fsync(fd)==0);close(fd);
 if(rc!=0&&e!=EEXIST){if(why)*why=[NSString stringWithFormat:@"cannot create runtime directory: %s",strerror(e)];return NO;}
 if(!synced){if(why)*why=@"cannot sync runtime directory";return NO;}
 return MYBIPDirSafe(why);
}
// ---- target file -----------------------------------------------------------------------
static inline NSString *MYBIPNewTarget(void){
 return [MYBIPDir() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@%@",MYB_IP_PREFIX,[[NSUUID.UUID.UUIDString substringToIndex:8] lowercaseString],MYB_IP_SUFFIX]];
}
static inline BOOL MYBIPCreateTarget(NSString *path,NSData *data,NSString **why){
 int fd=open(path.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);
 if(fd<0){if(why)*why=[NSString stringWithFormat:@"create failed: %s",strerror(errno)];return NO;}
 const char *p=data.bytes;size_t left=data.length;BOOL ok=YES;
 while(left){ssize_t n=write(fd,p,left);if(n<0&&errno==EINTR)continue;if(n<=0){ok=NO;break;}p+=n;left-=(size_t)n;}
 if(ok&&fchmod(fd,0644)!=0)ok=NO;
 if(ok&&geteuid()==0&&fchown(fd,0,0)!=0)ok=NO;
 if(ok&&fsync(fd)!=0)ok=NO;
 if(close(fd)!=0)ok=NO;
 if(!ok){unlink(path.fileSystemRepresentation);if(why)*why=@"write/permission/sync failed";return NO;}
 if(!MYBIPSyncDir(path.stringByDeletingLastPathComponent)){unlink(path.fileSystemRepresentation);if(why)*why=@"directory sync failed";return NO;}
 if(![[NSData dataWithContentsOfFile:path] isEqualToData:data]){unlink(path.fileSystemRepresentation);if(why)*why=@"read-back mismatch";return NO;}
 return YES;
}
static inline NSDictionary *MYBIPIdentity(NSString *path,NSData *data){
 struct stat st;if(lstat(path.fileSystemRepresentation,&st)!=0||!S_ISREG(st.st_mode))return nil;
 return @{@"path":path,@"ino":@((unsigned long long)st.st_ino),@"dev":@(st.st_dev),@"size":@((long long)st.st_size),
  @"birthSec":@((long long)MYB_ST_BIRTH(st).tv_sec),@"birthNsec":@((long long)MYB_ST_BIRTH(st).tv_nsec),
  @"sha256":MYBIPHex(data),@"bootSession":MYBIPBootSession(),@"createdAt":NSDate.date};
}
typedef NS_ENUM(int,MYBIPFile){MYBIPFileAbsent,MYBIPFileSame,MYBIPFileSameContent,MYBIPFileDifferent,MYBIPFileUnsafe};
// Same = inode, birth time and content match; SameContent = only the content matches
// (a copy created by something else with the same bytes); Different = anything else.
static inline MYBIPFile MYBIPClassifyFile(NSString *path,NSDictionary *idt){
 struct stat st;
 if(lstat(path.fileSystemRepresentation,&st)!=0)return errno==ENOENT?MYBIPFileAbsent:MYBIPFileUnsafe;
 if(!S_ISREG(st.st_mode)||![idt[@"path"] isEqual:path])return MYBIPFileUnsafe;
 NSData *cur=[NSData dataWithContentsOfFile:path];
 BOOL sha=cur&&[MYBIPHex(cur) isEqualToString:idt[@"sha256"]];
 BOOL ino=[idt[@"ino"] unsignedLongLongValue]==(unsigned long long)st.st_ino;
 BOOL birth=[idt[@"birthSec"] longLongValue]==(long long)MYB_ST_BIRTH(st).tv_sec&&[idt[@"birthNsec"] longLongValue]==(long long)MYB_ST_BIRTH(st).tv_nsec;
 if(ino&&birth&&sha)return MYBIPFileSame;
 return sha?MYBIPFileSameContent:MYBIPFileDifferent;
}
// Remove only the exact recorded name with a matching identity. Never touches flags, never
// follows links, never removes a different file that happens to sit at the same name.
static inline BOOL MYBIPRemoveTarget(NSString *path,NSDictionary *idt,NSString **note){
 if(!MYBIPShapeOK(path)){if(note)*note=@"not an exact MYbloXX® runtime name; not touched";return YES;}
 MYBIPFile c=MYBIPClassifyFile(path,idt);
 if(c==MYBIPFileAbsent){if(note)*note=@"already absent";return YES;}
 if(c!=MYBIPFileSame){if(note)*note=@"a file MYbloXX® cannot prove it created (identity or content differs, including an identical copy) is at that name; left in place";return NO;}
 struct stat st;if(lstat(path.fileSystemRepresentation,&st)==0&&(MYB_ST_FLAGS(st)&MYB_PROTECTIVE_FLAGS)){if(note)*note=@"carries flags MYbloXX® never sets; left in place";return NO;}
 if(unlink(path.fileSystemRepresentation)!=0&&errno!=ENOENT){if(note)*note=[NSString stringWithFormat:@"unlink failed: %s",strerror(errno)];return NO;}
 MYBIPSyncDir(path.stringByDeletingLastPathComponent);
 if(note)*note=@"removed";return YES;
}
// ---- journal ---------------------------------------------------------------------------
static inline NSDictionary *MYBIPReadJournal(NSString *journal){
 NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:journal];return [d isKindOfClass:NSDictionary.class]?d:@{};
}
static inline BOOL MYBIPWriteJournal(NSString *journal,NSDictionary *d){
 NSMutableDictionary *m=[d mutableCopy];m[@"updated"]=NSDate.date;
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:m format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
 if(!data)return NO;
 [[NSFileManager defaultManager] createDirectoryAtPath:journal.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *tmp=[journal stringByAppendingString:@".tmp"];
 int fd=open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_TRUNC|O_NOFOLLOW,0600);if(fd<0)return NO;
 const char *p=data.bytes;size_t left=data.length;BOOL ok=YES;
 while(left){ssize_t n=write(fd,p,left);if(n<0&&errno==EINTR)continue;if(n<=0){ok=NO;break;}p+=n;left-=(size_t)n;}
 if(ok&&fsync(fd)!=0)ok=NO;if(close(fd)!=0)ok=NO;
 if(!ok||rename(tmp.fileSystemRepresentation,journal.fileSystemRepresentation)!=0){unlink(tmp.fileSystemRepresentation);return NO;}
 MYBIPSyncDir(journal.stringByDeletingLastPathComponent);return YES;
}
// ---- managed link ----------------------------------------------------------------------
static inline NSString *MYBIPTempLink(void){return [MYBIPManagedPath() stringByAppendingString:@".mybloxx-tx"];}
static inline void MYBIPClearStaleTempLink(void){
 struct stat st;NSString *t=MYBIPTempLink();
 if(lstat(t.fileSystemRepresentation,&st)==0&&S_ISLNK(st.st_mode))unlink(t.fileSystemRepresentation);
}
// Atomic replace: symlink at a temporary name, then rename over the managed entry.
static inline BOOL MYBIPPointLink(NSString *dest,NSString **why){
 MYBIPClearStaleTempLink();NSString *t=MYBIPTempLink();
 if(symlink(dest.fileSystemRepresentation,t.fileSystemRepresentation)!=0){if(why)*why=[NSString stringWithFormat:@"temporary link failed: %s",strerror(errno)];return NO;}
 if(rename(t.fileSystemRepresentation,MYBIPManagedPath().fileSystemRepresentation)!=0){int e=errno;unlink(t.fileSystemRepresentation);if(why)*why=[NSString stringWithFormat:@"replacing the managed link failed: %s",strerror(e)];return NO;}
 return YES;
}
static inline BOOL MYBIPLinkIs(NSString *dest){
 NSString *cur=nil;MYBIPClassifyLink(&cur);return [cur isEqualToString:dest];
}
// A link MYbloXX may replace or detach: absent, its own runtime target, or the legacy B50 link.
static inline BOOL MYBIPMayReplaceLink(NSString **why){
 NSString *dest=nil;MYBIPLinkKind k=MYBIPClassifyLink(&dest);
 if(k==MYBIPLinkAbsent||k==MYBIPLinkOwned||k==MYBIPLinkLegacy)return YES;
 if(why)*why=k==MYBIPLinkExperiment?@"the inline-PAC experiment owns the managed link; run its rollback first"
  :[NSString stringWithFormat:@"the managed configuration belongs to something else (%@); not touched",dest?:@"not a symlink"];
 return NO;
}
// Every top-level key other than Proxies survives; Proxies is replaced as a whole.
static inline NSData *MYBIPPlistData(NSString *script,NSDictionary *baseRoot){
 NSMutableDictionary *root=[baseRoot isKindOfClass:NSDictionary.class]?[baseRoot mutableCopy]:[NSMutableDictionary dictionary];
 root[@"Proxies"]=MYBIPInlineProxies(script);
 return [NSPropertyListSerialization dataWithPropertyList:root format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
}
// Preserved top-level keys come from the current runtime target (or the legacy Files plist).
static inline NSDictionary *MYBIPCurrentRoot(NSString *legacyPlist){
 NSString *dest=nil;MYBIPLinkKind k=MYBIPClassifyLink(&dest);NSString *path=nil;
 if(k==MYBIPLinkOwned)path=dest;
 else if(k==MYBIPLinkLegacy&&legacyPlist.length)path=legacyPlist;
 NSDictionary *root=path?[NSDictionary dictionaryWithContentsOfFile:path]:nil;
 return [root isKindOfClass:NSDictionary.class]?root:nil;
}
// ---- ownership ledger ------------------------------------------------------------------
// A runtime file is deleted by the sweep only if MYbloXX RECORDED creating it: the exact name is written
// to a ledger inside the same root-owned directory before the file exists, and the inode is added once it
// does. A file that merely has the generated shape (a look-alike, or a leftover from before the ledger
// existed) is preserved. Journal-recorded targets are still removed by MYBIPRemoveTarget with their identity.
static inline NSString *MYBIPLedgerPath(void){return [MYBIPDir() stringByAppendingPathComponent:@".ledger.plist"];}
static inline NSMutableDictionary *MYBIPReadLedger(void){
 NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:MYBIPLedgerPath()];NSDictionary *files=[d[@"files"] isKindOfClass:NSDictionary.class]?d[@"files"]:@{};
 return [files mutableCopy];
}
static inline BOOL MYBIPWriteLedger(NSDictionary *files){return MYBIPWriteJournal(MYBIPLedgerPath(),@{@"files":files});}
// A ledger entry is either "planned" (name only: the file may not exist, or may be something else entirely) or
// "complete" (full identity: inode, birth time, size and SHA-256 of the bytes MYbloXX wrote). Only a complete entry
// whose file still matches ALL of it authorizes deletion; a name-only entry never does.
#ifdef MYB_INLINE_TESTING
static BOOL gMYBIPFailIdentityRecord=NO; // tests: simulate a failure to persist a complete identity
#endif
static inline BOOL MYBIPLedgerRecord(NSString *path,NSDictionary *identity){
#ifdef MYB_INLINE_TESTING
 if(identity&&gMYBIPFailIdentityRecord)return NO;
#endif
 if(!MYBIPShapeOK(path))return NO;
 if(identity&&(![identity[@"path"] isEqual:path]||!identity[@"sha256"]||!identity[@"ino"]||!identity[@"birthSec"]))return NO;
 NSMutableDictionary *f=MYBIPReadLedger();NSMutableDictionary *e=[NSMutableDictionary dictionary];
 if(identity)e[@"identity"]=identity;else if(f[path.lastPathComponent][@"identity"])return YES; // never downgrade a complete entry
 f[path.lastPathComponent]=e;return MYBIPWriteLedger(f);
}
// Delete only recorded, unreferenced, shape-valid, root-owned regular files whose COMPLETE recorded identity
// (inode, birth time, content hash) still matches. Name-only, incomplete or mismatching entries are preserved.
static inline void MYBIPSweep(NSString *keep){
 NSString *linked=nil;MYBIPClassifyLink(&linked);NSMutableDictionary *ledger=MYBIPReadLedger();BOOL dirty=NO;
 for(NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:MYBIPDir() error:NULL]){
  NSString *path=[MYBIPDir() stringByAppendingPathComponent:name];
  if(!MYBIPShapeOK(path)||[path isEqual:keep]||[path isEqual:linked])continue;
  NSDictionary *entry=ledger[name];if(![entry isKindOfClass:NSDictionary.class])continue; // not recorded by MYbloXX: never ours to delete
  NSDictionary *idt=entry[@"identity"];if(![idt isKindOfClass:NSDictionary.class])continue; // name-only: ambiguous, preserved
  struct stat st;if(lstat(path.fileSystemRepresentation,&st)!=0||!S_ISREG(st.st_mode)||st.st_uid!=MYBIPOwnerUID()||(MYB_ST_FLAGS(st)&MYB_PROTECTIVE_FLAGS))continue;
  if(MYBIPClassifyFile(path,idt)!=MYBIPFileSame)continue; // replaced, or rewritten in place: preserved
  if(unlink(path.fileSystemRepresentation)==0){[ledger removeObjectForKey:name];dirty=YES;}
 }
 // forget records of files that no longer exist
 for(NSString *name in [ledger.allKeys copy]){struct stat st;if(lstat([MYBIPDir() stringByAppendingPathComponent:name].fileSystemRepresentation,&st)!=0&&errno==ENOENT){[ledger removeObjectForKey:name];dirty=YES;}}
 if(dirty)MYBIPWriteLedger(ledger);
}
// ---- the transaction -------------------------------------------------------------------
// Returns 0 ok, 2 refused (nothing changed), 3 failed (state recoverable), 99 simulated crash (tests).
static inline int MYBIPApply(NSString *script,NSString *mode,NSString *journal,NSString *legacyPlist,NSString **why){
 if(![script isKindOfClass:NSString.class]||script.length<20||script.length>MYB_IP_MAX_SCRIPT||![script containsString:@"function FindProxyForURL"]){if(why)*why=@"the effective PAC is missing or invalid";return 2;}
 if(!MYBIPMayReplaceLink(why))return 2;
 if(!MYBIPEnsureDir(why))return 2;
 NSDictionary *oldJ=MYBIPReadJournal(journal);
 NSString *oldDest=nil;MYBIPLinkKind oldKind=MYBIPClassifyLink(&oldDest);
 NSData *data=MYBIPPlistData(script,MYBIPCurrentRoot(legacyPlist));
 if(!data){if(why)*why=@"cannot encode the configuration";return 3;}
 NSString *to=MYBIPNewTarget();struct stat st;
 if(lstat(to.fileSystemRepresentation,&st)==0||errno!=ENOENT||!MYBIPShapeOK(to)){if(why)*why=@"planned target already exists";return 2;}
 // 1. the exact name is made durable BEFORE the file exists or the link moves
 MYB_IP_STEP(1);
 NSMutableDictionary *j=[oldJ mutableCopy];
 if(oldKind==MYBIPLinkOwned&&oldJ[@"target"]&&[oldJ[@"target"] isEqual:oldDest])j[@"previous"]=@{@"path":oldDest,@"identity":oldJ[@"identity"]?:@{}};
 else [j removeObjectForKey:@"previous"];
 j[@"phase"]=@"planned";j[@"pending"]=to;j[@"mode"]=mode?:@"";j[@"scriptSHA256"]=MYBIPHex([script dataUsingEncoding:NSUTF8StringEncoding]);
 if(!MYBIPWriteJournal(journal,j)){if(why)*why=@"cannot record the runtime target durably; nothing changed";return 3;}
 if(!MYBIPLedgerRecord(to,nil)){if(why)*why=@"cannot record the runtime target ownership; nothing changed";return 3;}
 MYB_IP_STEP(2);
 if(!MYBIPCreateTarget(to,data,why)){[j removeObjectForKey:@"pending"];j[@"phase"]=oldJ[@"phase"]?:@"idle";MYBIPWriteJournal(journal,j);return 3;}
 NSDictionary *ident=MYBIPIdentity(to,data);
 if(!ident){NSString *n=nil;MYBIPRemoveTarget(to,nil,&n);unlink(to.fileSystemRepresentation);if(why)*why=@"cannot read back the new target";return 3;}
 j[@"phase"]=@"created";j[@"pendingIdentity"]=ident;
 if(!MYBIPLedgerRecord(to,ident)){ // identity could not be made durable: do not leave a weaker, name-only entry behind a live file
  NSString *n=nil;MYBIPRemoveTarget(to,ident,&n);[j removeObjectForKey:@"pending"];[j removeObjectForKey:@"pendingIdentity"];j[@"phase"]=oldJ[@"phase"]?:@"idle";MYBIPWriteJournal(journal,j);
  if(why)*why=@"cannot record the runtime target identity; nothing changed";return 3;}
 if(!MYBIPWriteJournal(journal,j)){unlink(to.fileSystemRepresentation);if(why)*why=@"cannot record target identity";return 3;}
 MYB_IP_STEP(3);
 // 2. atomic link replacement (legacy/absent/owned all handled the same way)
 if(!MYBIPPointLink(to,why)){MYBIPRemoveTarget(to,ident,NULL);return 3;}
 MYB_IP_STEP(4);
 BOOL ok=MYBIPLinkIs(to)&&MYBIPClassifyFile(to,ident)==MYBIPFileSame;
 if(!ok){
  if(oldKind==MYBIPLinkAbsent)unlink(MYBIPManagedPath().fileSystemRepresentation);else MYBIPPointLink(oldDest,NULL);
  MYBIPRemoveTarget(to,ident,NULL);if(why)*why=@"the new target did not verify; previous link restored";return 3;
 }
 MYB_IP_STEP(5);
 NSDictionary *prev=j[@"previous"];
 [j removeObjectForKey:@"previous"];[j removeObjectForKey:@"pending"];[j removeObjectForKey:@"pendingIdentity"];
 j[@"target"]=to;j[@"identity"]=ident;j[@"phase"]=@"linked";
 if(!MYBIPWriteJournal(journal,j)){if(why)*why=@"link moved but the journal could not be updated";return 3;}
 MYB_IP_STEP(6);
 if([prev[@"path"] isKindOfClass:NSString.class]&&![prev[@"path"] isEqual:to]){NSString *n=nil;MYBIPRemoveTarget(prev[@"path"],prev[@"identity"],&n);}
 MYBIPSweep(to);
 return 0;
}
// Remove protection. The link goes first (so nothing can dangle), then the recorded target.
// Returns 0 ok / nothing to do, 2 refused (foreign), 3 failed.
static inline int MYBIPDetach(NSString *journal,NSString **why){
 NSString *dest=nil;MYBIPLinkKind k=MYBIPClassifyLink(&dest);
 if(k==MYBIPLinkExperiment||k==MYBIPLinkForeign||k==MYBIPLinkNotSymlink||k==MYBIPLinkError){MYBIPMayReplaceLink(why);if(k==MYBIPLinkError&&why)*why=@"cannot inspect the managed link";return 2;}
 NSDictionary *j=MYBIPReadJournal(journal);
 if(k==MYBIPLinkOwned||k==MYBIPLinkLegacy){
  MYBIPClearStaleTempLink();
  if(unlink(MYBIPManagedPath().fileSystemRepresentation)!=0&&errno!=ENOENT){if(why)*why=[NSString stringWithFormat:@"cannot remove the managed link: %s",strerror(errno)];return 3;}
 }
 MYB_IP_STEP(7);
 BOOL clean=YES;NSString *note=nil;
 for(NSString *key in @[@"target",@"pending"]){
  NSString *path=j[key];if(![path isKindOfClass:NSString.class])continue;
  NSDictionary *idt=[key isEqual:@"target"]?j[@"identity"]:j[@"pendingIdentity"];
  clean=MYBIPRemoveTarget(path,idt,&note)&&clean;
 }
 if([j[@"previous"][@"path"] isKindOfClass:NSString.class])clean=MYBIPRemoveTarget(j[@"previous"][@"path"],j[@"previous"][@"identity"],&note)&&clean;
 if(k==MYBIPLinkOwned&&dest&&![dest isEqual:j[@"target"]])MYBIPRemoveTarget(dest,nil,&note);
 MYBIPSweep(nil);
 NSMutableDictionary *idle=[NSMutableDictionary dictionaryWithObject:@"idle" forKey:@"phase"];
 if(!MYBIPWriteJournal(journal,idle)){if(why)*why=@"detached, but the journal could not be reset";return 3;}
 return 0;
}
// Uninstall: remove every runtime file MYbloXX created (recorded targets, unreferenced generated
// names, the then-empty directory) and the journal. Never touches the managed link.
static inline BOOL MYBIPCleanupFiles(NSString *journal){
 NSDictionary *j=MYBIPReadJournal(journal);BOOL clean=YES;NSString *note=nil;
 NSString *linked=nil;MYBIPLinkKind kind=MYBIPClassifyLink(&linked);
 for(NSString *key in @[@"target",@"pending"]){
  NSString *path=j[key];if(![path isKindOfClass:NSString.class]||(kind==MYBIPLinkOwned&&[path isEqual:linked]))continue;
  clean=MYBIPRemoveTarget(path,[key isEqual:@"target"]?j[@"identity"]:j[@"pendingIdentity"],&note)&&clean;
 }
 if([j[@"previous"][@"path"] isKindOfClass:NSString.class])clean=MYBIPRemoveTarget(j[@"previous"][@"path"],j[@"previous"][@"identity"],&note)&&clean;
 MYBIPSweep(nil);
 if(MYBIPDirSafe(NULL)){NSDictionary *left=MYBIPReadLedger();BOOL any=NO;for(NSString *n in left)if([NSFileManager.defaultManager fileExistsAtPath:[MYBIPDir() stringByAppendingPathComponent:n]])any=YES;if(!any)unlink(MYBIPLedgerPath().fileSystemRepresentation);}
 if(MYBIPDirSafe(NULL))rmdir(MYBIPDir().fileSystemRepresentation); // only succeeds when empty
 if(clean&&journal.length)unlink(journal.fileSystemRepresentation);
 return clean;
}
// Startup/uptime recovery decision. Never repoints a link on its own; it reports what a caller
// holding the operation lock and the persisted intent must do.
//   ok            nothing to do
//   reapply       intent is enabled but the runtime target is missing/invalid/stale
//   orphan-clean  intent is disabled (or no owned link) and runtime files are left over
static inline NSString *MYBIPRecoveryAction(BOOL intentEnabled,NSString *expectedScript){
 NSDictionary *s=MYBRuntimeStatus();NSString *state=s[@"state"];
 if(intentEnabled){
  if([state isEqual:@"configured"])return (expectedScript&&![s[@"script"] isEqual:expectedScript])?@"reapply":@"ok";
  if([state isEqual:@"disabled"]||[state isEqual:@"target-missing"]||[state isEqual:@"target-invalid"]||[state isEqual:@"legacy-url"])return @"reapply";
  return @"blocked";
 }
 if([state isEqual:@"configured"]||[state isEqual:@"target-missing"]||[state isEqual:@"target-invalid"]||[state isEqual:@"legacy-url"])return @"orphan-clean";
 return @"ok";
}
