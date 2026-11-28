// MYbloXX In-App Ad Blocking: SoundCloud. Ads only.
// PROVENANCE: ADAPTED from pstepanovum/PSSoundcloud (GPL-3.0, tested by its author on SoundCloud 8.73.0): the same two ad-permission
// checks (AdsRequestPermitter.shouldRequestAds and DisplayAdBannerFeatureProvider.canRequestAdBanner) are answered "no"
// (src/Features/Ads.x). The module is a derivative work, distributed under the GNU GPL v3 with its source (see NOTICE.md and COPYING
// in usr/share/doc/mybloxx-inappads); compiled into MYBInAppAds.dylib, it makes the whole dylib GPL-3.0. What differs: it does not
// carry PSSoundcloud's list of third-party ad hosts (MYbloXX's own network blocking covers hosts), only its refusal of soundcloud.com/ads
// requests and promoted.soundcloud.com, which a host-level filter cannot separate from the app's own API; it does not touch the subscriber
// flag, and reports counts to MYbloXX's local service. Class names are Swift-mangled and version specific; a rename leaves the hook off.
// Answers "no" to the app's two ad-permission checks (ads request permitter and banner feature provider). It does not touch
// the subscriber flag and reports counts to MYbloXX's local service. Class names are Swift-mangled and version specific; a
// rename leaves the hook off.
#import <Foundation/Foundation.h>
#import "../../../Shared/MYBInAppAds.h"
#import "../../../Shared/MYBVersion.h"
#import "../../../Shared/MYBAdsReport.h"
#ifndef MYB_INAPPADS_TESTING
#import <roothide.h>
#endif
static IMP origPermit,origBanner,origProtocolClasses;
// SoundCloud fetches its audio and video ads from soundcloud.com/ads/... : the same host as the app's own API, so the network layer
// (which sees hosts, not paths, inside HTTPS) cannot tell them apart. Those requests are refused here with an ordinary connection
// failure, so the app sees a failed ad request, never a fake ad. Nothing else on soundcloud.com is touched.
BOOL MYBSoundCloudRequestIsAd(NSURLRequest *request){
 NSURL *url=request.URL;NSString *host=url.host.lowercaseString;if(!host.length)return NO;
 if([host isEqualToString:@"promoted.soundcloud.com"])return YES;
 if(![host isEqualToString:@"soundcloud.com"]&&![host hasSuffix:@".soundcloud.com"])return NO;
 NSString *path=url.path;return [path isEqualToString:@"/ads"]||[path hasPrefix:@"/ads/"];
}
@interface MYBSoundCloudAdProtocol:NSURLProtocol
@end
@implementation MYBSoundCloudAdProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request{return MYBSoundCloudRequestIsAd(request);}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{return request;}
- (void)startLoading{
 MYBAdsNoteDecisions(@"soundcloud",@"request",1);
 [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil]];
}
- (void)stopLoading{}
@end
// Sessions only consult the protocol classes in their own configuration, so ours is added to each (once).
static NSArray *hookProtocolClasses(id self_,SEL _cmd){
 NSArray *classes=origProtocolClasses?((NSArray *(*)(id,SEL))origProtocolClasses)(self_,_cmd):nil;
 if(![classes isKindOfClass:NSArray.class])classes=@[];
 if([classes containsObject:MYBSoundCloudAdProtocol.class])return classes;
 return [@[MYBSoundCloudAdProtocol.class] arrayByAddingObjectsFromArray:classes];
}
// The original answer tells whether the app was about to request ads; only then is a decision counted.
static BOOL answer(IMP original,id self_,SEL _cmd){
 BOOL wanted=original?((BOOL(*)(id,SEL))original)(self_,_cmd):NO;
 if(wanted)MYBAdsNoteDecisions(@"soundcloud",@"request",1);
 return NO;
}
static BOOL answerPermit(id self_,SEL _cmd){return answer(origPermit,self_,_cmd);}
static BOOL answerBanner(id self_,SEL _cmd){return answer(origBanner,self_,_cmd);}
NSUInteger MYBSoundCloudInstallHooks(NSUInteger *attempted){
 NSUInteger ok=0;
 // Asked before any ad request: audio ads in the queue, banners and interstitials.
 if(MYBAdsHookNamed("_TtC10SoundCloud19AdsRequestPermitter","shouldRequestAds",NO,(IMP)answerPermit,&origPermit))ok++;
 // Banner slots on track, playlist, profile and search pages: not asked for, so no empty box is left.
 if(MYBAdsHookNamed("_TtC3Ads30DisplayAdBannerFeatureProvider","canRequestAdBanner",NO,(IMP)answerBanner,&origBanner))ok++;
 // Requests made through the shared session and older APIs, and through every session configuration.
 [NSURLProtocol registerClass:MYBSoundCloudAdProtocol.class];
 if(MYBAdsHookNamed("NSURLSessionConfiguration","protocolClasses",NO,(IMP)hookProtocolClasses,&origProtocolClasses))ok++;
 if(attempted)*attempted=3;return ok;
}
#ifndef MYB_INAPPADS_TESTING
// Started by the shared dispatcher (Companions/InAppAds/Dispatcher.m) only in this app's own process.
void MYBAdsRun_soundcloud(void){
 @autoreleasepool{
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:jbroot(MYB_ADS_PREFS_PATH)]?:[NSDictionary dictionaryWithContentsOfFile:MYB_ADS_PREFS_PATH];
  if(!MYBAdsModuleEnabled(prefs,@"soundcloud"))return;
  MYBAdsReportLoaded(@"soundcloud",@MYB_COMPONENT_VERSION);NSUInteger attempted=0,ok=MYBSoundCloudInstallHooks(&attempted);MYBAdsLogResult("soundcloud",ok,attempted);MYBAdsReportHooks(@"soundcloud",ok,attempted,0);
 }
}
#endif
