// MYbloXX SpeedyAds: per-app ad acceleration for App Control.
// Fixed per-app acceleration policy (MYbloXX change). No SDK ad-blocking tables, inline
// overrides, all-native-video mode, master switch or user tuning remain.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <mach-o/dyld.h>
#import <notify.h>
#import <roothide.h>
#import "../../Shared/MYBLoopback.h"
#import "../../Shared/MYBAppControl.h"
#import "Acceleration.generated.h"
static BOOL active;
static NSInteger adDepth;
static NSHashTable<WKWebView *> *webviews;
static NSMutableDictionary<NSString *,NSValue *> *originalJB;
static char scriptInstalled;
static NSDictionary *loadPrefs(void){
 for(NSString *path in @[jbroot(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist"),@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist"]){NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:path];if(prefs)return prefs;}return @{};
}
static NSString *hookKey(Class cls,SEL selector){return [NSString stringWithFormat:@"%@%@/%@",class_isMetaClass(cls)?@"+":@"-",NSStringFromClass(cls),NSStringFromSelector(selector)];}
static BOOL compatibilityFlag(id object,SEL selector){
 if(active)return NO;
 for(Class cls=object_getClass(object);cls;cls=class_getSuperclass(cls)){
  IMP original=(IMP)[originalJB[hookKey(cls,selector)] pointerValue];if(original)return ((BOOL(*)(id,SEL))original)(object,selector);
 }return NO;
}
static void installCompatibility(void){
 if(!active)return;
 const char *classes[]={"BUDeviceHelper","EBAppLogDeviceHelper","HMDBUInfo","MobClick","MobClick","SSEDeviceStatus","UMUtils","UMUtils"};
 const char *selectors[]={"bu_isJailBroken","isJailBroken","isJailBroken","isJailbroken","isPirated","jailBroken","isDeviceJailBreak","isAppPirate"};
 for(NSUInteger i=0;i<8;i++){
  Class typeClass=objc_getClass(classes[i]);if(!typeClass)continue;
  for(int kind=0;kind<2;kind++){
   Class cls=kind?object_getClass(typeClass):typeClass;SEL selector=sel_registerName(selectors[i]);Method method=class_getInstanceMethod(cls,selector);if(!method||method_getNumberOfArguments(method)!=2)continue;
   char type[8]={0};method_getReturnType(method,type,sizeof(type));if(type[0]!='B'&&type[0]!='c')continue;
   if(class_getMethodImplementation(cls,selector)==(IMP)compatibilityFlag)continue;
   IMP previous=NULL;MSHookMessageEx(cls,selector,(IMP)compatibilityFlag,&previous);if(previous)originalJB[hookKey(cls,selector)]=[NSValue valueWithPointer:(const void *)previous];
  }
 }
}
static BOOL updateScripts(WKUserContentController *controller,BOOL enabled){
 NSString *source=MYBAccelerationScript(enabled);NSArray *scripts=controller.userScripts;BOOL found=NO;
 for(WKUserScript *script in scripts)if([script.source hasPrefix:@"/* MYbloXX App Control 49 */"]){found=YES;if([script.source isEqual:source])return YES;}
 if(!enabled&&!found)return NO;
 // Replace only our script; preserve the SDK's scripts and message handlers.
 [controller removeAllUserScripts];
 for(WKUserScript *script in scripts)if(![script.source hasPrefix:@"/* MYbloXX App Control 49 */"])[controller addUserScript:script];
 [controller addUserScript:[[WKUserScript alloc] initWithSource:source injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO]];
 return YES;
}
static void updateWebview(WKWebView *view){
 if(updateScripts(view.configuration.userContentController,active)){objc_setAssociatedObject(view,&scriptInstalled,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[view evaluateJavaScript:MYBAccelerationScript(active) completionHandler:nil];}
}
static void refreshRuntime(NSDictionary *prefs){
 active=MYBAppControlSelected(prefs,NSBundle.mainBundle.bundleIdentifier)&&UIApplication.sharedApplication.applicationState!=UIApplicationStateBackground; // Inactive counts: a launching app is Inactive until it becomes active, and ads can be requested in that window
 installCompatibility();for(WKWebView *view in webviews.allObjects)updateWebview(view);
}
static void refreshFromBridge(void){
 refreshRuntime(loadPrefs());NSString *bid=NSBundle.mainBundle.bundleIdentifier?:@"";
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSData *data=MYBLoopbackGET(8787,[@"/app-config?app=" stringByAppendingString:bid]);id prefs=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;if([prefs isKindOfClass:NSDictionary.class])dispatch_async(dispatch_get_main_queue(),^{refreshRuntime(prefs);});});
}
static void imageAdded(__unused const struct mach_header *image,__unused intptr_t slide){dispatch_async(dispatch_get_main_queue(),^{installCompatibility();});}
%group AdContext
%hook GADFullScreenAdViewController
- (void)viewDidAppear:(BOOL)animated{%orig;adDepth++;}
- (void)viewDidDisappear:(BOOL)animated{%orig;if(adDepth>0)adDepth--;}
%end
%hook MAFullscreenAdViewController
- (void)viewDidAppear:(BOOL)animated{%orig;adDepth++;}
- (void)viewDidDisappear:(BOOL)animated{%orig;if(adDepth>0)adDepth--;}
%end
%end
%hook AVPlayer
- (void)setRate:(float)rate{
 if(active&&adDepth>0&&rate>0){%orig((float)MYBAccelerationMultiplier);}else {%orig(rate);}
}
%end
%hook WKWebView
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration{
 BOOL inject=configuration?updateScripts(configuration.userContentController,active):NO;
 WKWebView *view=%orig;
 if(view){[webviews addObject:view];if(inject)objc_setAssociatedObject(view,&scriptInstalled,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}return view;
}
%end
%ctor{@autoreleasepool{
 webviews=[NSHashTable weakObjectsHashTable];originalJB=[NSMutableDictionary dictionary];%init;%init(AdContext);
 _dyld_register_func_for_add_image(imageAdded);
 refreshRuntime(loadPrefs()); // selected apps are armed as the library loads, not only after the first main-queue turn
 dispatch_async(dispatch_get_main_queue(),^{
  refreshFromBridge();int token=0;notify_register_dispatch("net.myxxdev.mybloxx.speedyads.changed",&token,dispatch_get_main_queue(),^(__unused int value){refreshFromBridge();});
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification){refreshFromBridge();}];
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification){active=NO;adDepth=0;for(WKWebView *view in webviews.allObjects)updateWebview(view);}];
 });
}}
