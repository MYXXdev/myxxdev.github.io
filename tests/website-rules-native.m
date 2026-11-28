#import "../Shared/MYBWebsiteTransaction.h"
static void require(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(int argc,const char *argv[]){@autoreleasepool{
 require(argc==3,"input/output arguments");NSFileManager *fm=NSFileManager.defaultManager;NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",root.UTF8String,1);
 NSString *data=[root stringByAppendingPathComponent:@"var/mobile/Library/MYbloXX"],*prefs=[root stringByAppendingPathComponent:@"var/mobile/Library/Preferences"];[fm createDirectoryAtPath:data withIntermediateDirectories:YES attributes:nil error:NULL];[fm createDirectoryAtPath:prefs withIntermediateDirectories:YES attributes:nil error:NULL];
 NSMutableDictionary *paths=[@{@"website":MYBWebsiteFile(),@"applied":[data stringByAppendingPathComponent:@"AppliedRules.plist"],@"draft":MYBDraftFile(),@"guard":[prefs stringByAppendingPathComponent:@"guard.plist"],@"state":[data stringByAppendingPathComponent:@"State.plist"]} mutableCopy];paths[@"ownedLogical"]=paths[@"owned"];
 NSString *input=[NSString stringWithUTF8String:argv[1]],*output=[NSString stringWithUTF8String:argv[2]];[fm createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:NULL];
 for(NSString *file in [fm contentsOfDirectoryAtPath:input error:NULL])if([file.pathExtension isEqual:@"pac"]){NSString *base=[NSString stringWithContentsOfFile:[input stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:NULL];NSString *wrapped=MYBWebsitePAC(base,@[@"100widgets.com"]);require(wrapped!=nil,"all 14 PACs wrap");require([wrapped writeToFile:[output stringByAppendingPathComponent:file] atomically:YES encoding:NSUTF8StringEncoding error:NULL],"write wrapped fixture");require([MYBWebsitePAC(base,@[]) isEqual:base],"no exceptions means original PAC");}
 for(NSString *mode in @[@"Default",@"blockXXX",@"blockSocials",@"Custom"]){
  [fm removeItemAtPath:paths[@"website"] error:NULL];
  [@{@"enabled":@YES,@"mode":mode} writeToFile:paths[@"state"] atomically:YES];
  [@{@"blocked":@[@"100widgets.com",@"kept.example"],@"allowed":@[@"existing.example"]} writeToFile:paths[@"applied"] atomically:YES];
  [@{@"blocked":@[@"100widgets.com",@"pending.example"],@"allowed":@[@"draft.example"]} writeToFile:paths[@"draft"] atomically:YES];
  [@{@"Enabled":@YES,@"Blocked":@[@"100widgets.com"],@"Allowed":@[],@"URLs":@[@"https://100widgets.com/"]} writeToFile:paths[@"guard"] atomically:YES];
  paths[@"pacFallback"]=[input stringByAppendingPathComponent:@"Default.pac"];
  // On RootHide, PACCurrent may not contain this mode; the bundled PAC
  // is what the local daemon actually serves.
  paths[@"pac"]=[root stringByAppendingPathComponent:@"missing-persistent.pac"];
  // Saved state may lag behind the actual iOS linked plist.
  [@{@"enabled":@NO,@"mode":@"outdated"} writeToFile:paths[@"state"] atomically:YES];
  __block int applyCount=0,recoverCount=0;int rc=MYBCommitWebsiteAllow(@"100widgets.com",mode,paths,@{},^int{return 0;},^BOOL(NSString *s){return [s containsString:@"MYBWebsiteBaseFindProxyForURL"];},^int{applyCount++;return 0;},^{recoverCount++;},nil);
  require(rc==0&&applyCount==1&&recoverCount==0,"apply once, no recovery on success");require([[NSDictionary dictionaryWithContentsOfFile:paths[@"state"]][@"mode"] isEqual:@"outdated"],"stale mode retained and not used as authority");
  NSDictionary *applied=[NSDictionary dictionaryWithContentsOfFile:paths[@"applied"]],*draft=[NSDictionary dictionaryWithContentsOfFile:paths[@"draft"]],*guard=[NSDictionary dictionaryWithContentsOfFile:paths[@"guard"]];
  require([applied[@"blocked"] isEqual:@[@"kept.example"]],"exact block removed, other applied block retained");require(![applied[@"allowed"] containsObject:@"draft.example"],"draft allow not accidentally applied");require([draft[@"blocked"] containsObject:@"pending.example"]&&[draft[@"allowed"] containsObject:@"draft.example"],"pending draft preserved");require([guard[@"Blocked"] containsObject:@"100widgets.com"] && ![guard[@"Allowed"] containsObject:@"100widgets.com"],"Shield block and allow lists remain completely independent");
  NSMutableDictionary *before=[NSMutableDictionary dictionary];for(NSString *key in @[@"website",@"applied",@"draft",@"guard"])before[key]=[NSData dataWithContentsOfFile:paths[key]];
  for(int fault=0;fault<2;fault++){
   __block int writes=0,recovered=0;rc=MYBCommitWebsiteAllow(@"another.example",mode,paths,@{},^int{return 0;},^BOOL(NSString *s){return s.length>0;},^int{return 69;},^{recovered++;},^BOOL(NSData *bytes,NSString *path){writes++;if(fault==0&&writes==3)return NO;return [bytes writeToFile:path atomically:YES];});
   require(rc==(fault==0?73:69),"fault surfaced");require(recovered==(fault==0?0:1),"runtime re-applied only after a failed apply");for(NSString *key in before)require([[NSData dataWithContentsOfFile:paths[key]] isEqual:before[key]],"all files rolled back byte for byte");
  }
  rc=MYBCommitWebsiteAllow(@"another.example",@"allowY",paths,@{},^int{return 69;},^BOOL(NSString *s){return s.length>0;},^int{return 0;},^{},nil);require(rc==69,"changed live PAC mode rejected");
  rc=MYBCommitWebsiteAllow(@"another.example",mode,paths,@{},^int{return 3;},^BOOL(NSString *s){return s.length>0;},^int{require(NO,"must not apply while protection is not active");return 0;},^{},nil);require(rc==3,"inactive/absent runtime target rejects the exception");
  for(NSString *key in before)require([[NSData dataWithContentsOfFile:paths[key]] isEqual:before[key]],"a rejected exception changes nothing");
 }
 require(MYBTrimWebsiteAllows(@[],paths[@"website"],paths[@"guard"]),"remove exception");
 require(MYBWebsiteDomains().count==0,"removed domain no longer overrides PAC");NSDictionary *restored=[NSDictionary dictionaryWithContentsOfFile:paths[@"guard"]];require(![restored[@"Allowed"] containsObject:@"100widgets.com"]&&[restored[@"Blocked"] containsObject:@"100widgets.com"],"Shield stays independent after MYbloXX exception removal");
 require(!MYBValidWebsiteDomain(@"bad;domain.com")&&!MYBValidWebsiteDomain(@"*.example.com")&&!MYBValidWebsiteDomain(@"Upper.example"),"invalid domains rejected");
 // ---- temporary website exceptions: separate from permanent ones, never persisted into rule files ----
 {
  [fm removeItemAtPath:paths[@"website"] error:NULL];
  [@{@"enabled":@YES,@"mode":@"Default"} writeToFile:paths[@"state"] atomically:YES];
  [@{@"blocked":@[@"kept.example"],@"allowed":@[]} writeToFile:paths[@"applied"] atomically:YES];
  [@{@"blocked":@[@"kept.example"],@"allowed":@[]} writeToFile:paths[@"draft"] atomically:YES];
  [@{@"Enabled":@YES,@"Blocked":@[@"kept.example"],@"Allowed":@[],@"URLs":@[]} writeToFile:paths[@"guard"] atomically:YES];
  paths[@"pacFallback"]=[input stringByAppendingPathComponent:@"Default.pac"];paths[@"pac"]=[root stringByAppendingPathComponent:@"missing-persistent.pac"];
  BOOL(^pacOK)(NSString *)=^BOOL(NSString *t){return t.length>0;};
  NSMutableDictionary *snap=[NSMutableDictionary dictionary];for(NSString *key in @[@"applied",@"draft",@"guard"])snap[key]=[NSData dataWithContentsOfFile:paths[key]];
  __block int applies=0;
  int rc=MYBCommitWebsiteTemp(@"temp.example",@"Default",@"temp",paths,^int{return 0;},pacOK,^int{applies++;return 0;},^{},nil);
  NSDictionary *web=[NSDictionary dictionaryWithContentsOfFile:paths[@"website"]];
  require(rc==0&&applies==1,"temporary exception applied once");
  require(MYBWebsiteTempLive(web).count==1&&[MYBWebsiteLiveDomains(web) containsObject:@"temp.example"],"temporary exception is live");
  require(MYBWebsiteDomains().count==0&&![MYBEffectiveRules(@{@"blocked":@[],@"allowed":@[]},web)[@"allowed"] containsObject:@"temp.example"],"temporary exception never enters the permanent/persisted rules");
  require([MYBEffectiveRulesLive(@{@"blocked":@[],@"allowed":@[]},web)[@"allowed"] containsObject:@"temp.example"],"live rules (PAC generation only) include it");
  for(NSString *key in snap)require([[NSData dataWithContentsOfFile:paths[key]] isEqual:snap[key]],"applied/draft/Shield files untouched by a temporary exception");
  // failed apply rolls the website file back and recovers once
  NSData *websiteBefore=[NSData dataWithContentsOfFile:paths[@"website"]];__block int recovered=0;
  rc=MYBCommitWebsiteTemp(@"other.example",@"Default",@"once",paths,^int{return 0;},pacOK,^int{return 69;},^{recovered++;},nil);
  require(rc==69&&recovered==1&&[[NSData dataWithContentsOfFile:paths[@"website"]] isEqual:websiteBefore],"failed apply keeps the previous configuration");
  // an expired entry is no longer live and is pruned without touching anything else
  NSMutableDictionary *aged=[web mutableCopy];NSMutableArray *list=[NSMutableArray array];for(NSDictionary *e in web[@"temp"]){NSMutableDictionary *m=[e mutableCopy];m[@"wallExpiry"]=@1;[list addObject:m];}aged[@"temp"]=list;[aged writeToFile:paths[@"website"] atomically:YES];
  require(MYBWebsiteTempLive([NSDictionary dictionaryWithContentsOfFile:paths[@"website"]]).count==0,"expired exception is not live");
  BOOL changed=NO;rc=MYBCommitWebsiteRevoke(nil,@"Default",paths,^int{return 0;},pacOK,^int{return 0;},^{},nil,&changed);
  require(rc==0&&changed&&[[NSDictionary dictionaryWithContentsOfFile:paths[@"website"]][@"temp"] count]==0,"pruneexpired removes expired entries");
  changed=YES;rc=MYBCommitWebsiteRevoke(nil,@"Default",paths,^int{require(NO,"nothing to prune must not apply");return 0;},pacOK,^int{return 0;},^{},nil,&changed);
  require(rc==0&&!changed,"pruning with nothing expired is a no-op");
  // explicit revoke, and a permanent exception is unaffected by revoking a temporary one
  MYBCommitWebsiteTemp(@"temp.example",@"Default",@"once",paths,^int{return 0;},pacOK,^int{return 0;},^{},nil);
  require(MYBCommitWebsiteAllow(@"perm.example",@"Default",paths,@{},^int{return 0;},pacOK,^int{return 0;},^{},nil)==0,"permanent exception added");
  changed=NO;rc=MYBCommitWebsiteRevoke(@"temp.example",@"Default",paths,^int{return 0;},pacOK,^int{return 0;},^{},nil,&changed);
  web=[NSDictionary dictionaryWithContentsOfFile:paths[@"website"]];
  require(rc==0&&changed&&MYBWebsiteTempLive(web).count==0&&[MYBRuleArray(web[@"domains"]) containsObject:@"perm.example"],"revoke removes only the temporary exception");
  require(MYBCommitWebsiteTemp(@"perm.example",@"Default",@"temp",paths,^int{return 0;},pacOK,^int{require(NO,"already permanent");return 0;},^{},nil)==0,"temporary request for a permanently allowed domain is a no-op");
  require(MYBCommitWebsiteTemp(@"bad;domain",@"Default",@"temp",paths,^int{return 0;},pacOK,^int{return 0;},^{},nil)==64&&MYBCommitWebsiteTemp(@"x.example",@"Default",@"forever",paths,^int{return 0;},pacOK,^int{return 0;},^{},nil)==64,"invalid domain or duration rejected");
 }
 NSString *globalBase=[NSString stringWithContentsOfFile:[input stringByAppendingPathComponent:@"Default.pac"] encoding:NSUTF8StringEncoding error:NULL];
 NSString *global=MYBUserRulesPAC(globalBase,@[@"shouldblock.example"],@[@"shouldallow.example"]);
 NSString *layeredGlobal=MYBWebsitePAC(global,@[@"100widgets.com"]);
 NSString *outputGlobal=[[output stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"mybloxx-user-overlay.pac"];
 require(layeredGlobal!=nil&&[layeredGlobal writeToFile:outputGlobal atomically:YES encoding:NSUTF8StringEncoding error:NULL],"global custom rules + independent website exceptions layered");
 require([MYBUserRulesPAC(globalBase,@[],@[]) isEqualToString:globalBase],"empty custom list preserves original PAC verbatim");
 [fm removeItemAtPath:root error:NULL];printf("Website transaction checks passed across four modes, pending edits and rollback failures.\\n");
 }return 0;}
