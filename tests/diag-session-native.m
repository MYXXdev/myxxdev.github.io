// Focused check of Shared/MYBDiagSession.h: bounded, opt-in session and a domains-only export (GNU runtime friendly).
#import "../Shared/MYBDiagSession.h"
static int fails=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL %s\n",m);fails++;}}while(0)
int main(void){@autoreleasepool{
 NSString *f=@"/tmp/mybloxx-diag-test.plist";[NSFileManager.defaultManager removeItemAtPath:f error:NULL];
 CHECK(![[MYBDiagState(f,1000) objectForKey:@"active"] boolValue],"no session until started");
 CHECK(MYBDiagStart(f,1000)&&[[MYBDiagState(f,1100) objectForKey:@"active"] boolValue],"start makes it active");
 NSDictionary *late=MYBDiagState(f,1000+MYB_DIAG_MAX_SECONDS+5);
 CHECK(![[late objectForKey:@"active"] boolValue]&&[[late objectForKey:@"end"] doubleValue]==1000+MYB_DIAG_MAX_SECONDS,"a session never stopped ends by itself at the limit");
 CHECK(MYBDiagStop(f,1500),"stop works");NSDictionary *stopped=MYBDiagState(f,1600);
 CHECK(![[stopped objectForKey:@"active"] boolValue]&&[[stopped objectForKey:@"end"] doubleValue]==1500,"stopped session records its end");
 NSDictionary *a1=[NSDictionary dictionaryWithObjectsAndKeys:@"ads.example.com",@"host",[NSNumber numberWithInt:3],@"b",[NSNumber numberWithInt:0],@"a",[NSNumber numberWithDouble:1200],@"last",[NSDictionary dictionaryWithObject:[NSDictionary dictionary] forKey:@"Safari"],@"apps",nil];
 NSDictionary *a2=[NSDictionary dictionaryWithObjectsAndKeys:@"old.example.com",@"host",[NSNumber numberWithInt:1],@"b",[NSNumber numberWithInt:0],@"a",[NSNumber numberWithDouble:500],@"last",nil];
 NSDictionary *a3=[NSDictionary dictionaryWithObjectsAndKeys:@"evil.com/path?token=abc",@"host",[NSNumber numberWithInt:1],@"b",[NSNumber numberWithInt:0],@"a",[NSNumber numberWithDouble:1300],@"last",nil];
 NSDictionary *a4=[NSDictionary dictionaryWithObjectsAndKeys:@"cdn.example.com",@"host",[NSNumber numberWithInt:0],@"b",[NSNumber numberWithInt:4],@"a",[NSNumber numberWithDouble:1400],@"last",nil];
 NSString *out=MYBDiagExport([NSArray arrayWithObjects:a1,a2,a3,a4,nil],stopped,YES,YES,[NSArray arrayWithObject:@"example.com"],[NSArray array]);
 CHECK([out containsString:@"ads.example.com"]&&[out containsString:@"Safari"],"in-window host and app are listed");
 CHECK(![out containsString:@"old.example.com"],"a host seen before the session is left out");
 CHECK(![out containsString:@"token"]&&![out containsString:@"?"]&&![out containsString:@"://"],"no query strings, paths or links in the export");
 CHECK([out containsString:@"allowed by your rule"],"a matching user rule is named");
 NSString *bare=MYBDiagExport([NSArray arrayWithObject:a1],stopped,NO,NO,[NSArray array],[NSArray array]);
 CHECK(![bare containsString:@"Safari"]&&![bare containsString:@" - 3"],"app and count appear only when asked for");
 NSMutableArray *many=[NSMutableArray array];for(int i=0;i<400;i++)[many addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"h%d.example.com",i],@"host",[NSNumber numberWithInt:1],@"b",[NSNumber numberWithDouble:1200],@"last",nil]];
 NSString *big=MYBDiagExport(many,stopped,NO,NO,[NSArray array],[NSArray array]);
 CHECK([[big componentsSeparatedByString:@"\n"] count]<=MYB_DIAG_MAX_ROWS+4,"export size is capped");
 CHECK([MYBDiagExport([NSArray array],stopped,NO,NO,[NSArray array],[NSArray array]) hasPrefix:@"Nothing"],"empty session says so");
 CHECK(MYBDiagClear(f)&&![[MYBDiagState(f,2000) objectForKey:@"active"] boolValue],"clear removes the session");
 MYBDiagStart(f,1000);MYBDiagStop(f,1100);CHECK([[MYBDiagState(f,1100+MYB_DIAG_KEEP_SECONDS+10) objectForKey:@"start"] doubleValue]==0,"old results clear themselves");
 if(fails){fprintf(stderr,"%d failed\n",fails);return 1;}puts("diag-session-native ok");return 0;}}
