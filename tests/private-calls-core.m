// Desktop test of Shared/MYBPrivateCalls.h (pure rules). Plain Foundation: no literals, no blocks that need the iOS runtime.
#import <Foundation/Foundation.h>
#import "../Shared/MYBPrivateCalls.h"

// ---- stand-ins for Phone's call-history objects (same getter names) ----
@interface FakeHandle : NSObject {@public NSString *v,*n;} @end
@implementation FakeHandle
- (NSString *)value{return v;} - (NSString *)normalizedValue{return n;}
@end
@interface FakeCall : NSObject {@public NSMutableSet *hs;NSString *cid,*iso,*name;BOOL out,ans;}
@end
@implementation FakeCall
- (NSSet *)remoteParticipantHandles{return hs;} - (NSString *)callerId{return cid;} - (NSString *)isoCountryCode{return iso;} - (NSString *)callerName{return name;}
- (BOOL)mobileOriginated{return out;} - (BOOL)answered{return ans;}
@end
static FakeCall *Call(NSString *number,NSString *name,BOOL out,BOOL ans){
 FakeCall *c=[[FakeCall alloc] init];c->hs=[NSMutableSet set];
 if(number){FakeHandle *h=[[FakeHandle alloc] init];h->v=number;h->n=number;[c->hs addObject:h];}
 c->iso=@"es";c->name=name;c->out=out;c->ans=ans;return c;
}
static int fails=0,checks=0;
#define CHECK(c,m) do{checks++;if(!(c)){fails++;printf("FAIL: %s (line %d)\n",m,__LINE__);}}while(0)
#define K(raw,reg) MYBPCKey(raw,reg)
int main(void){@autoreleasepool{
 // ---- normalization ----
 CHECK([K(@"+34 612 345 678",nil) isEqualToString:@"+34612345678"],"international with spaces");
 CHECK([K(@"0034 612 345 678",@"ES") isEqualToString:@"+34612345678"],"00 prefix is international");
 CHECK([K(@"612345678",@"ES") isEqualToString:@"+34612345678"],"Spain national gets +34");
 CHECK([K(@"34612345678",@"ES") isEqualToString:@"+34612345678"],"Spain number with its own country code");
 CHECK([K(@"(415) 555-0123",@"US") isEqualToString:@"+14155550123"],"US formatted national");
 CHECK([K(@"1-415-555-0123",@"US") isEqualToString:@"+14155550123"],"US with leading 1");
 CHECK([K(@"+1 415 555 0123",@"ES") isEqualToString:@"+14155550123"],"US number typed in Spain stays +1");
 CHECK([K(@"011 34 612 345 678",@"US") isEqualToString:@"+34612345678"],"011 exit code from the US");
 CHECK([K(@"07911 123456",@"GB") isEqualToString:@"+447911123456"],"UK trunk 0 removed");
 CHECK([K(@"4155550123",@"ES") hasPrefix:@"n:ES:"],"10 digits in Spain is not a Spanish number: ambiguous, region kept");
 CHECK([K(@"4155550123",nil) isEqualToString:@"n::4155550123"],"no region: exact digits only");
 CHECK(K(@"12345",@"ES")==nil,"too short");
 CHECK(K(@"+34 612 345 678 ext 5",@"ES")==nil,"extension refused");
 CHECK(K(@"*67 612345678",@"ES")==nil,"service code prefix refused");
 CHECK(K(@"612,345,678",@"ES")==nil,"pause refused");
 CHECK(K(@"call me",@"ES")==nil,"text refused");
 CHECK(K(@"+0034612345678",@"ES")==nil,"plus then zero refused");
 CHECK(K(@"+3412345678901234567",@"ES")==nil,"too long refused");
 CHECK(K(nil,@"ES")==nil&&K(@"",@"ES")==nil,"nil and empty");
 CHECK([K(@"‎+34 612 345 678",nil) isEqualToString:@"+34612345678"],"direction mark ignored");
 CHECK(MYBPCIsProtectedNumber(@"112")&&MYBPCIsProtectedNumber(@"9 1 1")&&MYBPCIsProtectedNumber(@"999")&&!MYBPCIsProtectedNumber(@"612345678"),"emergency numbers are never private");
 // ---- matching: only the same key ----
 NSString *a=K(@"+34 612 345 678",nil);
 CHECK(MYBPCKeysMatch(a,K(@"612345678",@"ES")),"national equals international");
 CHECK(MYBPCKeysMatch(a,K(@"0034612345678",@"FR")),"00 form from another region");
 CHECK(!MYBPCKeysMatch(a,K(@"+34 612 345 679",nil)),"last digit differs");
 CHECK(!MYBPCKeysMatch(a,K(@"+34 12 345 678",nil)),"missing leading digit");
 CHECK(!MYBPCKeysMatch(K(@"612345678",@"ES"),K(@"+44612345678",nil)),"same digits, other country");
 CHECK(!MYBPCKeysMatch(K(@"4155550123",@"ES"),K(@"+14155550123",nil)),"ambiguous never matches a settled number");
 CHECK(MYBPCKeysMatch(K(@"4155550123",@"ES"),K(@"4155550123",@"ES")),"ambiguous matches only itself");
 CHECK(!MYBPCKeysMatch(K(@"4155550123",@"ES"),K(@"4155550123",@"PT")),"ambiguous in another region");
 // ---- records: newest wins, removal sticks across the two lists ----
 NSArray *s1=[NSArray arrayWithObject:MYBPCRecord(a,@"A",@"mute",YES,100)];
 NSArray *eff=MYBPCEffective(s1,nil);
 CHECK(eff.count==1&&[[[eff objectAtIndex:0] objectForKey:@"a"] isEqual:@"mute"],"one entry");
 NSArray *p1=[NSArray arrayWithObject:MYBPCRecord(a,@"A",@"decline",YES,200)];
 eff=MYBPCEffective(s1,p1);CHECK(eff.count==1&&[[[eff objectAtIndex:0] objectForKey:@"a"] isEqual:@"decline"],"newer action in the other list wins");
 NSArray *p2=MYBPCLogWith(p1,MYBPCRecord(a,@"A",@"decline",NO,300));
 eff=MYBPCEffective(s1,p2);CHECK(eff.count==0,"a removal in Phone beats an older add in Settings");
 NSArray *s2=MYBPCLogWith(s1,MYBPCRecord(a,@"A",@"mute",YES,400));
 eff=MYBPCEffective(s2,p2);CHECK(eff.count==1,"adding it again later brings it back");
 NSArray *tie=[NSArray arrayWithObject:MYBPCRecord(a,@"A",@"mute",NO,500)];
 eff=MYBPCEffective([NSArray arrayWithObject:MYBPCRecord(a,@"A",@"mute",YES,500)],tie);CHECK(eff.count==0,"a tie goes to the removal");
 eff=MYBPCEffective([NSArray arrayWithObjects:@"junk",[NSDictionary dictionary],nil],[NSNumber numberWithInt:3]);CHECK(eff.count==0,"junk is ignored");
 CHECK([MYBPCNormalizeAction(@"voicemail") isEqual:@"mute"]&&[MYBPCNormalizeAction(nil) isEqual:@"mute"]&&[MYBPCNormalizeAction(@"decline") isEqual:@"decline"],"an unknown action is Mute");
 NSMutableArray *big=[NSMutableArray array];
 for(int i=0;i<MYB_PC_MAX_RECORDS+20;i++)big=[MYBPCLogWith(big,MYBPCRecord([NSString stringWithFormat:@"+3460000%04d",i],@"",@"mute",i%2==0,(double)i)) mutableCopy];
 CHECK(big.count==MYB_PC_MAX_RECORDS,"the list is capped");
 // ---- calls: whole-call rule ----
 NSArray *entries=MYBPCEffective(s1,nil);
 NSArray *one=[NSArray arrayWithObject:[NSArray arrayWithObjects:@"+34612345678",@"612345678",nil]];
 CHECK(MYBPCEntryForHandles(entries,one,@"ES")!=nil,"a call from a private number matches");
 CHECK(MYBPCEntryForHandles(entries,[NSArray arrayWithObject:[NSArray arrayWithObject:@"+34612345679"]],@"ES")==nil,"another number does not");
 CHECK(MYBPCEntryForHandles(entries,[NSArray arrayWithObject:[NSArray arrayWithObject:@"612 34 56 78"]],@"GB")!=nil,"a placed call kept as dialed still matches when read in another country");
 CHECK(MYBPCEntryForHandles(entries,[NSArray arrayWithObject:[NSArray arrayWithObject:@"+44612345678"]],@"GB")==nil,"a number with its own country code never matches by its tail");
 CHECK(MYBPCEntryForHandles(entries,[NSArray arrayWithObject:[NSArray arrayWithObject:@"612 34 56 79"]],@"GB")==nil,"a different tail does not match");
 CHECK(MYBPCEntryForHandles(entries,[NSArray arrayWithObject:[NSArray arrayWithObject:@"Mama"]],@"ES")==nil,"a name is never a match");
 CHECK(MYBPCEntryForHandles(entries,[NSArray arrayWithObject:[NSArray arrayWithObject:@""]],@"ES")==nil,"withheld is left alone");
 NSArray *mixed=[NSArray arrayWithObjects:[NSArray arrayWithObject:@"+34612345678"],[NSArray arrayWithObject:@"+34699999999"],nil];
 CHECK(MYBPCEntryForHandles(entries,mixed,@"ES")==nil,"a group call with someone not private stays visible");
 CHECK(MYBPCEntryForHandles(nil,one,@"ES")==nil&&MYBPCEntryForHandles(entries,nil,@"ES")==nil,"empty inputs");
 CHECK([MYBPCDisplayForKey(a) hasPrefix:@"+34"],"display keeps the country code");
 // ---- the decision ----
 NSDictionary *mute=MYBPCRecord(a,@"",@"mute",YES,1),*dec=MYBPCRecord(a,@"",@"decline",YES,1),*hang=MYBPCRecord(a,@"",@"hangup",YES,1);
 CHECK(MYBPCDecide(mute,YES,YES,NO,YES,NO,NO,NO)==MYBPCDoMute,"Mute applies to a ringing private call");
 CHECK(MYBPCDecide(dec,YES,YES,NO,YES,NO,NO,NO)==MYBPCDoDecline,"Decline applies to a ringing private call");
 CHECK(MYBPCLooseSame(@"+34612345678",@"n:US:612345678")&&MYBPCLooseSame(@"+34612345678",@"612345678")&&MYBPCLooseSame(@"+447710995621",@"n::07710995621")&&MYBPCLooseSame(@"+14155550123",@"n:ES:4155550123"),"one number saved in any way is one number, in any country");
 CHECK(!MYBPCLooseSame(@"+34612345678",@"+34612345679")&&!MYBPCLooseSame(@"+34612345678",@"+44612345678")&&!MYBPCLooseSame(@"+34612",@"+3461"),"different numbers stay different");
 CHECK(MYBPCEntryForHandles(entries,[NSArray arrayWithObject:[NSArray arrayWithObject:@"612345678"]],@"US")!=nil,"a call read in the wrong country still matches the number saved with its country code");
 CHECK(MYBPCContactFallback==NULL&&MYBPCEntryForHandles(entries,[NSArray arrayWithObject:[NSArray arrayWithObject:@"+34600000000"]],@"ES")==nil,"with no contact lookup installed only numbers match");
 CHECK([MYBPCLabelWithNumber([entries objectAtIndex:0],nil,@"ES") rangeOfString:@"6"].location!=NSNotFound,"the list label carries the number");
 CHECK(MYBPCDecide(hang,YES,YES,NO,YES,NO,NO,NO)==MYBPCDoHangup,"Hang up applies to a ringing private call");
 CHECK(MYBPCDecide(hang,YES,YES,NO,YES,NO,NO,YES)==MYBPCDoDecline,"Hang up with another call going is a decline, never an answer");
 CHECK(MYBPCDecide(hang,YES,YES,YES,YES,NO,NO,NO)==MYBPCNothing&&MYBPCDecide(hang,YES,YES,NO,NO,NO,NO,NO)==MYBPCNothing,"Hang up never touches an answered call or another app's call");
 CHECK(MYBPCDecide(nil,YES,YES,NO,YES,NO,NO,NO)==MYBPCNothing,"an unmatched caller is left alone");
 CHECK(MYBPCDecide(mute,NO,YES,NO,YES,NO,NO,NO)==MYBPCNothing&&MYBPCDecide(dec,NO,YES,NO,YES,NO,NO,NO)==MYBPCNothing,"switch off: nothing happens");
 CHECK(MYBPCDecide(dec,YES,YES,YES,YES,NO,NO,NO)==MYBPCNothing,"an answered call is never ended");
 CHECK(MYBPCDecide(dec,YES,NO,NO,YES,NO,NO,NO)==MYBPCNothing,"an outgoing or non-incoming call is left alone");
 CHECK(MYBPCDecide(dec,YES,YES,NO,NO,NO,NO,NO)==MYBPCNothing,"FaceTime and other apps are left alone");
 CHECK(MYBPCDecide(dec,YES,YES,NO,YES,YES,NO,NO)==MYBPCNothing,"an emergency call is left alone");
 CHECK(MYBPCDecide(dec,YES,YES,NO,YES,NO,YES,NO)==MYBPCNothing&&MYBPCDecide(mute,YES,YES,NO,YES,NO,YES,NO)==MYBPCNothing,"the action runs only once per call");
 CHECK(MYBPCDecide(dec,YES,YES,NO,YES,NO,NO,YES)==MYBPCDoDecline,"a second private call while another is active can be declined");
 CHECK(MYBPCDecide(mute,YES,YES,NO,YES,NO,NO,YES)==MYBPCNothing,"Mute does not touch a call-waiting call");

 // ---- grouped history: All and Missed, shared names ----
 {
  NSArray *eff2=MYBPCEffective([NSArray arrayWithObject:MYBPCRecord(a,@"A",@"mute",YES,1)],nil);
  FakeCall *p1=Call(@"+34612345678",@"Ana",NO,NO),*p2=Call(@"+34612345678",@"Ana",YES,YES),*p3=Call(@"+34612345678",@"Ana",NO,YES);
  FakeCall *other=Call(@"+34699999999",@"Ana",NO,NO);              // a different person who shares the contact name
  FakeCall *plain=Call(@"+34611111111",@"Luis",NO,YES);
  NSArray *all=[NSArray arrayWithObjects:p1,other,p2,plain,p3,nil];
  NSArray *shown=MYBPCFilterRecents(all,eff2,@"ES");
  CHECK(shown.count==2&&[shown containsObject:other]&&[shown containsObject:plain],"All: only the private number's calls are hidden");
  CHECK([shown containsObject:other],"a different person with the same contact name stays visible");
  NSMutableArray *missedBefore=[NSMutableArray array];for(id c in all)if([MYBPCKindOfRecent(c) isEqual:@"Missed"])[missedBefore addObject:c];
  NSArray *missedShown=MYBPCFilterRecents(missedBefore,eff2,@"ES");
  CHECK(missedBefore.count==2&&missedShown.count==1&&[missedShown objectAtIndex:0]==other,"Missed: the private number's missed call is hidden, the other stays");
  CHECK([MYBPCKindOfRecent(p1) isEqual:@"Missed"]&&[MYBPCKindOfRecent(p2) isEqual:@"Outgoing"]&&[MYBPCKindOfRecent(p3) isEqual:@"Received"],"missed, outgoing and received are told apart");
  NSArray *back=MYBPCFilterRecents(all,MYBPCEffective([NSArray arrayWithObject:MYBPCRecord(a,@"A",@"mute",NO,2)],[NSArray arrayWithObject:MYBPCRecord(a,@"A",@"mute",YES,1)]),@"ES");
  CHECK(back.count==all.count,"after the number is removed every call is back in Recents");
  CHECK(MYBPCFilterRecents(all,[NSArray array],@"ES")==all,"no private numbers: the list is returned untouched");
  FakeCall *group=Call(@"+34612345678",@"Ana",NO,YES);FakeHandle *h2=[[FakeHandle alloc] init];h2->v=@"+34699999999";h2->n=@"+34699999999";[group->hs addObject:h2];
  CHECK(MYBPCFilterRecents([NSArray arrayWithObject:group],eff2,@"ES").count==1,"a group call with a non-private person stays visible");
  FakeCall *noNumber=Call(nil,@"Ana",NO,NO);noNumber->cid=nil;
  CHECK(MYBPCFilterRecents([NSArray arrayWithObject:noNumber],eff2,@"ES").count==1,"an entry with no number is never hidden");
  FakeCall *legacy=Call(nil,@"Ana",NO,NO);legacy->cid=@"612345678";
  CHECK(MYBPCFilterRecents([NSArray arrayWithObject:legacy],eff2,@"ES").count==0,"an old-style entry with only the caller number still matches exactly");
  FakeCall *near=Call(@"+34612345679",@"Ana",NO,NO);
  CHECK(MYBPCFilterRecents([NSArray arrayWithObject:near],eff2,@"ES").count==1,"a number one digit away is not hidden");
  {id nn=[NSNull null];CHECK(MYBPCFilterRecents((NSArray *)nn,eff2,@"ES")==(NSArray *)nn,"a non-array is passed through untouched");}
  // two numbers of one contact: choose which
  NSArray *two=MYBPCEffective([NSArray arrayWithObject:MYBPCRecord(a,@"A",@"mute",YES,1)],nil);
  FakeCall *work=Call(@"+34911111111",@"Ana",NO,NO);
  CHECK(MYBPCFilterRecents([NSArray arrayWithObjects:p1,work,nil],two,@"ES").count==1,"only the chosen one of a contact's numbers is private");
 }
 // ---- display: formatted the way Phone shows numbers; names win when known ----
 CHECK([MYBPCFormat(@"+34615034567",@"ES") isEqual:@"615 03 45 67"],"a number of the phone's own country has no country code and Spanish grouping");
 CHECK([MYBPCFormat(@"+34615034567",@"GB") isEqual:@"+34 615 03 45 67"],"a foreign number keeps its country code");
 CHECK([MYBPCFormat(@"+14155550123",@"ES") isEqual:@"+1 (415) 555-0123"],"a US number is shown the US way");
 CHECK([MYBPCFormat(@"n:ES:615034567",@"ES") isEqual:@"615 03 45 67"],"a number typed without a country code is shown the same way");
 CHECK([MYBPCKey(@"615 03 45 67",@"ES") isEqual:MYBPCKey(@"+34 615 03 45 67",@"ES")],"typed with or without the country code it is one number");
 CHECK([MYBPCLabel(MYBPCRecord(@"+34615034567",@"+34 615 034 567",@"mute",YES,1),nil,@"ES") isEqual:@"615 03 45 67"],"an old number-only label is shown in the new format");
 CHECK([MYBPCLabel(MYBPCRecord(@"+34615034567",@"Ana",@"mute",YES,1),nil,@"ES") isEqual:@"Ana"],"a stored name is kept");
 CHECK([MYBPCLabel(MYBPCRecord(@"+34615034567",@"+34 615 034 567",@"mute",YES,1),@"Ana Ruiz",@"ES") isEqual:@"Ana Ruiz"],"the contact's name wins when it is known");
 CHECK(MYBPCNameOnly(@"+34 615")==nil&&[MYBPCNameOnly(@"Ana") isEqual:@"Ana"],"a number is not mistaken for a name");
 printf("%d checks, %d failed\n",checks,fails);
 return fails?1:0;
}}
