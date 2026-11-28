#import "../Shared/MYBRuleStore.h"
static void require(BOOL ok,const char *s){if(!ok){fprintf(stderr,"FAIL: %s\n",s);exit(1);}}
static NSDictionary *readRules(NSString *p){return [NSDictionary dictionaryWithContentsOfFile:p];}
int main(int argc,char **argv){@autoreleasepool{
 require(argc==2,"bundled PAC path required");NSFileManager *fm=NSFileManager.defaultManager;
 NSString *fixture=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
 NSString *root=[fixture stringByAppendingPathComponent:@"data"],*bundle=[NSString stringWithUTF8String:argv[1]];
 [fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
 NSDictionary *active=@{@"blocked":@[@"blocked.example",@"hidden.example"],@"allowed":@[@"visible.example"]},*web=@{@"domains":@[@"hidden.example"]},*empty=@{@"blocked":@[],@"allowed":@[]};
 NSDictionary *effective=MYBEffectiveRules(active,web);
 require([effective[@"allowed"] isEqual:@[@"visible.example",@"hidden.example"]],"hidden active website exception appears in visible allowed list");
 require([effective[@"blocked"] isEqual:@[@"blocked.example"]],"UI matches runtime precedence");
 require([MYBRecoveredRules(nil,effective,@{},@{}) isEqual:effective],"reinstall restores durable archive");
 require([MYBRecoveredRules(empty,effective,@{@"MYB2-allow":@"stale.example"},@{}) isEqual:empty],"intentional empty rules never resurrect old backups or legacy defaults");
 require([MYBRecoveredRules(active,nil,@{@"MYB2-allow":@""},web) isEqual:effective],"empty legacy Settings defaults cannot mask active rules");
 NSArray *names=@[@"Default",@"allowY",@"blockAdSense",@"blockApple",@"blockSocials",@"blockXXX",@"MYbloXX",@"MYbloXXTest",@"MYbloXXallowFB",@"MYbloXXallowY",@"MYbloXXnoApple",@"MYbloXXnoFB",@"MYbloXXnoSocials",@"MYbloXXnoXXX"];
 NSString *old=[root stringByAppendingPathComponent:@"PAC-old"],*pointer=[root stringByAppendingPathComponent:@"PACCurrent"];
 [fm createDirectoryAtPath:old withIntermediateDirectories:YES attributes:nil error:NULL];
 [@"modified PAC containing old allow" writeToFile:[old stringByAppendingPathComponent:@"Default.pac"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 [fm createSymbolicLinkAtPath:pointer withDestinationPath:old error:NULL];
 NSString *applied=[root stringByAppendingPathComponent:@"AppliedRules.plist"],*draft=[fixture stringByAppendingPathComponent:@"draft.plist"],*archive=[fixture stringByAppendingPathComponent:@"Files/ManualRules.plist"],*website=[root stringByAppendingPathComponent:@"WebsiteAllows.plist"],*updates=[root stringByAppendingPathComponent:@"Updates.plist"];
 [fm createDirectoryAtPath:archive.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 NSDictionary *initial=@{applied:effective,draft:@{@"blocked":@[],@"allowed":@[@"stale-draft.example"]},archive:effective,website:web,updates:@{@"previousDirectory":old}};
 require(MYBWriteRuleFiles(initial,nil,nil)==0,"fixture writes");
 NSMutableDictionary *before=[NSMutableDictionary dictionary];for(NSString *p in initial)before[p]=[NSData dataWithContentsOfFile:p];
 NSDictionary *reset=@{applied:empty,draft:empty,archive:empty,website:@{@"domains":@[]},updates:@{@"revision":@"factory"}};
 __block int written=0;
 int rc=MYBWriteRuleFiles(reset,nil,^BOOL(NSData *data,NSString *p){if(++written==3)return NO;return [data writeToFile:p atomically:YES];});
 require(rc==73,"partial write failure surfaced");for(NSString *p in before)require([[NSData dataWithContentsOfFile:p] isEqual:before[p]],"partial writes roll back every rule file");
 BOOL(^validate)(NSData *)=^BOOL(NSData *d){return [[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] containsString:@"function FindProxyForURL"];};
 rc=MYBFactoryPACReset(bundle,root,names,reset,validate,^int{return 75;});
 require(rc==75 && [[fm destinationOfSymbolicLinkAtPath:pointer error:NULL] isEqual:old],"failed factory activation restores original PAC pointer");
 for(NSString *p in before)require([[NSData dataWithContentsOfFile:p] isEqual:before[p]],"failed factory activation restores all rule files");
 rc=MYBFactoryPACReset(bundle,root,names,reset,validate,^int{
  for(NSString *n in [names arrayByAddingObject:@"Custom"]){
   NSString *filename=[n stringByAppendingString:@".pac"],*original=[([n isEqual:@"Custom"]?@"Default":n) stringByAppendingString:@".pac"];
   require([[NSData dataWithContentsOfFile:[pointer stringByAppendingPathComponent:filename]] isEqual:[NSData dataWithContentsOfFile:[bundle stringByAppendingPathComponent:original]]],"all 14 modes and Custom restored byte for byte before activation");
  }return 0;
 });
 require(rc==0,"factory reset succeeds");require(![fm fileExistsAtPath:old],"old downloadable rollback generations discarded");
 require([readRules(applied) isEqual:empty] && [readRules(archive) isEqual:empty] && [readRules(draft) isEqual:empty],"active lists, UI and durable archive all cleared");
 require(!readRules(updates)[@"previousDirectory"],"rollback cannot resurrect custom rules");
 [fm removeItemAtPath:applied error:NULL];
 require([MYBRecoveredRules(readRules(applied),readRules(archive),@{@"MYB2-allow":@"stale.example"},readRules(website)) isEqual:empty],"reset remains empty after reinstall even with stale legacy preferences");
 // A subsequent explicit deletion clears the old separate exception store too.
 require(MYBWriteRuleFiles(@{applied:empty,website:@{@"domains":@[]},archive:empty},nil,nil)==0,"delete rules");
 require([MYBEffectiveRules(readRules(applied),readRules(website)) isEqual:empty],"deleted website no longer allowed by hidden overlay");
 [fm removeItemAtPath:fixture error:NULL];puts("Rule recovery, reinstall, deletion, factory reset and failure rollback checks passed");return 0;
}}
