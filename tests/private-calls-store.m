// Desktop test of Shared/MYBPrivateCallsStore.h: the REAL store and write path on temporary files (no mock). Plain Foundation + POSIX.
#import <Foundation/Foundation.h>
#include <sys/wait.h>
#import "../Shared/MYBPrivateCallsStore.h"

static int fails=0,checks=0;
#define CHECK(c,m) do{checks++;if(!(c)){fails++;printf("FAIL: %s (line %d)\n",m,__LINE__);}}while(0)
static NSString *Dir;
static NSString *StoreFile(void){return [Dir stringByAppendingPathComponent:@"privacy.plist"];}
static NSString *StampFile(void){return [Dir stringByAppendingPathComponent:@"reset.plist"];}
static NSArray *Eff(void){return MYBPCEffective(MYBPCStoreLog(StoreFile()),nil);}
static NSString *ActionOf(NSString *key){return [MYBPCEntryForKey(Eff(),key) objectForKey:@"a"];}
static void Fresh(void){[[NSFileManager defaultManager] removeItemAtPath:Dir error:NULL];[[NSFileManager defaultManager] createDirectoryAtPath:Dir withIntermediateDirectories:YES attributes:nil error:NULL];}
static double T=1000;
static double Tick(void){T+=1;return T;}

int main(void){@autoreleasepool{
 Dir=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"pcstore-%d",(int)getpid()]];
 NSString *A=@"+34611111111",*B=@"+34622222222",*C=@"+14155550123";

 // ---- 1. one store: Settings adds, Phone (direct write) sees it; Phone adds, Settings sees it; edit and remove from either side ----
 Fresh();
 CHECK(MYBPCStoreSet(StoreFile(),A,@"A",@"mute",YES,Tick(),NULL),"Settings add saves");
 CHECK(MYBPCEntryForKey(Eff(),A)!=nil,"Phone reads the Settings number from the same file");
 CHECK(MYBPCStoreSet(StoreFile(),B,@"B",@"decline",YES,Tick(),NULL),"Phone add saves");
 CHECK([ActionOf(B) isEqual:@"decline"]&&Eff().count==2,"Settings sees the Phone number with its action");
 CHECK(MYBPCStoreSet(StoreFile(),B,@"B",@"mute",YES,Tick(),NULL)&&[ActionOf(B) isEqual:@"mute"],"edit changes the action in the one record");
 CHECK(MYBPCStoreSet(StoreFile(),B,@"B",@"mute",NO,Tick(),NULL)&&MYBPCEntryForKey(Eff(),B)==nil&&Eff().count==1,"remove leaves the list in one step");
 CHECK(MYBPCStoreLog(StoreFile()).count==2,"removal is kept as a record so an old add cannot return");
 CHECK([[NSFileManager defaultManager] fileExistsAtPath:[StoreFile() stringByAppendingString:@".lock"]],"a lock file is used");

 // ---- 2. a failed save never looks saved ----
 NSString *bad=[Dir stringByAppendingPathComponent:@"missing/privacy.plist"];
 CHECK(!MYBPCStoreSet(bad,C,@"C",@"mute",YES,Tick(),NULL),"an unwritable store reports failure");
 CHECK(MYBPCEntryForKey(MYBPCEffective(MYBPCStoreLog(bad),nil),C)==nil,"and the number is not private");
 CHECK(Eff().count==1,"the real store is unchanged by the failed save");

 // ---- 3. Phone cannot write: its request goes through the root side (ApplyPending), same function ----
 Fresh();
 NSDictionary *req=MYBPCRecord(A,@"A",@"decline",YES,Tick());
 BOOL failed=NO;
 CHECK(MYBPCApplyPending(StoreFile(),StampFile(),[NSArray arrayWithObject:req],nil,&failed)==1&&!failed,"the helper applies Phone's request");
 CHECK([ActionOf(A) isEqual:@"decline"],"the request is in the store with its action");
 CHECK(MYBPCApplyPending(StoreFile(),StampFile(),[NSArray arrayWithObject:req],nil,&failed)==0,"applying the same request again does nothing");
 NSDictionary *removeReq=MYBPCRecord(A,@"A",@"decline",NO,Tick());
 CHECK(MYBPCApplyPending(StoreFile(),StampFile(),[NSArray arrayWithObjects:req,removeReq,nil],nil,&failed)>0&&MYBPCEntryForKey(Eff(),A)==nil,"a later removal request removes it from the store too");
 CHECK(MYBPCApplyPending(StoreFile(),StampFile(),[NSArray arrayWithObject:req],nil,&failed)==0&&MYBPCEntryForKey(Eff(),A)==nil,"an old add request cannot resurrect a removed number");
 failed=NO;
 CHECK(MYBPCApplyPending(bad,StampFile(),[NSArray arrayWithObject:MYBPCRecord(C,@"C",@"mute",YES,Tick())],nil,&failed)==0&&failed,"an unwritable store is reported as failed, not as applied");

 // ---- 4. migration from r18: Settings list is already the store; the Phone list is merged in ----
 Fresh();
 double t0=Tick();
 NSDictionary *seed=[NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:MYBPCRecord(A,@"A",@"decline",YES,t0),MYBPCRecord(B,@"B",@"mute",YES,t0+10),MYBPCRecord(C,@"C",@"decline",YES,t0),nil] forKey:MYB_PC_KEY_LOG];
 CHECK([seed writeToFile:StoreFile() atomically:YES],"r18 Settings list written as r18 did");
 NSArray *oldPhone=[NSArray arrayWithObjects:
   MYBPCRecord(A,@"A",@"mute",YES,t0),            // same time, different action: Mute (less disruptive)
   MYBPCRecord(B,@"B",@"decline",YES,t0+5),       // older than Settings' record: Settings' choice stays
   MYBPCRecord(C,@"C",@"mute",YES,t0+20),         // newer than Settings: Phone's choice wins
   MYBPCRecord(@"+34633333333",@"D",@"decline",YES,t0+1),   // Phone-only number: kept with its action
   MYBPCRecord(@"+34644444444",@"E",@"mute",NO,t0+2),       // Phone-only removal: stays removed
   nil];
 CHECK(MYBPCApplyPending(StoreFile(),StampFile(),nil,oldPhone,&failed)>0&&!failed,"migration runs");
 CHECK([ActionOf(A) isEqual:@"mute"],"tie between different actions keeps Mute");
 CHECK([ActionOf(B) isEqual:@"mute"],"the newer Settings choice beats the older Phone choice");
 CHECK([ActionOf(C) isEqual:@"mute"],"the newer Phone choice beats the older Settings choice");
 CHECK([ActionOf(@"+34633333333") isEqual:@"decline"],"a Phone-only number is kept with its chosen action");
 CHECK(MYBPCEntryForKey(Eff(),@"+34644444444")==nil&&Eff().count==4,"no number is lost and a removal stays removed");
 CHECK([[MYBPCStoreRead(StoreFile()) objectForKey:MYB_PC_KEY_VERSION] intValue]==2,"the store is marked migrated only after the verified write");
 CHECK(MYBPCStoreCovers(MYBPCStoreLog(StoreFile()),oldPhone),"the store covers every old Phone record (so Phone may retire its list)");
 NSData *before=[NSData dataWithContentsOfFile:StoreFile()];
 CHECK(MYBPCApplyPending(StoreFile(),StampFile(),nil,oldPhone,&failed)==0,"a retry after the migration changes nothing");
 CHECK([before isEqualToData:[NSData dataWithContentsOfFile:StoreFile()]],"and does not rewrite the file");

 // ---- 5. an interrupted migration is safe to retry ----
 Fresh();
 CHECK([seed writeToFile:StoreFile() atomically:YES],"r18 list again");
 NSString *savedFile=StoreFile();
 failed=NO;
 chmod([Dir fileSystemRepresentation],0555);   // the write cannot happen (skipped when running as root)
 int rcFail=MYBPCApplyPending(savedFile,StampFile(),nil,oldPhone,&failed);
 chmod([Dir fileSystemRepresentation],0755);
 if(geteuid()!=0){CHECK(rcFail==0&&failed,"an interrupted migration reports failure");}
 if(geteuid()!=0){CHECK([MYBPCStoreLog(StoreFile()) count]==3&&[ActionOf(A) isEqual:@"decline"],"the r18 list is untouched by the failed attempt");}
 MYBPCApplyPending(StoreFile(),StampFile(),nil,oldPhone,&failed);CHECK(!failed&&Eff().count==4&&[[MYBPCStoreRead(StoreFile()) objectForKey:MYB_PC_KEY_VERSION] intValue]==2,"the retry completes the migration");

 // ---- 6. Restore Defaults: store off and empty, old Phone entries and queued requests cannot come back ----
 NSDictionary *sw=[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:MYB_PC_KEY_SWITCH];
 NSMutableDictionary *withSwitch=[NSMutableDictionary dictionaryWithDictionary:MYBPCStoreRead(StoreFile())];[withSwitch addEntriesFromDictionary:sw];[withSwitch writeToFile:StoreFile() atomically:YES];
 T=5000;double resetAt=Tick();
 CHECK(MYBPCResetStore(StoreFile(),StampFile(),resetAt),"reset runs");
 NSDictionary *after=MYBPCStoreRead(StoreFile());
 CHECK(Eff().count==0&&![after objectForKey:MYB_PC_KEY_SWITCH]&&![after objectForKey:MYB_PC_KEY_VERSION],"reset clears the rules, the switch and the migration mark");
 CHECK(MYBPCApplyPending(StoreFile(),StampFile(),[NSArray arrayWithObject:MYBPCRecord(A,@"A",@"decline",YES,resetAt-1)],oldPhone,&failed)==0||Eff().count==0,"old Phone entries and old requests are not applied after a reset");
 CHECK(Eff().count==0,"nothing was resurrected");
 CHECK(MYBPCStoreSet(StoreFile(),A,@"A",@"mute",YES,Tick(),NULL)&&Eff().count==1,"a number added after the reset works");
 CHECK(MYBPCApplyPending(StoreFile(),StampFile(),nil,oldPhone,&failed)==0||Eff().count==1,"the old list still cannot come back later");
 CHECK(Eff().count==1,"only the new number is private");

 // ---- 7. concurrent edits from several processes: nothing is lost ----
 Fresh();
 int kids=4,per=15;
 for(int p=0;p<kids;p++){
  pid_t pid=fork();
  if(pid==0){
   @autoreleasepool{for(int i=0;i<per;i++){NSString *k=[NSString stringWithFormat:@"+3460000%02d%02d",p,i];MYBPCStoreSet(StoreFile(),k,k,@"mute",YES,1e6+p*100+i,NULL);}}
   _exit(0);
  }
 }
 int st;while(wait(&st)>0){}
 CHECK((int)Eff().count==kids*per,"every number added by four processes at once is in the store");
 CHECK([MYBPCStoreRead(StoreFile()) isKindOfClass:NSDictionary.class]&&[MYBPCStoreRead(StoreFile()) count]>0,"the file is whole");

 // ---- 8. the switch is kept when the list changes ----
 Fresh();
 [[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:MYB_PC_KEY_SWITCH] writeToFile:StoreFile() atomically:YES];
 MYBPCStoreSet(StoreFile(),A,@"A",@"mute",YES,Tick(),NULL);
 CHECK([[MYBPCStoreRead(StoreFile()) objectForKey:MYB_PC_KEY_SWITCH] boolValue],"saving a number keeps the Private Calls switch");
 [[NSFileManager defaultManager] removeItemAtPath:Dir error:NULL];
 printf("%d checks, %d failed\n",checks,fails);
 return fails?1:0;
}}
