#import <Foundation/Foundation.h>
#define MYB_RULE_TESTING 1
#define MYB_SHIELD_TESTING 1
double gMYBShieldWall=0,gMYBShieldMono=0;NSString *gMYBShieldBoot=nil;
#import "../Shared/MYBShield.h"
#import "../Shared/MYBSupervision.h"
#import "../Shared/MYBSupervisionMessage.h"
// RH-15-112526: the retired Browser Rules switch, per-scheme history events, and history dismissal.
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",root.UTF8String,1);
 gMYBShieldWall=2000000;gMYBShieldMono=9000;gMYBShieldBoot=@"boot-X";
 NSString *perm=MYBShieldPermissionsFile(),*act=MYBShieldActivityFile();

 // 1. Browser Rules switch off: the rules turn on, the saved lists are kept, and popup blocking keeps its effective state.
 BOOL off=NO;
 NSDictionary *old=@{@"Enabled":@NO,@"BlockPopups":@YES,@"ShowBlocked":@NO,@"Blocked":@[@"ads.example"],@"Allowed":@[@"ok.example"],@"URLs":@[@"https://x.example/p"],@"PopupMode":@"standard"};
 NSDictionary *fixed=MYBShieldNormalizedRules(old,&off);
 CHECK(off,"a saved Enabled=NO is reported so Settings can tell the person once");
 CHECK([fixed[@"Enabled"] boolValue]&&[fixed[@"ShowBlocked"] boolValue],"rules and notices come back on");
 CHECK([fixed[@"Blocked"] isEqual:old[@"Blocked"]]&&[fixed[@"Allowed"] isEqual:old[@"Allowed"]]&&[fixed[@"URLs"] isEqual:old[@"URLs"]],"saved rules are preserved");
 CHECK(![fixed[@"BlockPopups"] boolValue]&&[fixed[@"PopupMode"] isEqual:@"standard"],"popups stay unblocked as they effectively were, and the mode is kept");
 CHECK(MYBShieldPopupVerdict(fixed,0,YES)==MYBPopupAllow,"normalizing does not start blocking popups");
 NSDictionary *popupsOnly=MYBShieldNormalizedRules(@{@"Enabled":@NO,@"BlockPopups":@NO},&off);
 CHECK(off&&![popupsOnly[@"BlockPopups"] boolValue],"popups that were off stay off");
 NSDictionary *healthy=@{@"Enabled":@YES,@"BlockPopups":@YES};
 CHECK(MYBShieldNormalizedRules(healthy,&off)==healthy&&!off,"a healthy setting is returned untouched and reports nothing");
 CHECK(MYBShieldPopupVerdict(@{@"BlockPopups":@YES},0,NO)==MYBPopupBlockStrict,"popup blocking needs only Block Browser Pop-Ups");
 NSDictionary *quiet=MYBShieldNormalizedRules(@{@"Enabled":@YES,@"BlockPopups":@YES,@"ShowBlocked":@NO},&off);
 CHECK(!off&&[quiet[@"ShowBlocked"] boolValue]&&[quiet[@"BlockPopups"] boolValue],"retired notices switch is turned on without touching popup blocking");

 // 2. History events keep the scheme only when the original event knew it.
 MYBShieldRecordActivityScheme(act,@"appredirect",@"com.apple.mobilesafari",@"org.mozilla.ios.firefox",@"ask-block",@"firefox",YES);
 MYBShieldRecordActivityScheme(act,@"appredirect",@"com.apple.mobilesafari",@"org.mozilla.ios.firefox",@"ask-block",nil,NO);
 MYBShieldRecordActivityScheme(act,@"appredirect",@"com.apple.mobilesafari",@"org.mozilla.ios.firefox",@"ask-block",@"firefox",YES);
 NSArray *items=MYBShieldActivity(act);
 CHECK(items.count==2,"events with and without a known scheme are separate rows");
 NSDictionary *known=nil,*unknown=nil;for(NSDictionary *i in items){if(i[@"scheme"])known=i;else unknown=i;}
 CHECK(known&&[known[@"count"] integerValue]==2&&[known[@"scheme"] isEqual:@"firefox"],"the same known scheme collapses into one counted row");
 CHECK(unknown&&unknown[@"scheme"]==nil,"an event that did not know its scheme carries none (it can never become a widened Allow Once)");

 // 3. An allow saved from history covers exactly that route.
 CHECK(MYBShieldAddGrantFor(perm,@"appredirect",@"com.apple.mobilesafari",@"org.mozilla.ios.firefox",@"always",nil,nil)!=nil,"history allow saved");
 CHECK([MYBShieldAllows(perm,@"appredirect",@"com.apple.mobilesafari",@"org.mozilla.ios.firefox",NO) isEqual:@"always"],"that route is allowed");
 CHECK(MYBShieldAllows(perm,@"appredirect",@"com.apple.mobilesafari",@"com.google.ios.youtube",NO)==nil,"another destination from the same app is not");
 CHECK(MYBShieldAllows(perm,@"appredirect",@"com.example.other",@"org.mozilla.ios.firefox",NO)==nil,"another source to the same destination is not");
 CHECK(MYBShieldAllows(perm,@"appstore",@"com.apple.mobilesafari",nil,NO)==nil,"App Store requests are not allowed by an app-to-app route");

 // 4. Dismissing one entry removes only that entry; permissions and the other rows stay.
 CHECK(MYBShieldDismissActivity(act,known),"the chosen event is dismissed");
 items=MYBShieldActivity(act);
 CHECK(items.count==1&&items[0][@"scheme"]==nil,"the other event is untouched");
 CHECK([MYBShieldAllows(perm,@"appredirect",@"com.apple.mobilesafari",@"org.mozilla.ios.firefox",NO) isEqual:@"always"],"dismissing history never removes a permission");
 CHECK(!MYBShieldDismissActivity(act,known),"dismissing it again finds nothing and changes nothing");
 // 5. Supervision default on a fresh install: only an unmanaged, unsupervised device qualifies; nothing that belongs to someone else is touched.
 NSString *dir=[root stringByAppendingPathComponent:@"cfg"],*file=[dir stringByAppendingPathComponent:@"CloudConfigurationDetails.plist"],*rec=[root stringByAppendingPathComponent:@"Supervision.plist"];
 [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *why=nil;
 CHECK(MYBSupervisionEligibleForDefault(file,rec,&why)&&why==nil,"no configuration file and a safe folder: eligible");
 [@{@"IsSupervised":@NO} writeToFile:file atomically:YES];
 CHECK(MYBSupervisionEligibleForDefault(file,rec,NULL),"a file that only says not supervised: eligible");
 [@{@"IsSupervised":@YES} writeToFile:file atomically:YES];
 CHECK(!MYBSupervisionEligibleForDefault(file,rec,&why)&&[why containsString:@"already supervised"],"already supervised: not eligible, and it says why");
 [@{@"OrganizationName":@"Acme School"} writeToFile:file atomically:YES];
 CHECK(!MYBSupervisionEligibleForDefault(file,rec,&why)&&[why containsString:@"management"],"a managed device is left alone");
 CHECK([MYBSupervisionStatus(file,rec)[@"managed"] boolValue],"the status the Settings banner falls back on says managed when an organisation key exists");
 [@{@"CloudConfigurationUIComplete":@YES,@"ConfigurationWasApplied":@YES,@"IsSupervised":@NO} writeToFile:file atomically:YES];
 CHECK(![MYBSupervisionStatus(file,rec)[@"managed"] boolValue],"bookkeeping keys alone are not management");
 CHECK(MYBSupervisionEligibleForDefault(file,rec,&why),"ordinary iOS bookkeeping keys on an unmanaged iPhone do not block the default (this was why supervision came up off)");
 [@{@"IsSupervised":@NO,@"ConfigurationURL":@"https://mdm.example"} writeToFile:file atomically:YES];
 CHECK(!MYBSupervisionEligibleForDefault(file,rec,NULL),"an enrolment key means managed even when the flag is off");
 [NSFileManager.defaultManager removeItemAtPath:file error:NULL];
 [@{@"owner":@"net.myxxdev.mybloxx"} writeToFile:rec atomically:YES];
 CHECK(!MYBSupervisionEligibleForDefault(file,rec,&why)&&[why containsString:@"record"],"an upgrade that already has our record is never re-defaulted");
 [NSFileManager.defaultManager removeItemAtPath:rec error:NULL];
 CHECK(!MYBSupervisionEligibleForDefault([root stringByAppendingPathComponent:@"nowhere/CloudConfigurationDetails.plist"],rec,&why),"an unavailable configuration folder: not eligible");
 // Uninstall ownership: turning it on then off with a record only undoes our own change; a device supervised before us is never touched.
 [@{@"IsSupervised":@YES,@"OrganizationName":@"Acme"} writeToFile:file atomically:YES];
 CHECK(MYBChangeSupervision(YES,file,rec)==3&&![NSFileManager.defaultManager fileExistsAtPath:rec],"enabling on an already supervised device changes nothing and creates no record");
 CHECK(MYBChangeSupervision(NO,file,rec)==3,"disabling without our record changes nothing (uninstall cannot undo what is not ours)");
 CHECK([[NSDictionary dictionaryWithContentsOfFile:file][@"OrganizationName"] isEqual:@"Acme"],"the organisation identity is intact");
 [NSFileManager.defaultManager removeItemAtPath:file error:NULL];
 CHECK(MYBChangeSupervision(YES,file,rec)==0&&[[NSDictionary dictionaryWithContentsOfFile:file][@"IsSupervised"] boolValue],"a fresh eligible device: turned on through the supported flow");
 CHECK(MYBChangeSupervision(NO,file,rec)==0&&![NSFileManager.defaultManager fileExistsAtPath:file]&&![NSFileManager.defaultManager fileExistsAtPath:rec],"uninstall restores exactly what existed before: the file it created is removed");
 [NSFileManager.defaultManager removeItemAtPath:root error:NULL];
 if(failures){fprintf(stderr,"%d RH-15-112526 check(s) FAILED\n",failures);return 1;}
 printf("RH-15-112526 policy checks passed: Browser Rules migration, scheme-aware history, scoped allow, single-entry dismiss.\n");
}return 0;}
