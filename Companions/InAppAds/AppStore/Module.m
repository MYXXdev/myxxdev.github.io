// MYbloXX In-App Ad Blocking: App Store. DISCOVERY ONLY, nothing is blocked.
// PROVENANCE: no source text and no published hook is used. No published tweak or class dump covering the sponsored placements in the
// App Store on iOS 16 was found, so there is nothing established to hook. This module therefore does the one honest thing available: when
// the person switches on "Collect discovery details" in Settings > In-App Ad Blocking > Status, it writes bounded class, selector and
// view-type names to the system log (see Shared/MYBAdsDiscovery.h for exactly what is and is not collected) so the sponsored search
// result and Today placements can be identified from one device log and a real hook written. With that switch off it does nothing.
// It never reads account data, search text, app names, prices, images or any other content.
#import <Foundation/Foundation.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#ifndef MYB_ADS_COUNTER
#define MYB_ADS_COUNTER MYBAppStoreDiscoveryCounter // one class per module: they share one dylib (a test that includes several modules in one file keeps the first name)
#endif
#import "../../../Shared/MYBAdsDiscovery.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif

// One collection. imageFragments limits class names to the App Store's own images; tests pass none.
NSDictionary *MYBAppStoreDiscoveryInfo(NSUInteger phase,NSArray<NSString *> *imageFragments,NSArray *windows,NSString *appVersion,NSString *osVersion){
 NSArray *classes=MYBAdsDiscoveryAdLikeClasses(imageFragments,MYB_ADS_DISCOVERY_MAX_ITEMS);
 NSMutableDictionary *selectors=[NSMutableDictionary dictionary];
 NSArray *keys=@[@"sponsor",@"advert",@"placement",@"impression",@"lockup",@"shelf",@"searchresult",@"model"];
 for(NSString *name in classes){
  if(selectors.count>=10)break;
  Class cls=NSClassFromString(name);NSArray *list=MYBAdsDiscoverySelectors(cls,keys,20);
  if(list.count)selectors[name]=@{@"chain":MYBAdsDiscoveryChain(cls),@"selectors":list};
 }
 NSDictionary *views=MYBAdsDiscoveryViewClasses(windows,4000);
 NSMutableDictionary *adViews=[NSMutableDictionary dictionary];
 for(NSString *name in views)if(MYBAdsDiscoveryNameLooksAdLike(name)&&adViews.count<15)adViews[name]=@{@"count":views[name],@"chain":MYBAdsDiscoveryChain(NSClassFromString(name))};
 return @{@"phase":@(phase),@"appVersion":appVersion?:@"",@"os":osVersion?:@"",@"adLikeClasses":classes,@"classSelectors":selectors,@"viewClasses":views,@"adLikeViews":adViews};
}
#ifndef MYB_INAPPADS_TESTING
#import <UIKit/UIKit.h>
// Started by the shared dispatcher only in the App Store's own process. A session starts it now, or later while the App Store is already open.
void MYBAdsRun_appstore(void){
 @autoreleasepool{
  MYBAdsDiscoveryWatch(@"appstore",^(NSString *session){
   MYBAdsDiscoveryStarted(@"appstore",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]); // proves the collector ran and reached the service, not that Search was opened
   // 30 s and 100 s after the session starts: long enough to open the Search tab and scroll once between the two
   for(NSNumber *delay in @[@30,@100]){
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.intValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
     NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
     MYBAdsDiscoveryLog(@"appstore",MYBAppStoreDiscoveryInfo(delay.unsignedIntegerValue,@[@"AppStore",@"JetEngine",@"AMSUI"],MYBAdsDiscoveryWindows(),version,UIDevice.currentDevice.systemVersion));
    });
   }
  });
 }
}
#endif
