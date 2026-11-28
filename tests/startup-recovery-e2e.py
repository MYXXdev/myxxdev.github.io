"""Automatic recovery after a reboot / re-jailbreak, through the REAL helper entry point as a process.
usage: startup-recovery-e2e.py <helper process binary> <pacs dir>
The fixture simulates a reboot by deleting the volatile inline-PAC target while every saved preference remains; the
recovery action is then run exactly as the launchd job runs it. CFNetwork verification cannot be observed on a CI
runner, so MYB_TEST_VERIFY injects that single input (applied / not-applied); everything else is shipping code."""
import fcntl,os,plistlib,subprocess,sys,tempfile
from pathlib import Path
helper,pacs=sys.argv[1:3]
fails=[]
def check(ok,msg):
    if not ok:fails.append(msg);print('FAIL:',msg)
def H(args,root,extra=None):
    env=dict(os.environ,MYB_FIXTURE_ROOT=root,MYB_TEST_PACS=pacs,MYB_TEST_NO_SLEEP='1');env.update(extra or {})
    return subprocess.run([helper]+args,env=env,capture_output=True,text=True,timeout=120)
def init(extra=None,marker=True):
    d=tempfile.mkdtemp(prefix='mybstart-');r=H(['--init'],d,{} if marker else {'MYB_TEST_NO_OPTIN':'1'});assert r.returncode==0,r.stdout+r.stderr;return d
def verdict(root,host='kept.example'):return H(['--verdict',host],root).stdout.strip()
def rec(root):
    p=Path(root)/'var/mobile/Library/MYbloXX/StartupRecovery.plist'
    return plistlib.loads(p.read_bytes()) if p.exists() else {}
def restarts(root):
    p=Path(root)/'var/mobile/Library/MYbloXX/control.log'
    return p.read_text(errors='ignore').count('Restart requested (test seam)') if p.exists() else 0
