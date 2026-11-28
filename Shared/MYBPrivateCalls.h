#pragma once
// MYbloXX® Private Calls: the pure rules. No UIKit, no hooks, no file access, no private classes, so the same code runs in Settings, Phone, the
// incoming-call component and the desktop tests, and a mistake here can only ever mean "this number did not match" (normal call handling).
//
// Numbers stay on the phone. A "key" is what two numbers are compared by:
//   "+14155550123"   a number with a known country code (international, or national in a known region), digits only
//   "n:ES:6123456"   a national number whose country could not be settled; it matches only the very same digits in the very same region
//   "n::6123456"     the same with no region at all
// A different key never matches. There is no last-digits matching, no prefix matching and no name matching, and a caller ID match is only a rule
// match: it does not prove who is calling.
#import <Foundation/Foundation.h>

#define MYB_PC_KEY_SWITCH @"PrivateCalls"                 // privacy.plist, OFF unless it is a true number
#define MYB_PC_KEY_LOG @"PrivateCallsLog"                 // privacy.plist: records written by Settings
#define MYB_PC_PHONE_DOMAIN @"com.apple.mobilephone"      // Phone keeps the records it writes in its own preferences
#define MYB_PC_PHONE_LOG @"MYBPCLog"                      // r18 only: the old Phone list, read once by the migration and then retired
#define MYB_PC_PHONE_QUEUE @"MYBPCQueue"                  // Phone's requests when it cannot write the store itself
#define MYB_PC_KEY_VERSION @"PrivateCallsStoreVersion"    // 2 once the r18 lists were merged into the store
#define MYB_PC_REQUEST_NOTIFY "net.myxxdev.mybloxx.privatecalls.request"
#define MYB_PC_ACTION_MUTE @"mute"
#define MYB_PC_ACTION_DECLINE @"decline"
#define MYB_PC_ACTION_HANGUP @"hangup"
#define MYB_PC_MAX_RECORDS 400

typedef struct { const char *iso; const char *cc; const char *trunk; int minNat; int maxNat; } MYBPCRegion;
static const MYBPCRegion MYBPCRegions[] = {
 {"US","1","1",10,10},{"CA","1","1",10,10},{"GB","44","0",9,10},{"ES","34","",9,9},{"FR","33","0",9,9},{"DE","49","0",7,12},{"IT","39","",6,11},
 {"PT","351","",9,9},{"NL","31","0",9,9},{"BE","32","0",8,9},{"IE","353","0",7,9},{"CH","41","0",9,9},{"AT","43","0",7,13},{"SE","46","0",7,9},
 {"NO","47","",8,8},{"DK","45","",8,8},{"FI","358","0",5,11},{"PL","48","",9,9},{"MX","52","",10,10},{"BR","55","0",10,11},{"AR","54","0",10,10},
 {"CO","57","",10,10},{"CL","56","",9,9},{"PE","51","0",8,9},{"AU","61","0",9,9},{"NZ","64","0",8,10},{"IN","91","0",10,10},{"JP","81","0",9,10},
 {"KR","82","0",8,10},{"CN","86","0",9,11},{"ZA","27","0",9,9},{"MA","212","0",9,9},{"AE","971","0",8,9},{"TR","90","0",10,10},{"GR","30","",10,10}};

static inline const MYBPCRegion *MYBPCFindRegion(NSString *iso){
 if(![iso isKindOfClass:NSString.class]||iso.length!=2)return NULL;
 NSString *up=[iso uppercaseString];
 for(size_t i=0;i<sizeof(MYBPCRegions)/sizeof(MYBPCRegions[0]);i++)if(strcmp(MYBPCRegions[i].iso,[up UTF8String])==0)return &MYBPCRegions[i];
 return NULL;
}

