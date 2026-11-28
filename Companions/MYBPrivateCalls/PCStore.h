#pragma once
// MYbloXX® Private Calls, storage. Numbers and actions stay on this phone, in ONE list: the privacy preference file that holds the other Extra Privacy switches.
// Nothing here is logged.
#import <Foundation/Foundation.h>
BOOL PCSwitchOn(void);                       // Private Calls is switched on in MYbloXX® Settings
void PCReload(void);                         // re-read both lists now
NSArray *PCEffectiveEntries(void);           // the numbers that are private right now: {k, d, a, t, on}
NSString *PCRegion(void);                    // the phone's region, used only to read numbers typed without a country code
BOOL PCSetEntry(NSString *key, NSString *display, NSString *action, BOOL on);   // saves into THE store (directly or through the root helper); YES only after reading it back
void PCRetire(void);                         // drops Phone's r18 list and finished requests once the store covers them
NSDictionary *PCStoreState(void);            // booleans, counts and words only: store read, migrated, last save route
void PCPublish(NSString *domain, NSString *key, NSDictionary *status);          // counts and class names only
