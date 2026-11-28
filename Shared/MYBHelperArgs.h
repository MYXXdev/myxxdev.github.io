// Strict argv validation for the privileged helper entry point (MYXXdev <action> [arguments]).
// One table gives every action its exact argument count; the arguments that name a mode, a domain,
// a duration or a switch are validated here too, so a malformed invocation is refused before any
// privilege is used. The count of arguments is argc-2 (argv[0]=program, argv[1]=action).
// Kept separate from the helper so the real argv/argc handling is testable without root.
#import <Foundation/Foundation.h>
#import "MYBWebsiteRules.h"
#define MYB_HELPER_EXIT_USAGE 64
// Exit status carried to callers: 64 = refused as malformed (nothing changed).
static inline NSDictionary<NSString *,NSArray<NSNumber *> *> *MYBHelperActionArity(void){
 static NSDictionary *table;static dispatch_once_t once;dispatch_once(&once,^{
  NSMutableDictionary *t=[NSMutableDictionary dictionary];
  for(NSString *a in @[@"runtimecheck",@"adsfilter",@"migrateprofile",@"legacyprepare",@"legacypreflight",@"appcontrolmigrate",@"uninstall",@"migrateinline",@"status",@"appwatch",@"startuprecover",@"restoredefaults",@"initdefaults",@"settingsrefresh",@"backupfiles",@"syncfiles",@"restorebackup",@"restoreimport",@"recoverrules",@"preparefiles",@"installlink",@"enable",@"disable",@"reconfigure",@"fullreset",@"cellularreset",@"spoof",@"unspoof",@"respring",@"restore",@"repair",@"adopt",@"diagnose",@"localhealth",@"updatecheck",@"updateauto",@"refreshbundled",@"updaterollback",@"pruneexpired",@"statuspublish",@"pacview",@"connectionreset",@"supervisionstatus",@"systemcheck"])t[a]=@[@0,@0];
  for(NSString *a in @[@"appfocus",@"mode",@"selectmode",@"custom",@"proxy",@"testrule",@"ccmodule",@"updatepolicy",@"revokewebsite"])t[a]=@[@1,@1];
  for(NSString *a in @[@"generate",@"localcustom"])t[a]=@[@2,@2];
  for(NSString *a in @[@"pinset",@"pinremove",@"pinstatus"])t[a]=@[@0,@0]; // the PIN arrives on standard input, never as an argument
  t[@"watch"]=@[@1,@2]; // on [SECONDS] | off: the time-limited Watch everything switch; SECONDS is clamped again in the helper
  t[@"pinauth"]=@[@1,@1];
  t[@"profilediag"]=@[@0,@0]; // read-only probe of the profile service; writes a diagnostic file, changes nothing
  t[@"profilestatus"]=@[@2,@2]; // FOLDER NAME of a bundled profile; validated again in the helper
  t[@"profilestage"]=@[@2,@3]; // FOLDER NAME [replace]: "replace" is sent only after the person chose to replace a waiting profile
  t[@"allowwebsite"]=@[@2,@3]; // DOMAIN MODE [DURATION]; the duration is optional for older callers
  table=[t copy];});
 return table;
}
static inline NSString *MYBHelperArg(const char *const *argv,int i){NSString *s=[NSString stringWithUTF8String:argv[i]];return s;}
// Returns YES when the invocation is well formed. On refusal `reason` is a short, secret-free explanation
// (it never echoes argument values, which may be a domain the user typed).
static inline BOOL MYBHelperArgsValid(int argc,const char *const *argv,BOOL(^modeOK)(NSString *),NSString **reason){
 NSString *why=nil;
 do{
  if(argc<2||!argv||!argv[1]){why=@"no action";break;}
  // Every argument is short, except the two rule lists of localcustom: very long lists (the domain
  // validator in the helper enforces the real limits). A bulk import of more than a few dozen domains must not be refused here.
  BOOL ruleLists=argc>=2&&argv[1]&&strcmp(argv[1],"localcustom")==0;
  for(int i=1;i<argc;i++){size_t cap=(ruleLists&&i>=2)?500000:512;if(!argv[i]||strnlen(argv[i],cap+1)>cap){why=@"argument missing or too long";break;}}
  if(why)break;
  NSString *action=MYBHelperArg(argv,1);if(!action){why=@"action is not valid text";break;}
  NSArray<NSNumber *> *range=MYBHelperActionArity()[action];
  if(!range){why=@"unknown action";break;}
  int n=argc-2;
  if(n<range[0].intValue||n>range[1].intValue){why=[NSString stringWithFormat:@"%@ takes %@ argument(s), got %d",action,[range[0] isEqual:range[1]]?range[0].stringValue:[NSString stringWithFormat:@"%@-%@",range[0],range[1]],n];break;}
  if([@[@"mode",@"selectmode"] containsObject:action]){NSString *m=MYBHelperArg(argv,2);if(!m||!modeOK||!modeOK(m)){why=@"unknown protection mode";break;}}
  if([action isEqual:@"watch"]){NSString *v=MYBHelperArg(argv,2);if(![@[@"on",@"off"] containsObject:v?:@""]){why=@"watch must be on or off";break;}if(n==2){NSString *sec=MYBHelperArg(argv,3);NSCharacterSet *bad=[[NSCharacterSet decimalDigitCharacterSet] invertedSet];if(!sec.length||sec.length>5||[sec rangeOfCharacterFromSet:bad].location!=NSNotFound){why=@"seconds must be a number";break;}}}
  if([action isEqual:@"updatepolicy"]){NSString *v=MYBHelperArg(argv,2);if(![@[@"on",@"off"] containsObject:v?:@""]){why=@"update policy must be on or off";break;}}
  if([action isEqual:@"allowwebsite"]){
   NSString *d=MYBHelperArg(argv,2),*m=MYBHelperArg(argv,3);
   if(!MYBValidWebsiteDomain(d)){why=@"not a valid website domain";break;}
   if(!m||!(modeOK&&(modeOK(m)||[m isEqual:@"Custom"]))){why=@"unknown protection mode";break;}
   if(n==3){NSString *u=MYBHelperArg(argv,4);if(![@[@"once",@"temp",@"always"] containsObject:u?:@""]){why=@"duration must be once, temp or always";break;}}
  }
  if([action isEqual:@"pinauth"]){NSString *scope=MYBHelperArg(argv,2);BOOL known=[@[@"mode",@"disable",@"rules",@"restore",@"override"] containsObject:scope]||([scope hasPrefix:@"allow:"]&&MYBValidWebsiteDomain([scope substringFromIndex:6]));if(!known){why=@"unknown PIN scope";break;}}
  if([action isEqual:@"revokewebsite"]){NSString *d=MYBHelperArg(argv,2);if(!MYBValidWebsiteDomain(d)){why=@"not a valid website domain";break;}}
 }while(0);
 if(why&&reason)*reason=why;
 return why==nil;
}
