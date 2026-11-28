#pragma once
// noXXX PIN protection: pure logic shared by the privileged helper and the tests. Nothing here touches the file system.
//
// What it is: an optional four-digit PIN that the helper requires before it will WEAKEN noXXX (leave it, turn protection off,
// allow a site noXXX blocks, add an Allow rule for such a site, replace the PAC with a Proxy Override, restore a backup or
// the defaults). The check lives in the privileged helper, so Settings, the blocked page and any other caller meet the same gate.
//
// How the PIN is kept: PBKDF2-HMAC-SHA256 over the PIN with a random per-install salt, then HMAC-SHA256 under a random
// device secret that lives in a separate root-only file. The record is root-only and is never part of a backup, an export,
// a diagnostic or a status file. A wrong PIN is throttled persistently (it survives restarts and reboots; a changed system
// clock cannot shorten a lockout inside one boot session).
// After a correct PIN the helper keeps a one-use, scope-bound, two-minute authorisation record; the guarded operation consumes it.
//
// Honest limits: a four-digit PIN has 10,000 values, so the throttle is the real protection. This stops accidental and casual
// weakening and any caller that goes through the helper. It does NOT stop someone with root on the device, someone who
// removes the package, or edits files as root. There is no recovery code and no bypass: a forgotten PIN is cleared only by
// restoring the device or removing MYbloXX.
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptoError.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import "MYBClock.h"
#import "MYBOptions.h"
#define MYB_PIN_ITERATIONS 150000
#define MYB_PIN_GRANT_SECONDS 120
typedef NS_ENUM(NSInteger,MYBPinResult){MYBPinOK=0,MYBPinWrong,MYBPinLocked,MYBPinBadFormat,MYBPinNotSet};
// Exit codes the helper uses for PIN outcomes (distinct from every existing code).
#define MYB_PIN_EXIT_REQUIRED 90
#define MYB_PIN_EXIT_LOCKED 91
#define MYB_PIN_EXIT_FORMAT 92
#define MYB_PIN_EXIT_NOTSET 93

