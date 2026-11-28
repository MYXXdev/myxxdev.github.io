// The shipping helper entry point as a real PROCESS (real argv/argc, real exit status), built with the same
// test seams as helper-real-native: fixture root, injected configd restart result. Test-only subcommands start
// with "--" and never reach the shipping code; everything else goes to the real main() of Helper/MYXXdev.m.
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
// Test-only clock seams (compiled only with -DMYB_SHIELD_TESTING=1, which the shipping build never sets): a test sets the wall clock,
// the monotonic clock and the boot session for one process, so lockouts and expiries can be checked without sleeping.
double gMYBShieldWall=0,gMYBShieldMono=0;NSString *gMYBShieldBoot=nil;
#define main MYBHelperEntry
#include "../Helper/MYXXdev.m"
#undef main
static NSString *E(const char *k){const char *v=getenv(k);return v?@(v):nil;}
static NSString *P(NSString *rel){return [E("MYB_FIXTURE_ROOT") stringByAppendingPathComponent:rel];}
static NSString *DataFile(NSString *n){return P([@"var/mobile/Library/MYbloXX" stringByAppendingPathComponent:n]);}
static NSString *PrefFile(NSString *n){return P([@"var/mobile/Library/Preferences" stringByAppendingPathComponent:n]);}
static void Seams(void){
 gMYBIPDirOverride=P(@"iptmp/MYbloXX-inlinepac");gMYBIPManagedOverride=P(@"Managed/com.apple.SystemConfiguration.plist");gMYBIPOwnerOverride=(int)geteuid();
 if(E("MYB_TEST_FILES")){gMYBTestFilesFolder=P(@"Files/MYbloXX");[NSFileManager.defaultManager createDirectoryAtPath:gMYBTestFilesFolder withIntermediateDirectories:YES attributes:nil error:NULL];}
 if(getenv("MYB_TEST_WALL"))gMYBShieldWall=atof(getenv("MYB_TEST_WALL"));if(getenv("MYB_TEST_MONO"))gMYBShieldMono=atof(getenv("MYB_TEST_MONO"));if(getenv("MYB_TEST_BOOT"))gMYBShieldBoot=@(getenv("MYB_TEST_BOOT"));
 gMYBTestPretendRoot=YES;gMYBTestRestartResult=E("MYB_TEST_RESTART_RESULT")?E("MYB_TEST_RESTART_RESULT").intValue:0;
}
static NSString *Verdict(NSString *script,NSString *host){
 JSContext *c=[JSContext new];
 [c evaluateScript:@"function dnsDomainIs(h,d){return h.slice(-d.length)===d;} function shExpMatch(s,p){return new RegExp('^'+p.split('*').map(function(x){return x.replace(/[.+?^${}()|[\\]\\\\]/g,'\\\\$&');}).join('.*')+'$').test(s);}"];
 [c evaluateScript:script];JSValue *f=c[@"FindProxyForURL"];if(!f.isObject)return @"NO-FUNCTION";
 return [f callWithArguments:@[[NSString stringWithFormat:@"https://%@/",host],host]].toString;
}
int main(int argc,char **argv){@autoreleasepool{
 if(!E("MYB_FIXTURE_ROOT")){fprintf(stderr,"MYB_FIXTURE_ROOT required\n");return 2;}
 setenv("MYB_TEST_BOOTSTRAP",P(@"jb").UTF8String,1);
 Seams();
 if(argc>=2&&!strncmp(argv[1],"--init",6)){ 
  if(!getenv("MYB_TEST_NO_CC")){ // the Control Centre module as the package ships it (active)
   NSString *cc=P(@"jb/Library/ControlCenter/Bundles/MYbloXXCC2.bundle");[NSFileManager.defaultManager createDirectoryAtPath:cc withIntermediateDirectories:YES attributes:nil error:NULL];
   [@"module" writeToFile:[cc stringByAppendingPathComponent:@"MYbloXXCC2"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  }
 }
 if(argc>=2&&!strcmp(argv[1],"--init")){
  NSFileManager *fm=NSFileManager.defaultManager;NSString *pacs=E("MYB_TEST_PACS");
  for(NSString *d in @[DataFile(@""),PrefFile(@""),P(@"iptmp"),P(@"Managed"),P(@"jb/usr/share/mybloxx"),P(@"var/run"),P(@"jb/var/run"),P(@"jb/Library/MobileSubstrate/DynamicLibraries")])[fm createDirectoryAtPath:d withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:NULL];
  [fm copyItemAtPath:pacs toPath:P(@"jb/usr/share/mybloxx/pacs") error:NULL];[fm copyItemAtPath:pacs toPath:DataFile(@"PAC") error:NULL];
  NSDictionary *rules=@{@"blocked":@[@"kept.example"],@"allowed":@[]};
  [rules writeToFile:DataFile(@"AppliedRules.plist") atomically:YES];[rules writeToFile:DataFile(@"ManualRules.plist") atomically:YES];[rules writeToFile:PrefFile(@"net.myxxdev.mybloxx.ruledraft.plist") atomically:YES];
  [@{@"Enabled":@YES,@"Blocked":@[@"kept.example"],@"Allowed":@[],@"URLs":@[],@"ShowBlocked":@YES} writeToFile:PrefFile(@"net.myxxdev.mybloxx.safariguard.plist") atomically:YES];
  if(!E("MYB_TEST_NO_OPTIN"))touch(KSystemOptIn);
  int rc=configure(@"Default");printf("init rc=%d\n",rc);return rc;
 }
  // A reboot: the inline-PAC target lives in volatile storage and is gone; every saved preference remains.
 if(argc>=2&&!strcmp(argv[1],"--reboot")){NSFileManager *fm=NSFileManager.defaultManager;for(NSString *n in [fm contentsOfDirectoryAtPath:gMYBIPDirOverride error:NULL])[fm removeItemAtPath:[gMYBIPDirOverride stringByAppendingPathComponent:n] error:NULL];printf("rebooted\n");return 0;}
 // Saved intent changed without detaching anything (what a state file that disagrees with the runtime looks like).
 if(argc>=3&&!strcmp(argv[1],"--set-intent")){NSString *m=selectedMode();return saveState(m.length?m:@"Default",!strcmp(argv[2],"on"));}
 if(argc>=2&&!strcmp(argv[1],"--init-empty")){NSFileManager *fm=NSFileManager.defaultManager;for(NSString *d in @[DataFile(@""),PrefFile(@""),P(@"iptmp"),P(@"Managed"),P(@"jb/usr/share/mybloxx"),P(@"jb/var/run"),P(@"jb/Library/MobileSubstrate/DynamicLibraries")])[fm createDirectoryAtPath:d withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:NULL];[fm copyItemAtPath:E("MYB_TEST_PACS") toPath:P(@"jb/usr/share/mybloxx/pacs") error:NULL];[fm copyItemAtPath:E("MYB_TEST_PACS") toPath:DataFile(@"PAC") error:NULL];return 0;}
 if(argc>=3&&!strcmp(argv[1],"--verdict")){printf("%s\n",[Verdict(MYBRuntimeStatus()[@"script"]?:@"",@(argv[2])) UTF8String]);return 0;}
 if(argc>=2&&!strcmp(argv[1],"--snapshot")){ // digest of everything an exception transaction may touch
  NSMutableData *all=[NSMutableData data];
  for(NSString *p in @[KState,DataFile(@"AppliedRules.plist"),DataFile(@"ManualRules.plist"),MYBWebsiteFile(),MYBDraftFile(),PrefFile(@"net.myxxdev.mybloxx.safariguard.plist")]){NSData *d=[NSData dataWithContentsOfFile:p];[all appendData:d?:[NSData data]];}
  NSString *rt=MYBRuntimeStatus()[@"script"];if(rt)[all appendData:[rt dataUsingEncoding:NSUTF8StringEncoding]];
  printf("%s\n",MYBRuntimeSHA256([[NSString alloc] initWithData:all encoding:NSISOLatin1StringEncoding]).UTF8String);return 0;
 }
 if(argc>=2&&!strcmp(argv[1],"--websites")){NSDictionary *w=[NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()]?:@{};printf("domains=%lu temp=%lu\n",(unsigned long)[w[@"domains"] count],(unsigned long)[w[@"temp"] count]);return 0;}
 return MYBHelperEntry(argc,argv);
}}
