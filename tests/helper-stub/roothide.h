// Test stand-in for <roothide.h>: maps the jailbreak root onto the fixture directory so the REAL helper code runs
// unmodified against files in a temporary directory.
#import <Foundation/Foundation.h>
static inline NSString *jbroot(NSString *path){
 NSString *root=NSProcessInfo.processInfo.environment[@"MYB_FIXTURE_ROOT"]?:@"/nonexistent-fixture";
 return [root stringByAppendingString:path.length?path:@"/"];
}
