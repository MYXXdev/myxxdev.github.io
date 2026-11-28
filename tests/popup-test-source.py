"""Popup Test: the URL the Settings row opens is the one the local service serves, the page is stable and labelled, and nothing bypasses the policy."""
import re,sys,base64,hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parent.parent
R=lambda p:(root/p).read_text()
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg)
page=R('BlockedServer/PopupTestPage.html');main=R('BlockedServer/main.m');tr=R('Preferences/MYBTroubleshootingController.m')
need('#define MYB_BLOCK_PORT 8788' in main,'the local service listens on 8788 (port 80 is not used)')
need('"/mybloxx-window-test"' in main.replace('@"','"') and 'popupTest' in main,'the service serves /mybloxx-window-test')
need('http://127.0.0.1:8788/mybloxx-window-test' in tr and 'windows-test' not in tr,'Settings opens the exact route the service serves')
need('MYBLoopbackGET(8788,@"/mybloxx-window-test")' in tr and 'Repair Now' in tr,'Settings checks the page itself and offers Repair when it is unavailable')
need('openURL' in tr[tr.index('- (void)openPopupTest'):][:1200],'the test still opens in Safari, not an embedded view')
need('backdrop-filter:none' in page and '.ambient{display:none}' in page and 'class="ambient"' not in page,'light rendering: no stacked backdrop blur or animated blurred background')
need('Page ready' in page,'the page says it is ready before any test runs')
labels=re.findall(r"b:'(Run Test \d: [^']+)'",page)+re.findall(r"'(Run Test \d: [^']+)'",page)
need(len(set(labels))>=8,'every test has its own clearly labelled button (%d found)'%len(set(labels)))
need("tests.forEach(function(c){if(c.go&&!c.nocheck)" in page,'Run Tests 1 to 7 does not navigate the page away')
need('location.reload' not in page and 'setInterval' not in page and 'meta http-equiv' not in page.lower(),'the page never reloads or refreshes itself')
need("window.open(" in page and 'bypass' not in page.lower() and 'testMode' not in page,'tests call the real window.open with no bypass')
brand=root/'BlockedServer/Brand.h'
if brand.exists():
    src=brand.read_text();hs=re.search(r'MYBPopupScriptHash=@"([^"]+)"',src).group(1)
    pg=json.loads(re.search(r'MYBPopupTestPage=@(".*?");\n',src,re.S).group(1))
    sc=re.search(r'<script>(.*?)</script>',pg,re.S).group(1)
    need(base64.b64encode(hashlib.sha256(sc.encode()).digest()).decode()==hs,'the script hash in the response header matches the page script')
    need('{{MYB_BRAND}}' in pg and '/*MYB_TOKENS*/' not in pg and '/*MYB_GLASS*/' not in pg,'brand placeholder present, style tokens resolved')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Popup Test source checks passed.')
