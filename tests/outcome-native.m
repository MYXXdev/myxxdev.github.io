// Every reset / Proxy Override message is checked against what the transaction actually did.
#import <Foundation/Foundation.h>
#import "../Shared/MYBOutcomeText.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){printf("FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static BOOL has(NSString *s,NSString *t){return [s.lowercaseString containsString:t.lowercaseString];}
int main(void){@autoreleasepool{
 NSDictionary *o=MYBResetOutcome(0,@{},YES);
 CHECK([o[@"kind"] isEqual:@"success"]&&has(o[@"detail"],@"respring"),"clean reset: success, respring advice when asked");
 CHECK(!has(MYBResetOutcome(0,@{},NO)[@"detail"],@"respring"),"no respring advice when nothing needs it");
 o=MYBResetOutcome(90,@{@"exceptions":@[@"protection-left-off"]},NO);
 CHECK([o[@"kind"] isEqual:@"partial"]&&has(o[@"detail"],@"not a complete")&&has(o[@"detail"],@"off")&&has(o[@"detail"],@"remove"),"foreign proxy: partial, says protection is off, names the next step");
 CHECK(!has(o[@"title"],@"Restored")||has(o[@"title"],@"Partly"),"a partial reset never carries the plain success title");
 o=MYBResetOutcome(90,@{@"exceptions":@[@"controlcenter-unavailable",@"supervision-unchanged"]},NO);
 CHECK(has(o[@"detail"],@"Control Centre")&&!has(o[@"detail"],@"YouTopia")&&has(o[@"detail"],@"supervision"),"each skipped component is named");
 o=MYBResetOutcome(91,@{},NO);CHECK(has(o[@"detail"],@"put your previous settings back")&&[o[@"kind"] isEqual:@"failed"],"verification failure that was rolled back says so");
 o=MYBResetOutcome(92,@{},NO);CHECK(!has(o[@"detail"],@"nothing was changed")&&!has(o[@"detail"],@"still in place")&&has(o[@"detail"],@"repair"),"mixed state never claims the old settings are intact");
 for(NSNumber *rc in @[@124,@125]){o=MYBResetOutcome(rc.intValue,@{},NO);CHECK(!has(o[@"detail"],@"nothing was changed")&&!has(o[@"detail"],@"still in place")&&!has(o[@"detail"],@"unchanged"),"a killed or timed-out helper never claims 'unchanged'");}
 o=MYBResetOutcome(73,@{},NO);CHECK(has(o[@"detail"],@"still in place"),"an ordinary pre-commit or self-rolled-back failure does say unchanged");
 o=MYBResetOutcome(75,@{},NO);CHECK(has(o[@"title"],@"busy"),"lock busy is explained");
 CHECK([MYBProxyOutcome(0)[@"kind"] isEqual:@"success"],"proxy success");
 CHECK(!has(MYBProxyOutcome(94)[@"detail"],@"previous working setup was restored")&&has(MYBProxyOutcome(94)[@"detail"],@"repair"),"proxy: failed rollback is not reported as restored");
 CHECK(has(MYBProxyOutcome(69)[@"detail"],@"restored"),"proxy: a rolled-back failure says the previous setup was restored");
 CHECK(!has(MYBProxyOutcome(125)[@"detail"],@"restored")&&!has(MYBProxyOutcome(125)[@"detail"],@"unchanged"),"proxy: a killed helper makes no claim");
 CHECK(has(MYBProxyOutcome(3)[@"detail"],@"nothing was changed"),"proxy: foreign configuration refused up front");
 {int codes[]={0,3,75,76,78,80,81,82,99};for(int i=0;i<9;i++){NSDictionary *o=MYBProfileOutcome(codes[i]);
   if(!o[@"title"]||!o[@"detail"]||[o[@"title"] length]<5||(codes[i]!=0&&![o[@"kind"] isEqual:@"failed"])||(codes[i]==0&&![o[@"kind"] isEqual:@"success"])){fprintf(stderr,"FAIL: profile outcome %d malformed\n",codes[i]);failures++;}
   if(codes[i]==82&&([o[@"detail"] containsString:@"unchanged"]||![o[@"detail"] containsString:@"saved"])){fprintf(stderr,"FAIL: 82 must not claim unchanged and must say the choice is saved\n");failures++;}
   if(codes[i]==81&&![o[@"detail"] containsString:@"nothing else was changed"]){fprintf(stderr,"FAIL: 81 wording\n");failures++;}}}
 printf(failures?"%d outcome check(s) FAILED\n":"Outcome message checks passed.\n",failures);return failures?1:0;}}
