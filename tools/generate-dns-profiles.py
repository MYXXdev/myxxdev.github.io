#!/usr/bin/env python3
"""Generates the three bundled DNS profiles. Provider endpoints come from tools/dns-providers-verified.json, which records the official page each value was
read from and the date (2026-11-15). tests/dns-profiles.py fails if a profile drifts from that file.
Each is an Apple `com.apple.dnsSettings.managed` payload (DNS over HTTPS), installable on iOS 14 and later. The profiles hold no
MYbloXX® data, contain no on-demand rules and are removable by the user."""
from pathlib import Path
import plistlib,uuid
root=Path(__file__).resolve().parents[1]/'layout/usr/share/mybloxx/dns';root.mkdir(parents=True,exist_ok=True)
ns=uuid.UUID('4b7d1c0e-2f6a-4d57-9a31-5c8e0b77a4d2')
import json
_v=json.loads((Path(__file__).resolve().parent/'dns-providers-verified.json').read_text())['providers']
_titles={'Cloudflare':'Cloudflare 1.1.1.1','Google':'Google Public DNS','Quad9':'Quad9 (secured)'}
providers={k:{'title':_titles[k],'url':v['url'],'addresses':v['addresses']} for k,v in _v.items()}
for key,p in providers.items():
    ident=f'net.myxxdev.mybloxx.dns.{key.lower()}'
    payload={'PayloadType':'com.apple.dnsSettings.managed','PayloadVersion':1,'PayloadIdentifier':ident+'.settings','PayloadUUID':str(uuid.uuid5(ns,key+'settings')).upper(),
      'PayloadDisplayName':p['title']+' (encrypted DNS)','DNSSettings':{'DNSProtocol':'HTTPS','ServerURL':p['url'],'ServerAddresses':p['addresses']}}
    profile={'PayloadType':'Configuration','PayloadVersion':1,'PayloadIdentifier':ident,'PayloadUUID':str(uuid.uuid5(ns,key+'profile')).upper(),
      'PayloadDisplayName':'MYbloXX® DNS - '+p['title'],'PayloadOrganization':'MYXXdev™',
      'PayloadDescription':'Encrypted DNS (DNS over HTTPS) using '+p['title']+'. This profile only sets which DNS resolver iOS uses; it does not change MYbloXX® blocking. Remove it in Settings > General > VPN & Device Management.',
      'PayloadRemovalDisallowed':False,'PayloadContent':[payload]}
    (root/(key+'.mobileconfig')).write_bytes(plistlib.dumps(profile,sort_keys=False))
print('Generated',len(providers),'DNS profiles')
