#pragma once
// Blocking options. Default is the base; allowY!, blockAdSense, noApple, noSocials and noXXX are options that can be
// combined. A selection is stored as ONE mode identifier, so every existing place that keeps a mode (saved state, status
// files, backups, PAC file names, updates) keeps working:
//   "Default"                          no option
//   "allowY", "blockAdSense", "blockApple", "blockSocials", "blockXXX"      exactly one option: the historical identifiers
//   "allowY+blockAdSense+blockXXX"     several options, always in the fixed order below, joined by "+"
// The matching PAC for every identifier is generated from rules/canonical.json by rules/generate.py (32 files).
// Precedence between options, independent of the order they were chosen in: every option's exemptions are applied to the
// Default list first, then every option's blocks are added, so a blocking option always wins over another option's exemption.
#import <Foundation/Foundation.h>
static inline NSArray<NSString *> *MYBOptionOrder(void){return @[@"allowY",@"blockAdSense",@"blockApple",@"blockSocials",@"blockXXX"];}
static inline NSString *MYBOptionLabel(NSString *option){return @{@"allowY":@"allowY!",@"blockAdSense":@"blockAdSense",@"blockApple":@"noApple",@"blockSocials":@"noSocials",@"blockXXX":@"noXXX"}[option]?:option;}
// Identifier for a set of options; unknown names are ignored. Always canonical (fixed order, no duplicates).
static inline NSString *MYBModeIDForOptions(id options){
 NSSet *want=[options isKindOfClass:NSSet.class]?options:[NSSet setWithArray:[options isKindOfClass:NSArray.class]?options:@[]];
 NSMutableArray *chosen=[NSMutableArray array];for(NSString *o in MYBOptionOrder())if([want containsObject:o])[chosen addObject:o];
 return chosen.count?[chosen componentsJoinedByString:@"+"]:@"Default";
}
// The options an identifier stands for, or nil when it is not a valid identifier (a hand-edited or malicious value).
static inline NSArray<NSString *> *MYBOptionsForModeID(NSString *mode){
 if(![mode isKindOfClass:NSString.class]||!mode.length||mode.length>80)return nil;if([mode isEqual:@"Default"])return @[];
 NSArray *parts=[mode componentsSeparatedByString:@"+"];NSArray *order=MYBOptionOrder();NSInteger last=-1;
 for(NSString *p in parts){NSInteger i=(NSInteger)[order indexOfObject:p];if(i==NSNotFound||i<=last)return nil;last=i;}
 return parts;
}
static inline BOOL MYBModeIDValid(NSString *mode){return MYBOptionsForModeID(mode)!=nil;}
// All 32 identifiers.
static inline NSArray<NSString *> *MYBModeIDs(void){
 NSMutableArray *all=[NSMutableArray arrayWithObject:@"Default"];NSArray *order=MYBOptionOrder();
 for(NSUInteger m=1;m<(1u<<order.count);m++){NSMutableArray *c=[NSMutableArray array];for(NSUInteger i=0;i<order.count;i++)if(m&(1u<<i))[c addObject:order[i]];[all addObject:[c componentsJoinedByString:@"+"]];}
 return all;
}
// "Default", "Default + blockAdSense + noXXX".
static inline NSString *MYBModeSummary(NSString *mode){
 NSArray *options=MYBOptionsForModeID(mode);if(!options)return nil;if(!options.count)return @"Default";
 NSMutableArray *names=[NSMutableArray arrayWithObject:@"Default"];for(NSString *o in options)[names addObject:MYBOptionLabel(o)];return [names componentsJoinedByString:@" + "];
}
// Migration of a saved mode value to a current identifier. Accepts what earlier releases and hand edits may have stored:
// a current identifier (unchanged), a historical standalone PAC name (MYbloXXnoXXX), a display label (noXXX, allowY!), and
// a set of options in any order separated by "+", "," or spaces. "Custom" (the historical Proxy Override marker) passes through.
// Returns nil for anything else; the caller keeps its existing value (never guesses). Off/on state is never part of a mode.
static inline NSString *MYBMigrateModeID(id raw){
 if(![raw isKindOfClass:NSString.class])return nil;
 NSString *text=[raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(!text.length||text.length>120)return nil;
 if([text isEqual:@"Custom"])return @"Custom";
 if(MYBModeIDValid(text))return text;
 NSDictionary *tokens=@{@"default":@"",@"mybloxx":@"",@"mybloxxtest":@"",@"mybloxxallowfb":@"",@"mybloxxnofb":@"",
  @"allowy":@"allowY",@"allowy!":@"allowY",@"mybloxxallowy":@"allowY",@"blockadsense":@"blockAdSense",
  @"blockapple":@"blockApple",@"noapple":@"blockApple",@"mybloxxnoapple":@"blockApple",
  @"blocksocials":@"blockSocials",@"nosocials":@"blockSocials",@"mybloxxnosocials":@"blockSocials",
  @"blockxxx":@"blockXXX",@"noxxx":@"blockXXX",@"mybloxxnoxxx":@"blockXXX"};
 NSMutableArray *options=[NSMutableArray array];
 for(NSString *part in [text componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"+, "]]){
  if(!part.length)continue;NSString *hit=tokens[part.lowercaseString];if(!hit)return nil;if(hit.length)[options addObject:hit];
 }
 return MYBModeIDForOptions(options);
}
