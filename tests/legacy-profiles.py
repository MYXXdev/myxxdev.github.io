"""Legacy Mode profiles: remote PAC addresses (never localhost), the exact profile-to-PAC mapping, historical identifiers, and that every
mapped PAC is a standalone PAC the package generates. Also prints the mapping table used in the delivery report."""
import plistlib,re,sys,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1];fails=[]
def check(ok,msg):
    print(('PASS ' if ok else 'FAIL ')+msg)
    if not ok:fails.append(msg)
MAP={'Default':'Default','allowY':'allowY','blockAdSense':'blockAdSense','noApple':'blockApple','noSocials':'blockSocials','noXXX':'blockXXX'}
hdr=(root/'Shared/MYBProfiles.h').read_text()
check(all(re.search(r'@"%s":@"%s"'%(k,v),hdr) for k,v in MAP.items()),'MYBProfiles.h carries the same profile-to-PAC mapping')
seen=set();print('profile -> PAC address')
for name,pac in MAP.items():
    f=root/'layout/usr/share/mybloxx/profiles'/(name+'.mobileconfig');check(f.exists(),name+': profile is bundled')
    raw=f.read_bytes();p=plistlib.loads(raw);pay=p['PayloadContent'][0];url=pay['ProxyPACURL'];print('  %-13s %s'%(name,url))
    check(url=='https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/%s.pac'%pac,name+': remote jsDelivr PAC for '+pac)
    check(b'127.0.0.1' not in raw and b'localhost' not in raw.lower() and b'8787' not in raw,name+': no localhost, no local port')
    check(pay['PayloadType']=='com.apple.proxy.http.global' and pay['ProxyType']=='Auto' and len(p['PayloadContent'])==1,name+': one automatic-proxy payload')
    check(p['PayloadIdentifier']=='net.myxxdev.mybloxx' and p.get('PayloadRemovalDisallowed') is False and p['PayloadType']=='Configuration',name+': historical identifier, user-removable')
    ids=[p['PayloadUUID'],pay['PayloadUUID']];check(all(str(uuid.UUID(i)).upper()==i for i in ids) and not set(ids)&seen,name+': unique well-formed UUIDs');seen|=set(ids)
    check('OnDemandRules' not in p and 'ProhibitDisablement' not in raw.decode(),name+': nothing that prevents removal')
    check((root/'layout/usr/share/mybloxx/pacs'/(pac+'.pac')).exists(),name+': the standalone PAC is generated and bundled')
    check(not re.search(r'safari',raw.decode(errors='ignore'),re.I),name+': does not name a browser')
# the historical published names are byte-copies of the standalone PACs (aliases) so older installs keep working
for alias,pac in {'MYbloXX':'Default','MYbloXXallowY':'allowY','MYbloXXnoApple':'blockApple','MYbloXXnoSocials':'blockSocials','MYbloXXnoXXX':'blockXXX'}.items():
    check((root/'layout/usr/share/mybloxx/pacs'/(alias+'.pac')).read_bytes()==(root/'layout/usr/share/mybloxx/pacs'/(pac+'.pac')).read_bytes(),'alias %s.pac is a byte copy of %s.pac'%(alias,pac))
ctl=(root/'Preferences/MYBLegacyController.m').read_text()
check('legacyprepare' in ctl and '@"disable"' not in ctl,'Legacy Mode goes through the helper-enforced legacyprepare action (PIN checked by the helper, not by hiding a row)')
helper=(root/'Helper/MYXXdev.m').read_text()
check('legacyprepare' in helper and 'PinConfigured()){int gate=pinRequire(@"disable")' in helper,'the helper refuses legacyprepare without a PIN authorisation whenever a PIN is set')
check('localhealth' not in ctl and '127.0.0.1' not in ctl and not re.search(r'Safari',ctl),'Legacy Mode no longer needs a local service and does not name a browser')
sys.exit(1 if fails else 0)
