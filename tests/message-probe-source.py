#!/usr/bin/env python3
# Message Firewall research, step one: MYBMessageProbe (Companions/MYBMessageProbe). A read-only, no-hook look at imagent's own loaded classes, so the
# real object graph around a message's suppression decision is known from the phone it will run on before any blocking code gets written. These
# checks exist to keep it exactly that -- read-only, class/property/method NAMES only, never a live message -- even as the probe or its Settings
# entry point changes.
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILS = []
def need(cond, label):
    print(('ok  ' if cond else 'FAIL'), label)
    if not cond: FAILS.append(label)

probe_dir = ROOT / 'Companions' / 'MYBMessageProbe'
tweak = (probe_dir / 'Tweak.m').read_text()
plist = (probe_dir / 'MYBMessageProbe.plist').read_text()
makefile = (probe_dir / 'Makefile').read_text()
main_makefile = (ROOT / 'Makefile').read_text()
diag = (ROOT / 'Preferences' / 'MYBDiagnosticsController.m').read_text()

need('"imagent"' in plist, 'the probe injects into imagent, nowhere else')
need('.xm' not in makefile and 'Tweak.m' in makefile, 'the probe is a plain tweak, not a Logos hook file')
need('%hook' not in tweak and 'MSHookMessageEx' not in tweak and 'MSHookFunction' not in tweak, 'the probe installs no hook of any kind')
need('Companions/MYBMessageProbe' in main_makefile, 'the probe is actually built (wired into the aggregate Makefile)')

# the one live method call this file is allowed to make on a discovered class is NSClassFromString, to get the Class object for introspection --
# never an instance method that would read or touch a real message, handle or pipeline input.
import re
forbidden_calls = ['plainBody', 'formattedNumber', 'text]', '_id]', 'sender]', 'alloc]', 'new]']
need(not any(f in tweak for f in forbidden_calls), 'the probe never calls an accessor that would read live message/contact content')
need('class_copyPropertyList' in tweak and 'class_copyMethodList' in tweak, 'the probe reads only declared class metadata (names), not instances')
need('objc_copyClassList' in tweak, 'the probe finds classes by listing what imagent already has loaded, not by guessing or hardcoding one name')
need('property_getName' in tweak and 'sel_getName' in tweak, 'only names are extracted from the metadata, never values')
need('method_getTypeEncoding' in tweak, 'the probe also reads each method\'s type encoding (argument/return shape), needed to write a correct hook safely -- still metadata, never a value')

need('MYBCSCPublishIn' in tweak and 'net.myxxdev.mybloxx.imp' in tweak, 'the probe reports through the same proven one-way mailbox the audio probe uses, under its own namespace')
need('net.myxxdev.mybloxx.csm' not in tweak and 'net.myxxdev.mybloxx.csd' not in tweak, 'the message probe never reuses the call-service probe\'s namespace (reports would overwrite or be overwritten)')

# imagent may be sandboxed against channels callservicesd is allowed to use (or vice versa) -- the probe tries every channel Companions/MYBPrivateCallService
# already proved necessary, independently, so one being refused never silently loses the rest.
need('CFPreferencesSetAppValue' in tweak and 'com.apple.imagent' in tweak, 'the probe also writes its report into imagent\'s own preferences domain')
need('net.myxxdev.mybloxx.messageprobe' in tweak, 'the probe also writes into a dedicated preferences domain, separate from imagent\'s own')
need('MessageProbe.plist' in tweak and '/var/mobile/Library/MYbloXX/' in tweak and '/var/tmp/' in tweak and '/tmp/' in tweak, 'the probe also writes plain fallback files in the same spread of locations proven for the call service')
need('MarkAlive' in tweak and 'MessageProbeAlive' in tweak, 'a bare alive marker is written separately from the full report, so a constructor that ran but whose report channels were all refused can still be told apart from one that never ran')
need(all('@try' in tweak for _ in [0]) and tweak.count('@try') >= 4, 'every fallback channel is wrapped so one failing cannot stop or crash the rest')

need('"Message Pipeline Probe"' in diag, 'Settings has a way to copy the probe\'s report')
need('copyMessageProbe' in diag, 'the Settings row is wired to an actual copy action')
need('net.myxxdev.mybloxx.imp.probe' in diag and 'net.myxxdev.mybloxx.imp.%u' in diag, 'Settings asks the same probe it reads back from')
need('com.apple.imagent' in diag and 'net.myxxdev.mybloxx.messageprobe' in diag, 'Settings reads back the same fallback preferences domains the probe writes to')
need('MessageProbeAlive' in diag, 'Settings can tell the person a partial result (loaded, but no full report) apart from nothing at all')
need('never a number' in diag or 'never a number, a contact or a message' in diag.lower() or 'class and method names' in diag.lower() or 'class, property and method names' in diag.lower(), 'the copy confirmation tells the person what is and is not in what they are about to paste/share')

print(f'\n{len(FAILS)} failed' if FAILS else '\nAll message-probe source checks passed.')
sys.exit(1 if FAILS else 0)
