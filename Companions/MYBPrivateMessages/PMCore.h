#pragma once
// MYbloXX® Private Conversations, MobileSMS only. This component never touches Apple's message database, CommCenter, carrier or SIM settings, call
// handling or message delivery. It keeps, in Messages' own preferences, only a salted hash of each private conversation's chat identity and whether
// "Hide Alerts" was already on before MYbloXX® changed it. No names, numbers, addresses, message text or attachments are ever stored or logged.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void (^PMDone)(BOOL ok, NSString *message);

// Switches written by MYbloXX® Settings (privacy.plist). Both default OFF.
BOOL PMActive(void);      // Private Conversations is switched on AND the hooks it needs were found on this iOS build
BOOL PMSwitchOn(void);
BOOL PMLockOn(void);      // require device authentication to open the private list
void PMReloadPrefs(void);

// Identity: a salted hash of the exact chat GUID (service + chat), never of a participant. Two threads with one person in common are two identities.
NSString *PMIdentity(id conversation);
BOOL PMIsPrivate(id conversation);
NSString *PMTitle(id conversation);
NSArray *PMPrivateConversations(void);
NSArray *PMOrdinaryConversations(void);

// Move and return. Every step is verified; a failure is reconciled and the message says what really happened.
void PMMove(id conversation, PMDone done);
void PMReturn(id conversation, PMDone done);
void PMReconcile(void);   // finishes half-done moves and any "restore alerts" request from Settings; runs even when the feature is off

// Session: unlocked from the five taps until Messages leaves the screen or the phone locks.
BOOL PMSessionUnlocked(void);
void PMSessionBegin(void);
void PMSessionEnd(void);

void PMInstallHooks(void);
void PMNoteTop(UIViewController *top);          // called as screens appear: bounces a private thread opened without the session
BOOL PMPrivateThreadVisible(void);
void PMPopPrivateThread(void);
void PMRefreshLists(void);
void PMPublishStatus(void);
UIViewController *PMFindController(NSString *classPrefix);
BOOL PMOpenNative(id conversation);
void PMCountMenuUse(void);
void PMScanList(UIViewController *list);        // reads the live list for its menu hookup and hooks it
