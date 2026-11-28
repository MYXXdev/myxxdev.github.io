// Branded supervision message: when it applies, and what it says. Pure logic; the Settings view rewrite itself is device-only.
#import <Foundation/Foundation.h>
#include "../Shared/MYBSupervisionMessage.h"
static int failures=0;
#define REQUIRE(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);failures++;}}while(0)
int main(void){@autoreleasepool{
 NSDictionary *ours=@{@"owner":@"net.myxxdev.mybloxx",@"createdFile":@YES,@"hadValue":@NO};
 NSDictionary *spoofOnly=@{@"IsSupervised":@YES};
 NSDictionary *on=@{@"enabled":@YES},*off=@{@"enabled":@NO};
 REQUIRE([MYBSupervisionMessage(spoofOnly,ours,on,nil) isEqual:@"This device is supervised and shielded by MYbloXX®"],"protected: enabled text, exact");
 REQUIRE([MYBSupervisionMessage(spoofOnly,ours,off,nil) isEqual:@"MYbloXX® protection is disabled."],"not protected: disabled text, exact");
 REQUIRE([MYBSupervisionMessage(spoofOnly,ours,nil,nil) isEqual:MYB_SUPERVISION_TEXT_OFF],"no state file: reads as not protected");
 NSDictionary *installed=@{@"checks":@{@"net.myxxdev.mybloxx":@{@"state":@"installed"}}},*staged=@{@"state":@"staged",@"checks":@{@"net.myxxdev.mybloxx":@{@"state":@"notinstalled"}}};
 REQUIRE([MYBSupervisionMessage(spoofOnly,ours,off,installed) isEqual:MYB_SUPERVISION_TEXT_LEGACY],"a Legacy profile that iOS reports as installed counts as protection");
 REQUIRE([MYBSupervisionMessage(spoofOnly,ours,off,staged) isEqual:MYB_SUPERVISION_TEXT_OFF],"a staged or not-installed profile is not protection");
 // never branded
 REQUIRE(MYBSupervisionMessage(@{@"IsSupervised":@YES,@"OrganizationName":@"Acme School"},ours,on,nil)==nil,"a genuine organisation notice is left alone");
 REQUIRE(MYBSupervisionMessage(@{@"IsSupervised":@YES,@"ConfigurationURL":@"https://mdm.example/enroll"},ours,on,nil)==nil,"an enrolment URL means it may be genuine");
 REQUIRE([MYBSupervisionMessage(@{@"IsSupervised":@YES,@"CloudConfigurationUIComplete":@YES,@"SomethingElse":@1},ours,on,nil) isEqual:MYB_SUPERVISION_TEXT_ON],"unrelated iOS bookkeeping keys do not stop the branded message");
 REQUIRE(MYBSupervisionMessage(@{@"IsSupervised":@YES,@"OrganizationMagic":@"x"},ours,on,nil)==nil&&MYBSupervisionMessage(@{@"IsSupervised":@YES,@"SupervisorHostCertificates":@[]},ours,on,nil)==nil&&MYBSupervisionMessage(@{@"IsSupervised":@YES,@"ConfigurationSource":@1},ours,on,nil)==nil,"any organisation or enrolment key leaves the notice alone");
 REQUIRE([MYBSupervisionMessage(spoofOnly,@{},on,nil) isEqual:MYB_SUPERVISION_TEXT_EXISTING_ON]&&[MYBSupervisionMessage(spoofOnly,nil,on,nil) isEqual:MYB_SUPERVISION_TEXT_EXISTING_ON],"supervision MYbloXX did not create shows the truthful text, never the ownership text");
 REQUIRE(![MYB_SUPERVISION_TEXT_EXISTING_ON containsString:@"shielded by"]&&![MYB_SUPERVISION_TEXT_EXISTING_ON containsString:@"supervised and"],"the existing-supervision text does not claim MYbloXX supervises the device");
 REQUIRE(MYBSupervisionMessage(spoofOnly,@{},off,nil)==nil,"an existing supervision with MYbloXX protection off keeps iOS's own text");
 REQUIRE([MYBSupervisionMessage(spoofOnly,@{},off,installed) isEqual:MYB_SUPERVISION_TEXT_EXISTING_LEGACY],"an existing supervision with an installed Legacy profile says so truthfully");
 REQUIRE(MYBSupervisionMessage(@{@"IsSupervised":@YES,@"OrganizationName":@"Acme School"},@{},on,nil)==nil&&MYBSupervisionMessage(@{@"IsSupervised":@YES,@"MDMEnrolled":@YES},nil,on,nil)==nil,"an organisation or MDM notice that is not ours is never rewritten");
 REQUIRE([MYBSupervisionMessage(spoofOnly,@{@"owner":@"com.example.other"},on,nil) isEqual:MYB_SUPERVISION_TEXT_EXISTING_ON],"another owner's record is not ours: the text never says MYbloXX supervises");
 REQUIRE(MYBSupervisionMessage(@{@"IsSupervised":@NO},ours,on,nil)==nil&&MYBSupervisionMessage(@{},ours,on,nil)==nil&&MYBSupervisionMessage(nil,ours,on,nil)==nil,"an unsupervised device gets no message");
 REQUIRE(![MYB_SUPERVISION_TEXT_ON containsString:@"—"]&&![MYB_SUPERVISION_TEXT_OFF containsString:@"—"],"no em dashes");
 if(failures)return 1;printf("Branded supervision message checks passed.\n");return 0;}}
