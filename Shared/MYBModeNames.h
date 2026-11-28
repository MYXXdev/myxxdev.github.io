#pragma once
#import <Foundation/Foundation.h>
#import "MYBOptions.h"
static inline NSString *MYBModeName(NSString *mode){if(![mode isKindOfClass:NSString.class]||!mode.length)return @"Default";if([mode containsString:@"+"])return MYBModeSummary(mode)?:mode;return @{@"Default":@"Default",@"allowY":@"allowY!",@"blockAdSense":@"blockAdSense",@"blockApple":@"noApple",@"blockSocials":@"noSocials",@"blockXXX":@"noXXX",@"MYbloXX":@"Default",@"MYbloXXnoXXX":@"noXXX",@"MYbloXXnoApple":@"noApple",@"MYbloXXnoSocials":@"noSocials",@"MYbloXXnoFB":@"noSocials",@"MYbloXXallowY":@"allowY!",@"Custom":@"Custom",@"Proxy":@"Proxy Override",@"Legacy":@"Legacy"}[mode]?:mode?:@"Default";}
// Dashboard / diagnostics text for the current selection: "Default", "Default + noXXX", "Default + blockAdSense + noXXX".
// Values that are not option selections (Proxy Override, Custom, unknown) fall back to MYBModeName.
static inline NSString *MYBModeDisplay(NSString *mode){return MYBModeSummary(MYBMigrateModeID(mode))?:MYBModeName(mode);}
