#!/usr/bin/env python3
"""Checks, over the internet, the endpoints the Legacy Mode profiles depend on. Run it from a machine with normal network access (CI does).
FAILS when a mapped PAC address is unreachable or is not a PAC. REPORTS (does not fail) whether the published PAC already equals the
standalone PAC bundled in this package: until the prepared rules branch is published, the published PACs are the earlier rules."""
import hashlib,re,sys,time,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1]
MAP={'Default':'Default','allowY':'allowY','blockAdSense':'blockAdSense','noApple':'blockApple','noSocials':'blockSocials','noXXX':'blockXXX'}
LINKS={'Default':'MYbloXX','allowY':'MYbloXXallowY','noApple':'MYbloXXnoApple','noSocials':'MYbloXXnoSocials','noXXX':'MYbloXXnoXXX'}
def get(url):
    last=None
    for _ in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'mybloxx-verify'}),timeout=30) as r:return r.status,r.read(),r.headers.get('Content-Type','')
        except Exception as e:last=e;time.sleep(2)
    return None,str(last).encode(),''
bad=0
for name,pac in MAP.items():
    url=f'https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/{pac}.pac';code,body,ctype=get(url)
    ok=code==200 and b'FindProxyForURL' in body;same=ok and hashlib.sha256(body).digest()==hashlib.sha256((root/f'layout/usr/share/mybloxx/pacs/{pac}.pac').read_bytes()).digest()
    print(('OK   ' if ok else 'FAIL ')+f'{name:13s} {url}  {code}  {"= bundled hybrid" if same else "differs from the bundled hybrid (publish the prepared rules)"}');bad+=0 if ok else 1
for name,pub in LINKS.items():
    url=f'https://myxxdev.github.io/MYbloXX/{pub}.mobileconfig';code,body,ctype=get(url)
    print(('OK   ' if code==200 else 'WARN ')+f'{name:13s} profile link {url}  {code}  {ctype}')
sys.exit(1 if bad else 0)
