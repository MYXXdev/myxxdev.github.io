#import "../Shared/MYBUninstall.h"
static void need(BOOL value,const char *label){if(!value){fprintf(stderr,"FAIL: %s\n",label);exit(1);}}
static void put(NSString *path,NSString *text){need([text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL],"write fixture");}
int main(void){@autoreleasepool{
 NSFileManager *fm=NSFileManager.defaultManager;NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
 need([fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL],"create fixture");
 NSString *folder=[root stringByAppendingPathComponent:@"Files"],*managed=[root stringByAppendingPathComponent:@"managed.plist"],*backup=[root stringByAppendingPathComponent:@"previous.plist"];
 [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *live=[folder stringByAppendingPathComponent:@"MYbloXX.plist"],*settings=[folder stringByAppendingPathComponent:@"MYbloXX-Settings.plist"],*pac=[folder stringByAppendingPathComponent:@"MYbloXX.pac"],*previous=[folder stringByAppendingPathComponent:@"MYbloXX.plist.previous"],*readme=[folder stringByAppendingPathComponent:@"README.txt"];
 put(live,@"live config");put(settings,@"SAVED SETTINGS");put(pac,@"LAST PAC");put(previous,@"SAVED PREVIOUS CONFIG");put(readme,@"MYbloXX system PAC configuration.");put(backup,@"ORIGINAL MANAGED POLICY");
 need([fm createSymbolicLinkAtPath:managed withDestinationPath:live error:NULL],"active link");BOOL changed=NO;
 need(MYBUninstallDetach(managed,backup,@[live],NO,&changed)==0&&changed,"detach native owned link and restore prior policy");
 need([[NSString stringWithContentsOfFile:managed encoding:NSUTF8StringEncoding error:NULL] isEqual:@"ORIGINAL MANAGED POLICY"],"original managed policy restored");
 need([[NSString stringWithContentsOfFile:backup encoding:NSUTF8StringEncoding error:NULL] isEqual:@"ORIGINAL MANAGED POLICY"],"prior policy backup is retained");
 need(MYBUninstallLiveFiles(@[folder])==0&&! [fm fileExistsAtPath:live]&&![fm fileExistsAtPath:readme],"remove only live plist and installed readme");
 need([[NSString stringWithContentsOfFile:settings encoding:NSUTF8StringEncoding error:NULL] isEqual:@"SAVED SETTINGS"]&&[[NSString stringWithContentsOfFile:pac encoding:NSUTF8StringEncoding error:NULL] isEqual:@"LAST PAC"]&&[[NSString stringWithContentsOfFile:previous encoding:NSUTF8StringEncoding error:NULL] isEqual:@"SAVED PREVIOUS CONFIG"],"settings, last PAC and prior configuration backup unchanged");
 changed=NO;need(MYBUninstallDetach(managed,backup,@[live],NO,&changed)==0&&!changed&&MYBUninstallLiveFiles(@[folder])==0,"repeat cleanup is idempotent");
 [fm removeItemAtPath:managed error:NULL];NSString *foreign=[root stringByAppendingPathComponent:@"foreign.plist"];put(foreign,@"FOREIGN");[fm createSymbolicLinkAtPath:managed withDestinationPath:foreign error:NULL];
 changed=NO;need(MYBUninstallDetach(managed,backup,@[live],NO,&changed)==0&&!changed&&[[fm destinationOfSymbolicLinkAtPath:managed error:NULL] isEqual:foreign],"foreign symlink untouched");
 [fm removeItemAtPath:managed error:NULL];
 NSString *old=@"/private/var/mobile/Containers/Shared/AppGroup/8D4768A8-0731-443F-BB19-40B694EB4F71/File Provider Storage/MYbloXX/MYbloXX.plist";
 [fm createSymbolicLinkAtPath:managed withDestinationPath:old error:NULL];changed=NO;
 need(MYBUninstallDetach(managed,nil,@[],NO,&changed)==0&&changed&&! [fm destinationOfSymbolicLinkAtPath:managed error:NULL],"dangling former AppGroup link removed");
 need(!MYBUninstallOwnedLink([old stringByAppendingString:@".other"],@[])&&!MYBUninstallOwnedLink(@"/var/mobile/Containers/Shared/AppGroup/../MYbloXX.plist",@[])&&!MYBUninstallOwnedLink(@"relative/MYbloXX.plist",@[]),"similar paths, traversal and relative links rejected");
 // Temporarily paused App Control: no link exists, but prior adopted policy
 // still needs restoration. A restore failure must stop before Files deletion.
 changed=NO;need(MYBUninstallDetach(managed,backup,@[live],NO,&changed)==0&&changed,"prior policy restored while App Control had detached link");
 [fm removeItemAtPath:managed error:NULL];put(managed,@"OLD OWNED CONFIG");changed=NO;need(MYBUninstallDetach(managed,nil,@[],YES,&changed)==0&&changed,"legacy owned regular config removed");
 put(managed,@"FOREIGN REGULAR POLICY");changed=NO;need(MYBUninstallDetach(managed,backup,@[],NO,&changed)==0&&!changed,"foreign regular policy untouched");
 put(readme,@"MY PERSONAL README");need(MYBUninstallLiveFiles(@[folder])==0&&[fm fileExistsAtPath:readme],"personal readme preserved");
 NSString *alias=[root stringByAppendingPathComponent:@"alias"];[fm createSymbolicLinkAtPath:alias withDestinationPath:folder error:NULL];put(live,@"KEEP");need(MYBUninstallLiveFiles(@[alias])==73&&[fm fileExistsAtPath:live],"do not follow a substituted Files folder symlink");
 [fm removeItemAtPath:root error:NULL];puts("Uninstall ownership, dangling links, App Control pause, prior-policy restoration, idempotence and backup/PAC preservation passed");return 0;
}}
