"""First-install defaults, upgrade preservation, Restore Default Settings and Proxy Override, through the REAL helper entry
point as a process. usage: defaults-e2e.py <helper process binary> <pacs dir>
Fixture root + injected configd restart result are the only seams; every decision is shipping code."""
import json,os,plistlib,subprocess,sys,tempfile
from pathlib import Path
helper,pacs=sys.argv[1:3]
fails=[]
def check(ok,msg):
    if not ok:fails.append(msg);print('FAIL:',msg)
def H(args,root,extra=None):
    env=dict(os.environ,MYB_FIXTURE_ROOT=root,MYB_TEST_PACS=pacs,MYB_TEST_NO_SLEEP='1',MYB_TEST_FILES='1');env.update(extra or {})
    return subprocess.run([helper]+args,env=env,capture_output=True,text=True,timeout=120)
D=lambda root,n:Path(root)/'var/mobile/Library/MYbloXX'/n
P=lambda root,n:Path(root)/'var/mobile/Library/Preferences'/n
def plist(path):
    try:return plistlib.loads(Path(path).read_bytes())
    except Exception:return None
def verdict(root,host='100widgets.com'):return H(['--verdict',host],root).stdout.strip()
def snap(root):return H(['--snapshot'],root).stdout.strip()
def log(root):
    p=D(root,'control.log');return p.read_text(errors='ignore') if p.exists() else ''
def fresh():
    d=tempfile.mkdtemp(prefix='mybdef-');assert H(['--init-empty'],d).returncode==0;return d
def installed():
    d=tempfile.mkdtemp(prefix='mybdef-');r=H(['--init'],d);assert r.returncode==0,r.stdout+r.stderr;return d
BASE={'Enabled':True,'BlockPopups':True,'ShowBlocked':True,'PopupMode':'strict','RedirectAskAppStore':True,'RedirectAskOtherApps':False}
def shield_ok(root):
    s=plist(P(root,'net.myxxdev.mybloxx.safariguard.plist')) or {}
    return all(s.get(k)==v for k,v in BASE.items()) and not s.get('Blocked') and not s.get('Allowed')