def snap(root):return H(['--snapshot'],root).stdout.strip()
APPLIED={'MYB_TEST_VERIFY':'applied'}
# 1. THE reported bug: enabled, rebooted, no opt-in marker file. Repair works; the boot path must too.
d=init(marker=False);blocked=verdict(d);check(blocked not in('NO-FUNCTION',''),'fixture has a live PAC before the reboot')
H(['--reboot'],d);check(verdict(d)=='NO-FUNCTION','a reboot removes the volatile runtime target')
before=restarts(d);r=H(['startuprecover'],d,APPLIED)
check(r.returncode==0,f'startuprecover exits 0 after a reboot without the opt-in marker (got {r.returncode})')
check(verdict(d)==blocked,'the same effective PAC is back after startuprecover')
check(rec(d).get('result')=='already-applied' and rec(d).get('attempts')==2,f'reapplied, then verified on the next attempt ({rec(d).get("result")}/{rec(d).get("attempts")})')
check(restarts(d)-before==1,f'exactly one network refresh for one restoration (got {restarts(d)-before})')
# 2. Idempotent: running it again changes nothing and does not interrupt the network.
s1=snap(d);b=restarts(d);r=H(['startuprecover'],d,APPLIED)
check(r.returncode==0 and rec(d).get('result')=='already-applied' and rec(d).get('attempts')==1,'second run: already applied, first attempt')
check(restarts(d)==b and snap(d)==s1,'second run causes no configd restart and no state change')
# 3. 'restore' (the name older job files use) is the same path
H(['--reboot'],d);r=H(['restore'],d,APPLIED);check(r.returncode==0 and verdict(d)==blocked,'the legacy `restore` action uses the same recovery')
# 4. Disabled intent stays disabled, and a leftover owned configuration is removed
d2=init();check(H(['--set-intent','off'],d2).returncode==0,'fixture: saved intent off with the runtime still present')
b=restarts(d2);r=H(['startuprecover'],d2,APPLIED)
check(r.returncode==0 and rec(d2).get('result')=='disabled','disabled intent: result disabled')
check(verdict(d2)=='NO-FUNCTION','disabled intent: leftover MYbloXX runtime removed');check(restarts(d2)-b==1,'one refresh to leave stock networking')
H(['--reboot'],d2);b=restarts(d2);r=H(['startuprecover'],d2,APPLIED)
check(r.returncode==0 and verdict(d2)=='NO-FUNCTION' and restarts(d2)==b,'disabled after reboot: nothing applied, no network refresh')
# 5. Nothing saved (fresh install, or a respring/re-jailbreak with no configuration) is NOT treated as a first install
d3=tempfile.mkdtemp(prefix='mybstart-');check(H(['--init-empty'],d3).returncode==0,'fixture: empty')
r=H(['startuprecover'],d3,APPLIED);check(r.returncode==0 and rec(d3).get('result')=='nothing-to-restore' and verdict(d3)=='NO-FUNCTION','no saved configuration: nothing restored, nothing enabled')
# 6. Persistent failure: bounded refreshes, honest result, runtime stays in place, Repair remains the fallback
d4=init();H(['--reboot'],d4);b=restarts(d4);r=H(['startuprecover'],d4,{'MYB_TEST_VERIFY':'not-applied'})
check(r.returncode==69 and rec(d4).get('result')=='gave-up','unconfirmable protection: reported as gave-up, not success')
check(restarts(d4)-b<=3,f'at most one apply refresh plus two nudges (got {restarts(d4)-b})');check(verdict(d4)==blocked,'the applied runtime is left in place')
# 7. The operation lock is honoured: held lock -> no changes; released -> recovers
d5=init();H(['--reboot'],d5);lock=Path(d5)/'jb/var/run/mybloxx-operation.lock';fd=os.open(lock,os.O_CREAT|os.O_RDWR);fcntl.flock(fd,fcntl.LOCK_EX)
s=snap(d5);r=H(['startuprecover'],d5,APPLIED)
check(r.returncode!=0 and verdict(d5)=='NO-FUNCTION' and snap(d5)==s,f'held operation lock: no change, not success (exit {r.returncode})')
fcntl.flock(fd,fcntl.LOCK_UN);os.close(fd);r=H(['startuprecover'],d5,APPLIED);check(r.returncode==0 and verdict(d5)==blocked,'after the lock is released recovery succeeds')
# 8. Launch limit per boot: launchd cannot loop it forever
d6=init();H(['--reboot'],d6);codes=[H(['startuprecover'],d6,{'MYB_TEST_VERIFY':'not-applied'}).returncode for _ in range(6)]
check(codes[:4]==[69]*4 and codes[4]==0 and 'launch limit' in rec(d6).get('detail',''),f'launch limit stops the restart loop: {codes}')
# 9. Not our configuration (inline-PAC experiment / foreign owner): untouched
d7=init();H(['--reboot'],d7);Path(d7,'Managed/com.apple.SystemConfiguration.plist').write_bytes(plistlib.dumps({'Proxies':{'ProxyAutoConfigEnable':1,'ProxyAutoConfigURLString':'http://other.example/x.pac'}}))
r=H(['startuprecover'],d7,APPLIED);check(r.returncode==0 and rec(d7).get('result')in('not-ours','deferred','already-applied'),f'foreign configuration is not overwritten ({rec(d7).get("result")})')
# 10. Review finding 4: installed-but-unverifiable is its OWN result, is never recorded as verified, and is not retried forever
UNID={'MYB_TEST_VERIFY':'identity-unavailable'}
d8=init();H(['--reboot'],d8);b8=restarts(d8);r=H(['startuprecover'],d8,UNID);rc8=rec(d8)
check(r.returncode==0,f'identity-unavailable is a final answer: exit 0 (got {r.returncode})')
check(rc8.get('result')=='applied-unverified',f'recorded as applied-unverified, not restored/already-applied ({rc8.get("result")})')
check(rc8.get('verification')=='identity-unavailable' and 'verified' not in (rc8.get('detail','').replace('cannot be confirmed','').replace('not verified','')),f'the record does not claim verification ({rc8})')
check(rc8.get('attempts',99)<=2,f'no endless retries: {rc8.get("attempts")} attempt(s)')
check(restarts(d8)-b8==1,f'one network refresh for the one restoration, none for the unverifiable result (got {restarts(d8)-b8})')
b8=restarts(d8);s8=snap(d8);r=H(['startuprecover'],d8,UNID)
check(r.returncode==0 and rec(d8).get('result')=='applied-unverified' and rec(d8).get('attempts')==1 and restarts(d8)==b8 and snap(d8)==s8,'running it again: same answer on the first attempt, no refresh, no change')
if fails:print(len(fails),'startup-recovery check(s) FAILED');sys.exit(1)
print('Startup recovery checks passed: no-marker reboot, idempotence, disabled intent, nothing-saved, bounded failure, operation lock, launch limit.')
