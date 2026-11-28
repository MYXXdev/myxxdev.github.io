#pragma once
// MYBEffectivePAC.h: the ONE definition of the effective PAC (base mode PAC + user rules +
// website exceptions + transport rewrite). pacd serves it, the helper embeds it inline.
#import "MYBTransport.h"
#import "MYBWebsiteRules.h"
#import "MYBRuleStore.h"
#import "MYBSetupBackup.h"
// Base PAC: first valid candidate (updated PACCurrent, then PAC, then bundled).
static inline NSString *MYBBasePACText(NSString *file,NSArray<NSString *> *folders){
 for(NSString *folder in folders){
  NSData *data=[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:file]];
  if(data.length<100||data.length>2*1024*1024)continue;
  NSString *text=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if([text containsString:@"function FindProxyForURL"])return text;
 }
 return nil;
}
static inline NSString *MYBEffectivePACText(NSString *mode,NSArray<NSString *> *folders,NSString *appliedPath,NSString *websitePath){
 NSString *base=MYBBasePACText([mode stringByAppendingString:@".pac"],folders);
 if(!base)return nil;
 NSDictionary *applied=appliedPath?[NSDictionary dictionaryWithContentsOfFile:appliedPath]:nil;
 NSDictionary *website=websitePath?[NSDictionary dictionaryWithContentsOfFile:websitePath]:nil;
 return MYBSetupLivePAC(base,MYBEffectiveRulesLive(applied,website));
}
