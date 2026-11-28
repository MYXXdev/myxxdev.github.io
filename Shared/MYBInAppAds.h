#pragma once
// In-App Ad Blocking (experimental): the catalogue the Settings screen and the per-app modules share, the stored
// choices, and the small runtime hook helper every module uses.
//
// Scope, deliberately narrow: each module removes advertising only (sponsored or promoted items, banners,
// interstitials, audio/video ads, and the empty gap an ad leaves). Nothing here touches downloads, background
// playback, subscription or Premium state, watermarks, read receipts, recommendations, Stories/Reels/Shorts/LIVE
// surfaces, or the app's identity.
//
// All modules ship in ONE dylib (MYBInAppAds.dylib), injected only into the apps listed below. A dispatcher identifies the process and
// starts the one module that owns it; each module keeps its own switch (default ON) and its own diagnostics. A module reads its switch
// once when the app starts, so a change takes effect the next time the app is opened.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/log.h>

#define MYB_ADS_PREFS_PATH @"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.inappads.plist"

// One entry per module. "ours" is the app version verified on a device (empty until verified).
static inline NSArray<NSDictionary *> *MYBAdsCatalogue(void){
 return @[
  @{@"module":@"youtube",@"name":@"YouTube",@"bundles":@[@"com.google.ios.youtube"],@"ours":@"",
    @"note":@"Removes player, Shorts and feed ads. Background playback and other YouTube changes are not touched."},
  @{@"module":@"instagram",@"name":@"Instagram",@"bundles":@[@"com.burbn.instagram"],@"ours":@"",
    @"note":@"Removes sponsored posts, Reels and Story ads. Shopping, suggestions and downloads are not touched."},
  @{@"module":@"tiktok",@"name":@"TikTok",@"bundles":@[@"com.zhiliaoapp.musically",@"com.ss.iphone.ugc.Ame",@"com.ss.iphone.ugc.Aweme",@"com.ss.iphone.ugc.aweme.lite"],@"ours":@"",
    @"note":@"Removes ad videos from the For You feed. LIVE, downloads and auto-scroll are not touched."},
  @{@"module":@"soundcloud",@"name":@"SoundCloud",@"bundles":@[@"com.soundcloud.TouchApp"],@"ours":@"",
    @"note":@"Stops audio, video and banner ad requests. SoundCloud Go and subscription state are not touched."},
  @{@"module":@"reddit",@"name":@"Reddit",@"bundles":@[@"com.reddit.Reddit"],@"ours":@"",
    @"note":@"Removes promoted posts and comment-page ads. Awards, scores and recommendations are not touched."},
  @{@"module":@"youtubemusic",@"name":@"YouTube Music",@"bundles":@[@"com.google.ios.youtubemusic"],@"ours":@"",
    @"note":@"Empties the player ad list and ad lead-in where the app uses them. Playback, background play, Premium and downloads are not touched."},
  @{@"module":@"x",@"name":@"X",@"bundles":@[@"com.atebits.Tweetie2"],@"ours":@"",
    @"note":@"Hides posts and trends X marks as promoted. Your timeline, replies, follows and topics are not touched."},
  @{@"module":@"messenger",@"name":@"Messenger",@"bundles":@[@"com.facebook.Messenger"],@"ours":@"",
    @"note":@"Removes ad rows from the chat list. Chats, Stories, Notes and suggestions are not touched."},
  @{@"module":@"facebook",@"name":@"Facebook",@"bundles":@[@"com.facebook.Facebook"],@"ours":@"",
    @"note":@"Removes sponsored posts, Watch and Stories ads, and Marketplace ads. Posts, messages, search, purchases and checkout are not touched."},
  @{@"module":@"amazon",@"name":@"Amazon Shopping",@"bundles":@[@"com.amazon.Amazon"],@"ours":@"",
    @"note":@"Hides sponsored results in Amazon’s web pages. Native app ads are not covered. Products, prices, search and checkout are not touched."},
  @{@"module":@"threads",@"name":@"Threads",@"bundles":@[@"com.burbn.barcelona"],@"ours":@"",
    @"note":@"Stops sponsored posts from being requested and placed in your feed. Posts, replies and follows are not touched."},
  @{@"module":@"gmail",@"name":@"Gmail",@"bundles":@[@"com.google.Gmail"],@"ours":@"",
    @"note":@"Removes the ad rows at the top of the inbox. Mail, labels, search and accounts are not touched."},
  @{@"module":@"douban",@"name":@"Douban",@"bundles":@[@"com.douban.frodo"],@"ours":@"",
    @"note":@"Removes the launch ad and ad slots. Posts, reviews and accounts are not touched."},
  @{@"module":@"qqmusic",@"name":@"QQ Music",@"bundles":@[@"com.tencent.QQMusic"],@"ours":@"",
    @"note":@"Removes the launch ad. Music, playback and your account are not touched."},
  @{@"module":@"sogou",@"name":@"Sogou Input",@"bundles":@[@"com.sogou.sogouinput"],@"ours":@"",
    @"note":@"Removes the launch ad and ad cells. Typing, skins and your account are not touched."},
  @{@"module":@"wechat",@"name":@"WeChat",@"bundles":@[@"com.tencent.xin"],@"ours":@"",
    @"note":@"Removes the launch ad and Moments ad data. Chats, Moments posts and your account are not touched."},
  @{@"module":@"bilibili",@"name":@"Bilibili",@"bundles":@[@"tv.danmaku.bilianime"],@"ours":@"",
    @"note":@"Removes commercial cards from the home feed and ad results from search. Videos, live, comments, banners and your account are not touched."},
  // Discovery only: nothing is blocked and it has no switch in the everyday list. Loaded only while "Collect discovery details" is on.
  @{@"module":@"appstore",@"name":@"App Store",@"bundles":@[@"com.apple.AppStore"],@"ours":@"",@"discoveryOnly":@YES,
    @"note":@"Discovery only. Writes bounded class and selector names to the log so sponsored placements can be identified. Blocks nothing."}];
}
static inline NSDictionary *MYBAdsEntry(NSString *module){for(NSDictionary *e in MYBAdsCatalogue())if([e[@"module"] isEqual:module])return e;return nil;}
static inline NSString *MYBAdsKey(NSString *module){return [@"ads-" stringByAppendingString:module];}
// On unless the person switched it off. A missing file or a missing key (a fresh install or a factory reset) means on, so every
// supported app is covered from the start; only an explicit "off" turns a module off.
static inline BOOL MYBAdsModuleEnabled(NSDictionary *prefs,NSString *module){
 if(!module.length)return NO;
 id value=[prefs isKindOfClass:NSDictionary.class]?prefs[MYBAdsKey(module)]:nil;
 return [value isKindOfClass:NSNumber.class]?[value boolValue]:YES;
}
// Whether the app version is one we have verified. Used for wording only; it never decides whether hooks install.
static inline BOOL MYBAdsVersionVerified(NSString *module,NSString *version){
 NSString *ours=MYBAdsEntry(module)[@"ours"];return ours.length&&[ours isEqual:version];
}