// Returns the key for a typed or stored number, or nil when it is not a plain telephone number (letters, *, #, pauses, extensions, too short or too long).
// region: the ISO country the number should be read in when it has no country code (nil when unknown).
static inline NSString *MYBPCKey(NSString *raw,NSString *region){
 if(![raw isKindOfClass:NSString.class])return nil;
 NSMutableString *digits=[NSMutableString string];BOOL plus=NO;BOOL first=YES;
 for(NSUInteger i=0;i<raw.length;i++){
  unichar c=[raw characterAtIndex:i];
  if(c>='0'&&c<='9'){[digits appendFormat:@"%C",c];first=NO;continue;}
  if(c=='+'){if(!first||plus||digits.length)return nil;plus=YES;continue;}
  if(c==' '||c=='-'||c=='('||c==')'||c=='.'||c==0x00A0||c==0x2011||c==0x2013||c=='/')continue;   // layout only
  if(c==0x200E||c==0x200F||c==0x202A||c==0x202C||c==0x2066||c==0x2069)continue;                                                          // direction marks
  return nil;
 }
 if(digits.length<6||digits.length>15)return nil;
 NSString *iso=[region isKindOfClass:NSString.class]&&region.length==2?[region uppercaseString]:nil;
 const MYBPCRegion *reg=MYBPCFindRegion(iso);
 if(plus){
  if([digits hasPrefix:@"0"]||digits.length<7)return nil;
  return [@"+" stringByAppendingString:digits];
 }
 if([digits hasPrefix:@"00"]&&!(reg&&strcmp(reg->cc,"1")==0)){
  NSString *rest=[digits substringFromIndex:2];
  if(rest.length<7||[rest hasPrefix:@"0"])return nil;
  return [@"+" stringByAppendingString:rest];
 }
 if(reg&&strcmp(reg->cc,"1")==0&&[digits hasPrefix:@"011"]){
  NSString *rest=[digits substringFromIndex:3];
  if(rest.length<7||[rest hasPrefix:@"0"])return nil;
  return [@"+" stringByAppendingString:rest];
 }
 if(reg){
  NSString *cc=[NSString stringWithUTF8String:reg->cc],*trunk=[NSString stringWithUTF8String:reg->trunk];
  NSInteger len=(NSInteger)digits.length;
  // already carries its own country code and the rest has a valid national length
  if([digits hasPrefix:cc]){
   NSInteger nat=len-(NSInteger)cc.length;
   if(nat>=reg->minNat&&nat<=reg->maxNat&&!(len>=reg->minNat&&len<=reg->maxNat))return [@"+" stringByAppendingString:digits];
  }
  if(trunk.length&&[digits hasPrefix:trunk]){
   NSString *rest=[digits substringFromIndex:trunk.length];
   if((NSInteger)rest.length>=reg->minNat&&(NSInteger)rest.length<=reg->maxNat)return [NSString stringWithFormat:@"+%@%@",cc,rest];
  }
  if(len>=reg->minNat&&len<=reg->maxNat)return [NSString stringWithFormat:@"+%@%@",cc,digits];
 }
 return [NSString stringWithFormat:@"n:%@:%@",iso?:@"",digits];
}
static inline BOOL MYBPCKeyIsInternational(NSString *key){return [key hasPrefix:@"+"];}
static inline BOOL MYBPCKeysMatch(NSString *a,NSString *b){return a.length&&b.length&&[a isEqualToString:b];}

// Emergency numbers and service codes are never made private, whatever region they are read in.
static inline BOOL MYBPCIsProtectedNumber(NSString *raw){
 NSMutableString *d=[NSMutableString string];
 for(NSUInteger i=0;raw&&i<raw.length;i++){unichar c=[raw characterAtIndex:i];if(c>='0'&&c<='9')[d appendFormat:@"%C",c];}
 static NSString *const list[]={@"112",@"911",@"999",@"000",@"110",@"119",@"100",@"101",@"102",@"15",@"17",@"18",@"122",@"123",@"091",@"061",@"088",@"092"};
 for(size_t i=0;i<sizeof(list)/sizeof(list[0]);i++)if([d isEqualToString:list[i]])return YES;
 return NO;
}

