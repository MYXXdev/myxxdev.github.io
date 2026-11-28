# Private Conversations (RH-15-112526, Debian 6.11252026-6-RH)

Messages only (`com.apple.MobileSMS`, iOS 16). No CommCenter, carrier bundle, SIM/eSIM, call or delivery code is in the component (the package test fails if
any appears). Off until switched on in MYbloXX® Settings > Extra Privacy Protection > Private Conversations.

## What it does
- Five taps on the Messages title (large or collapsed) open the private list. Optional Face ID / passcode lock (LocalAuthentication) in front of it.
- Threads never leave Apple's database. Only a salted SHA-256 of the exact chat GUID, the earlier Hide Alerts state and a state word are stored, in Messages' own preferences.
- A **Private** swipe action appears on ordinary conversations only while the private session is unlocked (Apple's own menu is not changed). In the private list: swipe or long-press **Return to Messages**; **+** adds a conversation by name if the menu cannot be extended on a given build.
- Silencing: the native per-conversation Hide Alerts. The stock long-press Hide Alerts / Show Alerts action is performed itself (so no private setter is needed) and the result is **read back twice** before the thread is hidden. A runtime-discovered setter is used first when one exists. If it cannot be proven the move is undone and the thread stays visible. Needs the thread on screen in the ordinary list.
- Lock: the session ends and the list closes when Messages resigns active/backgrounds or the phone locks; an opaque cover hides the list and any private thread from the app switcher.

## Runtime evidence
From the phone (iOS 16.5.1, diagnostics copied from Settings): CKConversation has isMuted, setMutedUntilDate:, unmute and canMuteStateBeToggled; the list builds its long-press menu through `_dci_collectionView:contextMenuConfigurationForItemsAtIndexPaths:point:`. Both are wired.

Selectors of private classes could not be checked offline (the SDK has class names only). The component discovers them at run time, publishes which list getters it hooked and the
names of mute-related selectors it saw (names only) to the status Settings shows, and does nothing if the list getters are not found.

## Coverage (what is and is not claimed)
Covered in code: main list, pinned and unread-filter arrays (ChatKit list getters), long-press menu, private list, lock, cover.
Not claimed, needs the phone: banners, sounds, Lock Screen, Notification Center, badges, group mentions; Messages search results; Spotlight and Siri suggestions; Apple Watch, Mac and iPad alerts; Face ID prompt from Messages.
A person with a phone number and an iMessage email can have two threads (two GUIDs). Only the thread you moved is private.

## Upgrade, off, uninstall
Assignments live in Messages' preferences and survive upgrades. Turning the switch off shows every thread again (hooks stop filtering). Hide Alerts can only be restored by Messages:
Settings offers **Turn Off and Restore Alerts** and **Restore Alerts Now** (opens Messages, which restores each thread's earlier setting and keeps working even with the switch off). Do this before uninstalling; the uninstall prints a reminder.

## Device checklist (disposable threads only)
1. Baseline: send/receive SMS, iMessage, make and receive a call, check cellular data. Do not touch eSIM settings.
2. Settings: turn on Private Conversations. Open Messages, read the tip. Five taps on the title opens the list (try large and collapsed title).
3. Go back, swipe a disposable thread left and tap Private. The row disappears at once; check pinned, Unread filter and search.
4. Reply to it from another phone: banner, sound, Lock Screen, Notification Center, badge. Repeat for a group (with a mention) and for a person on number + email.
5. Open the thread from the private list, send a reply and an attachment.
6. Background Messages, check the app switcher snapshot; lock the phone and reopen: the list is closed.
7. Return to Messages: thread reappears, Hide Alerts is as before (test a thread that was already muted first).
8. Turn the feature off with a private thread present; choose Restore Alerts. Repeat baseline (SMS, iMessage, calls, cellular).
9. Spotlight and Siri: search the contact name and note what appears.
