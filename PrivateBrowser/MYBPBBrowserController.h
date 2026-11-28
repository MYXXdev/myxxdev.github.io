#import <UIKit/UIKit.h>
// The entire browsing UI: address bar, web view, back/forward/reload/wipe toolbar, and a basic tab switcher.
// Privacy guarantees (all tabs share one process-lifetime-only WKWebsiteDataStore, never the persistent default
// store) live here rather than scattered across files, so "what does private actually mean" has one place to read.
// Popup/ad/tracker blocking is deliberately NOT implemented here: this app just uses WKWebView and WKUIDelegate the
// ordinary way, and MYbloXX's existing Shield component (Companions/MYBShieldBrowser, injected into this app's
// bundle ID via Shared/MYBBrowserPolicy.h) supplies the same blocking every other browser on the device already
// gets, by transparently wrapping setNavigationDelegate:/setUIDelegate: -- there is no second blocking engine here.
@interface MYBPBBrowserController : UIViewController
// Drops every in-memory record from the shared data store immediately, without waiting for the process to exit.
// Used both by a real app termination and by the in-app "Wipe" control, so a mid-session wipe is a real guarantee,
// not just a visual reset of the tab list.
+ (void)purgeEphemeralData;
@end
