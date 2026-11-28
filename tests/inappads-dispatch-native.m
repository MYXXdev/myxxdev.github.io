// The shared ad-blocking dylib's dispatcher: exactly one module starts, only in the app that owns it.
#define MYB_INAPPADS_TESTING 1
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
static int ran[18];
void MYBAdsRun_youtube(void){ran[0]++;}void MYBAdsRun_instagram(void){ran[1]++;}void MYBAdsRun_tiktok(void){ran[2]++;}void MYBAdsRun_soundcloud(void){ran[3]++;}
void MYBAdsRun_reddit(void){ran[4]++;}void MYBAdsRun_youtubemusic(void){ran[5]++;}void MYBAdsRun_x(void){ran[6]++;}void MYBAdsRun_messenger(void){ran[7]++;}void MYBAdsRun_facebook(void){ran[8]++;}void MYBAdsRun_amazon(void){ran[9]++;}void MYBAdsRun_threads(void){ran[10]++;}void MYBAdsRun_gmail(void){ran[11]++;}void MYBAdsRun_appstore(void){ran[12]++;}void MYBAdsRun_douban(void){ran[13]++;}void MYBAdsRun_qqmusic(void){ran[14]++;}void MYBAdsRun_sogou(void){ran[15]++;}void MYBAdsRun_wechat(void){ran[16]++;}void MYBAdsRun_bilibili(void){ran[17]++;}
#import "../Companions/InAppAds/Dispatcher.m"
static int failures;
#define CHECK(c,m) do{if(c)printf("PASS %s\n",m);else{printf("FAIL %s\n",m);failures++;}}while(0)
static int total(void){int t=0;for(int i=0;i<18;i++)t+=ran[i];return t;}
int main(void){@autoreleasepool{
 NSArray *modules=@[@"youtube",@"instagram",@"tiktok",@"soundcloud",@"reddit",@"youtubemusic",@"x",@"messenger",@"facebook",@"amazon",@"threads",@"gmail",@"appstore",@"douban",@"qqmusic",@"sogou",@"wechat",@"bilibili"];
 // every catalogue bundle maps to its own module and starts that module alone
 for(NSDictionary *entry in MYBAdsCatalogue())for(NSString *bundle in entry[@"bundles"]){
  memset(ran,0,sizeof ran);
  NSString *module=MYBAdsModuleForBundle(bundle);
  CHECK([module isEqual:entry[@"module"]],([[NSString stringWithFormat:@"%@ maps to %@",bundle,entry[@"module"]] UTF8String]));
  CHECK(MYBAdsRunModule(module),"the owning module starts");
  NSUInteger index=[modules indexOfObject:module];
  CHECK(total()==1&&index!=NSNotFound&&ran[index]==1,([[NSString stringWithFormat:@"%@: exactly that one module ran",bundle] UTF8String]));
 }
 memset(ran,0,sizeof ran);
 CHECK(MYBAdsModuleForBundle(@"com.google.ios.youtube.ShareExtension")==nil,"an app extension never matches");
 CHECK(MYBAdsModuleForBundle(@"com.apple.springboard")==nil&&MYBAdsModuleForBundle(@"com.apple.mobilesafari")==nil,"system processes never match");
 CHECK(MYBAdsModuleForBundle(@"")==nil&&MYBAdsModuleForBundle(nil)==nil,"no identifier, no module");
 CHECK(!MYBAdsRunModule(nil)&&!MYBAdsRunModule(@"unknown"),"an unknown module starts nothing");
 CHECK(total()==0,"nothing ran for any of those");
 CHECK([MYBAdsCatalogue() count]==18,"eighteen modules in the shared dylib");
}
 return failures?1:0;}
