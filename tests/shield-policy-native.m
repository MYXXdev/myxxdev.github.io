#import <Foundation/Foundation.h>
#define MYB_RULE_TESTING 1
#define MYB_SHIELD_TESTING 1
double gMYBShieldWall=0,gMYBShieldMono=0;NSString *gMYBShieldBoot=nil;
#import "../Shared/MYBShield.h"
static int failures=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s (line %d)\n",m,__LINE__);failures++;}}while(0)
static void Clock(double wall,double mono,NSString *boot){gMYBShieldWall=wall;gMYBShieldMono=mono;gMYBShieldBoot=boot;}
int main(void){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",root.UTF8String,1);
 NSString *perm=MYBShieldPermissionsFile(),*act=MYBShieldActivityFile();
 Clock(1000000,5000,@"boot-A");

 // 1. scopes are never combined
 CHECK(MYBShieldAddGrant(perm,@"popup",@"Example.COM",nil,@"always")!=nil,"popup grant added (host normalised)");
 CHECK([MYBShieldAllows(perm,@"popup",@"example.com",nil,NO) isEqual:@"always"],"popup source allowed");
 CHECK([MYBShieldAllows(perm,@"popup",@"a.b.example.com",nil,NO) isEqual:@"always"],"subdomain of the source allowed");
 CHECK(MYBShieldAllows(perm,@"popup",@"notexample.com",nil,NO)==nil,"look-alike suffix rejected");
 CHECK(MYBShieldAllows(perm,@"appstore",@"com.apple.mobilesafari",nil,NO)==nil,"popup grant does not allow app store");
 CHECK(MYBShieldAddGrant(perm,@"appstore",@"com.apple.mobilesafari",nil,@"always")!=nil,"appstore grant added");
 CHECK(MYBShieldAllows(perm,@"appstore",@"org.mozilla.ios.Firefox",nil,NO)==nil,"appstore grant is per source app");
 CHECK(MYBShieldAllows(perm,@"appredirect",@"com.apple.mobilesafari",@"com.example.app",NO)==nil,"appstore grant does not allow other apps");
 CHECK(MYBShieldAddGrant(perm,@"appredirect",@"com.apple.mobilesafari",@"com.example.app",@"always")!=nil,"appredirect grant added");
 CHECK(MYBShieldAllows(perm,@"appredirect",@"com.apple.mobilesafari",@"com.example.other",NO)==nil,"appredirect is per destination");
 CHECK(MYBShieldAddGrant(perm,@"popup",@"bad host!",nil,@"always")==nil&&MYBShieldAddGrant(perm,@"appstore",@"nodots",nil,@"always")==nil&&MYBShieldAddGrant(perm,@"appstore",@"com.a.b",@"x.y.z",@"always")==nil&&MYBShieldAddGrant(perm,@"popup",@"x.com",nil,@"forever")==nil,"invalid input refused");

 // 2. one-time grant is consumed by the intended operation only
 CHECK(MYBShieldAddGrant(perm,@"popup",@"once.example",nil,@"once")!=nil,"once grant");
 CHECK([MYBShieldAllows(perm,@"popup",@"once.example",nil,NO) isEqual:@"once"],"peek does not consume");
 CHECK([MYBShieldAllows(perm,@"popup",@"once.example",nil,YES) isEqual:@"once"],"first use consumes");
 CHECK(MYBShieldAllows(perm,@"popup",@"once.example",nil,YES)==nil,"second use is not allowed (no reusable bypass)");
 // a standing grant is not burned by a once grant on the same source
 MYBShieldAddGrant(perm,@"popup",@"example.com",nil,@"always");MYBShieldAddGrant(perm,@"popup",@"sub.example.com",nil,@"once");
 CHECK([MYBShieldAllows(perm,@"popup",@"sub.example.com",nil,YES) isEqual:@"always"],"longer-lived grant wins");
 CHECK([MYBShieldAllows(perm,@"popup",@"sub.example.com",nil,YES) isEqual:@"always"],"standing grant keeps working");
 // once grant expires on its own
 MYBShieldAddGrant(perm,@"popup",@"late.example",nil,@"once");Clock(1000000+MYB_SHIELD_ONCE_SECONDS+1,5000+MYB_SHIELD_ONCE_SECONDS+1,@"boot-A");
 CHECK(MYBShieldAllows(perm,@"popup",@"late.example",nil,YES)==nil,"stale one-time grant expired");
 Clock(1000000,5000,@"boot-A");

 // 3. temporary grant: 15 minutes, clock changes can only shorten it
 NSDictionary *t=MYBShieldAddGrant(perm,@"popup",@"temp.example",nil,@"temp");CHECK(t!=nil,"temp grant");
 Clock(1000000+899,5000+899,@"boot-A");CHECK([MYBShieldAllows(perm,@"popup",@"temp.example",nil,NO) isEqual:@"temp"],"valid at 14:59");
 Clock(1000000+901,5000+901,@"boot-A");CHECK(MYBShieldAllows(perm,@"popup",@"temp.example",nil,NO)==nil,"expired at 15:01");
 MYBShieldAddGrant(perm,@"popup",@"temp2.example",nil,@"temp");
 Clock(1000000-86400*10,5000+10,@"boot-A");CHECK([MYBShieldAllows(perm,@"popup",@"temp2.example",nil,NO) isEqual:@"temp"],"wall clock moved back but monotonic time still inside the window: still valid");
 Clock(1000000-86400*10,5000+2000,@"boot-A");CHECK(MYBShieldAllows(perm,@"popup",@"temp2.example",nil,NO)==nil,"setting the wall clock back cannot extend a grant (monotonic expiry)");
 Clock(1000000+86400*30,5000+10,@"boot-A");CHECK(MYBShieldAllows(perm,@"popup",@"temp2.example",nil,NO)==nil,"setting the wall clock forward expires it early");
 Clock(1000000,5000,@"boot-A");MYBShieldAddGrant(perm,@"popup",@"boot.example",nil,@"temp");
 Clock(1000010,9,@"boot-B");CHECK(MYBShieldAllows(perm,@"popup",@"boot.example",nil,NO)==nil,"temporary grants do not survive a reboot");
 CHECK([MYBShieldAllows(perm,@"popup",@"example.com",nil,NO) isEqual:@"always"],"permanent grants survive a reboot");
 Clock(1000000,5000,@"boot-A");

 // 4. revoke + list
 NSDictionary *r=MYBShieldAddGrant(perm,@"appstore",@"com.test.app",nil,@"temp");
 CHECK(MYBShieldRevoke(perm,r[@"id"])&&MYBShieldAllows(perm,@"appstore",@"com.test.app",nil,NO)==nil,"revoke removes the grant");
 CHECK(!MYBShieldRevoke(perm,@"nope"),"revoking an unknown id changes nothing");
 NSUInteger live=MYBShieldLiveGrants(perm).count;CHECK(live>=4,"live list contains standing grants");

 // 5. backup/restore never permanentizes temporary or one-time grants
 MYBShieldAddGrant(perm,@"popup",@"onlytemp.example",nil,@"temp");MYBShieldAddGrant(perm,@"popup",@"onlyonce.example",nil,@"once");
 NSArray *exported=MYBShieldExportPermanent(perm);
 for(NSDictionary *e in exported){CHECK(e[@"mode"]==nil&&e[@"boot"]==nil&&e[@"wallExpiry"]==nil,"export carries no expiry fields");CHECK(![e[@"source"] isEqual:@"onlytemp.example"]&&![e[@"source"] isEqual:@"onlyonce.example"],"export excludes temporary and one-time grants");}
 CHECK(exported.count==3,"export has exactly the three standing grants");
 NSString *root2=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",root2.UTF8String,1);NSString *perm2=MYBShieldPermissionsFile();
 NSArray *valid=MYBShieldValidatedPermanent(exported);CHECK(valid.count==3&&MYBShieldReplacePermanent(perm2,valid),"restore applies validated list");
 for(NSDictionary *g in MYBShieldLiveGrants(perm2))CHECK([g[@"mode"] isEqual:@"always"],"restored grants are standing only");
 CHECK(MYBShieldValidatedPermanent(@[@{@"kind":@"popup",@"source":@"ok.example"},@{@"kind":@"bogus",@"source":@"x"}])==nil,"any malformed entry rejects the whole import");
 CHECK([MYBShieldValidatedPermanent(nil) count]==0,"older backups without the section restore as 'no change'");
 // temp grant on the target survives a restore untouched and is not promoted
 MYBShieldAddGrant(perm2,@"popup",@"t.example",nil,@"temp");MYBShieldReplacePermanent(perm2,@[]);
 CHECK([MYBShieldAllows(perm2,@"popup",@"t.example",nil,NO) isEqual:@"temp"]&&MYBShieldExportPermanent(perm2).count==0,"restore keeps temp as temp and exports nothing");
 setenv("MYB_FIXTURE_ROOT",root.UTF8String,1);

 // 6. Standard vs Strict
 NSDictionary *strict=@{@"Enabled":@YES,@"BlockPopups":@YES},*standard=@{@"Enabled":@YES,@"BlockPopups":@YES,@"PopupMode":@"standard"};
 CHECK(MYBShieldPopupVerdict(strict,1,NO)==MYBPopupBlockStrict,"Strict blocks even a user-gesture, first-party window");
 CHECK(MYBShieldPopupVerdict(strict,-1,NO)==MYBPopupBlockStrict&&MYBShieldPopupVerdict(strict,0,YES)==MYBPopupBlockStrict,"Strict blocks regardless of gesture/destination");
 CHECK(MYBShieldPopupVerdict(standard,0,NO)==MYBPopupBlockNoGesture,"Standard blocks windows without a tap/click");
 CHECK(MYBShieldPopupVerdict(standard,1,YES)==MYBPopupBlockDestination,"Standard blocks a window going to a blocked site");
 CHECK(MYBShieldPopupVerdict(standard,1,NO)==MYBPopupAllow&&MYBShieldPopupVerdict(standard,-1,NO)==MYBPopupAllow,"Standard allows an ordinary tap/click window");
 CHECK(MYBShieldPopupVerdict(@{@"Enabled":@YES,@"BlockPopups":@NO},0,YES)==MYBPopupAllow&&MYBShieldPopupVerdict(@{@"BlockPopups":@NO},0,YES)==MYBPopupAllow,"Block Browser Pop-Ups off means off");
 CHECK(MYBShieldPopupVerdict(@{@"Enabled":@NO,@"BlockPopups":@YES},0,YES)==MYBPopupBlockStrict,"the retired Browser Rules switch no longer disables popup blocking (migration clears it first)");
 CHECK(MYBShieldStrict(@{}),"unset mode keeps the existing block-everything behaviour");

 // 7. activity: capped, collapsed, host-only, clearable
 for(int i=0;i<5;i++)MYBShieldRecordActivity(act,@"popup",@"Src.Example",@"dst.example",@"popup-strict");
 NSArray *items=MYBShieldActivity(act);CHECK(items.count==1&&[items[0][@"count"] integerValue]==5,"repeated attempts collapse into one counted row");
 MYBShieldRecordActivity(act,@"website",@"com.apple.mobilesafari",@"https://x.example/path?token=SECRET",@"custom-rule");
 for(NSDictionary *i in MYBShieldActivity(act))CHECK(![[i description] containsString:@"SECRET"]&&![[i description] containsString:@"/path"],"no URL path/query is stored");
 for(int i=0;i<80;i++)MYBShieldRecordActivity(act,@"popup",[NSString stringWithFormat:@"h%d.example",i],@"d.example",@"popup-strict");
 CHECK(MYBShieldActivity(act).count==MYB_SHIELD_MAX_ACTIVITY,"retention is capped");
 CHECK([MYBShieldActivity(act)[0][@"source"] isEqual:@"h79.example"],"newest first");
 MYBShieldRecordActivity(act,@"bogus",@"a.example",@"b.example",@"x");MYBShieldRecordActivity(act,@"appstore",@"com.apple.mobilesafari",@"ignored.example",@"appstore");
 CHECK([MYBShieldActivity(act)[0][@"dest"] isEqual:@""],"app store rows carry no invented destination");
 CHECK(MYBShieldClearActivity(act)&&MYBShieldActivity(act).count==0,"Clear History");

 // 7b. each history clears only its own events (popups, redirects and websites never wipe one another)
 MYBShieldRecordActivity(act,@"popup",@"p.example",@"q.example",@"popup-strict");MYBShieldRecordActivity(act,@"appstore",@"org.mozilla.ios.Firefox",@"",@"appstore");
 MYBShieldRecordActivity(act,@"appredirect",@"com.apple.mobilesafari",@"com.google.ios.youtube",@"block-this-time");MYBShieldRecordActivity(act,@"website",@"com.apple.mobilesafari",@"w.example",@"custom-rule");
 CHECK(MYBShieldActivityOfTypes(act,@[@"appstore",@"appredirect"]).count==2&&MYBShieldActivityOfTypes(act,@[@"popup"]).count==1,"each screen lists only its own kinds");
 CHECK(MYBShieldClearActivityTypes(act,@[@"appstore",@"appredirect"])&&MYBShieldActivityOfTypes(act,@[@"appstore",@"appredirect"]).count==0&&MYBShieldActivityOfTypes(act,@[@"popup"]).count==1&&MYBShieldActivityOfTypes(act,@[@"website"]).count==1,"clearing redirect history keeps popup and website history");
 CHECK(MYBShieldClearActivityTypes(act,@[@"popup"])&&MYBShieldActivityOfTypes(act,@[@"popup"]).count==0&&MYBShieldActivityOfTypes(act,@[@"website"]).count==1,"clearing popup history keeps website history");
 MYBShieldClearActivity(act);
 { // clearing history never touches saved permissions, and a one-time block is an event, not a rule
  NSDictionary *g=MYBShieldAddGrant(perm,@"appstore",@"org.mozilla.ios.Firefox",nil,@"temp");CHECK(g!=nil,"fixture: a saved redirect permission");
  MYBShieldRecordActivity(act,@"appstore",@"org.mozilla.ios.Firefox",@"",@"block-this-time");MYBShieldClearActivityTypes(act,@[@"appstore",@"appredirect"]);
  CHECK(MYBShieldAllows(perm,@"appstore",@"org.mozilla.ios.Firefox",nil,NO)!=nil,"clearing history leaves the permission");
  CHECK(MYBShieldAddGrant(perm,@"appstore",@"org.mozilla.ios.Firefox",nil,@"block")==nil,"an app redirect can never be saved as an Always Block rule");
  CHECK(MYBShieldRevoke(perm,g[@"id"])&&MYBShieldAllows(perm,@"appstore",@"org.mozilla.ios.Firefox",nil,NO)==nil,"revoking removes that permission");
 }
 // 8. notice rate limit never grants
 NSMutableDictionary *last=[NSMutableDictionary dictionary];
 CHECK(MYBShieldShouldNotify(last,@"k",100,8)&&!MYBShieldShouldNotify(last,@"k",101,8)&&MYBShieldShouldNotify(last,@"k",109,8)&&MYBShieldShouldNotify(last,@"other",101,8),"presentation is rate limited per key");
 CHECK(MYBShieldAllows(perm,@"popup",@"never-allowed.example",nil,NO)==nil,"rate limiting grants nothing");

 // 9. wording
 CHECK([MYBShieldTitle(@"popup") isEqual:@"Popup blocked"]&&[MYBShieldTitle(@"website") isEqual:@"Website blocked"]&&[MYBShieldTitle(@"appstore") isEqual:@"App Store redirect blocked"]&&[MYBShieldTitle(@"appredirect") isEqual:@"App redirect blocked"],"distinct titles");
 CHECK(![[MYBShieldReasonText(@"popup-strict") lowercaseString] containsString:@"website blocked"],"popup wording never says website blocked");

 // Popup permission lifecycle: Always Block is a saved, revocable permission; nothing else is remembered.
 {NSString *pb=[root stringByAppendingPathComponent:@"block-perm.plist"];Clock(2000000,9000,@"boot-B");
  CHECK(MYBShieldDecide(pb,@"popup",@"ads.example",nil,NO)==nil,"no permission: the attempt asks");
  NSDictionary *blk=MYBShieldAddGrant(pb,@"popup",@"Ads.Example.",nil,@"block");CHECK(blk==nil,"a malformed host is not saved as a block");
  blk=MYBShieldAddGrant(pb,@"popup",@"ads.example",nil,@"block");CHECK(blk!=nil&&[blk[@"mode"] isEqual:@"block"]&&blk[@"expiry"]==nil&&blk[@"wallExpiry"]==nil,"Always Block is saved without any expiry");
  CHECK([[MYBShieldDecide(pb,@"popup",@"ads.example",nil,YES) objectForKey:@"verdict"] isEqual:@"block"],"a saved block refuses without asking");
  CHECK([[MYBShieldDecide(pb,@"popup",@"x.ads.example",nil,YES) objectForKey:@"verdict"] isEqual:@"block"],"a saved block covers subdomains");
  CHECK(MYBShieldDecide(pb,@"popup",@"notads.example",nil,YES)==nil,"a look-alike suffix is not blocked");
  CHECK(MYBShieldAllows(pb,@"popup",@"ads.example",nil,YES)==nil,"the allow-only view never reports a block as an allow");
  CHECK(MYBShieldAddGrant(pb,@"appstore",@"com.a.b",nil,@"block")==nil,"only popups have a standing block");
  Clock(2000000+86400*40,9000+86400*40,@"boot-C");
  CHECK([[MYBShieldDecide(pb,@"popup",@"ads.example",nil,NO) objectForKey:@"verdict"] isEqual:@"block"],"a saved block survives time and reboot");
  MYBShieldAddGrant(pb,@"popup",@"shop.ads.example",nil,@"always");
  CHECK([[MYBShieldDecide(pb,@"popup",@"shop.ads.example",nil,NO) objectForKey:@"verdict"] isEqual:@"allow"],"the more specific allow wins over a parent block");
  CHECK([[MYBShieldDecide(pb,@"popup",@"cdn.ads.example",nil,NO) objectForKey:@"verdict"] isEqual:@"block"],"siblings stay blocked");
  NSArray *out=MYBShieldExportPermanent(pb);NSArray *back=MYBShieldValidatedPermanent(out);
  CHECK(back.count==2&&[[[back filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"mode == 'block'"]] firstObject][@"source"] isEqual:@"ads.example"],"backups carry the block and keep it a block");
  CHECK(MYBShieldValidatedPermanent(@[@{@"kind":@"popup",@"source":@"a.example",@"mode":@"once"}])==nil,"an import cannot smuggle in a one-time grant");
  CHECK(MYBShieldValidatedPermanent(@[@{@"kind":@"appstore",@"source":@"com.a.b",@"mode":@"block"}])==nil,"an import cannot create a block for another scope");
  NSString *pb2=[root stringByAppendingPathComponent:@"block-perm2.plist"];CHECK(MYBShieldReplacePermanent(pb2,back)&&[[MYBShieldDecide(pb2,@"popup",@"q.ads.example",nil,NO) objectForKey:@"verdict"] isEqual:@"block"],"restore re-creates the block");
  NSDictionary *only=[NSDictionary dictionaryWithContentsOfFile:pb];NSString *bid=nil;for(NSDictionary *g in only[@"grants"])if([g[@"mode"] isEqual:@"block"])bid=g[@"id"];
  CHECK(bid&&MYBShieldRevoke(pb,bid)&&MYBShieldDecide(pb,@"popup",@"cdn.ads.example",nil,NO)==nil,"revoking the block makes the next attempt ask again");
  // Allow Once is exactly one attempt; the next asks.
  MYBShieldAddGrant(pb,@"popup",@"once2.example",nil,@"once");
  CHECK([[MYBShieldDecide(pb,@"popup",@"once2.example",nil,YES) objectForKey:@"mode"] isEqual:@"once"]&&MYBShieldDecide(pb,@"popup",@"once2.example",nil,YES)==nil,"Allow Once permits one attempt, then asks again");
  // 15 minutes expires, then asks.
  Clock(3000000,20000,@"boot-D");MYBShieldAddGrant(pb,@"popup",@"t15.example",nil,@"temp");
  Clock(3000000+899,20000+899,@"boot-D");CHECK([[MYBShieldDecide(pb,@"popup",@"t15.example",nil,NO) objectForKey:@"verdict"] isEqual:@"allow"],"15 minutes holds");
  Clock(3000000+901,20000+901,@"boot-D");CHECK(MYBShieldDecide(pb,@"popup",@"t15.example",nil,NO)==nil,"after 15 minutes the next attempt asks again");
  CHECK([MYBShieldDurationText(@"block") containsString:@"block"],"block has its own wording");
 }
 [NSFileManager.defaultManager removeItemAtPath:root error:NULL];[NSFileManager.defaultManager removeItemAtPath:root2 error:NULL];
 CHECK(![MYBShieldReasonText(@"prompt-unavailable") isEqual:MYBShieldReasonText(@"unknown-code")]&&![MYBShieldReasonText(@"prompt-suppressed") isEqual:MYBShieldReasonText(@"unknown-code")],"prompt-unavailable / prompt-suppressed have their own wording");
 CHECK([MYBShieldReasonText(@"prompt-unavailable") containsString:@"no option"]||[MYBShieldReasonText(@"prompt-unavailable") containsString:@"No prompt"],"unavailable wording says no option was offered");
 // ---- App Redirect permission save: the real writer (SpringBoard side) and the real consumer (transition check) --------------------
 {
  NSString *r3=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",r3.UTF8String,1);
  NSString *pp=MYBShieldPermissionsFile();Clock(2000000,9000,@"boot-R");
  NSString *app=@"com.example.source",*dst=@"com.example.target",*other=@"com.example.other";
  // Allow Once: authorises exactly the intended attempt (source AND destination), is consumed by the executing transition only.
  NSDictionary *g=MYBShieldAddGrant(pp,@"appredirect",app,dst,@"once");CHECK(g&&[g[@"mode"] isEqual:@"once"],"Allow Once is saved and acknowledged");
  CHECK(MYBShieldAllows(pp,@"appredirect",app,other,NO)==nil&&MYBShieldAllows(pp,@"appredirect",other,dst,NO)==nil&&MYBShieldAllows(pp,@"appstore",app,nil,NO)==nil&&MYBShieldAllows(pp,@"popup",@"example.com",nil,NO)==nil,"the approval is bound to source and destination and does not leak to other kinds");
  CHECK([MYBShieldAllows(pp,@"appredirect",app,dst,NO) isEqual:@"once"]&&[MYBShieldAllows(pp,@"appredirect",app,dst,NO) isEqual:@"once"],"the preliminary can-it-run check does not consume it");
  CHECK([MYBShieldAllows(pp,@"appredirect",app,dst,YES) isEqual:@"once"]&&MYBShieldAllows(pp,@"appredirect",app,dst,NO)==nil,"the executing transition consumes it; the next attempt asks again");
  // Allow for 15 minutes: expires.
  CHECK(MYBShieldAddGrant(pp,@"appredirect",app,dst,@"temp")!=nil&&[MYBShieldAllows(pp,@"appredirect",app,dst,YES) isEqual:@"temp"],"Allow for 15 Minutes is saved and allowed");
  Clock(2000000+MYB_SHIELD_TEMP_SECONDS+1,9000+MYB_SHIELD_TEMP_SECONDS+1,@"boot-R");CHECK(MYBShieldAllows(pp,@"appredirect",app,dst,NO)==nil,"a 15-minute permission expires");Clock(2000000,9000,@"boot-R");
  // Always Allow persists across a fresh read (a new process reads the same file) and revocation removes it.
  NSDictionary *al=MYBShieldAddGrant(pp,@"appredirect",app,dst,@"always");CHECK(al!=nil,"Always Allow is saved");
  CHECK([MYBShieldAllows(pp,@"appredirect",app,dst,YES) isEqual:@"always"]&&[MYBShieldAllows(pp,@"appredirect",app,dst,YES) isEqual:@"always"],"Always Allow is not consumed");
  CHECK([[NSDictionary dictionaryWithContentsOfFile:pp][@"grants"] count]==1,"duplicate saves of the same permission leave exactly one record");
  NSDictionary *al2=MYBShieldAddGrant(pp,@"appredirect",app,dst,@"always");CHECK(al2!=nil&&[[NSDictionary dictionaryWithContentsOfFile:pp][@"grants"] count]==1,"a repeated Allow never writes a second record");al=al2; // the repeat replaced the first record, so revocation must name the current one
  CHECK(MYBShieldRevoke(pp,al[@"id"])&&MYBShieldAllows(pp,@"appredirect",app,dst,NO)==nil,"revocation removes it");
  // Block This Time creates no rule at all; App Redirect has no standing block.
  NSData *before=[NSData dataWithContentsOfFile:pp];CHECK(MYBShieldAddGrant(pp,@"appredirect",app,dst,@"block")==nil&&[MYBShieldLastError() containsString:@"standing block"],"a standing block is refused for app redirects, with the reason recorded");
  CHECK([[NSData dataWithContentsOfFile:pp] isEqual:before],"a refused save leaves the file byte-for-byte as it was");
  // The failure that was reproduced on a device: a lock file the saving process cannot open for writing (created by root).
  NSString *lock=[pp stringByAppendingString:@".lock"];chmod(lock.fileSystemRepresentation,0444);
  NSDictionary *viaRO=MYBShieldAddGrant(pp,@"appredirect",@"com.example.ro",dst,@"always");
  CHECK(viaRO!=nil||geteuid()==0,"a lock file without write access no longer makes Allow fail");CHECK([MYBShieldAllows(pp,@"appredirect",@"com.example.ro",dst,NO) isEqual:@"always"]||geteuid()==0,"and the permission it saved is honoured");
  chmod(lock.fileSystemRepresentation,0600);
  // App Store and other-app permissions are separate scopes with separate keys.
  CHECK(MYBShieldAddGrant(pp,@"appstore",app,nil,@"always")!=nil&&[MYBShieldAllows(pp,@"appstore",app,nil,NO) isEqual:@"always"]&&MYBShieldAllows(pp,@"appredirect",app,dst,NO)==nil,"App Store permission is separate from an app-to-app permission");
  // Failed persistence keeps the previous permissions and reports the real reason.
  if(geteuid()!=0){
   NSString *dir=pp.stringByDeletingLastPathComponent;NSData *keep=[NSData dataWithContentsOfFile:pp];chmod(dir.fileSystemRepresentation,0555);
   NSDictionary *fail=MYBShieldAddGrant(pp,@"appredirect",@"com.example.new",dst,@"always");
   chmod(dir.fileSystemRepresentation,0755);
   CHECK(fail==nil&&[MYBShieldLastError() length]>0&&![MYBShieldSaveFailureReason() isEqual:@""],"failed persistence is reported (no fake success) with the real error");
   CHECK([[NSData dataWithContentsOfFile:pp] isEqual:keep]&&MYBShieldAllows(pp,@"appredirect",@"com.example.new",dst,NO)==nil,"failed persistence keeps every previous permission and grants nothing");
   CHECK(MYBShieldReasonText(MYBShieldSaveFailureReason()).length>20&&![MYBShieldReasonText(MYBShieldSaveFailureReason()) isEqual:MYBShieldReasonText(@"unknown-code")],"the activity list explains a failed save in plain words");
  }
  // Concurrent attempts: two simultaneous Allows for different destinations both land; none is lost.
  dispatch_group_t grp=dispatch_group_create();dispatch_queue_t q=dispatch_get_global_queue(QOS_CLASS_UTILITY,0);__block int okCount=0;NSLock *lk=[NSLock new];
  for(int i=0;i<8;i++)dispatch_group_async(grp,q,^{NSDictionary *r=MYBShieldAddGrant(pp,@"appredirect",@"com.example.conc",[NSString stringWithFormat:@"com.example.t%d",i],@"always");if(r){[lk lock];okCount++;[lk unlock];}});
  dispatch_group_wait(grp,DISPATCH_TIME_FOREVER);
  int live=0;for(int i=0;i<8;i++)if([MYBShieldAllows(pp,@"appredirect",@"com.example.conc",[NSString stringWithFormat:@"com.example.t%d",i],NO) isEqual:@"always"])live++;
  CHECK(okCount==8&&live==8,"eight concurrent Allows are all saved and honoured");
  // Website, popup and app-redirect permissions never answer for one another.
  CHECK(MYBShieldAddGrant(pp,@"popup",@"example.com",nil,@"always")!=nil&&MYBShieldAllows(pp,@"appredirect",@"example.com",dst,NO)==nil&&MYBShieldAllows(pp,@"appstore",@"example.com",nil,NO)==nil,"a popup permission does not allow an app redirect");
  [NSFileManager.defaultManager removeItemAtPath:r3 error:NULL];
 }

 // ---- Allow Once is ONE bound attempt, not a 120-second allowance ----------------------------------------------------------------
 {
  NSString *r4=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",r4.UTF8String,1);
  NSString *po=MYBShieldPermissionsFile();Clock(3000000,11000,@"boot-O");
  NSString *app=@"com.example.source",*dst=@"com.example.target";
  NSDictionary *g=MYBShieldAddGrantFor(po,@"appredirect",app,dst,@"once",@"HTTPS",@"attempt-1");
  CHECK(g&&[g[@"scheme"] isEqual:@"https"]&&[g[@"attempt"] isEqual:@"attempt-1"],"a one-time grant records its scheme (lower-case) and the pending attempt");
  g=MYBShieldAddGrantFor(po,@"appredirect",app,dst,@"once",@"myapp",@"attempt-2");CHECK(g!=nil,"saved");
  CHECK(MYBShieldAllowsScheme(po,@"appredirect",app,dst,@"https",YES)==nil&&MYBShieldAllowsScheme(po,@"appredirect",app,dst,nil,YES)==nil,"a different or unobservable scheme does not use it, and does not burn it");
  CHECK(MYBShieldAllowsScheme(po,@"appredirect",app,@"com.example.other",@"myapp",YES)==nil&&MYBShieldAllowsScheme(po,@"appredirect",@"com.example.other",dst,@"myapp",YES)==nil,"another destination or source does not use it");
  CHECK([MYBShieldAllowsScheme(po,@"appredirect",app,dst,@"MyApp",NO) isEqual:@"once"],"the matching attempt is allowed (peek)");
  CHECK([MYBShieldAllowsScheme(po,@"appredirect",app,dst,@"myapp",YES) isEqual:@"once"],"the matching executing attempt is allowed once");
  CHECK(MYBShieldAllowsScheme(po,@"appredirect",app,dst,@"myapp",YES)==nil&&MYBShieldAllowsScheme(po,@"appredirect",app,dst,@"myapp",NO)==nil,"a repeated redirect finds nothing");
  // expiry: valid for at most 120 s even when unused
  MYBShieldAddGrantFor(po,@"appredirect",app,dst,@"once",nil,@"attempt-3");Clock(3000000+MYB_SHIELD_ONCE_SECONDS+1,11000+MYB_SHIELD_ONCE_SECONDS+1,@"boot-O");
  CHECK(MYBShieldAllowsScheme(po,@"appredirect",app,dst,nil,YES)==nil,"an unused one-time grant expires after 120 seconds");Clock(3000000,11000,@"boot-O");
  // concurrency: many simultaneous redirects, exactly one is allowed
  MYBShieldAddGrantFor(po,@"appredirect",app,dst,@"once",@"myapp",@"attempt-4");
  __block int allowed=0;NSObject *mu=[NSObject new];
  dispatch_apply(32,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^(size_t i){
   NSString *m=MYBShieldAllowsScheme(po,@"appredirect",app,dst,@"myapp",YES);if(m)@synchronized(mu){allowed++;}});
  CHECK(allowed==1,"32 concurrent redirects: exactly one consumes the approval");
  // a one-time grant never replaces a standing permission, and a standing permission is not burned by one
  MYBShieldAddGrantFor(po,@"appredirect",app,dst,@"always",nil,nil);MYBShieldAddGrantFor(po,@"appredirect",app,dst,@"once",nil,@"attempt-5");
  CHECK([MYBShieldAllowsScheme(po,@"appredirect",app,dst,nil,YES) isEqual:@"always"]&&[MYBShieldAllowsScheme(po,@"appredirect",app,dst,nil,YES) isEqual:@"always"],"a one-time grant does not replace or burn a standing permission");
  // invalid schemes are refused rather than stored
  CHECK(!MYBShieldSchemeValid(@"")&&!MYBShieldSchemeValid(@"1abc")&&!MYBShieldSchemeValid(@"a b")&&!MYBShieldSchemeValid(@"https://x")&&MYBShieldSchemeValid(@"my-app.v2+x"),"scheme validation");
  // if the consumption cannot be saved, the attempt is refused (never allowed twice)
  if(geteuid()!=0){
   NSString *r5=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];setenv("MYB_FIXTURE_ROOT",r5.UTF8String,1);NSString *pf=MYBShieldPermissionsFile();
   MYBShieldAddGrantFor(pf,@"appredirect",app,dst,@"once",nil,@"attempt-6");
   NSString *dir=pf.stringByDeletingLastPathComponent;chmod(dir.UTF8String,0500);
   CHECK(MYBShieldAllowsScheme(pf,@"appredirect",app,dst,nil,YES)==nil,"consumption that cannot be saved refuses the attempt");
   chmod(dir.UTF8String,0700);CHECK(MYBShieldAllowsScheme(pf,@"appredirect",app,dst,nil,YES)!=nil,"and the approval is still single-use once storage works");
   [NSFileManager.defaultManager removeItemAtPath:r5 error:NULL];
  }
  [NSFileManager.defaultManager removeItemAtPath:r4 error:NULL];
 }
 if(failures){fprintf(stderr,"%d shield policy check(s) FAILED\n",failures);return 1;}
 printf("Shield policy checks passed: scopes, once/15-minute/always, clock and reboot safety, backup, Standard/Strict, activity.\n");
}return 0;}
