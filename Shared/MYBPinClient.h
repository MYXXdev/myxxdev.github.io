#pragma once
// Client side of the noXXX PIN: run the helper with the PIN on STANDARD INPUT (never in an argument list, which other processes
// can read) and map a refused helper action to the scope its authorisation needs. Used by Settings and the blocked page.
#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>
#import <signal.h>
#import <errno.h>
#import "MYBPin.h"
extern char **environ;
// Runs `helper args...` with `input` on standard input. Returns the exit status (or 125/71 on failure); `output` receives standard output.
static inline int MYBPinHelperRun(NSString *helper,NSArray<NSString *> *args,NSString *input,NSString **output){
 if(!helper.length||args.count>6)return 64;
 int in[2]={-1,-1},out[2]={-1,-1};if(pipe(in)!=0)return 71;if(pipe(out)!=0){close(in[0]);close(in[1]);return 71;}
 posix_spawn_file_actions_t actions;posix_spawn_file_actions_init(&actions);
 posix_spawn_file_actions_adddup2(&actions,in[0],0);posix_spawn_file_actions_adddup2(&actions,out[1],1);
 posix_spawn_file_actions_addclose(&actions,in[0]);posix_spawn_file_actions_addclose(&actions,in[1]);posix_spawn_file_actions_addclose(&actions,out[0]);posix_spawn_file_actions_addclose(&actions,out[1]);
 NSMutableArray<NSData *> *storage=[NSMutableArray array];const char *argv[9]={"MYXXdev",NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL};int n=1;
 for(NSString *a in args){NSMutableData *d=[[a dataUsingEncoding:NSUTF8StringEncoding] mutableCopy]?:[NSMutableData data];[d appendBytes:"\0" length:1];[storage addObject:d];argv[n++]=(const char *)d.bytes;}
 pid_t pid=0;int rc=posix_spawn(&pid,helper.fileSystemRepresentation,&actions,NULL,(char *const *)argv,environ);
 posix_spawn_file_actions_destroy(&actions);close(in[0]);close(out[1]);
 if(rc){close(in[1]);close(out[0]);return 69;}
 NSData *bytes=[[input?:@"" stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
 signal(SIGPIPE,SIG_IGN);if(input.length)(void)write(in[1],bytes.bytes,bytes.length);close(in[1]);
 NSMutableData *collected=[NSMutableData data];char buffer[256];ssize_t got;
 while((got=read(out[0],buffer,sizeof(buffer)))>0&&collected.length<4096)[collected appendBytes:buffer length:(NSUInteger)got];
 close(out[0]);int status=0;pid_t w;do{w=waitpid(pid,&status,0);}while(w<0&&errno==EINTR);
 if(output)*output=[[NSString alloc] initWithData:collected encoding:NSUTF8StringEncoding]?:@"";
 return w<0?125:(WIFEXITED(status)?WEXITSTATUS(status):125);
}
// The authorisation scope a refused helper action needs, or nil when the action is not PIN-guarded.
static inline NSString *MYBPinScopeForArgs(NSArray<NSString *> *args){
 NSString *action=args.firstObject;if(!action)return nil;
 if([@[@"mode",@"selectmode"] containsObject:action])return @"mode";
 if([@[@"disable",@"legacyprepare",@"legacypreflight"] containsObject:action])return @"disable";
 if([@[@"custom",@"proxy"] containsObject:action])return @"override";
 if([@[@"restorebackup",@"restoreimport",@"restoredefaults"] containsObject:action])return @"restore";
 if([action isEqual:@"localcustom"])return @"rules";
 if([action isEqual:@"allowwebsite"]&&args.count>=2)return MYBPinAllowScope(args[1]);
 return nil;
}
// "Wrong PIN", "Try again in 2 minutes", ... for an exit status from a PIN action.
static inline NSString *MYBPinOutcomeText(int rc,NSString *output){
 if(rc==MYB_PIN_EXIT_LOCKED){
  NSRange r=[output?:@"" rangeOfString:@"locked="];long s=r.location==NSNotFound?0:[[output substringFromIndex:NSMaxRange(r)] longLongValue];
  if(s<=0)return @"Too many wrong PINs. Try again later.";
  if(s<90)return [NSString stringWithFormat:@"Too many wrong PINs. Try again in %ld seconds.",s];
  if(s<5400)return [NSString stringWithFormat:@"Too many wrong PINs. Try again in %ld minutes.",(s+59)/60];
  return [NSString stringWithFormat:@"Too many wrong PINs. Try again in %ld hours.",(s+3599)/3600];
 }
 if(rc==MYB_PIN_EXIT_REQUIRED)return @"That PIN is not correct.";
 if(rc==MYB_PIN_EXIT_FORMAT)return @"A PIN is exactly four digits.";
 if(rc==MYB_PIN_EXIT_NOTSET)return @"No PIN is set.";
 return @"The PIN could not be checked. Nothing was changed.";
}
