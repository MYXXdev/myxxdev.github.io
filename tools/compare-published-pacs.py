#!/usr/bin/env python3
"""Behavioural comparison of the PACs a Legacy Mode profile actually receives against the PACs this package generates.
Usage: compare-published-pacs.py [--dir DIR] [--base URL] [--strict]
  --dir   read published PACs from DIR (<name>.pac), e.g. a checkout of the rules repository
  --base  otherwise fetch <base>/<name>.pac (default: the jsDelivr master address the profiles use)
Every domain in rules/canonical.json is probed (apex, subdomain, look-alike) through the real PAC text under node. Prints, per PAC, how
many probes decide differently from the bundled one. Exit 1 with --strict when any differ (CI uses --strict once the prepared rules are published)."""
import json,subprocess,sys,tempfile,time,urllib.request,urllib.error
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'rules'))
import generate as G
args=sys.argv[1:];strict='--strict' in args
def opt(n,d=None):return args[args.index(n)+1] if n in args else d
src=opt('--dir');base=opt('--base','https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX')
NAMES=['Default']+list(G.ORDER)+sorted(G.CANON['aliases'])  # every file a profile or older consumer can fetch, aliases included
canon=G.CANON;doms=set(canon['base']['domains']);kills=set(canon['base']['kill'])
for o in canon['options'].values():doms|=set(o['domains_add'])|set(o['domains_remove']);kills|=set(o['kill_add'])
hosts=sorted(doms|kills);probes=[]
for d in hosts:
    for h in (d,'www.'+d,'x.y.'+d,'not'+d,d+'.example.org'):probes.append(['https://'+h+'/',h])
for h in sorted(set(canon['exact_allow'])|set(canon.get('exact_allow_unless',{}))|{'marketingturkiye.com','www.marketingturkiye.com'}):probes.append(['https://'+h+'/',h])  # exceptions, and the look-alike that must not be exempt
for h in ['github.com','raw.githubusercontent.com','www.apple.com','example.com','login.microsoftonline.com','ads.doubleclick.net']:probes.append(['https://'+h+'/',h])
def classify(code,headers,body):
    """Names the likely cause of an HTTP failure from what the host actually answered. A guess is labelled as one."""
    h={k.lower():v for k,v in headers.items()}
    if code==429 or 'retry-after' in h:return 'rate limiting (the host asked us to slow down)'
    if code==404:return 'wrong URL or file not published (404)'
    if code in (401,403):
        if h.get('x-ratelimit-remaining')=='0':return 'rate limiting (quota exhausted)'
        if 'blocked' in body.lower() or 'abuse' in body.lower() or 'rate' in body.lower():return 'host policy or rate block (the body says so)'
        return 'permissions or host-side block (%d with no rate-limit header; not a wrong URL, the same file is served by raw.githubusercontent.com)'%code
    if code>=500:return 'hosting outage (%d)'%code
    return 'unclassified (%s)'%code
def fetch(n):
    if src:return (Path(src)/(n+'.pac')).read_text()
    last=None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(base+'/'+n+'.pac',timeout=30) as r:return r.read().decode()
        except urllib.error.HTTPError as e:
            body=e.read(300).decode('utf-8','replace');last=(e.code,dict(e.headers),body)
            if e.code in (404,): break
            time.sleep(2*(attempt+1))
        except Exception as e:last=(0,{},str(e));time.sleep(2*(attempt+1))
    raise Unavailable(n,*last)
class Unavailable(Exception):
    def __init__(self,n,code,headers,body):self.n,self.code,self.headers,self.body=n,code,headers,body
def decide(pacs):
    tmp=Path(tempfile.mkdtemp());paths={}
    for n,text in pacs.items():f=tmp/(n+'.pac');f.write_text(text);paths[n]=str(f)
    p=subprocess.run(['node',str(root/'tests/pac-eval.js')],input=json.dumps({'pacs':paths,'probes':probes}).encode(),capture_output=True)
    if p.returncode:print(p.stderr.decode()[:500]);sys.exit(2)
    return json.loads(p.stdout)
bundled={n:(root/'layout/usr/share/mybloxx/pacs'/(n+'.pac')).read_text() for n in NAMES};pub={};unavailable=[]
for n in NAMES:
    try:pub[n]=fetch(n)
    except Unavailable as e:
        keep=('server','cf-ray','cf-cache-status','x-jsd-version','x-served-by','retry-after','x-ratelimit-remaining','content-type','via')
        print('UNAVAILABLE %-13s %s%s\n   url: %s\n   cause: %s\n   headers: %s\n   body: %r'%(n,'HTTP %d'%e.code if e.code else 'no response','',base+'/'+n+'.pac',classify(e.code,e.headers,e.body),{k:v for k,v in e.headers.items() if k.lower() in keep},e.body[:200]))
        unavailable.append(n)
if unavailable:
    print('\nUpstream availability problem: %d of %d published PACs could not be read (%s). Local rule correctness is tested by other steps; this step compares the live files and cannot run for these.'%(len(unavailable),len(NAMES),', '.join(unavailable)))
    for n in unavailable:NAMES.remove(n)
a=decide({n:bundled[n] for n in NAMES});b=decide(pub);diff=0
print('probes per PAC: %d'%len(probes))
for n in NAMES:
    # the evaluator returns decisions per PAC name, probe order preserved
    x,y=a[n],b[n];d=[(probes[i][1],x[i],y[i]) for i in range(len(probes)) if x[i]!=y[i]]
    print('%-13s %s  %d of %d decisions differ%s'%(n,'MATCH' if not d else 'DIFFERS',len(d),len(probes),'' if not d else '   e.g. '+'; '.join('%s: published %s, intended %s'%(h,py,bx) for h,bx,py in d[:3])));diff+=len(d)
sys.exit(3 if unavailable else (1 if strict and diff else 0))
