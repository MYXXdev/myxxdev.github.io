#pragma once
// MYbloXX® Connection Inspector, diagnostic session. Opt-in, local, short and bounded. A session records only when it started and stopped; what it shows is the
// website activity MYbloXX® already keeps, limited to that window. It does not hook anything, touch the PAC apply path, network services or radio settings.
// The export holds domain names, the decision and (if asked) the app name and a count: never a full URL, query string, credential or page content.
#import <Foundation/Foundation.h>
#define MYB_DIAG_MAX_SECONDS 1800.0
#define MYB_DIAG_MAX_ROWS 150
#define MYB_DIAG_KEEP_SECONDS 86400.0
static inline NSDictionary *MYBDiagState(NSString *file,double now){
 NSDictionary *raw=[NSDictionary dictionaryWithContentsOfFile:file];
 double start=[[raw objectForKey:@"start"] doubleValue],end=[[raw objectForKey:@"end"] doubleValue];
 if(start<=0)return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],@"active",[NSNumber numberWithDouble:0],@"start",[NSNumber numberWithDouble:0],@"end",nil];
 if(end<=0&&now-start>=MYB_DIAG_MAX_SECONDS)end=start+MYB_DIAG_MAX_SECONDS;               // a session that was never stopped ends by itself
 if(end>0&&now-end>MYB_DIAG_KEEP_SECONDS){[NSFileManager.defaultManager removeItemAtPath:file error:NULL];return MYBDiagState(file,now);}   // old results clear themselves
 return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:end<=0],@"active",[NSNumber numberWithDouble:start],@"start",[NSNumber numberWithDouble:end],@"end",nil];
}
static inline BOOL MYBDiagStart(NSString *file,double now){
 NSDictionary *d=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:now],@"start",nil];return [d writeToFile:file atomically:YES];}
static inline BOOL MYBDiagStop(NSString *file,double now){
 NSDictionary *state=MYBDiagState(file,now);if(![[state objectForKey:@"active"] boolValue])return YES;
 NSDictionary *d=[NSDictionary dictionaryWithObjectsAndKeys:[state objectForKey:@"start"],@"start",[NSNumber numberWithDouble:now],@"end",nil];return [d writeToFile:file atomically:YES];}
static inline BOOL MYBDiagClear(NSString *file){[NSFileManager.defaultManager removeItemAtPath:file error:NULL];return ![NSFileManager.defaultManager fileExistsAtPath:file];}
static inline BOOL MYBDiagSafeHost(NSString *host){return host.length>0&&host.length<=253&&[host rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#@:& =%"]].location==NSNotFound;}
// hosts: the Activity list (host, b, a, last, apps). include: apps / counts as NSNumber booleans. Returns the text the person previews before sharing.
static inline NSString *MYBDiagExport(NSArray *hosts,NSDictionary *state,BOOL includeApps,BOOL includeCounts,NSArray *allowRules,NSArray *blockRules){
 double start=[[state objectForKey:@"start"] doubleValue],end=[[state objectForKey:@"end"] doubleValue];
 NSMutableArray *lines=[NSMutableArray array];NSUInteger shown=0;
 for(NSDictionary *h in hosts){
  NSString *host=[h objectForKey:@"host"];double last=[[h objectForKey:@"last"] doubleValue];
  if(!MYBDiagSafeHost(host)||last<start||(end>0&&last>end))continue;
  if(shown>=MYB_DIAG_MAX_ROWS)break;
  NSInteger b=[[h objectForKey:@"b"] integerValue],a=[[h objectForKey:@"a"] integerValue];
  NSString *why=@"seen";BOOL ruled=NO;
  for(NSString *r in allowRules)if([host isEqualToString:r]||[host hasSuffix:[@"." stringByAppendingString:r]]){why=@"allowed by your rule";ruled=YES;break;}
  if(!ruled)for(NSString *r in blockRules)if([host isEqualToString:r]||[host hasSuffix:[@"." stringByAppendingString:r]]){why=@"blocked by your rule";ruled=YES;break;}
  NSString *decision=ruled?why:(a>b?@"allowed":@"blocked");
  NSMutableString *line=[NSMutableString stringWithFormat:@"%@ - %@",host,decision];
  if(includeCounts)[line appendFormat:@" - %ld",(long)(a>b?a:b)];
  if(includeApps){NSDictionary *apps=[h objectForKey:@"apps"];if([apps isKindOfClass:NSDictionary.class]&&apps.count)[line appendFormat:@" - %@",[[apps.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "]];}
  [lines addObject:line];shown++;
 }
 if(!lines.count)return @"Nothing was recorded during this session.";
 return [NSString stringWithFormat:@"MYbloXX connection session\n%@\n\n%@",@"Domains only. No full links, no query strings, no page content.",[lines componentsJoinedByString:@"\n"]];
}
