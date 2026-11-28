// Quiets Apple's "Profile Downloaded - Review the profile in the Settings app" alert, and only that alert, and only for a profile MYbloXX
// itself is queueing. MYbloXX opens Apple's install screen straight away, so the alert is redundant there. Every other profile (one the
// person downloaded from Safari, a Mail attachment, an MDM push) keeps Apple's alert exactly as iOS posts it.
//
// How: the real display method is wrapped, never replaced. Its shape was read from this iOS (16.5.1) by the previous probe build:
//   displayUserNotificationWithIdentifier:title:message:defaultButtonText:alternateButtonText:otherButtonText:textfieldPlaceholder:
//   displayOnLockScreen:dismissOnLock:displayInAppWhitelistModes:dismissAfterTimeInterval:assertion:completionBlock:   (v@:@@@@@@@BBBd@@?)
// The hook is installed only when the method's encoding is exactly that. For the matching alert the alert is not shown, and the completion
// block is run once by itself, but only when its own stored signature says it returns nothing and takes plain numbers/BOOLs (or nothing). If
// that cannot be established the original is called with a very short dismiss interval instead (the previous behaviour). Anything
// unexpected falls through to the original, unchanged.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <roothide.h>
static NSString *DiagPath(void){return jbroot(@"/var/mobile/Library/MYbloXX/ProfileDiagnostics.txt");}
static void Note(NSString *line){
 NSString *path=DiagPath();int fd=open(path.fileSystemRepresentation,O_WRONLY|O_APPEND|O_CREAT,0666);if(fd<0)return;fchmod(fd,0666);
 NSString *stamp=[NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
 NSData *d=[[NSString stringWithFormat:@"%@ [alert] %@\n",stamp,line] dataUsingEncoding:NSUTF8StringEncoding];if(d)write(fd,d.bytes,d.length);close(fd);
}
// True only while MYbloXX's own marker says it is queueing a profile right now (written by MYbloXX immediately BEFORE it calls the profile
// service, because iOS posts the alert during that call). The marker expires after 90 seconds.
static BOOL MYbloXXIsStagingNow(void){
 NSDictionary *rec=[NSDictionary dictionaryWithContentsOfFile:jbroot(@"/var/mobile/Library/Preferences/net.myxxdev.mybloxx.profilealert.plist")];
 NSTimeInterval at=[rec[@"at"] respondsToSelector:@selector(doubleValue)]?[rec[@"at"] doubleValue]:0;
 NSTimeInterval age=[NSDate date].timeIntervalSince1970-at;
 return at>0&&age>=-5&&age<=90;
}
// The completion block's own signature, read from the block itself (nothing is assumed about it). It may be called without a real answer only
// when it returns nothing and every argument is a plain number or BOOL, so there is no object or pointer to get wrong.
struct MYBBlockLayout{void *isa;int flags;int reserved;void *invoke;struct{unsigned long reserved,size;} *descriptor;};
static NSMethodSignature *BlockSignature(id block){
 if(!block)return nil;
 struct MYBBlockLayout *layout=(__bridge struct MYBBlockLayout *)block;
 if(!(layout->flags&(1<<30)))return nil; // no signature stored
 char *d=(char *)layout->descriptor+2*sizeof(unsigned long);
 if(layout->flags&(1<<25))d+=2*sizeof(void *); // copy and dispose helpers come first
 const char *types=*(const char **)d;
 if(!types)return nil;
 @try{return [NSMethodSignature signatureWithObjCTypes:types];}@catch(__unused id e){return nil;}
}
static BOOL ScalarOnly(NSMethodSignature *sig){
 if(!sig||sig.methodReturnType[0]!='v')return NO;
 for(NSUInteger i=1;i<sig.numberOfArguments;i++){const char *t=[sig getArgumentTypeAtIndex:i];if(!t||!strchr("cCsSiIlLqQB",t[0]))return NO;}
 return YES;
}
static void CallWithZeros(id block,NSMethodSignature *sig){
 NSInvocation *inv=[NSInvocation invocationWithMethodSignature:sig];
 for(NSUInteger i=1;i<sig.numberOfArguments;i++){NSUInteger size=0;NSGetSizeAndAlignment([sig getArgumentTypeAtIndex:i],&size,NULL);void *zero=calloc(1,size?size:8);[inv setArgument:zero atIndex:(NSInteger)i];free(zero);}
 inv.target=block;[inv invoke];
}
static NSString *InstallMessage(void){
 NSString *(*loc)(NSString *)=(NSString *(*)(NSString *))dlsym(RTLD_DEFAULT,"MCLocalizedString");
 return loc?loc(@"INSTALL_PROFILE_MESSAGE_PHONE"):nil;
}
%group Quiet
%hook MCUserNotificationManager
- (void)displayUserNotificationWithIdentifier:(id)ident title:(id)title message:(id)message defaultButtonText:(id)defaultText alternateButtonText:(id)alternateText otherButtonText:(id)otherText textfieldPlaceholder:(id)placeholder displayOnLockScreen:(BOOL)onLock dismissOnLock:(BOOL)dismissOnLock displayInAppWhitelistModes:(BOOL)inApp dismissAfterTimeInterval:(double)interval assertion:(id)assertion completionBlock:(id)completion{
 NSString *expected=InstallMessage();
 BOOL isInstallAlert=expected.length&&[message isKindOfClass:NSString.class]&&[(NSString *)message isEqualToString:expected];
 if(isInstallAlert&&MYbloXXIsStagingNow()){
  NSMethodSignature *sig=BlockSignature(completion);
  if(!completion||ScalarOnly(sig)){
   // Not shown at all. iOS's own completion is still run (with no real answer: nothing but plain numbers), so the service is never left waiting.
   Note([NSString stringWithFormat:@"Profile Downloaded alert not shown: MYbloXX® is queueing this profile (completion %@)",completion?[NSString stringWithUTF8String:sig.methodReturnType?:"?"]:@"none"]);
   if(completion){id block=completion;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),^{CallWithZeros(block,sig);});}
   return;
  }
  Note([NSString stringWithFormat:@"Profile Downloaded alert shortened (completion not safe to call by itself: %@)",sig?[NSString stringWithUTF8String:sig.description.UTF8String?:"?"]:@"no signature"]);
  %orig(ident,title,message,defaultText,alternateText,otherText,placeholder,NO,dismissOnLock,inApp,0.05,assertion,completion);
  return;
 }
 if(isInstallAlert)Note(@"Profile Downloaded alert left as is: MYbloXX® was not queueing a profile");
 %orig;
}
%end
%end
%ctor{
 @autoreleasepool{
  Class c=NSClassFromString(@"MCUserNotificationManager");if(!c)return;
  SEL s=NSSelectorFromString(@"displayUserNotificationWithIdentifier:title:message:defaultButtonText:alternateButtonText:otherButtonText:textfieldPlaceholder:displayOnLockScreen:dismissOnLock:displayInAppWhitelistModes:dismissAfterTimeInterval:assertion:completionBlock:");
  Method m=class_getInstanceMethod(c,s);if(!m)return;
  const char *e=method_getTypeEncoding(m);NSMutableString *flat=[NSMutableString string];for(const char *q=e?e:"";*q;q++)if(*q<'0'||*q>'9')[flat appendFormat:@"%c",*q];
  if(![flat isEqualToString:@"v@:@@@@@@@BBBd@@?"])return; // any other shape: nothing is hooked
  %init(Quiet);
 }
}
