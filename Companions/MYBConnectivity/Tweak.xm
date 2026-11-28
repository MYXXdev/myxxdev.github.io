#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <notify.h>
#import <dlfcn.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <sys/sysctl.h>
#import <sys/socket.h>
#import <roothide.h>
#import "../../Shared/MYBConnectivity.h"
#import "../../Shared/MYBPrivateCallsStore.h"
#import "../../Shared/MYBCallServiceList.h"
#import "../../Shared/MYBFirewallList.h"
// Advanced > Connectivity, two independent features, each OFF until switched on in MYbloXX® Settings. One dylib, two processes, nothing shared between them:
//
//   com.apple.Preferences  Per-App Network Access. Settings shows its per-app "Off / WLAN / WLAN & Cellular Data" controls only on China-region
//                          cellular devices; the gate is UIDevice -sf_isChinaRegionCellularDevice (the same method the community tweak Conditional
//                          overrides for Settings on iOS 15, and the one the old DataPlus hook targeted). The override is installed in the Settings
//                          process only, never in any other process, and answers YES only while the switch is on. MobileGestalt, the device region
//                          and every other process are not touched. The enforcement itself is iOS's own.
//   com.apple.springboard  Keep Personal Hotspot Active. Does not enable Personal Hotspot and never changes its on/off behaviour. While the hotspot is
//                          up AND a device is connected it holds one self-expiring "NetworkClientActive" power assertion, nothing else. It releases it
//                          the moment the hotspot goes down, the last device leaves, the switch is turned off, or (by its own time limit) if this
//                          code stops running. Normal sleep is untouched outside an active session. It records what it saw (hotspot up/down,
//                          devices, lock state, Low Power Mode, whether iOS accepted the assertion) in a short local log so the baseline can be
//                          read from the device. No app traffic, no sleep overrides, no radio or Wi-Fi power overrides.
static NSDictionary *connPrefs;
static BOOL switchOn(NSString *key){return MYBConnFlag(connPrefs,key);}
static void reloadPrefs(void){connPrefs=[NSDictionary dictionaryWithContentsOfFile:MYBConnPrefsFile()]?:@{};}

// ================================ Per-App Network Access (Settings only) ==================================================================
static NSMutableArray<NSString *> *gateCallers; // image names that asked, so the on-device status shows who really consumes the answer
static BOOL gateInstalled;
static void writeGateStatus(NSString *state){
 NSDictionary *status=@{@"state":state?:@"",@"callers":gateCallers?:@[],@"time":@(NSDate.date.timeIntervalSince1970)};
 [status writeToFile:MYBNetAccessStatusFile() atomically:YES];
}
%group SettingsGate
%hook UIDevice
- (BOOL)sf_isChinaRegionCellularDevice{
 if(!switchOn(MYB_CONN_KEY_NETWORK_MENU))return %orig;
 Dl_info info;void *caller=__builtin_return_address(0);
 if(dladdr(caller,&info)&&info.dli_fname){
  NSString *image=[[NSString stringWithUTF8String:info.dli_fname] lastPathComponent];
  if(!gateCallers)gateCallers=[NSMutableArray array];
  if(image.length&&![gateCallers containsObject:image]&&gateCallers.count<12){[gateCallers addObject:image];writeGateStatus(@"answering yes in Settings");}
 }
 return YES;
}
%end
%end
static void installGate(void){
 if(gateInstalled)return;
 if(![UIDevice instancesRespondToSelector:@selector(sf_isChinaRegionCellularDevice)])return;
 gateInstalled=YES;%init(SettingsGate);writeGateStatus(@"hook installed");
}

