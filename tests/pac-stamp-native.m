// The PAC date reader (Shared/MYBPACStamp.h): UTC format, legacy zones, numeric stamps, invalid dates, ambiguity, engine identity.
#import "../Shared/MYBPACStamp.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static NSData *D(NSString *s){return [s dataUsingEncoding:NSUTF8StringEncoding];}
static NSData *Hdr(NSString *stamp){return D([NSString stringWithFormat:@"//\n// MYbloXX by MYXXdev (Default)\n// Updated: %@\n// Support Development: myxxfm.com/donate\n//\nvar x=1;",stamp]);}
static NSData *Legacy(NSString *line){return D([NSString stringWithFormat:@"//\n// MYbloXX by MYXXdev (Default)\n// Updated: %@\n//\nvar x=1;",line]);}
int main(int argc,char **argv){@autoreleasepool{
 (void)argc;(void)argv;
 int k=0;
 CHECK(MYBPACStampRead(Hdr(@"2026/11/20 - 00:10 UTC"),&k)==202611200010LL&&k==MYBStampKindUTC,"current UTC header");
 CHECK([MYBPACStampText(202611200010LL) isEqual:@"2026/11/20 - 00:10 UTC"],"stamp text is YYYY/MM/DD - HH:MM UTC");
 CHECK([MYBPACStampText(0) isEqual:@"unknown"],"no stamp is shown as unknown");
 // the required equality, and the other zones
 CHECK(MYBPACStamp(Legacy(@"11/20/26 - 01:10 CET"))==MYBPACStamp(Hdr(@"2026/11/20 - 00:10 UTC")),"11/20/26 - 01:10 CET equals 2026/11/20 - 00:10 UTC");
 CHECK(MYBPACStampRead(Legacy(@"11/20/26 - 01:10 CET"),&k)==202611200010LL&&k==MYBStampKindLegacyZone,"CET header normalises to UTC");
 CHECK(MYBPACStamp(Legacy(@"07/01/26 - 12:00 CEST"))==202607011000LL,"CEST is +2");
 CHECK(MYBPACStamp(Legacy(@"11/15/26 - 11:25 MST"))==202611151825LL,"MST is -7 (11:25 MST = 18:25 UTC)");
 CHECK(MYBPACStamp(Legacy(@"07/15/26 - 11:25 MDT"))==202607151725LL,"MDT is -6");
 CHECK(MYBPACStamp(Legacy(@"11/15/26 - 11:25 PST"))==202611151925LL&&MYBPACStamp(Legacy(@"07/15/26 - 11:25 PDT"))==202607151825LL,"PST/PDT");
 CHECK(MYBPACStamp(Legacy(@"11/15/26 - 11:25 EST"))==202611151625LL&&MYBPACStamp(Legacy(@"07/15/26 - 11:25 EDT"))==202607151525LL,"EST/EDT");
 CHECK(MYBPACStamp(Legacy(@"11/15/26 - 11:25 CST"))==202611151725LL&&MYBPACStamp(Legacy(@"07/15/26 - 11:25 CDT"))==202607151625LL,"CST/CDT");
 CHECK(MYBPACStamp(Legacy(@"11/15/26 - 11:25 UTC"))==202611151125LL&&MYBPACStamp(Legacy(@"11/15/26 - 11:25 GMT"))==202611151125LL,"UTC/GMT");
 // crossing a day, month and year boundary
 CHECK(MYBPACStamp(Legacy(@"11/30/26 - 20:00 MST"))==202612010300LL,"MST evening rolls into the next month");
 CHECK(MYBPACStamp(Legacy(@"12/31/26 - 20:00 MST"))==202701010300LL,"MST evening rolls into the next year");
 CHECK(MYBPACStamp(Legacy(@"01/01/27 - 00:30 CET"))==202612312330LL,"CET after midnight rolls back into the previous year");
 CHECK(MYBPACStamp(Legacy(@"03/01/28 - 00:30 CET"))==202802292330LL,"leap day reached through the offset");
 // ambiguous: no zone, and numeric stamps, both read as CET
 CHECK(MYBPACStampRead(Legacy(@"11/20/26 - 01:10"),&k)==202611200010LL&&k==MYBStampKindAmbiguous,"a legacy header without a zone is ambiguous and read as CET");
 CHECK(MYBPACStampRead(D(@"var MYB_STAMP=202611200110;var y=2;"),&k)==202611200010LL&&k==MYBStampKindAmbiguous,"numeric stamp: correct field positions, read as CET");
 CHECK(MYBPACStamp(D(@"var MYB_STAMP=202611200110;"))==MYBPACStamp(Hdr(@"2026/11/20 - 00:10 UTC")),"the numeric CET stamp of an old-engine copy equals the same rules in the new format");
 CHECK(MYBPACStamp(D(@"function f(){}\nvar MYB_STAMP=202601010030;"))==202512312330LL,"numeric stamp on a later line");
 // not a date at all
 CHECK(MYBPACStamp(D(@"var MYB_STAMP=202613200110;"))==0,"numeric: month 13");
 CHECK(MYBPACStamp(D(@"var MYB_STAMP=202602300110;"))==0,"numeric: 30 February");
 CHECK(MYBPACStamp(D(@"var MYB_STAMP=202611202410;"))==0,"numeric: hour 24");
 CHECK(MYBPACStamp(D(@"var MYB_STAMP=202611200160;"))==0,"numeric: minute 60");
 CHECK(MYBPACStamp(D(@"var MYB_STAMP=2026112001;"))==0,"numeric: too short");
 CHECK(MYBPACStamp(Hdr(@"2026/13/20 - 00:10 UTC"))==0&&MYBPACStamp(Hdr(@"2026/02/29 - 00:10 UTC"))==0&&MYBPACStamp(Hdr(@"2028/02/29 - 00:10 UTC"))==202802290010LL,"UTC header: month 13 and 29 February 2026 rejected, 29 February 2028 accepted");
 CHECK(MYBPACStamp(Hdr(@"2026/11/20 - 24:10 UTC"))==0&&MYBPACStamp(Hdr(@"2026/11/20 - 00:60 UTC"))==0,"UTC header: hour 24 and minute 60 rejected");
 CHECK(MYBPACStamp(Hdr(@"2026/11/20 - 00:10 CET"))==0,"a new-format date must say UTC");
 CHECK(MYBPACStamp(Hdr(@"2026/11/20 - 00:10"))==0&&MYBPACStamp(Hdr(@"2026-11-20 - 00:10 UTC"))==0&&MYBPACStamp(Hdr(@"2026/11/20 - 00:10 UTC extra"))==0,"missing zone, wrong separators and trailing text are not accepted");
 CHECK(MYBPACStamp(Legacy(@"11/20/26 - 01:10 XYZ"))==0,"an unknown zone name is not guessed");
 CHECK(MYBPACStamp(Legacy(@"13/20/26 - 01:10 CET"))==0&&MYBPACStamp(Legacy(@"02/30/26 - 01:10"))==0,"legacy: impossible dates");
 CHECK(MYBPACStamp(D(@"function FindProxyForURL(u,h){return 'DIRECT';}"))==0&&MYBPACStamp(D(@""))==0&&MYBPACStamp(nil)==0,"missing stamps are 0");
 CHECK(MYBPACStamp(Hdr(@"1999/11/20 - 00:10 UTC"))==0&&MYBPACStamp(Hdr(@"2100/01/01 - 00:10 UTC"))==0,"years outside 2000-2099 rejected");
 // comparison order
 CHECK(MYBPACStamp(Hdr(@"2026/11/20 - 00:11 UTC"))>MYBPACStamp(Legacy(@"11/20/26 - 01:10 CET")),"one minute later is newer");
 CHECK(MYBPACStamp(Hdr(@"2026/11/20 - 00:09 UTC"))<MYBPACStamp(D(@"var MYB_STAMP=202611200110;")),"one minute earlier is older");
 // canonical stamp: strict
 CHECK(MYBCanonicalStamp(@"2026/11/20 - 00:10 UTC")==202611200010LL,"canonical stamp");
 CHECK(MYBCanonicalStamp(@"11/20/26 - 01:10 CET")==0&&MYBCanonicalStamp(@"11/15/26 - 11:25 MST")==0&&MYBCanonicalStamp(@"2026/11/20 - 00:10 CET")==0,"canonical.json must use the UTC format");
 CHECK(MYBCanonicalStamp(@"2026/02/31 - 00:10 UTC")==0&&MYBCanonicalStamp(@" 2026/11/20 - 00:10 UTC")==0&&MYBCanonicalStamp(@"2026/11/20 - 00:10 UTC\n")==0&&MYBCanonicalStamp(nil)==0&&MYBCanonicalStamp(@5)==0&&MYBCanonicalStamp(@"")==0,"canonical: bad, padded, missing and non-string stamps");
 // engine identity is separate from age
 CHECK(MYBPACEngineCurrent(Hdr(@"2026/11/20 - 00:10 UTC")),"current engine");
 CHECK(!MYBPACEngineCurrent(D(@"var MYB_STAMP=202611200110;")),"numeric-stamp PAC is the old engine");
 CHECK(!MYBPACEngineCurrent(Legacy(@"11/20/26 - 01:10 CET"))&&!MYBPACEngineCurrent(Legacy(@"11/20/26 - 01:10")),"legacy-header PAC is the old engine");
 CHECK(!MYBPACEngineCurrent(D(@"//\n// Updated: 2026/11/20 - 00:10 UTC\nvar MYB_STAMP=202611200110;"))&&!MYBPACEngineCurrent(nil),"a UTC date alone is not proof of the new engine");
 // plausibility against the clock
 NSDate *now=[NSDate dateWithTimeIntervalSince1970:1795564800]; // 2026-11-25 00:00:00 UTC
 CHECK(MYBStampPlausible(202611200010LL,now)&&MYBStampPlausible(202611250000LL,now)&&MYBStampPlausible(202612010000LL,now),"recent and slightly future stamps are plausible");
 CHECK(!MYBStampPlausible(202612020100LL,now)&&!MYBStampPlausible(209901010000LL,now),"stamps more than 7 days ahead are not");
 CHECK(!MYBStampPlausible(0,now)&&!MYBStampPlausible(201912312359LL,now),"no stamp and pre-2020 stamps are not");
 if(failures){fprintf(stderr,"%d stamp check(s) FAILED\n",failures);return 1;}
 printf("PAC date reader checks passed.\n");
}return 0;}
