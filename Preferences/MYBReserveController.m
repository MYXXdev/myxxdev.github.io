#import "MYBMenuBase.h"
#import "MYBDesign.h"
#import "MYBTips.h"
#import <notify.h>
#import "../Companions/MYXXReserve/Shared/RSVShared.h"

// MYXX Reserve (low-battery reserve). The tweak itself lives in Companions/MYXXReserve; this is its Settings screen.
// It reads and writes the same preference domain the tweak reads (com.myxxdev.reserve) and talks to SpringBoard through Darwin notifications.
// It never touches CommCenter, carrier bundles, SIM or eSIM. Airplane Mode is off by default.
static NSString *const kRSVDomain=@RSV_DOMAIN;
static id RSVPref(NSString *key){CFPreferencesAppSynchronize((__bridge CFStringRef)kRSVDomain);return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)kRSVDomain));}
static BOOL RSVFlag(NSString *key,BOOL fallback){id v=RSVPref(key);return [v isKindOfClass:NSNumber.class]?[v boolValue]:fallback;}
static NSInteger RSVNumber(NSString *key,NSInteger fallback){id v=RSVPref(key);return [v isKindOfClass:NSNumber.class]?[v integerValue]:fallback;}
static void RSVSet(NSString *key,id value){CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,(__bridge CFStringRef)kRSVDomain);CFPreferencesAppSynchronize((__bridge CFStringRef)kRSVDomain);notify_post(RSV_N_PREFS);}
static uint64_t RSVState(const char *name){int t=0;uint64_t w=0;if(notify_register_check(name,&t)==NOTIFY_STATUS_OK){notify_get_state(t,&w);notify_cancel(t);}return w;}
static NSString *RSVStatusText(NSString *key){CFStringRef d=CFSTR(RSV_STATUS_DOMAIN);CFPreferencesAppSynchronize(d);id o=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,d));return [o isKindOfClass:NSString.class]?o:nil;}
static NSString *RSVWhen(uint32_t t){
 if(!t)return @"no time";NSInteger ago=(NSInteger)-[[NSDate dateWithTimeIntervalSince1970:t] timeIntervalSinceNow];ago=MAX(0,ago);
 return ago<60?[NSString stringWithFormat:@"%lds ago",(long)ago]:ago<3600?[NSString stringWithFormat:@"%ld min ago",(long)(ago/60)]:[NSString stringWithFormat:@"%ld h ago",(long)(ago/3600)];
}
static NSString *RSVHelperResult(uint8_t code){
 switch(code){case RSVExitNoRootDomain:return @"power system not found";case RSVExitNoPMConnect:return @"power connection refused";case RSVExitSleepError:return @"iOS rejected the sleep request";case RSVExitNoBackboardd:return @"could not restart the display system";case 0xfe:return @"respring did not happen";case 0xff:return @"helper never finished";default:return [NSString stringWithFormat:@"code %u",code];}
}
static NSString *RSVSpringBoardLine(void){
 uint64_t s=RSVState(RSV_N_SB_STATE);
 if(!s)return @"Not loaded. SpringBoard has not reported in. Respring once; if this stays, the Reserve tweak is not being loaded.";
 uint16_t b=RSVStatusBuild(s);uint8_t c=RSVStatusCode(s),d=RSVStatusDetail(s);NSString *when=RSVWhen(RSVStatusTime(s));
 if(b!=RSV_BUILD)return [NSString stringWithFormat:@"SpringBoard is still running an older build (%u). Respring to load build %d.",b,RSV_BUILD];
 switch(c){
  case RSVSBLoaded:return [NSString stringWithFormat:@"Loaded in SpringBoard, %@",when];
  case RSVSBRequestReceived:return [NSString stringWithFormat:@"Request received, %@",when];
  case RSVSBQuickTestRunning:return [NSString stringWithFormat:@"Quick test running, started %@",when];
  case RSVSBQuickTestPassed:return [NSString stringWithFormat:@"Quick test passed%@, %@",d==1?@" (ended with Volume Up x3)":(d==2?@" (SpringBoard power route)":@""),when];
  case RSVSBEntering:return [NSString stringWithFormat:@"Entering reserve%@, %@",d?@" (full test)":@"",when];
  case RSVSBSleepRequested:return [NSString stringWithFormat:@"In reserve, sleep requested%@, %@",d==1?@" by SpringBoard":@"",when];
  case RSVSBRecovered:return [NSString stringWithFormat:@"Recovered%@, %@",d==2?@" (after recovery respring)":(d==1?@" (full test)":@""),when];
  case RSVSBRestoredAfterRespring:return [NSString stringWithFormat:@"Settings restored after a respring during reserve, %@",when];
  case RSVSBFailHelperLaunch:return [NSString stringWithFormat:@"Sleep failed: the power helper could not start (error %u), %@",d,when];
  case RSVSBFailSleep:return [NSString stringWithFormat:@"Sleep failed: %@, %@",RSVHelperResult(d),when];
  case RSVSBFailOverlay:return [NSString stringWithFormat:@"The black screen could not be shown, %@",when];
  case RSVSBFailRecovery:return [NSString stringWithFormat:@"Recovery failed: %@ (settings were restored; respring manually), %@",RSVHelperResult(d),when];
  case RSVSBFailQuickTest:return [NSString stringWithFormat:@"Quick test failed: %@, %@",RSVHelperResult(d),when];
  case RSVSBBusy:return [NSString stringWithFormat:@"Request ignored (%@), %@",d==0xfe?@"Reserve is switched off":(d==0xfd?@"unplug the charger first":@"something is already running"),when];
  default:return [NSString stringWithFormat:@"Unknown status 0x%02x, %@",c,when];
 }
}
static NSString *RSVHelperLine(void){
 uint64_t s=RSVState(RSV_N_HELPER_STATE);if(!s)return @"Power helper: not run yet (run the quick test)";
 uint8_t step=RSVStatusCode(s),ctx=RSVStatusDetail(s);uint32_t val=RSVStatusTime(s);NSString *who=(ctx&1)?@"root":@"mobile";
 switch(step){
  case RSVHelperProbeOK:return [NSString stringWithFormat:@"Power helper: power system reachable (ran as %@)",who];
  case RSVHelperAboutToSleep:return [NSString stringWithFormat:@"Power helper: sent the sleep request (ran as %@)",who];
  case RSVHelperSleepOK:return [NSString stringWithFormat:@"Power helper: iOS accepted the sleep request (ran as %@)",who];
  case RSVHelperRespringSent:return @"Power helper: display system restarted";
  case RSVHelperNoRootDomain:return @"Power helper: power system not found";
  case RSVHelperNoPMConnect:return [NSString stringWithFormat:@"Power helper: power connection refused, code 0x%08x (ran as %@)",val,who];
  case RSVHelperSleepError:return [NSString stringWithFormat:@"Power helper: sleep rejected, IOReturn 0x%08x (ran as %@)",val,who];
  case RSVHelperNoBackboardd:return @"Power helper: backboardd not found";
  default:return [NSString stringWithFormat:@"Power helper: step 0x%02x",step];
 }
}
static NSString *RSVDisplayLine(void){
 uint64_t s=RSVState(RSV_N_DISP_STATE);if(!s)return @"Battery percentage hook: no signal yet";
 if(RSVStatusBuild(s)!=RSV_BUILD)return @"Battery percentage hook: older build running, respring";
 return RSVStatusCode(s)==1?@"Battery percentage hook: active in SpringBoard":@"Battery percentage hook: battery item not found on this iOS";
}
static NSString *RSVThermalLine(void){
 uint64_t s=RSVState(RSV_N_THERMAL_STATE);
 if(!s)return @"CPU slowdown: not loaded yet (it starts after the next reboot or userspace reboot)";
 switch(RSVStatusCode(s)){
  case RSVThermalLoaded:return @"CPU slowdown: loaded, waiting for the thermal system";
  case RSVThermalProductFound:return @"CPU slowdown: ready";
  case RSVThermalThrottled:return [NSString stringWithFormat:@"CPU slowdown: on since %@",RSVWhen(RSVStatusTime(s))];
  case RSVThermalUnthrottled:return [NSString stringWithFormat:@"CPU slowdown: off since %@",RSVWhen(RSVStatusTime(s))];
  case RSVThermalNoProduct:return @"CPU slowdown: thermal system object not found on this iOS";
  case RSVThermalNoSelector:return @"CPU slowdown: not supported on this iOS";
  default:return @"CPU slowdown: unknown";
 }
}
static NSString *RSVStatusBlock(void){
 NSMutableArray *l=[NSMutableArray array];
 [l addObject:[NSString stringWithFormat:@"Installed: MYXX Reserve %s (build %d)",RSV_VERSION,RSV_BUILD]];
 [l addObject:[@"SpringBoard: " stringByAppendingString:RSVSpringBoardLine()]];
 [l addObject:RSVDisplayLine()];[l addObject:RSVHelperLine()];
 if(RSVFlag(@"throttleCPU",NO))[l addObject:RSVThermalLine()];
 NSString *hooks=RSVStatusText(@"hooks");if(hooks.length)[l addObject:[@"Not available on this iOS: " stringByAppendingString:hooks]];
 NSString *last=RSVStatusText(@"lastEvent");if(last.length)[l addObject:[@"Last event: " stringByAppendingString:last]];
 return [l componentsJoinedByString:@"\n"];
}

