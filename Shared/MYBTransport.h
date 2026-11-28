#import <Foundation/Foundation.h>
// Translate the historical blocked sink only at the local serving boundary.
// Stored/upstream PACs, their checksums and the special BYPASS route stay intact.
static NSString *MYBTransportPACText(NSString *text){
 static NSRegularExpression *route;static dispatch_once_t once;
 dispatch_once(&once,^{route=[NSRegularExpression regularExpressionWithPattern:@"\\bPROXY[ \\t]+127\\.0\\.0\\.1:8021(?=[\\\"';\\s]|$)" options:0 error:NULL];});
 return [route stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0,text.length) withTemplate:@"PROXY 127.0.0.1:8788"];
}
