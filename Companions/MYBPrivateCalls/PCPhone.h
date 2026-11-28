#pragma once
// MYbloXX® Private Calls, Phone side (com.apple.mobilephone only): hides the private numbers' calls from Recents, five taps on Recents open Private Recents
// after Face ID or passcode, and long-press on a call can make its number private. The calls themselves are never changed or deleted.
void PCPhoneInstall(void);
void PCPhoneLockAll(void);           // Phone left the screen or the phone locked: close Private Recents
void PCPhoneCoverIfNeeded(void);     // opaque cover before the app switcher snapshot
void PCPhoneUncover(void);
