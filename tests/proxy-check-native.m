// Proxy Override value checks and the bounded reachability probe, against a real loopback listener.
#import <Foundation/Foundation.h>
#import "../Shared/MYBProxyCheck.h"
#include <netinet/in.h>
static int failures=0;
#define CHECK(c,m) do{if(!(c)){printf("FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
int main(void){@autoreleasepool{
 CHECK(MYBProxyURLValid(@"http://proxy.example:8080")&&MYBProxyURLValid(@"http://192.168.1.20:3128/")&&MYBProxyURLValid(@"http://[::1]:8080"),"plain http host:port accepted");
 for(NSString *bad in @[@"",@"https://p.example:8080",@"http://u:p@p.example:8080",@"http://u@p.example:8080",@"http://p.example",@"http://p.example:0",@"http://p.example:65536",@"http://p.example:8080/x",@"http://p.example:8080?q=1",@"http://p.example:8080#f",@"ftp://p.example:21"])CHECK(!MYBProxyURLValid(bad),[[@"rejected: " stringByAppendingString:bad] UTF8String]);
 CHECK(MYBProxyHasCredentials(@"http://u:p@h:1")&&MYBProxyHasCredentials(@"http://u@h:1")&&!MYBProxyHasCredentials(@"http://h:1"),"credential detection");
 CHECK(!MYBProxyFieldProblem(@"proxy.example.com",@"8080")&&!MYBProxyFieldProblem(@" 10.0.0.2 ",@" 3128 "),"good fields accepted");
 for(NSArray *p in @[@[@"",@"8080"],@[@"http://x",@"8080"],@[@"u@x.com",@"8080"],@[@"x.com/path",@"8080"],@[@"bad host",@"8080"],@[@"x.com",@""],@[@"x.com",@"0"],@[@"x.com",@"65536"],@[@"x.com",@"80a"]])CHECK(MYBProxyFieldProblem(p[0],p[1]).length>0,([[NSString stringWithFormat:@"rejected fields %@",p] UTF8String]));
 int srv=socket(AF_INET,SOCK_STREAM,0);struct sockaddr_in a={0};a.sin_family=AF_INET;a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);a.sin_port=0;CHECK(bind(srv,(struct sockaddr *)&a,sizeof a)==0&&listen(srv,4)==0,"listener");
 socklen_t len=sizeof a;getsockname(srv,(struct sockaddr *)&a,&len);int port=ntohs(a.sin_port);
 CHECK(MYBProxyReachable(@"127.0.0.1",port,3),"reachable server is reported reachable");
 close(srv); // now nothing listens on that port
 NSDate *t=[NSDate date];CHECK(!MYBProxyReachable(@"127.0.0.1",port,3),"closed port is reported unreachable");CHECK([[NSDate date] timeIntervalSinceDate:t]<3.5,"the probe is bounded");
 CHECK(!MYBProxyReachable(@"definitely-not-a-host.invalid",80,2),"unresolvable host is unreachable");
 if(failures){printf("%d proxy-check failure(s)\n",failures);return 1;}
 printf("Proxy Override validation and reachability checks passed.\n");
}return 0;}
