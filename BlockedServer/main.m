#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>
#import <signal.h>
#import <errno.h>
#import <string.h>
#import <stdio.h>
#import "Brand.h"
#ifndef MYB_BLOCK_PORT
#define MYB_BLOCK_PORT 8788
#endif
#ifndef MYB_WATCH_PORT
#define MYB_WATCH_PORT 8790
#endif
#ifndef MYB_PREVIEW_PORT
#define MYB_PREVIEW_PORT 8789
#endif
static NSDictionary *startupStatus;
#import "../Shared/MYBRuntimeStatus.h"
#import "PeerApp.h"
#import "BrowserBridge.h"
#import "../Shared/MYBInAppAds.h"
#import "../Shared/MYBAdsReport.h"
#import "../Shared/MYBActivityLog.h"
#import "WatchProxy.h"
#import "../Shared/MYBAdsDiscovery.h"
static NSDictionary<NSString *,NSArray<NSString *> *> *MYBAdsBundleMap(void){NSMutableDictionary *m=[NSMutableDictionary dictionary];for(NSDictionary *e in MYBAdsCatalogue())m[e[@"module"]]=e[@"bundles"];return m;}
#import "WebsiteActions.h"
#import "ShieldRoutes.h"
#import "BlockAttribution.h"
#import "BlockedRender.h"
static void report(NSString *text){
 fprintf(stderr,"[MYbloXX® blockd] %s\n",text.UTF8String);
 NSString *root=[[NSFileManager defaultManager] fileExistsAtPath:@"/rootfs/var/mobile"]?@"/rootfs/var/mobile/Library/MYbloXX":@"/var/mobile/Library/MYbloXX";
 [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];NSString *path=[root stringByAppendingPathComponent:@"blockd.log"];
 NSData *line=[[NSString stringWithFormat:@"%@ %@\n",[NSDate date],text] dataUsingEncoding:NSUTF8StringEncoding];NSDictionary *a=[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
 if(!a||[a[NSFileSize] unsignedLongLongValue]>131072){[line writeToFile:path atomically:YES];return;}
 NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];@try{[file seekToEndOfFile];[file writeData:line];[file closeFile];}@catch(__unused NSException *exception){}
}
static int openListener(int port,NSMutableDictionary *results){
 int fd=socket(AF_INET,SOCK_STREAM,0),error=fd<0?errno:0;NSString *stage=@"socket";
 if(fd>=0){int yes=1;setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof(yes));struct sockaddr_in address={0};address.sin_len=sizeof(address);address.sin_family=AF_INET;address.sin_port=htons(port);address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);stage=@"bind";if(bind(fd,(struct sockaddr *)&address,sizeof(address))<0)error=errno;else{stage=@"listen";if(listen(fd,32)<0)error=errno;}}
 if(error){if(fd>=0)close(fd);results[[NSString stringWithFormat:@"%d",port]]=@{@"listening":@NO,@"stage":stage,@"errno":@(error),@"error":[NSString stringWithUTF8String:strerror(error)]};report([NSString stringWithFormat:@"127.0.0.1:%d %@ failed: errno=%d (%s)",port,stage,error,strerror(error)]);return -1;}
 results[[NSString stringWithFormat:@"%d",port]]=@{@"listening":@YES};report([NSString stringWithFormat:@"Listening on 127.0.0.1:%d",port]);return fd;
}
static void serve(int fd,int localPort){
 struct timeval timeout={1,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
 NSMutableData *input=[NSMutableData data];char buffer[2048];BOOL complete=NO;NSTimeInterval deadline=NSDate.timeIntervalSinceReferenceDate+2;
 while(input.length<16384&&NSDate.timeIntervalSinceReferenceDate<deadline){ssize_t n=recv(fd,buffer,MIN(sizeof(buffer),16384-input.length),0);if(n<=0)break;[input appendBytes:buffer length:(NSUInteger)n];NSString *s=[[NSString alloc] initWithData:input encoding:NSISOLatin1StringEncoding];if([s containsString:@"\r\n\r\n"]){complete=YES;break;}}
 NSString *request=complete?[[NSString alloc] initWithData:input encoding:NSISOLatin1StringEncoding]:@"";NSArray *lines=[request componentsSeparatedByString:@"\r\n"];NSArray *first=[lines.firstObject componentsSeparatedByString:@" "];NSMutableDictionary *headers=[NSMutableDictionary dictionary];
 for(NSString *line in lines){NSRange colon=[line rangeOfString:@":"];if(colon.location==NSNotFound)continue;NSString *key=[[line substringToIndex:colon.location] lowercaseString];headers[key]=[[line substringFromIndex:colon.location+1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];}
 // Fetch Metadata is absent for ordinary untrusted HTTP origins. Accept
 // identifies HTML-capable requests when that stronger signal is missing.
 NSString *dest=[headers[@"sec-fetch-dest"] lowercaseString],*mode=[headers[@"sec-fetch-mode"] lowercaseString];BOOL htmlAccept=NO;
 for(NSString *entry in [headers[@"accept"] componentsSeparatedByString:@","]){NSString *type=[[[entry componentsSeparatedByString:@";"] firstObject] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if([type.lowercaseString isEqual:@"text/html"]||[type.lowercaseString isEqual:@"application/xhtml+xml"]){htmlAccept=YES;break;}}
 BOOL document=[dest isEqual:@"document"],fallback=!dest.length&&htmlAccept;
 BOOL navigation=localPort==MYB_BLOCK_PORT&&first.count==3&&[first[0] isEqual:@"GET"]&&(document||fallback)&&(!mode.length||[mode isEqual:@"navigate"]);
 NSString *target=first.count==3?first[1]:@"";NSURLComponents *absolute=[NSURLComponents componentsWithString:target];NSString *route=[target hasPrefix:@"/"]?[target componentsSeparatedByString:@"?"].firstObject:absolute.path;
 NSString *localHost=[NSString stringWithFormat:@"127.0.0.1:%d",localPort],*localName=[NSString stringWithFormat:@"localhost:%d",localPort];BOOL hostIsLocal=[headers[@"host"] isEqual:localHost]||[headers[@"host"] isEqual:localName];BOOL targetIsLocal=[target hasPrefix:@"/"]||([absolute.scheme isEqual:@"http"]&&[@[@"127.0.0.1",@"localhost"] containsObject:absolute.host]&&absolute.port.integerValue==localPort&&!absolute.user.length&&!absolute.password.length);
 // Blocked-host activity (off unless the person turned it on): a request the PAC sent here for another host. Host only, never a path.
 if(localPort==MYB_BLOCK_PORT&&first.count==3&&!hostIsLocal&&!targetIsLocal){NSString *noted=[first[0] isEqual:@"CONNECT"]?first[1]:[NSURLComponents componentsWithString:first[1]].host;if(noted.length)MYBActivityNote(noted,MYBActivityEnabledFast()?MYBPeerAppForClient(fd,localPort):nil,NO);}
 BOOL localGet=first.count==3&&[first[0] isEqual:@"GET"]&&hostIsLocal&&targetIsLocal;
 NSURLComponents *parts=[NSURLComponents componentsWithString:[target hasPrefix:@"/"]?[@"http://127.0.0.1" stringByAppendingString:target]:target];
 BOOL preview=localGet&&[route isEqual:@"/mybloxx-preview"],status=localGet&&[route isEqual:@"/mybloxx-status"],statusPage=localGet&&[route isEqual:@"/mybloxx-status-page"],popupTest=localGet&&[route isEqual:@"/mybloxx-window-test"],popupTarget=localGet&&[route isEqual:@"/mybloxx-window-target"];
 BOOL bridge=localGet&&[headers[@"x-mybloxx-bridge"] isEqual:@"1"],config=bridge&&[route isEqual:@"/mybloxx-browser-config"],event=bridge&&([route isEqual:@"/mybloxx-browser-event"]||[route isEqual:@"/mybloxx-ads-event"]);BOOL adsEvent=event&&[route isEqual:@"/mybloxx-ads-event"];
 BOOL notice=localGet&&[route isEqual:@"/mybloxx-blocked"];NSString *noticeHost=@"This website";for(NSURLQueryItem *item in parts.queryItems)if([item.name isEqual:@"host"]&&item.value.length&&item.value.length<=253)noticeHost=item.value;
 if(adsEvent){NSMutableDictionary *aq=[NSMutableDictionary dictionary];for(NSURLQueryItem *item in parts.queryItems)if(item.value.length<=130)aq[item.name]=item.value;if(!MYBAdsRecordEvent(aq,MYBAdsBundleMap(),NSDate.date.timeIntervalSince1970))event=NO;}
 else if(event&&!recordBrowserEvent(parts.queryItems))event=NO;
 // In-App Ad Blocking discovery (Status > Discovery): pieces from an app, and Settings' start / stop / clear / read. Bridge header required,
 // memory only, and pieces are kept only while a session the person started is open.
 BOOL discoveryPiece=bridge&&[route isEqual:@"/mybloxx-ads-discovery"],discoveryControl=bridge&&[route isEqual:@"/mybloxx-ads-discovery-control"],discoveryRead=bridge&&[route isEqual:@"/mybloxx-ads-discovery-read"];
 NSMutableDictionary *dq=[NSMutableDictionary dictionary];for(NSURLQueryItem *item in parts.queryItems)if(item.value.length<=MYB_ADS_DISCOVERY_CHUNK+8)dq[item.name]=item.value;
 NSString *discoveryBody=nil;NSTimeInterval discoveryNow=NSDate.date.timeIntervalSince1970;
 if(discoveryPiece)discoveryBody=MYBAdsDiscoveryAccept(dq,MYBAdsBundleMap(),discoveryNow)?@"{\"ok\":true}":@"{\"ok\":false}";
 else if(discoveryControl)discoveryBody=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:MYBAdsDiscoveryControl(dq[@"op"],discoveryNow) options:0 error:NULL] encoding:NSUTF8StringEncoding];
 else if(discoveryRead)discoveryBody=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:MYBAdsDiscoverySnapshot(discoveryNow) options:0 error:NULL] encoding:NSUTF8StringEncoding];
 // Ad Network Blocking: an app reports that the library loaded in it; Settings reads who has.
 BOOL sdkLoaded=bridge&&[route isEqual:@"/mybloxx-ads-sdk-loaded"],sdkRead=bridge&&[route isEqual:@"/mybloxx-ads-sdk-read"];
 if(sdkLoaded){NSMutableDictionary *sq=[NSMutableDictionary dictionary];for(NSURLQueryItem *item in parts.queryItems)if(item.value.length<=60)sq[item.name]=item.value;discoveryBody=MYBAdSDKRecordLoaded(sq,discoveryNow)?@"{\"ok\":true}":@"{\"ok\":false}";}
 else if(sdkRead)discoveryBody=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:@{@"ok":@YES,@"apps":MYBAdSDKSeenSnapshot()} options:0 error:NULL] encoding:NSUTF8StringEncoding];
 if(discoveryBody)event=YES; // answered as JSON with 200, like the other bridge events
 NSString *ticket=nil;for(NSURLQueryItem *item in parts.queryItems)if([item.name isEqual:@"request"]&&item.value.length==64)ticket=item.value;
 BOOL canonical=localPort==MYB_BLOCK_PORT&&[headers[@"host"] isEqual:localHost]&&targetIsLocal&&first.count==3;
 NSDictionary *confirmation=(canonical&&localGet&&[route isEqual:@"/mybloxx-allow"])?websiteConfirmation(ticket):nil;
 if([route hasPrefix:@"/mybloxx-allow"]||[route hasPrefix:@"/mybloxx-shield-"]||statusPage||popupTest||popupTarget)navigation=NO;
 BOOL shieldRoute=[route hasPrefix:@"/mybloxx-shield-"];BOOL actionRoute=shieldRoute||[@[@"/mybloxx-allow-apply",@"/mybloxx-allow-status"] containsObject:route];int actionStatus=403;NSDictionary *actionReply=shieldRoute?shieldAction(route,first.count==3?first[0]:@"",headers,canonical,parts.queryItems,&actionStatus):(actionRoute?websiteAction(route,first.count==3?first[0]:@"",headers,canonical,&actionStatus):nil);
 NSString *body=@"";
 if(navigation||preview||notice||confirmation){
  NSString *host=[NSURLComponents componentsWithString:first[1]].host?:headers[@"host"]?:@"This website";if(notice)host=noticeHost;if(host.length>253)host=[host substringToIndex:253];
  NSString *returnURL=nil;if(notice){for(NSURLQueryItem *item in parts.queryItems)if([item.name isEqual:@"url"])returnURL=item.value;if(![[NSURL URLWithString:returnURL].host.lowercaseString isEqual:noticeHost.lowercaseString])returnURL=nil;}else if(navigation&&!hostIsLocal){returnURL=absolute.host?target:[NSString stringWithFormat:@"http://%@%@",headers[@"host"],target];}
  NSString *op=shieldParam(parts.queryItems,@"op",64),*replay=shieldParam(parts.queryItems,@"replay",8),*app=shieldParam(parts.queryItems,@"app",200);
  NSString *allowTicket=(!preview&&!confirmation)?newWebsiteRequest(returnURL,op,replay):nil;
  if(confirmation)host=confirmation[@"domain"];
  NSDictionary *why=preview?@{@"code":@"filter-mode",@"mode":@"Default"}:(confirmation?@{@"code":@"unknown"}:blockedExplanation(returnURL,notice?parts.queryItems:@[]));
  if(notice&&!preview&&!confirmation)MYBShieldRecordActivity(MYBShieldActivityFile(),@"website",app,host,[why[@"code"] isEqual:@"custom-rule"]?@"custom-rule":[why[@"code"] isEqual:@"filter-mode"]?@"filter-mode":@"blocked");
  body=renderBlockedPage(confirmation?@"confirm":@"blocked",host,why,app,confirmation,allowTicket,preview);
 }
 if(config){NSMutableDictionary *cfg=[browserConfig() mutableCopy];cfg[@"bridgeSecret"]=bridgeSecret?:@"";body=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:cfg options:0 error:NULL] encoding:NSUTF8StringEncoding];}
 if(event)body=@"{\"ok\":true}";
 if(discoveryBody)body=discoveryBody;
 if(statusPage)body=[MYBStatusPage stringByReplacingOccurrencesOfString:@"{{MYB_BRAND}}" withString:MYBBrandBase64];
 if(popupTest)body=[MYBPopupTestPage stringByReplacingOccurrencesOfString:@"{{MYB_BRAND}}" withString:MYBBrandBase64];
 if(popupTarget)body=MYBPopupTargetPage;
 if(status)body=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:diagnosticSnapshot() options:NSJSONWritingPrettyPrinted error:NULL] encoding:NSUTF8StringEncoding]?:@"{}";
 if(actionRoute)body=actionReply?[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:actionReply options:0 error:NULL] encoding:NSUTF8StringEncoding]:@"";
 NSData *data=[body dataUsingEncoding:NSUTF8StringEncoding];NSString *head=[NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: %@; charset=utf-8\r\nContent-Length: %lu\r\nCache-Control: no-store\r\nContent-Security-Policy: default-src 'none'; script-src 'sha256-%@'; style-src 'unsafe-inline'; img-src data:; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nConnection: close\r\n\r\n",actionRoute?(actionStatus==202?@"202 Accepted":actionStatus==200?@"200 OK":actionStatus==409?@"409 Conflict":@"403 Forbidden"):(navigation||preview||status||statusPage||popupTest||popupTarget||notice||config||event||confirmation)?@"200 OK":@"403 Forbidden",(status||config||event||actionRoute)?@"application/json":@"text/html",(unsigned long)data.length,popupTest?MYBPopupScriptHash:statusPage?MYBStatusScriptHash:MYBPageScriptHash];NSMutableData *response=[[head dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];[response appendData:data];const char *bytes=response.bytes;NSUInteger sent=0;while(sent<response.length){ssize_t n=send(fd,bytes+sent,response.length-sent,0);if(n<=0)break;sent+=(NSUInteger)n;}close(fd);
}
static void acceptConnections(int server,int port,dispatch_semaphore_t slots){
 while(1){int client=accept(server,NULL,NULL);if(client<0){if(errno==EINTR)continue;report([NSString stringWithFormat:@"accept on %d failed: errno=%d (%s)",port,errno,strerror(errno)]);break;}dispatch_semaphore_wait(slots,DISPATCH_TIME_FOREVER);dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{@autoreleasepool{serve(client,port);}dispatch_semaphore_signal(slots);});}close(server);
}
int main(int argc,const char *argv[]){@autoreleasepool{
 bridgeSecret=websiteToken();browserEvents=[NSMutableDictionary dictionary];websiteRequests=[NSMutableDictionary dictionary];signal(SIGPIPE,SIG_IGN);BOOL diagnose=argc==2&&strcmp(argv[1],"--diagnose")==0;if(argc>1&&!diagnose){fprintf(stderr,"Usage: mybloxx-blockd [--diagnose]\n");return 64;}
 NSMutableDictionary *results=[NSMutableDictionary dictionary];int block=openListener(MYB_BLOCK_PORT,results);int preview=openListener(MYB_PREVIEW_PORT,results);int watch=openListener(MYB_WATCH_PORT,results);
 startupStatus=@{@"version":@MYB_COMPONENT_VERSION,@"pid":@(getpid()),@"uid":@(getuid()),@"euid":@(geteuid()),@"ports":results};
 if(diagnose){NSData *json=[NSJSONSerialization dataWithJSONObject:startupStatus options:NSJSONWritingPrettyPrinted error:NULL];fwrite(json.bytes,1,json.length,stdout);fputs("\nProbe only; ports are closed again. An existing running service can produce Address already in use.\n",stdout);if(block>=0)close(block);if(preview>=0)close(preview);return 0;}
 if(block<0&&preview<0)return 2;dispatch_semaphore_t slots=dispatch_semaphore_create(8);dispatch_queue_t acceptors=dispatch_queue_create("net.myxxdev.mybloxx.blockd.accept",DISPATCH_QUEUE_CONCURRENT);
 if(block>=0)dispatch_async(acceptors,^{acceptConnections(block,MYB_BLOCK_PORT,slots);});if(preview>=0)dispatch_async(acceptors,^{acceptConnections(preview,MYB_PREVIEW_PORT,slots);});if(watch>=0)dispatch_async(acceptors,^{watchAccept(watch);});dispatch_main();
 }return 0;}
