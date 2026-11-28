#!/usr/bin/env python3
# Call Firewall: scope, safety rules and Settings/daemon wiring, checked on the source. The decision logic itself is covered by firewall-core.m
# (precedence, range matching, store round-trip, wire-format round-trip). This file only checks that the pieces are actually plugged together.
import re,sys,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
def R(p):return (ROOT/p).read_text(encoding='utf-8')
bad=[];total=0
def need(c,m):
    global total;total+=1
    print(('ok   ' if c else 'FAIL ')+m)
    if not c:bad.append(m)
strip=lambda t:re.sub(r'//[^\n]*','',re.sub(r'/\*.*?\*/','',t,flags=re.S))

rules_raw=R('Shared/MYBFirewallRules.h')
rules=strip(rules_raw)
store=strip(R('Shared/MYBFirewallStore.h'))
wire=strip(R('Shared/MYBFirewallWire.h'))
fwl=strip(R('Shared/MYBFirewallList.h'))
conn=strip(R('Shared/MYBConnectivity.h'))
ctrl=strip(R('Preferences/MYBFirewallController.m'))
modern=strip(R('Preferences/MYBModernController.m'))
menubase=strip(R('Preferences/MYBMenuBase.m')).replace(' ','')
conntweak=strip(R('Companions/MYBConnectivity/Tweak.xm'))
cstweak_raw=R('Companions/MYBPrivateCallService/Tweak.m')
cstweak=strip(cstweak_raw)
mk=R('Preferences/Makefile')

# never shares state with Private Calls
need('net.myxxdev.mybloxx.firewall.plist' in conn and 'MYBFirewallPrefsFile' in conn,'the Firewall has its own preference file, never Private Calls\' privacy.plist')
need('MYB_PC_KEY_SWITCH' not in rules and 'MYB_PC_KEY_SWITCH' not in store,'the Firewall never reuses Private Calls\' switch key')

# decision precedence (exercised in depth by firewall-core.m; here we only confirm the documented order still appears in the source)
need('always wins' in rules_raw and 'absolute' in rules_raw and 'Unknown rule' in rules_raw and 'International Block' in rules_raw,'the decision function still documents its own precedence order')
need(re.search(r'MYBFWNothing\s*=\s*0',rules) is not None and re.search(r'MYBFWDoHangup\s*=\s*3',rules) is not None,'the Firewall decision enum keeps its own explicit numbering, never assumed to match the daemon\'s int convention')

# store reuses Private Calls' proven locking, never a second lock implementation
need('MYBPCLockTake' in store and 'MYBPCLockGive' in store,'the Firewall store reuses the one proven file lock, not a second implementation')
need(not re.search(r'flock\(|O_EXLOCK',store),'no new locking primitive was written for the Firewall')

# wire format has no CF/notify dependency (kept testable on the desktop GNUstep toolchain)
need('notify.h' not in wire and 'CFPreferences' not in wire,'the wire (text) layer stays pure Foundation so it can be unit-tested on the desktop')
need('CFPreferences' in fwl and 'MYBCallServiceChannel.h' in fwl and 'MYBFirewallWire.h' in fwl,'the publish layer is the thin CF/notify wrapper around the wire layer')
need('MYB_FWL_NEED' in fwl,'the daemon can ask SpringBoard for a fresh copy, the same way it does for Private Calls')

# daemon integration: additive only, Decide() itself is untouched
decide_body=re.search(r'static int Decide\(id call\)\s*\{.*?\n\}',cstweak,re.S)
need(decide_body is not None and 'FirewallDecide' not in decide_body.group(0),'Decide() (Private Calls) was not modified to add the Firewall')
need('static int FirewallDecide(id call)' in cstweak,'the Firewall has its own, independent decision function in the call service')
need(re.search(r'int d = Decide\(call\);\s*\n\s*if \(!d\) d = FirewallDecide\(call\);',cstweak) is not None,'the Firewall only gets a turn when Private Calls has nothing to say about the call')
need('notify_post(MYB_FWL_NEED)' in cstweak,'the daemon asks SpringBoard to publish a fresh copy when it finds no live data yet')
need('#import "../../Shared/MYBFirewallList.h"' in cstweak_raw,'the call service imports the Firewall\'s own live-channel header')

