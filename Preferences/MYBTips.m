#import "MYBTips.h"
#import "MYBDesign.h"
#define MYB_SHEET_CLASS MYBSettingsTipSheet
#import "../Shared/MYBShieldSheet.h"

static NSString *TipsFile(void){return MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.tips.plist");}
static BOOL Showing;

void MYBTipShowOnce(UIViewController *host,NSString *key,NSString *heading,NSString *message,NSString *symbol){
 if(Showing||!key.length||!host.view.window||host.presentedViewController)return;
 NSDictionary *dismissed=[NSDictionary dictionaryWithContentsOfFile:TipsFile()][@"Dismissed"];
 if([dismissed[key] boolValue])return;
 Showing=YES;
 MYBSettingsTipSheet *sheet=[MYBSettingsTipSheet new];
 sheet.kicker=@"MYBLOXX® TIP";sheet.heading=heading;sheet.message=message;sheet.symbol=symbol.length?symbol:@"lightbulb.fill";sheet.tone=MYBShieldAccent();
 sheet.dismissOnBackdrop=NO; // dismissed only by the button, so a tip that was not read is not counted as read
 sheet.actions=@[[MYBShieldAction title:@"Got It" detail:nil style:MYBShieldActionPrimary handler:^{
  NSMutableDictionary *tips=[([NSDictionary dictionaryWithContentsOfFile:TipsFile()]?:@{}) mutableCopy];
  NSMutableDictionary *seen=[([tips[@"Dismissed"] isKindOfClass:NSDictionary.class]?tips[@"Dismissed"]:@{}) mutableCopy];
  seen[key]=@YES;tips[@"Dismissed"]=seen;[tips writeToFile:TipsFile() atomically:YES];
 }]];
 sheet.onGone=^{Showing=NO;};
 if(![MYBSettingsTipSheet present:sheet from:host completion:nil])Showing=NO;
}

void MYBShieldChoice(UIViewController *host,NSString *heading,NSString *message,NSArray<NSArray<NSString *> *> *facts,NSString *symbol,NSInteger tone,NSArray<NSDictionary *> *actions){
 if(!host.view.window)return;
 UIViewController *top=host;while(top.presentedViewController&&!top.presentedViewController.isBeingDismissed)top=top.presentedViewController;
 MYBSettingsTipSheet *sheet=[MYBSettingsTipSheet new];
 sheet.heading=heading;sheet.message=message;sheet.facts=facts;sheet.symbol=symbol.length?symbol:@"hand.raised.fill";
 sheet.tone=tone==1?MYBShieldPositive():tone==2?MYBShieldWarning():MYBShieldAccent();
 NSMutableArray *built=[NSMutableArray array];BOOL hasCancel=NO;
 for(NSDictionary *a in actions){
  NSString *style=a[@"style"];MYBShieldActionStyle s=[style isEqual:@"primary"]?MYBShieldActionPrimary:[style isEqual:@"destructive"]?MYBShieldActionDestructive:[style isEqual:@"cancel"]?MYBShieldActionCancel:MYBShieldActionSecondary;
  if(s==MYBShieldActionCancel)hasCancel=YES;
  MYBShieldAction *action=[MYBShieldAction title:a[@"title"] detail:a[@"detail"] style:s handler:a[@"handler"]];action.result=a[@"result"];[built addObject:action];
 }
 sheet.actions=built;sheet.dismissOnBackdrop=hasCancel||built.count<=1;
 [MYBSettingsTipSheet present:sheet from:top completion:nil];
}

BOOL MYBTipsReplay(void){
 NSMutableDictionary *tips=[([NSDictionary dictionaryWithContentsOfFile:TipsFile()]?:@{}) mutableCopy];
 [tips removeObjectForKey:@"Dismissed"];
 tips[@"ReplayCount"]=@([tips[@"ReplayCount"] integerValue]+1);
 return [tips writeToFile:TipsFile() atomically:YES];
}
