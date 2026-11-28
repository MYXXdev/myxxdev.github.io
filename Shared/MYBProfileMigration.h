#pragma once
// Recognising a standalone legacy MYbloXX proxy profile that a person installed by hand. Pure logic (no system calls), so the helper
// and the tests share it. A profile is positively identified only when ALL of this holds: a known MYbloXX profile identifier, an
// MYXXdev organisation, and exactly one payload that is an automatic global proxy whose PAC address is one MYbloXX has used
// (the published PACs through jsDelivr or GitHub, or the earlier local address). Anything else is left alone: a profile with other
// payloads is "ambiguous" (guided fallback), everything else is "foreign" (never touched: DNS, VPN, MDM, work or school).
#import <Foundation/Foundation.h>
#import "MYBProfiles.h"
// Foreign: not ours, never touched. Candidate: recognised as probably one of ours by identity (identifier, organisation, a published
// PayloadUUID) but its contents could not be read, so it is NOT established that removing it is safe: never removed, guided to Settings.
// StandaloneLegacy: identity AND contents confirmed (one automatic-proxy payload whose PAC address MYbloXX has used): the only kind that
// may be migrated, and only after the person chooses. Ambiguous: readable but not matching (extra or unrelated payloads, another PAC).
typedef NS_ENUM(NSInteger,MYBProfileKind){MYBProfileForeign=0,MYBProfileStandaloneLegacy,MYBProfileAmbiguous,MYBProfileCandidate};
// The organisation the published profiles carry is exactly "MYXXdev\u2122" (older copies may say "MYXXdev"). A prefix or contained name is a look-alike.
static inline BOOL MYBProfileOrganisationOurs(NSString *org){
 if(![org isKindOfClass:NSString.class])return NO;NSString *t=[org stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
 return [t isEqualToString:@"MYXXdev\u2122"]||[t isEqualToString:@"MYXXdev"];
}
static inline BOOL MYBProfileKnownPACAddress(NSString *url){
 if(![url isKindOfClass:NSString.class]||url.length>300)return NO;
 NSArray *patterns=@[@"^https?://cdn\\.jsdelivr\\.net/gh/MYXXdev/myxxdev\\.github\\.io(@[A-Za-z0-9._-]+)?/(MYbloXX|custom|prere)/[A-Za-z0-9._-]+\\.pac$",
  @"^https://raw\\.githubusercontent\\.com/MYXXdev/myxxdev\\.github\\.io/[A-Za-z0-9._-]+/(MYbloXX|custom|prere)/[A-Za-z0-9._-]+\\.pac$",
  @"^https?://myxxdev\\.github\\.io/(MYbloXX|custom|prere)/[A-Za-z0-9._-]+\\.pac$", // every earlier release published here, over http and https
  @"^http://(127\\.0\\.0\\.1|localhost):8787/[A-Za-z0-9]+\\.pac$"];
 for(NSString *p in patterns){NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:p options:0 error:NULL];if([re numberOfMatchesInString:url options:0 range:NSMakeRange(0,url.length)]==1)return YES;}
 return NO;
}
// `profile`: @{identifier, displayName, organization, payloads:[{type, pacURL, proxyType}]}, as read from the system. Missing facts mean "not identified".
static inline MYBProfileKind MYBClassifyProfile(NSDictionary *profile){
 if(![profile isKindOfClass:NSDictionary.class])return MYBProfileForeign;
 NSString *identifier=profile[@"identifier"];if(![identifier isKindOfClass:NSString.class]||![MYBLegacyProfileKnownIdentifiers() containsObject:identifier])return MYBProfileForeign;
 NSString *org=profile[@"organization"];BOOL orgUnknown=![org isKindOfClass:NSString.class]||![org stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length;
 BOOL unreadable=![profile[@"payloads"] isKindOfClass:NSArray.class];
 // An organisation that is READ and is not ours is foreign. An organisation that could not be read is unknown, not "someone else's": with the
 // payloads also unreadable the exact MYbloXX identifier makes it a candidate (corroborated by the effective proxy in MYBMigrationRun).
 if(!(unreadable&&orgUnknown)&&!MYBProfileOrganisationOurs(org))return MYBProfileForeign;
 // The contents could not be read from this iOS. Identifier + organisation + a published PayloadUUID make it a CANDIDATE: recognised, not
 // established as safe to remove. Identity is never enough to remove a profile; without the contents it is left for the person to remove.
 if(![profile[@"payloads"] isKindOfClass:NSArray.class]){
  return MYBProfileCandidate; // identifier (+ organisation when readable); a UUID is NOT required: older releases used many other PayloadUUIDs
 }
 NSArray *payloads=profile[@"payloads"];if(payloads.count!=1)return MYBProfileAmbiguous;
 NSDictionary *p=payloads.firstObject;if(![p isKindOfClass:NSDictionary.class])return MYBProfileAmbiguous;
 if(![p[@"type"] isEqual:@"com.apple.proxy.http.global"]||!MYBProfileKnownPACAddress(p[@"pacURL"])||(p[@"proxyType"]&&![p[@"proxyType"] isEqual:@"Auto"]))return MYBProfileAmbiguous;
 return MYBProfileStandaloneLegacy;
}
// What is kept so the person (or a later release) can see what was replaced: no secrets, just the facts that identified it.
static inline NSDictionary *MYBProfileRecovery(NSDictionary *profile){
 NSDictionary *p=[profile[@"payloads"] firstObject];
 return @{@"identifier":profile[@"identifier"]?:@"",@"displayName":profile[@"displayName"]?:@"",@"organization":profile[@"organization"]?:@"",@"pacURL":([p isKindOfClass:NSDictionary.class]?p[@"pacURL"]:nil)?:@"",@"time":[NSDate date]};
}
// Result codes. 0 done. 3 a profile is present that is not positively a standalone MYbloXX profile (nothing touched).
#define MYB_MIGRATE_FOREIGN 3
#define MYB_MIGRATE_SWITCH_NEEDED 78    // a recognised MYbloXX profile holds the proxy; nothing is removed until the person chooses Switch to Native Protection
#define MYB_MIGRATE_UNAVAILABLE 76      // this iOS will not list, describe or remove profiles for us: guided fallback, nothing changed
#define MYB_MIGRATE_RECORD_FAILED 80    // recovery information could not be stored durably, so nothing was removed
#define MYB_MIGRATE_NOT_CONFIRMED 81    // removal was asked for but the service/proxy state did not confirm it in time: no native apply
#define MYB_MIGRATE_APPLY_FAILED 82     // the profile is gone but native protection did not come up: recorded, never reported as success

// Everything the migration touches comes through this object, so the helper binds the real system and the tests bind a fake one.
@interface MYBMigrationEnv : NSObject
@property(copy) NSArray *(^list)(void);                       // installed profile identifiers, or nil when the service cannot say
@property(copy) NSDictionary *(^describe)(NSString *);        // classifier input for ONE identifier, or nil when it will not say
@property(copy) void (^remove)(NSString *);                   // asks the service to remove; it only has to RUN and finish within its bound
@property(copy) BOOL (^managedGone)(void);                    // the managed-proxy file is gone
@property(copy) NSString *(^effectivePAC)(void);               // the PAC address the system is using NOW (nil: none or cannot say); optional
@property(copy) BOOL (^effectiveClear)(NSString *);           // the system's EFFECTIVE proxy settings no longer use this PAC address
@property(copy) BOOL (^record)(NSDictionary *);               // durable write (data and directory flushed); NO on failure
@property(copy) NSDictionary *(^loadRecord)(void);
@property(copy) int (^apply)(NSString *);                     // native protection for the mode; returns the helper result
@property(copy) BOOL (^owned)(void);                          // MYbloXX's own link is installed and live
@property(copy) void (^wait)(void);                           // one bounded wait step
@property BOOL savedEnabled;@property(copy) NSString *mode;@property int steps;
@end
@implementation MYBMigrationEnv @end

static inline BOOL MYBMigrationListed(NSArray *ids,NSString *identifier){return [ids isKindOfClass:NSArray.class]&&[ids containsObject:identifier];}
static inline int MYBMigrationApply(MYBMigrationEnv *e,NSDictionary *profile,BOOL wasEnabled,NSString *mode,void(^log)(NSString *)){
 NSMutableDictionary *base=[NSMutableDictionary dictionaryWithDictionary:MYBProfileRecovery(profile)];base[@"wasEnabled"]=@(wasEnabled);base[@"mode"]=mode?:@"Default";
 if(!wasEnabled){base[@"phase"]=@"done-disabled";e.record(base);log(@"MIGRATE: legacy profile removed; protection stays off as you saved it");return 0;}
 int rc=e.apply(mode);
 if(rc||!e.owned()){base[@"phase"]=@"apply-failed";base[@"result"]=@(rc?rc:MYB_MIGRATE_APPLY_FAILED);e.record(base);log([NSString stringWithFormat:@"MIGRATE: profile removed but native protection is not on (%d); your saved setting is kept; run Repair",rc]);return MYB_MIGRATE_APPLY_FAILED;}
 base[@"phase"]=@"done";e.record(base);log(@"MIGRATE: legacy profile replaced by native protection");return 0;
}
static inline int MYBMigrationRun(MYBMigrationEnv *e,BOOL userChose,void(^log)(NSString *)){
 if(e.owned()){log(@"MIGRATE: native protection already owns the proxy; nothing to do");return 0;}
 NSDictionary *rec=e.loadRecord();NSString *phase=[rec[@"phase"] isKindOfClass:NSString.class]?rec[@"phase"]:@"";
 BOOL pending=[@[@"removing",@"removed",@"apply-failed",@"removal-failed"] containsObject:phase];
 BOOL wasEnabled=pending?[rec[@"wasEnabled"] boolValue]:e.savedEnabled;NSString *mode=pending&&[rec[@"mode"] length]?rec[@"mode"]:e.mode;
 NSArray *ids=e.list();
 if(![ids isKindOfClass:NSArray.class]){log(@"MIGRATE: this iOS does not let MYbloXX® list profiles; remove the profile in Settings");return MYB_MIGRATE_UNAVAILABLE;}
 // 1. find the one standalone profile. Profiles with other identifiers are never described, let alone touched.
 NSMutableArray *legacy=[NSMutableArray array];BOOL ambiguous=NO,candidate=NO;
 for(NSString *ident in ids){
  if(![ident isKindOfClass:NSString.class]||![MYBLegacyProfileKnownIdentifiers() containsObject:ident])continue;
  NSDictionary *p=e.describe(ident);if(!p){log(@"MIGRATE: this iOS will not describe the profile; remove it in Settings");return MYB_MIGRATE_UNAVAILABLE;}
  MYBProfileKind kind=MYBClassifyProfile(p);
  // Contents unreadable, but the system is demonstrably using a PAC address MYbloXX has published, and exactly this one MYbloXX-identified
  // profile is installed: the profile holding that proxy is established, so it is treated as the standalone profile (identity + effective
  // proxy are two independent observations). Without that corroboration it stays a candidate and is never removed.
  if(kind==MYBProfileCandidate&&e.effectivePAC){NSString *live=e.effectivePAC();
   if(MYBProfileKnownPACAddress(live)){NSMutableDictionary *q=[p mutableCopy];q[@"payloads"]=@[@{@"type":@"com.apple.proxy.http.global",@"pacURL":live,@"proxyType":@"Auto"}];q[@"corroborated"]=@YES;p=q;kind=MYBProfileStandaloneLegacy;log([NSString stringWithFormat:@"MIGRATE: profile contents unreadable; identified by its identifier and the live MYbloXX PAC address (%@)",live]);}}
  if(kind==MYBProfileStandaloneLegacy)[legacy addObject:p];else if(kind==MYBProfileCandidate)candidate=YES;else ambiguous=YES;
 }
 if(ambiguous||legacy.count>1){log(@"MIGRATE: the installed profile is not positively a standalone MYbloXX® profile; left untouched");return MYB_MIGRATE_FOREIGN;}
 if(candidate){log(@"MIGRATE: a profile looks like an earlier MYbloXX® profile by name, organisation and identity, but its contents could not be read, so it is not established as safe to remove; remove it in Settings");return MYB_MIGRATE_UNAVAILABLE;}
 NSDictionary *profile=legacy.firstObject;
 if(profile&&!userChose){log(@"MIGRATE: a recognised MYbloXX® profile is installed; waiting for the person to choose Switch to Native Protection");return MYB_MIGRATE_SWITCH_NEEDED;}
 if(!profile){
  // Nothing of ours is installed. An interrupted run is finished (idempotent); otherwise there is nothing to do.
  if(!pending){if(!e.managedGone()){log(@"MIGRATE: another profile holds the proxy; left untouched");return MYB_MIGRATE_FOREIGN;}log(@"MIGRATE: no legacy profile is present; nothing to do");return 0;}
  NSString *pac=rec[@"pacURL"]?:@"";
  for(int i=0;i<e.steps&&!(e.managedGone()&&e.effectiveClear(pac));i++)e.wait();
  if(!(e.managedGone()&&e.effectiveClear(pac))){log(@"MIGRATE: the earlier removal is not confirmed; native protection not applied");return MYB_MIGRATE_NOT_CONFIRMED;}
  NSDictionary *stub=@{@"identifier":rec[@"identifier"]?:@"",@"displayName":rec[@"displayName"]?:@"",@"organization":rec[@"organization"]?:@"",@"payloads":@[@{@"pacURL":pac}]};
  return MYBMigrationApply(e,stub,wasEnabled,mode,log);
 }
 // 2. recovery first: if this cannot be stored durably nothing is removed.
 NSMutableDictionary *r=[NSMutableDictionary dictionaryWithDictionary:MYBProfileRecovery(profile)];r[@"phase"]=@"removing";r[@"wasEnabled"]=@(wasEnabled);r[@"mode"]=mode?:@"Default";
 if(!e.record(r)){log(@"MIGRATE: recovery information could not be stored; nothing was removed");return MYB_MIGRATE_RECORD_FAILED;}
 // 3. ask the service, then confirm from the service AND the file AND the effective proxy, with a bounded wait.
 NSString *ident=profile[@"identifier"],*pac=[[profile[@"payloads"] firstObject][@"pacURL"] description]?:@"";
 e.remove(ident);
 BOOL confirmed=NO;
 for(int i=0;i<=e.steps;i++){
  NSArray *now=e.list();
  if([now isKindOfClass:NSArray.class]&&!MYBMigrationListed(now,ident)&&e.managedGone()&&e.effectiveClear(pac)){confirmed=YES;break;}
  if(i<e.steps)e.wait();
  else log([NSString stringWithFormat:@"MIGRATE: after removal: still listed=%d managedFileGone=%d effectiveProxyClear=%d",MYBMigrationListed(now,ident)?1:0,e.managedGone()?1:0,e.effectiveClear(pac)?1:0]);
 }
 if(!confirmed){r[@"phase"]=@"removal-failed";e.record(r);log(@"MIGRATE: the profile is still in effect after removal; nothing else changed");return MYB_MIGRATE_NOT_CONFIRMED;}
 r[@"phase"]=@"removed";e.record(r);
 return MYBMigrationApply(e,profile,wasEnabled,mode,log);
}
