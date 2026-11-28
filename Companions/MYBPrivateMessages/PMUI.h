#pragma once
#import <UIKit/UIKit.h>
void PMOpenFromGesture(UIViewController *host);   // five taps on the Messages title: authenticate if asked, then show the private list
void PMLockAll(void);                              // Messages left the screen or the phone locked
void PMCoverIfNeeded(void);                        // opaque cover before the app switcher snapshot
void PMUncover(void);
void PMMaybeShowTip(UIViewController *host);
