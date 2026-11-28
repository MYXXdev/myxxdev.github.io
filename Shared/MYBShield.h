#pragma once
// MYbloXX Shield policy: scoped permissions, expiry, one-time grants and recent activity.
//
// Pure Foundation so the same code runs in Safari/SpringBoard tweaks, the blocked-page server, the
// privileged helper, Settings and the native macOS tests.
//
// Scopes are never combined:
//   popup        source website (host and its subdomains) may create new windows
//   appstore     one source app (bundle id) may launch the App Store
//   appredirect  one source app may open one destination app (source -> destination)
// Network website exceptions (destination domain) are a different layer, stored by MYBWebsiteRules.h
// and applied through the inline PAC. A Shield permission never implies a website exception and vice versa.
//
// Durations: once (ONE attempt, valid for at most 120 s; see below), temp (15 minutes), always. `block` (popups only) is a standing refusal:
// the source website is blocked without asking again until the user revokes it in Permissions. Among matching grants the
// most specific website wins, so a block for example.com does not override an allow for shop.example.com.
// Allow Once is a single-use RETRY approval, not a 120-second allowance and not a resumed attempt. The attempt the prompt was shown for has
// already been declined and ends there; the person's second tap is a NEW attempt. What lets that retry through is matching, not identity:
//   a once grant matches a later attempt only when kind, source app, destination and URL scheme (the scheme only, never the URL) are all the
//   same as in the prompt, and it is still inside its 120 s window in the same boot session (monotonic and wall clock both). The first
//   EXECUTING transition that matches consumes it under the file lock and the consumption must be saved, else that attempt is refused.
//   Everything else (another source, destination or scheme, a second independent tap, a concurrent duplicate, an expired or unsaved grant)
//   finds nothing and is asked again. The prompt's attempt id is stored only as a diagnostic label; it is not compared on the retry.
// Saving the permission does NOT resume the original redirect (the transition was declined and has no continuation; see MYBShieldPending.h
// for the exact limitation); the person sees "Allowed. Try again." and taps the link again. After a failed save nothing is allowed.
// once/temp grants are valid only in the boot session that created them, only while a monotonic
// clock AND the wall clock both say they are unexpired. Clock changes can therefore only shorten
// a grant, never extend it. They are not exported in backups and never survive a reboot.
#import <Foundation/Foundation.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#import <fcntl.h>
#import <sys/sysctl.h>
#import <time.h>
#import "MYBWebsiteRules.h"
#import "MYBClock.h"

#define MYB_SHIELD_ONCE_SECONDS 120.0
#define MYB_SHIELD_TEMP_SECONDS 900.0
#define MYB_SHIELD_MAX_GRANTS 200
#define MYB_SHIELD_MAX_ACTIVITY 40

static inline NSString *MYBShieldPermissionsFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/ShieldPermissions.plist");}
static inline NSString *MYBShieldActivityFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/ShieldActivity.plist");}

static inline BOOL MYBShieldKindValid(NSString *k){return [@[@"popup",@"appstore",@"appredirect"] containsObject:k];}
static inline BOOL MYBShieldModeValid(NSString *m){return [@[@"once",@"temp",@"always",@"block"] containsObject:m];}
static inline BOOL MYBShieldBundleValid(NSString *s){
 if(![s isKindOfClass:NSString.class]||s.length<3||s.length>200||![s containsString:@"."])return NO;
 NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"].invertedSet;return [s rangeOfCharacterFromSet:bad].location==NSNotFound;
}
// Hosts only. IP literals and single-label hosts are valid popup sources on purpose (intranet pages).
static inline NSString *MYBShieldHost(NSString *raw){
 if(![raw isKindOfClass:NSString.class]||!raw.length||raw.length>253)return nil;NSString *h=raw.lowercaseString;
 NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-.:[]"].invertedSet;if([h rangeOfCharacterFromSet:bad].location!=NSNotFound)return nil;
 if([h hasPrefix:@"."]||[h hasSuffix:@"."]||[h containsString:@".."])return nil;return h;
}
static inline BOOL MYBShieldSourceValid(NSString *kind,NSString *source){return [kind isEqual:@"popup"]?MYBShieldHost(source)!=nil:MYBShieldBundleValid(source);}
static inline BOOL MYBShieldDestValid(NSString *kind,NSString *dest){if(![kind isEqual:@"appredirect"])return !dest.length;return MYBShieldBundleValid(dest);}

