// Runs the REAL privileged helper code (Helper/MYXXdev.m and its .inc files, compiled in) against a fixture root.
// Only three things that touch the live system are injected (see MYB_HELPER_TESTING in the helper): configd restarts,
// the managed-parent check and network fetches. Everything else - the transactions, the journaled inline-PAC apply,
// rule generation, backup/restore - is the shipping code, so an apply FAILURE can be produced and the recovery
// observed: the previous configuration and the user's saved intent must survive.
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#define main MYBHelperEntryNotUsedByTests
#include "../Helper/MYXXdev.m"
#undef main
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static NSString *gPacs,*gRoot;
static NSFileManager *fm(void){return NSFileManager.defaultManager;}
static NSString *P(NSString *rel){return [gRoot stringByAppendingPathComponent:rel];}
static NSString *DataFile(NSString *name){return P([@"var/mobile/Library/MYbloXX" stringByAppendingPathComponent:name]);}
static NSString *PrefFile(NSString *name){return P([@"var/mobile/Library/Preferences" stringByAppendingPathComponent:name]);}
static NSDictionary *Snap(NSArray *paths){NSMutableDictionary *d=[NSMutableDictionary dictionary];for(NSString *p in paths){NSData *x=[NSData dataWithContentsOfFile:p];d[p]=x?:(id)NSNull.null;}return d;}
static BOOL Same(NSDictionary *a,NSDictionary *b){return [a isEqualToDictionary:b];}
static NSString *Runtime(void){return MYBRuntimeStatus()[@"script"];}
static NSString *Verdict(NSString *script,NSString *host){
 JSContext *c=[JSContext new];
 [c evaluateScript:@"function dnsDomainIs(h,d){return h.slice(-d.length)===d;} function shExpMatch(s,p){return new RegExp('^'+p.split('*').map(function(x){return x.replace(/[.+?^${}()|[\\]\\\\]/g,'\\\\$&');}).join('.*')+'$').test(s);}"];
 [c evaluateScript:script];JSValue *f=c[@"FindProxyForURL"];if(!f.isObject)return @"NO-FUNCTION";
 return [f callWithArguments:@[[NSString stringWithFormat:@"https://%@/",host],host]].toString;
}
static void Fixture(void){
 gRoot=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"mybhelper-" stringByAppendingString:NSUUID.UUID.UUIDString]];
 setenv("MYB_FIXTURE_ROOT",gRoot.UTF8String,1);setenv("MYB_TEST_BOOTSTRAP",P(@"jb").UTF8String,1);
 NSString *data=DataFile(@""),*prefs=PrefFile(@"");
 for(NSString *d in @[data,prefs,P(@"iptmp"),P(@"Managed"),P(@"jb/usr/share/mybloxx")])[fm() createDirectoryAtPath:d withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:NULL];
 [fm() copyItemAtPath:gPacs toPath:P(@"jb/usr/share/mybloxx/pacs") error:NULL];
 [fm() copyItemAtPath:[gPacs.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"generator"] toPath:P(@"jb/usr/share/mybloxx/generator") error:NULL];
 [fm() copyItemAtPath:gPacs toPath:DataFile(@"PAC") error:NULL];
 gMYBIPDirOverride=P(@"iptmp/MYbloXX-inlinepac");gMYBIPManagedOverride=P(@"Managed/com.apple.SystemConfiguration.plist");gMYBIPOwnerOverride=(int)geteuid();
 gMYBTestRestartResult=0;gMYBTestRestarts=0;gMYBTestFetch=nil;
 [@{@"blocked":@[@"kept.example"],@"allowed":@[]} writeToFile:DataFile(@"AppliedRules.plist") atomically:YES];
 [@{@"blocked":@[@"kept.example"],@"allowed":@[]} writeToFile:DataFile(@"ManualRules.plist") atomically:YES];
 [@{@"blocked":@[@"kept.example"],@"allowed":@[]} writeToFile:PrefFile(@"net.myxxdev.mybloxx.ruledraft.plist") atomically:YES];
 [@{@"Enabled":@YES,@"Blocked":@[@"kept.example"],@"Allowed":@[],@"URLs":@[]} writeToFile:PrefFile(@"net.myxxdev.mybloxx.safariguard.plist") atomically:YES];
 touch(KSystemOptIn);
}
// The header line of the shipping Default PAC, so the aging/newer-generation checks follow the real stamp.
static NSString *StampLine(void){NSString *t=[NSString stringWithContentsOfFile:[gPacs stringByAppendingPathComponent:@"Default.pac"] encoding:NSUTF8StringEncoding error:NULL];for(NSString *l in [t componentsSeparatedByString:@"\n"])if([l hasPrefix:@"// Updated: "])return l;return @"// Updated: none";}
// "YYYY/MM/DD - HH:MM" as the numeric stamp line the previous generator wrote (digits only, no zone: read as CET).
static NSString *StampVar(NSString *text){int m=0,d=0,y=0,h=0,mi=0;sscanf(text.UTF8String,"%d/%d/%d - %d:%d",&y,&m,&d,&h,&mi);return [NSString stringWithFormat:@"var MYB_STAMP=%04d%02d%02d%02d%02d;",y,m,d,h,mi];}
static NSArray *WatchPaths(void){return @[KState,DataFile(@"AppliedRules.plist"),DataFile(@"ManualRules.plist"),MYBWebsiteFile(),MYBDraftFile(),PrefFile(@"net.myxxdev.mybloxx.safariguard.plist"),DataFile(@"Updates.plist"),MYBShieldPermissionsFile()];}
static NSString *LinkTarget(NSString *name){return [fm() destinationOfSymbolicLinkAtPath:DataFile(name) error:NULL];}
static NSDictionary *Web(void){return [NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()]?:@{};}