// ---- records -----------------------------------------------------------------------------------------------------------------------------
// A record is {k: key, d: display text, a: action, t: seconds since 1970, on: BOOL}. Settings and Phone each keep their own list (neither can always write the
// other's file), and the newest record for a key wins. A removal is a record with on = NO, so a number removed in one place stays removed in the other.
static inline NSString *MYBPCNormalizeAction(id action){
 if([action isEqual:MYB_PC_ACTION_DECLINE])return MYB_PC_ACTION_DECLINE;
 if([action isEqual:MYB_PC_ACTION_HANGUP])return MYB_PC_ACTION_HANGUP;
 return MYB_PC_ACTION_MUTE;   // anything unknown is the gentler action
}
static inline NSDictionary *MYBPCRecord(NSString *key,NSString *display,NSString *action,BOOL on,double now){
 return [NSDictionary dictionaryWithObjectsAndKeys:key,@"k",display?:@"",@"d",MYBPCNormalizeAction(action),@"a",[NSNumber numberWithDouble:now],@"t",[NSNumber numberWithBool:on],@"on",nil];
}
static inline BOOL MYBPCRecordValid(id r){
 if(![r isKindOfClass:NSDictionary.class])return NO;
 id k=[r objectForKey:@"k"],t=[r objectForKey:@"t"],on=[r objectForKey:@"on"];
 return [k isKindOfClass:NSString.class]&&[(NSString *)k length]&&[t isKindOfClass:NSNumber.class]&&[on isKindOfClass:NSNumber.class];
}
static inline NSInteger MYBPCOlderFirst(id x,id y,void *c){(void)c;return (NSInteger)[[x objectForKey:@"t"] compare:[y objectForKey:@"t"]];}
// Merge: the newest record per key wins (removals are kept as records so an old add cannot come back). When two records for a key have the same
// time, a removal beats an add, and two adds with different actions become Mute, the less disruptive one.
static inline NSArray *MYBPCMerge(NSArray *logA,NSArray *logB){
 NSMutableDictionary *best=[NSMutableDictionary dictionary];
 NSArray *both[2]={[logA isKindOfClass:NSArray.class]?logA:nil,[logB isKindOfClass:NSArray.class]?logB:nil};
 for(int i=0;i<2;i++)for(id r in both[i]){
  if(!MYBPCRecordValid(r))continue;
  NSString *k=[r objectForKey:@"k"];NSDictionary *have=[best objectForKey:k];
  double t=[[r objectForKey:@"t"] doubleValue],ht=have?[[have objectForKey:@"t"] doubleValue]:-1;
  BOOL on=[[r objectForKey:@"on"] boolValue],hon=have?[[have objectForKey:@"on"] boolValue]:NO;
  if(!have||t>ht)[best setObject:r forKey:k];
  else if(t==ht){
   if(hon&&!on)[best setObject:r forKey:k];
   else if(hon&&on&&![MYBPCNormalizeAction([r objectForKey:@"a"]) isEqual:MYBPCNormalizeAction([have objectForKey:@"a"])])
    [best setObject:MYBPCRecord(k,[have objectForKey:@"d"],MYB_PC_ACTION_MUTE,YES,t) forKey:k];
  }
 }
 NSMutableArray *out=[NSMutableArray arrayWithArray:[best allValues]];
 [out sortUsingFunction:MYBPCOlderFirst context:NULL];
 while(out.count>MYB_PC_MAX_RECORDS){   // drop the oldest removal first, then the oldest record
  NSUInteger drop=NSNotFound;for(NSUInteger i=0;i<out.count;i++)if(![[[out objectAtIndex:i] objectForKey:@"on"] boolValue]){drop=i;break;}
  [out removeObjectAtIndex:drop==NSNotFound?0:drop];
 }
 return out;
}
// The effective list: the numbers that are private right now.
static inline NSArray *MYBPCEffective(NSArray *logA,NSArray *logB){
 NSMutableArray *out=[NSMutableArray array];
 for(NSDictionary *r in MYBPCMerge(logA,logB))if([[r objectForKey:@"on"] boolValue])[out addObject:r];
 return out;
}
// Adds or replaces a record in one list (the list of the process that is writing). Keeps one record per key and the list short.
static inline NSArray *MYBPCLogWith(NSArray *log,NSDictionary *record){
 NSMutableArray *out=[NSMutableArray array];
 for(id r in ([log isKindOfClass:NSArray.class]?log:[NSArray array]))if(MYBPCRecordValid(r)&&![[r objectForKey:@"k"] isEqual:[record objectForKey:@"k"]])[out addObject:r];
 [out addObject:record];
 while(out.count>MYB_PC_MAX_RECORDS){   // drop the oldest removal first, then the oldest record
  NSUInteger drop=NSNotFound;for(NSUInteger i=0;i<out.count;i++)if(![[[out objectAtIndex:i] objectForKey:@"on"] boolValue]){drop=i;break;}
  [out removeObjectAtIndex:drop==NSNotFound?0:drop];
 }
 return out;
}
static inline NSDictionary *MYBPCEntryForKey(NSArray *effective,NSString *key){
 for(NSDictionary *e in effective)if([[e objectForKey:@"k"] isEqual:key])return e;
 return nil;
}
// The same telephone number however it was saved: with or without its country code, with or without the leading 0, typed or stored, and whatever country the
// phone happened to read it in. Only the digits count: they are the same when equal, or when the shorter (at least 7 digits) ends the longer by at most a
// country code and a trunk digit. This is how a number added with +34 and a call that arrives as 952 12 34 56 are one number.
static inline NSString *MYBPCDigitsOfKey(NSString *key){
 if(![key isKindOfClass:NSString.class])return @"";
 NSString *s=[key hasPrefix:@"n:"]?[[key componentsSeparatedByString:@":"] lastObject]:key;
 NSMutableString *d=[NSMutableString string];
 for(NSUInteger i=0;i<s.length;i++){unichar c=[s characterAtIndex:i];if(c>='0'&&c<='9')[d appendFormat:@"%C",c];}
 while([d hasPrefix:@"0"])[d deleteCharactersInRange:NSMakeRange(0,1)];   // international prefix and trunk zeros are not part of the number
 return d;
}
static inline BOOL MYBPCLooseSame(NSString *a,NSString *b){
 NSString *da=MYBPCDigitsOfKey(a),*db=MYBPCDigitsOfKey(b);
 if(!da.length||!db.length)return NO;
 if([da isEqualToString:db])return YES;
 NSString *sh=da.length<=db.length?da:db,*lg=da.length<=db.length?db:da;
 return sh.length>=7&&lg.length-sh.length<=4&&[lg hasSuffix:sh];
}
static inline NSDictionary *MYBPCEntryForKeyLoose(NSArray *effective,NSString *key){
 NSDictionary *exact=MYBPCEntryForKey(effective,key);
 if(exact)return exact;
 for(NSDictionary *e in effective)if(MYBPCLooseSame([e objectForKey:@"k"],key))return e;
 return nil;
}

