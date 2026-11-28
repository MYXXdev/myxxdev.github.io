"""WebKit Networking refresh policy through the REAL helper entry point as a process (the process table itself is faked by the test
seam; the engine is covered by tests/process-refresh-native.m). usage: webkit-refresh-e2e.py <helper process binary> <pacs dir>
Checks that a refresh runs ONCE per committed protection change, and never for no-op, read-only, failed or appearance operations."""
import os,subprocess,sys,tempfile
from pathlib import Path
helper,pacs=sys.argv[1:3];fails=[]
def check(ok,msg):
    print(('PASS ' if ok else 'FAIL ')+msg)
    if not ok:fails.append(msg)
def H(args,root,extra=None):
    env=dict(os.environ,MYB_FIXTURE_ROOT=root,MYB_TEST_PACS=pacs,MYB_TEST_NO_SLEEP='1',MYB_TEST_VERIFY='applied');env.update(extra or {})
    return subprocess.run([helper]+args,env=env,capture_output=True,text=True,timeout=120)
def count(root,text='WebKit Networking refresh requested (test seam)'):
    p=Path(root)/'var/mobile/Library/MYbloXX/control.log';return p.read_text(errors='ignore').count(text) if p.exists() else 0
d=tempfile.mkdtemp(prefix='mybwk-');r=H(['--init'],d);assert r.returncode==0,r.stdout+r.stderr
base=count(d)
domains=','.join(f'bulk{i}.example' for i in range(60))
b=count(d);r=H(['localcustom',domains,''],d);check(r.returncode==0,'a 60-domain import succeeds')
if r.returncode!=0:
    lg=Path(d)/'var/mobile/Library/MYbloXX/control.log';print('DIAG exit',r.returncode,'stdout',r.stdout[-400:],'stderr',r.stderr[-400:]);print('DIAG log tail',(lg.read_text(errors='ignore')[-1200:] if lg.exists() else 'no control.log'))
check(count(d)-b==1,f'60 imported domains cause ONE WebKit refresh (got {count(d)-b})')
b=count(d);r=H(['localcustom',domains,''],d);check(r.returncode==0 and count(d)==b,'re-applying the same rules changes nothing and refreshes nothing')
b=count(d);H(['status'],d);H(['pacview'],d);H(['statuspublish'],d);check(count(d)==b,'status, PAC view and diagnostics never refresh')
b=count(d);r=H(['mode','blockApple'],d);check(r.returncode==0 and count(d)-b==1,'a mode change refreshes once')
b=count(d);r=H(['mode','blockApple'],d);check(count(d)==b,'selecting the mode already in use refreshes nothing')
b=count(d);r=H(['disable'],d);check(r.returncode==0 and count(d)-b==1,'turning protection off refreshes once')
b=count(d);r=H(['enable'],d);check(r.returncode==0 and count(d)-b==1,'turning protection on refreshes once')
b=count(d);r=H(['localcustom','other.example',''],d,{'MYB_TEST_RESTART_RESULT':'69'});check(r.returncode!=0 and count(d)==b,'a change that failed and was rolled back does not refresh')
# the exception applies to the mode in force (blockApple since the mode change above); another mode is refused with 69
b=count(d);r=H(['allowwebsite','site.example','blockApple','temp'],d);ok=r.returncode==0;check(ok and count(d)-b==1,'temporary website access refreshes once when it starts')
b=count(d);r=H(['revokewebsite','site.example'],d);check(r.returncode==0 and count(d)-b==1,'revoking temporary access refreshes once')
b=count(d);r=H(['pruneexpired'],d);check(count(d)==b,'an expiry sweep with nothing to expire refreshes nothing')
sys.exit(1 if fails else 0)
