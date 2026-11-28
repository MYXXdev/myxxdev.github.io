// Advanced > Connectivity and Extra Privacy Protection: preference defaults and the Personal Hotspot hold rule. Runs on the CI Mac; not a device test.
#import "../Shared/MYBConnectivity.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){printf("FAIL: %s\n",m);failures++;}}while(0)
int main(void){@autoreleasepool{
 NSFileManager *fm=NSFileManager.defaultManager;
 NSString *root=NSProcessInfo.processInfo.environment[@"MYB_FIXTURE_ROOT"];
 [fm createDirectoryAtPath:[root stringByAppendingPathComponent:@"var/mobile/Library/Preferences"] withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *file=MYBConnPrefsFile();
 CHECK([file hasPrefix:root],"prefs resolve under the fixture root");
 CHECK(!MYBConnFlagInFile(file,MYB_CONN_KEY_NETWORK_MENU),"missing file means off");
 CHECK(!MYBConnFlagInFile(file,MYB_CONN_KEY_HOTSPOT),"missing file means hotspot off");
 CHECK(MYBConnWriteFlag(file,MYB_CONN_KEY_HOTSPOT,YES),"write hotspot on");
 CHECK(MYBConnFlagInFile(file,MYB_CONN_KEY_HOTSPOT),"hotspot reads on");
 CHECK(!MYBConnFlagInFile(file,MYB_CONN_KEY_NETWORK_MENU),"switches are independent");
 CHECK(MYBConnWriteFlag(file,MYB_CONN_KEY_NETWORK_MENU,YES),"write network menu on");
 CHECK(MYBConnFlagInFile(file,MYB_CONN_KEY_HOTSPOT),"writing one switch keeps the other");
 CHECK(MYBConnWriteFlag(file,MYB_CONN_KEY_HOTSPOT,NO)&&!MYBConnFlagInFile(file,MYB_CONN_KEY_HOTSPOT),"off is written");
 [@{MYB_CONN_KEY_HOTSPOT:@"yes"} writeToFile:file atomically:YES];
 CHECK(!MYBConnFlagInFile(file,MYB_CONN_KEY_HOTSPOT),"a value that is not a number means off");
 NSString *priv=MYBPrivPrefsFile();
 CHECK(!MYBConnFlagInFile(priv,MYB_PRIV_KEY_DELETED)&&!MYBConnFlagInFile(priv,MYB_PRIV_KEY_ALBUM),"privacy switches default off");
 CHECK(MYBConnWriteFlag(priv,MYB_PRIV_KEY_ALBUM,YES)&&!MYBConnFlagInFile(priv,MYB_PRIV_KEY_DELETED),"privacy switches are independent");
 CHECK(MYBHotspotShouldHold(YES,YES,1),"hold: switch on, hotspot up, one device");
 CHECK(!MYBHotspotShouldHold(NO,YES,3),"no hold when the switch is off");
 CHECK(!MYBHotspotShouldHold(YES,NO,3),"no hold when the hotspot is down");
 CHECK(!MYBHotspotShouldHold(YES,YES,0),"no hold with no device");
 CHECK(!MYBHotspotShouldHold(YES,YES,-1),"no hold when the device count is unknown");
 printf(failures?"%d failure(s)\n":"Connectivity checks passed\n",failures);
}return failures?1:0;}
