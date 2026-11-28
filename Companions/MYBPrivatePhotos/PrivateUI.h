#pragma once
// The Private Album and Photos tips use MYbloXX®'s own Shield sheet, colours and logo (Shared/MYBShieldSheet.h), so a confirmation in Photos looks and
// behaves like one in Settings or on the Home Screen. This file is the only place that includes that header: it defines a class, so every other file
// reaches it through these functions.
#import <UIKit/UIKit.h>
UIColor *MYXXBackground(void);
UIColor *MYXXPanel(void);
UIColor *MYXXAccent(void);
UIColor *MYXXMuted(void);
UIImage *MYXXMarkImage(void);
void MYXXStyleNavigation(UINavigationController *navigation);
// One message with a single OK. ok: the positive look (a copy that was saved), otherwise the cautionary one.
void MYXXShowMessage(UIViewController *host, NSString *title, NSString *message, BOOL ok);
// The centered confirmation: exact text, closes by itself, or on any tap.
void MYXXShowConfirmation(UIViewController *host, NSString *text, NSString *symbol);
// Choices: each @{@"title",@"detail"(optional),@"style":@"primary"|@"secondary"|@"destructive"|@"cancel",@"handler":block(optional)}.
void MYXXShowChoice(UIViewController *host, NSString *title, NSString *message, NSString *symbol, NSArray<NSDictionary *> *choices);
// A short branded tip, shown once per key. Dismissal is remembered across upgrades; "Replay Tips" in MYbloXX® Settings shows them again.
void MYXXShowTipOnce(UIViewController *host, NSString *key, NSString *heading, NSString *message, NSString *symbol);
void MYXXShowTipFactsOnce(UIViewController *host, NSString *key, NSString *heading, NSString *message, NSArray<NSArray<NSString *> *> *facts, NSString *symbol);
// Shared Face ID / device passcode check for the private views. proceed runs only after iOS reports success; a cancel or failure changes nothing.
void MYXXAuthenticate(UIViewController *host, NSString *reason, void (^proceed)(void));