// ---- calls -------------------------------------------------------------------------------------------------------------------------------
// Which entry a call belongs to. values: every number string the call carries (the dialled value, the normalised value, ...). The call matches when
// EVERY number it carries as a person matches an entry, and each of those resolves to one and the same entry. A call with no usable number, with
// several different people, or with one person who is not on the list is left alone (nil).
// A number dialed without a country code (a placed call keeps what was dialed) is read in the wrong country when Phone tags it differently from the
// number on the list. It still matches when its last nine digits are those of exactly one private number. A number that carries its own + never does.
static inline NSDictionary *MYBPCTailMatch(NSArray *effective,NSString *form){
 if(![form isKindOfClass:NSString.class])return nil;
 NSMutableString *digits=[NSMutableString string];
 for(NSUInteger i=0;i<form.length;i++){unichar c=[form characterAtIndex:i];if(c>='0'&&c<='9')[digits appendFormat:@"%C",c];else if(c=='+')return nil;else if(c!=' '&&c!='-'&&c!='('&&c!=')'&&c!='.'&&c!=0x00A0)return nil;}
 if(digits.length<9||digits.length>12||[digits hasPrefix:@"00"])return nil;
 NSString *tail=[digits substringFromIndex:digits.length-9];
 NSDictionary *only=nil;
 for(NSDictionary *e in effective){
  NSString *k=[e objectForKey:@"k"];
  if(![k isKindOfClass:NSString.class]||k.length<10)continue;
  if([[k substringFromIndex:k.length-9] isEqualToString:tail]){if(only&&![[only objectForKey:@"k"] isEqual:[e objectForKey:@"k"]])return nil;only=e;}
 }
 return only;
}
// Where the process may read the phone's contacts, a second way to match is installed here (MYBPCContactEntry): a call from another number of the same
// contact is the same person. Left NULL, only numbers match.
static NSDictionary *(*MYBPCContactFallback)(NSArray *effective,NSArray *people,NSString *region)=NULL;
static inline NSDictionary *MYBPCEntryForHandlesExact(NSArray *effective,NSArray *people,NSString *region){
 // people: array of arrays; each inner array holds the strings that describe ONE person (value, normalised value).
 if(!effective.count||!people.count)return nil;
 NSDictionary *found=nil;
 for(NSArray *forms in people){
  NSDictionary *hit=nil;BOOL any=NO;
  for(NSString *form in forms){
   NSString *key=MYBPCKey(form,region);
   if(!key)continue;
   any=YES;
   NSDictionary *e=MYBPCEntryForKeyLoose(effective,key);
   if(e&&!hit)hit=e;                              // two private entries for one number (saved in two ways) are one person
  }
  if(!hit)for(NSString *form in forms){NSDictionary *t=MYBPCTailMatch(effective,form);if(t){hit=t;any=YES;break;}}
  if(!any||!hit)return nil;                      // a person we cannot read, or one who is not private: the whole call stays visible
  if(!found)found=hit;                           // several private people: still private, the first entry decides
 }
 return found;
}