# ---- A. genuine fresh install: every requested default is on and effective
d=fresh();r=H(['initdefaults'],d)
check(r.returncode==0,f'fresh initdefaults exits 0 (got {r.returncode}: {r.stdout}{r.stderr})')
rec=plist(D(d,'Defaults.plist')) or {};check(rec.get('origin')=='fresh' and rec.get('version')==1,f'fresh install recorded ({rec})')
st=plist(D(d,'State.plist')) or {};check(st.get('enabled') is True and st.get('mode')=='Default','master switch on, Default mode saved')
check(shield_ok(d),'Shield master, Website Rules, Block Popups, Show Blocked and Ask Before Apps Open the App Store on, Ask Before Links Open Other Apps off; Strict popups kept')
check((plist(D(d,'Updates.plist')) or {}).get('automatic') is True,'Automatic Updates on')
check(verdict(d) not in('NO-FUNCTION','DIRECT',''),f'the runtime really blocks after the defaults ({verdict(d)})')
check('YouTopia' not in r.stdout+r.stderr,'the retired YouTopia component is not mentioned or activated')
# ---- B. idempotent: running it again (or a helper launch / re-jailbreak) changes nothing
s1=snap(d);r=H(['initdefaults'],d);check(r.returncode==0 and snap(d)==s1,'second initdefaults changes nothing')
H(['diagnose'],d);H(['statuspublish'],d);check(snap(d)==s1,'a helper launch is not a first installation')
# ---- C. earlier install with NO baseline record: only never-chosen keys are completed; every saved value stays
d=installed()
P(d,'net.myxxdev.mybloxx.safariguard.plist').write_bytes(plistlib.dumps({'Enabled':True,'BlockPopups':False,'ShowBlocked':False,'Blocked':['kept.example'],'Allowed':[],'URLs':[]}))
D(d,'Updates.plist').write_bytes(plistlib.dumps({'automatic':False}))
check(H(['--set-intent','off'],d).returncode==0,'fixture: user had MYbloXX off');D(d,'Defaults.plist').unlink(missing_ok=True)
r=H(['initdefaults'],d);rec=plist(D(d,'Defaults.plist')) or {}
check(r.returncode==0 and rec.get('origin')=='upgrade-completed','a leftover install without a baseline record is completed, not mistaken for a configured one (got %s rc=%s %s)'%(rec.get('origin'),r.returncode,r.stdout))
s=plist(P(d,'net.myxxdev.mybloxx.safariguard.plist'))
check(s.get('BlockPopups') is False and s.get('ShowBlocked') is False and s.get('Enabled') is True,'explicit saved values (including false) are never changed')
check(s.get('RedirectAskAppStore') is True and s.get('RedirectAskOtherApps') is False and s.get('PopupMode')=='strict','keys that were never chosen get the baseline (App Store on, other apps off)')
check(s.get('Blocked')==['kept.example'],'custom Shield rules are kept')
check((plist(D(d,'Updates.plist')) or {}).get('automatic') is False,'an explicit Automatic Updates off stays off')
check((plist(D(d,'State.plist')) or {}).get('enabled') is False,'an explicit protection off stays off')
# C1. older choices become the same effective choices and the older keys are not rewritten (mixed, both on, master off)
for legacy,store,other in [({'RedirectEnabled':True,'RedirectOtherApps':False},True,False),({'RedirectEnabled':True,'RedirectOtherApps':True},True,True),({'RedirectEnabled':False,'RedirectOtherApps':True},False,False),({'RedirectEnabled':True},True,False)]:
    d=installed();old=dict({'Enabled':True,'Blocked':[],'Allowed':[],'URLs':[]},**legacy)
    P(d,'net.myxxdev.mybloxx.safariguard.plist').write_bytes(plistlib.dumps(old));D(d,'Defaults.plist').unlink(missing_ok=True)
    r=H(['initdefaults'],d);s=plist(P(d,'net.myxxdev.mybloxx.safariguard.plist')) or {}
    check(r.returncode==0 and s.get('RedirectAskAppStore') is store and s.get('RedirectAskOtherApps') is other,'older redirect choices %s keep their effective result (store %s, other %s; got %s/%s)'%(legacy,store,other,s.get('RedirectAskAppStore'),s.get('RedirectAskOtherApps')))
    check(all(s.get(k)==v for k,v in legacy.items()) and ('RedirectOtherApps' in s)==('RedirectOtherApps' in legacy),'the older redirect keys are left exactly as they were')