static inline BOOL MYBShieldGrantLive(NSDictionary *g){
 if(![g isKindOfClass:NSDictionary.class])return NO;NSString *kind=g[@"kind"],*mode=g[@"mode"],*source=g[@"source"],*dest=g[@"dest"]?:@"";
 if(!MYBShieldKindValid(kind)||!MYBShieldModeValid(mode)||!MYBShieldSourceValid(kind,source)||!MYBShieldDestValid(kind,dest)||![g[@"id"] isKindOfClass:NSString.class])return NO;
 if([mode isEqual:@"always"]||[mode isEqual:@"block"])return YES;
 return MYBClockLive(g); // same boot session, and BOTH clocks must agree it is unexpired
}

// ---- locked storage -------------------------------------------------------------------------
// Several processes write these files: SpringBoard and Preferences as "mobile", the helper and installer scripts as root. A file or lock
// created by root used to be unopenable for read-write by SpringBoard, which made every Allow fail with "could not be saved". So:
//  * the lock is taken with flock(), which needs no write access: if read-write is refused the lock is opened read-only;
//  * anything root creates is handed to mobile (501): the lock is 0600 and the data file 0644, so only mobile and root can take the lock or change a
//    permission; no other process can write either, and nothing outside the MYbloXX folder is touched;
//  * the real reason for a failure is kept (MYBShieldLastError) so diagnostics can say why instead of a generic message.
static NSString *MYBShieldLastErrorValue __attribute__((unused));
static inline NSString *MYBShieldLastError(void){return MYBShieldLastErrorValue?:@"";}
static inline void MYBShieldSetError(NSString *what,int err){MYBShieldLastErrorValue=err?[NSString stringWithFormat:@"%@ (errno %d)",what,err]:what;}
static inline void MYBShieldHandOver(NSString *path,mode_t mode){if(geteuid()==0){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,mode);}}
static inline int MYBShieldLock(NSString *path){
 NSString *lock=[path stringByAppendingString:@".lock"],*dir=[lock stringByDeletingLastPathComponent];
 BOOL fresh=![NSFileManager.defaultManager fileExistsAtPath:dir];
 [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];if(fresh)MYBShieldHandOver(dir,0755);
 BOOL existed=[NSFileManager.defaultManager fileExistsAtPath:lock];
 int fd=open(lock.fileSystemRepresentation,O_CREAT|O_RDWR,0600);
 if(fd<0){int first=errno;fd=open(lock.fileSystemRepresentation,O_RDONLY);if(fd<0){MYBShieldSetError(@"the lock file cannot be opened",first);return -1;}}
 else if(!existed)MYBShieldHandOver(lock,0600);
 if(flock(fd,LOCK_EX)!=0){int e=errno;close(fd);MYBShieldSetError(@"the lock could not be taken",e);return -1;}
 return fd;
}
static inline void MYBShieldUnlock(int fd){if(fd>=0){flock(fd,LOCK_UN);close(fd);}}
static inline NSMutableArray *MYBShieldReadGrants(NSString *path){
 NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:path];NSArray *items=[root[@"grants"] isKindOfClass:NSArray.class]?root[@"grants"]:@[];
 NSMutableArray *out=[NSMutableArray array];for(id g in items)if(MYBShieldGrantLive(g)&&out.count<MYB_SHIELD_MAX_GRANTS)[out addObject:g];return out;
}
static inline BOOL MYBShieldWriteGrants(NSString *path,NSArray *grants){
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"version":@1,@"grants":grants} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
 if(!data){MYBShieldSetError(@"the permissions could not be encoded",0);return NO;}
 NSError *err=nil;
 if(![data writeToFile:path options:NSDataWritingAtomic error:&err]){MYBShieldSetError([@"the permissions file cannot be written: " stringByAppendingString:err.localizedDescription?:@"unknown"],(int)err.code);return NO;}
 MYBShieldHandOver(path,0644);return YES;
}

