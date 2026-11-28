#pragma once
// Watch proxy: passes allowed connections through so they can be counted. It only ever receives traffic while "Watch everything"
// is on (the PAC then offers it as "PROXY 127.0.0.1:8790; DIRECT"), and it never decides anything: every connection is passed on
// unchanged. It listens on this device's loopback address only, refuses to connect back to the device itself, and holds no
// request or response data beyond what it is relaying. For each connection it keeps only the website name (and, afterwards,
// which app asked) for the Activity list, and only while that list is on.
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/resource.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <poll.h>
#import <fcntl.h>
#import <pthread.h>
#import <unistd.h>
#import <errno.h>
#ifndef MYB_WATCH_PORT
#define MYB_WATCH_PORT 8790
#endif
#define MYB_WATCH_MAX_CONNECTIONS 320
#define MYB_WATCH_HEAD_MAX 16384
static int gWatchOpen=0;
static BOOL watchWriteAll(int fd,const void *bytes,size_t length){
 const uint8_t *p=bytes;
 while(length){ssize_t n=send(fd,p,length,0);if(n<0&&errno==EINTR)continue;if(n<=0)return NO;p+=n;length-=(size_t)n;}
 return YES;
}
// Connects to host:port, trying each address; refuses loopback so the proxy can never be pointed back at this device.
static int watchConnect(NSString *host,int port){
 struct addrinfo hints;memset(&hints,0,sizeof(hints));hints.ai_socktype=SOCK_STREAM;hints.ai_family=AF_UNSPEC;struct addrinfo *res=NULL;char service[8];snprintf(service,sizeof(service),"%d",port);
 if(getaddrinfo(host.UTF8String,service,&hints,&res)!=0||!res)return -1;
 int result=-1;
 for(struct addrinfo *a=res;a&&result<0;a=a->ai_next){
  if(a->ai_family==AF_INET&&(ntohl(((struct sockaddr_in *)a->ai_addr)->sin_addr.s_addr)>>24)==127)continue;
  if(a->ai_family==AF_INET6&&IN6_IS_ADDR_LOOPBACK(&((struct sockaddr_in6 *)a->ai_addr)->sin6_addr))continue;
  int fd=socket(a->ai_family,a->ai_socktype,a->ai_protocol);if(fd<0)continue;
  int flags=fcntl(fd,F_GETFL,0);fcntl(fd,F_SETFL,flags|O_NONBLOCK);
  int rc=connect(fd,a->ai_addr,a->ai_addrlen);BOOL ok=rc==0;
  if(rc<0&&errno==EINPROGRESS){struct pollfd pfd={.fd=fd,.events=POLLOUT};if(poll(&pfd,1,8000)==1){int err=0;socklen_t len=sizeof(err);getsockopt(fd,SOL_SOCKET,SO_ERROR,&err,&len);ok=err==0;}}
  if(!ok){close(fd);continue;}
  fcntl(fd,F_SETFL,flags);int yes=1;setsockopt(fd,IPPROTO_TCP,TCP_NODELAY,&yes,sizeof(yes));setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&yes,sizeof(yes));
  result=fd;
 }
 freeaddrinfo(res);return result;
}
// Relays both directions until both ends are done or nothing has moved for 5 minutes.
static void watchRelay(int a,int b){
 uint8_t *buffer=malloc(16384);if(!buffer)return;BOOL aOpen=YES,bOpen=YES;int idle=0;
 while((aOpen||bOpen)&&idle<300){
  struct pollfd fds[2]={{.fd=aOpen?a:-1,.events=POLLIN},{.fd=bOpen?b:-1,.events=POLLIN}};
  int ready=poll(fds,2,1000);if(ready<0){if(errno==EINTR)continue;break;}
  if(ready==0){idle++;continue;}idle=0;
  for(int i=0;i<2;i++){
   if(!(fds[i].revents&(POLLIN|POLLHUP|POLLERR)))continue;
   int from=i==0?a:b,to=i==0?b:a;ssize_t n=recv(from,buffer,16384,0);
   if(n<=0){if(i==0)aOpen=NO;else bOpen=NO;shutdown(to,SHUT_WR);continue;}
   if(!watchWriteAll(to,buffer,(size_t)n)){aOpen=bOpen=NO;}
  }
 }
 free(buffer);
}
static BOOL watchHostAllowed(NSString *host){return host.length&&host.length<=253&&![host hasPrefix:@"["]&&[host rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" \r\n\t/@\\"]].location==NSNotFound;}
static void watchSplitHostPort(NSString *hostPort,int defaultPort,NSString **host,int *port){
 NSRange colon=[hostPort rangeOfString:@":" options:NSBackwardsSearch];*port=defaultPort;*host=hostPort;
 if(colon.location!=NSNotFound){int p=[[hostPort substringFromIndex:colon.location+1] intValue];if(p>0&&p<65536){*port=p;*host=[hostPort substringToIndex:colon.location];}}
}
static void watchServe(int client){
 int yes=1;setsockopt(client,SOL_SOCKET,SO_NOSIGPIPE,&yes,sizeof(yes));struct timeval timeout={10,0};setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
 struct sockaddr_in peer;socklen_t peerLength=sizeof(peer);int clientPort=getpeername(client,(struct sockaddr *)&peer,&peerLength)==0&&peer.sin_family==AF_INET?ntohs(peer.sin_port):0;
 NSMutableData *input=[NSMutableData data];uint8_t chunk[2048];NSRange end={NSNotFound,0};
 while(input.length<MYB_WATCH_HEAD_MAX){
  ssize_t n=recv(client,chunk,sizeof(chunk),0);if(n<=0)return;[input appendBytes:chunk length:(NSUInteger)n];
  end=[input rangeOfData:[NSData dataWithBytes:"\r\n\r\n" length:4] options:0 range:NSMakeRange(0,input.length)];if(end.location!=NSNotFound)break;
 }
 if(end.location==NSNotFound)return;
 struct timeval none={0,0};setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&none,sizeof(none));
 NSString *head=[[NSString alloc] initWithData:[input subdataWithRange:NSMakeRange(0,end.location)] encoding:NSISOLatin1StringEncoding];
 NSData *rest=[input subdataWithRange:NSMakeRange(end.location+4,input.length-end.location-4)];
 NSArray<NSString *> *lines=[head componentsSeparatedByString:@"\r\n"];NSArray<NSString *> *first=[lines.firstObject componentsSeparatedByString:@" "];
 const char *bad="HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n";
 if(first.count!=3){watchWriteAll(client,bad,strlen(bad));return;}
 NSString *method=first[0],*target=first[1],*host=nil;int port=0;int upstream=-1;NSData *prefix=nil;
 if([method isEqual:@"CONNECT"]){
  watchSplitHostPort(target,443,&host,&port);
  if(!watchHostAllowed(host)){watchWriteAll(client,bad,strlen(bad));return;}
 }else{
  NSURLComponents *url=[NSURLComponents componentsWithString:target];
  if(![url.scheme.lowercaseString isEqual:@"http"]||!url.host.length){watchWriteAll(client,bad,strlen(bad));return;}
  host=url.host;port=url.port?url.port.intValue:80;if(!watchHostAllowed(host)||port<=0||port>65535){watchWriteAll(client,bad,strlen(bad));return;}
  NSString *path=url.percentEncodedPath.length?url.percentEncodedPath:@"/";if(url.percentEncodedQuery.length)path=[path stringByAppendingFormat:@"?%@",url.percentEncodedQuery];
  // Rewrite the request for the origin server: ordinary path, no proxy headers, one request per connection.
  NSMutableString *out=[NSMutableString stringWithFormat:@"%@ %@ %@\r\n",method,path,first[2]];BOOL sawConnection=NO;
  for(NSUInteger i=1;i<lines.count;i++){
   NSString *line=lines[i];NSString *lower=line.lowercaseString;
   if([lower hasPrefix:@"proxy-connection:"]||[lower hasPrefix:@"proxy-authorization:"])continue;
   if([lower hasPrefix:@"connection:"]){if(!sawConnection)[out appendString:@"Connection: close\r\n"];sawConnection=YES;continue;}
   [out appendFormat:@"%@\r\n",line];
  }
  if(!sawConnection)[out appendString:@"Connection: close\r\n"];[out appendString:@"\r\n"];prefix=[out dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
 }
 // Count it (website name only); the app is looked up afterwards, off the data path, while the connection is still open.
 if(MYBActivityEnabledFast()){
  NSString *counted=host;int serverPort=MYB_WATCH_PORT;
  static dispatch_queue_t lookup;static dispatch_once_t once;static volatile int queued=0;dispatch_once(&once,^{lookup=dispatch_queue_create("net.myxxdev.mybloxx.watch.lookup",DISPATCH_QUEUE_SERIAL);});
  if(queued<64&&clientPort>0){__atomic_add_fetch(&queued,1,__ATOMIC_RELAXED);dispatch_async(lookup,^{NSDictionary *app=MYBPeerAppForPort(clientPort,serverPort);MYBActivityNote(counted,app,YES);__atomic_sub_fetch(&queued,1,__ATOMIC_RELAXED);});}
  else MYBActivityNote(counted,nil,YES);
 }
 upstream=watchConnect(host,port);
 if(upstream<0){const char *gateway="HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\nContent-Length: 0\r\n\r\n";watchWriteAll(client,gateway,strlen(gateway));return;}
 if([method isEqual:@"CONNECT"]){
  const char *ok="HTTP/1.1 200 Connection Established\r\n\r\n";if(!watchWriteAll(client,ok,strlen(ok))){close(upstream);return;}
  if(rest.length&&!watchWriteAll(upstream,rest.bytes,rest.length)){close(upstream);return;}
 }else{
  if(!watchWriteAll(upstream,prefix.bytes,prefix.length)||(rest.length&&!watchWriteAll(upstream,rest.bytes,rest.length))){close(upstream);return;}
 }
 watchRelay(client,upstream);close(upstream);
}
static void *watchThread(void *arg){
 int client=(int)(intptr_t)arg;@autoreleasepool{watchServe(client);}close(client);__atomic_sub_fetch(&gWatchOpen,1,__ATOMIC_RELAXED);return NULL;
}
static void watchAccept(int server){
 // Each relayed connection uses two descriptors; raise the limit well above the default.
 struct rlimit limit;if(getrlimit(RLIMIT_NOFILE,&limit)==0&&limit.rlim_cur<4096){limit.rlim_cur=MIN((rlim_t)4096,limit.rlim_max);setrlimit(RLIMIT_NOFILE,&limit);}
 while(1){
  int client=accept(server,NULL,NULL);if(client<0){if(errno==EINTR||errno==ECONNABORTED)continue;if(errno==EMFILE||errno==ENFILE){usleep(100000);continue;}break;}
  if(__atomic_add_fetch(&gWatchOpen,1,__ATOMIC_RELAXED)>MYB_WATCH_MAX_CONNECTIONS){__atomic_sub_fetch(&gWatchOpen,1,__ATOMIC_RELAXED);close(client);continue;}
  pthread_attr_t attr;pthread_attr_init(&attr);pthread_attr_setdetachstate(&attr,PTHREAD_CREATE_DETACHED);pthread_attr_setstacksize(&attr,256*1024);pthread_t thread;
  if(pthread_create(&thread,&attr,watchThread,(void *)(intptr_t)client)!=0){__atomic_sub_fetch(&gWatchOpen,1,__ATOMIC_RELAXED);close(client);}
  pthread_attr_destroy(&attr);
 }
}
