# Source-level guarantees for the Shield upgrade (not a substitute for device verification).
import re,sys
from pathlib import Path
def read(p):return Path(p).read_text()
bad=[]
def need(c,m):
    if not c:bad.append(m)
sr=read('BlockedServer/ShieldRoutes.h');main=read('BlockedServer/main.m');tweak=read('Companions/MYBShieldBrowser/Tweak.xm');sb=read('Companions/MYBShieldRedirects/Tweak.xm')
# protected routes: POST, no Origin, bridge header and secret are all required before any state change
need('bridgeAuthenticated' in sr and 'Sec-Fetch-Site' in sr and 'Origin' in sr and 'X-MYbloXX-Bridge' in sr,'shield routes check bridge header and cross-site headers')
need(len(re.findall(r'bridgeAuthenticated\(',sr))>=2,'both shield routes authenticate')
need('kind' in sr and 'popup' in sr and 'appstore' not in sr.split('shieldAction')[1] if 'shieldAction' in sr else False,'web bridge can only touch popup grants')
# App grants are created only from SpringBoard's own UI
need('MYBShieldAddGrant' in sb and 'MYBShieldAddGrant' not in main,'app grants are not creatable from the web server')
# one apply path: no new PAC transport or restart outside the helper
for f in ('BlockedServer/WebsiteActions.h','Companions/MYBShieldBrowser/Tweak.xm','Companions/MYBShieldRedirects/Tweak.xm'):
    need('configd' not in read(f) and 'scutil' not in read(f),f+' does not apply network config itself')
need('runHelperArgs' in read('BlockedServer/WebsiteActions.h'),'website allow goes through the privileged helper')
# popup interception covers both public and private createWebView, and never replaces window.open in page scripts
proxies=read('Shared/MYBDelegateProxies.h')
need('createWebViewWithConfiguration' in proxies and 'forNavigationAction' in proxies and 'gMYBPopupGate=popupAllowed' in tweak,'UIDelegate createWebView proxied and gated by the popup decision')
need('(void)_webView:(WKWebView *)view createWebViewWithConfiguration' in proxies,'private async createWebView form handled')
need('window.open' not in tweak.replace('window.open() from','') or 'evaluateJavaScript' not in tweak,'no page-script window.open replacement')
need('setJavaScriptEnabled' not in tweak and 'javaScriptEnabled' not in tweak,'JavaScript is not disabled')
# the source page is never replaced for a blocked popup
need('showBanner' in tweak and 'showPopupOptions' in tweak,'popup uses non-modal notice + options')
# SpringBoard prompt must not act on a locked device
need('isUILocked' in sb,'locked device is left alone')
need('declineWithReason' in sb and 'presentPrompt' in sb,'decline plus visible prompt')
# nothing timed is exported
setup=read('Helper/MYBSetup.inc');need('MYBShieldExportPermanent' in setup and 'wallExpiry' not in setup,'backup carries only standing permissions')
# obsolete code gone
need('MYBRedirectBlocked' not in read('Shared/MYBRedirectPolicy.h'),'old silent-decline helper removed')
need('8787' not in read('BlockedServer/BlockAttribution.h'),'attribution no longer fetches the PAC over loopback')