# SpringBoard mirror: the same publish-at-start / on-change / on-request pattern already proven for Private Calls
need('publishFirewallList' in conntweak and 'startFirewallListMirror' in conntweak,'the Firewall gets its own mirror function, parallel to Private Calls\' startPrivateListMirror')
need(re.search(r'startFirewallListMirror\(void\)\{.*?publishFirewallList\(\);.*?MYB_FW_NOTIFY.*?MYB_FWL_NEED',conntweak,re.S) is not None,'the Firewall mirror publishes at start and listens for both a settings change and a daemon request')
need('startFirewallListMirror();' in conntweak.split('isEqual:@"com.apple.springboard"')[1][:400],'the Firewall mirror is actually started in the SpringBoard ctor branch')

# Settings UI: visible, not hidden behind a gesture (the opposite of Private Calls, by design)
need('@interface MYBFirewallController : MYBTileListBase' in ctrl,'the Firewall/Protection Center has its own visible Settings screen, now with the live stat-tile hero')
need(ctrl.count('"switch"')>=2,'the screen has at least a master switch and the Allow List Mode switch')
need('Allow List Mode' in ctrl and 'MYB_FW_KEY_ALLOWLIST' in ctrl,'Allow List Mode is exposed')
need('No Caller ID' in ctrl and 'MYB_FW_KEY_UNKNOWN_ACTION' in ctrl,'the Unknown/no-caller-ID rule is exposed')
need('Block International Numbers' in ctrl and 'MYB_FW_KEY_INTL_BLOCK' in ctrl,'the International Block rule is exposed')
need('Number Ranges' in ctrl and 'askRange' in ctrl and 'MYBFWValidRange' in ctrl,'number ranges can be added and are validated before being stored')
need('askNumber' in ctrl and 'pickContacts' in ctrl,'a number can be added by hand or from Contacts, the same two ways Private Calls offers')
need('Remove from Call Firewall' in ctrl,'a number can be removed again')
need('Allow' in ctrl and 'MYB_FW_ACTION_ALLOW' in ctrl,'a listed number can be exempted from every blanket rule with Allow')
need('MYXXAuthenticate' not in ctrl,'the Firewall screen itself needs no extra authentication beyond Settings\' own PIN gate')
# the Preferences bundle runs inside Settings.app, never inside Phone/Messages/Photos, so it can never call an MYXX*-prefixed function: those are
# implemented only in Companions/MYBPrivate*/PrivateUI.m, which is compiled into those three companion dylibs, not into Preferences -- calling one
# here links clean (the undefined-symbol check only runs at dyld load time) and then crashes the whole Settings bundle the instant it's opened.
need(not re.search(r'\bMYXX[A-Z]\w*\s*\(',ctrl),'the Settings screen calls no function that only exists in the Private Calls/Messages/Photos companion dylibs')
need('PrivatePhotos/PrivateUI.h' not in ctrl and 'PrivateMessages' not in ctrl and 'MYBPrivateCalls/' not in ctrl,'the Settings screen does not import a companion dylib\'s own header')
need(ctrl.count('MYBFWAfterChange()')>=3 and re.search(r'MYBFWAfterChange\(void\)\{notify_post\(MYB_FW_NOTIFY\);MYBFWLPublish',ctrl) is not None,'every settings write funnels through one place that republishes immediately, so no reboot is needed to see a change')

# wired into the dashboard and the icon registry, as a top-level, visible feature (never nested under Extra Privacy Protection, which is for the hidden features)
need('"MYBFirewallController"' in modern and 'Protection Center' in modern,'Protection Center has its own row on the main Settings page')
need(re.search(r'@"PROTECTION CENTER"[^@]*?@"rows":@\[\s*@\{[^}]*?"MYBFirewallController"',modern,re.S) is not None,'Protection Center sits in its own top-level section, not folded into Extra Privacy Protection')
need('"MYBFirewallController":@[' in menubase,'the icon and tone registry has an entry for the new screen')

# Makefile
need('MYBFirewallController.m' in mk,'the new Settings screen is actually compiled into the bundle')