// ---- runtime hook helper ---------------------------------------------------------------------------------------
// Replace one method on exactly one class. Returns NO, and changes nothing, when the class or selector is missing, so
// an app update that renames something leaves that hook off and the app untouched. Inherited methods are overridden on
// the class itself, never on the superclass.
static inline BOOL MYBAdsHook(Class cls,SEL sel,BOOL classMethod,IMP replacement,IMP *original){
 if(!cls||!sel||!replacement)return NO;
 Class target=classMethod?object_getClass(cls):cls;
 Method method=classMethod?class_getClassMethod(cls,sel):class_getInstanceMethod(cls,sel);
 if(!method||!target)return NO;
 IMP previous=method_getImplementation(method);
 if(previous==replacement)return NO; // already installed: never wrap ourselves twice
 if(original)*original=previous;
 class_replaceMethod(target,sel,replacement,method_getTypeEncoding(method));
 return YES;
}
static inline BOOL MYBAdsHookNamed(const char *className,const char *selector,BOOL classMethod,IMP replacement,IMP *original){
 Class cls=objc_getClass(className);return cls?MYBAdsHook(cls,sel_registerName(selector),classMethod,replacement,original):NO;
}
static inline void MYBAdsLogResult(const char *module,NSUInteger installed,NSUInteger attempted){
 os_log(OS_LOG_DEFAULT,"MYbloXX® In-App Ad Blocking [%{public}s]: %lu of %lu hooks installed",module,(unsigned long)installed,(unsigned long)attempted);
}
// Items an ad filter must keep: anything that is not recognisably an ad is returned untouched.
static inline NSArray *MYBAdsFilter(NSArray *items,BOOL(^isAd)(id item)){
 if(![items isKindOfClass:NSArray.class]||!items.count)return items;
 NSUInteger removed=0;NSMutableArray *kept=nil;
 for(NSUInteger i=0;i<items.count;i++){
  id item=items[i];
  if(isAd(item)){if(!kept){kept=[[items subarrayWithRange:NSMakeRange(0,i)] mutableCopy];}removed++;continue;}
  [kept addObject:item];
 }
 return removed?kept:items; // untouched (and not copied) when nothing was an ad
}
