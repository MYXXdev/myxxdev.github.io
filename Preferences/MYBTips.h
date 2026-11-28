#pragma once
#import <UIKit/UIKit.h>
// Short branded tips, shown once each in the same MYbloXX® sheet the Shield uses. A tip is remembered as dismissed only when "Got It" is tapped.
// Dismissals live in net.myxxdev.mybloxx.tips.plist, which updates, disabling and uninstalling never touch.
void MYBTipShowOnce(UIViewController *host, NSString *key, NSString *heading, NSString *message, NSString *symbol);
// The Shield sheet for a question, a result or an error raised from Settings. actions: @{@"title",@"detail"(opt),@"style":primary|secondary|destructive|cancel,
// @"handler":void(^)(void)(opt),@"result":NSDictionary*(^)(void)(opt: {title,message,ok} replaces the sheet's content after the handler runs)}.
// facts: [label,value] pairs. tone: 0 accent, 1 positive, 2 warning.
void MYBShieldChoice(UIViewController *host,NSString *heading,NSString *message,NSArray<NSArray<NSString *> *> *facts,NSString *symbol,NSInteger tone,NSArray<NSDictionary *> *actions);
// Replay Tips: forgets every dismissal and tells Photos (through ReplayCount) to do the same. Returns NO if the file could not be written.
BOOL MYBTipsReplay(void);
