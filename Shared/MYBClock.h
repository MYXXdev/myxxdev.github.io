#pragma once
// Shared time source for expiring permissions (Shield grants and temporary website exceptions).
// A timed record stores the boot session plus BOTH a wall-clock and a monotonic deadline. It is live only
// in the boot session that created it and only while both clocks agree it is unexpired, so changing the
// system clock can shorten a record but never extend it, and nothing timed survives a reboot.
#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import <time.h>
#ifdef MYB_SHIELD_TESTING
extern double gMYBShieldWall,gMYBShieldMono;extern NSString *gMYBShieldBoot;
#endif
static inline double MYBShieldWall(void){
#ifdef MYB_SHIELD_TESTING
 if(gMYBShieldWall>0)return gMYBShieldWall;
#endif
 return NSDate.date.timeIntervalSince1970;
}
static inline double MYBShieldMono(void){
#ifdef MYB_SHIELD_TESTING
 if(gMYBShieldMono>0)return gMYBShieldMono;
#endif
 struct timespec ts;clock_gettime(CLOCK_MONOTONIC_RAW,&ts);return (double)ts.tv_sec+(double)ts.tv_nsec/1e9;
}
static inline NSString *MYBShieldBoot(void){
#ifdef MYB_SHIELD_TESTING
 if(gMYBShieldBoot)return gMYBShieldBoot;
#endif
 char buffer[64]={0};size_t size=sizeof(buffer);if(sysctlbyname("kern.bootsessionuuid",buffer,&size,NULL,0)==0&&buffer[0])return [NSString stringWithUTF8String:buffer];
 struct timeval boot;size=sizeof(boot);int mib[2]={CTL_KERN,KERN_BOOTTIME};if(sysctl(mib,2,&boot,&size,NULL,0)==0)return [NSString stringWithFormat:@"boot-%ld",(long)boot.tv_sec];
 return @"unknown";
}
static inline void MYBClockStamp(NSMutableDictionary *record,double seconds){record[@"boot"]=MYBShieldBoot();record[@"wallExpiry"]=@(MYBShieldWall()+seconds);record[@"monoExpiry"]=@(MYBShieldMono()+seconds);}
static inline BOOL MYBClockLive(NSDictionary *record){
 if(![record[@"boot"] isEqual:MYBShieldBoot()])return NO;double wall=[record[@"wallExpiry"] doubleValue],mono=[record[@"monoExpiry"] doubleValue];
 if(wall<=0||mono<=0)return NO;return MYBShieldWall()<wall&&MYBShieldMono()<mono;
}
