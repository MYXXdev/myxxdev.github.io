#import <WebKit/WebKit.h>
#import "../Shared/MYBLoopback.h"
#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBWeb.h"
#import "../Shared/MYBProfileInstall.h"
#import <dlfcn.h>

@interface MYBWebController () <WKNavigationDelegate>
@property(nonatomic,strong) NSURL *url;
@property(nonatomic,copy) NSString *note;
@property(nonatomic,strong) WKWebView *web;
@property(nonatomic,strong) UIProgressView *progress;
@property(nonatomic,strong) UILabel *noteLabel;
@property(nonatomic,strong) UILabel *failure;
@end
@implementation MYBWebController
- (instancetype)initWithURL:(NSURL *)url title:(NSString *)title note:(NSString *)note{
 if((self=[super init])){_url=url;_note=[note copy];self.title=title;}
 return self;
}
- (void)viewDidLoad{
 [super viewDidLoad];
 self.view.backgroundColor=MYBBackground();MYBStyleNavigation(self);
 UILabel *note=nil;
 if(self.note.length){
  note=[UILabel new];note.translatesAutoresizingMaskIntoConstraints=NO;note.numberOfLines=0;note.font=MYBFont(13,UIFontWeightRegular);note.textColor=MYBMuted();note.text=self.note;
  [self.view addSubview:note];self.noteLabel=note;
 }
 WKWebViewConfiguration *config=[WKWebViewConfiguration new];config.websiteDataStore=[WKWebsiteDataStore nonPersistentDataStore];
 self.web=[[WKWebView alloc] initWithFrame:CGRectZero configuration:config];self.web.translatesAutoresizingMaskIntoConstraints=NO;self.web.navigationDelegate=self;
 self.web.opaque=NO;self.web.backgroundColor=MYBBackground();self.web.scrollView.backgroundColor=MYBBackground();
 [self.view addSubview:self.web];
 self.progress=[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];self.progress.translatesAutoresizingMaskIntoConstraints=NO;self.progress.progressTintColor=MYBAccent();self.progress.trackTintColor=UIColor.clearColor;
 [self.view addSubview:self.progress];
 self.failure=[UILabel new];self.failure.translatesAutoresizingMaskIntoConstraints=NO;self.failure.numberOfLines=0;self.failure.textAlignment=NSTextAlignmentCenter;self.failure.font=MYBFont(15,UIFontWeightRegular);self.failure.textColor=MYBMuted();self.failure.hidden=YES;
 [self.view addSubview:self.failure];
 UILayoutGuide *g=self.view.safeAreaLayoutGuide;
 NSMutableArray *c=[NSMutableArray arrayWithArray:@[
  [self.progress.topAnchor constraintEqualToAnchor:g.topAnchor],[self.progress.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.progress.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
  [self.web.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.web.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[self.web.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
  [self.failure.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[self.failure.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:MYBMargin],[self.failure.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-MYBMargin]]];
 if(note){[c addObjectsFromArray:@[[note.topAnchor constraintEqualToAnchor:g.topAnchor constant:8],[note.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:MYBMargin],[note.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-MYBMargin],[self.web.topAnchor constraintEqualToAnchor:note.bottomAnchor constant:8]]];}
 else [c addObject:[self.web.topAnchor constraintEqualToAnchor:g.topAnchor]];
 [NSLayoutConstraint activateConstraints:c];
 [self.web addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
 // The page is requested only now, because the person opened this screen.
 [self.web loadRequest:[NSURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20]];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
 if([keyPath isEqualToString:@"estimatedProgress"]){double p=self.web.estimatedProgress;self.progress.hidden=p>=1.0;self.progress.progress=(float)p;}
 else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
- (void)dealloc{@try{[self.web removeObserver:self forKeyPath:@"estimatedProgress"];}@catch(__unused id e){}}
- (void)openInBrowser{
 NSURL *url=self.web.URL?:self.url;
 MYBConfirmWithButton(self,@"Open in Browser?",[NSString stringWithFormat:@"%@ opens in your default browser.",url.host.length?url.host:@"This page"],@"Open",^{[UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];});
}
- (void)failed:(NSError *)error{
 if(error.code==NSURLErrorCancelled)return;
 self.failure.text=@"This page could not be loaded. Check your connection, then go back and try again.";self.failure.hidden=NO;self.web.hidden=YES;
}
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error{[self failed:error];}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{[self failed:error];}
@end

void MYBPushWeb(UIViewController *owner,NSString *urlString,NSString *title,NSString *note){
 NSURL *url=[NSURL URLWithString:urlString];NSString *scheme=url.scheme.lowercaseString;
 if(!url||!([scheme isEqual:@"https"]||([scheme isEqual:@"http"]&&[url.host isEqual:@"127.0.0.1"])))return;
 UIViewController *page=[[MYBWebController alloc] initWithURL:url title:title note:note];
 [owner.navigationController pushViewController:page animated:YES];
}

// ---- Configuration profile installation (one coordinator for DNS and Legacy profiles) -------------------------------
// The bundled profile is read from disk by the helper and queued with iOS’s own profile service (see Shared/MYBProfileInstall.h);
// only after that succeeds does this open Settings at the downloaded profile, where iOS shows its own review and Install steps.
// MYbloXX® never reports a profile as installed because it was staged or saved: Installed is read back from iOS by identifier.
// Fallbacks that always work: Save to Files, Copy Link (Legacy profiles have a published link), Open Device Management.
static BOOL MYBProfileBusy; // one staging at a time: repeated taps while a profile is being prepared are ignored

static void MYBSaveProfileToFiles(UIViewController *owner,NSString *folder,NSString *file,NSString *title){
 NSString *source=MYBPath([NSString stringWithFormat:@"/usr/share/mybloxx/%@/%@.mobileconfig",folder,file]);
 NSData *body=[NSData dataWithContentsOfFile:source];
 NSString *safe=[[title componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
 NSURL *copy=[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[@"MYbloXX-" stringByAppendingString:[(safe.length?safe:@"Profile") stringByAppendingString:@".mobileconfig"]]];
 if(!body.length||![body writeToURL:copy atomically:YES]){MYBMessage(owner,@"Profile Not Available",@"The profile file is missing from this install. Reinstall MYbloXX®, then try again.");return;}
 UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[copy] applicationActivities:nil];
 share.completionWithItemsHandler=^(__unused UIActivityType type,BOOL completed,__unused NSArray *items,__unused NSError *error){
  [NSFileManager.defaultManager removeItemAtURL:copy error:NULL];
  if(completed)MYBMessage(owner,@"Profile File Saved",@"Open the file from Files. If iOS shows Profile Downloaded, open Settings and choose Install. Saving a profile does not install it, and MYbloXX® cannot see whether you did.");
 };
 share.popoverPresentationController.sourceView=owner.view;
 [owner presentViewController:share animated:YES completion:nil];
}
// Opens Settings at the downloaded profile; tries each known page and stops at the first that opens.
static void MYBOpenInstaller(NSArray<NSString *> *urls,NSUInteger index,void(^done)(BOOL)){
 if(index>=urls.count){done(NO);return;}
 NSURL *url=[NSURL URLWithString:urls[index]];
 if(!url||![UIApplication.sharedApplication canOpenURL:url]){MYBOpenInstaller(urls,index+1,done);return;}
 [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL opened){if(opened)done(YES);else MYBOpenInstaller(urls,index+1,done);}];
}
static void MYBProfileFallbacks(UIViewController *owner,NSString *folder,NSString *file,NSString *title,NSString *link,NSString *reason){
 NSMutableArray *choices=[NSMutableArray arrayWithObject:@"Save Profile to Files"];
 if(link.length)[choices addObject:@"Copy Profile Link"];
 [choices addObject:@"Open Device Management"];
 MYBChoose(owner,reason,choices,^(NSUInteger index){
  NSString *choice=choices[index];
  if([choice isEqual:@"Copy Profile Link"]){
   UIPasteboard.generalPasteboard.string=link;
   MYBMessage(owner,@"Profile Link Copied",@"Paste the link into your browser and allow the download. Then open Settings and choose Install from the Profile Downloaded notice. Downloading a profile does not install it.");
  }else if([choice isEqual:@"Open Device Management"]){
   MYBOpenInstaller(@[@"prefs:root=General&path=ManagedConfigurationList"],0,^(BOOL opened){if(!opened)MYBMessage(owner,@"Open Settings Yourself",@"Open Settings, then General, then VPN & Device Management.");});
  }else MYBSaveProfileToFiles(owner,folder,file,title);
 });
}
// ---- Settings-process attempt --------------------------------------------------------------------------------------------------
// When the helper’s own attempt does not stage the profile, the same shared routine is run in THIS process (the Settings component). Which
// process iOS lets use the profile service is a device question, so both outcomes, the caller identity and the exact errors are recorded
// in the diagnostics file (Copy Profile Diagnostics). Nothing here assumes a bundle-id argument changes anyone’s permissions.
static NSString *MYBDiagFile(void){return MYBMobileFile(@"/var/mobile/Library/MYbloXX/ProfileDiagnostics.txt");}
static void MYBAppDiagNote(NSString *line){
 NSString *path=MYBDiagFile();if(!path.length||!line.length)return;
 NSString *old=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]?:@"";if(old.length>20000)old=[old substringFromIndex:old.length-12000];
 NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"yyyy-MM-dd HH:mm:ss";
 [[old stringByAppendingFormat:@"%@ %@\n",[f stringFromDate:NSDate.date],line] writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL]; // best effort
}
static NSDictionary *MYBHelperStageRecord(void){return [NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.profileinstall.plist")]?:@{};}
static void MYBStageInSettings(NSString *folder,NSString *file,BOOL replace,void(^done)(NSDictionary *result,NSDictionary *nav)){
 // Written BEFORE the service call: iOS posts its "Profile Downloaded" alert during that call, and the alert hook (MYBProfileAlert) only
 // shortens it while this marker is fresh, so profiles MYbloXX did not queue keep Apple’s alert untouched.
 [@{@"at":@([[NSDate date] timeIntervalSince1970])} writeToFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.profilealert.plist") atomically:YES];
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSData *data=[NSData dataWithContentsOfFile:MYBPath([NSString stringWithFormat:@"/usr/share/mybloxx/%@/%@.mobileconfig",folder,file])];
  dlopen("/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration",RTLD_LAZY);
  Class cls=NSClassFromString(@"MCProfileConnection");SEL shared=NSSelectorFromString(@"sharedConnection");
  id conn=(cls&&[cls respondsToSelector:shared])?((id(*)(id,SEL))objc_msgSend)(cls,shared):nil;
  NSDictionary *r=MYBProfileStage(conn,data,[file stringByAppendingString:@".mobileconfig"],replace);
  MYBAppDiagNote([NSString stringWithFormat:@"[settings] stage %@/%@ -> %@ category=%@ api=%@ error=%@/%@ attempts=%@",folder,file,r[@"state"],r[@"category"]?:@"-",r[@"api"]?:@"-",r[@"errorDomain"]?:@"-",r[@"errorCode"]?:@"-",r[@"attempts"]?:@"-"]);
  NSDictionary *nav=nil;
  if([r[@"state"] isEqual:@"staged"]){
   nav=MYBOpenProfileInstallerSensitive();
   MYBAppDiagNote([NSString stringWithFormat:@"[settings] installer navigation opened=%@ detail=%@ url=%@",nav[@"opened"],nav[@"detail"]?:@"-",nav[@"url"]?:@"-"]);
   NSDictionary *info=MYBProfileInfo(data);
   if(info){ // the record the status check reads, in the helper’s format
    NSMutableDictionary *rec=[MYBHelperStageRecord() mutableCopy];NSMutableDictionary *digests=[rec[@"stagedDigests"] mutableCopy]?:[NSMutableDictionary dictionary];digests[info[@"key"]]=info[@"digest"];
    [rec addEntriesFromDictionary:@{@"state":@"staged",@"folder":folder,@"name":file,@"at":@([[NSDate date] timeIntervalSince1970]),@"identifier":info[@"identifier"],@"uuid":info[@"uuid"],@"key":info[@"key"],@"digest":info[@"digest"],@"stagedDigests":digests,@"api":r[@"api"]?:@"",@"detail":r[@"detail"]?:@""}];
    [rec writeToFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.profileinstall.plist") atomically:NO];
   }
  }
  dispatch_async(dispatch_get_main_queue(),^{done(r,nav);});
 });
}
static void MYBStageProfile(UIViewController *owner,NSString *folder,NSString *file,NSString *label,NSString *link,BOOL replace);
// Called when iOS may already hold another downloaded profile. Nothing was handed to iOS yet; only this explicit choice replaces it.
static void MYBAskReplaceWaitingProfile(UIViewController *owner,NSString *folder,NSString *file,NSString *label,NSString *link,BOOL known){
 NSString *why=known?@"Another profile is already waiting in Settings.":@"iOS cannot tell MYbloXX\u00ae whether another profile is already waiting in Settings.";
 MYBConfirmWithButton(owner,@"Replace a Waiting Profile?",[why stringByAppendingString:@" Continuing can replace it with the MYbloXX\u00ae profile, and the other profile would have to be downloaded again. Cancel to leave it as it is."],@"Replace",^{
  MYBProfileBusy=YES;MYBStageProfile(owner,folder,file,label,link,YES);
 });
}
// Fallback: the helper stages, when the Settings component could not. The helper has no profile-service entitlement on iOS 16.5.1 (device log:
// profiled-access=no, error 39000), so this only matters if a future iOS lets it.
static void MYBStageViaHelper(UIViewController *owner,NSString *folder,NSString *file,NSString *label,NSString *link,BOOL replace,NSDictionary *settingsResult){
 MYBProgress(owner,@"Preparing Profile");
 NSArray *args=replace?@[@"profilestage",folder,file,@"replace"]:@[@"profilestage",folder,file];
 [(MYBMenuBase *)owner runHelper:args completion:^(int rc){
  MYBDismissStatus(owner);
  if(rc==0){MYBProfileBusy=NO;return;} // staged, and the helper opened Apple\u2019s own install screen (kMCSettingsURLProfilePurgatoryInstallation); Installed is read back when this screen is next shown
  if(rc==8){
   // staged, but the helper could not open the installer: try the Settings pages from here, and only then the manual routes
   MYBOpenInstaller(MYBProfileInstallerURLs(),0,^(BOOL opened){
    MYBProfileBusy=NO;
    if(opened){return;} // iOS now shows the downloaded profile; Installed is read back when this screen is next shown
    MYBProfileFallbacks(owner,folder,file,label,link,@"Profile Ready. Settings Did Not Open");
   });
   return;
  }
  if(rc==6||rc==7){MYBProfileBusy=NO;MYBAskReplaceWaitingProfile(owner,folder,file,label,link,rc==6);return;}
  if(rc==5){MYBProfileBusy=NO;MYBMessage(owner,@"Profile Not Available",@"The profile file is missing or damaged in this install. Reinstall MYbloXX®, then try again.");return;}
  NSDictionary *helperMsg=(rc==2||rc==4||rc==3)?MYBProfileFailureMessage(MYBHelperStageRecord(),@"MYbloXX\u00ae helper"):@{@"title":@"Helper Did Not Finish",@"detail":[NSString stringWithFormat:@"The helper stopped with status %d before iOS answered.",rc]};
  if(rc==3){MYBProfileBusy=NO;MYBMessage(owner,helperMsg[@"title"],helperMsg[@"detail"]);return;}
  MYBProfileBusy=NO;
  NSDictionary *settingsMsg=MYBProfileFailureMessage(settingsResult,@"Settings component");
  NSString *detail=[NSString stringWithFormat:@"From Settings: %@\n\nFrom the helper: %@",settingsMsg[@"detail"],helperMsg[@"detail"]];
  MYBConfirmWithButton(owner,settingsMsg[@"title"],detail,@"Other Ways to Get This Profile",^{MYBProfileFallbacks(owner,folder,file,label,link,@"Get the Profile Another Way");});
 }];
}
// The Settings component is the caller iOS lets use the profile service (device log: profiled-access=yes), so it goes first.
static void MYBStageProfile(UIViewController *owner,NSString *folder,NSString *file,NSString *label,NSString *link,BOOL replace){
 MYBProgress(owner,@"Preparing Profile");
 MYBStageInSettings(folder,file,replace,^(NSDictionary *r,NSDictionary *nav){
  NSString *state=r[@"state"];
  if([state isEqual:@"staged"]){
   MYBDismissStatus(owner);
   if([nav[@"opened"] boolValue]){MYBProfileBusy=NO;return;}
   MYBOpenInstaller(MYBProfileInstallerURLs(),0,^(BOOL opened){MYBProfileBusy=NO;if(!opened)MYBProfileFallbacks(owner,folder,file,label,link,@"Profile Ready. Settings Did Not Open");});
   return;
  }
  if([state isEqual:@"pendingother"]||[state isEqual:@"pendingunknown"]){MYBDismissStatus(owner);MYBProfileBusy=NO;MYBAskReplaceWaitingProfile(owner,folder,file,label,link,[state isEqual:@"pendingother"]);return;}
  if([state isEqual:@"restricted"]||[state isEqual:@"invalid"]){MYBDismissStatus(owner);MYBProfileBusy=NO;NSDictionary *m=[state isEqual:@"invalid"]?@{@"title":@"Profile Not Available",@"detail":@"The profile file is missing or damaged in this install. Reinstall MYbloXX\u00ae, then try again."}:MYBProfileFailureMessage(r,@"Settings component");MYBMessage(owner,m[@"title"],m[@"detail"]);return;}
  MYBDismissStatus(owner);
  MYBStageViaHelper(owner,folder,file,label,link,replace,r);
 });
}
void MYBDeliverProfileFile(UIViewController *owner,NSString *folder,NSString *file,NSString *title,NSString *link){
 if(MYBProfileBusy)return;
 NSString *label=title.length?title:@"Profile";
 if(![owner respondsToSelector:@selector(runHelper:completion:)]){MYBProfileFallbacks(owner,folder,file,label,link,[@"Get " stringByAppendingString:label]);return;}
 MYBProfileBusy=YES;
 MYBStageProfile(owner,folder,file,label,link,NO);
}
// The label shown for a bundled profile: Installed, Different Version Installed, Installed, Not Verified, Not Installed, Accepted, Not Confirmed
// or Unable to Check. It is looked up by the profile’s own identifier AND PayloadUUID: the Legacy profiles share one identifier.
NSString *MYBProfileStatusText(NSString *folder,NSString *file){
 NSData *data=[NSData dataWithContentsOfFile:MYBPath([NSString stringWithFormat:@"/usr/share/mybloxx/%@/%@.mobileconfig",folder,file])];
 NSDictionary *info=MYBProfileInfo(data);NSString *key=info[@"key"];
 NSDictionary *record=[NSDictionary dictionaryWithContentsOfFile:MYBMobileFile(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.profileinstall.plist")];
 NSDictionary *check=key?record[@"checks"][key]:nil;
 return MYBProfileDisplayLabel([check isKindOfClass:NSDictionary.class]?check[@"state"]:nil,record,key,NSDate.date.timeIntervalSince1970);
}
// Reads the installed state of each profile back from iOS, one after another, then reports once.
static void MYBRefreshProfileStep(UIViewController *owner,NSString *folder,NSArray<NSString *> *files,NSUInteger index,void(^done)(void)){
 if(index>=files.count){if(done)done();return;}
 [(MYBMenuBase *)owner runHelper:@[@"profilestatus",folder,files[index]] completion:^(int rc){(void)rc;MYBRefreshProfileStep(owner,folder,files,index+1,done);}];
}
void MYBRefreshProfileStatus(UIViewController *owner,NSString *folder,NSArray<NSString *> *files,void(^done)(void)){
 if(![owner respondsToSelector:@selector(runHelper:completion:)]||!files.count){if(done)done();return;}
 MYBRefreshProfileStep(owner,folder,files,0,done);
}
