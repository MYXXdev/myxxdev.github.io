// Which browsers MYbloXX's Shield component is injected into, and what each is expected to support.
// The tweak filter (Companions/MYBShieldBrowser/MYBShieldBrowser.plist), the runtime checks in the tweak and the
// diagnostics all derive from this one list; tests/browser-policy.py fails the build if they disagree.
//
// Four separate things are tracked per browser, because each can work without the others:
//   network    system-proxy filtering (PAC). Independent of injection - it works for every app, injected or not.
//   popups     popup interception (navigation-policy and window-creation hooks) + the native "Popup blocked" notice
//   page       blocked-page presentation (redirecting a blocked top-level navigation to the local notice)
//   prompts    permission prompts / allow-and-retry (UIKit sheets and banners presented over the browser's window)
// "evidence" says what has actually been observed on a device: "none" means implemented, awaiting device verification.
//
// Deliberately NOT injected: every other process. In-app WKWebViews and SFSafariViewController
// (com.apple.SafariViewService is shared by every app on the device) are not browsers and are not hooked; their
// traffic is still filtered by the system proxy.
#import <Foundation/Foundation.h>
static inline NSArray<NSDictionary *> *MYBBrowserTable(void){
 static NSArray *table;static dispatch_once_t once;dispatch_once(&once,^{
  #define B(bid,nm,fam) @{@"id":bid,@"name":nm,@"family":fam,@"network":@YES,@"popups":@YES,@"page":@YES,@"prompts":@YES,@"evidence":@"none"}
  table=@[
   B(@"com.apple.mobilesafari",@"Safari",@"webkit-system"),
   B(@"org.mozilla.ios.Firefox",@"Firefox",@"webkit-third-party"),
   B(@"org.mozilla.ios.Focus",@"Firefox Focus",@"webkit-third-party"),
   B(@"com.google.chrome.ios",@"Chrome",@"webkit-third-party"),
   B(@"com.microsoft.msedge",@"Edge",@"webkit-third-party"),
   B(@"com.brave.ios.browser",@"Brave",@"webkit-third-party"),
   B(@"com.opera.OperaTouch",@"Opera",@"webkit-third-party"),
   B(@"com.duckduckgo.mobile.ios",@"DuckDuckGo",@"webkit-third-party"),
   B(@"net.myxxdev.mybloxxbrowser",@"MYB Private",@"webkit-first-party"),
  ];
  #undef B
 });return table;
}
static inline NSDictionary *MYBBrowserInfo(NSString *bundle){
 if(![bundle isKindOfClass:NSString.class])return nil;
 for(NSDictionary *b in MYBBrowserTable())if([b[@"id"] isEqual:bundle])return b;return nil;
}
static inline BOOL MYBBrowserInjects(NSString *bundle){return MYBBrowserInfo(bundle)!=nil;}
// Whether `capability` (network | popups | page | prompts) is attempted in this host.
static inline BOOL MYBBrowserSupports(NSString *bundle,NSString *capability){return [MYBBrowserInfo(bundle)[capability] boolValue];}
// Diagnostic state for one browser from what its component has reported. "Unknown" is not "failed": a browser that has
// not been launched since install has sent nothing, and that proves nothing about injection.
//   events: dictionary of observed flags - loaded, navigation, windowHook, bridgeFailed, hostUnsupported, shieldOff
static inline NSString *MYBBrowserDiagnosticState(NSDictionary *events){
 if(![events isKindOfClass:NSDictionary.class]||![events count])return @"not-observed";
 if([events[@"hostUnsupported"] boolValue])return @"host-callback-unsupported";
 if([events[@"bridgeFailed"] boolValue]&&![events[@"bridgeReady"] boolValue])return @"bridge-unavailable";
 if([events[@"shieldOff"] boolValue])return @"shield-disabled";
 if([events[@"windowHook"] boolValue])return @"window-hook-observed";
 if([events[@"navigation"] boolValue])return @"navigation-hook-observed";
 if([events[@"loaded"] boolValue])return @"loaded";
 return @"not-observed";
}
