#pragma once
// Rule-generation identity for PAC files: the rule date and a digest of a whole bundled PAC set.
// Pure functions so the native tests exercise the shipping code.
//
// Every date is turned into one comparable value, YYYYMMDDHHMM in UTC ("a stamp"); 0 means "no usable date".
//
// Formats read from a PAC (first 512 bytes):
//   1. current   "// Updated: YYYY/MM/DD - HH:MM UTC"          exact, already UTC.
//   2. numeric   "var MYB_STAMP=YYYYMMDDHHMM;"                 written by earlier generators; no zone recorded.
//   3. legacy    "// Updated: MM/DD/YY - HH:MM[ ZONE]"         written by the oldest releases.
// Zones understood for legacy headers: UTC GMT (0), CET (+1), CEST (+2), EST (-5), EDT (-4), CST (-6), CDT (-5),
// MST (-7), MDT (-6), PST (-8), PDT (-7). They are converted before any comparison, so
// "11/20/26 - 01:10 CET" and "2026/11/20 - 00:10 UTC" are the same stamp.
// A legacy header without a zone and every numeric MYB_STAMP are AMBIGUOUS: no zone was recorded. They are read
// as CET, the zone of the newest releases that used them, because treating them as UTC would make an old-engine
// copy of today's rules look an hour newer than the same rules in the new format and keep it active forever.
// A legacy header with a zone name that is not in the list, an impossible date (month 13, 30 February, hour 24 ...)
// or a year outside 2000-2099 is not a date at all: the stamp is 0.
#import <Foundation/Foundation.h>
#ifndef MYB_STAMP_ONLY
#import <CommonCrypto/CommonDigest.h>
#endif

enum {MYBStampKindNone=0,MYBStampKindUTC=1,MYBStampKindLegacyZone=2,MYBStampKindAmbiguous=3};