# ---- review fixes (RC3) ----
need('OBJC_ASSOCIATION_ASSIGN' not in tweak,'no unsafe (assign) association anywhere in the Safari guard')
need('MYBBannerSlot' in tweak and 'clearIfGeneration' in tweak,'banner is owned by a slot and dismissals are generation-bound')
need('allowKey' not in tweak and 'now-[mark[' not in tweak and '<4)' not in tweak,'no time-based popup decision cache')
need('consumeURL' in tweak and 'rememberAllowedURL' in tweak and 'policyGeneration' in tweak,'single-use operation token tied to the policy generation')
need('MYBRedirectPlanFor' in sb and 'makePromptWindow' in sb,'prompt availability is planned before the transition is declined')
need(sb.index('MYBRedirectPlanFor(')<sb.rindex('declineWithReason'),'plan is computed before decline')
need(sb.count('deviceUnlocked()')>=4,'lock state is rechecked at presentation and action time')
page=read('BlockedServer/BlockedPage.html');need('Allow once' not in page,'website page never labels a 2-minute domain exception "once"')
inl=read('Shared/MYBInlinePAC.h');need('MYBIPFileSame' in inl[inl.index('static inline void MYBIPSweep'):inl.index('// ---- the transaction')],'sweep requires the complete recorded identity (inode, birth, content hash)')
need('c!=MYBIPFileSame' in inl[inl.index('static inline BOOL MYBIPRemoveTarget'):inl.index('static inline BOOL MYBIPRemoveTarget')+900],'RemoveTarget refuses everything except a proven-identical file (identical-content copies included)')
need('MYBIPLedgerRecord' in inl and 'not recorded by MYbloXX' in inl,'runtime sweep only deletes recorded files')
rs=read('Shared/MYBRuntimeStatus.h');need('128 KiB' not in rs and 'device-tested' not in rs,'no unsupported size/device claims in status header')
need('device-tested design' not in inl,'no unsupported device-tested claim in the inline PAC header')
need('MYBRuntimeVerify' in read('Helper/MYXXdev.m') and 'CFNetworkCopySystemProxySettings' in read('Helper/MYXXdev.m'),'helper verifies the effective system settings')
need('MYBRecoveryTake' in read('Helper/MYBAppControl.inc') and 'removeItemAtPath:recoveryPath' not in read('Helper/MYBAppControl.inc'),'recovery counter is not deleted on success')
sg=read('Companions/MYBShieldBrowser/Tweak.xm')
need('UIAlertController' not in sb and 'UIAlertController' not in sg,'Shield prompts are the branded sheet, not UIAlertController')
need('MYBShieldSheet' in sb and 'MYBShieldSheet' in sg and 'ShieldSheet.h' in sb and 'ShieldSheet.h' in sg,'both prompt surfaces use the shared sheet')
need('dismissOnBackdrop=NO' in sb,'a redirect prompt is never dismissed by a stray tap')
need('promptWindow!=window' in sb and 'closePrompt' in sb and 'prompt-unavailable' in sb,'redirect prompt keeps its slot discipline and unavailable reporting')
pp=sg[sg.index('static BOOL presentPopupSheet'):sg.index('static void showPopupOptions(WKWebView *view,NSString *source,NSString *dest,NSString *reason,MYBPendingPopup *pending,id attempt){')]
need('presentedViewController' in pp[:700] and 'UIApplicationStateActive' in pp[:700],'popup sheet is refused while something is presented or the app is not active')
nb=sg[sg.index('static void noticeBlockedPopup'):sg.index('// ---- popup policy')]
need('presentPopupSheet(' in nb and nb.index('presentPopupSheet(')<nb.index('showBanner('),'a blocked popup opens the sheet directly; the banner is only the fallback')
need('promptCooldown' not in sg and 'MYBShieldShouldNotify' not in sg and 'noticeLast' not in sg,'no time-based suppression of the permission sheet (cooldown / notify rate limit removed)')
need('MYBPromptGate' in sg and sg.count('[gate() finish]')>=3,'one permission question at a time; every outcome, dismissal and presentation failure clears it')
need('Block This Time' in sg and 'Always Block' in sg and 'Always Allow' in sg and 'Allow Once' in sg and 'Allow for 15 Minutes' in sg and 'Keep blocked' not in sg,'the five explicit popup choices')
need('@"block"' in sg and 'noticeSavedBlock' in sg and 'ShowBlocked' not in sg[sg.index('static void noticeSavedBlock'):sg.index('static void noticeBlockedPopup')],'Always Block is saved and its notice is always shown (there is no notices switch)')
need('MYBShieldDecide' in read('BlockedServer/ShieldRoutes.h') and 'popup-saved-block' in read('BlockedServer/ShieldRoutes.h'),'the bridge reports saved blocks and records them')
need('Always blocked' in read('Preferences/MYBPopupControlController.m') and 'nosign' in read('Preferences/MYBPopupControlController.m'),'a saved block is visible and revocable in Always Blocked Popup Sites')
need('Keep blocked' not in sb,'the redirect prompt uses the same Block This Time wording')
need('Popup permission saved' not in sg and 'MYBPopupReplayCheck' in sg and 'gReplaying' in sg,'no saved-confirmation step; replay goes through the shared validity check and cannot prompt again')
need('Tap the original link again' in sg,'script-created windows get the inline fallback')
need(sb.count('deviceUnlocked()')>=4,'lock state still re-checked (redirect)')
shs=read('Shared/MYBShieldSheet.h');need('_fired' in shs and 'accessibilityViewIsModal' in shs and 'UIAccessibilityIsReduceTransparencyEnabled' in shs and 'UIAccessibilityIsReduceMotionEnabled' in shs,'sheet fires once, is modal, honours Reduce Transparency and Reduce Motion')
need('MYBShieldAllows' in sb and 'MYBShieldAddGrant' in sb and 'MYBShieldAddGrant' not in shs,'the sheet never grants; the caller does')
sh=read('Shared/MYBShield.h')
need('open(lock.fileSystemRepresentation,O_RDONLY)' in sh and 'MYBShieldHandOver' in sh and 'MYBShieldRepairOwnership' in sh,'the lock falls back to read-only and root-created Shield files are handed to mobile')
need('could not be read back' in sh and 'MYBShieldSaveFailureReason' in sh and 'MYBShieldLastError' in sh,'a save is confirmed by reading it back and a failure records its real reason')
need('attempted' in sb and 'MYBShieldSaveFailureReason()' in sb,'a repeated tap never writes twice and a failed save is recorded')
need('MYBShieldRepairOwnership' in read('Helper/MYBStartup.inc') and 'MYBShieldRepairOwnership' in read('Helper/MYXXdev.m'),'the helper repairs Shield file ownership at startup and on Repair')
sh2=read('Shared/MYBShield.h')
need('0666' not in sh2 and 'O_CREAT|O_RDWR,0600' in sh2,'the Shield lock is not world-writable: only mobile and root can take it or change a permission')
need('MYBShieldAllowsScheme' in read('Companions/MYBShieldRedirects/Tweak.xm') and 'MYBShieldAddGrantFor' in read('Companions/MYBShieldRedirects/Tweak.xm') and 'attempt' in read('Companions/MYBShieldRedirects/Tweak.xm'),'Allow Once is created for one pending attempt and consumed with its scheme')
need('if(!MYBShieldWriteGrants(path,grants))result=nil;' in sh2,'a one-time approval whose consumption cannot be saved is refused')
tw=open('Companions/MYBShieldRedirects/Tweak.xm').read()
need('MYBPendingBegin(' in tw and 'MYBPendingIsPending(' in tw and 'MYBPendingFinish(' in tw and 'MYBPendingCancel(' in tw,'the redirect prompt registers, checks, finishes and cancels its pending attempt')
need('Permission saved · tap the link again' in tw and 'MYBPendingFinish(MYBPendingStore(),attempt,grant!=nil,NSDate.timeIntervalSinceReferenceDate,resume)' in tw and 'dispatch_block_t resume=nil;if(held)resume=held;else if(resumeURL)resume=' in tw,'after a saved permission the allowed link is opened again (run once, only when the URL is known); without a URL the prompt still says Allowed. Try again.')
need('reopenAllowedURL' in tw and tw.index('reopenAllowedURL(resumeURL')>tw.index('MYBShieldAddGrantFor') and 'writeToFile' not in tw[tw.index('static void reopenAllowedURL'):tw.index('static void presentPrompt')],'the re-open only follows a saved grant and the URL is never written to disk')

