"""DNS profiles must match the provider values recorded from the providers' official pages (tools/dns-providers-verified.json),
be well-formed Apple DNS Settings payloads, carry no MYbloXX data and no on-demand rules, and be user-removable."""
import json,plistlib,sys,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1];fails=[]
def check(ok,msg):
    print(('PASS ' if ok else 'FAIL ')+msg)
    if not ok:fails.append(msg)
ver=json.loads((root/'tools/dns-providers-verified.json').read_text())
check(all(p['sources']['url'].startswith('https://') and p['sources']['addresses'].startswith('https://') for p in ver['providers'].values()),'every verified value names its official source page')
seen=set()
for name,p in ver['providers'].items():
    f=root/'layout/usr/share/mybloxx/dns'/(name+'.mobileconfig');check(f.exists(),f'{name}: profile is bundled')
    prof=plistlib.loads(f.read_bytes());pay=prof['PayloadContent'][0];dns=pay['DNSSettings']
    check(prof['PayloadType']=='Configuration' and pay['PayloadType']=='com.apple.dnsSettings.managed','%s: Configuration profile with a com.apple.dnsSettings.managed payload'%name)
    check(dns['DNSProtocol']=='HTTPS' and dns['ServerURL']==p['url'],f'{name}: DoH URL equals the documented one ({dns["ServerURL"]})')
    check(dns['ServerAddresses']==p['addresses'],f'{name}: bootstrap addresses equal the documented ones')
    check(dns['ServerURL'].startswith('https://') and not any(k in dns for k in('MatchDomains','SupplementalMatchDomains')),f'{name}: no domain-scoping that would silently narrow the resolver')
    check(not any(k in pay or k in prof for k in('OnDemandRules','ProhibitDisablement')),f'{name}: no on-demand rules and nothing that prevents turning it off')
    check(prof.get('PayloadRemovalDisallowed') is False,f'{name}: user can remove it')
    ids=[prof['PayloadUUID'],pay['PayloadUUID']]
    check(all(str(uuid.UUID(i)).upper()==i for i in ids) and not (set(ids)&seen) and ids[0]!=ids[1],f'{name}: unique well-formed UUIDs');seen|=set(ids)
    check('MYbloXX' not in json.dumps(dns),f'{name}: carries no MYbloXX data')
sys.exit(1 if fails else 0)