static inline NSDictionary *MYBPCEntryForHandles(NSArray *effective,NSArray *people,NSString *region){
 NSDictionary *hit=MYBPCEntryForHandlesExact(effective,people,region);
 if(!hit&&MYBPCContactFallback&&effective.count&&people.count)hit=MYBPCContactFallback(effective,people,region);
 return hit;
}

// Display only: groups digits in a readable way without changing what is stored. A key is shown as "+" and its digits, in blocks.
// How a number is shown: the way Phone shows it. A number of the phone's own country has no country code and is grouped the way Apple groups it
// (Spain: 612 34 56 78); a number of another country starts with +code (+1 (415) 555-0123).
static inline NSString *MYBPCGroup(NSString *digits,const char *iso){
 NSUInteger n=digits.length;
 if(iso&&!strcmp(iso,"ES")&&n==9)return [NSString stringWithFormat:@"%@ %@ %@ %@",[digits substringToIndex:3],[digits substringWithRange:NSMakeRange(3,2)],[digits substringWithRange:NSMakeRange(5,2)],[digits substringFromIndex:7]];
 if(iso&&(!strcmp(iso,"US")||!strcmp(iso,"CA"))&&n==10)return [NSString stringWithFormat:@"(%@) %@-%@",[digits substringToIndex:3],[digits substringWithRange:NSMakeRange(3,3)],[digits substringFromIndex:6]];
 if(n==9)return [NSString stringWithFormat:@"%@ %@ %@",[digits substringToIndex:3],[digits substringWithRange:NSMakeRange(3,3)],[digits substringFromIndex:6]];
 if(n==10)return [NSString stringWithFormat:@"%@ %@ %@",[digits substringToIndex:3],[digits substringWithRange:NSMakeRange(3,3)],[digits substringFromIndex:6]];
 if(n==8)return [NSString stringWithFormat:@"%@ %@",[digits substringToIndex:4],[digits substringFromIndex:4]];
 if(n==7)return [NSString stringWithFormat:@"%@ %@",[digits substringToIndex:3],[digits substringFromIndex:3]];
 NSMutableString *out=[NSMutableString string];
 for(NSUInteger i=0;i<n;i++){if(i>0&&i%3==0)[out appendString:@" "];[out appendFormat:@"%C",[digits characterAtIndex:i]];}
 return out;
}
static inline NSString *MYBPCFormat(NSString *key,NSString *deviceRegion){
 if(![key isKindOfClass:NSString.class]||!key.length)return @"";
 if(![key hasPrefix:@"+"]){
  NSArray *parts=[key componentsSeparatedByString:@":"];
  NSString *digits=[parts lastObject],*reg=parts.count>=3?[parts objectAtIndex:1]:nil;
  return MYBPCGroup(digits,reg.length?[reg UTF8String]:NULL);
 }
 NSString *digits=[key substringFromIndex:1];
 const MYBPCRegion *own=MYBPCFindRegion(deviceRegion),*best=NULL;
 for(size_t i=0;i<sizeof(MYBPCRegions)/sizeof(MYBPCRegions[0]);i++){
  NSString *cc=[NSString stringWithUTF8String:MYBPCRegions[i].cc];
  if([digits hasPrefix:cc]&&(!best||strlen(MYBPCRegions[i].cc)>strlen(best->cc)))best=&MYBPCRegions[i];
 }
 if(!best)return [@"+" stringByAppendingString:MYBPCGroup(digits,NULL)];
 NSString *national=[digits substringFromIndex:strlen(best->cc)];
 BOOL sameCountry=own&&!strcmp(own->cc,best->cc);
 const char *iso=sameCountry?own->iso:best->iso;
 if(sameCountry)return MYBPCGroup(national,iso);
 return [NSString stringWithFormat:@"+%s %@",best->cc,MYBPCGroup(national,iso)];
}
static inline NSString *MYBPCDisplayForKey(NSString *key){return MYBPCFormat(key,nil);}
// What a row is called: the contact's name when it is known, otherwise the formatted number. A stored label that is a name (has letters) is kept.
static inline NSString *MYBPCLabel(NSDictionary *entry,NSString *liveName,NSString *deviceRegion){
 if([liveName isKindOfClass:NSString.class]&&liveName.length)return liveName;
 NSString *d=[entry objectForKey:@"d"];
 if([d isKindOfClass:NSString.class]&&[d rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].length)return d;
 return MYBPCFormat([entry objectForKey:@"k"],deviceRegion);
}
// A name worth storing: it has letters (a number shown as a name is not a name).
static inline NSString *MYBPCNameOnly(id candidate){
 if(![candidate isKindOfClass:NSString.class]||![(NSString *)candidate length])return nil;
 return [(NSString *)candidate rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].length?candidate:nil;
}

