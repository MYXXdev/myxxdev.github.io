#import <Foundation/Foundation.h>
#import "../Shared/MYBTransport.h"
#import "../Shared/MYBWebsiteRules.h"
#import "../Shared/MYBRuleStore.h"
#import "../Shared/MYBSetupBackup.h"
#import "../Shared/MYBEffectivePAC.h"
#import "../Shared/MYBProfiles.h"
#import "../Shared/MYBAppControl.h"
#import <arpa/inet.h>
#import <errno.h>
#import <netinet/in.h>
#import <signal.h>
#import <spawn.h>
#import <mach-o/dyld.h>
extern char **environ;
#import <sys/socket.h>
#import <sys/types.h>
#import <sys/time.h>
#import <unistd.h>
#import <fcntl.h>
#include <string.h>

#ifndef MYB_PAC_PORT
#define MYB_PAC_PORT 8787
#endif
static NSString *bootstrapRoot(void) {
#ifdef MYB_SERVER_TESTING
 NSString *fixture=NSProcessInfo.processInfo.environment[@"MYB_FIXTURE_ROOT"];if(fixture.length)return fixture;
#endif
 uint32_t size=0;_NSGetExecutablePath(NULL,&size);
 if(size==0 || size>32768)return @"/";
 char *buf=calloc((size_t)size+1,1);
 NSString *path=nil;
 if(buf && _NSGetExecutablePath(buf,&size)==0)
   path=[NSString stringWithUTF8String:buf];
 free(buf);
 NSRange r=[path rangeOfString:@"/usr/libexec/mybloxx-pacd" options:NSBackwardsSearch];
 if(r.location!=NSNotFound){NSString *root=[path substringToIndex:r.location];return root.length?root:@"/";} return @"/";
}
static NSArray<NSString *> *candidatePACPaths(NSString *file) {
 NSString *root=bootstrapRoot();
 NSMutableArray<NSString *> *paths=[NSMutableArray array];
 // The local PAC daemon runs natively, so use its writable jailbreak root.
 // Prioritize updated PACCurrent files and user rules over bundled defaults.
 for(NSString *folder in @[
   [root stringByAppendingPathComponent:@"var/mobile/Library/MYbloXX/PACCurrent"],
   [root stringByAppendingPathComponent:@"var/mobile/Library/MYbloXX/PAC"],
   [root stringByAppendingPathComponent:@"usr/share/mybloxx/pacs"]]) {
    NSString *candidate=[folder stringByAppendingPathComponent:file];
    if(![paths containsObject:candidate])[paths addObject:candidate];
 }
 return paths;
}
static NSData *loadPAC(NSString *file) {
 for(NSString *candidate in candidatePACPaths(file)) {
  NSError *error=nil;
  NSData *data=[NSData dataWithContentsOfFile:candidate options:NSDataReadingMappedIfSafe error:&error];
  if(data.length>=100 && data.length<=2*1024*1024) {
   NSString *text=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
   if([text containsString:@"function FindProxyForURL"])return data;
  }
  NSLog(@"[MYbloXX® PAC] Tried %@: %@",candidate,
      error.localizedDescription?:@"not a valid readable PAC");
 }
 return nil;
}
// Diagnostic-only: log PAC fetches, never requested browsing URLs.
// A successful fetch only proves the PAC file was retrieved, not evaluated.
static void recordPACFetch(NSString *filename) {
 NSString *dir=[bootstrapRoot() stringByAppendingPathComponent:@"var/mobile/Library/MYbloXX"];
 NSString *file=[dir stringByAppendingPathComponent:@"PACFetchDiagnostics.log"];
 [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *line=[NSString stringWithFormat:@"%@ PAC_FETCH %@\n",[NSDate date],filename];
 NSData *bytes=[line dataUsingEncoding:NSUTF8StringEncoding];
 int fd=open(file.fileSystemRepresentation,O_WRONLY|O_APPEND|O_CREAT|O_NOFOLLOW,0644);
 if(fd>=0) {
  (void)write(fd,bytes.bytes,bytes.length);
  close(fd);
 }
}
static BOOL writeAll(int fd,const void *ptr,size_t length) {
 const uint8_t *data=ptr;
 while(length) {
  ssize_t bytes=send(fd,data,length,0);
  if(bytes<=0){if(bytes<0&&errno==EINTR)continue;return NO;}
  data+=bytes;length-=(size_t)bytes;
 }
 return YES;
}
static BOOL serve(int client) {
 struct timeval timeout={.tv_sec=4,.tv_usec=0};
 setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
 setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
 char request[2048]={0};
 // TCP may split the request line or headers across multiple packets.
 size_t received=0;
 while(received<sizeof(request)-1 && !strstr(request,"\r\n\r\n")) {
  ssize_t part=recv(client,request+received,sizeof(request)-1-received,0);
  if(part<0 && errno==EINTR)continue;
  if(part<=0)return NO;
  received+=(size_t)part;
  request[received]=0;
 }
 if(!strstr(request,"\r\n\r\n"))return NO;
 ssize_t n=(ssize_t)received;
 NSString *line=[[NSString alloc] initWithBytes:request length:(NSUInteger)n encoding:NSASCIIStringEncoding];
 if(!line)return NO;
 NSRange end=[line rangeOfString:@"\r\n"];
 if(end.location==NSNotFound)return NO;
 NSString *requestLine=[line substringToIndex:end.location];
 NSArray *tokens=[requestLine componentsSeparatedByString:@" "];
 if(tokens.count!=3 || ![tokens[0] isEqualToString:@"GET"])return NO;
 NSString *path=[tokens[1] componentsSeparatedByString:@"?"].firstObject;
 if([path isEqualToString:@"/health"]) {
  NSData *body=[@"MYbloXX-PAC-READY\n" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *header=[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nCache-Control: no-store\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",(unsigned long)body.length];
  NSData *headers=[header dataUsingEncoding:NSASCIIStringEncoding];
  return writeAll(client,headers.bytes,headers.length)&&writeAll(client,body.bytes,body.length);
 }
 if([path isEqual:@"/app-config"]){
  NSURLComponents *query=[NSURLComponents componentsWithString:tokens[1]];NSString *app=nil;for(NSURLQueryItem *item in query.queryItems)if([item.name isEqual:@"app"])app=item.value;
  if(!app.length||app.length>255||[app rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"].invertedSet].location!=NSNotFound)return NO;
  NSDictionary *prefs=[NSDictionary dictionaryWithContentsOfFile:[bootstrapRoot() stringByAppendingPathComponent:@"var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist"]]?:@{};NSMutableDictionary *filtered=[NSMutableDictionary dictionary];
  for(NSString *key in prefs)if([@[@"Uninstalling",[@"enabled-" stringByAppendingString:app]] containsObject:key])filtered[key]=prefs[key];
  NSData *body=[NSJSONSerialization dataWithJSONObject:filtered options:0 error:NULL];if(!body)return NO;NSString *header=[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",(unsigned long)body.length];NSData *h=[header dataUsingEncoding:NSASCIIStringEncoding];return writeAll(client,h.bytes,h.length)&&writeAll(client,body.bytes,body.length);
 }
 if([path hasPrefix:@"/dns/"]){
  NSString *file=[path substringFromIndex:5],*name=file.stringByDeletingPathExtension;
  if([file.pathExtension isEqual:@"mobileconfig"]&&[MYBDNSProfileNames() containsObject:name]&&[file isEqual:[name stringByAppendingString:@".mobileconfig"]]){
   NSData *body=[NSData dataWithContentsOfFile:[[bootstrapRoot() stringByAppendingPathComponent:@"usr/share/mybloxx/dns"] stringByAppendingPathComponent:file]];
   if(body.length){NSString *header=[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config\r\nContent-Disposition: attachment; filename=\"%@\"\r\nCache-Control: no-store\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",file,(unsigned long)body.length];NSData *h=[header dataUsingEncoding:NSUTF8StringEncoding];return writeAll(client,h.bytes,h.length)&&writeAll(client,body.bytes,body.length);}
  }
  const char *notFound="HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";writeAll(client,notFound,strlen(notFound));return NO;
 }
 if([path hasPrefix:@"/profiles/"]){
  NSString *file=[path substringFromIndex:10],*name=file.stringByDeletingPathExtension;
  if([file.pathExtension isEqual:@"mobileconfig"]&&[MYBLegacyProfileNames() containsObject:name]&&[file isEqual:[name stringByAppendingString:@".mobileconfig"]]){
   NSData *body=[NSData dataWithContentsOfFile:[[bootstrapRoot() stringByAppendingPathComponent:@"usr/share/mybloxx/profiles"] stringByAppendingPathComponent:file]];
   if(body.length){NSString *header=[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config\r\nContent-Disposition: attachment; filename=\"%@\"\r\nCache-Control: no-store\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",file,(unsigned long)body.length];NSData *h=[header dataUsingEncoding:NSUTF8StringEncoding];return writeAll(client,h.bytes,h.length)&&writeAll(client,body.bytes,body.length);}
  }
  const char *notFound="HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";writeAll(client,notFound,strlen(notFound));return NO;
 }
 static NSSet *names;
 static dispatch_once_t once;
 dispatch_once(&once,^{
    names=[NSSet setWithArray:@[@"Default.pac",@"allowY.pac",@"blockAdSense.pac",@"blockApple.pac",@"blockSocials.pac",@"blockXXX.pac",@"Custom.pac",@"MYbloXX.pac",@"MYbloXXTest.pac",@"MYbloXXallowFB.pac",@"MYbloXXallowY.pac",@"MYbloXXnoApple.pac",@"MYbloXXnoFB.pac",@"MYbloXXnoSocials.pac",@"MYbloXXnoXXX.pac"]];
 });
 NSString *filename=[path hasPrefix:@"/"]?[path substringFromIndex:1]:@"";
 if([names containsObject:filename])recordPACFetch(filename);
 if(![names containsObject:filename]) {
  const char *response="HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
  writeAll(client,response,strlen(response));return NO;
 }
 NSData *content=loadPAC(filename);
 if(!content || content.length<100 || content.length>2*1024*1024) {
  NSLog(@"[MYbloXX® PAC] 503 %@: no readable valid PAC in %@",filename,candidatePACPaths(filename));
  const char *response="HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
  writeAll(client,response,strlen(response));return NO;
 }
 NSString *text=[[NSString alloc] initWithData:content encoding:NSUTF8StringEncoding];
 if(![text containsString:@"function FindProxyForURL"])return NO;
 // Keep global MYbloXX custom allow/block rules distinct from Shield.
 // Overlay on the selected base PAC without rewriting the source file.
 NSString *root=bootstrapRoot();
 NSString *layered=MYBEffectivePACText([filename stringByDeletingPathExtension],@[
   [root stringByAppendingPathComponent:@"var/mobile/Library/MYbloXX/PACCurrent"],
   [root stringByAppendingPathComponent:@"var/mobile/Library/MYbloXX/PAC"],
   [root stringByAppendingPathComponent:@"usr/share/mybloxx/pacs"]],
   [root stringByAppendingPathComponent:@"var/mobile/Library/MYbloXX/AppliedRules.plist"],MYBWebsiteFile());
 if(!layered)return NO;
 content=[layered dataUsingEncoding:NSUTF8StringEncoding];
 NSString *header=[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: application/x-ns-proxy-autoconfig\r\nCache-Control: no-cache, no-store\r\nContent-Length: %lu\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\n",(unsigned long)content.length];
 NSData *headers=[header dataUsingEncoding:NSASCIIStringEncoding];
 return writeAll(client,headers.bytes,headers.length)&&writeAll(client,content.bytes,content.length);
}
int main(void) {
 @autoreleasepool {
  signal(SIGPIPE,SIG_IGN);
  NSLog(@"[MYbloXX® PAC] Starting offline server; executable root=%@",bootstrapRoot());
  int fd=socket(AF_INET,SOCK_STREAM,0);
  if(fd<0)return 71;
  int reuse=1;setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,&reuse,sizeof(reuse));
  struct sockaddr_in addr={0};
  addr.sin_family=AF_INET;
  addr.sin_port=htons(MYB_PAC_PORT);
  addr.sin_addr.s_addr=htonl(INADDR_LOOPBACK); // never bind Wi-Fi interface
  if(bind(fd,(const struct sockaddr *)&addr,sizeof(addr))!=0){NSLog(@"[MYbloXX® PAC] bind failed errno=%d",errno);close(fd);return 73;}
  if(listen(fd,8)!=0){NSLog(@"[MYbloXX® PAC] listen failed errno=%d",errno);close(fd);return 74;}
  // pacd is no longer the PAC transport: system protection embeds the effective PAC inline.
  // It stays for local clients (App Control settings, blocked-page attribution, legacy profiles).
  // Restoring protection after a re-jailbreak belongs to the restore job and the runtime
  // watcher, never to this server, so restarting it can no longer trigger configd restarts.
  for(;;) {
   int client=accept(fd,NULL,NULL);
   if(client<0){if(errno==EINTR)continue;break;}
   @autoreleasepool {serve(client);}
   close(client);
  }
  close(fd);
  return 1;
 }
}