# Known Junk Callers: Mikey's own bulk (~1.1M-number) spam-caller dataset, bolted onto the existing Call Firewall rather than given a whole new
# feature of its own, since it is squarely an extension of what the Firewall already decides. The matcher itself (binary search over a sorted,
# fixed-width mmapped file) is covered in depth by junk-callers-core.m; this only checks the pieces are plugged together, in the right order.
jc=strip(R('Shared/MYBJunkCallers.h'))
gen=R('tools/generate-junk-callers.py')
need('MYB_FW_KEY_JUNKCALLERS_ON' in rules and 'MYB_FW_KEY_JUNKCALLERS_ACTION' in rules,'the Firewall rules header has the two new Known Junk Callers keys')
need(re.search(r'numberWithBool:NO\],MYB_FW_KEY_JUNKCALLERS_ON',store) is not None,'Known Junk Callers defaults OFF -- an aggregated, unreviewed list, unlike the Firewall\'s own hand-curated rules')
need('junkcallers=%d' in wire and 'junkcallersaction=%@' in wire and '"junkcallers="' in wire.replace(' ','') and '"junkcallersaction="' in wire.replace(' ','').replace('\n',''),'the wire format publishes and parses the two new settings, the same live channel every other Firewall rule already uses')
need('MYB_JC_RECORD_LEN' in jc and 'MYB_JC_HEADER_LEN' in jc,'the dataset header defines its fixed record/header widths')
need('static inline BOOL MYBJCBufferContains(' in jc and 'memcmp' in jc,'the matcher is a real binary search over raw bytes, not a linear scan or an NSArray of a million strings')
need('mmap(' in jc and 'MAP_PRIVATE' in jc and 'PROT_READ' in jc,'the dataset is memory-mapped read-only, never fully loaded into live memory')
need('roothide.h' not in R('Shared/MYBJunkCallers.h'),'the pure matcher header stays plain Foundation, with no RootHide SDK dependency -- that stays in the call-service hook, which already links it')
need('#import <roothide.h>' in cstweak_raw and '#import "../../Shared/MYBJunkCallers.h"' in cstweak_raw,'the call service hook brings in both RootHide path resolution and the matcher header')
jc_fallback=re.search(r'if \(decision == MYBFWNothing && !unknownCaller && key\.length && JunkRecords && \[\[settings objectForKey:MYB_FW_KEY_JUNKCALLERS_ON\] boolValue\]\)',cstweak)
need(jc_fallback is not None,'the bundled dataset is only ever consulted when nothing else -- no entry, no range, no Allow List Mode, no International Block -- already decided the call')
need(re.search(r'decision = MYBFWFromAction\(\[settings objectForKey:MYB_FW_KEY_JUNKCALLERS_ACTION\]\)',cstweak) is not None,'a match applies the user\'s own configured action, not a hardcoded one')
need('Count(@"jcChecked")' in cstweak and 'Count(@"jcMatched")' in cstweak,'Known Junk Callers gets its own diagnostics counters, same class/counter-only convention as the rest of the hook')
need(not re.search(r'Count\(\[NSString stringWithFormat:@"jc\w*%@',cstweak),'the diagnostics never interpolate a number or a name into a Known Junk Callers counter key')
need(re.search(r'MYBJCLoad\(jbroot\(MYB_JC_DATASET_PATH\)',cstweak) is not None,'the dataset is loaded from its real on-device path via jbroot, not a hardcoded absolute path')
need('"Known Junk Callers"' in ctrl and 'MYB_FW_KEY_JUNKCALLERS_ON' in ctrl and '"switch"' in ctrl,'the Settings screen exposes Known Junk Callers as a switch, same pattern as every other rule')
need('chooseJunkCallers' in ctrl and '- (void)chooseJunkCallers{' in ctrl,'the per-match action (Mute/Decline/Hang up) is configurable, same as every other Firewall rule')
need('tools/data/junk-callers-source.txt' in gen and "'<Q'" in gen,'the generator reads the checked-in raw source list and writes the 8-byte little-endian record-count header the matcher expects')
need(re.search(r"'layout'\s*/\s*'usr'\s*/\s*'share'\s*/\s*'mybloxx'\s*/\s*'junk-callers'\s*/\s*'JunkCallers\.dat'",gen) is not None,'the compiled dataset is written into the layout tree, so Theos ships it in the package the same way it ships the PAC/profile files')
need('tools/generate-junk-callers.py' in R('.github/workflows/build-deb-only.yml'),'the generator actually runs in CI before packaging, alongside the existing PAC/profile generators')
import pathlib as _pl
_dat=_pl.Path(ROOT/'layout/usr/share/mybloxx/junk-callers/JunkCallers.dat')
need(_dat.exists() and _dat.stat().st_size>8,'the compiled dataset file exists and is non-empty (freshly regenerated from the checked-in source before every build)')

