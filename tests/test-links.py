"""Section 13: the Ad Blocker Test page works in every generated PAC through exactly its own hostnames, nothing broader, and the old
turtlecute-specific exception is gone. Runs the real PAC text under node, for every shipped PAC."""
import json,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];pacs=sorted((root/'layout/usr/share/mybloxx/pacs').glob('*.pac'))
probes=[['https://%s/'%h,h] for h in ['superadblocktest.com','www.superadblocktest.com','superadblocktest.com.evil.example','xsuperadblocktest.com','sub.superadblocktest.com','evil-superadblocktest.com','turtlecute.org','www.turtlecute.org','ads.doubleclick.net']]
p=subprocess.run(['node',str(root/'tests/pac-eval.js')],input=json.dumps({'pacs':{f.stem:str(f)for f in pacs},'probes':probes}).encode(),capture_output=True)
if p.returncode:print(p.stderr.decode()[:400]);sys.exit(2)
res=json.loads(p.stdout);bad=0
def need(ok,m):
    global bad
    print(('PASS ' if ok else 'FAIL ')+m)
    if not ok:bad+=1
need(len(res)>=40,'%d PACs checked'%len(res))
for name,r in res.items():
    need(r[0]=='DIRECT' and r[1]=='DIRECT',name+': the test page and its www host load')
    if name in('Default','blockXXX','blockApple','blockSocials','allowY','blockAdSense'):need(r[8]!='DIRECT',name+': a real ad host is still blocked')
canon=(root/'rules/canonical.json').read_text()
import re
entries=sorted(set(re.findall(r'"([^"]*superadblocktest[^"]*)"',canon.split('"sources"')[0])))
need(entries==['superadblocktest.com','www.superadblocktest.com'],'the allow entries are exactly the two required hostnames, got %s'%entries)
need('turtlecute' not in canon.lower(),'canonical rules hold no turtlecute-specific exception')
need(all('turtlecute' not in f.read_text().lower() for f in pacs),'no shipped PAC mentions turtlecute')
sys.exit(1 if bad else 0)
