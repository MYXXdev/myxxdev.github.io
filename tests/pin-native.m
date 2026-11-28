// noXXX PIN logic: format, key derivation, persistent throttle, scoped one-use grants, and when a PIN is required.
#import <Foundation/Foundation.h>
#define MYB_SHIELD_TESTING 1
double gMYBShieldWall=0,gMYBShieldMono=0;NSString *gMYBShieldBoot=nil;
#import "../Shared/MYBPin.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static void Clock(double wall,double mono,NSString *boot){gMYBShieldWall=wall;gMYBShieldMono=mono;gMYBShieldBoot=boot;}
int main(void){@autoreleasepool{
 Clock(1000000,5000,@"boot-A");
 for(NSString *ok in @[@"0000",@"1234",@"9999"])CHECK(MYBPinFormatValid(ok),"four digits are valid");
 for(NSString *bad in @[@"",@"123",@"12345",@"12a4",@" 123",@"１２３４",@"12.4",@"-123"])CHECK(!MYBPinFormatValid(bad),"anything else is refused");
 CHECK(!MYBPinFormatValid((id)@1234)&&!MYBPinFormatValid(nil),"non-strings refused");
 NSData *secret=MYBPinRandom(32);CHECK(secret.length==32&&![secret isEqual:MYBPinRandom(32)],"random secrets differ");
 NSDictionary *rec=MYBPinRecordNew(@"4821",secret,2000);CHECK(rec&&MYBPinRecordNew(@"48",secret,2000)==nil,"a record exists only for a valid PIN");
 CHECK(![[[NSString alloc] initWithData:[NSPropertyListSerialization dataWithPropertyList:rec format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL] encoding:NSUTF8StringEncoding] containsString:@"4821"],"the PIN itself is never stored");
 { NSMutableDictionary *z=[MYBPinRecordNew(@"0042",secret,2000) mutableCopy];double rr=0;Clock(3000000,7000,@"boot-Z");
  CHECK(MYBPinVerify(z,@"0042",secret,&rr)==MYBPinOK,"a PIN with leading zeroes verifies");
  CHECK(MYBPinVerify([z mutableCopy],@"0420",secret,&rr)==MYBPinWrong&&MYBPinVerify([z mutableCopy],@"4200",secret,&rr)==MYBPinWrong&&MYBPinVerify([z mutableCopy],@"0043",secret,&rr)==MYBPinWrong,"digits moved, dropped or changed are wrong");
  CHECK(MYBPinVerify([z mutableCopy],@"42",secret,&rr)==MYBPinBadFormat&&MYBPinVerify([z mutableCopy],@"00042",secret,&rr)==MYBPinBadFormat,"a PIN whose zeroes were dropped or added is malformed, never accepted"); Clock(1000000,5000,@"boot-A"); }
 NSData *d1=MYBPinDerive(@"4821",rec[@"salt"],secret,2000),*d2=MYBPinDerive(@"4821",rec[@"salt"],secret,2000);CHECK([d1 isEqual:d2]&&d1.length==32,"derivation is deterministic");
 CHECK(![d1 isEqual:MYBPinDerive(@"4822",rec[@"salt"],secret,2000)],"another PIN derives another value");
 CHECK(![d1 isEqual:MYBPinDerive(@"4821",rec[@"salt"],MYBPinRandom(32),2000)],"the device secret is part of the derivation");
 CHECK(![d1 isEqual:MYBPinDerive(@"4821",MYBPinRandom(16),secret,2000)],"the salt is part of the derivation");
 CHECK(MYBPinRecordNew(@"4821",secret,2000)[@"salt"]!=nil&&![[MYBPinRecordNew(@"4821",secret,2000)[@"salt"] description] isEqual:[rec[@"salt"] description]],"every record has its own salt");
 // verification and persistent throttling
 NSMutableDictionary *m=[rec mutableCopy];double retry=0;
 CHECK(MYBPinVerify(m,@"4821",secret,&retry)==MYBPinOK,"the right PIN opens");
 CHECK(MYBPinVerify(m,@"0000",secret,&retry)==MYBPinWrong&&MYBPinVerify(m,@"0001",secret,&retry)==MYBPinWrong,"two wrong PINs are only wrong");
 CHECK(MYBPinVerify(m,@"0002",secret,&retry)==MYBPinLocked&&retry==30,"the third wrong PIN locks for 30 seconds");
 CHECK(MYBPinVerify(m,@"4821",secret,&retry)==MYBPinLocked&&retry>29,"the right PIN is refused while locked (no oracle)");
 CHECK([m[@"failures"] integerValue]==3,"attempts while locked are not counted");
 Clock(1000031,5031,@"boot-A");CHECK(MYBPinVerify(m,@"0003",secret,&retry)==MYBPinLocked&&retry==60,"after the wait, the fourth wrong PIN locks for a minute");
 // the lockout survives a "restart of the helper": it lives in the record, which is persisted
 NSData *saved=[NSPropertyListSerialization dataWithPropertyList:m format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];NSMutableDictionary *m2=[[NSPropertyListSerialization propertyListWithData:saved options:NSPropertyListMutableContainers format:NULL error:NULL] mutableCopy];
 CHECK(MYBPinVerify(m2,@"4821",secret,&retry)==MYBPinLocked,"a persisted lockout still holds");
 // moving the system clock forward inside the same boot does not end it
 Clock(1000000+99999,5031.5,@"boot-A");CHECK(MYBPinLockRemaining(m2)>50,"a forward clock change inside one boot does not shorten the lockout");
 // a reboot keeps the wall-clock deadline
 Clock(1000031+30,10,@"boot-B");CHECK(MYBPinLockRemaining(m2)>0,"after a reboot the wall-clock deadline still applies");
 Clock(1000031+61,20,@"boot-B");CHECK(MYBPinLockRemaining(m2)==0&&MYBPinVerify(m2,@"4821",secret,&retry)==MYBPinOK&&[m2[@"failures"] integerValue]==0,"after the wait the right PIN opens and clears the count");
 CHECK(MYBPinDelayForFailures(1)==0&&MYBPinDelayForFailures(2)==0&&MYBPinDelayForFailures(5)==300&&MYBPinDelayForFailures(6)==900&&MYBPinDelayForFailures(7)==3600&&MYBPinDelayForFailures(8)==7200&&MYBPinDelayForFailures(60)==86400,"the schedule grows to a day and stops");
 NSMutableDictionary *none=[NSMutableDictionary dictionary];CHECK(MYBPinVerify(none,@"1234",secret,&retry)==MYBPinNotSet,"no record means no PIN is set");
 Clock(2000000,9000,@"boot-C");NSMutableDictionary *r3=[MYBPinRecordNew(@"1111",secret,2000) mutableCopy];CHECK(MYBPinVerify(r3,@"11x1",secret,&retry)==MYBPinBadFormat,"a malformed attempt is refused without counting");
 CHECK([r3[@"failures"] integerValue]==0,"a malformed attempt is not a failure");
 // grants
 NSMutableArray *g=MYBPinGrantIssue(@[],@"mode");CHECK(g.count==1,"a grant is issued");
 g=MYBPinGrantIssue(g,MYBPinAllowScope(@"Example.COM."));CHECK(g.count==2&&MYBPinScopeValid(@"allow:example.com"),"a site grant is scoped to the normalised host");
 CHECK(!MYBPinGrantConsume(g,@"disable"),"a grant for another scope is not accepted");
 CHECK(!MYBPinGrantConsume(g,@"allow:other.com"),"a grant for another site is not accepted");
 CHECK(MYBPinGrantConsume(g,@"allow:example.com")&&!MYBPinGrantConsume(g,@"allow:example.com"),"a grant works once");
 CHECK(MYBPinGrantConsume(g,@"mode"),"the other grant is still there");
 g=MYBPinGrantIssue(@[],@"rules");Clock(2000000+MYB_PIN_GRANT_SECONDS+1,9000+MYB_PIN_GRANT_SECONDS+1,@"boot-C");CHECK(!MYBPinGrantConsume(g,@"rules"),"a grant expires");
 Clock(2000000,9000,@"boot-C");g=MYBPinGrantIssue(@[],@"rules");Clock(2000001,9001,@"boot-D");CHECK(!MYBPinGrantConsume(g,@"rules"),"a grant does not survive a reboot");
 Clock(2000000,9000,@"boot-C");NSMutableArray *many=[NSMutableArray array];for(int i=0;i<40;i++)many=MYBPinGrantIssue(many,[NSString stringWithFormat:@"allow:h%d.example",i]);CHECK(many.count<=16,"outstanding grants are bounded");
 for(NSString *bad in @[@"",@"allow:",@"allow:UPPER.com",@"allow:a b.com",@"allow:../x",@"mode ",@"everything",@"allow:a/b.com"])CHECK(!MYBPinScopeValid(bad),"malformed scope refused");
 CHECK(MYBPinGrantIssue(@[],@"allow:../x").count==0,"an invalid scope never gets a grant");
 // policy
 CHECK(MYBPinProtectedNow(YES,YES,@"blockXXX")&&MYBPinProtectedNow(YES,YES,@"allowY+blockXXX"),"noXXX with a PIN and protection on is protected");
 CHECK(!MYBPinProtectedNow(NO,YES,@"blockXXX")&&!MYBPinProtectedNow(YES,NO,@"blockXXX")&&!MYBPinProtectedNow(YES,YES,@"allowY+blockApple"),"no PIN, protection off, or no noXXX: nothing is protected");
 CHECK(MYBPinChangeWeakens(YES,YES,@"blockXXX",YES,@"Default")&&MYBPinChangeWeakens(YES,YES,@"blockXXX",NO,@"blockXXX")&&MYBPinChangeWeakens(YES,YES,@"allowY+blockXXX",YES,@"allowY"),"leaving noXXX or turning protection off needs the PIN");
 CHECK(!MYBPinChangeWeakens(YES,YES,@"blockXXX",YES,@"blockApple+blockXXX")&&!MYBPinChangeWeakens(YES,YES,@"blockXXX",YES,@"allowY+blockXXX"),"adding options while keeping noXXX does not");
 CHECK(!MYBPinChangeWeakens(YES,NO,@"blockXXX",YES,@"Default")&&!MYBPinChangeWeakens(YES,YES,@"Default",YES,@"blockApple"),"changes that do not leave noXXX do not");
 if(failures){fprintf(stderr,"%d PIN check(s) FAILED\n",failures);return 1;}
 printf("noXXX PIN logic checks passed.\n");
}return 0;}