// Run by the root helper: hands the Shield files (and their lock files) to mobile so SpringBoard can always save a permission.
static inline void MYBShieldRepairOwnership(void){
 if(geteuid()!=0)return;NSString *p=MYBShieldPermissionsFile(),*a=MYBShieldActivityFile();
 MYBShieldHandOver(p.stringByDeletingLastPathComponent,0755);
 for(NSString *f in @[p,a])for(NSString *x in @[f,[f stringByAppendingString:@".lock"]])if([NSFileManager.defaultManager fileExistsAtPath:x])MYBShieldHandOver(x,[x hasSuffix:@".lock"]?0600:0644);
}
// ---- grant lifecycle ------------------------------------------------------------------------
static inline BOOL MYBShieldSchemeValid(NSString *scheme){
 if(![scheme isKindOfClass:NSString.class]||!scheme.length||scheme.length>32)return NO;
 NSCharacterSet *ok=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789+.-"];
 return [scheme rangeOfCharacterFromSet:ok.invertedSet].location==NSNotFound&&[scheme characterAtIndex:0]>='a'&&[scheme characterAtIndex:0]<='z';
}
static inline NSString *MYBShieldNormalScheme(NSString *scheme){NSString *l=[scheme isKindOfClass:NSString.class]?scheme.lowercaseString:nil;return MYBShieldSchemeValid(l)?l:nil;}
static inline NSDictionary *MYBShieldAddGrantFor(NSString *path,NSString *kind,NSString *source,NSString *dest,NSString *mode,NSString *scheme,NSString *attempt){
 dest=dest?:@"";scheme=MYBShieldNormalScheme(scheme);if(kind&&[kind isEqual:@"popup"])source=MYBShieldHost(source);
 if(!MYBShieldKindValid(kind)||!MYBShieldModeValid(mode)||!MYBShieldSourceValid(kind,source)||!MYBShieldDestValid(kind,dest)){MYBShieldSetError(@"the permission request is not valid",0);return nil;}
 MYBShieldSetError(@"",0);int lock=MYBShieldLock(path);if(lock<0)return nil;NSDictionary *result=nil;
 NSMutableArray *grants=MYBShieldReadGrants(path);
 // A new permission replaces the one it supersedes. A one-time grant never replaces a longer-lived one (it could only weaken it).
 BOOL isOnce=[mode isEqual:@"once"];
 for(NSDictionary *g in [grants copy])if([g[@"kind"] isEqual:kind]&&[g[@"source"] isEqual:source]&&[(g[@"dest"]?:@"") isEqual:dest]&&(!isOnce||[g[@"mode"] isEqual:@"once"]))[grants removeObject:g];
 if(grants.count<MYB_SHIELD_MAX_GRANTS){
  if([mode isEqual:@"block"]&&![kind isEqual:@"popup"]){MYBShieldSetError(@"only websites can have a standing block",0);MYBShieldUnlock(lock);return nil;} // only popups have a standing block
  double life=[mode isEqual:@"once"]?MYB_SHIELD_ONCE_SECONDS:MYB_SHIELD_TEMP_SECONDS;
  NSMutableDictionary *g=[@{@"id":NSUUID.UUID.UUIDString,@"kind":kind,@"source":source,@"mode":mode,@"created":@(MYBShieldWall())} mutableCopy];if(dest.length)g[@"dest"]=dest;
  if(isOnce){if(scheme)g[@"scheme"]=scheme;if([attempt isKindOfClass:NSString.class]&&attempt.length&&attempt.length<=64)g[@"attempt"]=attempt;} // what exactly it authorises
  if(![mode isEqual:@"always"]&&![mode isEqual:@"block"])MYBClockStamp(g,life);
  [grants addObject:g];
  if(MYBShieldWriteGrants(path,grants)){
   // Success is reported only after the saved file is read back and holds this exact permission.
   BOOL saved=NO;for(NSDictionary *r in MYBShieldReadGrants(path))if([r[@"id"] isEqual:g[@"id"]]){saved=YES;break;}
   if(saved)result=g;else MYBShieldSetError(@"the permission was written but could not be read back",0);
  }
 }else MYBShieldSetError(@"too many saved permissions",0);
 MYBShieldUnlock(lock);return result;
}
static inline NSDictionary *MYBShieldAddGrant(NSString *path,NSString *kind,NSString *source,NSString *dest,NSString *mode){return MYBShieldAddGrantFor(path,kind,source,dest,mode,nil,nil);}
// Judges one attempt against the saved permissions. Returns @{@"verdict":@"allow"|@"block",@"mode":...} or nil when nothing
// applies (the caller then asks). A one-time grant is consumed only when `consume` is YES and only when no longer-lived
// grant already covers the attempt, so one tap cannot burn a standing permission. The most specific matching website wins
// between a block and an allow; between allows the longer-lived one wins.
static inline NSDictionary *MYBShieldDecideScheme(NSString *path,NSString *kind,NSString *source,NSString *dest,NSString *scheme,BOOL consume){
 if(!MYBShieldKindValid(kind))return nil;dest=dest?:@"";scheme=MYBShieldNormalScheme(scheme);if([kind isEqual:@"popup"])source=MYBShieldHost(source);if(!MYBShieldSourceValid(kind,source))return nil;
 int lock=MYBShieldLock(path);if(lock<0)return nil;NSMutableArray *grants=MYBShieldReadGrants(path);NSDictionary *onceMatch=nil;NSString *allowMode=nil;NSUInteger allowLen=0,blockLen=0;BOOL blocked=NO;
 for(NSDictionary *g in grants){
  if(![g[@"kind"] isEqual:kind])continue;NSString *gs=g[@"source"];BOOL match;
  if([kind isEqual:@"popup"])match=[source isEqual:gs]||[source hasSuffix:[@"." stringByAppendingString:gs]];
  else if([kind isEqual:@"appredirect"])match=[source isEqual:gs]&&[dest isEqual:g[@"dest"]];
  else match=[source isEqual:gs];
  if(!match)continue;
  if([g[@"mode"] isEqual:@"block"]){blocked=YES;blockLen=MAX(blockLen,gs.length);}
  else if([g[@"mode"] isEqual:@"once"]){
   // A one-time grant that names a scheme authorises only that scheme; if the scheme cannot be observed now it does not match.
   NSString *gscheme=g[@"scheme"];if(gscheme.length&&![gscheme isEqual:scheme])continue;
   onceMatch=g;
  }
  else if(!allowMode){allowMode=g[@"mode"];allowLen=gs.length;}
 }
 NSDictionary *result=nil;
 if(blocked&&(!(allowMode||onceMatch)||blockLen>=MAX(allowLen,onceMatch?[onceMatch[@"source"] length]:0)))result=@{@"verdict":@"block",@"mode":@"block"};
 else if(allowMode)result=@{@"verdict":@"allow",@"mode":allowMode};
 else if(onceMatch){result=@{@"verdict":@"allow",@"mode":@"once"};if(consume){
  // Consumed under the lock, and the consumption must reach storage: otherwise the same approval could be used again, so refuse.
  [grants removeObject:onceMatch];if(!MYBShieldWriteGrants(path,grants))result=nil;
 }}
 MYBShieldUnlock(lock);return result;
}
static inline NSDictionary *MYBShieldDecide(NSString *path,NSString *kind,NSString *source,NSString *dest,BOOL consume){return MYBShieldDecideScheme(path,kind,source,dest,nil,consume);}
static inline NSString *MYBShieldAllowsScheme(NSString *path,NSString *kind,NSString *source,NSString *dest,NSString *scheme,BOOL consume){
 NSDictionary *d=MYBShieldDecideScheme(path,kind,source,dest,scheme,consume);return [d[@"verdict"] isEqual:@"allow"]?d[@"mode"]:nil;
}
// Allow-only view of the same decision: the grant mode when the attempt is allowed, nil when it is blocked or undecided.
static inline NSString *MYBShieldAllows(NSString *path,NSString *kind,NSString *source,NSString *dest,BOOL consume){
 NSDictionary *d=MYBShieldDecide(path,kind,source,dest,consume);return [d[@"verdict"] isEqual:@"allow"]?d[@"mode"]:nil;
}
static inline BOOL MYBShieldRevoke(NSString *path,NSString *identifier){
 int lock=MYBShieldLock(path);if(lock<0)return NO;NSMutableArray *grants=MYBShieldReadGrants(path);BOOL changed=NO;
 for(NSDictionary *g in [grants copy])if([g[@"id"] isEqual:identifier]){[grants removeObject:g];changed=YES;}
 BOOL ok=changed?MYBShieldWriteGrants(path,grants):NO;MYBShieldUnlock(lock);return ok;
}
// Removes expired / invalid records from disk; returns live grants for display.
static inline NSArray *MYBShieldLiveGrants(NSString *path){
 int lock=MYBShieldLock(path);NSMutableArray *grants=MYBShieldReadGrants(path);
 if(lock>=0){NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:path];if([root[@"grants"] count]!=grants.count)MYBShieldWriteGrants(path,grants);MYBShieldUnlock(lock);}
 return grants;
}
// Backup/restore carry only standing permissions. Temporary and one-time grants are never exported or imported.
static inline NSArray *MYBShieldExportPermanent(NSString *path){
 NSMutableArray *out=[NSMutableArray array];for(NSDictionary *g in MYBShieldReadGrants(path))if([g[@"mode"] isEqual:@"always"]||[g[@"mode"] isEqual:@"block"]){
  NSMutableDictionary *e=[@{@"kind":g[@"kind"],@"source":g[@"source"]} mutableCopy];if([g[@"dest"] length])e[@"dest"]=g[@"dest"];if([g[@"mode"] isEqual:@"block"])e[@"mode"]=@"block";
  [out addObject:e];
 }
 return out;
}
// Validates everything first; returns nil (and changes nothing) if any entry is malformed.
static inline NSArray *MYBShieldValidatedPermanent(id raw){
 if(raw==nil)return @[];if(![raw isKindOfClass:NSArray.class]||[raw count]>MYB_SHIELD_MAX_GRANTS)return nil;NSMutableArray *out=[NSMutableArray array];
 for(id e in raw){
  if(![e isKindOfClass:NSDictionary.class])return nil;NSString *k=e[@"kind"],*s=e[@"source"],*d=e[@"dest"]?:@"",*m=e[@"mode"];if([k isEqual:@"popup"])s=MYBShieldHost(s);
  if(m!=nil&&!([m isEqual:@"always"]||([m isEqual:@"block"]&&[k isEqual:@"popup"])))return nil; // older backups have no mode: standing allow
  if(!MYBShieldKindValid(k)||!MYBShieldSourceValid(k,s)||!MYBShieldDestValid(k,d))return nil;NSMutableDictionary *n=[@{@"kind":k,@"source":s} mutableCopy];if(d.length)n[@"dest"]=d;if([m isEqual:@"block"])n[@"mode"]=@"block";[out addObject:n];}
 return out;
}
// Replaces standing permissions with `permanent` while keeping this boot's live temporary grants untouched.
static inline BOOL MYBShieldReplacePermanent(NSString *path,NSArray *permanent){
 int lock=MYBShieldLock(path);if(lock<0)return NO;NSMutableArray *grants=MYBShieldReadGrants(path);
 for(NSDictionary *g in [grants copy])if([g[@"mode"] isEqual:@"always"]||[g[@"mode"] isEqual:@"block"])[grants removeObject:g];
 for(NSDictionary *e in permanent){NSMutableDictionary *g=[@{@"id":NSUUID.UUID.UUIDString,@"kind":e[@"kind"],@"source":e[@"source"],@"mode":[e[@"mode"] isEqual:@"block"]?@"block":@"always",@"created":@(MYBShieldWall())} mutableCopy];if([e[@"dest"] length])g[@"dest"]=e[@"dest"];[grants addObject:g];}
 BOOL ok=MYBShieldWriteGrants(path,grants);MYBShieldUnlock(lock);return ok;
}