static inline long long MYBDaysFromCivil(long long y,long long m,long long d){
 y-=m<=2;long long era=(y>=0?y:y-399)/400;long long yoe=y-era*400;long long doy=(153*(m+(m>2?-3:9))+2)/5+d-1;long long doe=yoe*365+yoe/4-yoe/100+doy;return era*146097+doe-719468;
}
static inline void MYBCivilFromDays(long long z,long long *y,long long *m,long long *d){
 z+=719468;long long era=(z>=0?z:z-146096)/146097;long long doe=z-era*146097;long long yoe=(doe-doe/1460+doe/36524-doe/146096)/365;long long yy=yoe+era*400;long long doy=doe-(365*yoe+yoe/4-yoe/100);long long mp=(5*doy+2)/153;
 *d=doy-(153*mp+2)/5+1;*m=mp<10?mp+3:mp-9;*y=yy+(*m<=2);
}
static inline long long MYBG(NSArray<NSString *> *g,NSUInteger i){return [[g objectAtIndex:i] longLongValue];}
// Calendar-validated local time plus its offset from UTC in minutes -> UTC stamp; 0 when the date is impossible.
static inline long long MYBStampFromLocal(long long y,long long mo,long long d,long long h,long long mi,long long offsetMinutes){
 if(y<2000||y>2099||mo<1||mo>12||d<1||h<0||h>23||mi<0||mi>59)return 0;
 static const int dim[12]={31,28,31,30,31,30,31,31,30,31,30,31};
 long long days=dim[mo-1]+(mo==2&&((y%4==0&&y%100!=0)||y%400==0)?1:0);if(d>days)return 0;
 long long minutes=MYBDaysFromCivil(y,mo,d)*1440+h*60+mi-offsetMinutes;
 long long day=minutes>=0?minutes/1440:-((-minutes+1439)/1440),rest=minutes-day*1440;
 long long uy,um,ud;MYBCivilFromDays(day,&uy,&um,&ud);
 if(uy<2000||uy>2099)return 0;
 return (((uy*100+um)*100+ud)*100+rest/60)*100+rest%60;
}
// Offset in minutes for a named zone; NO when the name is not one of the documented zones.
static inline BOOL MYBLegacyZoneOffset(NSString *zone,long long *offset){
 static const struct{const char *name;int hours;}zones[]={{"UTC",0},{"GMT",0},{"CET",1},{"CEST",2},{"EST",-5},{"EDT",-4},{"CST",-6},{"CDT",-5},{"MST",-7},{"MDT",-6},{"PST",-8},{"PDT",-7}};
 for(size_t i=0;i<sizeof(zones)/sizeof(zones[0]);i++)if([zone isEqualToString:[NSString stringWithUTF8String:zones[i].name]]){*offset=zones[i].hours*60;return YES;}
 return NO;
}
static inline NSString *MYBStampHead(NSData *data){
 if(![data isKindOfClass:NSData.class]||!data.length)return nil;
 return [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0,MIN((NSUInteger)512,data.length))] encoding:NSISOLatin1StringEncoding];
}
static inline NSArray<NSString *> *MYBStampGroups(NSString *text,NSString *pattern){
 NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
 NSTextCheckingResult *m=[re firstMatchInString:text options:0 range:NSMakeRange(0,text.length)];if(!m)return nil;
 NSMutableArray *groups=[NSMutableArray array];
 for(NSUInteger i=1;i<m.numberOfRanges;i++){NSRange r=[m rangeAtIndex:i];[groups addObject:r.location==NSNotFound?@"":[text substringWithRange:r]];}
 return groups;
}
// The stamp and how it was read. `kind` may be NULL.
static inline long long MYBPACStampRead(NSData *data,int *kind){
 if(kind)*kind=MYBStampKindNone;
 NSString *head=MYBStampHead(data);if(!head)return 0;
 NSArray<NSString *> *g=MYBStampGroups(head,@"(?:^|\\n)// Updated: (\\d{4})/(\\d{2})/(\\d{2}) - (\\d{2}):(\\d{2}) UTC(?=\\r?\\n|$)");
 if(g){long long v=MYBStampFromLocal(MYBG(g,0),MYBG(g,1),MYBG(g,2),MYBG(g,3),MYBG(g,4),0);if(v&&kind)*kind=MYBStampKindUTC;return v;}
 g=MYBStampGroups(head,@"(?:^|\\n)var MYB_STAMP=(\\d{12});");
 if(g){long long n=MYBG(g,0);
  // YYYYMMDDHHMM: minute=n%100, hour=(n/100)%100, day=(n/10000)%100, month=(n/1000000)%100, year=n/100000000.
  long long v=MYBStampFromLocal(n/100000000LL,(n/1000000LL)%100,(n/10000LL)%100,(n/100LL)%100,n%100,60);if(v&&kind)*kind=MYBStampKindAmbiguous;return v;}
 g=MYBStampGroups(head,@"(?:^|\\n)// Updated: (\\d{2})/(\\d{2})/(\\d{2}) - (\\d{2}):(\\d{2})(?: ([A-Za-z]{2,5}))?(?=\\s|$)");
 if(g){long long offset=60;BOOL zoned=NO;
  if([[g objectAtIndex:5] length]){if(!MYBLegacyZoneOffset([g objectAtIndex:5],&offset))return 0;zoned=YES;}
  long long v=MYBStampFromLocal(2000+MYBG(g,2),MYBG(g,0),MYBG(g,1),MYBG(g,3),MYBG(g,4),offset);
  if(v&&kind)*kind=zoned?MYBStampKindLegacyZone:MYBStampKindAmbiguous;return v;}
 return 0;
}
// Sortable YYYYMMDDHHMM in UTC; 0 when the PAC has no usable date.
static inline long long MYBPACStamp(NSData *data){return MYBPACStampRead(data,NULL);}
// Strict reader for the `stamp` of canonical.json: exactly "YYYY/MM/DD - HH:MM UTC" and a real date; otherwise 0.
static inline long long MYBCanonicalStamp(id text){
 if(![text isKindOfClass:NSString.class])return 0;
 NSArray<NSString *> *g=MYBStampGroups(text,@"\\A(\\d{4})/(\\d{2})/(\\d{2}) - (\\d{2}):(\\d{2}) UTC\\z");if(!g)return 0;
 return MYBStampFromLocal(MYBG(g,0),MYBG(g,1),MYBG(g,2),MYBG(g,3),MYBG(g,4),0);
}
// "YYYY/MM/DD - HH:MM UTC", the format shown to the person and written to PAC headers.
static inline NSString *MYBPACStampText(long long stamp){
 if(stamp<=0)return @"unknown";
 return [NSString stringWithFormat:@"%04lld/%02lld/%02lld - %02lld:%02lld UTC",stamp/100000000LL,(stamp/1000000LL)%100,(stamp/10000LL)%100,(stamp/100)%100,stamp%100];
}
// Engine identity, separate from the age of the rules: a PAC written by the current generator carries the exact
// UTC header; every earlier generator wrote a numeric MYB_STAMP or a legacy header. A set whose Default is not
// engine-current is converted even when its rules describe the same instant.
static inline BOOL MYBPACEngineCurrent(NSData *data){
 int kind=0;if(!MYBPACStampRead(data,&kind)||kind!=MYBStampKindUTC)return NO;
 NSString *head=MYBStampHead(data);return [head hasPrefix:@"//\n// MYbloXX by MYXXdev ("]&&![head containsString:@"MYB_STAMP"];
}
// A stamp from a downloaded release must be a real date, not before 2020 and not more than 7 days ahead of this device's clock.
static inline BOOL MYBStampPlausible(long long stamp,NSDate *now){
 if(stamp<202001010000LL)return NO;
 time_t t=(time_t)[now timeIntervalSince1970]+7*86400;struct tm utc;gmtime_r(&t,&utc);
 long long limit=MYBStampFromLocal(utc.tm_year+1900,utc.tm_mon+1,utc.tm_mday,utc.tm_hour,utc.tm_min,0);
 return limit&&stamp<=limit;
}
#ifndef MYB_STAMP_ONLY
// SHA-256 over name, length and bytes of every file in order; nil if any file is missing or unreadable.
static inline NSString *MYBPACSetDigest(NSString *directory,NSArray<NSString *> *modes){
 CC_SHA256_CTX ctx;CC_SHA256_Init(&ctx);
 for(NSString *mode in modes){
  NSData *data=[NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:[mode stringByAppendingString:@".pac"]] options:0 error:NULL];
  if(!data.length)return nil;
  NSString *head=[NSString stringWithFormat:@"%@\n%lu\n",mode,(unsigned long)data.length];const char *h=head.UTF8String;
  CC_SHA256_Update(&ctx,h,(CC_LONG)strlen(h));CC_SHA256_Update(&ctx,data.bytes,(CC_LONG)data.length);
 }
 unsigned char out[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(out,&ctx);
 NSMutableString *hex=[NSMutableString string];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",out[i]];return hex;
}
#endif
