#pragma once
// Proxy Override helpers shared by Settings and the tests. Pure value checks plus one bounded TCP reachability probe.
#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netdb.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
// A saved override must be a plain http://host:port. Credentials are never accepted (and so never stored or logged).
static inline BOOL MYBProxyURLValid(NSString *text){
 if(![text isKindOfClass:NSString.class]||!text.length||text.length>300)return NO;
 NSURLComponents *u=[NSURLComponents componentsWithString:text];
 return [u.scheme isEqual:@"http"]&&u.host.length&&u.host.length<=253&&u.port.integerValue>0&&u.port.integerValue<=65535&&!u.user.length&&!u.password.length&&!u.query.length&&!u.fragment.length&&(!u.path.length||[u.path isEqual:@"/"]);
}
static inline BOOL MYBProxyHasCredentials(NSString *text){
 NSURLComponents *u=[text isKindOfClass:NSString.class]?[NSURLComponents componentsWithString:text]:nil;return u.user.length||u.password.length;
}
// Returns nil when host/port are acceptable, otherwise a plain-language reason.
static inline NSString *MYBProxyFieldProblem(NSString *host,NSString *port){
 host=[host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];port=[port stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(!host.length)return @"Enter the server’s address, for example proxy.example.com or 192.168.1.20.";
 if([host containsString:@"://"]||[host containsString:@"/"]||[host containsString:@"@"])return @"Enter only the address. Leave out http://, any path, and any username or password.";
 NSCharacterSet *bad=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_:[]"].invertedSet;
 if(host.length>253||[host rangeOfCharacterFromSet:bad].location!=NSNotFound)return @"The address can only use letters, numbers, dots and dashes.";
 if(!port.length||[port rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location!=NSNotFound||port.integerValue<1||port.integerValue>65535)return @"The port is a number from 1 to 65535, for example 8080.";
 return nil;
}
// Can this device open a TCP connection to host:port within `timeout` seconds? Used to warn BEFORE a dead server is applied.
static inline BOOL MYBProxyReachable(NSString *host,NSInteger port,NSTimeInterval timeout){
 struct addrinfo hints;memset(&hints,0,sizeof hints);hints.ai_socktype=SOCK_STREAM;struct addrinfo *list=NULL;
 NSString *bare=[host hasPrefix:@"["]&&[host hasSuffix:@"]"]?[host substringWithRange:NSMakeRange(1,host.length-2)]:host;
 if(getaddrinfo(bare.UTF8String,[NSString stringWithFormat:@"%ld",(long)port].UTF8String,&hints,&list)!=0||!list)return NO;
 BOOL ok=NO;NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:timeout];
 for(struct addrinfo *a=list;a&&!ok;a=a->ai_next){
  int fd=socket(a->ai_family,a->ai_socktype,a->ai_protocol);if(fd<0)continue;fcntl(fd,F_SETFL,fcntl(fd,F_GETFL)|O_NONBLOCK);
  int r=connect(fd,a->ai_addr,a->ai_addrlen);
  if(r==0)ok=YES;
  else if(errno==EINPROGRESS){
   int ms=(int)MAX(0,[deadline timeIntervalSinceNow]*1000);struct pollfd p={.fd=fd,.events=POLLOUT};
   if(poll(&p,1,ms)==1){int err=0;socklen_t len=sizeof err;if(getsockopt(fd,SOL_SOCKET,SO_ERROR,&err,&len)==0&&err==0)ok=YES;}
  }
  close(fd);
 }
 freeaddrinfo(list);return ok;
}