// ---- browser website rules have no switch ----------------------------------------------------------------
// Earlier builds had "Use My Browser Rules" (Enabled) and "Blocked Page Notices" (ShowBlocked). Both are gone: rules always apply
// in supported browsers and blocked-page feedback is always on. Nothing reads either key any more, so a stale NO (from an old
// preference file or an old backup) is inert. This keeps the stored values honest as well and returns whether rules had been Off.
//   One thing was coupled: popup blocking also required Enabled. A saved Enabled=NO with BlockPopups=YES therefore meant popups
//   were NOT being blocked. To keep popup decisions exactly as they were, that combination becomes BlockPopups=NO.
//   The user's rules (Blocked, Allowed, URLs) and every other key are returned untouched.
static inline NSDictionary *MYBShieldNormalizedRules(NSDictionary *saved,BOOL *rulesWereOff){
 if(![saved isKindOfClass:NSDictionary.class]){if(rulesWereOff)*rulesWereOff=NO;return saved;}
 BOOL off=saved[@"Enabled"]&&![saved[@"Enabled"] boolValue];
 if(rulesWereOff)*rulesWereOff=off;
 BOOL fine=saved[@"Enabled"]&&[saved[@"Enabled"] boolValue]&&(!saved[@"ShowBlocked"]||[saved[@"ShowBlocked"] boolValue]);
 if(fine)return saved;
 NSMutableDictionary *next=[saved mutableCopy];
 if(off&&saved[@"BlockPopups"]&&[saved[@"BlockPopups"] boolValue])next[@"BlockPopups"]=@NO;
 next[@"Enabled"]=@YES;next[@"ShowBlocked"]=@YES;
 return next;
}
// ---- popup policy ---------------------------------------------------------------------------
// settings: the Shield preferences (BlockPopups, PopupMode). userGesture: -1 unknown, 0 no, 1 yes.
// Standard blocks windows that were not started by a tap/click and windows whose destination the
// user's own rules or the active filter already block. A gesture is NOT treated as proof that a window is wanted
// in Strict. Strict blocks every new window unless the source site has a popup permission.
typedef NS_ENUM(NSInteger,MYBPopupVerdict){MYBPopupAllow=0,MYBPopupBlockStrict,MYBPopupBlockNoGesture,MYBPopupBlockDestination};
static inline BOOL MYBShieldStrict(NSDictionary *settings){return ![settings[@"PopupMode"] isEqual:@"standard"];}
static inline MYBPopupVerdict MYBShieldPopupVerdict(NSDictionary *settings,int userGesture,BOOL destinationBlocked){
 if(![settings[@"BlockPopups"] boolValue])return MYBPopupAllow; // popups follow only their own switch; website rules have none
 if(MYBShieldStrict(settings))return MYBPopupBlockStrict;
 if(userGesture==0)return MYBPopupBlockNoGesture;
 if(destinationBlocked)return MYBPopupBlockDestination;
 return MYBPopupAllow;
}

