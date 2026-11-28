static NSString *AppControlSessionPath(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/AppControlSession.plist");}
static NSString *AppControlStatusPath(void){return MYBDataPath(@"/var/mobile/Library/MYbloXX/AppControlStatus.plist");}
static NSDictionary *AppControlSession(void){return [NSDictionary dictionaryWithContentsOfFile:AppControlSessionPath()]?:@{};}
static NSDictionary *AppControlPrefs(void){return [NSDictionary dictionaryWithContentsOfFile:MYBDataPath(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist")]?:@{};}
static BOOL AppControlSave(NSDictionary *session){[FM() createDirectoryAtPath:AppControlSessionPath().stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];return [session writeToFile:AppControlSessionPath() atomically:YES];}
static void AppControlStatus(int code,NSString *text){NSDictionary *status=@{@"code":@(code),@"message":text,@"time":[NSDate date]};[status writeToFile:AppControlStatusPath() atomically:YES];chown(AppControlStatusPath().fileSystemRepresentation,501,501);chmod(AppControlStatusPath().fileSystemRepresentation,0644);}
static void AppControlUpdateLiveExport(void){
 NSString *folder=MYBFilesFolder();if(!folder)return;NSString *live=nil;
 NSString *mode=selectedMode();live=MYBEffectiveScript(mode);
 if(live){NSString *path=[folder stringByAppendingPathComponent:@"MYbloXX.pac"];if([live writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL]){chown(path.fileSystemRepresentation,501,501);chmod(path.fileSystemRepresentation,0644);}}
}
static int appControlFocus(NSString *app){
 if(!app.length||app.length>255||[app rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"].invertedSet].location!=NSNotFound)return 64;
 NSDictionary *previous=AppControlSession(),*prefs=AppControlPrefs();BOOL actual=ownedLink();
 BOOL intended=loadSavedState()[@"enabled"]?[loadSavedState()[@"enabled"] boolValue]:actual;
 NSDictionary *plan=MYBAppControlPlan(prefs,previous,intended,selectedMode(),app,[NSDate date]);NSString *action=plan[@"action"];
 if([action isEqual:@"none"])return 0;
 // noXXX with a PIN is never paused for an app: the pause would drop it without the PIN.
 if([action isEqual:@"bypass"]&&MYBPinProtectedNow(PinConfigured(),intended,selectedMode())){AppControlStatus(0,@"MYbloXX® stays on in this app because noXXX PIN protection is active");return 0;}
 if([action isEqual:@"restore"]){
  int rc=[previous[@"previousEnabled"] boolValue]?MYBSetPACEnabled(YES):(ownedLink()?MYBSetPACEnabled(NO):0);
  if(!rc && actual!=[previous[@"previousEnabled"] boolValue])rc=restartConfigd();
  if(rc){AppControlSave(previous);AppControlStatus(rc,@"Unable to restore MYbloXX® after leaving the app. Use Repair MYbloXX.");return rc;}
  // Commit completion only after restoration succeeds. A timeout before this
  // point must leave an active session for the watchdog to recover.
  if(!AppControlSave(@{@"active":@NO}))return 73;
  AppControlStatus(0,@"Previous MYbloXX® on/off state restored");AppControlUpdateLiveExport();return 0;
 }
 if(managedOccupied()&&!ownedLink()){AppControlStatus(3,@"Another proxy/profile is active. App Control needs native MYbloXX®, without a legacy profile.");return 3;}
 BOOL wasBypassed=MYBAppControlBypassed(previous);
 if(!AppControlSave(plan[@"session"]))return 73;
 if([action isEqual:@"hold"])return 0;
 int rc=actual?MYBSetPACEnabled(NO):0;
 if(!rc && actual)rc=restartConfigd();
 if(rc){AppControlSave(previous);if(actual)MYBSetPACEnabled(YES);AppControlStatus(rc,@"Could not pause MYbloXX® for the selected app");return rc;}
 if(!wasBypassed||actual){AppControlStatus(0,@"MYbloXX® temporarily paused for the selected foreground app");AppControlUpdateLiveExport();}
 return 0;
}
static void AppControlNoteManual(NSString *action){
 if(![@[@"enable",@"disable"] containsObject:action])return;NSMutableDictionary *session=[AppControlSession() mutableCopy];if(![session[@"active"] boolValue])return;
 session[@"previousEnabled"]=@([action isEqual:@"enable"]);session[@"manualOverride"]=@YES;AppControlSave(session);
}
// Missing-target recovery (uptime). The watcher only looks; any change is made by the helper itself
// under the operation lock, honouring the saved preference and App Control, with a retry limit so
// a persistent deleter can never cause a configd restart loop. It runs only while the jailbreak
// (and therefore this launchd job) is running, never in stock mode.
static BOOL MYBRuntimeNeedsAttention(void){
 if([AppControlSession()[@"active"] boolValue])return NO;
 if(loadSavedState()[@"enabled"]==nil||MYBExperimentActive())return NO; // the saved intent is the authority (no marker file)
 NSString *action=MYBIPRecoveryAction([loadSavedState()[@"enabled"] boolValue],nil);
 return [action isEqual:@"reapply"]||[action isEqual:@"orphan-clean"];
}
static int runtimeCheck(void){
 if([AppControlSession()[@"active"] boolValue]||loadSavedState()[@"enabled"]==nil||MYBExperimentActive())return 0;
 BOOL intent=[loadSavedState()[@"enabled"] boolValue];
 NSString *action=MYBIPRecoveryAction(intent,nil);
 if(![action isEqual:@"reapply"]&&![action isEqual:@"orphan-clean"])return 0;
 NSString *recoveryPath=MYBDataPath(@"/var/mobile/Library/MYbloXX/InlineRecovery.plist");
 int attempt=0;
 if(!MYBRecoveryTake(recoveryPath,3,600,&attempt)){logLine(@"RUNTIME_CHECK: recovery limit reached (3 per 10 minutes, successful or not); not retrying until the window ends");return 0;}
 logLine([NSString stringWithFormat:@"RUNTIME_CHECK: %@ (intent enabled=%d, state=%@)",action,intent,MYBRuntimeStatus()[@"state"]]);
 if([action isEqual:@"reapply"]&&managedOccupied()&&!ownedLink())return 0;
 int rc=MYBSetPACEnabled([action isEqual:@"reapply"]);
 if(!rc)rc=restartConfigd();
 return rc;
}
// A Legacy switch turned native protection off so the profile can install. This runs every few seconds: once a profile holds the proxy, or
// native protection is back, the note is dropped; if the time is up and neither happened (the install was cancelled or never started),
// native protection is turned back on, so the person is never left unprotected by an abandoned switch.
static void MYBLegacyRevertCheck(void){
 NSString *path=MYBDataPath(@"/var/mobile/Library/MYbloXX/LegacyRevert.plist");
 NSDictionary *note=[NSDictionary dictionaryWithContentsOfFile:path];if(!note)return;
 if(ownedLink()||managedOccupied()){[FM() removeItemAtPath:path error:NULL];return;}
 NSDate *until=note[@"until"];if(![until isKindOfClass:NSDate.class]||until.timeIntervalSinceNow>0)return;
 [FM() removeItemAtPath:path error:NULL];
 logLine(@"LEGACY: the profile was not installed in time; native protection is being turned back on");
 NSString *helper=[MYBRoot() stringByAppendingPathComponent:@"MYXXdev"];pid_t pid=0;const char *args[]={"MYXXdev","enable",NULL};
 if(posix_spawn(&pid,helper.fileSystemRepresentation,NULL,NULL,(char *const *)args,environ)==0){
  BOOL finished=NO;int status=0;for(int tick=0;tick<400;tick++){pid_t result=waitpid(pid,&status,WNOHANG);if(result==pid||(result<0&&errno!=EINTR)){finished=YES;break;}usleep(50000);}
  if(!finished){kill(pid,SIGKILL);while(waitpid(pid,&status,0)<0&&errno==EINTR){}}
 }
}
static int appControlWatch(void){
 MYBPCWatchPrepare();
 for(int round=0;;round++){@autoreleasepool{
  if(round==0||round%60==0||MYBPCRequestPending())MYBPCApplyNow(); // Private Calls: Phone's pending requests
  MYBLegacyRevertCheck();
  MYBPublishRuntimeStatus(); // keeps Settings truthful even when its sandbox cannot read the target
  if(MYBAppControlExpired(AppControlSession(),[NSDate date])||(round%3==0&&MYBRuntimeNeedsAttention())){
   BOOL runtime=!MYBAppControlExpired(AppControlSession(),[NSDate date]);
   NSString *helper=[MYBRoot() stringByAppendingPathComponent:@"MYXXdev"];pid_t pid=0;const char *args[]={"MYXXdev",runtime?"runtimecheck":"appfocus",runtime?NULL:"__none__",NULL};
   if(posix_spawn(&pid,helper.fileSystemRepresentation,NULL,NULL,(char *const *)args,environ)==0){
    BOOL finished=NO;int status=0;
    for(int tick=0;tick<160;tick++){pid_t result=waitpid(pid,&status,WNOHANG);if(result==pid||(result<0&&errno!=EINTR)){finished=YES;break;}usleep(50000);}
    if(!finished){kill(pid,SIGKILL);while(waitpid(pid,&status,0)<0&&errno==EINTR){}}
   }
  }
 {
  // Apps are covered by Ad Network Blocking automatically: when an app is installed or removed, the loader filter is written again.
  static time_t lastApps;struct stat apps;
  if(round%6==0&&stat("/var/containers/Bundle/Application",&apps)==0&&apps.st_mtime!=lastApps){
   lastApps=apps.st_mtime;
   NSString *helper=[MYBRoot() stringByAppendingPathComponent:@"MYXXdev"];pid_t pid=0;const char *args[]={"MYXXdev","adsfilter",NULL};
   if(posix_spawn(&pid,helper.fileSystemRepresentation,NULL,NULL,(char *const *)args,environ)==0){
    int status=0;BOOL finished=NO;for(int tick=0;tick<160;tick++){pid_t result=waitpid(pid,&status,WNOHANG);if(result==pid||(result<0&&errno!=EINTR)){finished=YES;break;}usleep(50000);}
    if(!finished){kill(pid,SIGKILL);while(waitpid(pid,&status,0)<0&&errno==EINTR){}}
   }
  }
 }
 {
  // Temporary website exceptions: remove expired ones from the live PAC (expiry is also enforced
  // whenever the PAC is generated, so this only tidies the live config).
  NSDictionary *web=[NSDictionary dictionaryWithContentsOfFile:MYBWebsiteFile()];NSArray *stored=[web[@"temp"] isKindOfClass:NSArray.class]?web[@"temp"]:@[];
  static NSTimeInterval lastPrune;NSTimeInterval nowTime=NSDate.timeIntervalSinceReferenceDate;
  if(stored.count&&stored.count!=MYBWebsiteTempLive(web).count&&(lastPrune==0||nowTime-lastPrune>=120||nowTime<lastPrune)){lastPrune=nowTime; // 2-minute backoff: a failing apply must not restart configd every round
   NSString *helper=[MYBRoot() stringByAppendingPathComponent:@"MYXXdev"];pid_t pid=0;const char *args[]={"MYXXdev","pruneexpired",NULL};
   if(posix_spawn(&pid,helper.fileSystemRepresentation,NULL,NULL,(char *const *)args,environ)==0){
    int status=0;BOOL finished=NO;for(int tick=0;tick<160;tick++){pid_t result=waitpid(pid,&status,WNOHANG);if(result==pid||(result<0&&errno!=EINTR)){finished=YES;break;}usleep(50000);}
    if(!finished){kill(pid,SIGKILL);while(waitpid(pid,&status,0)<0&&errno==EINTR){}}
   }
  }
 }
 }for(int i=0;i<40&&!MYBPCRequestPending();i++)usleep(250000);}return 0;
}
