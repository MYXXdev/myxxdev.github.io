#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>
#import "../Shared/MYBRuntimeStatus.h"
extern char **environ;

// Use Apple's actual CCUIToggleModule superclass. The old UIViewController
// substitute compiled but was not runtime-safe.
#if __has_include(<ControlCenterUIKit/CCUIToggleModule.h>)
#import <ControlCenterUIKit/CCUIToggleModule.h>
#else
@interface CCUIToggleModule : NSObject
- (void)refreshState;
@end
#endif

@interface MYbloXXCC2 : CCUIToggleModule
@property (nonatomic, assign) BOOL busy;
@end

@implementation MYbloXXCC2

// Live system configuration, shared with the Settings toggle.
// Live system configuration: protection is "on" only when MYbloXX's managed link points at an
// intact inline-PAC runtime target (SpringBoard can read it directly).
static NSString *dynamicHelper(void) {
 NSString *bundle=[[NSBundle bundleForClass:[MYbloXXCC2 class]] bundlePath];
 NSRange boundary=[bundle rangeOfString:@"/Library/ControlCenter/Bundles/"];
 if(boundary.location!=NSNotFound) {
  NSString *candidate=[[bundle substringToIndex:boundary.location] stringByAppendingPathComponent:@"usr/sbin/MYXXdev/MYbloXX/MYXXdev"];
  if([[NSFileManager defaultManager] isExecutableFileAtPath:candidate])return candidate;
 }
 return @"/var/jb/usr/sbin/MYXXdev/MYbloXX/MYXXdev";
}

static NSString *mirrorPath(void) {
 NSString *bundle=[[NSBundle bundleForClass:[MYbloXXCC2 class]] bundlePath];
 NSRange boundary=[bundle rangeOfString:@"/Library/ControlCenter/Bundles/"];
 if(boundary.location==NSNotFound)return nil;
 return [[bundle substringToIndex:boundary.location] stringByAppendingPathComponent:@"var/mobile/Library/MYbloXX/RuntimeStatus.plist"];
}
- (BOOL)isSelected {
    return [MYBRuntimeStatusMirrored(mirrorPath())[@"enabled"] boolValue];
}
- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.42 green:0.12 blue:0.72 alpha:1.0];
}
- (UIImage *)iconGlyph {
    // CCUIToggleModule doesn't promise a public spinner API. Present an
    // hourglass while the helper runs, then restore the MYbloXX mark.
    if(self.busy) {
      UIImage *waiting=[UIImage systemImageNamed:@"hourglass"];
      if(waiting)return [waiting imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    UIImage *glyph=[UIImage imageNamed:@"icon" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    return [glyph imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
- (void)setSelected:(BOOL)selected {
    if (self.busy || selected == [self isSelected]) {
        [self refreshState];
        return;
    }
    self.busy = YES;
    [self refreshState]; // Refresh hourglass without guessing the final selected state.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        const char *action = selected ? "enable" : "disable";
        const char *args[] = {"MYXXdev",action,NULL};
        pid_t pid=0;
        int rc=posix_spawn(&pid,dynamicHelper().fileSystemRepresentation,NULL,NULL,(char *const *)args,environ);
        if(rc==0) {
            int status=0;
            if(waitpid(pid,&status,0)<0) rc=125;
            else rc=WIFEXITED(status)?WEXITSTATUS(status):126;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy=NO;
            if(rc!=0) NSLog(@"[MYbloXXCC2] action %s failed (%d)",action,rc);
            [self refreshState]; // Actual status, never optimistic UI state
        });
    });
}
@end