need('reopenAllowance' not in tw and 'reopenAllowed(' not in tw and 'age>3' not in tw and 'allowanceKey' not in tw,'no destination-wide or time-window bypass: only a saved permission lets a later request through')
need('to?:(id)NSNull.null' in tw and 'allowed-reopen-failed' in tw,'the link to re-open is searched on both scenes and, when missing, the action kinds iOS provided are logged')

# Entry hold-back for the App Store (device capture: the open reaches _handleOpenApplicationRequest before any transition, and it carries a user activity, not a link)
ent=tw[tw.index('static BOOL entryWantsHold'):tw.index('%hook SBMainWorkspace\n- (BOOL)_canExecuteTransitionRequest')]
need('v56@0:8@16@24@32@40@?48' in tw and tw.index('v56@0:8@16@24@32@40@?48')>tw.index('%group MYBEntry') and '%init(MYBEntry)' in tw,'the entry hook is installed only when the exact method encoding matches')
need(ent.count('%orig(bundle,options,activation,origin,heldResult)')==1 and 'released=YES' in ent and 'id heldResult=[result copy]' in ent,'the held call is passed on unchanged, once, with a heap copy of the result block')
need(re.search(r'\bresult\s*\(',ent) is None and 'invoke' not in ent.lower() and '((void(^)' not in ent,'the result block is never called or inspected by Shield')
need('MYBRedirectDecide(redirectSettings,source,trust,dest,YES' in tw and 'MYBRedirectNone' in ent and 'promptWindow||' in ent and 'deviceUnlocked()' in ent and 'entrySource(origin,options,&trust)' in tw,'an open from a protected source (the App Store, or another app when Other App Redirects is on) is held, only when a prompt can be shown')
need('_accessibilityFrontMostApplication' in tw and 'a direct launch is never touched' in tw,'a link opened through a system daemon is attributed to the app in front, and a SpringBoard launch is never touched')
need(tw.count('if(held)held();')>=6 and 'dispatch_time(DISPATCH_TIME_NOW,(int64_t)(30*NSEC_PER_SEC))' in tw,'a held request is released on every path and by a time limit')
need('@"%@|%@|%@"' in tw and tw[tw.index('%group MYBEntry'):].index('MYBShieldShouldNotify(promptLast')<tw[tw.index('%group MYBEntry'):].index('%orig(bundle,options,activation,origin,heldResult)'),'a refused held request starts the prompt gap before it is passed on, so the follow-up request raises no second prompt')
need('Allowed. %@ is opening' not in open('Shared/MYBShieldPending.h').read(),'the success text no longer claims the app is already opening')
need('redirectScheme(' not in tw and 'scheme=MYBShieldNormalScheme([(NSURL *)u scheme])' in tw,'the permission scheme and the replay link come from the same action')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Shield wiring checks passed.')
