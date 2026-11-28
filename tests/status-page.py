"""Status & Diagnostics page: runs the page's real model code (extracted from the shipping HTML) under node, and checks the
generated CSP hash and server wiring. Fails if the page, the generator or the route drift apart."""
import base64,hashlib,json,re,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];fails=[]
def check(ok,msg):
    print(('PASS ' if ok else 'FAIL ')+msg)
    if not ok:fails.append(msg)
html=(root/'BlockedServer/StatusPage.html').read_text()
brand=(root/'BlockedServer/Brand.h').read_text()
scripts=re.findall(r'<script>(.*?)</script>',html,re.S)
check(len(scripts)==1,'exactly one inline script')
tokens=(root/'BlockedServer/tokens.generated.css').read_text();glass=(root/'BlockedServer/glass.css').read_text()
built=html.replace('/*MYB_TOKENS*/',tokens).replace('/*MYB_GLASS*/',glass)
h=base64.b64encode(hashlib.sha256(re.findall(r'<script>(.*?)</script>',built,re.S)[0].encode()).digest()).decode()
check(('MYBStatusScriptHash=@"%s"'%h) in brand,'Brand.h carries the current status script hash (run tools/generate-block-brand.py)')
main=(root/'BlockedServer/main.m').read_text()
check('/mybloxx-status-page' in main and 'MYBStatusScriptHash' in main and '/mybloxx-status"' in main,'blockd serves the page with its own hash and keeps the JSON endpoint')
check(not re.search(r'https?://',scripts[0].replace('http://127.0.0.1','')),'page script makes no external requests')
check("fetch('/mybloxx-status'" in scripts[0],'page reads only the same-origin JSON endpoint')
check('innerHTML' not in scripts[0],'page never uses innerHTML (textContent only)')
runner=r'''
const js=process.argv[1];const f=new Function('document',js.replace('var MYBStatus=','globalThis.MYBStatus=')+';return MYBStatus');
const M=f(undefined);const now=Date.now(),s=now/1000;const out={};
const o=(x)=>M.overall(x,now).key;
out.none=o({intent:{known:false}});out.off=o({intent:{known:true,enabled:false}});
out.ok=o({intent:{known:true,enabled:true},runtime:{state:'configured',verification:'applied',publishedAt:s-5,verifiedAt:s-5}});
out.stale=o({intent:{known:true,enabled:true},runtime:{state:'configured',verification:'applied',publishedAt:s-900}});
out.unavail=o({intent:{known:true,enabled:true},runtime:{}});
out.missing=o({intent:{known:true,enabled:true},runtime:{state:'target-missing',publishedAt:s}});
out.notapplied=o({intent:{known:true,enabled:true},runtime:{state:'configured',verification:'not-applied',publishedAt:s}});
out.paused=o({intent:{known:true,enabled:true},appControlPaused:true});
out.disabledBeatsRuntime=o({intent:{known:true,enabled:false},runtime:{state:'configured',verification:'applied',publishedAt:s}});
const d={status:{intent:{known:true,enabled:true,mode:'Default'}},popupTrace:[{result:'block',layer:'nav',app:'a',source:'secret.example',destination:'dest.example',time:'x'}],browserStates:{}};
out.noCopy=typeof M.copyText==='undefined';
console.log(JSON.stringify(out));'''
r=subprocess.run(['node','-e',runner,scripts[0]],capture_output=True,text=True)
check(r.returncode==0,'model runs under node'+(' '+r.stderr[-200:] if r.returncode else ''))
if r.returncode==0:
    o=json.loads(r.stdout)
    for k,v in dict(none='not-configured',off='disabled',ok='verified',stale='stale',unavail='unavailable',missing='missing',notapplied='not-applied',paused='paused',disabledBeatsRuntime='disabled').items():
        check(o[k]==v,'overall state %s -> %s (got %s)'%(k,v,o[k]))
    check(o['noCopy'] and 'id="copy"' not in html and 'Raw JSON' not in html and 'JSON.stringify(d' not in html,'no Copy Diagnostics button and no raw JSON on the status page')
sys.exit(1 if fails else 0)