// ---- recent activity ------------------------------------------------------------------------
// Local, capped, host-only: no paths, queries or fragments are ever stored.
static inline NSString *MYBShieldSafeEndpoint(NSString *value,BOOL bundle){
 if(![value isKindOfClass:NSString.class]||!value.length)return @"";if(bundle)return MYBShieldBundleValid(value)?value:@"";NSString *h=MYBShieldHost(value);return h?:@"";
}
// `scheme` is what the event knows about the link type: nil = not known (an event from before this field, or one that never saw the link),
// @"" = known to have none (an app-open request), otherwise the link scheme. Allow Once from history is offered only when it is known, so it
// is never wider than the live prompt's one-time permission.
static inline void MYBShieldRecordActivityScheme(NSString *path,NSString *type,NSString *source,NSString *dest,NSString *reason,NSString *scheme,BOOL schemeKnown){
 if(![@[@"popup",@"website",@"appstore",@"appredirect"] containsObject:type])return;
 // popup: source site -> destination site; website: source app -> destination site; appstore: source app only; appredirect: source app -> destination app.
 NSString *s=MYBShieldSafeEndpoint(source,![type isEqual:@"popup"]),*d=MYBShieldSafeEndpoint(dest,[type isEqual:@"appredirect"]);if([type isEqual:@"appstore"])d=@"";
 NSString *why=[reason isKindOfClass:NSString.class]&&reason.length<=48?reason:@"blocked";
 int lock=MYBShieldLock(path);if(lock<0)return;
 NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:path];NSMutableArray *items=[([root[@"items"] isKindOfClass:NSArray.class]?root[@"items"]:@[]) mutableCopy];
 NSString *schemeText=schemeKnown?(MYBShieldNormalScheme(scheme)?:@""):nil;
 NSDictionary *same=nil;for(NSDictionary *i in items)if([i[@"type"] isEqual:type]&&[i[@"source"] isEqual:s]&&[i[@"dest"] isEqual:d]&&[i[@"reason"] isEqual:why]&&((!i[@"scheme"]&&!schemeText)||(schemeText&&[i[@"scheme"] isEqual:schemeText]))){same=i;break;}
 NSMutableDictionary *entry=same?[same mutableCopy]:[@{@"type":type,@"source":s,@"dest":d,@"reason":why,@"count":@0,@"first":@(MYBShieldWall())} mutableCopy];if(!same&&schemeText)entry[@"scheme"]=schemeText;
 if(same)[items removeObject:same];entry[@"count"]=@([entry[@"count"] integerValue]+1);entry[@"last"]=@(MYBShieldWall());[items insertObject:entry atIndex:0];
 while(items.count>MYB_SHIELD_MAX_ACTIVITY)[items removeLastObject];
 NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"version":@1,@"items":items} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];if(data)[data writeToFile:path atomically:YES];MYBShieldUnlock(lock);
}
static inline void MYBShieldRecordActivity(NSString *path,NSString *type,NSString *source,NSString *dest,NSString *reason){MYBShieldRecordActivityScheme(path,type,source,dest,reason,nil,NO);}
static inline NSArray *MYBShieldActivity(NSString *path){NSDictionary *root=[NSDictionary dictionaryWithContentsOfFile:path];return [root[@"items"] isKindOfClass:NSArray.class]?root[@"items"]:@[];}
// Removes exactly one history entry (the one with this identity). Permissions and every other entry are untouched.
static inline BOOL MYBShieldDismissActivity(NSString *path,NSDictionary *entry){
 int lock=MYBShieldLock(path);if(lock<0)return NO;
 NSMutableArray *items=[MYBShieldActivity(path) mutableCopy];BOOL found=NO;
 for(NSDictionary *i in [items copy])if([i[@"type"] isEqual:entry[@"type"]]&&[i[@"source"] isEqual:entry[@"source"]]&&[(i[@"dest"]?:@"") isEqual:(entry[@"dest"]?:@"")]&&[i[@"reason"] isEqual:entry[@"reason"]]&&[(i[@"scheme"]?:@"?") isEqual:(entry[@"scheme"]?:@"?")]&&[i[@"first"] isEqual:entry[@"first"]]){[items removeObject:i];found=YES;break;}
 BOOL ok=YES;
 if(found){if(!items.count)[NSFileManager.defaultManager removeItemAtPath:path error:NULL];else{NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"version":@1,@"items":items} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];ok=data&&[data writeToFile:path atomically:YES];}}
 MYBShieldUnlock(lock);return found&&ok;
}
// One list at a time: the popup screens and the redirect screens each show and clear only their own kinds of event.
static inline NSArray *MYBShieldActivityOfTypes(NSString *path,NSArray *types){
 NSMutableArray *out=[NSMutableArray array];for(NSDictionary *i in MYBShieldActivity(path))if([types containsObject:i[@"type"]])[out addObject:i];return out;
}
static inline BOOL MYBShieldClearActivityTypes(NSString *path,NSArray *types){
 int lock=MYBShieldLock(path);if(lock<0)return NO;
 NSMutableArray *keep=[NSMutableArray array];for(NSDictionary *i in MYBShieldActivity(path))if(![types containsObject:i[@"type"]])[keep addObject:i];
 BOOL ok=YES;
 if(!keep.count)[NSFileManager.defaultManager removeItemAtPath:path error:NULL];
 else{NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"version":@1,@"items":keep} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];ok=data&&[data writeToFile:path atomically:YES];}
 MYBShieldUnlock(lock);return ok;
}
static inline BOOL MYBShieldClearActivity(NSString *path){int lock=MYBShieldLock(path);if(lock<0)return NO;[NSFileManager.defaultManager removeItemAtPath:path error:NULL];MYBShieldUnlock(lock);return YES;}

