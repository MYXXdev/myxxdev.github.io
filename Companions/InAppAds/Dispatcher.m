// MYbloXX In-App Ad Blocking: the one shared dylib. It is injected into the supported apps named in its bundle filter
// (MYBInAppAds.plist) and into exactly the apps the person selected under Ad Network Blocking (the helper adds them to the filter; com.apple.UIKit is never named). On load it identifies the process and starts exactly one module, the one whose catalogue entry lists this
// app. Every other module stays unloaded in that process: no hooks, no work.
// Each module still reads its own switch (default OFF) and reports its own diagnostics; nothing here changes either.
#import <Foundation/Foundation.h>
#import "../../Shared/MYBInAppAds.h"

void MYBAdsRun_youtube(void);void MYBAdsRun_instagram(void);void MYBAdsRun_tiktok(void);void MYBAdsRun_soundcloud(void);
void MYBAdsRun_reddit(void);void MYBAdsRun_youtubemusic(void);void MYBAdsRun_x(void);void MYBAdsRun_messenger(void);void MYBAdsRun_facebook(void);void MYBAdsRun_amazon(void);void MYBAdsRun_threads(void);void MYBAdsRun_gmail(void);void MYBAdsRun_douban(void);void MYBAdsRun_qqmusic(void);void MYBAdsRun_sogou(void);void MYBAdsRun_wechat(void);void MYBAdsRun_bilibili(void);void MYBAdsRun_appstore(void);
void MYBAdSDKStart(void); // Ad Network Blocking (SDK/Module.m): returns at once unless this app is selected in Settings

// The module that owns this app, or nil. Matching is exact: an app extension (its identifier is longer) never matches.
NSString *MYBAdsModuleForBundle(NSString *bundle){
 if(![bundle isKindOfClass:NSString.class]||!bundle.length)return nil;
 for(NSDictionary *entry in MYBAdsCatalogue())if([entry[@"bundles"] containsObject:bundle])return entry[@"module"];
 return nil;
}
BOOL MYBAdsRunModule(NSString *module){
 static NSDictionary<NSString *,NSValue *> *table;
 static dispatch_once_t once;
 dispatch_once(&once,^{table=@{@"youtube":[NSValue valueWithPointer:(void *)MYBAdsRun_youtube],@"instagram":[NSValue valueWithPointer:(void *)MYBAdsRun_instagram],
  @"tiktok":[NSValue valueWithPointer:(void *)MYBAdsRun_tiktok],@"soundcloud":[NSValue valueWithPointer:(void *)MYBAdsRun_soundcloud],
  @"reddit":[NSValue valueWithPointer:(void *)MYBAdsRun_reddit],@"youtubemusic":[NSValue valueWithPointer:(void *)MYBAdsRun_youtubemusic],
  @"x":[NSValue valueWithPointer:(void *)MYBAdsRun_x],@"messenger":[NSValue valueWithPointer:(void *)MYBAdsRun_messenger],@"facebook":[NSValue valueWithPointer:(void *)MYBAdsRun_facebook],@"amazon":[NSValue valueWithPointer:(void *)MYBAdsRun_amazon],
  @"threads":[NSValue valueWithPointer:(void *)MYBAdsRun_threads],@"gmail":[NSValue valueWithPointer:(void *)MYBAdsRun_gmail],@"douban":[NSValue valueWithPointer:(void *)MYBAdsRun_douban],@"qqmusic":[NSValue valueWithPointer:(void *)MYBAdsRun_qqmusic],@"sogou":[NSValue valueWithPointer:(void *)MYBAdsRun_sogou],@"wechat":[NSValue valueWithPointer:(void *)MYBAdsRun_wechat],@"bilibili":[NSValue valueWithPointer:(void *)MYBAdsRun_bilibili],@"appstore":[NSValue valueWithPointer:(void *)MYBAdsRun_appstore]};});
 NSValue *entry=module?table[module]:nil;if(!entry)return NO;
 ((void(*)(void))entry.pointerValue)();return YES;
}
#ifndef MYB_INAPPADS_TESTING
__attribute__((constructor)) static void MYBAdsDispatch(void){
 @autoreleasepool{
  // The filter names only catalogue apps and the apps selected under Ad Network Blocking. This guard is a second line: a process that is
  // somehow loaded anyway (no catalogue module, not selected) does nothing beyond reading one small preferences file inside MYBAdSDKStart.
  MYBAdsRunModule(MYBAdsModuleForBundle(NSBundle.mainBundle.bundleIdentifier));
  MYBAdSDKStart();
 }
}
#endif
