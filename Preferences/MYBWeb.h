#import <UIKit/UIKit.h>
// Embedded web screen (informational pages and optional test pages) and the configuration-profile handoff.
//
// MYBWebController loads nothing until it is shown, uses a non-persistent data store (no cookies or history kept) and always
// offers "Open in Browser". Popup tests run inside an embedded web view test that environment, not necessarily your browser.
@interface MYBWebController : UIViewController
- (instancetype)initWithURL:(NSURL *)url title:(NSString *)title note:(NSString *)note;
@end
// Pushes the embedded screen. `note` is the short explanation shown above the page (nil for none).
void MYBPushWeb(UIViewController *owner,NSString *urlString,NSString *title,NSString *note);
// Delivers a locally served configuration profile (.mobileconfig) as a copyable link for Safari or as a file to save to Files.
// It never opens the default browser and never says the profile was installed: iOS does the review and install itself.
void MYBDeliverProfileFile(UIViewController *owner,NSString *folder,NSString *file,NSString *title,NSString *link);
NSString *MYBProfileStatusText(NSString *folder,NSString *file);
void MYBRefreshProfileStatus(UIViewController *owner,NSString *folder,NSArray<NSString *> *files,void(^done)(void));