// Presentation rate limit (per process): same key is announced at most once per `seconds`. It only
// suppresses the notice; it never grants anything and the attempt is still counted in the activity list.
static inline BOOL MYBShieldShouldNotify(NSMutableDictionary *last,NSString *key,double now,double seconds){
 double previous=[last[key] doubleValue];if(previous>0&&now>=previous&&now-previous<seconds)return NO;last[key]=@(now);if(last.count>128)[last removeAllObjects];return YES;
}

// ---- wording ---------------------------------------------------------------------------------
static inline NSString *MYBShieldTitle(NSString *type){
 if([type isEqual:@"popup"])return @"Popup blocked";if([type isEqual:@"appstore"])return @"App Store redirect blocked";if([type isEqual:@"appredirect"])return @"App redirect blocked";return @"Website blocked";
}
static inline NSString *MYBShieldReasonText(NSString *reason){
 NSDictionary *t=@{@"popup-strict":@"Strict popup protection blocks every new window until you allow this site.",
  @"popup-nogesture":@"This window opened without a tap or click.",
  @"popup-destination":@"This window was going to a website your rules block.",
  @"popup-saved-block":@"You chose Always Block for this website.",
  @"popup-busy":@"Blocked. Another popup question was already on screen.",
  @"popup-block-once":@"You chose Block This Time. Nothing was saved.",
  @"custom-rule":@"A rule you added blocks this website.",
  @"filter-mode":@"The active MYbloXX® blocking mode blocks this website.",
  @"appstore":@"Shield stops this app from opening the App Store on its own.",
  @"appredirect":@"Shield stops this app from opening another app on its own.",
  @"prompt-suppressed":@"Blocked. A prompt for this app was already showing or had just been shown, so you were not asked again.",
  @"prompt-unavailable":@"Blocked. No prompt could be shown at that moment, so there was no option to allow it.",
  @"save-failed-access":@"You chose Allow, but MYbloXX\u00ae could not open its permissions file, so nothing was allowed.",
  @"save-failed-write":@"You chose Allow, but the permission could not be written to storage, so nothing was allowed. Your earlier permissions are unchanged.",
  @"save-failed-check":@"You chose Allow, but the saved permission could not be confirmed, so nothing was allowed.",
  @"save-failed":@"You chose Allow, but the permission could not be saved, so nothing was allowed."};
 return t[reason]?:@"Blocked by MYbloXX®.";
}
// The activity list shows a plain reason; the exact system error stays in MYBShieldLastError() and the log.
static inline NSString *MYBShieldSaveFailureReason(void){
 NSString *e=MYBShieldLastError();
 if([e containsString:@"lock"])return @"save-failed-access";if([e containsString:@"cannot be written"]||[e containsString:@"encoded"])return @"save-failed-write";
 if([e containsString:@"read back"])return @"save-failed-check";return @"save-failed";
}
static inline NSString *MYBShieldDurationText(NSString *mode){return [mode isEqual:@"once"]?@"once":[mode isEqual:@"temp"]?@"for 15 minutes":[mode isEqual:@"block"]?@"never (blocked)":@"always";}
