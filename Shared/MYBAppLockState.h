#pragma once
// MYbloXX® App Lock: the unlock state machine and the list of apps that can never be selected. Pure logic, no UIKit, so it is tested on its own.
// Each unlock is bound to ONE activation of ONE app: a new activation, leaving the app, or locking the device invalidates any prompt still in flight, so a
// late or stale authentication result can never open the wrong visit.
#import <Foundation/Foundation.h>
typedef struct{int locked;int authenticating;unsigned long activation;unsigned long prompt;}MYBLockState;
static inline MYBLockState MYBLockInit(void){MYBLockState s;s.locked=1;s.authenticating=0;s.activation=1;s.prompt=0;return s;}
// The app came to the front (cold launch, switcher, notification tap, link, widget or Spotlight all end up here): a fresh activation, locked.
static inline void MYBLockActivate(MYBLockState *s){s->activation++;s->locked=1;s->authenticating=0;s->prompt=0;}
// Leaving the app or locking the device ends the visit and any prompt in flight.
static inline void MYBLockLeave(MYBLockState *s){s->activation++;s->locked=1;s->authenticating=0;s->prompt=0;}
// Starts a prompt for the current activation; returns its ticket, or 0 when one is already showing or the app is already unlocked.
static inline unsigned long MYBLockBeginPrompt(MYBLockState *s){if(!s->locked||s->authenticating)return 0;s->authenticating=1;s->prompt=s->activation*1000+1;return s->prompt;}
// A result arrives with the ticket it was started with. Only the live ticket counts; cancel, failure and anything stale leave the cover in place.
static inline int MYBLockFinish(MYBLockState *s,unsigned long ticket,int success){
 if(ticket==0||ticket!=s->prompt||!s->authenticating)return 0;
 s->authenticating=0;s->prompt=0;if(success){s->locked=0;return 1;}return 0;
}
static inline int MYBLockIsOpen(const MYBLockState *s){return !s->locked;}
// Apps that are never offered and never covered: Settings (the way back out), phone and emergency interfaces, system services, and the jailbreak recovery apps.
static inline BOOL MYBLockEligible(NSString *bundle){
 if(![bundle isKindOfClass:NSString.class]||bundle.length<3)return NO;
 for(NSString *exact in [NSArray arrayWithObjects:@"com.apple.springboard",@"com.apple.Preferences",@"com.apple.mobilephone",@"com.apple.InCallService",@"com.apple.facetime",@"com.apple.TelephonyUtilities",@"com.apple.MobileSOS",@"com.apple.purplebuddy",@"com.apple.CarPlayApp",@"com.apple.Spotlight",@"com.apple.SafariViewService",@"com.apple.camera",@"com.apple.Home",nil])if([bundle isEqualToString:exact])return NO;
 for(NSString *prefix in [NSArray arrayWithObjects:@"com.apple.CoreAuthUI",@"com.apple.siri",@"com.apple.SharingViewService",@"com.apple.ScreenTimeViewService",@"com.apple.PassbookUIService",@"com.apple.ios.StoreKitUIService",@"org.coolstar",@"xyz.willy",@"com.tigisoftware",@"com.opa334",@"com.roothide",@"net.myxxdev",nil])if([bundle hasPrefix:prefix])return NO;
 return YES;
}