int main(int argc,char **argv){@autoreleasepool{
 if(argc<2){fprintf(stderr,"usage: helper-real-native <pacs dir>\n");return 2;}gPacs=@(argv[1]);
 NSString *host=@"100widgets.com";
 // ================= website exceptions =================
 Fixture();
 CHECK(configure(@"Default")==0&&ownedLink()&&MYBRuntimeEnabled(),"fixture: protection configured through the real helper");
 NSString *baseline=Runtime();CHECK(baseline.length>1000,"fixture: a full PAC is embedded");
 CHECK([Verdict(baseline,host) containsString:@"PROXY"],"fixture: the test host is blocked by the base PAC");
 NSDictionary *files=Snap(WatchPaths());NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:KState];
 // -- permanent exception, apply fails (configd restart error): nothing may change
 gMYBTestRestartResult=69;gMYBTestRestarts=0;
 int rc=allowWebsite(host,@"Default",@"always");
 CHECK(rc==69,"failed apply is reported");
 CHECK(Same(files,Snap(WatchPaths())),"previous rule files restored byte-for-byte after a failed apply");
 CHECK([Runtime() isEqualToString:baseline],"the live inline PAC is the previous configuration again (recovered)");
 CHECK([Verdict(Runtime(),host) containsString:@"PROXY"],"and still blocks the host: the failed exception did not leak");
 CHECK([[NSDictionary dictionaryWithContentsOfFile:KState] isEqualToDictionary:state]&&[loadSavedState()[@"enabled"] boolValue],"saved intent (enabled, mode) unchanged by the failed operation");
 CHECK(gMYBTestRestarts>=2,"the real recovery path ran (apply attempt + recovery)");
 // -- same operation succeeds
 gMYBTestRestartResult=0;
 CHECK(allowWebsite(host,@"Default",@"always")==0,"permanent exception applies");
 CHECK(![Verdict(Runtime(),host) containsString:@"PROXY"],"the exception is in the effective, live PAC");
 NSString *withPermanent=Runtime();
 // -- temporary exception: failure keeps the previous (permanent-only) configuration
 files=Snap(WatchPaths());gMYBTestRestartResult=69;
 CHECK(allowWebsite(@"sub.100widgets.com",@"Default",@"temp")==69,"temporary exception apply failure reported");
 CHECK(Same(files,Snap(WatchPaths()))&&[Runtime() isEqualToString:withPermanent],"temporary exception failure leaves files and live PAC as they were");
 // -- remove the permanent one so the temporary behaviour is observable on a blocked host
 Fixture();configure(@"Default");gMYBTestRestartResult=0;
 CHECK(allowWebsite(host,@"Default",@"temp")==0,"temporary exception applies");
 CHECK(![Verdict(Runtime(),host) containsString:@"PROXY"]&&[Web()[@"temp"] count]==1&&[Web()[@"domains"] count]==0,"temporary exception is live and is NOT stored as a permanent one");
 // expired: the effective PAC generated NOW no longer carries it even before any prune runs ...
 NSMutableDictionary *aged=[Web() mutableCopy];NSMutableArray *list=[NSMutableArray array];for(NSDictionary *e in Web()[@"temp"]){NSMutableDictionary *m=[e mutableCopy];m[@"wallExpiry"]=@1;[list addObject:m];}aged[@"temp"]=list;[aged writeToFile:MYBWebsiteFile() atomically:YES];
 CHECK([Verdict(MYBEffectiveScript(@"Default"),host) containsString:@"PROXY"],"an expired exception is absent from a freshly generated effective PAC");
 // ... and the pruning pass removes it from the live runtime PAC too
 CHECK(![Verdict(Runtime(),host) containsString:@"PROXY"],"fixture: the live PAC still carries it until pruned");
 CHECK(revokeWebsite(nil)==0,"pruneexpired runs");
 CHECK([Verdict(Runtime(),host) containsString:@"PROXY"]&&[Web()[@"temp"] count]==0,"expired exception disappears from the live effective PAC, not just the list");
 // revoked: same check for an explicit revoke
 CHECK(allowWebsite(host,@"Default",@"temp")==0&&![Verdict(Runtime(),host) containsString:@"PROXY"],"granted again");
 CHECK(revokeWebsite(host)==0,"revoke");
 CHECK([Verdict(Runtime(),host) containsString:@"PROXY"]&&[Web()[@"temp"] count]==0,"revoked exception disappears from the live effective PAC");
 // revoke whose apply fails keeps the exception AND the live PAC consistent
 CHECK(allowWebsite(host,@"Default",@"temp")==0,"granted for the failure case");
 files=Snap(WatchPaths());NSString *liveBefore=Runtime();gMYBTestRestartResult=69;
 CHECK(revokeWebsite(host)==69&&Same(files,Snap(WatchPaths()))&&[Runtime() isEqualToString:liveBefore],"a failed revoke changes nothing");
 gMYBTestRestartResult=0;

 // ================= rule updates: one canonical rules file; every combination is generated on the device =================
 Fixture();configure(@"Default");
 NSString *genDir=[gPacs.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"generator"];
 NSData *canonBase=[NSData dataWithContentsOfFile:[genDir stringByAppendingPathComponent:@"canonical.json"]];
 NSData *(^variant)(NSString *,NSString *)=^NSData *(NSString *stamp,NSString *extraDomain){
  NSMutableDictionary *c=[NSJSONSerialization JSONObjectWithData:canonBase options:NSJSONReadingMutableContainers error:NULL];
  if(stamp)c[@"stamp"]=stamp;if(extraDomain)[c[@"base"][@"domains"] addObject:extraDomain];
  return [NSJSONSerialization dataWithJSONObject:c options:0 error:NULL];};
 NSString *rev=@"0123456789abcdef0123456789abcdef01234567";
 __block NSData *upstreamCanon=variant(@"2026/11/28 - 09:00 UTC",@"rules-update-probe.example.com");__block BOOL upstreamHasCanon=YES;__block BOOL corruptDownload=NO;
 NSData *(^fetch)(NSString *)=^NSData *(NSString *url){
  if([url containsString:@"/commits/master"])return [NSJSONSerialization dataWithJSONObject:@{@"sha":rev} options:0 error:NULL];
  if([url containsString:@"/contents/MYbloXX"]){NSMutableArray *a=[NSMutableArray arrayWithObject:@{@"name":@"Default.pac",@"sha":@"legacy-file-ignored-by-this-version"}];
   if(upstreamHasCanon)[a addObject:@{@"name":@"canonical.json",@"sha":GitBlobSHA(upstreamCanon)}];return [NSJSONSerialization dataWithJSONObject:a options:0 error:NULL];}
  if([url hasSuffix:@"/MYbloXX/canonical.json"]){if(corruptDownload){NSMutableData *d=[upstreamCanon mutableCopy];[d appendData:[@" " dataUsingEncoding:NSUTF8StringEncoding]];return d;}return upstreamCanon;}
  return nil; // no per-mode PAC is ever requested
 };gMYBTestFetch=fetch;
 NSString *before=Runtime();files=Snap(WatchPaths());NSString *pacDirBefore=PACDirectory();NSDictionary *st=[NSDictionary dictionaryWithContentsOfFile:KState];
 CHECK([Verdict(before,@"rules-update-probe.example.com") isEqualToString:@"DIRECT"],"fixture: the probe host is allowed before the update");
 // a download that fails the revision hash is not installed
 corruptDownload=YES;rc=updatePACs(NO);corruptDownload=NO;
 CHECK(rc!=0&&[PACDirectory().stringByResolvingSymlinksInPath isEqualToString:pacDirBefore.stringByResolvingSymlinksInPath]&&[Runtime() isEqualToString:before],"a rules file that does not match the verified revision changes nothing");
 // invalid rules (the validator refuses a protected service) are rejected before anything is staged
 { NSData *keep=upstreamCanon;NSMutableDictionary *bad=[NSJSONSerialization JSONObjectWithData:canonBase options:NSJSONReadingMutableContainers error:NULL];bad[@"stamp"]=@"2026/11/28 - 10:00 UTC";[bad[@"base"][@"domains"] addObject:@"apple.com"];
   upstreamCanon=[NSJSONSerialization dataWithJSONObject:bad options:0 error:NULL];rc=updatePACs(NO);
   CHECK(rc==65&&[Runtime() isEqualToString:before]&&[PACDirectory().stringByResolvingSymlinksInPath isEqualToString:pacDirBefore.stringByResolvingSymlinksInPath],"rules that block a protected service are rejected and the previous rules stay");
   CHECK([UpdateState()[@"lastResult"] containsString:@"validation failed"],"the rejection is reported");
   upstreamCanon=keep; }
 // the apply fails (configd restart error): the previous working configuration comes back, the staged generation is removed
 gMYBTestRestartResult=69;gMYBTestRestarts=0;
 rc=updatePACs(NO);
 CHECK(rc==69,"update apply failure reported");
 CHECK([PACDirectory().stringByResolvingSymlinksInPath isEqualToString:pacDirBefore.stringByResolvingSymlinksInPath],"previous rule generation is still the one in use");
 CHECK([Runtime() isEqualToString:before]&&MYBRuntimeEnabled(),"live PAC and protection are the previous working configuration");
 CHECK([[NSDictionary dictionaryWithContentsOfFile:KState] isEqualToDictionary:st],"saved intent unchanged by the failed update");
 CHECK(![[UpdateState()[@"revision"] description] isEqualToString:rev],"the failed revision is not recorded as installed");
 for(NSString *entry in [fm() contentsOfDirectoryAtPath:DataFile(@"") error:NULL])CHECK(![entry hasPrefix:@"PAC-"],"the staged generation of a failed update is removed");
 // update succeeds: every combination exists in the new generation, generated locally
 gMYBTestRestartResult=0;rc=updatePACs(NO);
 CHECK(rc==0&&[UpdateState()[@"revision"] isEqualToString:rev]&&[UpdateState()[@"rulesSource"] isEqualToString:@"canonical"],"update applies from the canonical rules");
 CHECK([[Verdict(Runtime(),@"rules-update-probe.example.com") description] containsString:@"PROXY"],"the new rule is live in the selected mode");
 { NSString *gen=PACDirectory().stringByResolvingSymlinksInPath;int have=0;for(NSString *m in MYBGeneratedPACNames())if(filePACValid([gen stringByAppendingPathComponent:[m stringByAppendingString:@".pac"]]))have++;
   CHECK(have==(int)MYBGeneratedPACNames().count&&have==40,"all 32 combinations and the historical names exist in the generation");
   NSString *combo=[NSString stringWithContentsOfFile:[gen stringByAppendingPathComponent:@"allowY+blockAdSense+blockXXX.pac"] encoding:NSUTF8StringEncoding error:NULL];
   CHECK([[Verdict(combo,@"rules-update-probe.example.com") description] containsString:@"PROXY"]&&[combo containsString:@"MYbloXX by MYXXdev (allowY! + blockAdSense + noXXX)"],"a combination file is generated from the same canonical data"); }
 // a selected combination keeps working through an update, with the user's custom rules and off state untouched
 Fixture();gMYBTestFetch=fetch;configure(@"allowY+blockXXX");rc=updatePACs(NO);
 CHECK(rc==0&&[selectedMode() isEqualToString:@"allowY+blockXXX"]&&[[Verdict(Runtime(),@"kept.example") description] containsString:@"PROXY"]&&[[Verdict(Runtime(),@"rules-update-probe.example.com") description] containsString:@"PROXY"],"a selected combination and the custom rules survive an update");
 // noXXX PIN protection survives an update, a failed update and a rollback: the PIN record, the selected noXXX mode and the blocking
 // of a noXXX-only site are the same afterwards, and no approval is ever created by any of them
 { Fixture();gMYBTestFetch=fetch;configure(@"blockXXX");NSData *secret=PinDeviceSecret(YES);NSDictionary *record=MYBPinRecordNew(@"4821",secret,2000);
   CHECK(secret&&record&&PinPrepareFolder()&&[record writeToFile:PinRecordPath() atomically:YES],"fixture: a PIN is set through the shipping storage code");
   NSData *recordBefore=[NSData dataWithContentsOfFile:PinRecordPath()];
   CHECK([[Verdict(Runtime(),@"stripchat.com") description] containsString:@"PROXY"],"fixture: noXXX blocks a noXXX-only site");
   gMYBTestRestartResult=69;rc=updatePACs(NO);gMYBTestRestartResult=0;
   CHECK(rc==69&&PinConfigured()&&[[NSData dataWithContentsOfFile:PinRecordPath()] isEqualToData:recordBefore]&&[selectedMode() isEqualToString:@"blockXXX"]&&[[Verdict(Runtime(),@"stripchat.com") description] containsString:@"PROXY"],"a failed update keeps noXXX and the PIN");
   rc=updatePACs(NO);
   CHECK(rc==0&&PinConfigured()&&[[NSData dataWithContentsOfFile:PinRecordPath()] isEqualToData:recordBefore]&&[selectedMode() isEqualToString:@"blockXXX"]&&MYBRuntimeEnabled()&&[[Verdict(Runtime(),@"stripchat.com") description] containsString:@"PROXY"]&&[[Verdict(Runtime(),@"rules-update-probe.example.com") description] containsString:@"PROXY"],"a successful update keeps noXXX on and the PIN, and brings the new rules");
   CHECK(rollbackPACs()==0&&PinConfigured()&&[selectedMode() isEqualToString:@"blockXXX"]&&[[Verdict(Runtime(),@"stripchat.com") description] containsString:@"PROXY"],"a rollback keeps noXXX on and the PIN");
   CHECK(PinGrantsLoad().count==0,"no update or rollback ever creates an approval");
   // saved-mode migration: a historical name for noXXX still means noXXX after the update, and the PIN still gates leaving it
   { NSMutableDictionary *state=[loadSavedState() mutableCopy];state[@"mode"]=@"MYbloXXnoXXX";[state writeToFile:KState atomically:YES];
     CHECK([selectedMode() isEqualToString:@"blockXXX"]&&MYBPinProtectedNow(PinConfigured(),PinEnabledFlag(),selectedMode()),"a saved historical noXXX name migrates to noXXX and stays PIN-protected"); } }
 // rollback whose apply fails keeps the updated generation
 NSString *updated=Runtime();gMYBTestRestartResult=69;
 CHECK(rollbackPACs()==69&&[Runtime() isEqualToString:updated],"failed rollback keeps the updated configuration live");
 gMYBTestRestartResult=0;
 // rollback to a generation saved by an earlier release (historical files only) is completed with built-in files, not refused
 { NSString *old=[DataFile(@"") stringByAppendingPathComponent:@"PAC-oldrelease"];[fm() createDirectoryAtPath:old withIntermediateDirectories:YES attributes:nil error:NULL];
   for(NSString *m in @[@"Default",@"allowY",@"blockAdSense",@"blockApple",@"blockSocials",@"blockXXX"])[fm() copyItemAtPath:[gPacs stringByAppendingPathComponent:[m stringByAppendingString:@".pac"]] toPath:[old stringByAppendingPathComponent:[m stringByAppendingString:@".pac"]] error:NULL];
   NSMutableDictionary *us=UpdateState();us[@"previousDirectory"]=old;SaveUpdates(us);
   CHECK(rollbackPACs()==0,"rollback to a historical-only generation succeeds");
   CHECK(filePACValid([[PACDirectory() stringByResolvingSymlinksInPath] stringByAppendingPathComponent:@"allowY+blockXXX.pac"]),"the rolled-back generation has every combination"); }
 // upstream that only has the old per-mode files: nothing is installed, and the reason is stated
 Fixture();gMYBTestFetch=fetch;configure(@"Default");upstreamHasCanon=NO;NSString *beforeLegacy=Runtime();
 CHECK(updatePACs(NO)==0&&[Runtime() isEqualToString:beforeLegacy]&&[UpdateState()[@"lastResult"] containsString:@"canonical rules file"],"an upstream without canonical rules leaves the built-in rules and says so");
 upstreamHasCanon=YES;gMYBTestFetch=nil;

 // ================= built-in rules reach the effective configuration on upgrade =================
 {
  NSString *bundledDir=P(@"jb/usr/share/mybloxx/pacs");
  NSData *(^readDef)(NSString *)=^NSData *(NSString *d){return [NSData dataWithContentsOfFile:[d stringByAppendingPathComponent:@"Default.pac"]];};
  void (^ageActive)(NSString *,NSString *)=^(NSString *dir,NSString *stamp){
   for(NSString *m in updateModes()){NSString *f=[dir stringByAppendingPathComponent:[m stringByAppendingString:@".pac"]];NSString *t=[NSString stringWithContentsOfFile:f encoding:NSUTF8StringEncoding error:NULL];if(!t)continue;
    t=[t stringByReplacingOccurrencesOfString:StampLine() withString:StampVar(stamp)];t=[t stringByAppendingString:@"\n// OLD-GENERATION-MARKER\n"];[t writeToFile:f atomically:YES encoding:NSUTF8StringEncoding error:NULL];}
  };
  // (a) old copies active -> replaced, rollback target kept, user data untouched
  Fixture();ageActive(DataFile(@"PAC"),@"2022/09/19 - 11:25");configure(@"Default");
  NSData *custom=[@"function FindProxyForURL(u,h){return \"DIRECT\";} // custom override padding padding padding padding padding padding padding padding padding padding padding" dataUsingEncoding:NSUTF8StringEncoding];[custom writeToFile:DataFile(@"PAC/Custom.pac") atomically:YES];
  NSDictionary *intent=[NSDictionary dictionaryWithContentsOfFile:KState],*applied=[NSDictionary dictionaryWithContentsOfFile:DataFile(@"AppliedRules.plist")];
  gMYBTestRestartResult=0;
  CHECK(refreshBundledPACs()==0,"refresh succeeds on an upgrade with old rule copies");
  CHECK([readDef(PACDirectory()) isEqualToData:readDef(bundledDir)],"the built-in rules are now the effective rules");
  CHECK([readDef(DataFile(@"PAC")) isEqualToData:readDef(bundledDir)],"the fallback PAC folder is refreshed too");
  CHECK([[NSString stringWithContentsOfFile:[UpdateState()[@"previousDirectory"] stringByAppendingPathComponent:@"Default.pac"] encoding:NSUTF8StringEncoding error:NULL] containsString:@"OLD-GENERATION-MARKER"],"the replaced rules are kept as the rollback target");
  CHECK([[NSDictionary dictionaryWithContentsOfFile:KState] isEqualToDictionary:intent],"selected mode and settings are preserved");
  CHECK([[NSDictionary dictionaryWithContentsOfFile:DataFile(@"AppliedRules.plist")] isEqualToDictionary:applied],"custom rules are preserved");
  CHECK([[NSData dataWithContentsOfFile:DataFile(@"PAC/Custom.pac")] isEqualToData:custom]&&[[NSData dataWithContentsOfFile:[PACDirectory() stringByAppendingPathComponent:@"Custom.pac"]] isEqualToData:custom],"the Custom PAC / Proxy Override travels with the new generation");
  CHECK(MYBRuntimeEnabled(),"protection stays on");
  NSDictionary *afterState=[UpdateState() copy];NSUInteger gens=0;for(NSString *e in [fm() contentsOfDirectoryAtPath:DataFile(@"") error:NULL])if([e hasPrefix:@"PAC-"])gens++;
  CHECK(refreshBundledPACs()==0&&[UpdateState() isEqualToDictionary:afterState],"refresh is idempotent");
  NSUInteger gens2=0;for(NSString *e in [fm() contentsOfDirectoryAtPath:DataFile(@"") error:NULL])if([e hasPrefix:@"PAC-"])gens2++;CHECK(gens==gens2,"a second refresh creates no new generation");
  CHECK(rollbackPACs()==0&&[[NSString stringWithContentsOfFile:[PACDirectory() stringByAppendingPathComponent:@"Default.pac"] encoding:NSUTF8StringEncoding error:NULL] containsString:@"OLD-GENERATION-MARKER"],"rollback returns to the previous rules");
  // (b) failed apply keeps the old rules live and active
  Fixture();ageActive(DataFile(@"PAC"),@"2022/09/19 - 11:25");configure(@"Default");
  NSString *liveBefore=Runtime();NSString *dirBefore=PACDirectory().stringByResolvingSymlinksInPath;gMYBTestRestartResult=69;
  CHECK(refreshBundledPACs()==69,"a failed refresh reports the failure");
  CHECK([PACDirectory().stringByResolvingSymlinksInPath isEqualToString:dirBefore]&&[Runtime() isEqualToString:liveBefore]&&MYBRuntimeEnabled(),"a failed refresh keeps the previous rules active and live");
  for(NSString *e in [fm() contentsOfDirectoryAtPath:DataFile(@"") error:NULL])CHECK(![e hasPrefix:@"PAC-"],"a failed refresh leaves no staged generation");
  CHECK(![UpdateState()[@"bundledDigest"] length],"a failed refresh is retried at the next opportunity");
  gMYBTestRestartResult=0;CHECK(refreshBundledPACs()==0&&[readDef(PACDirectory()) isEqualToData:readDef(bundledDir)],"the retry succeeds");
  // (d) an older upstream cannot replace the built-in rules
  Fixture();configure(@"Default");gMYBTestRestartResult=0;
  NSData *olderCanon=[NSJSONSerialization dataWithJSONObject:({NSMutableDictionary *c=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[[gPacs stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"generator/canonical.json"]] options:NSJSONReadingMutableContainers error:NULL];c[@"stamp"]=@"2020/01/01 - 09:00 UTC";c;}) options:0 error:NULL];
  NSString *oldRev=@"fedcba9876543210fedcba9876543210fedcba98";__block int fetches=0;
  gMYBTestFetch=^NSData *(NSString *url){fetches++;
   if([url containsString:@"/commits/master"])return [NSJSONSerialization dataWithJSONObject:@{@"sha":oldRev} options:0 error:NULL];
   if([url containsString:@"/contents/MYbloXX"])return [NSJSONSerialization dataWithJSONObject:@[@{@"name":@"canonical.json",@"sha":GitBlobSHA(olderCanon)}] options:0 error:NULL];
   if([url hasSuffix:@"/MYbloXX/canonical.json"])return olderCanon;
   return nil;};
  NSData *builtIn=readDef(bundledDir);NSString *live=Runtime();id autoBefore=UpdateState()[@"automatic"];
  CHECK(updatePACs(NO)==0,"an older upstream is not an error");
  CHECK([readDef(PACDirectory()) isEqualToData:builtIn]&&[Runtime() isEqualToString:live],"older upstream rules do not replace the built-in rules");
  CHECK(![[UpdateState()[@"revision"] description] isEqualToString:oldRev]&&[UpdateState()[@"lastResult"] containsString:@"older"],"the older upstream is reported, not installed");
  CHECK(UpdateState()[@"automatic"]==autoBefore||[UpdateState()[@"automatic"] isEqual:autoBefore],"automatic updates are left as they were");
  int seen=fetches;CHECK(updatePACs(NO)==0&&fetches>seen-1&&[readDef(PACDirectory()) isEqualToData:builtIn],"re-checking the same older upstream is stable");
  gMYBTestFetch=nil;
 }


 // ================= UTC release flow: engine and rule age are decided separately =================
 {
  NSString *bundledDir=P(@"jb/usr/share/mybloxx/pacs");
  NSData *(^readDef)(NSString *)=^NSData *(NSString *d){return [NSData dataWithContentsOfFile:[d stringByAppendingPathComponent:@"Default.pac"]];};
  void (^ageActive)(NSString *,NSString *)=^(NSString *dir,NSString *digits){
   for(NSString *m in updateModes()){NSString *f=[dir stringByAppendingPathComponent:[m stringByAppendingString:@".pac"]];NSString *t=[NSString stringWithContentsOfFile:f encoding:NSUTF8StringEncoding error:NULL];if(!t)continue;
    t=[t stringByReplacingOccurrencesOfString:StampLine() withString:StampVar(digits)];t=[t stringByAppendingString:@"\n// OLD-GENERATION-MARKER\n"];[t writeToFile:f atomically:YES encoding:NSUTF8StringEncoding error:NULL];}
  };
  NSString *(^rev)(NSString *)=^NSString *(NSString *c){return [@"" stringByPaddingToLength:40 withString:c startingAtIndex:0];};
  __block NSData *serve=nil;__block NSString *serveRev=rev(@"a");
  NSData *(^serveFetch)(NSString *)=^NSData *(NSString *url){
   if([url containsString:@"/commits/master"])return [NSJSONSerialization dataWithJSONObject:@{@"sha":serveRev} options:0 error:NULL];
   if([url containsString:@"/contents/MYbloXX"])return [NSJSONSerialization dataWithJSONObject:@[@{@"name":@"canonical.json",@"sha":GitBlobSHA(serve)}] options:0 error:NULL];
   if([url hasSuffix:@"/MYbloXX/canonical.json"])return serve;
   return nil;};
  NSUInteger (^generations)(void)=^NSUInteger{NSUInteger n=0;for(NSString *e in [fm() contentsOfDirectoryAtPath:DataFile(@"") error:NULL])if([e hasPrefix:@"PAC-"])n++;return n;};
  NSData *(^mutated)(void (^)(NSMutableDictionary *))=^NSData *(void (^edit)(NSMutableDictionary *)){NSMutableDictionary *c=[NSJSONSerialization JSONObjectWithData:canonBase options:NSJSONReadingMutableContainers error:NULL];c[@"stamp"]=@"2026/11/29 - 10:00 UTC";edit(c);return [NSJSONSerialization dataWithJSONObject:c options:0 error:NULL];};
  NSData *bundledCanon=[NSData dataWithContentsOfFile:[GeneratorDirectory() stringByAppendingPathComponent:@"canonical.json"]];
  NSString *probe=@"rules-update-probe.example.com";
  // (1) fresh install: the built-in set is the active set, recorded with its rules file; an upstream with the same rules is a no-op
  Fixture();configure(@"Default");gMYBTestRestartResult=0;
  CHECK(refreshBundledPACs()==0&&[readDef(PACDirectory()) isEqualToData:readDef(bundledDir)]&&ActiveEngineCurrent()&&MYBPACEngineCurrent(readDef(PACDirectory())),"fresh install: the built-in rules and the optimized engine are active");
  CHECK([UpdateState()[@"canonicalSHA"] isEqualToString:GitBlobSHA(bundledCanon)]&&generations()==0,"fresh install: the installed rules file is recorded and no extra generation is made");
  gMYBTestFetch=serveFetch;serve=bundledCanon;serveRev=rev(@"a");gMYBTestRestarts=0;
  { NSString *dirBefore=PACDirectory().stringByResolvingSymlinksInPath,*liveBefore=Runtime();
    CHECK(updatePACs(NO)==0&&[PACDirectory().stringByResolvingSymlinksInPath isEqualToString:dirBefore]&&[Runtime() isEqualToString:liveBefore]&&gMYBTestRestarts==0&&generations()==0,"unchanged rules file: nothing is reapplied");
    CHECK([UpdateState()[@"lastResult"] isEqualToString:@"Rules are up to date"]&&[UpdateState()[@"lastCheck"] isKindOfClass:NSDate.class],"unchanged rules are reported as up to date");
    serveRev=rev(@"b");CHECK(updatePACs(NO)==0&&gMYBTestRestarts==0&&generations()==0&&[UpdateState()[@"revision"] isEqualToString:rev(@"b")],"an unrelated commit to master with the same rules file is a no-op"); }
  // (2) upgrade from the old engine at the SAME instant: 01:10 CET digits == 00:10 UTC. The optimized engine must become active.
  Fixture();ageActive(DataFile(@"PAC"),@"2026/11/26 - 19:10");configure(@"Default");
  { NSMutableDictionary *us=UpdateState();us[@"automatic"]=@YES;SaveUpdates(us);
    NSData *oldDef=readDef(DataFile(@"PAC"));
    CHECK(MYBPACStamp(oldDef)==MYBPACStamp(readDef(bundledDir))&&!MYBPACEngineCurrent(oldDef)&&MYBPACEngineCurrent(readDef(bundledDir)),"fixture: the old engine holds the same instant as the built-in rules");
    NSDictionary *intent=[NSDictionary dictionaryWithContentsOfFile:KState],*applied=[NSDictionary dictionaryWithContentsOfFile:DataFile(@"AppliedRules.plist")];
    CHECK(refreshBundledPACs()==0,"same-stamp upgrade succeeds");
    CHECK([readDef(PACDirectory()) isEqualToData:readDef(bundledDir)]&&ActiveEngineCurrent(),"same-stamp upgrade: the optimized engine is now active");
    CHECK([[NSString stringWithContentsOfFile:[UpdateState()[@"previousDirectory"] stringByAppendingPathComponent:@"Default.pac"] encoding:NSUTF8StringEncoding error:NULL] containsString:@"OLD-GENERATION-MARKER"],"same-stamp upgrade: the old engine's set is the rollback target");
    CHECK([[NSDictionary dictionaryWithContentsOfFile:KState] isEqualToDictionary:intent]&&[[NSDictionary dictionaryWithContentsOfFile:DataFile(@"AppliedRules.plist")] isEqualToDictionary:applied]&&[UpdateState()[@"automatic"] boolValue]&&MYBRuntimeEnabled(),"same-stamp upgrade: mode, custom rules, Automatic Updates and protection are preserved");
    CHECK([[NSData dataWithContentsOfFile:StoredCanonicalPath(PACDirectory().stringByResolvingSymlinksInPath)] isEqualToData:bundledCanon]||generations()==1,"same-stamp upgrade: a generation was installed"); }
  // (3) cached r16 rules, newer by date, with no stored rules file: they cannot win; RAGGR is active at once. A later RAGGR release still installs.
  Fixture();ageActive(DataFile(@"PAC"),@"2026/11/28 - 09:00"); // 09:00 CET == 08:00 UTC, newer than the built-in RAGGR rules
  { for(NSString *m in updateModes()){NSString *f=[DataFile(@"PAC") stringByAppendingPathComponent:[m stringByAppendingString:@".pac"]];NSString *t=[NSString stringWithContentsOfFile:f encoding:NSUTF8StringEncoding error:NULL];if(!t)continue;
     NSMutableArray *keep=[NSMutableArray array];for(NSString *ln in [t componentsSeparatedByString:@"\n"]){if([ln hasPrefix:@"//"])[keep addObject:ln];}
     [keep addObject:@"function FindProxyForURL(u,h){return \"DIRECT\";}"];[[keep componentsJoinedByString:@"\n"] writeToFile:f atomically:YES encoding:NSUTF8StringEncoding error:NULL];} // r16-style rules: no RAGGR shapes
    configure(@"Default");gMYBTestRestartResult=0;NSString *shapeHost=@"qwertyuiop.shop";
    CHECK(![Verdict(Runtime(),shapeHost) containsString:@"PROXY"],"fixture: the cached r16 rules do not block a RAGGR shape host");
    CHECK(refreshBundledPACs()==0&&[readDef(PACDirectory()) isEqualToData:readDef(bundledDir)]&&ActiveEngineCurrent(),"cached r16 rules newer by date lose: the built-in RAGGR set is active after the upgrade");
    CHECK([Verdict(Runtime(),shapeHost) containsString:@"PROXY"],"RAGGR is live: the shape host is blocked");
    CHECK([[NSString stringWithContentsOfFile:[UpdateState()[@"previousDirectory"] stringByAppendingPathComponent:@"Default.pac"] encoding:NSUTF8StringEncoding error:NULL] containsString:@"OLD-GENERATION-MARKER"],"the cached r16 set is the rollback target");
    gMYBTestFetch=serveFetch;serve=variant(@"2026/11/28 - 08:00 UTC",probe);serveRev=rev(@"c");
    CHECK(updatePACs(NO)==0&&ActiveEngineCurrent()&&MYBPACStamp(readDef(PACDirectory()))==202611280800LL&&[Verdict(Runtime(),probe) containsString:@"PROXY"]&&[Verdict(Runtime(),shapeHost) containsString:@"PROXY"],"a later RAGGR release installs and keeps the RAGGR rules");
    CHECK([[NSData dataWithContentsOfFile:StoredCanonicalPath(PACDirectory().stringByResolvingSymlinksInPath)] isEqualToData:serve],"the rules file is stored with the generation"); }
  // (3b) cached r16 rules WITH a stored (non-RAGGR) rules file and the current engine: same outcome
  Fixture();configure(@"Default");
  { NSMutableDictionary *c=[NSJSONSerialization JSONObjectWithData:canonBase options:NSJSONReadingMutableContainers error:NULL];[c removeObjectForKey:@"compact"];c[@"stamp"]=@"2026/11/28 - 08:00 UTC";
    NSData *r16canon=[NSJSONSerialization dataWithJSONObject:c options:0 error:NULL];NSString *why=nil;NSDictionary *g=MYBGenerateModePACs(r16canon,GeneratorDirectory(),&why);int rc3=0;NSString *stage=g?StageGeneration(g,r16canon,&rc3):nil;
    CHECK(stage&&PointPACs(stage),"fixture: a downloaded r16-style generation (no RAGGR section) is active");
    NSMutableDictionary *st=UpdateState();st[@"revision"]=rev(@"9");SaveUpdates(st);configure(@"Default");gMYBTestRestartResult=0;
    CHECK(MYBPACEngineCurrent(readDef(PACDirectory()))&&!ActiveEngineCurrent(),"fixture: it has the current header and engine but is not RAGGR");
    CHECK(![Verdict(Runtime(),@"qwertyuiop.shop") containsString:@"PROXY"],"fixture: it does not block the RAGGR shape host");
    CHECK(refreshBundledPACs()==0&&[readDef(PACDirectory()) isEqualToData:readDef(bundledDir)]&&[Verdict(Runtime(),@"qwertyuiop.shop") containsString:@"PROXY"],"the newer-dated r16 generation is replaced by the built-in RAGGR set"); }
  // (3c) a feed without the RAGGR section can never replace RAGGR, however new
  Fixture();configure(@"Default");gMYBTestRestartResult=0;gMYBTestFetch=serveFetch;
  { NSMutableDictionary *c=[NSJSONSerialization JSONObjectWithData:canonBase options:NSJSONReadingMutableContainers error:NULL];[c removeObjectForKey:@"compact"];c[@"stamp"]=@"2026/12/01 - 08:00 UTC";serve=[NSJSONSerialization dataWithJSONObject:c options:0 error:NULL];serveRev=rev(@"7");
    NSString *dirNow=PACDirectory().stringByResolvingSymlinksInPath,*liveNow=Runtime();gMYBTestRestarts=0;
    CHECK(updatePACs(NO)==0&&[PACDirectory().stringByResolvingSymlinksInPath isEqualToString:dirNow]&&[Runtime() isEqualToString:liveNow]&&gMYBTestRestarts==0&&generations()==0&&[UpdateState()[@"lastResult"] containsString:@"RAGGR"],"a newer feed with no RAGGR rules is refused; the built-in RAGGR rules stay");
    CHECK([Verdict(Runtime(),@"qwertyuiop.shop") containsString:@"PROXY"],"RAGGR is still live after the refused feed");
    [c removeObjectForKey:@"stamp"];c[@"stamp"]=@"2026/11/28 - 08:00 UTC";serve=[NSJSONSerialization dataWithJSONObject:c options:0 error:NULL];serveRev=rev(@"8");
    CHECK(updatePACs(NO)==0&&[Runtime() isEqualToString:liveNow],"and again for an automatic check");
    CHECK(updatePACs(YES)==0&&[Runtime() isEqualToString:liveNow],"Automatic Updates path is the same"); }
  // (4) newer downloaded rules from the old engine WITH a stored rules file: regenerated at upgrade, data kept
  Fixture();ageActive(DataFile(@"PAC"),@"2026/11/28 - 09:00");configure(@"Default");
  { NSData *stored=variant(@"2026/11/28 - 08:00 UTC",probe);[stored writeToFile:StoredCanonicalPath(DataFile(@"PAC")) atomically:YES];
    gMYBTestRestartResult=0;CHECK(refreshBundledPACs()==0,"upgrade with stored rules succeeds");
    CHECK(ActiveEngineCurrent()&&MYBPACStamp(readDef(PACDirectory()))==202611280800LL&&[Verdict(Runtime(),probe) containsString:@"PROXY"],"newer downloaded rules are regenerated with the new engine and keep their data");
    CHECK([UpdateState()[@"lastResult"] containsString:@"converted to the optimized engine"],"the conversion is reported"); }
  // (5) a newer UTC release, then unchanged / unrelated / older / equal-date releases, then a changed test domain, rollback and a failed update
  Fixture();configure(@"Default");gMYBTestRestartResult=0;gMYBTestFetch=serveFetch;
  { serve=variant(@"2026/11/29 - 10:00 UTC",probe);serveRev=rev(@"a");
    CHECK(updatePACs(NO)==0&&MYBPACStamp(readDef(PACDirectory()))==202611291000LL&&[Verdict(Runtime(),probe) containsString:@"PROXY"]&&[selectedMode() isEqualToString:@"Default"],"one newer UTC release installs and is live");
    CHECK([UpdateState()[@"lastResult"] containsString:@"2026/11/29 - 10:00 UTC"]&&[UpdateState()[@"lastSuccess"] isKindOfClass:NSDate.class],"the success message shows the rules date in UTC");
    NSString *dirNow=PACDirectory().stringByResolvingSymlinksInPath,*liveNow=Runtime();NSUInteger gens=generations();gMYBTestRestarts=0;
    serveRev=rev(@"b");CHECK(updatePACs(NO)==0&&gMYBTestRestarts==0&&generations()==gens&&[PACDirectory().stringByResolvingSymlinksInPath isEqualToString:dirNow],"an unrelated master commit does not reapply");
    serve=variant(@"2026/11/21 - 00:00 UTC",nil);serveRev=rev(@"c");
    CHECK(updatePACs(NO)==0&&gMYBTestRestarts==0&&[Runtime() isEqualToString:liveNow]&&[UpdateState()[@"lastResult"] containsString:@"older"],"an older release is rejected");
    serve=variant(@"2026/11/29 - 10:00 UTC",@"same-date-other-rules.example");serveRev=rev(@"d");
    CHECK(updatePACs(NO)==0&&gMYBTestRestarts==0&&[Runtime() isEqualToString:liveNow]&&[UpdateState()[@"lastResult"] isEqualToString:@"Rules are up to date"],"the same date from the current engine is not reapplied");
    // changed test domain in a newer release is handled after the update
    serve=variant(@"2026/11/30 - 10:00 UTC",@"changed-test-domain.example");serveRev=rev(@"e");
    CHECK([Verdict(Runtime(),@"changed-test-domain.example") isEqualToString:@"DIRECT"],"fixture: the changed test domain is allowed before the update");
    CHECK(updatePACs(NO)==0&&[[Verdict(Runtime(),@"changed-test-domain.example") description] containsString:@"PROXY"]&&MYBPACStamp(readDef(PACDirectory()))==202611301000LL,"a changed test domain is handled after the update is applied");
    CHECK(rollbackPACs()==0&&[Verdict(Runtime(),@"changed-test-domain.example") isEqualToString:@"DIRECT"]&&MYBPACStamp(readDef(PACDirectory()))==202611291000LL,"rollback returns to the previous release");
    // a failed update (restart error) leaves the working rules, runtime and generations as they were
    serve=variant(@"2026/12/01 - 10:00 UTC",@"failed-update.example");serveRev=rev(@"f");dirNow=PACDirectory().stringByResolvingSymlinksInPath;liveNow=Runtime();gens=generations();
    gMYBTestRestartResult=69;int failed=updatePACs(NO);gMYBTestRestartResult=0;
    CHECK(failed==69&&[PACDirectory().stringByResolvingSymlinksInPath isEqualToString:dirNow]&&[Runtime() isEqualToString:liveNow]&&generations()==gens&&MYBRuntimeEnabled(),"rollback after a failed update: the working rules stay active and no stage is left");
    CHECK(![UpdateState()[@"revision"] isEqualToString:rev(@"f")],"a failed update is not recorded as installed"); }
  // (5b) mode changes, Repair and Restore Defaults keep RAGGR
  Fixture();configure(@"Default");gMYBTestRestartResult=0;
  { NSString *shape=@"qwertyuiop.shop";
    for(NSString *m in @[@"Default",@"allowY",@"blockApple",@"blockSocials+blockXXX",@"allowY+blockAdSense+blockApple+blockSocials+blockXXX",@"blockAdSense",@"blockXXX"]){
     NSString *modeLabel=[NSString stringWithFormat:@"mode %@: RAGGR is live, example.com is allowed",m];
     CHECK(configure(m)==0&&[Verdict(Runtime(),shape) containsString:@"PROXY"]&&![Verdict(Runtime(),@"example.com") containsString:@"PROXY"],modeLabel.UTF8String);}
    CHECK(configure(@"Default")==0,"back to Default");
    CHECK(MYBSetPACEnabled(YES)==0&&[Verdict(Runtime(),shape) containsString:@"PROXY"]&&[readDef(PACDirectory()) isEqualToData:readDef(bundledDir)],"Repair rebuilds the protection and RAGGR is still the active set");
    int restored=restoreDefaults();
    CHECK((restored==0||restored==MYB_DEFAULTS_PARTIAL)&&[Verdict(Runtime(),shape) containsString:@"PROXY"]&&[readDef(PACDirectory()) isEqualToData:readDef(bundledDir)]&&[selectedMode() isEqualToString:@"Default"],"Restore Defaults returns to Default mode on the RAGGR rules"); }
  // (6) invalid releases never change anything
  Fixture();configure(@"Default");gMYBTestRestartResult=0;gMYBTestFetch=serveFetch;
  { NSString *dirNow=PACDirectory().stringByResolvingSymlinksInPath,*liveNow=Runtime();gMYBTestRestarts=0;
    struct{const char *name;int expect;const char *text;}cases[]={{"bad calendar date",65,"invalid date"},{"missing stamp",65,"invalid date"},{"far future",65,"not plausible"},{"previous date format",0,"previous date format"},{"CET zone in the new format",65,"invalid date"},{"non-string stamp",65,"invalid date"},
      {"malformed pattern list",65,"validation failed"},{"bad pattern entry",65,"validation failed"},{"bad alias name",65,"validation failed"},{"bad alias target",65,"validation failed"}};
    for(int i=0;i<(int)(sizeof(cases)/sizeof(cases[0]));i++){
     serve=mutated(^(NSMutableDictionary *c){
      switch(i){case 0:c[@"stamp"]=@"2026/13/40 - 00:10 UTC";break;case 1:[c removeObjectForKey:@"stamp"];break;case 2:c[@"stamp"]=@"2099/01/01 - 00:00 UTC";break;case 3:c[@"stamp"]=@"12/05/26 - 10:00 MST";break;case 4:c[@"stamp"]=@"2026/12/05 - 10:00 CET";break;case 5:c[@"stamp"]=@20261205;break;
       case 6:c[@"base"][@"allow"][@"chains"]=@"not a list";break;case 7:c[@"base"][@"block"][@"chains"]=@[@[@1,@[@"a"]]];break;case 8:c[@"aliases"][@"Evil Name"]=@"Default";break;case 9:c[@"aliases"][@"MYbloXXNew"]=@"nonexistent";break;}});
     serveRev=rev(@"1");serveRev=[serveRev stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[NSString stringWithFormat:@"%x",i+1]];
     int got=updatePACs(NO);NSString *msg=UpdateState()[@"lastResult"]?:@"";
     NSString *label=[NSString stringWithFormat:@"invalid release (%s) is refused with the right result",cases[i].name];
     NSString *label2=[NSString stringWithFormat:@"invalid release (%s) leaves the working rules active",cases[i].name];
     CHECK(got==cases[i].expect&&[msg containsString:@(cases[i].text)],label.UTF8String);
     CHECK([PACDirectory().stringByResolvingSymlinksInPath isEqualToString:dirNow]&&[Runtime() isEqualToString:liveNow]&&gMYBTestRestarts==0&&generations()==0&&![UpdateState()[@"revision"] isEqualToString:serveRev],label2.UTF8String);
    } }
  gMYBTestFetch=nil;
 }
 // ================= older backups, restore failure =================
 Fixture();configure(@"Default");
 CHECK(MYBShieldAddGrant(MYBShieldPermissionsFile(),@"popup",@"standing.example",nil,@"always")!=nil,"fixture: a standing popup permission");
 NSDictionary *snapshot=SetupSnapshot();CHECK(snapshot!=nil&&snapshot[@"shieldPermissions"]!=nil,"a new backup carries standing Shield permissions");
 CHECK([snapshot[@"shieldPermissions"] count]==1,"exactly the standing permission");
 // an OLD backup: no shieldPermissions, Shield prefs without PopupMode / RedirectOtherApps
 NSMutableDictionary *old=[snapshot mutableCopy];[old removeObjectForKey:@"shieldPermissions"];old[@"shield"]=@{@"Enabled":@YES,@"Blocked":@[@"kept.example"],@"Allowed":@[],@"URLs":@[],@"BlockPopups":@YES};
 NSString *oldFile=P(@"old-backup.plist");CHECK([old writeToFile:oldFile atomically:YES],"old backup written");
 // a temporary permission and a temporary website exception exist when the restore happens
 MYBShieldAddGrant(MYBShieldPermissionsFile(),@"popup",@"temp.example",nil,@"temp");
 CHECK(allowWebsite(host,@"Default",@"temp")==0,"fixture: temporary website exception");
 rc=restoreSetup(oldFile);
 CHECK(rc==0,"an older backup (no Shield permissions section) restores");
 CHECK([MYBShieldAllows(MYBShieldPermissionsFile(),@"popup",@"standing.example",nil,NO) isEqual:@"always"],"older backup leaves existing standing permissions as they were");
 CHECK([MYBShieldAllows(MYBShieldPermissionsFile(),@"popup",@"temp.example",nil,NO) isEqual:@"temp"],"a live temporary permission is neither dropped nor made permanent");
 CHECK([Web()[@"temp"] count]==0&&[Web()[@"domains"] count]==0,"temporary website exceptions are not carried through a restore, and not made permanent");
 CHECK(MYBShieldStrict(@{})&&![[NSDictionary dictionaryWithContentsOfFile:PrefFile(@"net.myxxdev.mybloxx.safariguard.plist")] objectForKey:@"PopupMode"],"popup mode stays at its default (Strict) for an old backup");
 // a new backup replaces standing permissions
 MYBShieldRevoke(MYBShieldPermissionsFile(),[[[MYBShieldLiveGrants(MYBShieldPermissionsFile()) filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"source == 'standing.example'"]] firstObject] objectForKey:@"id"]);
 CHECK(MYBShieldAllows(MYBShieldPermissionsFile(),@"popup",@"standing.example",nil,NO)==nil,"fixture: standing permission revoked");
 NSString *newFile=P(@"new-backup.plist");[snapshot writeToFile:newFile atomically:YES];
 CHECK(restoreSetup(newFile)==0&&[MYBShieldAllows(MYBShieldPermissionsFile(),@"popup",@"standing.example",nil,NO) isEqual:@"always"],"a new backup restores standing permissions");
 CHECK([MYBShieldAllows(MYBShieldPermissionsFile(),@"popup",@"temp.example",nil,NO) isEqual:@"temp"],"restore never turns a temporary permission into a standing one");
 // restore whose apply fails: everything, including Shield permissions and intent, is put back
 MYBShieldRevoke(MYBShieldPermissionsFile(),[[[MYBShieldLiveGrants(MYBShieldPermissionsFile()) filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"source == 'standing.example'"]] firstObject] objectForKey:@"id"]);
 files=Snap(WatchPaths());NSString *liveNow=Runtime();NSDictionary *stateNow=[NSDictionary dictionaryWithContentsOfFile:KState];NSString *pointerNow=LinkTarget(@"PACCurrent");
 gMYBTestRestartResult=69;
 CHECK(restoreSetup(newFile)==69,"restore apply failure reported");
 gMYBTestRestartResult=0;
 CHECK(Same(files,Snap(WatchPaths())),"all rule, Shield and settings files are rolled back after a failed restore");
 CHECK([Runtime() isEqualToString:liveNow]&&[[NSDictionary dictionaryWithContentsOfFile:KState] isEqualToDictionary:stateNow],"live PAC and saved intent survive a failed restore");
 CHECK(pointerNow==nil?LinkTarget(@"PACCurrent")==nil:[LinkTarget(@"PACCurrent") isEqualToString:pointerNow],"the PAC generation pointer is put back");
 [fm() removeItemAtPath:gRoot error:NULL];
 if(failures){fprintf(stderr,"%d real-helper check(s) FAILED\n",failures);return 1;}
 printf("Real-helper checks passed: website/update/restore apply failures keep the previous configuration and intent; expired and revoked exceptions leave the live PAC.\n");
}return 0;}
