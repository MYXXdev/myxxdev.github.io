#import "../Shared/MYBTransport.h"
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc!=3)return 64;
 NSString *example=@"var x='PROXY 127.0.0.1:8021'; var y=\"PROXY 8.8.8.8:53\"; var z='PROXY 127.0.0.1:80210'; var u='http://127.0.0.1:8021/';";
 NSString *converted=MYBTransportPACText(example);
 if(![converted containsString:@"'PROXY 127.0.0.1:8788'"]||![converted containsString:@"PROXY 8.8.8.8:53"]||![converted containsString:@"PROXY 127.0.0.1:80210"]||![converted containsString:@"http://127.0.0.1:8021/"])return 1;
 NSString *input=[NSString stringWithUTF8String:argv[1]],*output=[NSString stringWithUTF8String:argv[2]];
 if(![NSFileManager.defaultManager createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:NULL])return 2;
 for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:input error:NULL]){
  if(![name.pathExtension isEqual:@"pac"])continue;NSString *text=[NSString stringWithContentsOfFile:[input stringByAppendingPathComponent:name] encoding:NSUTF8StringEncoding error:NULL];if(!text||![MYBTransportPACText(text) writeToFile:[output stringByAppendingPathComponent:name] atomically:YES encoding:NSUTF8StringEncoding error:NULL])return 3;
 }
 printf("Native PAC transport transformation completed.\n");
 }return 0;}
