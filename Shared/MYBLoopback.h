#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <fcntl.h>
#import <poll.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
#ifndef MYB_BRIDGE_PORT
#define MYB_BRIDGE_PORT 8788
#endif
// Bounded direct loopback request. Never uses system proxy settings or ATS.
static NSData *MYBLoopbackRequest(int port,NSString *method,NSString *path,NSString *secret){
 int fd=socket(AF_INET,SOCK_STREAM,0);if(fd<0)return nil;
 int flags=fcntl(fd,F_GETFL,0);fcntl(fd,F_SETFL,flags|O_NONBLOCK);struct sockaddr_in address;memset(&address,0,sizeof(address));address.sin_len=sizeof(address);address.sin_family=AF_INET;address.sin_port=htons(port);address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 int rc=connect(fd,(struct sockaddr *)&address,sizeof(address));if(rc<0&&errno!=EINPROGRESS){close(fd);return nil;}if(rc<0){struct pollfd p;memset(&p,0,sizeof(p));p.fd=fd;p.events=POLLOUT;int error=0;socklen_t size=sizeof(error);if(poll(&p,1,150)<=0||getsockopt(fd,SOL_SOCKET,SO_ERROR,&error,&size)<0||error){close(fd);return nil;}}
 fcntl(fd,F_SETFL,flags);struct timeval timeout;timeout.tv_sec=0;timeout.tv_usec=250000;setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));int yes=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&yes,sizeof(yes));
 NSString *extra=secret.length?[NSString stringWithFormat:@"X-MYbloXX-Bridge-Secret: %@\r\n",secret]:@"";NSString *length=[method isEqual:@"POST"]?@"Content-Length: 0\r\n":@"";NSData *request=[[NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nX-MYbloXX-Bridge: 1\r\n%@%@Connection: close\r\n\r\n",method,path,port,extra,length] dataUsingEncoding:NSUTF8StringEncoding];NSUInteger sent=0;while(sent<request.length){ssize_t n=send(fd,(const char *)request.bytes+sent,request.length-sent,0);if(n<=0){close(fd);return nil;}sent+=(NSUInteger)n;}
 NSMutableData *response=[NSMutableData data];char bytes[8192];NSTimeInterval end=NSDate.timeIntervalSinceReferenceDate+.35;while(response.length<2300000&&NSDate.timeIntervalSinceReferenceDate<end){ssize_t n=recv(fd,bytes,sizeof(bytes),0);if(n==0)break;if(n<0){close(fd);return nil;}[response appendBytes:bytes length:(NSUInteger)n];}close(fd);
 NSData *separator=[@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];NSRange split=[response rangeOfData:separator options:0 range:NSMakeRange(0,response.length)];if(split.location==NSNotFound)return nil;NSString *header=[[NSString alloc] initWithData:[response subdataWithRange:NSMakeRange(0,split.location)] encoding:NSASCIIStringEncoding];if(![header hasPrefix:@"HTTP/1.1 200 "])return nil;NSData *body=[response subdataWithRange:NSMakeRange(NSMaxRange(split),response.length-NSMaxRange(split))];
 for(NSString *line in [header componentsSeparatedByString:@"\r\n"])if([line.lowercaseString hasPrefix:@"content-length:"]){if([[line substringFromIndex:15] longLongValue]!=(long long)body.length)return nil;return body;}return nil;
}
static __attribute__((unused)) NSData *MYBLoopbackGET(int port,NSString *path){return MYBLoopbackRequest(port,@"GET",path,nil);}
