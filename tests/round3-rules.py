"""Round 3 rule decisions, against the generated PACs run in node: four hosts blocked in every mode, VK blocked as a whole site,
Apple's other hosts untouched in Default, loopback never judged (so MYbloXX's own local pages always load), and the local test-page
routes carry no word the PAC blocks."""
import json, subprocess, sys, tempfile
from pathlib import Path
R = Path(__file__).resolve().parent.parent
fails = []
def need(ok, msg):
    print(('PASS ' if ok else 'FAIL ') + msg)
    if not ok: fails.append(msg)
js = r'''const fs=require('fs'),vm=require('vm');const out={},urls=JSON.parse(fs.readFileSync(0,'utf8'));
for(const f of process.argv.slice(1)){const c={};vm.createContext(c);vm.runInContext(fs.readFileSync(f,'utf8')+';this.F=FindProxyForURL',c);
 const m={};for(const u of urls)m[u]=c.F(u,new URL(u).hostname);out[f]=m;}
console.log(JSON.stringify(out));'''
urls = ['https://app.adjust.com/x', 'https://analytics.twitter.com/i', 'https://xp.apple.com/r', 'https://vk.com/rtrg?p=1',
        'https://www.apple.com/', 'https://ulink.adjust.com/ul/x', 'https://twitter.com/', 'https://api.twitter.com/',
        'http://127.0.0.1:8788/mybloxx-window-test', 'http://127.0.0.1:8788/mybloxx-window-target', 'http://localhost:8788/mybloxx-window-target',
        'http://127.0.0.1:8788/mybloxx-popup-test']
pacs = sorted(str(p) for p in (R / 'layout/usr/share/mybloxx/pacs').glob('*.pac'))
with tempfile.TemporaryDirectory() as tmp:
    script = Path(tmp) / 'run.js'; script.write_text(js.replace('process.argv.slice(1)', 'process.argv.slice(2)'))
    run = subprocess.run(['node', str(script)] + pacs, input=json.dumps(urls), capture_output=True, text=True)
    if run.returncode: print(run.stderr[-600:]); sys.exit(1)
    res = json.loads(run.stdout)
blocked = lambda v: v.startswith('PROXY')
need(all(blocked(m[u]) for m in res.values() for u in urls[:4]), 'app.adjust.com, analytics.twitter.com, xp.apple.com and vk.com/rtrg are blocked in every one of the %d PAC files' % len(res))
d = res[str(R / 'layout/usr/share/mybloxx/pacs/Default.pac')]
need(not blocked(d[urls[4]]) and not blocked(d[urls[5]]) and not blocked(d[urls[6]]) and not blocked(d[urls[7]]), 'www.apple.com, ulink.adjust.com (app links), twitter.com and api.twitter.com still load in Default')
need(all(not blocked(m[u]) for m in res.values() for u in urls[8:12]), 'loopback pages load in every mode, even a URL containing "popup"')
main = (R / 'BlockedServer/main.m').read_text() + (R / 'Preferences/MYBTroubleshootingController.m').read_text() + (R / 'BlockedServer/PopupTestPage.html').read_text()
need('mybloxx-popup-' not in main and 'mybloxx-window-test' in main and 'mybloxx-window-target' in main, 'the test-page routes avoid the word "popup"')
canon = json.loads((R / 'rules/canonical.json').read_text())
need({'127.0.0.1', 'localhost'} <= set(canon['exact_allow']) and 'vk.com' in canon['base']['domains'] and {'app.adjust.com', 'analytics.twitter.com', 'xp.apple.com'} <= set(canon['base']['kill']), 'canonical rules hold the decisions')
sys.exit(1 if fails else 0)
