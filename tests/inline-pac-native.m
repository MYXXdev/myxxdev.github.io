// Exercises Shared/MYBInlinePAC.h and MYBRuntimeStatus.h exactly as compiled for the device,
// against a private temporary tree, including fault injection at every transaction step.
#define MYB_INLINE_TESTING 1
#import <Foundation/Foundation.h>
#import "../Shared/MYBInlinePAC.h"
#import "../Shared/MYBStatusModel.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){printf("FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static NSString *root,*journal,*legacy;
static NSString *SK(NSDictionary *rt,BOOL intent,NSNumber *err){return [MYBStatusModel(rt,intent,err)[@"kind"] description];}
static BOOL SA(NSDictionary *rt,BOOL intent,NSNumber *err){return [MYBStatusModel(rt,intent,err)[@"active"] boolValue];}
static NSString *Script(NSString *tag){return [NSString stringWithFormat:@"function FindProxyForURL(url,host){ /*%@*/ return \"DIRECT\"; }",tag];}
static void Reset(void){
 [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
 NSFileManager *fm=NSFileManager.defaultManager;
 [fm createDirectoryAtPath:[root stringByAppendingPathComponent:@"tmp"] withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:NULL];
 [fm createDirectoryAtPath:[root stringByAppendingPathComponent:@"Managed"] withIntermediateDirectories:YES attributes:nil error:NULL];
 [fm createDirectoryAtPath:[root stringByAppendingPathComponent:@"data"] withIntermediateDirectories:YES attributes:nil error:NULL];
 gMYBIPDirOverride=[root stringByAppendingPathComponent:@"tmp/MYbloXX-inlinepac"];
 gMYBIPManagedOverride=[root stringByAppendingPathComponent:@"Managed/com.apple.SystemConfiguration.plist"];
 gMYBIPOwnerOverride=(int)geteuid();gMYBIPFault=NULL;
 journal=[root stringByAppendingPathComponent:@"data/InlineRuntime.plist"];
 legacy=[root stringByAppendingPathComponent:@"Files/MYbloXX.plist"];
}
static NSArray *Files(void){NSMutableArray *a=[NSMutableArray array];for(NSString *n in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:gMYBIPDirOverride error:NULL]?:@[])if([n hasPrefix:MYB_IP_PREFIX])[a addObject:n];return a;}
static NSString *Dest(void){NSString *d=nil;MYBIPClassifyLink(&d);return d;}
static int Apply(NSString *tag,NSString **why){return MYBIPApply(Script(tag),@"Default",journal,legacy,why);}
static int faultStep=0,faultKind=0;
static int Fault(int step){return step==faultStep?faultKind:0;}
int main(void){@autoreleasepool{
 root=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"mybip-%d",getpid()]];
 NSString *why=nil;

 // 1. fresh enable: owned link, intact target, inline PAC, no URL, fallback off, no flags
 Reset();
 CHECK([MYBRuntimeStatus()[@"state"] isEqual:@"disabled"],"starts disabled");
 CHECK(Apply(@"a",&why)==0,"first apply");
 NSDictionary *s=MYBRuntimeStatus();
 CHECK([s[@"state"] isEqual:@"configured"]&&[s[@"enabled"] boolValue],"configured after apply");
 CHECK([s[@"script"] isEqual:Script(@"a")],"full script embedded unchanged");
 // 1b. configured (files) is not the same as applied (verified): identity + effective system settings
 {
  NSString *want=MYBRuntimeSHA256(Script(@"a"));NSDictionary *effOn=@{@"ProxyAutoConfigEnable":@1,@"ProxyAutoConfigJavaScript":Script(@"a")};
  CHECK([MYBRuntimeVerify(s,want,effOn)[@"verification"] isEqual:@"applied"],"matching script in effective settings = applied");
  CHECK([MYBRuntimeVerify(s,MYBRuntimeSHA256(Script(@"other")),effOn)[@"verification"] isEqual:@"stale"],"on-disk script is not the expected effective PAC = stale");
  CHECK([MYBRuntimeVerify(s,want,@{@"ProxyAutoConfigEnable":@0})[@"verification"] isEqual:@"not-applied"],"system PAC disabled = not applied");
  CHECK([MYBRuntimeVerify(s,want,@{@"ProxyAutoConfigEnable":@1,@"ProxyAutoConfigURLString":@"http://127.0.0.1:8787/x.pac"})[@"verification"] isEqual:@"not-applied"],"a PAC URL is not our inline PAC");
  CHECK([MYBRuntimeVerify(s,want,@{@"ProxyAutoConfigEnable":@1,@"ProxyAutoConfigJavaScript":Script(@"zzz")})[@"verification"] isEqual:@"not-applied"],"a different script in effect = not applied");
  CHECK([MYBRuntimeVerify(s,want,@{@"ProxyAutoConfigEnable":@1})[@"verification"] isEqual:@"identity-unavailable"],"PAC on but script not exposed: identity unavailable, not 'applied'");
  CHECK([MYBRuntimeVerify(s,want,nil)[@"verification"] isEqual:@"not-applied"],"no effective settings = not applied");
  CHECK([MYBRuntimeVerify(@{@"state":@"target-missing"},want,effOn)[@"verification"] isEqual:@"unchecked"],"nothing to verify when not configured");
  NSMutableDictionary *with=[s mutableCopy];
  CHECK([MYBRuntimeProtection(s) isEqual:@"configured"],"no verification yet: only configured, never applied");
  with[@"verification"]=@"applied";CHECK([MYBRuntimeProtection(with) isEqual:@"applied"],"applied only with a verified result");
  with[@"verification"]=@"stale";CHECK([MYBRuntimeProtection(with) isEqual:@"stale"]&&![MYBRuntimeProtection(with) isEqual:@"applied"],"stale is not protection");
  // the published mirror is used only while fresh and only for the same configuration
  NSString *mirror=[root stringByAppendingPathComponent:@"mirror.plist"];[NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
  [@{@"state":@"configured",@"destination":s[@"destination"],@"time":NSDate.date,@"verification":@"applied",@"verifiedAt":NSDate.date} writeToFile:mirror atomically:YES];
  CHECK([MYBRuntimeStatusMirrored(mirror)[@"verification"] isEqual:@"applied"],"fresh verification is surfaced");
  [@{@"state":@"configured",@"destination":s[@"destination"],@"time":NSDate.date,@"verification":@"applied",@"verifiedAt":[NSDate dateWithTimeIntervalSinceNow:-600]} writeToFile:mirror atomically:YES];
  CHECK(MYBRuntimeStatusMirrored(mirror)[@"verification"]==nil,"an old verification is not trusted");
  [@{@"state":@"configured",@"destination":@"/some/other/target",@"time":NSDate.date,@"verification":@"applied",@"verifiedAt":NSDate.date} writeToFile:mirror atomically:YES];
  CHECK(MYBRuntimeStatusMirrored(mirror)[@"verification"]==nil,"verification of a different target is not trusted");
 }
 NSDictionary *plist=[NSDictionary dictionaryWithContentsOfFile:Dest()];
 NSDictionary *p=plist[@"Proxies"];
 CHECK(!p[@"ProxyAutoConfigURLString"]&&![p[@"FallBackAllowed"] boolValue]&&[p[@"ProxyAutoConfigEnable"] boolValue]&&[p[@"ProxyAutoConfigJavaScript"] isEqual:Script(@"a")],"keys: no URL, fallback 0, enable 1, JS");
 CHECK([p[@"HTTPProxyType"] intValue]==2&&![p[@"HTTPEnable"] boolValue]&&![p[@"HTTPSEnable"] boolValue]&&[p[@"BypassAllowed"] boolValue],"other proxy keys exact");
 struct stat st;lstat(Dest().fileSystemRepresentation,&st);
 CHECK((st.st_mode&07777)==0644&&MYB_ST_FLAGS(st)==0,"target 0644, no chflags (boot cleanup may remove it)");
 CHECK(Files().count==1&&MYBIPShapeOK(Dest()),"exactly one shape-valid target");
 CHECK([MYBIPReadJournal(journal)[@"phase"] isEqual:@"linked"]&&[MYBIPReadJournal(journal)[@"target"] isEqual:Dest()],"journal records target");

 // 2. regenerate (rule change): new target, old removed, link atomically moved
 NSString *first=Dest();
 CHECK(Apply(@"b",&why)==0,"re-apply");
 CHECK(![Dest() isEqual:first]&&Files().count==1,"old target removed, one target");
 CHECK([MYBRuntimeStatus()[@"script"] isEqual:Script(@"b")],"new script active");
 CHECK(![[NSFileManager defaultManager] fileExistsAtPath:first],"previous file gone");

 // 3. unrelated top-level keys preserved
 NSMutableDictionary *withExtra=[[NSDictionary dictionaryWithContentsOfFile:Dest()] mutableCopy];withExtra[@"Other"]=@{@"keep":@"me"};
 NSString *editedTarget=Dest();[withExtra writeToFile:Dest() atomically:YES];
 CHECK(Apply(@"c",&why)==0&&[[NSDictionary dictionaryWithContentsOfFile:Dest()][@"Other"][@"keep"] isEqual:@"me"],"unrelated SystemConfiguration keys preserved");

 // 1c. structured status model: every state is a result or names its cause; nothing is a bare "checking"
 {
  NSDictionary *cfg=@{@"state":@"configured"};
  CHECK([SK(@{@"state":@"configured",@"verification":@"applied"},YES,nil) isEqual:@"applied-verified"]&&SA(@{@"state":@"configured",@"verification":@"applied"},YES,nil),"verified applied is active");
  CHECK([SK(@{@"state":@"configured",@"verification":@"identity-unavailable"},YES,nil) isEqual:@"applied-unidentified"]&&SA(@{@"state":@"configured",@"verification":@"identity-unavailable"},YES,nil),"applied, identity unavailable, is its own state");
  CHECK(![MYBStatusModel(@{@"state":@"configured",@"verification":@"identity-unavailable"},YES,nil)[@"title"] isEqual:@"Enabled"]&&[MYBStatusModel(@{@"state":@"configured",@"verification":@"identity-unavailable"},YES,nil)[@"tone"] isEqual:@"neutral"],"unverifiable is not worded or toned as verified");
  CHECK([SK(@{@"state":@"configured",@"verification":@"stale"},YES,nil) isEqual:@"stale"]&&!SA(@{@"state":@"configured",@"verification":@"stale"},YES,nil),"stale rules");
  CHECK([SK(@{@"state":@"configured",@"verification":@"not-applied"},YES,nil) isEqual:@"not-applied"],"configured but not applied");
  CHECK([SK(@{@"state":@"configured",@"mirrorAge":@5},YES,nil) isEqual:@"configured-awaiting"]&&[MYBStatusModel(@{@"state":@"configured",@"mirrorAge":@5},YES,nil)[@"refresh"] boolValue],"just published, no verification yet: awaiting, and a refresh is wanted");
  CHECK([SK(@{@"state":@"configured",@"mirrorAge":@600},YES,nil) isEqual:@"verification-unavailable"],"an old/silent helper is not 'awaiting' forever: verification unavailable");
  CHECK([SK(cfg,YES,nil) isEqual:@"verification-unavailable"],"configured with no helper record at all: verification unavailable, never an indefinite wait");
  CHECK([SK(@{@"state":@"configured",@"mirrorAge":@5},YES,@69) isEqual:@"verification-unavailable"]&&[MYBStatusModel(@{@"state":@"configured"},YES,@69)[@"detail"] containsString:@"69"],"a failed verification request is surfaced with its error code");
  CHECK([SK(@{@"state":@"disabled"},NO,nil) isEqual:@"disabled"]&&[SK(@{@"state":@"disabled"},YES,nil) isEqual:@"not-applied"],"disabled by intent vs intended-but-not-installed");
  CHECK([SK(@{@"state":@"target-missing"},YES,nil) isEqual:@"config-missing"]&&[SK(@{@"state":@"target-invalid"},YES,nil) isEqual:@"config-invalid"],"missing and invalid runtime configuration");
  CHECK([SK(@{@"state":@"foreign"},YES,nil) isEqual:@"foreign"]&&[SK(@{@"state":@"experiment"},YES,nil) isEqual:@"experiment"]&&[SK(@{@"state":@"legacy-url"},YES,nil) isEqual:@"legacy"],"foreign configuration, experiment and legacy are distinct");
  CHECK([SK(@{@"state":@"unverified"},YES,nil) isEqual:@"verification-unavailable"]&&[SK(@{@"state":@"unverified"},YES,@77) isEqual:@"verification-unavailable"],"unreadable target without a helper report: verification unavailable");
  CHECK([SK(@{@"state":@"someting-new"},YES,nil) isEqual:@"error"]&&[SK(@{},YES,nil) isEqual:@"error"],"unknown states fall to an explicit error, not a wait");
  for(NSString *st in @[@"disabled",@"configured",@"target-missing",@"target-invalid",@"legacy-url",@"experiment",@"foreign",@"unverified",@"error"])
   for(NSDictionary *extra in @[@{},@{@"verification":@"applied"},@{@"mirrorAge":@1}]){NSMutableDictionary *r=[@{@"state":st} mutableCopy];[r addEntriesFromDictionary:extra];NSDictionary *m=MYBStatusModel(r,YES,nil);
    CHECK([m[@"title"] length]&&[m[@"detail"] length]&&![[m[@"title"] lowercaseString] isEqual:@"checking"]&&![m[@"title"] hasPrefix:@"Checking"],"every state has a title and an explanation; none is a bare 'checking'");}
  { NSString *mirror=[root stringByAppendingPathComponent:@"mirror2.plist"];[NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
    NSDictionary *cur=MYBRuntimeStatus();
    [@{@"state":@"configured",@"destination":cur[@"destination"],@"time":[NSDate dateWithTimeIntervalSinceNow:-10],@"verification":@"applied",@"verifiedAt":[NSDate dateWithTimeIntervalSinceNow:-10]} writeToFile:mirror atomically:YES];
    NSDictionary *m=MYBRuntimeStatusMirrored(mirror);CHECK([m[@"mirrorAge"] doubleValue]>=9&&[m[@"mirrorAge"] doubleValue]<30&&[SK(m,YES,nil) isEqual:@"applied-verified"],"mirror ages are exposed and a fresh verified record maps to verified");
    [@{@"state":@"configured",@"destination":cur[@"destination"],@"time":[NSDate dateWithTimeIntervalSinceNow:-10],@"verification":@"applied",@"verifiedAt":[NSDate dateWithTimeIntervalSinceNow:-500]} writeToFile:mirror atomically:YES];
    m=MYBRuntimeStatusMirrored(mirror);CHECK([SK(m,YES,nil) isEqual:@"configured-awaiting"],"an expired verification is awaiting (refresh requested), not reported as applied");
    [@{@"state":@"configured",@"destination":@"/some/other/target",@"time":NSDate.date,@"verification":@"applied",@"verifiedAt":NSDate.date} writeToFile:mirror atomically:YES];
    m=MYBRuntimeStatusMirrored(mirror);CHECK(![SK(m,YES,nil) isEqual:@"applied-verified"],"a verification for a different configuration is never shown");
  }
 }
 // 4. disable: link and target removed, journal idle; second disable is a no-op
 CHECK(MYBIPDetach(journal,&why)==0,"detach");
 CHECK([MYBRuntimeStatus()[@"state"] isEqual:@"disabled"],"disabled");
 // the only file left is the one an outside edit replaced (identity no longer matches the record): preserved, never guessed at
 CHECK(Files().count==1&&[Files().firstObject isEqual:editedTarget.lastPathComponent],"only the externally rewritten file is preserved; everything MYbloXX owns is gone");
 unlink(editedTarget.fileSystemRepresentation);CHECK(Files().count==0,"no files left once the preserved file is removed by hand");
 CHECK([MYBIPReadJournal(journal)[@"phase"] isEqual:@"idle"],"journal idle");
 CHECK(MYBIPDetach(journal,&why)==0,"detach is idempotent");

 // 5. missing target during uptime is NOT protection; recovery policy says reapply only when intended
 CHECK(Apply(@"d",&why)==0,"apply d");
 unlink(Dest().fileSystemRepresentation);
 s=MYBRuntimeStatus();
 CHECK([s[@"state"] isEqual:@"target-missing"]&&![s[@"enabled"] boolValue],"missing target reported as not enabled");
 CHECK([MYBIPRecoveryAction(YES,nil) isEqual:@"reapply"],"enabled intent + missing target => reapply");
 CHECK([MYBIPRecoveryAction(NO,nil) isEqual:@"orphan-clean"],"disabled intent + dangling owned link => clean up, never reapply");
 CHECK(Apply(@"d2",&why)==0&&MYBRuntimeEnabled(),"reapply recreates target from current intent");
 CHECK([MYBIPRecoveryAction(YES,Script(@"d2")) isEqual:@"ok"]&&[MYBIPRecoveryAction(YES,Script(@"newer")) isEqual:@"reapply"],"stale script => reapply");
 CHECK([MYBIPRecoveryAction(NO,nil) isEqual:@"orphan-clean"],"disabled intent + active link => clean up");
 MYBIPDetach(journal,&why);
 CHECK([MYBIPRecoveryAction(NO,nil) isEqual:@"ok"]&&[MYBIPRecoveryAction(YES,nil) isEqual:@"reapply"],"stock/disabled state after detach");

 // 6. tampered target (content changed) is invalid, not active
 Apply(@"e",&why);
 [@"junk" writeToFile:Dest() atomically:NO encoding:NSUTF8StringEncoding error:NULL];
 CHECK([MYBRuntimeStatus()[@"state"] isEqual:@"target-invalid"],"garbage target invalid");
 CHECK(Apply(@"e2",&why)==0&&MYBRuntimeEnabled(),"apply heals tampered target");
 MYBIPDetach(journal,&why);

 // 7. fault injection at every step: link either unchanged or at a verified target; no secret leftovers
 for(int step=1;step<=6;step++)for(int kind=0;kind<2;kind++){
  Reset();gMYBIPFault=Fault;faultStep=0;
  Apply(@"base",&why);NSString *baseDest=Dest();
  faultStep=step;faultKind=kind==0?3:-999;
  int rc=Apply(@"next",&why);
  faultStep=0;
  NSString *label=[NSString stringWithFormat:@"step %d %s",step,kind==0?"fail":"crash"];
  CHECK(rc!=0,[[label stringByAppendingString:@": reports failure"] UTF8String]);
  NSString *now=Dest();
  BOOL stateOK=[now isEqual:baseDest]||(MYBIPShapeOK(now)&&[[NSFileManager defaultManager] fileExistsAtPath:now]);
  CHECK(stateOK,[[label stringByAppendingString:@": link at old or fully written new target"] UTF8String]);
  CHECK(MYBRuntimeEnabled()||[MYBRuntimeStatus()[@"state"] isEqual:@"target-missing"]==NO,[[label stringByAppendingString:@": never silently half-active"] UTF8String]);
  // recovery: a normal re-apply always converges and leaves exactly one file
  gMYBIPFault=NULL;
  CHECK(Apply(@"final",&why)==0&&MYBRuntimeEnabled()&&Files().count==1,[[label stringByAppendingString:@": re-apply converges to one target"] UTF8String]);
  CHECK([MYBRuntimeStatus()[@"script"] isEqual:Script(@"final")],[[label stringByAppendingString:@": final script active"] UTF8String]);
  // detach also converges after a failed/crashed detach step
  gMYBIPFault=Fault;faultStep=7;faultKind=kind==0?3:-999;
  MYBIPDetach(journal,&why);faultStep=0;gMYBIPFault=NULL;
  CHECK(MYBIPDetach(journal,&why)==0&&[MYBRuntimeStatus()[@"state"] isEqual:@"disabled"]&&Files().count<=1,[[label stringByAppendingString:@": detach converges"] UTF8String]);
 }
 // crash after link moved but before cleanup leaves at most a stale file the next apply sweeps
 Reset();Apply(@"x",&why);gMYBIPFault=Fault;faultStep=6;faultKind=-999;Apply(@"y",&why);faultStep=0;gMYBIPFault=NULL;
 CHECK(Files().count==2,"crash before old-target cleanup leaves the old file");
 Apply(@"z",&why);CHECK(Files().count==1,"next apply sweeps it");

 // 8. refusal of unrelated links/files/dirs
 Reset();
 CHECK(symlink("/etc/hosts",gMYBIPManagedOverride.fileSystemRepresentation)==0,"setup foreign link");
 CHECK(Apply(@"f",&why)==2&&[Dest() isEqual:@"/etc/hosts"],"foreign symlink untouched on apply");
 CHECK(MYBIPDetach(journal,&why)==2&&[Dest() isEqual:@"/etc/hosts"],"foreign symlink untouched on detach");
 CHECK([MYBRuntimeStatus()[@"state"] isEqual:@"foreign"]&&!MYBRuntimeEnabled(),"foreign reported as not ours");
 unlink(gMYBIPManagedOverride.fileSystemRepresentation);
 [@"x" writeToFile:gMYBIPManagedOverride atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 CHECK(Apply(@"f",&why)==2&&MYBIPDetach(journal,&why)==2,"regular file at managed path untouched");
 unlink(gMYBIPManagedOverride.fileSystemRepresentation);
 NSString *exp=[gMYBIPDirOverride stringByAppendingPathComponent:@"MYbloXX.inlinepac-volatile-0a1b2c3d.plist"];
 symlink(exp.fileSystemRepresentation,gMYBIPManagedOverride.fileSystemRepresentation);
 CHECK([MYBRuntimeStatus()[@"state"] isEqual:@"experiment"],"experiment link recognised");
 CHECK(Apply(@"f",&why)==2&&[why containsString:@"experiment"]&&MYBIPDetach(journal,&why)==2&&[Dest() isEqual:exp],"active experiment refused and untouched");
 unlink(gMYBIPManagedOverride.fileSystemRepresentation);

 // 9. legacy B50 link is migrated (replaced) and the Files plist is preserved
 Reset();
 NSString *files=[root stringByAppendingPathComponent:@"AppGroup/X/File Provider Storage/MYbloXX/MYbloXX.plist"];
 CHECK(!MYBIPLegacyFilesDestination(files),"test tree path is not a device path");
 NSString *legacyDest=@"/private/var/mobile/Containers/Shared/AppGroup/ABC/File Provider Storage/MYbloXX/MYbloXX.plist";
 symlink(legacyDest.fileSystemRepresentation,gMYBIPManagedOverride.fileSystemRepresentation);
 CHECK([MYBRuntimeStatus()[@"state"] isEqual:@"legacy-url"]&&!MYBRuntimeEnabled(),"legacy URL link is not 'enabled'");
 CHECK([MYBIPRecoveryAction(YES,nil) isEqual:@"reapply"],"enabled intent + legacy link => migrate");
 CHECK(Apply(@"m",&why)==0&&MYBRuntimeEnabled(),"legacy link replaced by inline target");
 MYBIPDetach(journal,&why);
 symlink(legacyDest.fileSystemRepresentation,gMYBIPManagedOverride.fileSystemRepresentation);
 CHECK(MYBIPDetach(journal,&why)==0&&[MYBRuntimeStatus()[@"state"] isEqual:@"disabled"],"legacy link can be detached when disabling");

 // 10. unsafe directories refused
 Reset();
 NSString *tmp=[root stringByAppendingPathComponent:@"tmp"];
 chmod(tmp.fileSystemRepresentation,0777);
 CHECK(Apply(@"g",&why)==2&&[why containsString:@"sticky"],"world-writable parent without sticky refused");
 chmod(tmp.fileSystemRepresentation,01777);
 CHECK(Apply(@"g",&why)==0,"sticky world-writable parent accepted (like /private/var/tmp)");
 MYBIPDetach(journal,&why);
 chmod(tmp.fileSystemRepresentation,0755);
 chmod(gMYBIPDirOverride.fileSystemRepresentation,0777);
 CHECK(Apply(@"g",&why)==2&&[why containsString:@"writable"],"writable runtime dir refused, never chmod'ed");
 struct stat ds;stat(gMYBIPDirOverride.fileSystemRepresentation,&ds);CHECK((ds.st_mode&0777)==0777,"unsafe dir permissions left alone");
 rmdir(gMYBIPDirOverride.fileSystemRepresentation);
 NSString *elsewhere=[root stringByAppendingPathComponent:@"elsewhere"];mkdir(elsewhere.fileSystemRepresentation,0755);
 symlink(elsewhere.fileSystemRepresentation,gMYBIPDirOverride.fileSystemRepresentation);
 CHECK(Apply(@"g",&why)==2,"symlinked runtime dir refused");
 CHECK(Files().count==0||YES,"-");
 CHECK([[[NSFileManager defaultManager] contentsOfDirectoryAtPath:elsewhere error:NULL] count]==0,"nothing written through the attacker link");
 unlink(gMYBIPDirOverride.fileSystemRepresentation);
 gMYBIPOwnerOverride=(int)geteuid()+1;
 CHECK(Apply(@"g",&why)==2,"parent not owned by root refused");
 gMYBIPOwnerOverride=(int)geteuid();

 // 11. only the exact recorded, identity-matched file is ever removed
 Reset();Apply(@"h",&why);NSString *t=Dest();
 // an unrelated file in the directory is never removed by sweep/detach
 NSString *foreign=[gMYBIPDirOverride stringByAppendingPathComponent:@"notes.txt"];[@"mine" writeToFile:foreign atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 NSString *lookalike=[gMYBIPDirOverride stringByAppendingPathComponent:@"MYbloXX-pac-ZZZZZZZZ.plist"];[@"mine" writeToFile:lookalike atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 Apply(@"h2",&why);MYBIPDetach(journal,&why);
 CHECK([[NSFileManager defaultManager] fileExistsAtPath:foreign]&&[[NSFileManager defaultManager] fileExistsAtPath:lookalike],"unrelated and look-alike files survive apply/detach");
 // ownership ledger: an unrecorded but perfectly shaped, root-owned look-alike is never deleted
 {
  Reset();Apply(@"o1",&why);
  NSString *twin=[gMYBIPDirOverride stringByAppendingPathComponent:@"MYbloXX-pac-deadbeef.plist"];[@"not ours" writeToFile:twin atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  CHECK(MYBIPShapeOK(twin),"fixture: look-alike has the generated shape");
  Apply(@"o2",&why);MYBIPSweep(nil);
  CHECK([[NSFileManager defaultManager] fileExistsAtPath:twin],"shape-valid unrecorded look-alike survives apply and sweep");
  MYBIPDetach(journal,&why);CHECK([[NSFileManager defaultManager] fileExistsAtPath:twin],"look-alike survives detach");
  CHECK(MYBIPCleanupFiles(journal)||YES,"cleanup runs");CHECK([[NSFileManager defaultManager] fileExistsAtPath:twin],"look-alike survives uninstall cleanup");
  NSFileManager *F=NSFileManager.defaultManager;[F removeItemAtPath:twin error:NULL];
  // helper: a file with a COMPLETE recorded identity
  NSString *(^owned)(NSString *,NSString *)=^NSString *(NSString *name,NSString *text){
   NSString *f=[gMYBIPDirOverride stringByAppendingPathComponent:name];NSData *d=[text dataUsingEncoding:NSUTF8StringEncoding];[d writeToFile:f atomically:YES];
   NSDictionary *idt=MYBIPIdentity(f,d);if(!idt||!MYBIPLedgerRecord(f,idt))return nil;return f;};
  // (a) an unchanged, completely recorded, unreferenced orphan IS swept
  Reset();Apply(@"o3",&why);
  NSString *orphan=owned(@"MYbloXX-pac-0badc0de.plist",@"mine");CHECK(orphan!=nil,"fixture: recorded orphan");
  MYBIPSweep(nil);CHECK(![F fileExistsAtPath:orphan],"unchanged owned orphan with full identity is swept");
  // (b) a NAME-ONLY (planned) entry never authorizes deletion, even for a file that exists
  NSString *nameOnly=[gMYBIPDirOverride stringByAppendingPathComponent:@"MYbloXX-pac-11111111.plist"];[@"x" writeToFile:nameOnly atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  CHECK(MYBIPLedgerRecord(nameOnly,nil),"record name only");MYBIPSweep(nil);
  CHECK([F fileExistsAtPath:nameOnly],"name-only ledger entry: file preserved");
  CHECK(MYBIPReadLedger()[nameOnly.lastPathComponent]!=nil,"name-only entry is kept, not silently promoted");
  [F removeItemAtPath:nameOnly error:NULL];MYBIPSweep(nil);
  // (c) in-place rewrite that KEEPS its inode (same name, same inode, different bytes): preserved
  NSString *rew=owned(@"MYbloXX-pac-22222222.plist",@"original bytes");CHECK(rew!=nil,"fixture: rewrite candidate");
  struct stat b4;lstat(rew.fileSystemRepresentation,&b4);
  { NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:rew];[h truncateFileAtOffset:0];[h writeData:[@"someone else's bytes" dataUsingEncoding:NSUTF8StringEncoding]];[h closeFile]; }
  struct stat af;lstat(rew.fileSystemRepresentation,&af);CHECK(b4.st_ino==af.st_ino,"fixture: inode unchanged by the rewrite");
  MYBIPSweep(nil);CHECK([F fileExistsAtPath:rew]&&[[NSString stringWithContentsOfFile:rew encoding:NSUTF8StringEncoding error:NULL] isEqual:@"someone else's bytes"],"in-place rewrite with the same inode is preserved untouched");
  [F removeItemAtPath:rew error:NULL];MYBIPSweep(nil);
  // (d) replaced file (different inode, even identical bytes): preserved
  NSString *rep=owned(@"MYbloXX-pac-33333333.plist",@"same");CHECK(rep!=nil,"fixture: replace candidate");
  unlink(rep.fileSystemRepresentation);[@"same" writeToFile:rep atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  MYBIPSweep(nil);CHECK([F fileExistsAtPath:rep],"a replaced file (new inode/birth) is preserved even with identical bytes");
  [F removeItemAtPath:rep error:NULL];MYBIPSweep(nil);
  // (e) identity persistence failure during apply: nothing changes, nothing is left that authorizes deletion
  Reset();CHECK(Apply(@"p1",&why)==0,"fixture: applied");
  NSString *beforeTarget=Dest(),*beforeScript=MYBRuntimeStatus()[@"script"];NSArray *beforeFiles=Files();
  gMYBIPFailIdentityRecord=YES;int frc=Apply(@"p2",&why);gMYBIPFailIdentityRecord=NO;
  CHECK(frc==3&&why.length,"failure to persist the identity is reported");
  CHECK([Dest() isEqual:beforeTarget]&&[MYBRuntimeStatus()[@"script"] isEqual:beforeScript],"previous configuration untouched after identity persistence failure");
  CHECK([Files() isEqual:beforeFiles],"the new file made for the failed attempt was removed (it was provably ours)");
  for(NSString *n in MYBIPReadLedger())CHECK(MYBIPReadLedger()[n][@"identity"]!=nil||![F fileExistsAtPath:[gMYBIPDirOverride stringByAppendingPathComponent:n]],"no live file is left with only a name-only ledger entry");
  CHECK([MYBIPReadJournal(journal)[@"pending"] length]==0,"journal no longer points at the failed target");
  CHECK(Apply(@"p3",&why)==0&&MYBRuntimeEnabled(),"a later apply succeeds normally");
 }
 // an IDENTICAL-content replacement (different inode, same bytes) is not ours: apply cleanup, detach and uninstall all leave it
 {
  NSFileManager *F=NSFileManager.defaultManager;
  // replaces `path` with a new file holding the same bytes; the new file exists before the old name is taken over, so the inode differs
  void(^swapIdentical)(NSString *)=^(NSString *path){
   NSData *d=[NSData dataWithContentsOfFile:path];NSString *tmp=[path stringByAppendingString:@".copy"];[d writeToFile:tmp atomically:NO];
   struct stat a,b;lstat(path.fileSystemRepresentation,&a);rename(tmp.fileSystemRepresentation,path.fileSystemRepresentation);lstat(path.fileSystemRepresentation,&b);
   CHECK(a.st_ino!=b.st_ino&&[[NSData dataWithContentsOfFile:path] isEqual:d],"fixture: identical bytes, different inode");};
  NSString *n2=nil;
  // direct
  Reset();Apply(@"i0",&why);NSString *tgt=Dest();NSDictionary *jid=MYBIPReadJournal(journal)[@"identity"];
  swapIdentical(tgt);
  CHECK(MYBIPClassifyFile(tgt,jid)==MYBIPFileSameContent,"fixture: classified as same content only");
  CHECK(!MYBIPRemoveTarget(tgt,jid,&n2)&&[F fileExistsAtPath:tgt],"RemoveTarget refuses an identical-content replacement");
  // apply cleanup (previous generation is an identical-content replacement)
  Reset();Apply(@"i1",&why);NSString *prev=Dest();swapIdentical(prev);
  Apply(@"i2",&why);
  CHECK([F fileExistsAtPath:prev]&&![prev isEqual:Dest()],"apply cleanup leaves the identical-content replacement of the previous generation");
  // detach
  Reset();Apply(@"i3",&why);tgt=Dest();NSString *lnk=nil;(void)lnk;swapIdentical(tgt);
  MYBIPDetach(journal,&why);
  CHECK([F fileExistsAtPath:tgt],"detach leaves an identical-content replacement of the target");
  CHECK([MYBRuntimeStatus()[@"state"] isEqual:@"disabled"],"detach still removes the link");
  // uninstall cleanup
  Reset();Apply(@"i4",&why);tgt=Dest();swapIdentical(tgt);
  unlink(gMYBIPManagedOverride.fileSystemRepresentation); // uninstall has already removed the managed entry
  MYBIPCleanupFiles(journal);
  CHECK([F fileExistsAtPath:tgt],"uninstall cleanup leaves an identical-content replacement");
  // control: the genuine, unchanged file is still removed by all of the same paths
  Reset();Apply(@"i5",&why);tgt=Dest();MYBIPDetach(journal,&why);CHECK(![F fileExistsAtPath:tgt],"control: the unchanged owned target is removed by detach");
  Reset();Apply(@"i6",&why);tgt=Dest();unlink(gMYBIPManagedOverride.fileSystemRepresentation);MYBIPCleanupFiles(journal);CHECK(![F fileExistsAtPath:tgt],"control: the unchanged owned target is removed by uninstall cleanup");
  Reset();Apply(@"i7",&why);prev=Dest();Apply(@"i8",&why);CHECK(![F fileExistsAtPath:prev],"control: the unchanged previous generation is removed by apply cleanup");
 }
 // a different file replaced our target at the recorded name: detach leaves it
 Reset();Apply(@"k",&why);t=Dest();
 NSDictionary *idt=MYBIPReadJournal(journal)[@"identity"];
 unlink(t.fileSystemRepresentation);[@"someone else's data" writeToFile:t atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 NSString *note=nil;
 CHECK(!MYBIPRemoveTarget(t,idt,&note)&&[[NSFileManager defaultManager] fileExistsAtPath:t],"different file at recorded name is not deleted");
 // immutable file is left alone
 #ifdef __APPLE__
 Reset();Apply(@"n",&why);t=Dest();chflags(t.fileSystemRepresentation,UF_IMMUTABLE);
 idt=MYBIPReadJournal(journal)[@"identity"];
 CHECK(!MYBIPRemoveTarget(t,idt,&note),"flagged file left alone");
 chflags(t.fileSystemRepresentation,0);
#endif
 // shape validation
 CHECK(!MYBIPShapeOK(@"/etc/passwd")&&!MYBIPShapeOK([gMYBIPDirOverride stringByAppendingString:@"/../x/MYbloXX-pac-00000000.plist"])&&!MYBIPShapeOK([gMYBIPDirOverride stringByAppendingString:@"/sub/MYbloXX-pac-00000000.plist"])&&MYBIPShapeOK([gMYBIPDirOverride stringByAppendingString:@"/MYbloXX-pac-0a1b2c3d.plist"]),"target shape strict");

 // 12. invalid scripts are never applied
 Reset();
 CHECK(MYBIPApply(@"",@"Default",journal,legacy,&why)==2&&MYBIPApply(@"no pac function here, just text.........",@"Default",journal,legacy,&why)==2,"invalid script refused");
 CHECK([MYBRuntimeStatus()[@"state"] isEqual:@"disabled"],"nothing linked after refusal");

 // 13. real device-size script (~64.5 KB) embeds byte-for-byte
 Reset();
 NSMutableString *big=[NSMutableString stringWithString:@"function FindProxyForURL(url,host){\n"];
 while(big.length<64530)[big appendFormat:@"if(dnsDomainIs(host,\"ad%u.example\"))return \"PROXY 127.0.0.1:8788\";\n",arc4random()];
 [big appendString:@"return \"DIRECT\";}\n"];
 CHECK(MYBIPApply(big,@"Default",journal,legacy,&why)==0&&[MYBRuntimeStatus()[@"script"] isEqual:big],"full-size PAC integrity");

 // 14. stale transaction temp link does not block
 Reset();symlink("/nonexistent",MYBIPTempLink().fileSystemRepresentation);
 CHECK(Apply(@"t",&why)==0,"stale tx link cleared");

 [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
 if(failures){printf("%d inline-PAC check(s) FAILED\n",failures);return 1;}
 puts("Inline PAC transaction checks passed");return 0;
}}
