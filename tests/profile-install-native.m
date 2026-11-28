// Profile installation core: staging through a connection object, error handling, status read-back, pending-record rules.
// Stand-in connection classes prove the module's own logic and its refusal to call a method whose shape it does not recognise.
// They do NOT prove the real MCProfileConnection on iOS 16.5.1 has these methods or accepts these calls.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include "../Shared/MYBProfileInstall.h"
static int failures=0;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)

static NSData *Profile(NSString *identifier){
 NSDictionary *d=@{@"PayloadType":@"Configuration",@"PayloadVersion":@1,@"PayloadUUID":@"11111111-2222-3333-4444-555555555555",@"PayloadIdentifier":identifier,@"PayloadContent":@[]};
 return [NSPropertyListSerialization dataWithPropertyList:d format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
}

// Installed-profile stand-ins: a profile object that can say its UUID, one that cannot, and a connection that returns them by identifier.
@interface FakeProfile:NSObject @property(copy) NSString *uuidText;@end
@implementation FakeProfile
- (NSString *)UUID{return self.uuidText;}
@end
@interface NoUUIDProfile:NSObject @end
@implementation NoUUIDProfile @end
@interface PayloadConn:NSObject @property id profile;@property(strong) NSData *data;@end
@implementation PayloadConn
- (id)installedProfileWithIdentifier:(NSString *)i{return [i isEqual:@"net.myxxdev.mybloxx"]?self.profile:nil;}
- (id)installedProfileDataWithIdentifier:(NSString *)i{return [i isEqual:@"net.myxxdev.mybloxx"]?self.data:nil;}
@end
@interface ProfConn:NSObject @property id profile;@end
@implementation ProfConn
- (id)installedProfileWithIdentifier:(NSString *)i{return [i isEqual:@"net.myxxdev.mybloxx"]?self.profile:nil;}
@end
static NSData *ProfileWith(NSString *identifier,NSString *uuid,NSString *extra){
 NSDictionary *d=@{@"PayloadType":@"Configuration",@"PayloadVersion":@1,@"PayloadUUID":uuid,@"PayloadIdentifier":identifier,@"PayloadDisplayName":extra?:@"x",@"PayloadContent":@[]};
 return [NSPropertyListSerialization dataWithPropertyList:d format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
}
static int calls;static id lastData;static id lastName;
// File-style staging that returns an object and fills the error pointer.
@interface FileConn:NSObject @property NSError *toFail;@property BOOL returnNil;@end
@implementation FileConn
- (id)queueFileDataForProfileInstallation:(NSData *)d originalFileName:(NSString *)n outError:(NSError **)e{calls++;lastData=d;lastName=n;if(self.toFail){if(e)*e=self.toFail;return nil;}return self.returnNil?nil:@"queued";}
- (id)installedProfileWithIdentifier:(NSString *)i{return [i isEqual:@"net.myxxdev.test.installed"]?@"profile":nil;}
@end
// Data-style fallback returning an object (the documented shape).
@interface DataConn:NSObject @end
@implementation DataConn
- (id)queueProfileDataForInstallation:(NSData *)d outError:(NSError **)e{calls++;lastData=d;return @"queued";}
@end
// Shapes whose result cannot be judged: void, BOOL and char returns. They must never be called.
@interface VoidConn:NSObject @end
@implementation VoidConn
- (void)queueFileDataForProfileInstallation:(NSData *)d originalFileName:(NSString *)n outError:(NSError **)e{calls++;}
@end
@interface BoolConn:NSObject @property BOOL answer;@end
@implementation BoolConn
- (BOOL)queueFileDataForProfileInstallation:(NSData *)d originalFileName:(NSString *)n outError:(NSError **)e{calls++;return self.answer;}
@end
@interface CharConn:NSObject @end
@implementation CharConn
- (char)queueProfileDataForInstallation:(NSData *)d outError:(NSError **)e{calls++;return 1;}
@end
// A connection that can peek at Apple's queue without removing anything (stands in for a method verified on a device).
@interface PeekConn:FileConn @property id waiting;@end
@implementation PeekConn
- (id)peekWaitingProfile{return self.waiting;}
@end
// A shape that must be refused: wrong arity and a return type that is not accepted.
@interface WrongConn:NSObject @end
@implementation WrongConn
- (int)queueFileDataForProfileInstallation:(NSData *)d originalFileName:(NSString *)n outError:(NSError **)e{calls++;return 1;}
- (id)queueProfileDataForInstallation:(NSData *)d{calls++;return @"x";}
- (int)installedProfileWithIdentifier:(NSString *)i{return 1;}
@end
// The error argument declared as an object (as some header dumps print it): called with no error pointer.
@interface ObjErrConn:NSObject @end
@implementation ObjErrConn
- (id)queueFileDataForProfileInstallation:(NSData *)d originalFileName:(NSString *)n outError:(id)e{calls++;return @"queued";}
@end

// The staging calls under test, with the waiting-profile decision made (replace chosen), so these checks are about the call itself.

// ---- the additional stage routes: Settings-side acceptance, the iOS 16 asynchronous interface, and the asynchronous peek --------------------
static NSString *lastBundle;static int lastTransition;
@interface AcceptConn:NSObject @property NSError *toFail;@end
@implementation AcceptConn
- (id)queueFileDataForAcceptance:(NSData *)d originalFileName:(NSString *)n forBundleID:(NSString *)b outError:(NSError **)e{calls++;lastData=d;lastName=n;lastBundle=b;if(self.toFail){if(e)*e=self.toFail;return nil;}return @"queued";}
@end
@interface AcceptThenFileConn:FileConn @property NSError *acceptFail;@end
@implementation AcceptThenFileConn
- (id)queueFileDataForAcceptance:(NSData *)d originalFileName:(NSString *)n outError:(NSError **)e{calls++;if(self.acceptFail){if(e)*e=self.acceptFail;return nil;}return @"queued";}
@end
@interface AsyncConn:NSObject @property NSError *toFail;@end
@implementation AsyncConn
- (void)queueProfileDataForInstallation:(NSData *)d originalFileName:(NSString *)n originatingBundleID:(NSString *)b transitionToUI:(BOOL)t completion:(void(^)(NSString *,unsigned long long,NSError *))c{
 calls++;lastData=d;lastBundle=b;lastTransition=t?1:0;NSError *err=self.toFail;dispatch_async(dispatch_get_global_queue(0,0),^{c(@"x",0,err);});}
@end
@interface PeekAsyncConn:FileConn @property NSData *waiting;@property NSError *peekError;@end
@implementation PeekAsyncConn
- (void)peekProfileDataFromPurgatoryForDeviceType:(unsigned long long)t withCompletion:(void(^)(NSData *,NSError *))c{NSData *w=self.waiting;NSError *e=self.peekError;dispatch_async(dispatch_get_global_queue(0,0),^{c(w,e);});}
@end
@interface UIDirectConn:AcceptConn @property NSError *uiFail;@end
@implementation UIDirectConn
- (id)_queueDataForAcceptance:(NSData *)d originalFileName:(NSString *)n originatingBundleID:(NSString *)b transitionToUI:(BOOL)t outError:(NSError **)e{calls++;lastData=d;lastBundle=b;lastTransition=t?1:0;if(self.uiFail){if(e)*e=self.uiFail;return nil;}return @"x";}
@end
@interface PeekSyncConn:FileConn @property id waiting;@end
@implementation PeekSyncConn
- (id)peekProfileDataFromPurgatoryForDeviceType:(unsigned long long)t{return self.waiting;}
@end
static NSDictionary *S(id c,NSData *d,NSString *n){return MYBProfileStageWithPeek(c,d,n,YES,@[]);}

int main(void){@autoreleasepool{
 NSData *good=Profile(@"net.myxxdev.test.installed");
 REQUIRE([MYBProfileIdentifier(good) isEqual:@"net.myxxdev.test.installed"],"identifier is read from a profile");
 REQUIRE(!MYBProfileIdentifier(nil)&&!MYBProfileIdentifier([@"not a plist" dataUsingEncoding:NSUTF8StringEncoding]),"damaged data has no identifier");
 NSData *notProfile=[NSPropertyListSerialization dataWithPropertyList:@{@"PayloadType":@"Other",@"PayloadIdentifier":@"x"} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
 REQUIRE(!MYBProfileIdentifier(notProfile),"a plist that is not a Configuration profile is refused");

 FileConn *file=[FileConn new];calls=0;
 NSDictionary *r=S(file,good,@"X.mobileconfig");
 REQUIRE([r[@"state"] isEqual:@"staged"]&&calls==1&&[lastData isEqual:good]&&[lastName isEqual:@"X.mobileconfig"],"file-style staging is called with the file data and name");
 file.toFail=[NSError errorWithDomain:@"MCProfileErrorDomain" code:4001 userInfo:@{NSLocalizedDescriptionKey:@"Profile installation is restricted on this device"}];
 r=S(file,good,nil);
 REQUIRE([r[@"state"] isEqual:@"restricted"]&&[r[@"errorCode"] intValue]==4001,"a restriction error is reported as restricted");
 file.toFail=[NSError errorWithDomain:@"MCProfileErrorDomain" code:1000 userInfo:@{NSLocalizedDescriptionKey:@"Invalid profile"}];
 r=S(file,good,nil);
 REQUIRE([r[@"state"] isEqual:@"failed"]&&[r[@"errorDomain"] isEqual:@"MCProfileErrorDomain"],"another error is reported as failed with its domain and code");
 file.toFail=nil;file.returnNil=YES;
 REQUIRE([S(file,good,nil)[@"state"] isEqual:@"failed"],"a nil result without an error is not success");
 file.returnNil=NO;

 calls=0;
 REQUIRE([S([DataConn new],good,nil)[@"state"] isEqual:@"staged"]&&calls==1,"the data-style method is used when the file-style one is absent");
 calls=0;
 REQUIRE([S([ObjErrConn new],good,nil)[@"state"] isEqual:@"staged"]&&calls==1,"an error argument declared as an object is accepted");
 calls=0;
 r=S([WrongConn new],good,nil);
 REQUIRE([r[@"state"] isEqual:@"unavailable"]&&calls==0,"methods with an unrecognised shape are never called");
 REQUIRE([S(nil,good,nil)[@"state"] isEqual:@"unavailable"],"no connection means unavailable");
 calls=0;
 REQUIRE([S(file,[@"junk" dataUsingEncoding:NSUTF8StringEncoding],nil)[@"state"] isEqual:@"invalid"]&&calls==0,"an invalid profile is not handed to iOS");

 // ---- documented object-returning shapes only: void, BOOL and char interfaces are never called and never reported as staged
 calls=0;
 REQUIRE([S([VoidConn new],good,nil)[@"state"] isEqual:@"unavailable"]&&calls==0,"a void-returning stage method is refused: absence of an error proves nothing");
 BoolConn *yes=[BoolConn new];yes.answer=YES;BoolConn *no=[BoolConn new];no.answer=NO;
 REQUIRE([S(yes,good,nil)[@"state"] isEqual:@"unavailable"]&&[S(no,good,nil)[@"state"] isEqual:@"unavailable"]&&calls==0,"a BOOL-returning method is refused whatever it would answer, so a false result can never become staged");
 REQUIRE([S([CharConn new],good,nil)[@"state"] isEqual:@"unavailable"]&&calls==0,"a char-returning method is refused");
 REQUIRE(!MYBProfileEncodingOK(@"v@:@@^@",3)&&!MYBProfileEncodingOK(@"B@:@@^@",3)&&!MYBProfileEncodingOK(@"c@:@^@",2)&&MYBProfileEncodingOK(@"@@:@@^@",3)&&MYBProfileEncodingOK(@"@@:@^@",2)&&!MYBProfileEncodingOK(@"@@:@@^@",2),"only the object-returning shapes of the right arity are accepted");
 // a successful stage is accepted, not confirmed
 NSDictionary *ok=S(file,good,@"X.mobileconfig");
 REQUIRE([ok[@"state"] isEqual:@"staged"]&&[ok[@"confirmed"] isEqual:@NO],"success is reported as accepted by iOS and explicitly unconfirmed");
 // ---- a waiting profile is detected before staging and never replaced without an explicit choice
 PeekConn *peek=[PeekConn new];calls=0;
 NSArray *peekNames=@[@"peekWaitingProfile"];
 REQUIRE([MYBProfilePendingStateWith(peek,peekNames) isEqual:@"none"],"a verified peek that finds nothing means the queue is empty");
 peek.waiting=@"someone-elses-profile";
 REQUIRE([MYBProfilePendingStateWith(peek,peekNames) isEqual:@"other"],"a verified peek that finds a profile means another is waiting");
 r=MYBProfileStageWithPeek(peek,good,nil,NO,peekNames);
 REQUIRE([r[@"state"] isEqual:@"pendingother"]&&calls==0,"another waiting profile stops staging before anything is handed to iOS");
 r=MYBProfileStageWithPeek(peek,good,nil,YES,peekNames);
 REQUIRE([r[@"state"] isEqual:@"staged"]&&calls==1,"only an explicit replace choice stages over a waiting profile");
 peek.waiting=nil;calls=0;
 REQUIRE([MYBProfileStageWithPeek(peek,good,nil,NO,peekNames)[@"state"] isEqual:@"staged"]&&calls==1,"an empty queue stages without asking");
 // no verified peek: the queue state is unknown, which also stops staging; the local record is never evidence of an empty queue
 calls=0;
 REQUIRE([MYBProfilePendingStateWith(file,@[]) isEqual:@"unknown"]&&[MYBProfilePendingStateWith(nil,peekNames) isEqual:@"unknown"],"without a verified peek the queue state is unknown");
 REQUIRE([MYBProfileStage(file,good,nil,NO)[@"state"] isEqual:@"pendingunknown"]&&calls==0,"an unknown queue stops staging until the person chooses");
 REQUIRE([MYBProfileStage(file,good,nil,YES)[@"state"] isEqual:@"staged"]&&calls==1,"the explicit choice stages");
 REQUIRE([MYBProfileVerifiedPeekSelectors() count]==0,"no peek is claimed as verified, and the destructive pop is never listed");
 // a method with the right name but the wrong shape is not used as a peek
 calls=0;REQUIRE([MYBProfilePendingStateWith([WrongConn new],@[@"queueFileDataForProfileInstallation:originalFileName:outError:"]) isEqual:@"unknown"]&&calls==0,"a peek with an unexpected shape is not called");

 // installed state
 REQUIRE([MYBProfileInstalledState(file,@"net.myxxdev.test.installed") isEqual:@"installed"],"installed is read back from iOS");
 REQUIRE([MYBProfileInstalledState(file,@"net.myxxdev.test.other") isEqual:@"notinstalled"],"an absent profile is not installed");
 REQUIRE([MYBProfileInstalledState([WrongConn new],@"x") isEqual:@"unknown"]&&[MYBProfileInstalledState(nil,@"x") isEqual:@"unknown"]&&[MYBProfileInstalledState(file,@"") isEqual:@"unknown"],"an unverifiable check is unknown, not not-installed");
 REQUIRE([MYBProfileStatusLabel(@"matched") isEqual:@"Installed, Contents Not Checked"]&&![[MYBProfileStatusLabel(@"matched") lowercaseString] isEqual:@"installed"]&&[MYBProfileStatusLabel(@"installed") isEqual:@"Installed"]&&[MYBProfileStatusLabel(@"notinstalled") isEqual:@"Not Installed"]&&[MYBProfileStatusLabel(@"unknown") isEqual:@"Unable to Check"]&&[MYBProfileStatusLabel(nil) isEqual:@"Unable to Check"],"status labels");
 REQUIRE(![[MYBProfileStatusLabel(@"staged") lowercaseString] containsString:@"installed"]||[MYBProfileStatusLabel(@"staged") isEqual:@"Unable to Check"],"a staged profile is never labelled Installed");

 // ---- which profile is installed: identifier AND PayloadUUID AND the bundled file that was staged (six Legacy profiles share one identifier)
 {
  NSData *def=ProfileWith(@"net.myxxdev.mybloxx",@"FD9913A0-D24B-4C09-93B0-D3F4066D8E79",@"Default");
  NSData *noApple=ProfileWith(@"net.myxxdev.mybloxx",@"9DB9ED54-D401-4CE1-880D-F669E6155EBA",@"noApple");
  NSDictionary *di=MYBProfileInfo(def),*ni=MYBProfileInfo(noApple);
  REQUIRE(di&&ni&&[di[@"identifier"] isEqual:ni[@"identifier"]]&&![di[@"key"] isEqual:ni[@"key"]]&&[di[@"key"] isEqual:@"net.myxxdev.mybloxx|FD9913A0-D24B-4C09-93B0-D3F4066D8E79"],"profiles that share an identifier have different keys");
  REQUIRE(MYBProfileInfo([@"junk" dataUsingEncoding:NSUTF8StringEncoding])==nil&&MYBProfileInfo(ProfileWith(@"net.myxxdev.mybloxx",@"not-a-uuid",nil))==nil,"a profile without a valid PayloadUUID has no identity");
  REQUIRE([di[@"digest"] length]==64&&![di[@"digest"] isEqual:ni[@"digest"]],"the digest is a SHA-256 of the file");
  FakeProfile *held=[FakeProfile new];held.uuidText=@"fd9913a0-d24b-4c09-93b0-d3f4066d8e79"; // lower case from iOS still matches
  ProfConn *conn=[ProfConn new];conn.profile=held;
  REQUIRE([MYBProfileInstalledStateFor(conn,di,di[@"digest"]) isEqual:@"matched"],"same identifier, same UUID and the submitted file is this file: matched (identity observed, submission recorded), NOT verified installed");
  REQUIRE([MYBProfileInstalledStateFor(conn,ni,ni[@"digest"]) isEqual:@"different"],"same identifier but another profile's UUID is NOT the requested profile");
  REQUIRE([MYBProfileInstalledStateFor(conn,di,@"0000000000000000000000000000000000000000000000000000000000000000") isEqual:@"different"],"same UUID but the staged file is not the current bundled file: different version");
  REQUIRE([MYBProfileInstalledStateFor(conn,di,nil) isEqual:@"unverified"]&&[MYBProfileInstalledStateFor(conn,di,@"") isEqual:@"unverified"],"same UUID with nothing tying it to the current file is not confirmed");
  conn.profile=[NoUUIDProfile new];
  REQUIRE([MYBProfileInstalledStateFor(conn,di,di[@"digest"]) isEqual:@"unverified"],"an installed profile whose UUID cannot be read is not counted as the requested one");
  FakeProfile *empty=[FakeProfile new];conn.profile=empty;
  REQUIRE([MYBProfileInstalledStateFor(conn,di,di[@"digest"]) isEqual:@"unverified"],"an empty UUID is not confirmation");
  conn.profile=nil;REQUIRE([MYBProfileInstalledStateFor(conn,di,di[@"digest"]) isEqual:@"notinstalled"],"nothing installed under the identifier");
  REQUIRE([MYBProfileInstalledStateFor([WrongConn new],di,di[@"digest"]) isEqual:@"unknown"]&&[MYBProfileInstalledStateFor(nil,di,nil) isEqual:@"unknown"],"an unanswerable lookup is unknown");
  REQUIRE([MYBProfileStatusLabel(@"matched") isEqual:@"Installed, Contents Not Checked"]&&![[MYBProfileStatusLabel(@"matched") lowercaseString] isEqual:@"installed"]&&[MYBProfileStatusLabel(@"installed") isEqual:@"Installed"]&&[MYBProfileStatusLabel(@"different") isEqual:@"Different Version Installed"]&&[MYBProfileStatusLabel(@"unverified") isEqual:@"Installed, Not Verified"],"labels keep installed, different and not-verified apart");

  // ---- installed payload: the strongest claim needs the installed data to be read and compared -------------------------------------
  {
   NSDictionary *bundledDict=@{@"PayloadType":@"Configuration",@"PayloadVersion":@1,@"PayloadUUID":@"FD9913A0-D24B-4C09-93B0-D3F4066D8E79",@"PayloadIdentifier":@"net.myxxdev.mybloxx",@"PayloadDisplayName":@"Default",
    @"PayloadContent":@[@{@"PayloadType":@"com.apple.proxy.http.global",@"PayloadUUID":@"F0A95878-A788-4CD4-AC31-42EDDB342D63",@"PayloadIdentifier":@"x.1",@"ProxyType":@"Auto",@"ProxyPACURL":@"http://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/Default.pac"}]};
   NSData *bundled=[NSPropertyListSerialization dataWithPropertyList:bundledDict format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
   NSDictionary *bi=MYBProfileInfo(bundled);
   FakeProfile *held=[FakeProfile new];held.uuidText=@"FD9913A0-D24B-4C09-93B0-D3F4066D8E79";
   PayloadConn *dc=[PayloadConn new];dc.profile=held;
   // installed data = same contents plus keys iOS added itself
   NSMutableDictionary *same=[bundledDict mutableCopy];same[@"PayloadOrganization"]=@"MYXXdev";NSMutableDictionary *pl=[bundledDict[@"PayloadContent"][0] mutableCopy];pl[@"PayloadVersion"]=@1;same[@"PayloadContent"]=@[pl];
   dc.data=[NSPropertyListSerialization dataWithPropertyList:same format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
   REQUIRE([MYBProfilePayloadVerdict(dc,@"net.myxxdev.mybloxx",bundled) isEqual:@"same"],"installed contents that cover the bundled profile (extra keys ignored) are the same");
   REQUIRE([MYBProfileVerifiedStateFor(dc,bi,bi[@"digest"],bundled) isEqual:@"installed"],"a verified payload is Installed");
   REQUIRE([MYBProfileVerifiedStateFor(dc,bi,nil,bundled) isEqual:@"installed"],"a verified payload is Installed even when MYbloXX never submitted it (installed from Files)");
   // SAME identifier and UUID, DIFFERENT contents: identity matches, contents do not
   NSMutableDictionary *swapped=[bundledDict mutableCopy];NSMutableDictionary *evil=[bundledDict[@"PayloadContent"][0] mutableCopy];evil[@"ProxyPACURL"]=@"https://evil.example/x.pac";swapped[@"PayloadContent"]=@[evil];
   dc.data=[NSPropertyListSerialization dataWithPropertyList:swapped format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
   REQUIRE([MYBProfileInstalledStateFor(dc,bi,bi[@"digest"]) isEqual:@"matched"],"identity alone cannot tell a replacement with the same identifier and UUID apart");
   REQUIRE([MYBProfilePayloadVerdict(dc,@"net.myxxdev.mybloxx",bundled) isEqual:@"different"]&&[MYBProfileVerifiedStateFor(dc,bi,bi[@"digest"],bundled) isEqual:@"different"],"same identifier and UUID but different contents is Different Version Installed when the data is readable");
   NSMutableDictionary *fewer=[bundledDict mutableCopy];fewer[@"PayloadContent"]=@[];dc.data=[NSPropertyListSerialization dataWithPropertyList:fewer format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
   REQUIRE([MYBProfilePayloadVerdict(dc,@"net.myxxdev.mybloxx",bundled) isEqual:@"different"],"a different number of payloads is different");
   // data not handed out: the identity state stays exactly as it was and is never upgraded
   dc.data=nil;REQUIRE([MYBProfilePayloadVerdict(dc,@"net.myxxdev.mybloxx",bundled) isEqual:@"unreadable"]&&[MYBProfileVerifiedStateFor(dc,bi,bi[@"digest"],bundled) isEqual:@"matched"],"unreadable data never upgrades the claim");
   REQUIRE([MYBProfileVerifiedStateFor(dc,bi,nil,bundled) isEqual:@"unverified"],"identity match with no submission and no readable data stays Not Verified");
   dc.data=(NSData *)@"not data";REQUIRE([MYBProfilePayloadVerdict(dc,@"net.myxxdev.mybloxx",bundled) isEqual:@"unreadable"],"a non-data answer is unreadable");
   REQUIRE([MYBProfilePayloadVerdict(nil,@"x",bundled) isEqual:@"unreadable"]&&[MYBProfilePayloadVerdict(dc,@"net.myxxdev.mybloxx",[@"junk" dataUsingEncoding:NSUTF8StringEncoding]) isEqual:@"unreadable"],"no service or an unreadable bundled file is unreadable");
   REQUIRE([MYBProfileStateExplanation(@"matched") containsString:@"did not"]||[MYBProfileStateExplanation(@"matched") containsString:@"would not"],"the explanation says the contents were not compared");
  }
  // accepted, not confirmed is its own label, only for the same profile, only while fresh, and never over a confirmed install
  NSDictionary *rec=@{@"state":@"staged",@"at":@(1000),@"key":di[@"key"]};
  REQUIRE([MYBProfileDisplayLabel(@"notinstalled",rec,di[@"key"],1100) isEqual:@"Accepted, Not Confirmed"]&&[MYBProfileDisplayLabel(@"different",rec,di[@"key"],1100) isEqual:@"Accepted, Not Confirmed"],"a freshly staged profile that is not yet installed shows Accepted, Not Confirmed");
  REQUIRE([MYBProfileDisplayLabel(@"notinstalled",rec,ni[@"key"],1100) isEqual:@"Not Installed"],"another profile with the same identifier does not inherit the staged state");
  REQUIRE([MYBProfileDisplayLabel(@"installed",rec,di[@"key"],1100) isEqual:@"Installed"],"a verified install is shown as Installed");
  REQUIRE([MYBProfileDisplayLabel(@"matched",rec,di[@"key"],1100) isEqual:@"Installed, Contents Not Checked"],"an identity match is never relabelled Accepted, Not Confirmed while fresh, and never shown as plain Installed");
  REQUIRE([MYBProfileDisplayLabel(@"notinstalled",rec,di[@"key"],1000+MYB_PROFILE_PENDING_SECONDS+1) isEqual:@"Not Installed"],"a stale staged record no longer shows");
  REQUIRE(![[MYBProfileDisplayLabel(@"notinstalled",rec,di[@"key"],1100) lowercaseString] isEqual:@"installed"],"accepted is never labelled Installed");
 }

 // pending record
 NSTimeInterval now=10000;
 REQUIRE(MYBProfilePendingFresh(@{@"state":@"staged",@"at":@(now-60)},now),"a recent staged record is pending");
 REQUIRE(!MYBProfilePendingFresh(@{@"state":@"staged",@"at":@(now-MYB_PROFILE_PENDING_SECONDS-1)},now),"an expired record is forgotten");
 REQUIRE(!MYBProfilePendingFresh(@{@"state":@"failed",@"at":@(now-1)},now)&&!MYBProfilePendingFresh(@{@"state":@"installed",@"at":@(now-1)},now)&&!MYBProfilePendingFresh(nil,now)&&!MYBProfilePendingFresh(@{@"state":@"staged",@"at":@(now+500)},now),"only a fresh staged record counts");
 NSArray *urls=MYBProfileInstallerURLs();
 REQUIRE(urls.count==2&&[urls.firstObject hasPrefix:@"prefs:"]&&[urls.lastObject hasSuffix:@"ManagedConfigurationList"],"the profile page is tried first, Device Management second");

 // Settings-side acceptance: the bundle-id variant is preferred and called once with the data, the name and the bundle id; it is an argument, not a permission
 {calls=0;AcceptConn *a=[AcceptConn new];NSDictionary *q=S(a,good,@"A.mobileconfig");
  REQUIRE([q[@"state"] isEqual:@"staged"]&&calls==1&&[lastBundle isEqual:@"com.apple.Preferences"]&&[lastName isEqual:@"A.mobileconfig"]&&[q[@"route"] isEqual:@"acceptBundle"],"the Settings-side acceptance route (with bundle id) stages through its exact shape");
  a.toFail=[NSError errorWithDomain:@"MCXPCErrorDomain" code:39000 userInfo:@{NSLocalizedDescriptionKey:@"Calling process lacks 'com.apple.managedconfiguration.profiled-access' entitlement"}];
  q=S(a,good,nil);
  REQUIRE([q[@"state"] isEqual:@"failed"]&&[q[@"category"] isEqual:@"denied"]&&[q[@"errorCode"] intValue]==39000&&[q[@"errorText"] length],"a service permission refusal is reported as denied with its domain, code and text");
  NSDictionary *m=MYBProfileFailureMessage(q,@"Settings component");
  REQUIRE([m[@"title"] isEqual:@"iOS Denied Access to the Profile Service"]&&![[m[@"detail"] lowercaseString] containsString:@"ios version"],"a denial is explained as a denial, never as an unsupported iOS version");}
 // a route that errors is followed by the next matching route; every attempt is recorded; nothing is retried on success
 {calls=0;AcceptThenFileConn *c=[AcceptThenFileConn new];c.acceptFail=[NSError errorWithDomain:@"X" code:7 userInfo:@{NSLocalizedDescriptionKey:@"no"}];
  NSDictionary *q=S(c,good,@"B.mobileconfig");
  REQUIRE([q[@"state"] isEqual:@"staged"]&&calls==2&&[q[@"attempts"] containsString:@"accept:error"]&&[q[@"attempts"] containsString:@"fileInstall:ok"],"a failed route falls through to the next matching route, and the attempts are recorded");
  c.acceptFail=nil;calls=0;q=S(c,good,nil);
  REQUIRE([q[@"state"] isEqual:@"staged"]&&calls==1&&[q[@"route"] isEqual:@"accept"],"the first route that is accepted ends the attempts");}
 // iOS 16 asynchronous interface: called only on its exact shape, with transitionToUI NO (MYbloXX opens Apple's screen itself)
 {calls=0;AsyncConn *a=[AsyncConn new];NSDictionary *q=S(a,good,@"C.mobileconfig");
  REQUIRE([q[@"state"] isEqual:@"staged"]&&calls==1&&lastTransition==0&&[q[@"route"] isEqual:@"async"],"the asynchronous interface stages with transitionToUI NO and waits for its completion");
  a.toFail=[NSError errorWithDomain:@"MCProfileErrorDomain" code:1000 userInfo:@{NSLocalizedDescriptionKey:@"Invalid profile"}];calls=0;q=S(a,good,nil);
  REQUIRE([q[@"state"] isEqual:@"failed"]&&[q[@"category"] isEqual:@"error"]&&[q[@"errorCode"] intValue]==1000,"an error delivered to the completion is a failure with its code");}
 // the asynchronous peek: non-destructive, called only on its exact shape, identical waiting data is not "another" profile
 {NSData *other=Profile(@"net.myxxdev.test.other");PeekAsyncConn *p=[PeekAsyncConn new];
  REQUIRE([MYBProfilePendingStateOurs(p,@[],good) isEqual:@"none"],"an empty purgatory means no other profile is waiting");
  p.waiting=other;REQUIRE([MYBProfilePendingStateOurs(p,@[],good) isEqual:@"other"],"a different waiting profile is reported as another profile");
  p.waiting=good;REQUIRE([MYBProfilePendingStateOurs(p,@[],good) isEqual:@"none"],"the same waiting data is not another profile");
  p.waiting=nil;p.peekError=[NSError errorWithDomain:@"X" code:1 userInfo:nil];REQUIRE([MYBProfilePendingStateOurs(p,@[],good) isEqual:@"unknown"],"a peek error means unknown, never none");
  p.peekError=nil;p.waiting=other;calls=0;REQUIRE([MYBProfileStage(p,good,nil,NO)[@"state"] isEqual:@"pendingother"]&&calls==0,"a waiting profile stops staging before anything is handed to iOS");
  p.waiting=nil;calls=0;REQUIRE([MYBProfileStage(p,good,nil,NO)[@"state"] isEqual:@"staged"]&&calls==1,"an empty purgatory stages without asking");}
 // failure categories before any call
 {NSDictionary *q=S(nil,good,nil);REQUIRE([q[@"state"] isEqual:@"unavailable"]&&[q[@"category"] isEqual:@"noservice"],"no connection is the noservice category");
  calls=0;q=S([WrongConn new],good,nil);REQUIRE([q[@"state"] isEqual:@"unavailable"]&&[q[@"category"] isEqual:@"noroute"]&&[q[@"api"] length]&&calls==0,"no matching shape is the noroute category, lists the shapes, and calls nothing");
  for(NSString *c in @[@"noservice",@"noroute",@"denied",@"restricted",@"error",@"nilresult",@"timeout"])REQUIRE(![[MYBProfileFailureMessage(@{@"category":c},@"helper")[@"detail"] lowercaseString] containsString:@"ios version"],"no failure category is blamed on the iOS version");}

 // direct-to-UI route: asks the service to go to the install screen (transitionToUI YES); a failure falls through to the acceptance route
 {calls=0;UIDirectConn *u=[UIDirectConn new];NSDictionary *q=S(u,good,@"D.mobileconfig");
  REQUIRE([q[@"state"] isEqual:@"staged"]&&calls==1&&lastTransition==1&&[lastBundle isEqual:@"com.apple.Preferences"]&&[q[@"route"] isEqual:@"uiDirect"],"the direct-to-UI route is tried first, with transitionToUI YES");
  u.uiFail=[NSError errorWithDomain:@"MCXPCErrorDomain" code:39000 userInfo:@{NSLocalizedDescriptionKey:@"denied"}];calls=0;q=S(u,good,nil);
  REQUIRE([q[@"state"] isEqual:@"staged"]&&calls==2&&[q[@"attempts"] containsString:@"uiDirect:denied"]&&[q[@"route"] isEqual:@"acceptBundle"],"a refused direct-to-UI call falls back to the acceptance route");}
 // the synchronous peek
 {NSData *other=Profile(@"net.myxxdev.test.other");PeekSyncConn *p=[PeekSyncConn new];
  REQUIRE([MYBProfilePendingStateOurs(p,@[],good) isEqual:@"none"],"a sync peek with nothing waiting means none");
  p.waiting=other;REQUIRE([MYBProfilePendingStateOurs(p,@[],good) isEqual:@"other"],"a different waiting profile is another profile");
  p.waiting=good;REQUIRE([MYBProfilePendingStateOurs(p,@[],good) isEqual:@"none"],"identical waiting data is not another profile");
  p.waiting=@"not data";REQUIRE([MYBProfilePendingStateOurs(p,@[],good) isEqual:@"unknown"],"an unexpected answer is unknown, never none");}
 if(failures)return 1;printf("Profile installation core checks passed.\n");return 0;}}
