// Classifier for hand-installed legacy MYbloXX profiles: only a positively identified standalone profile is ever a removal candidate.
#import <Foundation/Foundation.h>
#import "../Shared/MYBProfileMigration.h"
static int failures=0;
static void check(BOOL ok,NSString *msg){printf("%s %s\n",ok?"PASS":"FAIL",msg.UTF8String);if(!ok)failures++;}
static NSDictionary *prof(NSString *ident,NSString *org,NSArray *payloads){return @{@"identifier":ident,@"displayName":@"MYbloXX",@"organization":org,@"payloads":payloads};}
static NSDictionary *pay(NSString *type,NSString *url){return @{@"type":type,@"pacURL":url,@"proxyType":@"Auto"};}
int main(void){@autoreleasepool{
 NSString *remote=@"https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/blockApple.pac";
 NSString *good=@"com.apple.proxy.http.global";
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(good,remote)]))==MYBProfileStandaloneLegacy,@"historical remote profile is recognised");
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx.legacy",@"MYXXdev",@[pay(good,@"http://127.0.0.1:8787/Default.pac")]))==MYBProfileStandaloneLegacy,@"earlier local-address profile is recognised");
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(good,@"https://evil.example/MYbloXX/Default.pac")]))==MYBProfileAmbiguous,@"known identifier with a foreign PAC address is ambiguous, not removed");
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(good,remote),pay(@"com.apple.dnsSettings.managed",remote)]))==MYBProfileAmbiguous,@"extra payloads make it ambiguous");
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(@"com.apple.vpn.managed",remote)]))==MYBProfileAmbiguous,@"wrong payload type is ambiguous");
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx.dns.google",@"MYXXdev",@[pay(good,remote)]))==MYBProfileForeign,@"DNS profile identifier is foreign");
 check(MYBClassifyProfile(prof(@"com.corp.mdm",@"Acme",@[pay(good,remote)]))==MYBProfileForeign,@"work/MDM profile is foreign");
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"Someone Else",@[pay(good,remote)]))==MYBProfileForeign,@"known identifier from another organisation is foreign");
 check(MYBClassifyProfile(@{})==MYBProfileForeign&&MYBClassifyProfile((NSDictionary *)@"x")==MYBProfileForeign,@"malformed input is foreign");
 check(!MYBProfileKnownPACAddress(@"https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/x.pac?evil=1")&&!MYBProfileKnownPACAddress(@"https://cdn.jsdelivr.net.evil.com/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/x.pac"),@"look-alike PAC addresses are rejected");
 check(MYBProfileKnownPACAddress(@"https://raw.githubusercontent.com/MYXXdev/myxxdev.github.io/master/MYbloXX/Default.pac"),@"raw GitHub PAC address is accepted");
 NSDictionary *rec=MYBProfileRecovery(prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(good,remote)]));
 check([rec[@"pacURL"] isEqual:remote]&&rec[@"identifier"],@"recovery record keeps what identified the profile");

 // ---- the migration engine against a fake system ---------------------------------------------------------------------
 NSDictionary *legacyP=prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(good,remote)]);
 NSDictionary *(^desc)(NSDictionary *)=^NSDictionary *(NSDictionary *d){return d;};(void)desc;
 // World: identifiers installed -> profile dictionaries; managed file and effective proxy follow the removal unless told not to.
 __block NSMutableDictionary *installed;__block BOOL managedOn,effectiveOn,recordOK,removeWorks,applyOK,ownedNow,listOK,cleanButStale;__block NSDictionary *stored;
 __block int removeCalls,applyCalls,waits,describeCalls;__block NSMutableArray *describedIds;
 BOOL(^proxyHeld)(void)=^BOOL{for(NSDictionary *q in installed.allValues)for(NSDictionary *pp in q[@"payloads"])if([pp[@"type"] isEqual:@"com.apple.proxy.http.global"])return (BOOL)YES;return (BOOL)NO;};
 void(^world)(NSDictionary *)=^(NSDictionary *profiles){installed=[profiles mutableCopy];managedOn=proxyHeld();effectiveOn=managedOn;recordOK=YES;removeWorks=YES;applyOK=YES;ownedNow=NO;listOK=YES;cleanButStale=NO;stored=nil;removeCalls=applyCalls=waits=describeCalls=0;describedIds=[NSMutableArray array];};
 MYBMigrationEnv *(^env)(BOOL,NSString *)=^MYBMigrationEnv *(BOOL wasEnabled,NSString *mode){
  MYBMigrationEnv *e=[MYBMigrationEnv new];e.savedEnabled=wasEnabled;e.mode=mode;e.steps=6;
  e.list=^NSArray *{return listOK?installed.allKeys:nil;};
  e.describe=^NSDictionary *(NSString *i){describeCalls++;[describedIds addObject:i];return installed[i];};
  e.remove=^(NSString *i){removeCalls++;if(removeWorks){[installed removeObjectForKey:i];managedOn=proxyHeld();if(!cleanButStale)effectiveOn=managedOn;}};
  e.managedGone=^BOOL{return (BOOL)!managedOn;};e.effectiveClear=^BOOL(NSString *p){(void)p;return (BOOL)!effectiveOn;};
  e.record=^BOOL(NSDictionary *d){if(!recordOK)return NO;stored=d;return YES;};e.loadRecord=^NSDictionary *{return stored;};
  e.apply=^int(NSString *m){(void)m;applyCalls++;if(applyOK){ownedNow=YES;managedOn=YES;effectiveOn=YES;return 0;}return 5;};
  e.owned=^BOOL{return ownedNow;};e.wait=^{waits++;};return e;};
 void(^nolog)(NSString *)=^(NSString *l){(void)l;};
 // happy path
 world(@{@"net.myxxdev.mybloxx":legacyP});int rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
 check(rc==0&&removeCalls==1&&applyCalls==1&&[stored[@"phase"] isEqual:@"done"]&&ownedNow,@"happy path: removed once, confirmed, native applied, recorded done");
 check(rc==0&&MYBMigrationRun(env(YES,@"Default"),YES,nolog)==0&&removeCalls==1&&applyCalls==1,@"a second run is idempotent (no second removal or apply)");
 // saved disabled state survives
 world(@{@"net.myxxdev.mybloxx":legacyP});rc=MYBMigrationRun(env(NO,@"Default"),YES,nolog);
 check(rc==0&&applyCalls==0&&!ownedNow&&[stored[@"phase"] isEqual:@"done-disabled"],@"a saved disabled state is kept: the profile goes, native stays off");
 // mismatches: nothing is removed
 NSArray *bad=@[prof(@"net.myxxdev.mybloxx",@"Other Org",@[pay(good,remote)]),prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(good,@"https://evil.example/MYbloXX/Default.pac")]),prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(good,remote),pay(@"com.apple.dnsSettings.managed",remote)]),prof(@"net.myxxdev.mybloxx.dns.google",@"MYXXdev",@[pay(good,remote)])];
 for(NSDictionary *b in bad){world(@{b[@"identifier"]:b});rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);check(rc==MYB_MIGRATE_FOREIGN&&removeCalls==0&&applyCalls==0&&stored==nil,[NSString stringWithFormat:@"mismatch left untouched: %@ / %@ / %lu payload(s)",b[@"identifier"],b[@"organization"],(unsigned long)[b[@"payloads"] count]]);}
 // an unrelated profile next to ours is never described or removed
 world(@{@"net.myxxdev.mybloxx":legacyP,@"com.corp.vpn":prof(@"com.corp.vpn",@"Corp",@[pay(@"com.apple.vpn.managed",@"x")]),@"com.corp.mdm":prof(@"com.corp.mdm",@"Corp",@[])});
 rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
 check(rc==0&&removeCalls==1&&applyCalls==1,@"unrelated profiles present: ours is replaced, nothing else is acted on");
 check(![describedIds containsObject:@"com.corp.vpn"]&&![describedIds containsObject:@"com.corp.mdm"]&&installed[@"com.corp.vpn"]&&installed[@"com.corp.mdm"],@"unrelated profiles were never described and are still installed");
 // service cannot list: guided fallback, nothing changed
 world(@{@"net.myxxdev.mybloxx":legacyP});listOK=NO;rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
 check(rc==MYB_MIGRATE_UNAVAILABLE&&removeCalls==0&&stored==nil,@"service unavailable: guided fallback, no removal, no record");
 // recovery record cannot be stored: nothing is removed
 world(@{@"net.myxxdev.mybloxx":legacyP});recordOK=NO;rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
 check(rc==MYB_MIGRATE_RECORD_FAILED&&removeCalls==0&&installed.count==1,@"recovery not durable: the profile is NOT removed");
 // removal asked but nothing happens (not authorised): bounded wait, no apply, profile intact
 world(@{@"net.myxxdev.mybloxx":legacyP});removeWorks=NO;rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
 check(rc==MYB_MIGRATE_NOT_CONFIRMED&&applyCalls==0&&installed.count==1&&waits==6&&[stored[@"phase"] isEqual:@"removal-failed"],@"removal that does not happen: bounded wait (6 steps), no apply, profile intact, recorded");
 // service says gone and file gone, but the effective proxy is still set: not confirmed
 world(@{@"net.myxxdev.mybloxx":legacyP});cleanButStale=YES;rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
 check(rc==MYB_MIGRATE_NOT_CONFIRMED&&applyCalls==0&&waits==6,@"effective proxy still set: not confirmed, native not applied");
 // removal works but native apply fails: never a success, intent kept, then recovered on the next run
 world(@{@"net.myxxdev.mybloxx":legacyP});applyOK=NO;rc=MYBMigrationRun(env(YES,@"blockXXX"),YES,nolog);
 check(rc==MYB_MIGRATE_APPLY_FAILED&&[stored[@"phase"] isEqual:@"apply-failed"]&&[stored[@"wasEnabled"] boolValue]&&[stored[@"mode"] isEqual:@"blockXXX"]&&!ownedNow,@"apply failure: not reported as success, saved intent (enabled, blockXXX) recorded");
 applyOK=YES;managedOn=NO;effectiveOn=NO;rc=MYBMigrationRun(env(NO,@"Default"),YES,nolog); // saved state now says disabled, but the RECORD wins
 check(rc==0&&ownedNow&&[stored[@"phase"] isEqual:@"done"],@"the next run finishes the apply from the recorded intent, not from changed saved state");
 // interrupted after the record but before removal: the profile is still there, so the run retries removal
 world(@{@"net.myxxdev.mybloxx":legacyP});stored=@{@"phase":@"removing",@"wasEnabled":@(1),@"mode":@"blockXXX",@"identifier":@"net.myxxdev.mybloxx",@"pacURL":remote};
 rc=MYBMigrationRun(env(NO,@"Default"),YES,nolog);check(rc==0&&removeCalls==1&&applyCalls==1,@"interrupted before removal: retried with the recorded intent");
 // interrupted after removal, before apply: the profile is gone, so the run confirms and applies
 world(@{});stored=@{@"phase":@"removed",@"wasEnabled":@(1),@"mode":@"Default",@"identifier":@"net.myxxdev.mybloxx",@"pacURL":remote};
 rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);check(rc==0&&removeCalls==0&&applyCalls==1&&ownedNow,@"interrupted after removal: confirmed, then native applied");
 // a different profile still holds the managed proxy after ours is gone: preserved, not replaced
 world(@{@"net.myxxdev.mybloxx":legacyP});{MYBMigrationEnv *x=env(YES,@"Default");NSArray *(^origList)(void)=x.list;(void)origList;x.managedGone=^BOOL{return NO;};rc=MYBMigrationRun(x,YES,nolog);}
 check(rc==MYB_MIGRATE_NOT_CONFIRMED&&applyCalls==0,@"another occupant still holds the proxy: nothing is applied over it");
 // nothing installed and nothing recorded
 world(@{});managedOn=NO;effectiveOn=NO;rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);check(rc==0&&removeCalls==0&&applyCalls==0&&stored==nil,@"no profile: nothing happens");
 world(@{});managedOn=YES;rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);check(rc==MYB_MIGRATE_FOREIGN&&applyCalls==0,@"an unrecognised occupant with no profile of ours is left alone");
 // ---- historical evidence (the project's own published profiles) and the read-only inspection ---------------------------------
 {NSDictionary *hist[]={@{@"u":@"FD9913A0-D24B-4C09-93B0-D3F4066D8E79",@"p":@"MYbloXX"},@{@"u":@"73857AE2-F370-4581-9143-8B725816008B",@"p":@"MYbloXXallowFB"},@{@"u":@"257827F1-D835-45BD-85E2-F25056B81C6A",@"p":@"MYbloXXallowY"},@{@"u":@"9DB9ED54-D401-4CE1-880D-F669E6155EBA",@"p":@"MYbloXXnoApple"},@{@"u":@"FFB0B45E-9845-4AC6-8965-04DD10FF4FC7",@"p":@"MYbloXXnoSocials"},@{@"u":@"CE2BD79D-0696-4922-A872-AD78BFBB60C4",@"p":@"MYbloXXnoXXX"}};
  for(int i=0;i<6;i++){
   NSString *url=[NSString stringWithFormat:@"http://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/%@.pac",hist[i][@"p"]];
   NSMutableDictionary *h=[prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[pay(good,url)]) mutableCopy];h[@"uuid"]=hist[i][@"u"];
   check(MYBClassifyProfile(h)==MYBProfileStandaloneLegacy,[NSString stringWithFormat:@"published profile %@ (http PAC, org with trademark sign) is recognised",hist[i][@"p"]]);
   NSMutableDictionary *noPayload=[h mutableCopy];[noPayload removeObjectForKey:@"payloads"];
   check(MYBClassifyProfile(noPayload)==MYBProfileCandidate,[NSString stringWithFormat:@"%@ is only a CANDIDATE (recognised, not established safe) when the payload cannot be read",hist[i][@"p"]]);}}
 {NSMutableDictionary *u=[prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[]) mutableCopy];[u removeObjectForKey:@"payloads"];u[@"uuid"]=@"00000000-0000-0000-0000-000000000000";
  check(MYBClassifyProfile(u)==MYBProfileCandidate,@"unreadable payload with another UUID is still a CANDIDATE (older releases used many UUIDs): recognised, never removed on identity alone");
  [u removeObjectForKey:@"uuid"];check(MYBClassifyProfile(u)==MYBProfileCandidate,@"unreadable payload and no UUID is a candidate: unreadable is not 'not MYbloXX'");
  u[@"uuid"]=@"FD9913A0-D24B-4C09-93B0-D3F4066D8E79";u[@"organization"]=@"Acme";check(MYBClassifyProfile(u)==MYBProfileForeign,@"a published UUID under another organisation is foreign");}
 for(NSString *v in @[@"http://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/MYbloXX.pac",@"https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io/MYbloXX/Default.pac",@"https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@abc1234/MYbloXX/blockXXX.pac"])
  check(MYBProfileKnownPACAddress(v),[@"PAC address variant accepted: " stringByAppendingString:v]);
 // read-only inspection: Enable, Repair and startup never remove a recognised profile; only the person's choice does
 world(@{@"net.myxxdev.mybloxx":legacyP});rc=MYBMigrationRun(env(YES,@"Default"),NO,nolog);
 check(rc==MYB_MIGRATE_SWITCH_NEEDED&&removeCalls==0&&applyCalls==0&&stored==nil&&installed.count==1,@"inspection finds the profile, removes nothing, applies nothing and writes no record");
 world(@{@"net.myxxdev.mybloxx":legacyP});rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
 check(rc==0&&removeCalls==1&&applyCalls==1,@"after the person chooses Switch, the profile is removed and native protection applied");
 world(@{@"com.corp.mdm":prof(@"com.corp.mdm",@"Acme",@[pay(good,remote)])});rc=MYBMigrationRun(env(YES,@"Default"),NO,nolog);
 check(rc==MYB_MIGRATE_FOREIGN&&removeCalls==0&&describeCalls==0,@"an MDM or work profile is never described or touched, even by inspection");
 world(@{@"net.myxxdev.mybloxx":legacyP});listOK=NO;rc=MYBMigrationRun(env(YES,@"Default"),NO,nolog);
 check(rc==MYB_MIGRATE_UNAVAILABLE&&removeCalls==0&&applyCalls==0,@"inspection failure is reported as unresolved, never as no conflict");
 world(@{@"net.myxxdev.mybloxx":legacyP});{MYBMigrationEnv *x=env(YES,@"Default");x.describe=^NSDictionary *(NSString *i){(void)i;return nil;};rc=MYBMigrationRun(x,NO,nolog);}
 check(rc==MYB_MIGRATE_UNAVAILABLE&&removeCalls==0,@"a profile the system will not describe is unresolved, never ignored");
 // recognising a candidate is not establishing that it is safe to remove: identity alone never authorises removal, even when the person chose
 {NSMutableDictionary *cand=[prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[]) mutableCopy];[cand removeObjectForKey:@"payloads"];cand[@"uuid"]=@"FD9913A0-D24B-4C09-93B0-D3F4066D8E79";
  world(@{@"net.myxxdev.mybloxx":cand});rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
  check(rc==MYB_MIGRATE_UNAVAILABLE&&removeCalls==0&&applyCalls==0&&stored==nil&&installed.count==1,@"a recognised profile whose contents are unreadable is never removed, even after the person chose Switch");
  rc=MYBMigrationRun(env(YES,@"Default"),NO,nolog);check(rc==MYB_MIGRATE_UNAVAILABLE&&removeCalls==0,@"and is reported as unresolved by plain inspection");}
 // look-alike organisations and extra or unrelated payloads: nothing is removed
 for(NSString *org in @[@"MYXXdevil",@"MYXXdev Inc",@"myxxdev",@"XMYXXdev",@"MYXXdev™ Support",@"Not MYXXdev",@""]){
  check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",org,@[pay(good,remote)]))==MYBProfileForeign,[@"look-alike organisation is foreign: " stringByAppendingString:org]);}
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[pay(good,remote)]))==MYBProfileStandaloneLegacy&&MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev",@[pay(good,remote)]))==MYBProfileStandaloneLegacy,@"the exact organisation wording, with or without the trademark sign, is accepted");
 check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[pay(good,remote),pay(@"com.apple.security.root",@"x")]))==MYBProfileAmbiguous&&MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[]))==MYBProfileAmbiguous,@"extra payloads, or no payload at all, are ambiguous");
 for(NSString *badURL in @[@"http://cdn.jsdelivr.net.evil.example/gh/MYXXdev/myxxdev.github.io/MYbloXX/Default.pac",@"http://cdn.jsdelivr.net/gh/MYXXdev/other/MYbloXX/Default.pac",@"http://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io/MYbloXX/Default.pac?x=1",@"ftp://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io/MYbloXX/Default.pac",@"http://127.0.0.1:9999/Default.pac"])
  check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[pay(good,badURL)]))==MYBProfileAmbiguous,[@"unknown PAC endpoint is ambiguous: " stringByAppendingString:badURL]);
 // interrupted migration resumes without removing anything and without asking again
 world(@{});managedOn=NO;effectiveOn=NO;stored=@{@"phase":@"removed",@"identifier":@"net.myxxdev.mybloxx",@"pacURL":remote,@"wasEnabled":@YES,@"mode":@"Default"};
 rc=MYBMigrationRun(env(YES,@"Default"),NO,nolog);check(rc==0&&removeCalls==0&&applyCalls==1,@"an interrupted migration is finished by a plain inspection (no removal involved)");
 // replacement with the same identifier and UUID but different contents: identity matches, content does not
 {NSMutableDictionary *swap=[prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[pay(good,@"https://evil.example/x.pac")]) mutableCopy];swap[@"uuid"]=@"FD9913A0-D24B-4C09-93B0-D3F4066D8E79";
  check(MYBClassifyProfile(swap)==MYBProfileAmbiguous,@"same identifier and UUID with different, readable contents is ambiguous");}
 // ---- historical profiles from the project's own repository (PAC hosts used by earlier releases) --------------------------------
 for(NSString *v in @[@"http://myxxdev.github.io/MYbloXX/MYbloXXnoXXX.pac",@"https://myxxdev.github.io/MYbloXX/MYbloXX.pac",@"http://myxxdev.github.io/custom/StephanA.pac",@"http://myxxdev.github.io/custom/noApple.pac",@"http://myxxdev.github.io/prere/MYbloXXDisabler.pac"]){
  check(MYBProfileKnownPACAddress(v),[@"historical PAC address accepted: " stringByAppendingString:v]);
  check(MYBClassifyProfile(prof(@"net.myxxdev.mybloxx",@"MYXXdev™",@[pay(good,v)]))==MYBProfileStandaloneLegacy,[@"historical profile recognised: " stringByAppendingString:v]);}
 for(NSString *v in @[@"http://myxxdev.github.io.evil.example/MYbloXX/x.pac",@"http://myxxdev.github.io/other/x.pac",@"http://evilmyxxdev.github.io/MYbloXX/x.pac",@"http://myxxdev.github.io/MYbloXX/x.pac?a=1",@"http://myxxdev.github.io/MYbloXX/../x.pac/y"])
  check(!MYBProfileKnownPACAddress(v),[@"look-alike historical address rejected: " stringByAppendingString:v]);
 // unreadable contents AND unreadable organisation: still a candidate (not foreign), and only the live MYbloXX PAC address establishes it
 {NSDictionary *idOnly=@{@"identifier":@"net.myxxdev.mybloxx",@"uuid":@"11111111-2222-3333-4444-555555555555",@"displayName":@"",@"organization":@""};
  check(MYBClassifyProfile(idOnly)==MYBProfileCandidate,@"identity-only description with an unreadable organisation is a candidate");
  world(@{@"net.myxxdev.mybloxx":idOnly});rc=MYBMigrationRun(env(YES,@"Default"),YES,nolog);
  check(rc==MYB_MIGRATE_UNAVAILABLE&&removeCalls==0,@"no live-proxy corroboration: a candidate is never removed");
  world(@{@"net.myxxdev.mybloxx":idOnly});{MYBMigrationEnv *x=env(YES,@"Default");x.effectivePAC=^NSString *{return @"http://myxxdev.github.io/MYbloXX/MYbloXXnoApple.pac";};rc=MYBMigrationRun(x,YES,nolog);}
  check(rc==0&&removeCalls==1&&applyCalls==1&&ownedNow,@"candidate corroborated by the live MYbloXX PAC address: removed after the choice, then native applied");
  world(@{@"net.myxxdev.mybloxx":idOnly});{MYBMigrationEnv *x=env(YES,@"Default");x.effectivePAC=^NSString *{return @"https://corp.example/proxy.pac";};rc=MYBMigrationRun(x,YES,nolog);}
  check(rc==MYB_MIGRATE_UNAVAILABLE&&removeCalls==0,@"another proxy address is not corroboration: nothing removed");
  world(@{@"net.myxxdev.mybloxx":idOnly});{MYBMigrationEnv *x=env(YES,@"Default");x.effectivePAC=^NSString *{return @"http://myxxdev.github.io/MYbloXX/MYbloXXnoApple.pac";};rc=MYBMigrationRun(x,NO,nolog);}
  check(rc==MYB_MIGRATE_SWITCH_NEEDED&&removeCalls==0,@"corroborated candidate still waits for the person's choice");}
 return failures?1:0;}}
