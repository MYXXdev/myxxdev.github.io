#pragma once
// Watch everything. For a limited time the PAC offers every connection that would go DIRECT to the local watch service first
// ("PROXY 127.0.0.1:8790; DIRECT"), so the Activity list can show allowed websites too. The end time is written into the PAC
// itself and checked there, so watching stops by itself even if nothing runs afterwards; the helper also removes the marker.
// Blocked routes are never touched, and the fallback keeps a connection direct if the service is not there.
#import <Foundation/Foundation.h>
#import "MYBWebsiteRules.h"
#define MYB_WATCH_PORT_TEXT "8790"
static inline NSString *MYBWatchFile(void){return MYBRuleFile(@"var/mobile/Library/MYbloXX/WatchUntil");}
// The stored end time in epoch milliseconds, or 0. Expired values are returned too: the installed PAC and the PAC the current
// settings produce must stay identical until the marker is removed, and the PAC itself ignores an expired end time.
static inline long long MYBWatchStoredMillis(void){
 NSString *text=[NSString stringWithContentsOfFile:MYBWatchFile() encoding:NSUTF8StringEncoding error:NULL];
 long long value=[text longLongValue];return value>0?value:0;
}
static inline BOOL MYBWatchActive(void){return MYBWatchStoredMillis()>(long long)(NSDate.date.timeIntervalSince1970*1000);}
// Seconds left, 0 when not watching.
static inline NSInteger MYBWatchSecondsLeft(void){long long left=MYBWatchStoredMillis()-(long long)(NSDate.date.timeIntervalSince1970*1000);return left>0?(NSInteger)(left/1000):0;}
static inline NSString *MYBWatchWrap(NSString *pac,long long untilMillis){
 if(!pac||untilMillis<=0||![pac containsString:@"function FindProxyForURL"])return pac;
 // Assigned, not redeclared: a second function declaration would replace the original before it could be kept.
 return [pac stringByAppendingFormat:@"\nvar __mybWatchOriginal=FindProxyForURL;\nFindProxyForURL=function(url,host){var r=__mybWatchOriginal(url,host);if(r===\"DIRECT\"&&Date.now()<%lld&&!/^[0-9.]+$/.test(host)&&host.indexOf(\".\")>0&&host!==\"localhost\"&&!/\\.local$/.test(host))return \"PROXY 127.0.0.1:%s; DIRECT\";return r;};\n",untilMillis,MYB_WATCH_PORT_TEXT];
}
