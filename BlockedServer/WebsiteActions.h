#import "../Shared/MYBOptions.h"
#import <Security/Security.h>
#import <spawn.h>
#import <sys/wait.h>
#import <mach-o/dyld.h>
#import "../Shared/MYBWebsiteRules.h"
#import "../Shared/MYBPin.h"
#import "../Shared/MYBPinClient.h"
extern char **environ;
static NSMutableDictionary *websiteRequests;
static NSString *websiteOrigin(void){return [NSString stringWithFormat:@"http://127.0.0.1:%d",MYB_BLOCK_PORT];}
static NSString *websiteToken(void){unsigned char bytes[32];if(SecRandomCopyBytes(kSecRandomDefault,sizeof(bytes),bytes)!=errSecSuccess)return nil;NSMutableString *s=[NSMutableString string];for(NSUInteger i=0;i<sizeof(bytes);i++)[s appendFormat:@"%02x",bytes[i]];return s;}
static NSString *websiteURL(NSString *raw){
 if(!raw.length||raw.length>4096)return nil;NSURLComponents *u=[NSURLComponents componentsWithString:raw];NSString *host=u.host.lowercaseString;if(![@[@"http",@"https"] containsObject:u.scheme.lowercaseString]||u.user.length||u.password.length||!MYBValidWebsiteDomain(host)||[host isEqual:@"localhost"]||[host hasSuffix:@".localhost"]||[host isEqual:@"127.0.0.1"])return nil;
 // Numeric IP addresses are not domain exceptions.
 NSCharacterSet *digits=[NSCharacterSet characterSetWithCharactersInString:@"0123456789."];if([host rangeOfCharacterFromSet:digits.invertedSet].location==NSNotFound)return nil;return u.URL.absoluteString;
}
static void pruneWebsiteRequests(void){for(NSString *key in websiteRequests.allKeys){NSDictionary *d=websiteRequests[key];if([d[@"expires"] doubleValue]<NSDate.timeIntervalSinceReferenceDate&&![d[@"phase"] isEqual:@"applying"])[websiteRequests removeObjectForKey:key];}}
static NSString *newWebsiteRequest(NSString *raw,NSString *op,NSString *replay){NSString *url=websiteURL(raw);if(!url)return nil;@synchronized(websiteRequests){pruneWebsiteRequests();if(websiteRequests.count>=64)return nil;NSString *token=websiteToken();if(!token)return nil;NSCharacterSet *hex=[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet;BOOL goodOp=op.length>=8&&op.length<=64&&[op rangeOfCharacterFromSet:hex].location==NSNotFound;websiteRequests[token]=[@{@"op":goodOp?op:@"",@"replay":(goodOp&&[replay isEqual:@"get"])?@"get":@"none",@"url":url,@"domain":[NSURL URLWithString:url].host.lowercaseString,@"expires":@(NSDate.timeIntervalSinceReferenceDate+600),@"phase":@"ready"} mutableCopy];return token;}}
// Spawns the helper with EXACTLY the argument vector it will see in production (argv[0] + the given arguments).
static int spawnHelper(NSString *path,NSArray<NSString *> *arguments){
 char *args[8]={(char *)path.fileSystemRepresentation,NULL};int count=1;for(NSString *a in arguments){if(count>=6)return 64;args[count++]=(char *)a.UTF8String;}args[count]=NULL;
 pid_t child;int rc=posix_spawn(&child,path.fileSystemRepresentation,NULL,NULL,args,environ);if(rc)return 69;int status=0;pid_t waited;do{waited=waitpid(child,&status,0);}while(waited<0&&errno==EINTR);return waited<0?71:(WIFEXITED(status)?WEXITSTATUS(status):70);
}
// The helper that production would run (or, in tests, the one MYB_TEST_HELPER names; nil means "run nothing").
static NSString *helperExecutable(void){
#ifdef MYB_BRIDGE_TESTING
 NSString *test=NSProcessInfo.processInfo.environment[@"MYB_TEST_HELPER"];return test.length?test:nil;
#else
 uint32_t n=0;_NSGetExecutablePath(NULL,&n);if(!n||n>32768)return nil;char *buffer=calloc(n+1,1);if(!buffer)return nil;int result=_NSGetExecutablePath(buffer,&n);NSString *exe=result?nil:[NSString stringWithUTF8String:buffer];free(buffer);if(![exe hasSuffix:@"/usr/libexec/mybloxx-blockd"])return nil;
 NSString *root=[exe substringToIndex:exe.length-[@"/usr/libexec/mybloxx-blockd" length]];return [root stringByAppendingString:@"/usr/sbin/MYXXdev/MYbloXX/MYXXdev"];
#endif
}
static int runHelperArgs(NSArray<NSString *> *arguments){
 NSString *path=helperExecutable();
#ifdef MYB_BRIDGE_TESTING
 if(!path)return 0; // tests without a helper: nothing runs
#else
 if(!path)return 69;
#endif
 return spawnHelper(path,arguments);
}
// Authorises ONE website allow with the noXXX PIN. The PIN goes to the helper on standard input only; it is not kept anywhere here.
static int runPinAuthForSite(NSString *domain,NSString *pin,NSString **output){
 NSString *path=helperExecutable();if(!path)return 69;
 return MYBPinHelperRun(path,@[@"pinauth",MYBPinAllowScope(domain)],pin,output);
}
static int runWebsiteHelper(NSString *domain,NSString *mode,NSString *duration){return runHelperArgs(@[@"allowwebsite",domain,mode,duration]);}
// A navigation ticket can only display confirmation. Only the separate private
// capability in the localhost confirmation DOM can submit an actual write.
static NSDictionary *websiteConfirmation(NSString *ticket){if(ticket.length!=64)return nil;@synchronized(websiteRequests){pruneWebsiteRequests();NSMutableDictionary *d=websiteRequests[ticket];if(!d||![d[@"phase"] isEqual:@"ready"])return nil; // Confirm that MYbloXX's inline PAC is really enforced (owned link + intact runtime target),
 // not merely saved state. The chosen mode is the persisted selection the PAC was built from.
 NSDictionary *savedState=[NSDictionary dictionaryWithContentsOfFile:bridgeFile(@"var/mobile/Library/MYbloXX/State.plist")];
 NSString *mode=savedState[@"mode"];
 #ifdef MYB_BRIDGE_TESTING
 if(![savedState[@"enabled"] boolValue] || ![mode isKindOfClass:NSString.class])return nil;
 #else
 if(!MYBRuntimeEnabled() || ![mode isKindOfClass:NSString.class] ||
    !([@"Custom" isEqual:mode]||MYBModeIDValid(mode)))return nil;
 #endif
 NSString *secret=d[@"secret"]?:websiteToken();if(!secret)return nil;d[@"secret"]=secret;d[@"mode"]=mode;return [d copy];}}
static NSDictionary *websiteAction(NSString *route,NSString *method,NSDictionary *headers,BOOL canonical,int *status){
 *status=403;if(!canonical)return nil;NSString *origin=headers[@"origin"];BOOL apply=[route isEqual:@"/mybloxx-allow-apply"],poll=[route isEqual:@"/mybloxx-allow-status"];
 if((apply&&(![method isEqual:@"POST"]||![origin isEqual:websiteOrigin()]))||(poll&&(![method isEqual:@"GET"]||(origin&&![origin isEqual:websiteOrigin()]))))return nil;
 NSString *secret=headers[@"x-mybloxx-allow-token"];if(secret.length!=64)return nil;
 @synchronized(websiteRequests){pruneWebsiteRequests();NSMutableDictionary *d=nil;for(NSMutableDictionary *item in websiteRequests.allValues)if([item[@"secret"] isEqual:secret]){d=item;break;}if(!d)return nil;
  if(apply){
   if(![d[@"phase"] isEqual:@"ready"]&&![d[@"phase"] isEqual:@"pin"]){*status=409;return @{@"phase":d[@"phase"]};}
   NSString *duration=headers[@"x-mybloxx-allow-duration"]?:@"always";if(![@[@"once",@"temp",@"always"] containsObject:duration]){*status=403;return nil;}
   // The PIN, when there is one, arrives in this request header only (never in a URL, never in an argument list); it is held in a local
   // variable for the one helper call and is not stored in the request, the status reply or any log.
   NSString *pin=headers[@"x-mybloxx-allow-pin"];if(pin&&!MYBPinFormatValid(pin)){*status=403;return nil;}
   d[@"phase"]=@"applying";d[@"duration"]=duration;[d removeObjectForKey:@"code"];[d removeObjectForKey:@"message"];NSString *domain=d[@"domain"],*mode=d[@"mode"];
   dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{@autoreleasepool{
    int rc=0;NSString *out=nil;
    if(pin.length){rc=runPinAuthForSite(domain,pin,&out);}
    if(!rc)rc=runWebsiteHelper(domain,mode,duration);
    @synchronized(websiteRequests){
     if(rc==MYB_PIN_EXIT_REQUIRED||rc==MYB_PIN_EXIT_LOCKED||rc==MYB_PIN_EXIT_FORMAT){d[@"phase"]=@"pin";if(pin.length)d[@"message"]=MYBPinOutcomeText(rc,out);}
     else d[@"phase"]=rc?@"error":@"success";
     d[@"code"]=@(rc);if(!rc&&![duration isEqual:@"always"])d[@"until"]=@(NSDate.date.timeIntervalSince1970+([duration isEqual:@"once"]?120:900));d[@"expires"]=@(NSDate.timeIntervalSinceReferenceDate+600);
    }}});
   *status=202;return @{@"phase":@"applying"};}
  if(poll){*status=200;NSMutableDictionary *reply=[@{@"phase":d[@"phase"]} mutableCopy];if(d[@"code"])reply[@"code"]=d[@"code"];if([d[@"phase"] isEqual:@"pin"]&&d[@"message"])reply[@"message"]=d[@"message"];if([d[@"phase"] isEqual:@"success"]){reply[@"url"]=d[@"url"];reply[@"duration"]=d[@"duration"];if(d[@"until"])reply[@"expires"]=d[@"until"];}return reply;}
 }return nil;
}
