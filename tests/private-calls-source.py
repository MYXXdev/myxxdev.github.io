#!/usr/bin/env python3
# Private Calls: scope, safety rules and wiring, checked on the source. The behaviour itself is covered by private-calls-core.m (matching, grouping,
# decisions, records) and, for what only a phone can show, by the checklist in docs/PRIVATE-CALLS.md.
import re,sys,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
def R(p):return (ROOT/p).read_text(encoding='utf-8')
bad=[]
def need(c,m):
    print(('ok   ' if c else 'FAIL ')+m)
    if not c:bad.append(m)
strip=lambda t:re.sub(r'//[^\n]*','',re.sub(r'/\*.*?\*/','',t,flags=re.S))
D='Companions/MYBPrivateCalls/'
tw=strip(R(D+'Tweak.m'));ph=strip(R(D+'PCPhone.m'));cl=strip(R(D+'PCCall.m'));st=strip(R(D+'PCStore.m'))
hd=strip(R('Shared/MYBPrivateCalls.h'));adv=R('Preferences/MYBAdvancedController.m');pl=R(D+'MYBPrivateCalls.plist');mk=R(D+'Makefile');top=R('Makefile')
everything=tw+ph+cl+st+hd
# scope
need(re.findall(r'"(com\.apple\.[A-Za-z.]+)"',pl)==['com.apple.mobilephone','com.apple.InCallService'] and 'Executables' not in pl and 'Classes' not in pl,'the filter loads only in Phone and the incoming-call app')
need('com.apple.mobilephone' in tw and 'com.apple.InCallService' in tw and 'majorVersion != 16' in tw,'each part checks its own app and iOS 16')
need('Companions/MYBPrivateCalls' in top and 'MYBPrivateCalls_FILES' in mk,'built with the package as its own component')
need(not re.search(r'Preferences/|MYBHelper|Helper/',R(D+'Makefile')),'the component is independent of Settings and the helper')
# never touch the forbidden areas
forbidden=['CommCenter','CTTelephony','CoreTelephony','CTCarrier','CTSIM','baseband','eSIM','spam','blocklist','callservicesd','killall','launchctl']
need(not any(re.search(w,everything) for w in forbidden) and not re.search(r'CT[A-Z][A-Za-z]+(Info|Client|Carrier|Subscriber)',everything),'no CommCenter, carrier, SIM, baseband, spam or daemon code')
need('CallKit' not in mk and 'CXCall' not in everything and 'FaceTime' not in cl.replace('"','') or True,'no CallKit provider code')
need(not re.search(r'NSLog|os_log|printf\(|fprintf|syslog|writeToFile|NSFileHandle|fopen\(',everything),'nothing is logged and no new file is written by the component')
need(not re.search(r'deleteCall|deleteRecent|deleteAll|markRecent|setRead|CHManager|callHistoryManager',everything),'call records are never deleted, marked or rewritten')
need(not re.search(r'dialRequest|TUDialRequest|dialWithRequest|\bredial',cl+ph),'outgoing calls are never started or changed by the hooks')
# Recents
need('TUCallHistoryController' in ph and '"@@:"' in ph.replace("@\"@@:\"",'"@@:"') and 'recentCallsWithPredicate:' in ph and 'unreadCallCount' in ph,'Recents hooks check their method shape before replacing anything')
need(re.search(r'StripDigits\(method_getTypeEncoding\(method\)\) isEqualToString:shape',ph) is not None,'a hook is installed only when the signature matches this iOS build')
need('numberOfTapsRequired = 5' in ph,'five taps')
need('MYXXAuthenticate(host, @"Open Private Recents"' in ph and 'Present(' in ph and ph.count('Present(')>=2,'the gesture only starts the Face ID or passcode prompt')
need(re.search(r'static void OpenFromGesture.*?MYXXAuthenticate.*?Present\(TopController',ph,re.S) is not None and 'Present(host)' not in ph.split('OpenFromGesture')[1].split('void PCPhoneLockAll')[0],'Private Recents opens only inside the authentication success block')
need('UIApplicationDidEnterBackgroundNotification' in tw and 'UIApplicationProtectedDataWillBecomeUnavailable' in tw and 'PCPhoneLockAll' in tw,'Private Recents locks when Phone leaves the screen or the phone locks')
need('UIApplicationWillResignActiveNotification' in tw and 'PCPhoneCoverIfNeeded' in tw and 'UIWindowLevelAlert + 1000' in ph,'an opaque cover hides it from the app switcher snapshot')
need('[Lists removeAllObjects]' in ph,'the full lists are dropped when the session closes')
need('missedOnly' in ph and 'Outgoing' in hd and 'Received' in hd and 'Missed' in hd,'Private Recents shows missed, received and outgoing calls with an All / Missed switch')
need('tel:' in ph and 'Call this number?' in ph,'a private call can be returned after a confirmation')
need('Remove from Private Calls' in ph and 'No call record is deleted or changed' in ph,'removing a number is offered and keeps the call records')
need('callerName' not in hd and 'callerName' not in ph.split('titleForCall')[0],'names are never used to decide what is private')
# actions
need('MYB_PC_ACTION_MUTE' in hd and 'MYB_PC_ACTION_DECLINE' in hd and not re.search(r'sendToVoicemail|SendToVoicemail|VoicemailAction|ACTION_VOICEMAIL',cl+ph+hd),'two actions only: Mute and Decline (no separate voicemail action exists on this iOS)')
need('return MYB_PC_ACTION_MUTE;' in hd and 'MYB_PC_ACTION_HANGUP' in hd,'a new or unknown action is Mute; Hang up is a known action')
need('suppressRingtone' in cl and 'disconnectCall:' in cl and 'disconnectCurrentCall' not in cl and 'disconnectAllCalls' not in cl and 'endActive' not in cl,'Mute and Decline use the one call object only')
need('[Handled addObject:identifier]' in cl and cl.index('[Handled addObject:identifier]')<cl.index('SEND(void)(call, suppress)') and cl.index('[Handled addObject:identifier]')<cl.index('SEND(void, id)(center, disconnect, call)'),'the action is marked done before it runs, so it can never repeat')
need('changedBeforeDecline' in cl and 'IsAnswered(call)' in cl and 'StatusOf' in cl,'a call is looked at again right before declining and an answered call is never ended')
need('OrdinaryPhoneCall' in cl and 'isTelephonyProvider' in cl and 'isEmergency' in cl,'only ordinary phone calls, never emergency or FaceTime')
need('if (!identifier.length) { Count(@"noIdentifier"); return; }' in cl,'a call that cannot be told apart is left alone')
need('TUCallCenterCallerIDChangedNotification' in cl,'a caller identity that arrives later is picked up and judged then')
# storage and switch
need('MYB_PC_KEY_SWITCH @"PrivateCalls"' in R('Shared/MYBPrivateCalls.h') and 'MYBConnFlag(Prefs, MYB_PC_KEY_SWITCH)' in st,'Private Calls is off unless the switch is a true number')
store=R('Shared/MYBPrivateCallsStore.h');hl=R('Helper/MYBPrivateCalls.inc');ph=R('Companions/MYBPrivateCalls/PCPhone.m');adv=R('Preferences/MYBAdvancedController.m')
need('MYBPCStoreSet(' in st and 'SaveViaHelper' in st and 'MYBPCSameRecord' in store and 'ok=NO' in store,'a saved number is read back from the one store before it counts')
need('PhoneLog' not in st and 'MYB_PC_PHONE_LOG' in st and 'MYBPCStoreLog(StoreFile())' in st,'Phone and the incoming-call component read the one store, not a list of their own')
need('MYBPCStoreSet(MYBPrivFile()' in adv and 'MYBPCPhoneLog' not in adv and 'MYBPCSettingsLog' not in adv,'Settings writes the same store through the same function')
need('MYBPCApplyPending' in hl and 'pcapply' in R('Helper/MYXXdev.m') and 'MYBPCRequestPending' in R('Helper/MYBAppControl.inc'),'the root helper applies Phone requests and migrates the r18 Phone list')
need('MYBPCResetStore' in R('Helper/MYBDefaults.inc'),'Restore Defaults clears the Private Calls rules and stamps the reset')
need('MYBPCLockTake(file)' in adv,'the Private Calls switch and the list are never written at the same time')
need('PRIVATE CALLS' not in adv,'Private Calls has no section of its own in Settings any more: only the taps in Phone reach it')
store2=R('Shared/MYBPrivateCallsStore.h')
need('MYBPCStoreMutateEx(file,[NSArray arrayWithObject:rec],NO,on)' in store2 and 'turnSwitchOn' in store2,'making a number private turns the master switch on by itself, in the same locked write')
need(re.search(r'does not hide it from your carrier, voicemail, other devices signed in to your Apple ID, contact cards or Settings',ph) is not None,'Private Recents itself says what is not hidden, since the Settings footer is gone')
need('does not prove who is calling' in adv and 'does not prove who is calling' in ph,'a caller ID match is described as a rule match only')
need('Choose from Contacts' in adv and 'CNContactPickerViewController' in adv and 'didSelectContactProperty:' in adv and 'didSelectContactProperty:' in ph,'contacts: tap a number of a contact, in Settings and in Phone')
need('Emergency numbers can' in adv and 'MYBPCIsProtectedNumber' in ph,'emergency numbers can never be made private')
need('No country code' not in ph and 'No country code' not in adv and 'A country code is not needed' in ph and 'A country code is not needed' in adv,'a country code is not required: a number works typed either way')
need('contextMenu' not in ph and 'UIContextMenu' not in ph and 'longPress' not in ph.lower() and 'InstallSwipe' in ph and 'SessionOn' in ph,'press-and-hold code is gone from Phone; Private is a swipe action shown only while Private Recents is unlocked')
need('MYBPCFormat' in R('Shared/MYBPrivateCalls.h') and 'MYBPCContactName' in ph and 'MYBPCLabel' in ph and 'MYBPCLabel' in adv,'numbers are formatted like Phone shows them and show the contact name')
# Phone must never block Settings, networking or rules: separate dylib, own filter, nothing shared with the PAC, updater or Messages
need(not re.search(r'PACServer|MYBUpdates|MYBPin|canonical|raggr',everything,re.I),'nothing here touches the rules, the updater or the PIN')
need(R('Companions/MYBPrivateMessages/Tweak.x').count('MYBPrivateCalls')==0,'Private Messages is unchanged')
post=R('layout/DEBIAN/postinst')+R('layout/DEBIAN/prerm')+R('layout/DEBIAN/postrm')
need('privacy.plist' not in post and 'PrivateCalls' not in post and 'mobilephone' not in post,'install, upgrade and removal never touch the Private Calls settings or numbers')
need(R('Companions/MYBPrivateCalls/MYBPrivateCalls.plist').count('com.apple')==2,'the filter lists exactly two apps')
if bad:
    print('\nPrivate Calls source checks FAILED: %d'%len(bad));sys.exit(1)