# Protection Center: Call Firewall and Message Firewall unified into one screen with a live stat-tile hero, reusing
# the existing MYBTileListBase/MYBStatHero machinery (Activity's own hero) rather than inventing a new UI system.
stats=strip(R('Shared/MYBProtectionStats.h'))
mftweak=strip(R('Companions/MYBMessageFirewall/Tweak.m'))
need('MYBCSCSetStateIn' in stats and 'MYBCSCGetStateIn' in stats,'the counters reuse the proven sandbox-safe notify-state mailbox, not a new IPC mechanism')
need('#import "MYBTileBase.h"' in R('Preferences/MYBFirewallController.m'),'Protection Center pulls in the shared stat-tile hero base')
need(re.search(r'@interface MYBFirewallController\s*:\s*MYBTileListBase',ctrl) is not None,'Protection Center is built on the hero+tiles base, not plain MYBMenuBase')
need('Calls Blocked' in ctrl and 'Texts Blocked' in ctrl and 'Protections On' in ctrl,'the hero shows real call/message block counts plus a live protections-on count')
need('MYBPSCallsBlocked()' in ctrl and 'MYBPSMessagesBlocked()' in ctrl,'the tile values come from the real counters, never a hardcoded or placeholder number')
need('#import "../../Shared/MYBProtectionStats.h"' in cstweak_raw and 'MYBPSBumpCalls()' in cstweak,'the call service hook bumps the real counter exactly where a call is actually stopped/muted/hung up')
need('#import "../../Shared/MYBProtectionStats.h"' in R('Companions/MYBMessageFirewall/Tweak.m') and 'MYBPSBumpMessages()' in mftweak,'the message firewall hook bumps the real counter exactly where a message is actually blocked')
need(re.search(r'if \(blocked\) MYBPSBumpMessages\(\);',mftweak) is not None,'the message counter bumps once per genuinely blocked message, not once per message merely checked')

# Message Firewall diagnostics: whether the imagent hook actually installed is otherwise invisible from the phone, so this answers it from a real
# on-device self-report, with the hook and the reader sharing one definition of the report channel's name so they can never drift apart.
mfl=strip(R('Shared/MYBMessageFirewallList.h'))
need('MYB_MFH_OWN_DOMAIN' in mfl and 'MYB_MFH_OWN_KEY' in mfl and 'MYBMFHReadReport' in mfl,'the hook report channel name and its reader live in one shared header')
need('#define MYB_MFH_OWN_DOMAIN' not in mftweak,'the hook no longer keeps its own private copy of the report channel name -- it uses the shared one')
need('#define MYB_MFH_OWN_KEY' not in mftweak,'the hook no longer keeps its own private copy of the report key -- it uses the shared one')
need('copyMessageFirewallDiagnostics' in ctrl,'Protection Center can answer whether the message hook actually loaded into imagent, not just display settings')
need('MYBMFHReadReport()' in ctrl,'the diagnostics action reads the hook\'s real self-report rather than assuming it installed')
need('messageFirewallSwitch' in ctrl and 'MYBMFSwitchOn(MYBMessageFirewallFile())' in ctrl,'diagnostics surface the master switch state directly, the most common reason nothing blocks yet')
print(f'\n{total-len(bad)}/{total} passed')
if bad:
    print(f'{len(bad)} FAILED:')
    for b in bad:print(' -',b)
    sys.exit(1)