@interface MYBReserveController:MYBMenuBase
@property(nonatomic,strong) NSTimer *poll;
@property(nonatomic,copy) NSString *shownStatus;
@end
@implementation MYBReserveController
- (NSString *)heroTitle{return @"MYXX Reserve";}
- (NSString *)heroDetail{return @"At a low battery level the screen goes black and the phone sleeps, so the jailbreak survives until you charge.";}
- (BOOL)flag:(NSString *)key{
 static NSDictionary *defaults;if(!defaults)defaults=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],@"enabled",[NSNumber numberWithBool:YES],@"autoEnter",[NSNumber numberWithBool:YES],@"blockWakes",[NSNumber numberWithBool:YES],@"lowPowerMode",[NSNumber numberWithBool:YES],@"silenceFocus",[NSNumber numberWithBool:YES],@"pauseMedia",[NSNumber numberWithBool:NO],@"radioIsolation",[NSNumber numberWithBool:NO],@"throttleCPU",[NSNumber numberWithBool:NO],@"spoofPercent",nil];
 return RSVFlag(key,[defaults[key] boolValue]);
}
- (void)rebuildMenu{
 self.title=@"MYXX Reserve";self.shownStatus=RSVStatusBlock();
 NSInteger threshold=RSVNumber(@"threshold",3),rearm=RSVNumber(@"rearmMinutes",10);
 self.menuSections=@[
  @{@"title":@"STATUS",@"rows":@[@{@"title":@"Check Connection to SpringBoard",@"detail":@"Confirms this exact build is loaded and answering",@"icon":@"dot.radiowaves.left.and.right",@"tone":@(MYBToneBlue),@"action":@"ping"}],@"footer":self.shownStatus},
  @{@"title":@"TESTS",@"rows":@[
   @{@"title":@"Run Quick Test (10 seconds)",@"detail":@"Black screen and lock, then checks the power helper. Nothing else changes",@"icon":@"bolt.badge.checkmark",@"tone":@(MYBToneGreen),@"action":@"quick"},
   @{@"title":@"Run Full Reserve Test",@"detail":@"Real reserve and sleep. Unplug first",@"icon":@"moon.zzz.fill",@"tone":@(MYBToneAmber),@"action":@"full"}],
   @"footer":@"Both tests work at any battery level. Wake with Volume Up 3 times, plug in power, or wait: a full test wakes by itself after 2 minutes."},
  @{@"title":@"RESERVE",@"rows":@[
   @{@"title":@"MYXX Reserve",@"detail":@"Switch the whole feature on or off",@"icon":@"battery.25",@"accent":@YES,@"tone":@(MYBToneViolet),@"switch":@"enabled"},
   @{@"title":@"Start Automatically at Low Battery",@"detail":@"Off means only the Control Center toggle and the tests start it",@"icon":@"bolt.badge.clock",@"switch":@"autoEnter"},
   @{@"title":@"Start at Battery Level",@"detail":@"When the phone is not charging",@"icon":@"percent",@"value":[NSString stringWithFormat:@"%ld%%",(long)threshold],@"action":@"threshold"}],
   @"footer":@"Plug in power or press Volume Up 3 times to wake the phone. Carrier, SIM, eSIM and calls are never touched."},
  @{@"title":@"BATTERY PERCENTAGE",@"rows":@[
   @{@"title":@"Show Adjusted Percentage",@"detail":@"Reads 1% at the reserve level",@"icon":@"percent",@"switch":@"spoofPercent"}],
   @"footer":@"Example: with a 3% reserve level, a real 50% shows as 48%. It changes the number in the battery icon and its percentage text on the Home Screen, Lock Screen, Control Center and inside apps. An app shows it the next time you open that app. Apps installed later are picked up when you open this screen. With this off, nothing is touched anywhere."},
  @{@"title":@"WHILE IN RESERVE",@"rows":@[
   @{@"title":@"Keep the Screen Dark",@"detail":@"Tap, raise and side button do not wake it",@"icon":@"moon.fill",@"switch":@"blockWakes"},
   @{@"title":@"Turn on Low Power Mode",@"icon":@"battery.50",@"switch":@"lowPowerMode"},
   @{@"title":@"Turn on Do Not Disturb",@"icon":@"bell.slash.fill",@"switch":@"silenceFocus"},
   @{@"title":@"Pause Music and Video",@"icon":@"pause.fill",@"switch":@"pauseMedia"},
   @{@"title":@"Turn on Airplane Mode",@"detail":@"Off by default",@"icon":@"airplane",@"switch":@"radioIsolation"},
   @{@"title":@"Slow Down CPU",@"detail":@"Experimental, needs a reboot to load",@"icon":@"cpu",@"switch":@"throttleCPU"}],
   @"footer":@"Only settings that Reserve itself turned on are turned back off when the phone wakes."},
  @{@"title":@"AFTER YOU WAKE IT BY HAND",@"rows":@[
   @{@"title":@"Wait Before Starting Again",@"detail":@"0 waits until you plug in",@"icon":@"timer",@"value":[NSString stringWithFormat:@"%ld min",(long)rearm],@"action":@"rearm"}],
   @"footer":@"If you wake the phone with the volume buttons while the battery is still low, Reserve waits this long before it can start again. Charging always re-arms it."}];
 [self.tableView reloadData];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuildMenu];if([self flag:@"spoofPercent"]&&[self flag:@"enabled"])[self syncAppFilter];} // also picks up apps installed since
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];__weak typeof(self) weak=self;
 self.poll=[NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *__unused t){if(![RSVStatusBlock() isEqualToString:weak.shownStatus]&&!weak.presentedViewController)[weak rebuildMenu];}];
}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self.poll invalidate];self.poll=nil;}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *row=self.menuSections[p.section][@"rows"][p.row];NSString *key=row[@"switch"];MYBPrismCell *cell=[self cardForEntry:row table:t];
 if(key.length){MYBPrismSwitch *toggle=[MYBPrismSwitch new];toggle.key=key;toggle.onTintColor=MYBAccent();toggle.on=[self flag:key];[toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];cell.mybAccessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;[cell refreshContent];}
 return cell;
}
- (void)syncAppFilter{[self silentHelper:@[@"adsfilter"] completion:^(int rc){if(rc)MYBMessage(self,@"Saved, Not Applied Inside Apps",[NSString stringWithFormat:@"Your choice is saved, but MYbloXX® could not update which apps show the adjusted percentage (error %d). It still applies on the Home Screen, Lock Screen and Control Center. Use Repair MYbloXX® and try again.",rc]);}];}
- (void)toggled:(MYBPrismSwitch *)toggle{RSVSet(toggle.key,[NSNumber numberWithBool:toggle.on]);if([toggle.key isEqual:@"spoofPercent"]||[toggle.key isEqual:@"enabled"])[self syncAppFilter];[self rebuildMenu];}
- (void)send:(uint8_t)kind title:(NSString *)title{
 uint32_t nonce=arc4random()|1u;int t=0;notify_register_check(RSV_N_REQUEST,&t);notify_set_state(t,RSVPackRequest(kind,nonce));notify_cancel(t);notify_post(RSV_N_REQUEST);
 NSString *want=[NSString stringWithFormat:@"%u",nonce];__block int tries=0;__weak typeof(self) weak=self;
 [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer){
  tries++;BOOL acked=[RSVStatusText(@"lastAck") isEqualToString:want];
  if(!acked){uint64_t s=RSVState(RSV_N_SB_STATE);acked=RSVStatusBuild(s)==RSV_BUILD&&RSVStatusCode(s)==RSVSBRequestReceived&&RSVStatusDetail(s)==(nonce&0xff);}
  if(acked||tries>=16){[timer invalidate];[weak rebuildMenu];
   if(!acked)MYBMessage(weak,title,@"SpringBoard did not answer within 4 seconds. Respring once and look at the status. If it still says Not loaded, the Reserve tweak is not loading.");}
 }];
}
- (void)choose:(NSString *)title values:(NSArray<NSNumber *> *)values suffix:(NSString *)suffix key:(NSString *)key{
 UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 for(NSNumber *v in values){[a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@%@",v,suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *__unused x){RSVSet(key,v);[self rebuildMenu];}]];}
 [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 a.popoverPresentationController.sourceView=self.view;a.popoverPresentationController.sourceRect=CGRectMake(self.view.bounds.size.width/2,self.view.bounds.size.height/2,1,1);
 [self presentViewController:a animated:YES completion:nil];
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];NSString *action=self.menuSections[p.section][@"rows"][p.row][@"action"];
 if([action isEqual:@"ping"])[self send:RSVRequestPing title:@"Check Connection"];
 else if([action isEqual:@"quick"])[self send:RSVRequestQuickTest title:@"Quick Test"];
 else if([action isEqual:@"full"]){
  MYBConfirmWithButton(self,@"Full Reserve Test",@"Unplug the charger first.\n\nThe screen goes black and the phone is put to sleep, exactly like low-battery reserve.\n\nTo wake it: press Volume Up 3 times, plug in power, or wait 2 minutes. The phone resprings when it wakes.",@"Start Test",^{[self send:RSVRequestFullTest title:@"Full Reserve Test"];});
 }
 else if([action isEqual:@"threshold"]){NSMutableArray *v=[NSMutableArray array];for(NSInteger i=1;i<=20;i++)[v addObject:[NSNumber numberWithInteger:i]];[self choose:@"Start at Battery Level" values:v suffix:@"%" key:@"threshold"];}
 else if([action isEqual:@"rearm"])[self choose:@"Wait Before Starting Again" values:@[@0,@5,@10,@15,@20,@30,@45,@60] suffix:@" min" key:@"rearmMinutes"];
}
- (void)dealloc{[self.poll invalidate];}
@end