// ---- the one decision for an incoming call ---------------------------------------------------------------------------------------------------
// Only an ordinary, still-ringing, incoming phone call from a private number gets an action, and only once. Everything else is normal call handling:
// emergency calls, calls already answered, FaceTime and other apps' calls, a call that was already handled, and Mute while another call is going
// (the call-waiting tone is not the ringtone).
typedef enum { MYBPCNothing = 0, MYBPCDoMute = 1, MYBPCDoDecline = 2, MYBPCDoHangup = 3 } MYBPCDecision;
static inline NSString *MYBPCActionName(id action){return [action isEqual:MYB_PC_ACTION_DECLINE]?@"Decline":[action isEqual:MYB_PC_ACTION_HANGUP]?@"Hang up":@"Mute";}
static inline MYBPCDecision MYBPCDecide(NSDictionary *entry,BOOL switchOn,BOOL incoming,BOOL answeredOrConnected,BOOL ordinaryPhoneCall,BOOL emergency,BOOL alreadyHandled,BOOL otherCallActive){
 if(!switchOn||!entry||!incoming||answeredOrConnected||!ordinaryPhoneCall||emergency||alreadyHandled)return MYBPCNothing;
 if([[entry objectForKey:@"a"] isEqual:MYB_PC_ACTION_DECLINE])return MYBPCDoDecline;
 if([[entry objectForKey:@"a"] isEqual:MYB_PC_ACTION_HANGUP])return otherCallActive?MYBPCDoDecline:MYBPCDoHangup;   // answering would put the call in progress on hold, so with another call going it is declined
 return otherCallActive?MYBPCNothing:MYBPCDoMute;
}

