#pragma once
// Which app a blocked request came from. The PAC never knows, and the connection carries no app name, so this asks the
// system who owns the other end of the connection: the process holding a TCP socket whose local port is the peer port and
// whose remote port is ours. One scan of the open sockets serves every connection that is open at that moment; scans are
// limited to one every 30 ms (a request inside that gap waits it out) and entries are used once and expire after a second, so a reused port is never mislabelled.
// The iOS SDK ships no headers for these system calls, so they are declared here (they are exported by libSystem), and the
// position of the two port numbers inside the reply is found by looking at this process's own connection, whose ports are known.
// Best effort: when the system does not answer, the answer is nil and the request is counted without an app.
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <errno.h>
extern int proc_listpids(uint32_t type,uint32_t typeinfo,void *buffer,int buffersize);
extern int proc_pidinfo(int pid,int flavor,uint64_t arg,void *buffer,int buffersize);
extern int proc_pidfdinfo(int pid,int fd,int flavor,void *buffer,int buffersize);
extern int proc_pidpath(int pid,void *buffer,uint32_t buffersize);
#ifndef MYB_BLOCK_PORT
#define MYB_BLOCK_PORT 8788
#endif
#ifndef MYB_WATCH_PORT
#define MYB_WATCH_PORT 8790
#endif
#define MYB_PEER_ALL_PIDS 1
#define MYB_PEER_LISTFDS 1
#define MYB_PEER_FDSOCKETINFO 3
#define MYB_PEER_FDTYPE_SOCKET 2
#define MYB_PEER_INFO_SIZE 2048
typedef struct{int32_t fd;uint32_t type;}MYBPeerFD;
static NSLock *MYBPeerLock(void){static NSLock *lock;static dispatch_once_t once;dispatch_once(&once,^{lock=[NSLock new];});return lock;}
static NSMutableDictionary *MYBPeerState(void){static NSMutableDictionary *s;static dispatch_once_t once;dispatch_once(&once,^{s=[@{@"cache":[NSMutableDictionary dictionary],@"labels":[NSMutableDictionary dictionary],@"scanAt":@0,@"scans":@0,@"lastMs":@0,@"processes":@0,@"readable":@0,@"sockets":@0,@"matched":@0,@"resolved":@0,@"unresolved":@0,@"offset":@(-1),@"firstError":@0,@"calibrationTries":@0} mutableCopy];});return s;}
// The process's app as @{name,id}: the app's own name and bundle identifier, "Safari & web pages" for the shared web networking
// process, "iOS system" (no identifier) for anything else that is not an app.
static NSDictionary *MYBPeerLabel(int pid){
 char path[4096]={0};if(proc_pidpath(pid,path,sizeof(path))<=0)return nil;
 NSString *p=[NSString stringWithUTF8String:path];if(!p.length)return nil;
 NSMutableDictionary *labels=MYBPeerState()[@"labels"];NSDictionary *known=labels[p];if(known)return known;
 NSString *name=nil,*bundleID=nil;
 if([p containsString:@"WebKit.Networking"]||[p containsString:@"com.apple.WebKit"]){name=@"Safari & web pages";bundleID=@"com.apple.mobilesafari";}
 else{
  NSRange app=[p rangeOfString:@".app/"];
  if(app.location!=NSNotFound){
   NSString *bundlePath=[p substringToIndex:app.location+4];NSDictionary *info=[NSBundle bundleWithPath:bundlePath].infoDictionary;
   name=info[@"CFBundleDisplayName"]?:info[@"CFBundleName"]?:[[bundlePath lastPathComponent] stringByDeletingPathExtension];bundleID=info[@"CFBundleIdentifier"];
  }else name=@"iOS system";
 }
 if(name.length>60)name=[name substringToIndex:60];
 NSDictionary *label=bundleID.length?@{@"name":name,@"id":bundleID}:@{@"name":name};
 if(labels.count>400)[labels removeAllObjects];labels[p]=label;return label;
}
static int32_t MYBPeerInt(const uint8_t *b,int at){int32_t v;memcpy(&v,b+at,4);return v;}
// Finds where the foreign and local port numbers sit in the system's socket reply, using this process's own accepted connection
// (foreign = the client's port, local = our port). They are stored one after the other as 32-bit network-order values.
static int MYBPeerCalibrate(int clientPort,int serverPort){
 int bytes=proc_pidinfo(getpid(),MYB_PEER_LISTFDS,0,NULL,0);if(bytes<=0)return -1;
 MYBPeerFD *fds=malloc((size_t)bytes);if(!fds)return -1;bytes=proc_pidinfo(getpid(),MYB_PEER_LISTFDS,0,fds,bytes);
 uint8_t *info=malloc(MYB_PEER_INFO_SIZE);int found=-1;
 for(int j=0;info&&j<(bytes>0?bytes/(int)sizeof(MYBPeerFD):0)&&found<0;j++){
  if(fds[j].type!=MYB_PEER_FDTYPE_SOCKET)continue;
  int n=proc_pidfdinfo(getpid(),fds[j].fd,MYB_PEER_FDSOCKETINFO,info,MYB_PEER_INFO_SIZE);if(n<=64)continue;
  for(int at=0;at+8<=n;at+=4)if(MYBPeerInt(info,at)==(int32_t)htons((uint16_t)clientPort)&&MYBPeerInt(info,at+4)==(int32_t)htons((uint16_t)serverPort)){found=at;break;}
 }
 free(info);free(fds);return found;
}
static void MYBPeerScan(__unused int serverPort,double now){
 NSMutableDictionary *state=MYBPeerState(),*cache=state[@"cache"];int offset=[state[@"offset"] intValue];
 state[@"scanAt"]=@(now);state[@"scans"]=@([state[@"scans"] integerValue]+1);
 int bytes=proc_listpids(MYB_PEER_ALL_PIDS,0,NULL,0);if(bytes<=0){if(![state[@"firstError"] intValue])state[@"firstError"]=@(errno?:-1);return;}
 int cap=bytes+64*(int)sizeof(int);int *pids=malloc((size_t)cap);if(!pids)return;bytes=proc_listpids(MYB_PEER_ALL_PIDS,0,pids,cap);
 int count=bytes>0?bytes/(int)sizeof(int):0,readable=0,sockets=0,matched=0,me=getpid();uint8_t *info=malloc(MYB_PEER_INFO_SIZE);
 for(int i=0;info&&i<count;i++){
  int pid=pids[i];if(pid<=1||pid==me)continue;
  int size=proc_pidinfo(pid,MYB_PEER_LISTFDS,0,NULL,0);if(size<=0){if(![state[@"firstError"] intValue])state[@"firstError"]=@(errno?:-2);continue;}
  MYBPeerFD *fds=malloc((size_t)size);if(!fds)continue;size=proc_pidinfo(pid,MYB_PEER_LISTFDS,0,fds,size);if(size>0)readable++;
  for(int j=0;j<(size>0?size/(int)sizeof(MYBPeerFD):0);j++){
   if(fds[j].type!=MYB_PEER_FDTYPE_SOCKET)continue;sockets++;
   int n=proc_pidfdinfo(pid,fds[j].fd,MYB_PEER_FDSOCKETINFO,info,MYB_PEER_INFO_SIZE);if(n<=offset+8||offset<0)continue;
   int remote=ntohs((uint16_t)MYBPeerInt(info,offset)),local=ntohs((uint16_t)MYBPeerInt(info,offset+4));
   if((remote!=MYB_BLOCK_PORT&&remote!=MYB_WATCH_PORT)||local==MYB_BLOCK_PORT||local==MYB_WATCH_PORT||local<=0)continue;
   NSDictionary *label=MYBPeerLabel(pid);if(label){cache[@(local)]=@{@"app":label,@"at":@(now)};matched++;}
  }
  free(fds);
 }
 free(info);free(pids);state[@"processes"]=@(count);state[@"readable"]=@(readable);state[@"sockets"]=@(sockets);state[@"matched"]=@([state[@"matched"] integerValue]+matched);
 if(cache.count>600)[cache removeAllObjects];
}
// The app for the connection whose far end (the client) is `portValue`, accepted on `serverPort`; @{name,id} or nil when it cannot be told.
static NSDictionary *MYBPeerAppForPort(int portValue,int serverPort){
 NSNumber *port=@(portValue);NSDictionary *app=nil;
 [MYBPeerLock() lock];
 NSMutableDictionary *state=MYBPeerState(),*cache=state[@"cache"];double now=NSDate.date.timeIntervalSince1970;
 if([state[@"offset"] intValue]<0&&[state[@"calibrationTries"] integerValue]<50){state[@"calibrationTries"]=@([state[@"calibrationTries"] integerValue]+1);state[@"offset"]=@(MYBPeerCalibrate(portValue,serverPort));}
 NSDictionary *hit=cache[port];if(hit&&now-[hit[@"at"] doubleValue]>1)hit=nil;
 // A request that lands inside the 30 ms gap after a scan waits out the rest of the gap (at most 30 ms) and then looks again,
 // while its connection is still open, instead of going unmatched.
 if(!hit&&[state[@"offset"] intValue]>=0&&now-[state[@"scanAt"] doubleValue]<=0.03){double wait=0.031-(now-[state[@"scanAt"] doubleValue]);if(wait>0&&wait<=0.031)usleep((useconds_t)(wait*1e6));now=NSDate.date.timeIntervalSince1970;}
 if(!hit&&[state[@"offset"] intValue]>=0&&now-[state[@"scanAt"] doubleValue]>0.03){NSDate *t0=NSDate.date;MYBPeerScan(serverPort,now);state[@"lastMs"]=@((NSInteger)(-[t0 timeIntervalSinceNow]*1000));hit=cache[port];}
 if(hit){app=hit[@"app"];[cache removeObjectForKey:port];}
 state[app?@"resolved":@"unresolved"]=@([state[app?@"resolved":@"unresolved"] integerValue]+1);
 [MYBPeerLock() unlock];
 return app;
}
// The same, for a connection this process accepted: reads the client's port from the socket.
static NSDictionary *MYBPeerAppForClient(int clientFd,int serverPort){
 struct sockaddr_in addr;socklen_t length=sizeof(addr);if(getpeername(clientFd,(struct sockaddr *)&addr,&length)!=0||addr.sin_family!=AF_INET)return nil;
 return MYBPeerAppForPort(ntohs(addr.sin_port),serverPort);
}
static NSDictionary *MYBPeerDiagnostics(void){
 [MYBPeerLock() lock];NSMutableDictionary *s=MYBPeerState();
 NSDictionary *d=@{@"supported":@1,@"calibrated":@([s[@"offset"] intValue]>=0),@"calibrationTries":s[@"calibrationTries"],@"scans":s[@"scans"],@"lastScanMs":s[@"lastMs"],@"processesSeen":s[@"processes"],@"processesReadable":s[@"readable"],@"socketsSeen":s[@"sockets"],@"connectionsMatched":s[@"matched"],@"resolved":s[@"resolved"],@"unresolved":s[@"unresolved"],@"firstError":s[@"firstError"]};
 [MYBPeerLock() unlock];return d;
}