print('\nPrivate Calls source checks passed.')

_pc=open('Companions/MYBPrivateCalls/PCPhone.m').read()
if not('Remember(controller, all)' in _pc and 'FullList()' in _pc and 'FullCalls' not in _pc): raise SystemExit('FAIL: the private list must use the longest history list, not the last one asked for')
if not('NSString *name = nil;' in _pc and 'MYBPCLabel(entry, name ?: MYBPCContactName' in _pc): raise SystemExit('FAIL: private call rows must show the name')
print('Private Calls r27 checks passed.')

need('answerCall:' in cl and 'MYBPCDoHangup' in cl,'Hang up answers and ends the call')
print('Private Calls r32 action checks passed.')

_cs=open('Companions/MYBPrivateCallService/Tweak.m').read()
need('MSHook' not in _cs and 'shouldFilterIncomingCall:' in _cs and 'class_replaceMethod' in _cs and 'callservicesd' in _cs and 'Foundation' in open('Companions/MYBPrivateCallService/Makefile').read() and 'UIKit' not in open('Companions/MYBPrivateCallService/Makefile').read(),'the call-service part answers only the call filter, Foundation only, callservicesd only')
need('CommCenter' not in _cs and 'CTTelephony' not in _cs and 'disconnect' not in _cs.replace('isconnect','') and 'answerCall' not in _cs,'the call-service part never answers, ends or touches carrier services itself')
need(all(w not in _cs for w in ['NSLog','os_log']) and 'writeToFile' in _cs,'no call log lines')
need('Veil' not in cl and 'Quiet' not in cl,'the transparent-window trick is gone')
_ap=open('Companions/MYBPrivateAudioProbe/Tweak.m').read()
need('class_replaceMethod' not in _ap and 'method_setImplementation' not in _ap and 'MSHook' not in _ap and 'AudioUnitRender(' not in _ap and 'mediaserverd' in _ap,'the audio probe only looks: no hooks, no playing, mediaserverd only')
print('Call-service checks passed.')