// ---- call-history entries ---------------------------------------------------------------------------------------------------------------------
// Reads a Recents entry (a call-history object) only through its own getters, and only the numbers and the in/out/answered facts. Names are never read here, so
// a name two contacts share can never hide anyone: only a number on the list does.
static inline id MYBPCValue(id object,NSString *key){
 if(!object||![object respondsToSelector:NSSelectorFromString(key)])return nil;
 @try{return [object valueForKey:key];}@catch(NSException *e){(void)e;return nil;}
}
static inline NSArray *MYBPCPeopleOfRecent(id call,NSString **region){
 NSMutableArray *people=[NSMutableArray array];
 id handles=MYBPCValue(call,@"remoteParticipantHandles");
 if([handles isKindOfClass:NSSet.class]&&[handles count]){
  for(id handle in handles){
   NSMutableArray *forms=[NSMutableArray array];
   for(NSString *name in [NSArray arrayWithObjects:@"value",@"normalizedValue",nil]){id v=MYBPCValue(handle,name);if([v isKindOfClass:NSString.class]&&[v length])[forms addObject:v];}
   [people addObject:forms];
  }
 }else{
  id callerId=MYBPCValue(call,@"callerId");
  if([callerId isKindOfClass:NSString.class]&&[callerId length])[people addObject:[NSArray arrayWithObject:callerId]];
 }
 id iso=MYBPCValue(call,@"isoCountryCode");
 if(region&&[iso isKindOfClass:NSString.class]&&[iso length]==2)*region=iso;
 return people;
}
static inline NSDictionary *MYBPCEntryForRecent(id call,NSArray *effective,NSString *deviceRegion){
 NSString *region=nil;NSArray *people=MYBPCPeopleOfRecent(call,&region);
 return MYBPCEntryForHandles(effective,people,region?:deviceRegion);
}
// The list Phone shows: every entry that is not private, in the order Phone gave them. Nothing else about the list changes, so "All" and "Missed" (which Phone
// builds from the same entries) both lose only the private numbers' calls.
static inline NSArray *MYBPCFilterRecents(NSArray *all,NSArray *effective,NSString *deviceRegion){
 if(![all isKindOfClass:NSArray.class]||!effective.count)return all;
 NSMutableArray *kept=[NSMutableArray arrayWithCapacity:all.count];
 for(id call in all)if(!MYBPCEntryForRecent(call,effective,deviceRegion))[kept addObject:call];
 return kept.count==all.count?all:kept;
}
// kind: "Outgoing", "Received" or "Missed"
static inline BOOL MYBPCAnyTrue(id call,NSArray *keys){for(NSString *k in keys){id v=MYBPCValue(call,k);if([v respondsToSelector:@selector(boolValue)]&&[v boolValue])return YES;}return NO;}
// Phone's call record does not carry the same flag names on every iOS build, so several are tried, and a call that lasted is counted as answered.
static inline NSString *MYBPCKindOfRecent(id call){
 id status=MYBPCValue(call,@"callStatus");
 if([status respondsToSelector:@selector(unsignedIntValue)]){                                   // Phone's own status bits: 8 missed, 1 or 4 placed, 2 received
  unsigned st=[status unsignedIntValue];
  if(st&8)return @"Missed";
  if(st&(1|4))return @"Outgoing";
  if(st&2)return @"Received";
 }
 BOOL out=MYBPCAnyTrue(call,[NSArray arrayWithObjects:@"mobileOriginated",@"originated",@"outgoing",@"isOutgoing",@"outgoingCall",nil]);
 id duration=MYBPCValue(call,@"duration");
 BOOL answered=MYBPCAnyTrue(call,[NSArray arrayWithObjects:@"answered",@"wasAnswered",@"isAnswered",nil])||([duration respondsToSelector:@selector(doubleValue)]&&[duration doubleValue]>0);
 return out?@"Outgoing":answered?@"Received":@"Missed";
}
// For the list of private numbers: the name and the number together, so two numbers of one contact can be told apart.
static inline NSString *MYBPCLabelWithNumber(NSDictionary *entry,NSString *liveName,NSString *region){
 NSString *label=MYBPCLabel(entry,liveName,region),*number=MYBPCFormat([entry objectForKey:@"k"],region);
 if(!label.length)return number;
 if(!number.length||[label isEqualToString:number])return label;
 return [NSString stringWithFormat:@"%@ · %@",label,number];
}
