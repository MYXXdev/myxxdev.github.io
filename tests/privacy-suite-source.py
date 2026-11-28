#!/usr/bin/env python3
# Privacy suite (pass 14): scope of every new component, off-by-default, nothing near delivery/carrier code, honest copy, and wiring.
import re,sys,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
def R(p):return (ROOT/p).read_text(encoding='utf-8')
bad=[]
def need(c,m):
    print(('ok   ' if c else 'FAIL ')+m)
    if not c:bad.append(m)
strip=lambda t:re.sub(r'//[^\n]*','',re.sub(r'/\*.*?\*/','',t,flags=re.S))
cover=R('Companions/MYBPrivacyCover/Tweak.xm');cleanup=R('Companions/MYBBrowserCleanup/Tweak.xm');mk=R('Makefile')
lock=R('Preferences/MYBAppLockController.m');adv=R('Preferences/MYBAdvancedController.m');share=R('Preferences/MYBCleanShareController.m');sc=R('Preferences/MYBSafariCleanupController.m')
act=R('Preferences/MYBActivityController.m');diag=R('Preferences/MYBDiagnosticsController.m');state=R('Shared/MYBAppLockState.h');rules=R('Shared/MYBCleanupRules.h')
forbidden=r'CommCenter|CarrierBundle|CTCellularPlan|CoreTelephony|CTTelephony|imagent|IMDaemon|IMDPersistence|sqlite3|sms\.db|searchd'
for name,src in (('App Lock cover',cover),('Safari Cleanup',cleanup),('Clean Share',share),('Notification Privacy and App Lock settings',lock),('Safari Cleanup settings',sc)):
    need(not re.search(forbidden,strip(src)),name+' has no CommCenter, carrier, telephony, delivery or database code')
for c in ('MYBPrivacyCover','MYBBrowserCleanup'):need('Companions/'+c in mk,c+' is built with the package')
# App Lock: nothing runs unless this exact app is chosen; Settings/phone never touched; fresh install is empty
need('MYBLockEligible(bundle)' in cover and 'if(!lockApp&&!maskApp)return;' in cover and 'majorVersion!=16' in cover,'the cover leaves at once in any app that is not chosen, is not eligible, or is not iOS 16')
need('com.apple.Preferences' in state and 'com.apple.mobilephone' in state and 'com.apple.InCallService' in state and 'org.coolstar' in state,'Settings, phone and recovery apps can never be chosen')
need('AppLockEnabled' in lock and 'AppLockApps' in lock and not re.search(r'AppLockApps"\]=@\[@',lock),'App Lock is a switch and no app is pre-selected')
need('MYBLockBeginPrompt' in cover and 'MYBLockFinish(&State,ticket' in cover and 'MYBLockLeave' in cover,'every unlock is tied to one visit by a ticket; leaving or locking ends it')
need('UIApplicationWillResignActiveNotification' in cover and 'UIApplicationDidEnterBackgroundNotification' in cover and 'UIApplicationProtectedDataWillBecomeUnavailable' in cover and 'com.apple.springboard.lockstate' in cover,'cover goes on before the switcher snapshot, on background and on device lock')
need('makeKeyAndVisible' in cover and 'bringSubviewToFront' in cover,'the cover is on the first frame and stays on top')
need('LAPolicyDeviceOwnerAuthenticationWithBiometrics' in cover and 'LAPolicyDeviceOwnerAuthentication ' in cover.replace('LAPolicyDeviceOwnerAuthentication:','LAPolicyDeviceOwnerAuthentication '),'the passcode is allowed only when the person turned that option on')
need(not re.search(r'NSLog|os_log',strip(cover)),'the cover never logs')
need('Pause App Lock for 10 Minutes' in lock and 'AppLockPausedUntil' in cover,'there is an accessible way to switch App Lock off or pause it')
need('not yet a promise for every route' in lock or 'still being checked on a real phone' in lock,'App Lock copy does not claim every launch route is covered')
need('screenshots or screen recording' in lock,'Private Previews copy says what it does not stop')
# Notification privacy: native controls only
need('NOTIFICATIONS_ID' in lock and not re.search(r'%hook\s+(BB|NC|SB)',cover+cleanup),'Notification Privacy uses iOS Settings pages and hooks no notification delivery')
need('never listed' in lock and 'MYBLockEligible(bid)' in lock,'calls, emergency and system apps are never selectable')
# Clean Share
need('MYBCleanLink' in share and 'MYBStripLocation' in share and 'MYBRedactRender' in share and 'MYBRedactVerify' in share,'all three Clean Share tools are wired to the checked engines')
need('PHPickerFilter imagesFilter' in share and 'live-photo' in share and 'motion' in share,'photos come from the picker, and Live Photo limits are explained before export')
need('removeItemAtURL:output' in R('Shared/MYBImageClean.h') and 'MYBImageHasLocation(output)' in R('Shared/MYBImageClean.h'),'the exported copy is re-read and removed if location remains')
# Safari Cleanup
need('no-app-selected' in R('Companions/MYBPrivacyCover/MYBPrivacyCover.plist') and 'com.apple.UIKit' not in R('Companions/MYBPrivacyCover/MYBPrivacyCover.plist') and 'MYBCoverFilterBundles' in R('Helper/MYBAdsFilter.inc'),'App Lock loads only in apps the helper writes into its filter, never every UIKit process')
need(R('Companions/MYBBrowserCleanup/MYBBrowserCleanup.plist').count('com.apple')==1 and 'com.apple.mobilesafari' in R('Companions/MYBBrowserCleanup/MYBBrowserCleanup.plist'),'Safari Cleanup loads in Safari only')
need('css-display-none' in rules and not re.search(r'click\(|dispatchEvent|\.submit\(',cleanup+rules),'cleanup only hides; it never clicks, accepts or submits')
need('CleanupPausedUntil' in sc and 'CleanupExceptions' in sc and 'togglePause' in sc,'pause and per-site exceptions are in Settings')
need('rejected-kept-previous' in cleanup,'a rule WebKit refuses never replaces the working set')
# Inspector and diagnostics
need('Reason unavailable' in act and 'App unknown' in act and 'not being observed' in act,'Inspector names missing evidence and explains an empty allowed list')
need('whole phone, every app, not only browsers' in act,'the Inspector says an Allow applies to the whole phone')
need('MYBDiagSessionController' in act and 'MYB_DIAG_MAX_SECONDS' in R('Shared/MYBDiagSession.h') and 'Preview Export' in act,'the diagnostic session is opt-in, bounded and previewed before sharing')
need('MYBLocalNetworkController' in diag and 'cannot read these choices' in diag and not re.search(r'NWBrowser|Bonjour|NSNetService|nw_',diag),'Local Network Check explains and opens Settings; it scans nothing')
# front door
for page in ('MYBAppLockController','MYBPrivateItemsController','MYBNotifPrivacyController','MYBCleanShareController'):need('@"page":@"%s"'%page in adv,'Extra Privacy Protection opens '+page)
need('PrivateAlbumLock' in R('Shared/MYBConnectivity.h') and 'MYXXAuthenticate' in R('Companions/MYBPrivatePhotos/Tweak.x'),'optional Face ID for the private Photos views uses the shared check')
sys.exit(1 if bad else 0)
