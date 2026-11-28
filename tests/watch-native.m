#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#define MYB_RULE_TESTING 1
#import "../Shared/MYBWatch.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static NSString *route(NSString *pac,NSString *host,double nowMs){
 JSContext *c=[JSContext new];c[@"__nowMs"]=@(nowMs);
 [c evaluateScript:@"var __RealDate=Date;Date={now:function(){return __nowMs;}};"];
 [c evaluateScript:pac];JSValue *f=c[@"FindProxyForURL"];return [[f callWithArguments:@[[@"https://" stringByAppendingString:host],host]] toString];
}
int main(void){@autoreleasepool{
 NSString *base=@"function FindProxyForURL(url,host){if(host==='ads.example.com')return 'PROXY 127.0.0.1:8021';return 'DIRECT';}";
 long long until=2000000;NSString *wrapped=MYBWatchWrap(base,until);
 CHECK([route(wrapped,@"site.example.com",1000000) isEqual:@"PROXY 127.0.0.1:8790; DIRECT"],"allowed host goes to the watch service first while watching");
 CHECK([route(wrapped,@"ads.example.com",1000000) isEqual:@"PROXY 127.0.0.1:8021"],"blocked routes are never changed");
 CHECK([route(wrapped,@"site.example.com",2000001) isEqual:@"DIRECT"],"after the end time everything is direct again");
 CHECK([route(wrapped,@"192.168.1.5",1000000) isEqual:@"DIRECT"],"IP literals stay direct");
 CHECK([route(wrapped,@"localhost",1000000) isEqual:@"DIRECT"],"localhost stays direct");
 CHECK([route(wrapped,@"printer",1000000) isEqual:@"DIRECT"],"plain host names stay direct");
 CHECK([route(wrapped,@"mac.local",1000000) isEqual:@"DIRECT"],".local stays direct");
 CHECK([MYBWatchWrap(base,0) isEqual:base],"no end time leaves the PAC untouched");
 CHECK([MYBWatchWrap(@"var x=1;",until) isEqual:@"var x=1;"],"a PAC without FindProxyForURL is untouched");
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",root.UTF8String,1);
 CHECK(MYBWatchStoredMillis()==0&&!MYBWatchActive()&&MYBWatchSecondsLeft()==0,"not watching by default");
 [NSFileManager.defaultManager createDirectoryAtPath:MYBWatchFile().stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
 [[NSString stringWithFormat:@"%lld",(long long)(NSDate.date.timeIntervalSince1970*1000)+300000] writeToFile:MYBWatchFile() atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 CHECK(MYBWatchActive()&&MYBWatchSecondsLeft()>290,"an end time in the future is active");
 [@"1000" writeToFile:MYBWatchFile() atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 CHECK(!MYBWatchActive()&&MYBWatchSecondsLeft()==0&&MYBWatchStoredMillis()==1000,"an old end time is not active");
 if(failures){fprintf(stderr,"%d failures\n",failures);return 1;}puts("Watch overlay native checks passed.");
}return 0;}
