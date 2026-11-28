#import <Foundation/Foundation.h>
static inline NSString *jbroot(NSString *path){return [NSHomeDirectory() stringByAppendingPathComponent:[@"Documents/fixture" stringByAppendingString:path]];}