# C2. the same leftover with NOTHING chosen: every requested default becomes effective
d=installed()
P(d,'net.myxxdev.mybloxx.safariguard.plist').write_bytes(plistlib.dumps({'Blocked':[],'Allowed':[],'URLs':[]}))
D(d,'Updates.plist').write_bytes(plistlib.dumps({'revision':'old'}));D(d,'State.plist').write_bytes(plistlib.dumps({'savedAt':'x'}));D(d,'Defaults.plist').unlink(missing_ok=True)
r=H(['initdefaults'],d);rec=plist(D(d,'Defaults.plist')) or {}
check(r.returncode in (0,90) and rec.get('origin')=='upgrade-completed','leftover with nothing chosen is completed (rc=%s %s%s)'%(r.returncode,r.stdout,r.stderr))
check(shield_ok(d),'Shield, popups, notices and the App Store switch are on; the other-apps switch is off')
check((plist(D(d,'State.plist')) or {}).get('enabled') is True and (plist(D(d,'State.plist')) or {}).get('mode')=='Default','protection is on in Default mode')
check((plist(D(d,'Updates.plist')) or {}).get('automatic') is True and (plist(D(d,'Updates.plist')) or {}).get('revision')=='old','automatic updates are on and the rest of the update record is kept')
s2=snap(d);r=H(['initdefaults'],d);check(r.returncode==0 and snap(d)==s2,'a second run changes nothing')
# C3. a recorded install (baseline already applied) is never re-completed, even with keys missing
d=fresh();assert H(['initdefaults'],d).returncode==0 and plist(D(d,'Defaults.plist')),'fixture: baseline recorded'
P(d,'net.myxxdev.mybloxx.safariguard.plist').write_bytes(plistlib.dumps({'Enabled':True,'Blocked':[],'Allowed':[],'URLs':[]}));before=snap(d)
r=H(['initdefaults'],d);check(r.returncode==0 and snap(d)==before,'an install with a baseline record is left exactly as the user has it')
# ---- D. Restore Default Settings: complete baseline, backups preserved, runtime and saved state agree
d=installed();blocked=verdict(d)
files=Path(d)/'Files/MYbloXX';files.mkdir(parents=True,exist_ok=True)
(files/'MYbloXX-Settings.plist').write_bytes(plistlib.dumps({'format':'user-saved','marker':'PRECIOUS'}));(files/'My own backup.plist').write_bytes(b'user file')
check(H(['proxy','http://secret-proxy.invalid:8080'],d).returncode==0,'fixture: a Proxy Override is active')
P(d,'net.myxxdev.mybloxx.safariguard.plist').write_bytes(plistlib.dumps({'Enabled':False,'BlockPopups':False,'ShowBlocked':False,'PopupMode':'standard','Blocked':['mine.example'],'Allowed':['ok.example'],'URLs':[],'RedirectEnabled':False,'RedirectOtherApps':False,'RedirectAskAppStore':False,'RedirectAskOtherApps':True}))
D(d,'Updates.plist').write_bytes(plistlib.dumps({'automatic':False}));D(d,'ShieldActivity.plist').write_bytes(plistlib.dumps({'items':[{'x':1}]}))
H(['mode','blockApple'],d) # the user also changed the blocking mode
r=H(['restoredefaults'],d)
check(r.returncode==0,f'restoredefaults exits 0 (got {r.returncode}: {r.stdout}{r.stderr})')
st=plist(D(d,'State.plist')) or {};check(st.get('enabled') is True and st.get('mode')=='Default','baseline: protection on, Default mode')
check(shield_ok(d),'baseline: Shield defaults restored, custom Shield rules cleared')
check((plist(D(d,'Updates.plist')) or {}).get('automatic') is True,'baseline: Automatic Updates on')
check(not (D(d,'PAC')/'Custom.pac').exists() and not (D(d,'PACCurrent')/'Custom.pac').exists(),'custom PAC / Proxy Override PAC removed')
check('MYB2-proxy' not in (plist(P(d,'net.myxxdev.mybloxx.user.plist')) or {}),'Proxy Override setting cleared')
check(not D(d,'ShieldActivity.plist').exists(),'user-facing activity cleared')
check(verdict(d)==blocked and 'secret-proxy' not in log(d),'runtime matches the saved baseline and logs no proxy address')
arch=sorted((files/'Backups').glob('MYbloXX-Settings before Restore Defaults *.plist')) if (files/'Backups').exists() else []
check(len(arch)==1 and b'PRECIOUS' in arch[0].read_bytes(),'the existing saved backup was archived before anything replaced it')
check((files/'My own backup.plist').read_bytes()==b'user file','a user-created file in the backup folder is untouched')
check(plist(D(d,'Defaults.plist')).get('origin')=='reset','reset recorded')
# ---- E. failed reset keeps previous settings and runtime
d=installed();P(d,'net.myxxdev.mybloxx.safariguard.plist').write_bytes(plistlib.dumps({'Enabled':True,'BlockPopups':False,'Blocked':['mine.example'],'Allowed':[],'URLs':[]}))
before=snap(d);v=verdict(d);r=H(['restoredefaults'],d,{'MYB_TEST_RESTART_RESULT':'69'})
check(r.returncode!=0,f'a failing runtime refresh is not reported as success (exit {r.returncode})')
check(snap(d)==before and verdict(d)==v,'failure rolled back: saved files and live PAC are exactly as before')
check((plist(P(d,'net.myxxdev.mybloxx.safariguard.plist')) or {}).get('BlockPopups') is False,'user choice survived the failed reset')
# ---- F. another proxy configuration present: everything else is still applied, protection is not forced on
d=fresh();Path(d,'Managed/com.apple.SystemConfiguration.plist').write_bytes(plistlib.dumps({'Proxies':{'ProxyAutoConfigEnable':1,'ProxyAutoConfigURLString':'http://other.example/x.pac'}}))
r=H(['initdefaults'],d);rec=plist(D(d,'Defaults.plist')) or {}
check(r.returncode==90 and rec.get('exceptions')==['protection-left-off'] and rec.get('outcome')=='partial' and shield_ok(d),f'foreign proxy: defaults applied, protection left off ({rec})')
check(Path(d,'Managed/com.apple.SystemConfiguration.plist').read_bytes().count(b'other.example')==1,'the other configuration was not overwritten')
# ---- G. Proxy Override: validation, apply, rollback, return to filtering, no address in the log
d=installed();blocked=verdict(d);before=snap(d)
for bad in ['https://proxy.example:8080','http://u:p@proxy.example:8080','http://proxy.example:0','http://proxy.example:70000','http://proxy.example:8080/path','http://:8080','http://proxy.example:8080?x=1','proxy.example:8080','']:
    r=H(['proxy',bad],d);check(r.returncode!=0 and snap(d)==before,f'invalid override {bad!r} refused, nothing changed (exit {r.returncode})')
