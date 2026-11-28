#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <notify.h>
#import <spawn.h>
#import <sys/wait.h>
#import <signal.h>
#import <unistd.h>
#import <roothide.h>
#import <errno.h>
#import "../../Shared/MYBAppControl.h"
#import "../../Shared/MYBAppPrep.h"
#import "../../Shared/MYBAppSwitchLog.h"
extern char **environ;
// Event-based implementation. Never call SBS synchronous RPC from SpringBoard.
static NSDictionary *prefs;
static NSString *foreground=@"__none__", *foregroundName, *sentApp, *sentName, *suppressed;
static BOOL pausedActive; // blocking is paused for sentApp because a pause was really needed and succeeded
static MYBAppPrep *prep;
static NSTimeInterval sentAt;
static BOOL pending;
static NSUInteger generation, reloadGeneration;
static NSTimer *heartbeat;
static void MYBSubmit(void);
// ---- Activity trace -------------------------------------------------------------------------------------------------
// A short ring of what this side did (shown in Status & Diagnostics > App Switch Raw Trace; the user-facing history is App Switch Control > Activity), so a missing "Preparing App"
// screen can be explained from the device: foreground seen, skipped and why, window created with or without a scene, helper result.
static dispatch_queue_t MYBTraceQueue(void){static dispatch_queue_t q;static dispatch_once_t once;dispatch_once(&once,^{q=dispatch_queue_create("net.myxxdev.mybloxx.appcontrol.trace",DISPATCH_QUEUE_SERIAL);});return q;}
static void MYBTrace(NSString *event){
 NSDate *now=[NSDate date];
 dispatch_async(MYBTraceQueue(),^{
  NSString *path=jbroot(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.appcontrol-trace.plist");
  NSMutableArray *log=[[NSArray arrayWithContentsOfFile:path] mutableCopy]?:[NSMutableArray array];
  [log addObject:@{@"t":now,@"e":event}];while(log.count>30)[log removeObjectAtIndex:0];
  [log writeToFile:path atomically:YES];
 });
}
static BOOL MYBProtectionIntendedOn(void){
 NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:jbroot(@"/var/mobile/Library/MYbloXX/State.plist")];
 return state[@"enabled"]?[state[@"enabled"] boolValue]:YES; // unknown means there may be something to pause
}
// ---- "Preparing App" overlay and confirmation ------------------------------------------------------------------------
// The overlay is shown only while the helper is really pausing MYbloXX for the app that just came to the front, and removed
// when the helper acknowledges, the person cancels, they leave the app or the device locks. A confirmation toast is shown when
// nothing had to be prepared or once preparation finished. Neither holds requests back; they only report what is happening.
// iOS 13 and later attach every window to a UIWindowScene; a window created without one is never drawn by SpringBoard. This
// was the reason the first version of this screen did not appear, so the window is created on the live scene.
@interface MYBPrepWindow : UIWindow
@property(nonatomic) BOOL passthrough;
@end
@implementation MYBPrepWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event{return self.passthrough?NO:[super pointInside:point withEvent:event];}
@end
static UIWindowScene *MYBPrepScene(void){
 UIWindowScene *best=nil;
 for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
  if(![scene isKindOfClass:UIWindowScene.class])continue;
  if(!best||scene.activationState==UISceneActivationStateForegroundActive)best=(UIWindowScene *)scene;
 }
 return best;
}
static MYBPrepWindow *prepWindow;static UILabel *prepTitle,*prepDetail;static UIActivityIndicatorView *prepSpinner;static UIButton *prepCancel,*prepRetry,*prepContinue;static UIImageView *prepCheck;static NSUInteger toastGeneration;
static UIButton *MYBPrepButton(NSString *title,SEL action,BOOL primary){
 UIButtonConfiguration *configuration=[UIButtonConfiguration plainButtonConfiguration];
 configuration.title=title;configuration.contentInsets=NSDirectionalEdgeInsetsMake(12,22,12,22);
 configuration.baseForegroundColor=primary?UIColor.whiteColor:[UIColor colorWithWhite:1 alpha:.75];
 configuration.background.backgroundColor=primary?[UIColor colorWithRed:.43 green:.30 blue:.85 alpha:1]:[UIColor colorWithWhite:1 alpha:.12];configuration.background.cornerRadius=14;
 configuration.titleTextAttributesTransformer=^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attributes){NSMutableDictionary *a=[attributes mutableCopy];a[NSFontAttributeName]=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];return a;};
 UIButton *b=[UIButton buttonWithConfiguration:configuration primaryAction:nil];b.translatesAutoresizingMaskIntoConstraints=NO;
 [b addTarget:(id)NSClassFromString(@"MYBPrepActions") action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
static void MYBHidePrep(void){prepWindow.hidden=YES;[prepSpinner stopAnimating];toastGeneration++;}
static void MYBBuildPrepWindow(void){
 if(prepWindow)return;
 UIWindowScene *scene=MYBPrepScene();
 prepWindow=scene?[[MYBPrepWindow alloc] initWithWindowScene:scene]:[[MYBPrepWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
 MYBTrace(scene?@"Window created on a scene":@"Window created WITHOUT a scene (may not draw)");
 prepWindow.windowLevel=UIWindowLevelAlert+100;prepWindow.backgroundColor=UIColor.clearColor;
 UIViewController *root=[UIViewController new];prepWindow.rootViewController=root;
 UIVisualEffectView *blur=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];blur.frame=root.view.bounds;blur.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;blur.tag=77;[root.view addSubview:blur];
 UILabel *brand=[UILabel new];brand.text=@"MYbloXX®";brand.font=[UIFont systemFontOfSize:15 weight:UIFontWeightBold];brand.textColor=[UIColor colorWithWhite:1 alpha:.6];brand.tag=78;
 prepTitle=[UILabel new];prepTitle.font=[UIFont systemFontOfSize:22 weight:UIFontWeightBold];prepTitle.textColor=UIColor.whiteColor;prepTitle.numberOfLines=0;prepTitle.textAlignment=NSTextAlignmentCenter;
 prepDetail=[UILabel new];prepDetail.font=[UIFont systemFontOfSize:15];prepDetail.textColor=[UIColor colorWithWhite:1 alpha:.7];prepDetail.numberOfLines=0;prepDetail.textAlignment=NSTextAlignmentCenter;
 prepSpinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];prepSpinner.color=UIColor.whiteColor;
 prepCheck=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];prepCheck.tintColor=[UIColor colorWithRed:.3 green:.85 blue:.5 alpha:1];
 prepCancel=MYBPrepButton(@"Cancel",NSSelectorFromString(@"cancelPrep"),NO);prepRetry=MYBPrepButton(@"Retry",NSSelectorFromString(@"retryPrep"),YES);prepContinue=MYBPrepButton(@"Continue Without",NSSelectorFromString(@"continuePrep"),NO);
 UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[brand,prepSpinner,prepCheck,prepTitle,prepDetail,prepRetry,prepContinue,prepCancel]];
 stack.axis=UILayoutConstraintAxisVertical;stack.alignment=UIStackViewAlignmentCenter;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=NO;stack.tag=79;[root.view addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],[stack.centerYAnchor constraintEqualToAnchor:root.view.centerYAnchor],[stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.view.leadingAnchor constant:32],[stack.trailingAnchor constraintLessThanOrEqualToAnchor:root.view.trailingAnchor constant:-32]]];
}
// mode 0 = preparing (blocking, with Cancel), 1 = failed (Retry / Continue Without), 2 = confirmation toast (never blocks touches)
static void MYBShowPrep(int mode){
 MYBBuildPrepWindow();
 NSString *name=foregroundName.length?foregroundName:@"this app";
 UIView *root=prepWindow.rootViewController.view;
 BOOL toast=mode==2;prepWindow.passthrough=toast;
 [root viewWithTag:77].alpha=toast?0:1;
 prepSpinner.hidden=toast||mode==1;prepCheck.hidden=!toast;prepRetry.hidden=prepContinue.hidden=mode!=1;prepCancel.hidden=mode!=0;[root viewWithTag:78].hidden=toast;
 if(mode==0)prepTitle.text=[NSString stringWithFormat:@"Preparing %@...",name];
 else if(mode==1)prepTitle.text=[NSString stringWithFormat:@"Couldn’t prepare %@",name];
 else prepTitle.text=[NSString stringWithFormat:@"Ready for %@",name];
 prepDetail.text=mode==0?@"Pausing MYbloXX® for this app.":mode==1?@"MYbloXX® could not pause blocking for this app. Retry, or continue without it.":@"MYbloXX® is ready for this app.";
 if(mode==0)[prepSpinner startAnimating];else [prepSpinner stopAnimating];
 prepWindow.hidden=NO;
 MYBTrace([NSString stringWithFormat:@"Showing %@ (window %@)",mode==0?@"Preparing":mode==1?@"failure":@"confirmation",prepWindow.windowScene?@"on scene":@"no scene"]);
 NSUInteger generationAtShow=++toastGeneration;
 if(toast)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(toastGeneration==generationAtShow)MYBHidePrep();});
}
static BOOL MYBLocked(void){
 Class c=NSClassFromString(@"SBLockScreenManager");SEL shared=NSSelectorFromString(@"sharedInstance"),locked=NSSelectorFromString(@"isUILocked");
 if(![c respondsToSelector:shared])return NO;
 id manager=((id(*)(id,SEL))objc_msgSend)(c,shared);
 return [manager respondsToSelector:locked]&&((BOOL(*)(id,SEL))objc_msgSend)(manager,locked);
}
static int MYBRunFocus(NSString *app){
 pid_t pid=0;NSString *helper=jbroot(@"/usr/sbin/MYXXdev/MYbloXX/MYXXdev");
 const char *args[]={"MYXXdev","appfocus",app.UTF8String,NULL};
 int rc=posix_spawn(&pid,helper.fileSystemRepresentation,NULL,NULL,(char *const *)args,environ);if(rc)return rc;
 // Bounded, off-main wait. A stuck helper must never stall SpringBoard.
 for(int tick=0;tick<160;tick++){
  int status=0;pid_t result=waitpid(pid,&status,WNOHANG);
  if(result==pid)return WIFEXITED(status)?WEXITSTATUS(status):125;
  if(result<0&&errno!=EINTR)return 125;
  usleep(50000);
 }
 kill(pid,SIGKILL);int status=0;while(waitpid(pid,&status,0)<0&&errno==EINTR){}return 124;
}
static NSString *MYBTarget(void){return MYBAppControlSelected(prefs,foreground)&&!MYBLocked()?foreground:@"__none__";}
static void MYBPrepFinished(MYBPrepState state,BOOL needed){
 if(state==MYBPrepReady){MYBTrace(@"Helper acknowledged: ready");MYBShowPrep(2);(void)needed;} // brief, non-blocking confirmation
 else if(state==MYBPrepFailed){suppressed=[prep.app copy];MYBTrace([NSString stringWithFormat:@"Preparation failed (code %d)",prep.failureCode]);MYBShowPrep(1);} // no automatic retry loop behind a visible failure
 else if(state!=MYBPrepPreparing){MYBTrace(state==MYBPrepCancelled?@"Cancelled":@"Result ignored (app no longer in front)");MYBHidePrep();}
}
static void MYBSubmit(void){
 if(pending)return;if(!MYBAppControlServiceEnabled(prefs))return;NSString *target=MYBTarget();NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
 if([target isEqual:suppressed])return;
 if([target isEqual:sentApp]&&([target isEqual:@"__none__"]||now-sentAt<10))return;
 pending=YES;NSString *event=[target copy];BOOL entering=![event isEqual:@"__none__"];NSUInteger token=0;NSString *wasApp=[sentApp copy],*wasName=[sentName copy],*nowName=[foregroundName copy];
 // A heartbeat refresh for the app that is already prepared is silent. Only a real transition shows feedback.
 BOOL transition=entering&&![event isEqual:sentApp];BOOL needed=transition&&MYBProtectionIntendedOn();
 if(!prep)prep=[[MYBAppPrep alloc] initWithLimit:10];
 if(transition){
  token=[prep beginForApp:event now:now];
  MYBTrace([NSString stringWithFormat:@"Preparing %@ (pause needed: %@)",event,needed?@"yes":@"no, protection is off"]);
  if(needed)MYBShowPrep(0); // drawn immediately: the helper really has work to do, so there is no artificial delay
  // Backstop for the bounded wait: the helper call is already time-limited, this covers anything that never reports back.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((prep.limit+1)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(prep.token==token){MYBPrepState st=[prep expireAt:NSDate.timeIntervalSinceReferenceDate];if(st==MYBPrepFailed&&[MYBTarget() isEqual:event])MYBPrepFinished(st,needed);}});
 }else if(!entering){[prep reset];MYBHidePrep();}
 NSTimeInterval started=now;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{int rc=MYBRunFocus(event);
  dispatch_async(dispatch_get_main_queue(),^{pending=NO;
   if(!rc){sentApp=event;sentAt=NSDate.timeIntervalSinceReferenceDate;sentName=entering?nowName:nil;}
   // User-facing history: only real pause and resume events. A heartbeat refresh, or a pass through an app while protection was already off, is not an event.
   if(transition){
    if(!rc&&needed){pausedActive=YES;MYBAppSwitchRecord(MYBAppSwitchFile(),@"paused",event,nowName);}
    else if(rc)MYBAppSwitchRecord(MYBAppSwitchFile(),@"failed",event,nowName);
   }else if(!entering&&pausedActive&&wasApp.length&&![wasApp isEqual:@"__none__"]){
    if(!rc){pausedActive=NO;MYBAppSwitchRecord(MYBAppSwitchFile(),@"resumed",wasApp,wasName);}
    else MYBAppSwitchRecord(MYBAppSwitchFile(),@"resume-failed",wasApp,wasName);
   }
   if(transition){
    MYBTrace([NSString stringWithFormat:@"Helper returned %d after %d ms",rc,(int)((NSDate.timeIntervalSinceReferenceDate-started)*1000)]);
    if(prep.state==MYBPrepCancelled){ // cancelled while the helper was working: put things back instead of leaving MYbloXX paused
     sentApp=nil;dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{(void)MYBRunFocus(@"__none__");});return;
    }
    MYBPrepFinished([prep completeToken:token code:rc foreground:MYBTarget()],needed);
   }
   if(![MYBTarget() isEqual:event])MYBSubmit();
   else if(rc&&!transition){NSLog(@"MYbloXX® App Control: helper returned %d",rc);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{MYBSubmit();});}
   else if(rc)NSLog(@"MYbloXX® App Control: helper returned %d while preparing an app",rc);
  });
 });
}
@interface MYBPrepActions : NSObject
+ (void)cancelPrep;+ (void)retryPrep;+ (void)continuePrep;
@end
@implementation MYBPrepActions
+ (void)cancelPrep{MYBTrace(@"Cancel tapped");suppressed=[prep.app copy];[prep cancel];MYBHidePrep();if(!pending){sentApp=nil;dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{(void)MYBRunFocus(@"__none__");});}}
+ (void)retryPrep{MYBTrace(@"Retry tapped");suppressed=nil;sentApp=nil;[prep reset];MYBHidePrep();MYBSubmit();}
+ (void)continuePrep{[prep reset];MYBHidePrep();} // stays suppressed for this visit; the next foreground change clears it
@end
static void MYBForegroundChanged(id app){
 // frontDisplayDidChange: supplies an SBApplication or nil for Home/lock.
 // Nil is a restore event, never an invitation to query SpringBoardServices.
 NSString *bid=nil;SEL selector=NSSelectorFromString(@"bundleIdentifier");
 if([app respondsToSelector:selector]){id value=((id(*)(id,SEL))objc_msgSend)(app,selector);if([value isKindOfClass:NSString.class])bid=value;}
 foreground=bid.length?[bid copy]:@"__none__";NSUInteger version=++generation;
 foregroundName=nil;if(bid.length&&[app respondsToSelector:NSSelectorFromString(@"displayName")]){id name=((id(*)(id,SEL))objc_msgSend)(app,NSSelectorFromString(@"displayName"));if([name isKindOfClass:NSString.class])foregroundName=[name copy];}
 if(![foreground isEqual:suppressed])suppressed=nil;
 MYBTrace([NSString stringWithFormat:@"Foreground: %@ (selected: %@, locked: %@)",foreground,MYBAppControlSelected(prefs,foreground)?@"yes":@"no",MYBLocked()?@"yes":@"no"]);
 if(prep&&![foreground isEqual:prep.app])MYBHidePrep(); // left the app: the overlay never outlives it
 // Entering a selected app starts preparing at once; leaving or locking keeps the short debounce so a quick pass through Home does not toggle blocking.
 if(MYBAppControlSelected(prefs,foreground)&&!MYBLocked()){MYBSubmit();return;}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,150*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(version==generation)MYBSubmit();});
}
static void MYBReload(void){
 NSUInteger version=++reloadGeneration;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSDictionary *loaded=[NSDictionary dictionaryWithContentsOfFile:jbroot(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist")]?:@{};
  dispatch_async(dispatch_get_main_queue(),^{if(version!=reloadGeneration)return;prefs=loaded;sentApp=nil;MYBSubmit();
   [heartbeat invalidate];heartbeat=nil;
   if(MYBAppControlServiceEnabled(prefs))heartbeat=[NSTimer scheduledTimerWithTimeInterval:10 repeats:YES block:^(__unused NSTimer *t){MYBSubmit();}];
  });
 });
}
%group AppEvents
%hook SpringBoard
- (void)frontDisplayDidChange:(id)application {
 %orig;
 if(NSThread.isMainThread)MYBForegroundChanged(application);
 else dispatch_async(dispatch_get_main_queue(),^{MYBForegroundChanged(application);});
}
%end
%end
%ctor{@autoreleasepool{
 Class cls=NSClassFromString(@"SpringBoard");Method method=class_getInstanceMethod(cls,NSSelectorFromString(@"frontDisplayDidChange:"));
 char result[8]={0},argument[8]={0};if(method){method_getReturnType(method,result,sizeof(result));method_getArgumentType(method,2,argument,sizeof(argument));}
 if(method&&method_getNumberOfArguments(method)==3&&result[0]=='v'&&argument[0]=='@'){%init(AppEvents);MYBTrace(@"SpringBoard loaded App Control; foreground hook installed");}
 else {NSLog(@"MYbloXX® App Control: foreground event unavailable; bypass disabled");MYBTrace(@"Foreground hook UNAVAILABLE on this iOS version");}
 dispatch_async(dispatch_get_main_queue(),^{
  MYBReload();int preferencesToken=0,lockToken=0;
  notify_register_dispatch("net.myxxdev.mybloxx.speedyads.changed",&preferencesToken,dispatch_get_main_queue(),^(__unused int token){MYBReload();});
  notify_register_dispatch("com.apple.springboard.lockstate",&lockToken,dispatch_get_main_queue(),^(__unused int token){if(MYBLocked())MYBForegroundChanged(nil);});
 });
}}
