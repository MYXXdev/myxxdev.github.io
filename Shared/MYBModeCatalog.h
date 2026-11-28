#pragma once
#import <Foundation/Foundation.h>
#import "MYBModeNames.h"
// One catalogue of blocking modes for Blocking Mode, Exact Differences and Legacy Mode profiles, so every screen uses
// the same names and concise descriptions. Mode identifiers (and the PAC files they select) are not touched here.
static inline NSArray<NSDictionary *> *MYBModeTable(void){
 return @[
  @{@"mode":@"Default",@"icon":@"shield.lefthalf.filled",@"short":@"Standard protection",@"long":@"The original MYbloXX® protection."},
  @{@"mode":@"allowY",@"icon":@"y.circle",@"short":@"Keeps Yahoo! services reachable",@"long":@"Default protection, with Yahoo! services (m.yap.yahoo.com) and graph.instagram.com left reachable. You may see more ads there. It does not change YouTube."},
  @{@"mode":@"blockAdSense",@"icon":@"nosign",@"short":@"Also blocks Facebook Graph",@"long":@"Default protection plus graph.facebook.com."},
  @{@"mode":@"blockApple",@"icon":@"apple.logo",@"short":@"Also blocks Apple services",@"long":@"Default protection plus Apple, iCloud and iTunes addresses. Some Apple features may stop working."},
  @{@"mode":@"blockSocials",@"icon":@"person.2.slash",@"short":@"Also blocks social networks",@"long":@"Default protection plus Facebook, Instagram, TikTok, Snapchat and other social networks."},
  @{@"mode":@"blockXXX",@"icon":@"eye.slash",@"short":@"Also blocks adult sites",@"long":@"Default protection plus adult websites."}];
}

// Shown before a mode is applied or its profile is installed. Each notice states only what the bundled PAC for that mode
// does (tests/mode-notices.js evaluates the shipped PACs against every claim). The original MYbloXX notices (b4-b6
// config.m / legacy.m) were checked first and not carried over where the current PAC no longer behaves that way:
// blockSocials no longer blocks Google, and Default needs no notice. The same text is used for normal mode and legacy
// profiles, adapted only for where it is shown.
static inline NSString *MYBModeWarning(NSString *mode,BOOL profile){
 NSString *when=profile?@"installing this profile":@"switching to this mode";
 if([mode isEqual:@"blockAdSense"])return [NSString stringWithFormat:@"Before %@, you understand that this will BLOCK Facebook AdSense ads.\n\nblockAdSense may prevent Facebook and Messenger sign-in. If you are logged out of Facebook/Messenger, you will NOT be able to log in without first switching MYbloXX\u00ae off or returning to Default.\n\nThis also applies to games and apps that use Facebook accounts to log in or save progress. If you use Facebook to log in on a regular basis, switch to Default if you have trouble signing in.",when];
 if([mode isEqual:@"allowY"])return [NSString stringWithFormat:@"Before %@, you understand that Yahoo! (m.yap.yahoo.com) and graph.instagram.com requests are NOT blocked in this mode, which lets Yahoo! apps work as intended.\n\nExpect to see more ads inside Yahoo! apps.",when];
 if([mode isEqual:@"blockApple"])return [NSString stringWithFormat:@"Before %@, you understand that this blocks addresses used by Apple, iCloud, iMessage, the App Store and iTunes, and iOS software updates.\n\nApple ID sign-in, iCloud, messages, App Store downloads and iOS updates may stop working. Switch back to Default to restore them.",when];
 if([mode isEqual:@"blockSocials"])return [NSString stringWithFormat:@"Before %@, you understand that this blocks Facebook, Instagram, TikTok, Snapchat, X (Twitter), Reddit and other social networks.\n\nApps and games that use one of these accounts to log in will not sign in while this mode is on. Switch back to Default to use them again.",when];
 if([mode isEqual:@"blockXXX"])return [NSString stringWithFormat:@"Before %@, you understand that this blocks a list of adult websites. A list cannot cover every site.\n\nFor fuller protection, also turn on Limit Adult Websites in Settings > Screen Time > Content & Privacy Restrictions > Web Content.",when];
 return nil;
}