static inline BOOL MYBPinFormatValid(NSString *pin){
 if(![pin isKindOfClass:NSString.class]||pin.length!=4)return NO;
 for(NSUInteger i=0;i<4;i++){unichar c=[pin characterAtIndex:i];if(c<'0'||c>'9')return NO;}return YES;
}
static inline NSData *MYBPinRandom(NSUInteger n){NSMutableData *d=[NSMutableData dataWithLength:n];arc4random_buf(d.mutableBytes,n);return d;}
static inline NSData *MYBPinDerive(NSString *pin,NSData *salt,NSData *secret,uint32_t iterations){
 NSData *pinBytes=[pin dataUsingEncoding:NSUTF8StringEncoding];if(!pinBytes||!salt.length||!secret.length||iterations<1000)return nil;
 unsigned char stretched[32];
 if(CCKeyDerivationPBKDF(kCCPBKDF2,pinBytes.bytes,pinBytes.length,salt.bytes,salt.length,kCCPRFHmacAlgSHA256,iterations,stretched,sizeof(stretched))!=kCCSuccess)return nil;
 unsigned char out[CC_SHA256_DIGEST_LENGTH];CCHmac(kCCHmacAlgSHA256,secret.bytes,secret.length,stretched,sizeof(stretched),out);
 memset(stretched,0,sizeof(stretched));return [NSData dataWithBytes:out length:sizeof(out)];
}
static inline BOOL MYBPinEqual(NSData *a,NSData *b){if(a.length!=b.length||!a.length)return NO;const unsigned char *x=a.bytes,*y=b.bytes;unsigned char d=0;for(NSUInteger i=0;i<a.length;i++)d|=x[i]^y[i];return d==0;}
// A fresh record for a PIN, or nil when the PIN is not four digits.
static inline NSDictionary *MYBPinRecordNew(NSString *pin,NSData *secret,uint32_t iterations){
 if(!MYBPinFormatValid(pin))return nil;NSData *salt=MYBPinRandom(16),*verifier=MYBPinDerive(pin,salt,secret,iterations);if(!verifier)return nil;
 return @{@"version":@1,@"salt":salt,@"iterations":@(iterations),@"verifier":verifier,@"failures":@0,@"lockWall":@0,@"lockMono":@0,@"lockBoot":@""};
}
// Seconds to wait after this many consecutive wrong PINs: none for two, then 30 s, 1 min, 5 min, 15 min, then an hour doubling to a day.
static inline double MYBPinDelayForFailures(NSInteger failures){
 if(failures<3)return 0;if(failures==3)return 30;if(failures==4)return 60;if(failures==5)return 300;if(failures==6)return 900;
 double h=3600.0*(double)(1<<MIN(failures-7,5));return MIN(h,86400.0);
}
// Remaining lockout in seconds (0 = not locked). Within the boot session that set it, the monotonic clock decides as well as the wall
// clock, so moving the system clock forward does not end a lockout early; after a reboot the wall-clock deadline applies.
static inline double MYBPinLockRemaining(NSDictionary *record){
 double wall=[record[@"lockWall"] doubleValue]-MYBShieldWall(),mono=0;
 if([record[@"lockBoot"] isEqual:MYBShieldBoot()])mono=[record[@"lockMono"] doubleValue]-MYBShieldMono();
 return MAX(0,MAX(wall,mono));
}
// Verifies a PIN against the record and updates the record (failure count, lockout). While locked the PIN is not even looked at,
// so a locked device gives no oracle. `retry` receives the lockout seconds.
static inline MYBPinResult MYBPinVerify(NSMutableDictionary *record,NSString *pin,NSData *secret,double *retry){
 if(![record[@"verifier"] isKindOfClass:NSData.class])return MYBPinNotSet;
 double left=MYBPinLockRemaining(record);if(left>0){if(retry)*retry=left;return MYBPinLocked;}
 if(!MYBPinFormatValid(pin))return MYBPinBadFormat;
 NSData *got=MYBPinDerive(pin,record[@"salt"],secret,(uint32_t)[record[@"iterations"] unsignedIntValue]);
 if(MYBPinEqual(got,record[@"verifier"])){record[@"failures"]=@0;record[@"lockWall"]=@0;record[@"lockMono"]=@0;record[@"lockBoot"]=@"";if(retry)*retry=0;return MYBPinOK;}
 NSInteger failures=[record[@"failures"] integerValue]+1;record[@"failures"]=@(failures);double wait=MYBPinDelayForFailures(failures);
 if(wait>0){record[@"lockWall"]=@(MYBShieldWall()+wait);record[@"lockMono"]=@(MYBShieldMono()+wait);record[@"lockBoot"]=MYBShieldBoot();}
 if(retry)*retry=wait;return wait>0?MYBPinLocked:MYBPinWrong;
}
// ---- scoped one-use authorisations -------------------------------------------------------------------------------
// Scopes: mode, disable, rules, restore, override, or allow:<host>. A grant is created only after a correct PIN, covers exactly one
// scope, lives two minutes in one boot session, and is deleted the moment the guarded operation uses it.
static inline BOOL MYBPinScopeValid(NSString *scope){
 if(![scope isKindOfClass:NSString.class]||scope.length>262)return NO;
 if([@[@"mode",@"disable",@"rules",@"restore",@"override"] containsObject:scope])return YES;
 if(![scope hasPrefix:@"allow:"])return NO;NSString *host=[scope substringFromIndex:6];
 if(!host.length||host.length>253)return NO;
 for(NSUInteger i=0;i<host.length;i++){unichar c=[host characterAtIndex:i];if(!((c>='a'&&c<='z')||(c>='0'&&c<='9')||c=='.'||c=='-'))return NO;}
 return YES;
}
static inline NSMutableArray *MYBPinGrantsLive(NSArray *grants){NSMutableArray *live=[NSMutableArray array];for(NSDictionary *g in grants)if([g isKindOfClass:NSDictionary.class]&&MYBClockLive(g))[live addObject:g];return live;}
static inline NSMutableArray *MYBPinGrantIssue(NSArray *grants,NSString *scope){
 NSMutableArray *live=MYBPinGrantsLive(grants);if(!MYBPinScopeValid(scope))return live;
 for(NSDictionary *g in [live copy])if([g[@"scope"] isEqual:scope])[live removeObject:g]; // one grant per scope
 while(live.count>=16)[live removeObjectAtIndex:0];
 NSMutableDictionary *g=[@{@"scope":scope} mutableCopy];MYBClockStamp(g,MYB_PIN_GRANT_SECONDS);[live addObject:g];return live;
}
// YES (and the grant removed from `live`) when a live grant for exactly this scope exists.
static inline BOOL MYBPinGrantConsume(NSMutableArray *live,NSString *scope){
 for(NSDictionary *g in live)if([g[@"scope"] isEqual:scope]&&MYBClockLive(g)){[live removeObject:g];return YES;}return NO;
}
// ---- policy: when the PIN is needed ----------------------------------------------------------------------------
static inline BOOL MYBPinModeHasXXX(NSString *mode){return [MYBOptionsForModeID(mode) containsObject:@"blockXXX"];}
// noXXX is being relied on right now: a PIN exists, protection is on, and the selected mode includes noXXX.
static inline BOOL MYBPinProtectedNow(BOOL pinSet,BOOL enabled,NSString *mode){return pinSet&&enabled&&MYBPinModeHasXXX(mode);}
// Changing mode/enabled weakens noXXX when it is protected now and the result is off or has no noXXX.
static inline BOOL MYBPinChangeWeakens(BOOL pinSet,BOOL enabled,NSString *mode,BOOL newEnabled,NSString *newMode){
 if(!MYBPinProtectedNow(pinSet,enabled,mode))return NO;return !newEnabled||!MYBPinModeHasXXX(newMode);
}
// Host-name scope for an Allow of `host`: lower case, no trailing dot.
static inline NSString *MYBPinAllowScope(NSString *host){NSString *h=[[host lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@". \t\n"]];return [@"allow:" stringByAppendingString:h?:@""];}