// ================================ Keep Personal Hotspot Active (SpringBoard only) =========================================================
// Personal Hotspot is up when iOS has created its bridge interface (bridge100) with an address. Devices are the complete neighbour entries on it.
// Both are read-only observations. If the neighbour table cannot be read the count is unknown and nothing is held.
static const char *kBridge="bridge100";
static BOOL hotspotUp(void){
 struct ifaddrs *list=NULL;BOOL up=NO;if(getifaddrs(&list)!=0)return NO;
 for(struct ifaddrs *i=list;i;i=i->ifa_next)if(i->ifa_name&&!strcmp(i->ifa_name,kBridge)&&(i->ifa_flags&IFF_UP)&&i->ifa_addr&&i->ifa_addr->sa_family==AF_INET)up=YES;
 freeifaddrs(list);return up;
}
// BSD routing message layout (stable XNU ABI): header, then the destination sockaddr_in (ARP key) followed by the link-layer sockaddr_dl.
struct MYBRtMetrics{u_int32_t locks,mtu,hopcount;int32_t expire;u_int32_t recvpipe,sendpipe,ssthresh,rtt,rttvar,pksent,filler[4];};
struct MYBRtMsg{u_short msglen;u_char version,type;u_short index;int flags,addrs;pid_t pid;int seq,error,use;u_int32_t inits;struct MYBRtMetrics rmx;};
static NSInteger deviceCount(void){ // -1 when it cannot be read
 unsigned ifindex=if_nametoindex(kBridge);if(!ifindex)return 0;
 int mib[6]={CTL_NET,PF_ROUTE,0,AF_INET,NET_RT_FLAGS,0x400}; // RTF_LLINFO
 size_t need=0;if(sysctl(mib,6,NULL,&need,NULL,0)!=0)return -1;
 if(!need)return 0;
 char *buffer=(char *)malloc(need);if(!buffer)return -1;
 if(sysctl(mib,6,buffer,&need,NULL,0)!=0){free(buffer);return -1;}
 NSInteger count=0;time_t now=time(NULL);
 for(char *at=buffer;at+sizeof(struct MYBRtMsg)<=buffer+need;){
  struct MYBRtMsg *message=(struct MYBRtMsg *)at;if(message->msglen<sizeof(struct MYBRtMsg)||at+message->msglen>buffer+need)break;
  struct sockaddr_in *destination=(struct sockaddr_in *)(message+1);
  if(destination->sin_len&&at+sizeof(struct MYBRtMsg)+((destination->sin_len+3)&~3U)+sizeof(struct sockaddr_dl)<=at+message->msglen+sizeof(struct sockaddr_dl)){
   struct sockaddr_dl *link=(struct sockaddr_dl *)((char *)destination+(((destination->sin_len)+3)&~3U));
   BOOL fresh=message->rmx.expire==0||message->rmx.expire>now; // a stale entry is a device that is gone
   if(link->sdl_family==AF_LINK&&link->sdl_alen==6&&link->sdl_index==ifindex&&fresh)count++;
  }
  at+=message->msglen;
 }
 free(buffer);return count;
}
typedef int32_t (*PMCreate)(CFDictionaryRef,uint32_t *);
typedef int32_t (*PMRelease)(uint32_t);
static uint32_t assertionID;static BOOL holding;
static dispatch_source_t renewTimer;
static NSString *lastLogged;
static BOOL lowPower(void){return NSProcessInfo.processInfo.isLowPowerModeEnabled;}
static NSString *lockState(void){int token=0;uint64_t state=0;if(notify_register_check("com.apple.springboard.lockstate",&token)==NOTIFY_STATUS_OK){notify_get_state(token,&state);notify_cancel(token);return state?@"locked":@"unlocked";}return @"unknown";}
static void logEvent(NSString *line){
 NSString *entry=[NSString stringWithFormat:@"%@ %@\n",[NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle],line];
 NSString *path=MYBHotspotLogFile();NSData *existing=[NSData dataWithContentsOfFile:path]?:NSData.data;
 NSMutableData *all=[existing mutableCopy];[all appendData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
 if(all.length>16384)[all replaceBytesInRange:NSMakeRange(0,all.length-12288) withBytes:NULL length:0]; // short ring, local only
 [all writeToFile:path atomically:YES];
}
static BOOL takeAssertion(NSString **why){
 static PMCreate create;static dispatch_once_t once;dispatch_once(&once,^{void *io=dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",RTLD_LAZY);create=io?(PMCreate)dlsym(io,"IOPMAssertionCreateWithProperties"):NULL;});
 if(!create){if(why)*why=@"power assertions are not available on this iOS build";return NO;}
 NSDictionary *properties=@{@"AssertType":@"NetworkClientActive",@"AssertName":@"MYbloXX Personal Hotspot",@"AssertLevel":@255,@"TimeoutSeconds":@180,@"TimeoutAction":@"TimeoutActionRelease"};
 uint32_t fresh=0;int32_t result=create((__bridge CFDictionaryRef)properties,&fresh);
 if(result!=0){if(why)*why=[NSString stringWithFormat:@"iOS did not accept the assertion (code %d)",result];return NO;}
 uint32_t old=assertionID;assertionID=fresh;
 if(old){static PMRelease release;static dispatch_once_t r;dispatch_once(&r,^{void *io=dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",RTLD_LAZY);release=io?(PMRelease)dlsym(io,"IOPMAssertionRelease"):NULL;});if(release)release(old);}
 return YES;
}
static void dropAssertion(void){
 if(!assertionID)return;
 static PMRelease release;static dispatch_once_t once;dispatch_once(&once,^{void *io=dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",RTLD_LAZY);release=io?(PMRelease)dlsym(io,"IOPMAssertionRelease"):NULL;});
 if(release)release(assertionID);assertionID=0;
}
static void stopTimer(void){if(renewTimer){dispatch_source_cancel(renewTimer);renewTimer=nil;}}
static void evaluate(NSString *reason);
static void startTimer(void){ // renews the self-expiring assertion and notices a last device leaving; runs only while a session is active
 if(renewTimer)return;
 renewTimer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
 dispatch_source_set_timer(renewTimer,dispatch_time(DISPATCH_TIME_NOW,60*NSEC_PER_SEC),60*NSEC_PER_SEC,5*NSEC_PER_SEC);
 dispatch_source_set_event_handler(renewTimer,^{evaluate(@"timer");});dispatch_resume(renewTimer);
}
static void evaluate(NSString *reason){
 BOOL on=switchOn(MYB_CONN_KEY_HOTSPOT);
 BOOL up=on?hotspotUp():NO;NSInteger devices=up?deviceCount():0;
 BOOL want=MYBHotspotShouldHold(on,up,devices);
 NSString *note=nil;
 if(want){
  if(takeAssertion(&note)){if(!holding){holding=YES;}startTimer();}
  else{holding=NO;dropAssertion();stopTimer();}
 }else{
  if(holding||assertionID){dropAssertion();holding=NO;}
  if(!up)stopTimer();else if(on)startTimer(); // hotspot up with no device yet: keep watching for the first one
  else stopTimer();
 }
 NSString *state=[NSString stringWithFormat:@"switch=%@ hotspot=%@ devices=%@ holding=%@ screen=%@ lowpower=%@%@",on?@"on":@"off",up?@"up":@"down",devices<0?@"unknown":@(devices).stringValue,holding?@"yes":@"no",lockState(),lowPower()?@"yes":@"no",note?[@" note=" stringByAppendingString:note]:@""];
 if(![state isEqual:lastLogged]){lastLogged=state;logEvent([NSString stringWithFormat:@"[%@] %@",reason,state]);}
 NSDictionary *status=@{@"switch":@(on),@"hotspotUp":@(up),@"devices":@(devices),@"holding":@(holding),@"note":note?:@"",@"time":@(NSDate.date.timeIntervalSince1970)};
 [status writeToFile:MYBHotspotStatusFile() atomically:YES];
}
static void startHotspotWatcher(void){
 int token=0;
 notify_register_dispatch("com.apple.system.config.network_change",&token,dispatch_get_main_queue(),^(int t){(void)t;evaluate(@"network change");});
 notify_register_dispatch("com.apple.springboard.lockstate",&token,dispatch_get_main_queue(),^(int t){(void)t;evaluate(@"lock state");});
 notify_register_dispatch(MYB_CONN_NOTIFY,&token,dispatch_get_main_queue(),^(int t){(void)t;reloadPrefs();evaluate(@"switch changed");});
 evaluate(@"start");
}

// ================================ Private Calls list for the call service (SpringBoard only) ===============================================================
// The call service cannot read the preference file and its preference cache can be stale, so SpringBoard hands it the list directly: the switch and every
// number on the list (key and action, nothing else). Published at start, whenever Private Calls changes anything, and whenever the call service asks.
static void publishPrivateList(void){MYBCSLPublish(MYBPrivPrefsFile());}
static void startPrivateListMirror(void){
 static int changedToken=0,needToken=0;
 publishPrivateList();
 notify_register_dispatch(MYB_PRIV_NOTIFY,&changedToken,dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^(int t){(void)t;publishPrivateList();});
 notify_register_dispatch(MYB_CSL_NEED,&needToken,dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^(int t){(void)t;publishPrivateList();});
}
// Same mirror, same reasons, for the Call Firewall's own separate file and live channel -- it never touches Private Calls' list or switch.
static void publishFirewallList(void){MYBFWLPublish(MYBFirewallPrefsFile());}
static void startFirewallListMirror(void){
 static int changedToken=0,needToken=0;
 publishFirewallList();
 notify_register_dispatch(MYB_FW_NOTIFY,&changedToken,dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^(int t){(void)t;publishFirewallList();});
 notify_register_dispatch(MYB_FWL_NEED,&needToken,dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^(int t){(void)t;publishFirewallList();});
}

%ctor{
 @autoreleasepool{
  reloadPrefs();
  NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
  if([bundle isEqual:@"com.apple.Preferences"]){
   static int prefsToken=0;
   notify_register_dispatch(MYB_CONN_NOTIFY,&prefsToken,dispatch_get_main_queue(),^(int t){(void)t;reloadPrefs();});
   installGate();
   if(!gateInstalled)[NSNotificationCenter.defaultCenter addObserverForName:NSBundleDidLoadNotification object:nil queue:nil usingBlock:^(NSNotification *n){(void)n;installGate();}];
  }else if([bundle isEqual:@"com.apple.springboard"]){
   dispatch_async(dispatch_get_main_queue(),^{startHotspotWatcher();});
   dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{startPrivateListMirror();});
   dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{startFirewallListMirror();});
  }
 }
}
