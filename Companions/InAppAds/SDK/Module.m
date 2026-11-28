// MYbloXX Ad SDK load blocking: start-up. All behaviour and its limits are in Shared/MYBAdSDK.h. PROVENANCE: written against the public
// headers of the Google Mobile Ads and Meta Audience Network SDKs (class and delegate method names and their documented failure callbacks);
// no tweak source is used. Runs only in an app the person selected, from the one shared MYBInAppAds library (its filter lists exactly the selected apps, written by the helper; every other process returns before doing anything).
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <roothide.h>
#import "../../../Shared/MYBAdSDK.h"
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBAdsReport.h"
#import "../../../Shared/MYBVersion.h"
static BOOL MYBAdSDKArmed;
static NSTimeInterval MYBAdSDKReadAt;static NSUInteger MYBAdSDKAttempted;static BOOL MYBAdSDKBlockedScheduled;
static void MYBAdSDKSend(void){MYBAdSDKReportLoaded(MYBAdSDKInstalledCount(),MYBAdSDKAttempted,(NSUInteger)MAX(MYBAdSDKBlockedCount(),0),MYBAdSDKReadAt,@MYB_COMPONENT_VERSION);}
static void MYBAdSDKTry(void){
 if(!MYBAdSDKArmed)return;
 NSUInteger attempted=0,ok=MYBAdSDKInstall(&attempted);
 if(ok)NSLog(@"MYBAdSDK installed %lu of %lu entry points in %@",(unsigned long)ok,(unsigned long)attempted,NSBundle.mainBundle.bundleIdentifier);
 // Tell the service this app has the library, and how many entry points were hooked at this moment (0 when no covered SDK is present, which is
 // normal for an app that uses none). Sent on every pass; the service keeps the latest.
 MYBAdSDKAttempted=attempted;MYBAdSDKSend();
}
// SDKs that are frameworks load after launch: look again when a matching image arrives, then a few times shortly after launch.
static void MYBAdSDKImage(const struct mach_header *header,intptr_t slide){
 (void)slide;if(!MYBAdSDKArmed)return;
 Dl_info info;if(dladdr(header,&info)&&info.dli_fname&&(strstr(info.dli_fname,"GoogleMobileAds")||strstr(info.dli_fname,"FBAudienceNetwork")||strstr(info.dli_fname,"VungleAds")||strstr(info.dli_fname,"UnityAds")||strstr(info.dli_fname,"IronSource")||strstr(info.dli_fname,"MTGSDK")))dispatch_async(dispatch_get_main_queue(),^{MYBAdSDKTry();});
}
void MYBAdSDKStart(void){
 @autoreleasepool{
  NSString *bundle=NSBundle.mainBundle.bundleIdentifier;if(!bundle.length||[bundle hasPrefix:@"com.apple."]||[bundle hasPrefix:@"net.myxxdev."])return; // system and MYbloXX processes: no file read, nothing
  NSTimeInterval readAt=NSDate.date.timeIntervalSince1970; // the moment this launch read the choices
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdSDKSelected(prefs,bundle))return; // the one gate: nothing at all happens in any other app
  MYBAdSDKReadAt=readAt;MYBAdSDKArmed=YES;
  // The block count is reported as it grows: one report a few seconds after the first answered load, then again after each further burst.
  MYBAdSDKBlockedHook=^{@synchronized(NSBundle.class){if(MYBAdSDKBlockedScheduled)return;MYBAdSDKBlockedScheduled=YES;}dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3*NSEC_PER_SEC)),dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{@synchronized(NSBundle.class){MYBAdSDKBlockedScheduled=NO;}MYBAdSDKSend();});};
  MYBAdSDKTry();_dyld_register_func_for_add_image(MYBAdSDKImage);
  for(NSNumber *delay in @[@2,@6,@15])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.intValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{MYBAdSDKTry();});
 }
}