check(H(['proxy','http://secret-proxy.invalid:8080'],d).returncode==0,'valid override applied')
check(verdict(d)=='PROXY secret-proxy.invalid:8080','the override is the live PAC (all traffic through the proxy, no MYbloXX rules)')
check('secret-proxy' not in log(d),'the proxy address is not written to the log')
check(H(['selectmode','Default'],d).returncode==0 and verdict(d)==blocked,'Return to MYbloXX Filtering restores the normal rules')
d2=installed();foreign=Path(d2,'Managed/com.apple.SystemConfiguration.plist');foreign.unlink()  # it is a symlink to MYbloXX's PAC; replace it, do not write through it
foreign.write_bytes(plistlib.dumps({'Proxies':{'ProxyAutoConfigEnable':1,'ProxyAutoConfigURLString':'http://other.example/x.pac'}}))
b2=snap(d2)
r=H(['proxy','http://secret-proxy.invalid:8080'],d2);check(r.returncode==3 and snap(d2)==b2,f'foreign configuration: refused (3), saved state unchanged (exit {r.returncode})')

# ---- H. review findings 1-3: the baseline states every component; partial and failed resets are reported as what they are
CC=lambda root:(Path(root)/'jb/Library/ControlCenter/Bundles/MYbloXXCC2.bundle').exists()
# 1. components are part of the baseline: a reset puts the Control Centre module back even if the user turned them off
d=installed();check(H(['ccmodule','off'],d).returncode==0 and not CC(d),'fixture: Control Centre module turned off')
check(H(['component','YouTopia','off'],d).returncode!=0,'the retired component action is no longer accepted')
r=H(['restoredefaults'],d);rec=plist(D(d,'Defaults.plist')) or {}
check(r.returncode==0 and CC(d),f'Restore Defaults restores the Control Centre module (exit {r.returncode}, CC {CC(d)})')
check(rec.get('outcome')=='complete' and not rec.get('exceptions'),f'a clean reset is recorded as complete ({rec})')
# 2. another proxy owns the configuration: everything else is applied, protection is NOT forced, and the result is PARTIAL
d=installed();foreign=Path(d,'Managed/com.apple.SystemConfiguration.plist');foreign.unlink()
foreign.write_bytes(plistlib.dumps({'Proxies':{'ProxyAutoConfigEnable':1,'ProxyAutoConfigURLString':'http://other.example/x.pac'}}))
P(d,'net.myxxdev.mybloxx.safariguard.plist').write_bytes(plistlib.dumps({'Enabled':False,'BlockPopups':False,'ShowBlocked':False,'PopupMode':'standard','Blocked':['mine.example'],'Allowed':[],'URLs':[]}))
foreign_bytes=foreign.read_bytes();r=H(['restoredefaults'],d);rec=plist(D(d,'Defaults.plist')) or {}
check(r.returncode==90,f'foreign proxy: reset reports the PARTIAL outcome (90), not success (exit {r.returncode}: {r.stdout}{r.stderr})')
check(rec.get('outcome')=='partial' and 'protection-left-off' in (rec.get('exceptions') or []),f'the partial outcome and its reason are recorded ({rec})')
check(foreign.read_bytes()==foreign_bytes,'the other proxy configuration is byte-for-byte untouched')
check(shield_ok(d),'the rest of the baseline (Shield) was applied')
check((plist(D(d,'State.plist')) or {}).get('enabled') is False,'protection is saved as off, truthfully')
# 3. components missing on this device: also partial, named
d=tempfile.mkdtemp(prefix='mybdef-');assert H(['--init'],d,{'MYB_TEST_NO_CC':'1'}).returncode==0
r=H(['restoredefaults'],d);rec=plist(D(d,'Defaults.plist')) or {}
check(r.returncode==90 and 'controlcenter-unavailable' in (rec.get('exceptions') or []),f'missing Control Centre module: partial with the reason named (exit {r.returncode}, {rec})')
# 4. verification fails AFTER the baseline was committed: rolled back, and the user's history is kept
d=installed();H(['selectmode','blockApple'],d);P(d,'net.myxxdev.mybloxx.safariguard.plist').write_bytes(plistlib.dumps({'Enabled':True,'BlockPopups':False,'ShowBlocked':True,'PopupMode':'standard','Blocked':['mine.example'],'Allowed':[],'URLs':[]}))
D(d,'ShieldActivity.plist').write_bytes(plistlib.dumps({'items':[{'x':1}]}));before=snap(d);v=verdict(d)
r=H(['restoredefaults'],d,{'MYB_TEST_FORCE_DISAGREE':'1'});rec=plist(D(d,'Defaults.plist')) or {}
check(r.returncode==91,f'post-commit verification failure rolls back and says so (91), exit {r.returncode}')
check(verdict(d)==v and (plist(D(d,'State.plist')) or {}).get('mode')=='blockApple','the previous mode and live PAC are back')
check((plist(P(d,'net.myxxdev.mybloxx.safariguard.plist')) or {}).get('BlockPopups') is False,'the user\'s Shield choices are back')
check(D(d,'ShieldActivity.plist').exists(),'recent activity was not cleared by a reset that did not hold')
check(rec.get('outcome')=='rolled-back',f'outcome recorded as rolled back ({rec})')
# 5. ...and when the rollback itself fails the state is declared MIXED, never "unchanged"
d=installed();r=H(['restoredefaults'],d,{'MYB_TEST_FORCE_DISAGREE':'1','MYB_TEST_ROLLBACK_FAIL':'1'});rec=plist(D(d,'Defaults.plist')) or {}
check(r.returncode==92 and rec.get('outcome')=='mixed',f'failed rollback is reported as mixed (92), not as unchanged (exit {r.returncode}, {rec})')
# 6. a fresh install with a foreign proxy exits 90 too and says what was skipped
d=fresh();Path(d,'Managed/com.apple.SystemConfiguration.plist').write_bytes(plistlib.dumps({'Proxies':{'ProxyAutoConfigEnable':1,'ProxyAutoConfigURLString':'http://other.example/x.pac'}}))
r=H(['initdefaults'],d);check(r.returncode==90 and 'protection' in r.stdout.lower(),f'first install with a foreign proxy: partial, and the installer output says so ({r.returncode}: {r.stdout})')
# 7. Proxy Override: a failed configd restart AFTER apply is undone and reported accurately
d=installed();blocked=verdict(d);b=snap(d)
r=H(['proxy','http://secret-proxy.invalid:8080'],d,{'MYB_TEST_RESTART_RESULT':'69'})
check(r.returncode==69,f'failed restart after apply is an error, not success (exit {r.returncode})')
check(verdict(d)==blocked,'the previous working PAC is back after the failed override')
check(not D(d,'PAC/Custom.pac').exists() or (plist(D(d,'State.plist')) or {}).get('mode')!='Custom','the override is not left selected')
check('secret-proxy' not in log(d),'the proxy address is still not logged')
check('previous configuration was restored' in log(d),'the log says the previous configuration was restored')
if fails:print(len(fails),'defaults/reset/proxy check(s) FAILED');sys.exit(1)
print('Defaults, upgrade preservation, Restore Default Settings and Proxy Override checks passed.')
