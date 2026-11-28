"""noXXX PIN, end to end, against the SHIPPING code: the real helper entry point run as a process (real argv, real stdin, real exit
status, a fresh process for every call so "service restart" means exactly that) and the real blocked-page server.
usage: pin-e2e.py <blockd test binary> <helper process binary> <pacs dir>
What this exercises: Helper/MYXXdev.m dispatcher guards, Helper/MYBPin.inc, Shared/MYBPin.h, BlockedServer/WebsiteActions.h and the
shipped blocked page. Clocks are set per process through a test-only seam (compiled only into the test binary).
What it does NOT prove: anything about a real iPhone (Settings UI, the PIN prompt on screen, Control Centre, iOS honouring the PAC)."""
import json,os,plistlib,re,socket,subprocess,sys,tempfile,time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
blockd,helper,pacs=sys.argv[1:4]
PIN='5821';WRONG='7391';HOST='stripchat.com';ORDINARY='100widgets.com'
T0=1_800_000_000;M0=50_000
fails=[];passed=[0]
def check(ok,msg):
    if ok:passed[0]+=1
    else:fails.append(msg);print('FAIL:',msg)
def R(root,args,inp=None,t=0,boot='boot-A',extra=None,wall=None):
    env=dict(os.environ,MYB_FIXTURE_ROOT=root,MYB_TEST_PACS=pacs,MYB_TEST_WALL=str((wall if wall is not None else T0)+t),MYB_TEST_MONO=str(M0+t),MYB_TEST_BOOT=boot,MYB_TEST_NO_SLEEP='1')
    env.update(extra or {})
    return subprocess.run([helper]+args,env=env,input=(inp+'\n') if inp is not None else '',capture_output=True,text=True,timeout=90)
def rc(root,args,inp=None,**kw):return R(root,args,inp,**kw).returncode
def verdict(root,host=HOST):return R(root,['--verdict',host]).stdout.strip()
def blocked(root,host=HOST):return verdict(root,host).startswith('PROXY')
def snap(root):return R(root,['--snapshot']).stdout.strip()
def web(root):return R(root,['--websites']).stdout.strip()
def fresh(mode='blockXXX'):
    d=tempfile.mkdtemp(prefix='mybpin-');r=R(d,['--init']);assert r.returncode==0,r.stdout+r.stderr
    if mode!='Default':
        r=R(d,['mode',mode]);assert r.returncode==0,r.stdout+r.stderr
    return d
def protected(pin=PIN):
    d=fresh();r=R(d,['pinset'],pin);assert r.returncode==0,r.stdout+r.stderr;return d
def intact(root,before,msg):
    check(snap(root)==before and blocked(root),msg+' (nothing changed, noXXX still blocks)')
def status_line(root):return R(root,['status']).stdout.strip()
# ---------------------------------------------------------------------------------------------------------------------
# 0. the fixture itself: noXXX blocks the test host, plain Default does not; an ordinary ad host is blocked by both
r=fresh();check(blocked(r),'fixture: noXXX blocks '+HOST);check(blocked(r,ORDINARY),'fixture: noXXX still blocks an ordinary ad host')
d=fresh('Default');check(not blocked(d),'fixture: Default alone does not block '+HOST+' (so the PIN has something to protect)')
# ---------------------------------------------------------------------------------------------------------------------
# 1. correct and incorrect four-digit PINs, leading zeroes, no PIN in argv
d=fresh();check(rc(d,['pinstatus'])==0 and 'enabled=0' in R(d,['pinstatus']).stdout,'no PIN set yet')
check(rc(d,['pinset'],'0042')==0,'a PIN with leading zeroes can be set')
check('enabled=1' in R(d,['pinstatus']).stdout,'status reports the PIN as enabled')
check(rc(d,['pinauth','mode'],'0042')==0,'the correct PIN, leading zeroes kept, is accepted')
for bad,code,why in (('42',92,'two digits'),('00420',92,'five digits'),('abcd',92,'letters'),('12 4',92,'a space'),('',92,'empty'),('0043',90,'wrong digits'),('4200',90,'zeroes moved'),('0420',90,'zero dropped')):
    # each case on its own record: three well-formed wrong PINs in a row legitimately lock the PIN, which would mask the next case
    dd=protected('0042');check(rc(dd,['pinauth','mode'],bad)==code,f'{why} is refused with {code}')
check(rc(d,['pinset','1234'])==64 and rc(d,['pinauth','1234'])==64 and rc(d,['pinauth','mode','1234'])==64,'a PIN can never be given as an argument (refused as malformed)')
check(rc(d,['pinset'],'0042\n7777')==0,'changing the PIN needs the current one and the new one')
check(rc(d,['pinauth','mode'],'0042')==90 and rc(d,['pinauth','mode'],'7777')==0,'after a change only the new PIN works')
check(rc(d,['pinset'],'1111\n2222')==90 and rc(d,['pinauth','mode'],'7777')==0,'a change with the wrong current PIN is refused and keeps the old PIN')
check(rc(d,['pinremove'],'0000')==90 and 'enabled=1' in R(d,['pinstatus']).stdout,'removal with a wrong PIN is refused')
check(rc(d,['pinremove'],'7777')==0 and 'enabled=0' in R(d,['pinstatus']).stdout,'removal with the right PIN works')
check(rc(d,['mode','Default'])==0,'with no PIN set nothing is guarded')
check(rc(fresh('Default'),['pinremove'],'1234')==93,'removing a PIN that is not set says so (93)')
# ---------------------------------------------------------------------------------------------------------------------
# 2. no credential material anywhere but the root-only record (logs, status, backups, exports)
d=protected()
rc(d,['pinauth','mode'],WRONG);rc(d,['pinauth','mode'],PIN)
rc(d,['backupfiles'],extra={'MYB_TEST_FILES':'1'});rc(d,['syncfiles'],extra={'MYB_TEST_FILES':'1'});rc(d,['statuspublish'])
prot=Path(d)/'var/mobile/Library/MYbloXX/Protected';rec=plistlib.loads((prot/'NoXXXPin.plist').read_bytes())
secrets=[bytes(rec['verifier']),bytes(rec['salt']),(prot/'DeviceSecret').read_bytes()]
leak=[];pin_re=re.compile(rb'(?<![0-9])'+PIN.encode()+rb'(?![0-9])')
for p in Path(d).rglob('*'):
    if not p.is_file() or prot in p.parents:continue
    data=p.read_bytes()
    if any(s in data for s in secrets):leak.append(('secret',str(p)))
    if p.suffix in('.log','.txt','.json') and pin_re.search(data):leak.append(('pin',str(p)))
    if p.suffix=='.plist' and p.parent.name!='Protected':
        try:txt=json.dumps(plistlib.loads(data),default=lambda o:'<data>' if isinstance(o,bytes) else str(o))
        except Exception:txt=''
        if pin_re.search(txt.encode()):leak.append(('pin-plist',str(p)))
check(not leak,f'no verifier, salt, device secret or PIN outside the root-only folder (logs, state, backups, exports): {leak}')
pub=plistlib.loads((Path(d)/'var/mobile/Library/MYbloXX/PinState.plist').read_bytes())
check(set(pub)<={'enabled','lockedFor','updated'},f'the one readable status file carries only enabled/lockedFor/updated: {sorted(pub)}')
logs=''.join(p.read_text(errors='ignore') for p in (Path(d)/'var/mobile/Library/MYbloXX').rglob('*.log'))
check('PIN: attempt refused (wrong)' in logs and PIN not in logs and WRONG not in logs,'the log records that a PIN attempt failed, never the PIN')
# ---------------------------------------------------------------------------------------------------------------------
# 3. persistent throttling across service restarts (every call below is a new process), reboot and clock changes
d=protected()
check(rc(d,['pinauth','mode'],WRONG)==90 and rc(d,['pinauth','mode'],'0001')==90,'two wrong PINs are only wrong')
r=R(d,['pinauth','mode'],'0002');check(r.returncode==91 and 'locked=30' in r.stdout,'the third wrong PIN locks for 30 seconds (new process each time)')
check(rc(d,['pinauth','mode'],PIN,t=5)==91,'the right PIN is refused while locked, in a later process')
check(R(d,['pinstatus'],t=5).stdout.count('locked=')==1 and int(re.search(r'locked=(\d+)',R(d,['pinstatus'],t=5).stdout).group(1))>0,'the lock is visible in status')
check(rc(d,['pinauth','mode'],PIN,t=31)==0,'after the wait the right PIN opens')
check(rc(d,['pinauth','mode'],WRONG,t=32)==90,'a success resets the count: the next wrong PIN is only wrong again')
d=protected();[rc(d,['pinauth','mode'],f'000{i}') for i in range(3)]  # locked 30 s from T0
check(rc(d,['pinauth','mode'],PIN,t=9,wall=T0+99999)==91,'moving the wall clock forward inside one boot does not shorten a lock (monotonic clock wins)')
check(rc(d,['pinauth','mode'],PIN,t=10,boot='boot-B',wall=T0+10)==91,'after a reboot the wall-clock deadline still holds')
check(rc(d,['pinauth','mode'],PIN,t=61,boot='boot-B',wall=T0+61)==0,'and after the deadline the PIN works again')
d=protected();[rc(d,['pinauth','mode'],f'000{i}') for i in range(3)];rc(d,['pinauth','mode'],'0003',t=31);rc(d,['pinauth','mode'],'0004',t=92)  # 4th wrong at 31 s: 60 s lock (to 91 s); 5th wrong at 92 s: 300 s lock (to 392 s)
check(rc(d,['pinauth','mode'],PIN,t=100)==91,'the delay grows with every further failure')
# ---------------------------------------------------------------------------------------------------------------------
# 4. concurrent attempts: processes racing for the one operation lock
def burst(root,jobs):
    with ThreadPoolExecutor(len(jobs)) as pool:
        futures=[pool.submit(lambda j=j:R(root,j[0],j[1]).returncode) for j in jobs];return [f.result() for f in futures]
d=protected();codes=burst(d,[(['pinauth','mode'],'9999')]*14)
check(set(codes)<={90,91,75},f'concurrent wrong attempts only ever end as wrong, locked or busy: {sorted(set(codes))}')
check(codes.count(90)<=2,f'no more than two wrong attempts are ever counted before the lock, however they race ({codes.count(90)})')
check(any(c in(90,91) for c in codes),'at least one attempt really ran')
if 91 in codes:check(rc(d,['pinauth','mode'],PIN)==91,'after a race the lock holds and the right PIN is still refused')
check(0 not in codes,'a wrong-PIN flood never produces a success')
d=protected();rc(d,['pinauth','mode'],'0000');rc(d,['pinauth','mode'],'0001')
codes=burst(d,[(['pinauth','mode'],PIN)]*1+[(['pinauth','mode'],'1111')]*8)
check(codes.count(0)<=1,'a correct PIN racing wrong ones succeeds at most once')
# ---------------------------------------------------------------------------------------------------------------------
# 5. approvals: expired, replayed, wrong target, wrong operation, wrong boot; atomic single use
def allow_rule(root,host,**kw):return rc(root,['localcustom','',host],**kw)
d=protected();check(rc(d,['pinauth','rules'],PIN)==0 and allow_rule(d,HOST,t=119)==0 and not blocked(d),'a fresh approval lets the guarded change through')
d=protected();rc(d,['pinauth','rules'],PIN);b=snap(d);check(allow_rule(d,HOST,t=121)==90,'an expired approval (121 s) is refused');intact(d,b,'expired')
d=protected();rc(d,['pinauth','rules'],PIN);check(allow_rule(d,HOST)==0,'first use of an approval works')
b=snap(d);check(allow_rule(d,'chat4meets.com')==90,'a replayed approval is refused');check(snap(d)==b,'replay changed nothing')
d=protected();rc(d,['pinauth',f'allow:{HOST}'],PIN);b=snap(d)
check(rc(d,['allowwebsite','strpst.com','blockXXX','once'])==90,'an approval for one site does not open another');intact(d,b,'wrong target')
check(rc(d,['allowwebsite','www.'+HOST,'blockXXX','once'])==90,'an approval for a site does not cover its subdomain');intact(d,b,'subdomain')
check(rc(d,['allowwebsite',HOST,'blockXXX','once'])==0 and not blocked(d),'the approved site itself opens')
d=protected();rc(d,['pinauth','mode'],PIN);b=snap(d)
for args in (['disable'],['restoredefaults'],['localcustom','',HOST],['proxy','http://127.0.0.1:8888'],['allowwebsite',HOST,'blockXXX','once']):
    check(rc(d,args)==90,f'a mode approval does not authorise {args[0]}')
intact(d,b,'wrong operation')
check(rc(d,['mode','Default'])==0,'the mode approval authorises the mode change it was made for')
check(rc(d,['mode','blockXXX'])==0 and blocked(d),'moving back to noXXX never needs a PIN')
d=protected();rc(d,['pinauth','mode'],PIN);b=snap(d);check(rc(d,['mode','Default'],boot='boot-B')==90,'an approval does not survive a reboot');intact(d,b,'reboot')
d=protected();rc(d,['pinauth','disable'],PIN);check(rc(d,['mode','Default'])==90,'a disable approval cannot change the mode')
# Legacy Mode: with ANY PIN set the helper itself refuses to prepare a standalone profile (it would bypass noXXX), in every mode
for startMode in ('blockXXX','Default'):
    d=fresh(startMode);rc(d,['pinset'],PIN);b=snap(d)
    check(rc(d,['legacyprepare'])==90,f'legacyprepare is refused without approval when a PIN is set ({startMode})')
    check(snap(d)==b and (blocked(d) or startMode=='Default'),'legacyprepare refusal (nothing changed'+(', noXXX still blocks)' if startMode=='blockXXX' else ')'))
    check(rc(d,['pinauth','mode'],PIN)==0 and rc(d,['legacyprepare'])==90,f'a mode approval does not authorise legacyprepare ({startMode})')
    check(rc(d,['pinauth','disable'],PIN)==0 and rc(d,['legacyprepare'])==0,f'a one-use disable approval authorises legacyprepare ({startMode})')
    check(rc(d,['enable'])==0 and rc(d,['legacyprepare'])==90,f'the approval was single use ({startMode})')
d=fresh();check(rc(d,['legacyprepare'])==0,'without a PIN legacyprepare simply turns native protection off')
# atomic single use: eight processes race for one approval
d=protected();rc(d,['pinauth','rules'],PIN)
codes=burst(d,[(['localcustom','',HOST],None)]*8)
check(codes.count(0)==1 and set(codes)<={0,90,75},f'exactly one of eight racing uses consumes a single-use approval: {sorted(codes)}')
d=protected();rc(d,['pinauth',f'allow:{HOST}'],PIN)
codes=burst(d,[(['allowwebsite',HOST,'blockXXX','once'],None)]*8)
check(codes.count(0)==1 and set(codes)<={0,90,75},f'the same holds for a site approval: {sorted(codes)}')
# ---------------------------------------------------------------------------------------------------------------------
# 6. every bypass attempt without a PIN is refused and changes nothing
d=protected();before=snap(d);line=status_line(d)
attempts=[('master toggle off',['disable']),('Control Centre off (it runs the same helper action)',['disable']),('select another mode',['mode','Default']),
 ('select another mode, offline',['selectmode','Default']),('drop noXXX but keep another option',['mode','blockApple']),
 ('Proxy Override',['proxy','http://127.0.0.1:8888']),('restore a backup',['restorebackup']),('restore an imported backup',['restoreimport']),('reset to defaults',['restoredefaults']),
 ('Allow rule for a noXXX site',['localcustom','',HOST]),('Allow rule for a noXXX subdomain',['localcustom','','www.'+HOST]),('Allow rule for noXXX infrastructure',['localcustom','','assets.strpst.com']),
 ('exception for a noXXX site (2 minutes)',['allowwebsite',HOST,'blockXXX','once']),('exception for a noXXX site (15 minutes)',['allowwebsite',HOST,'blockXXX','temp']),
 ('exception for a noXXX site (always)',['allowwebsite',HOST,'blockXXX','always']),('exception for noXXX infrastructure',['allowwebsite','assets.strpst.com','blockXXX','once'])]
for name,args in attempts:
    check(rc(d,args)==90,f'bypass attempt refused: {name}');intact(d,before,name)
check(status_line(d)==line,'the saved mode and on/off state are exactly as before every attempt')
# App Control: the pause would drop noXXX without a PIN, so with a PIN it does not pause; without a PIN it does (control case)
prefs=lambda root:Path(root)/'var/mobile/Library/Preferences/net.myxxdev.mybloxx.speedyads.plist'
d=protected();prefs(d).write_bytes(plistlib.dumps({'enabled-com.example.app':True}));b=snap(d)
check(rc(d,['appfocus','com.example.app'])==0 and blocked(d),'App Control does not pause protection while noXXX PIN protection is on')
check('active=1' in status_line(d) and 'mode=blockXXX' in status_line(d),'... and the saved mode and on/off state are untouched')
d2=fresh();prefs(d2).write_bytes(plistlib.dumps({'enabled-com.example.app':True}))
check(rc(d2,['appfocus','com.example.app'])==0 and not blocked(d2),'control case: without a PIN App Control still pauses protection for the app')
# ordinary changes are never gated
d=protected();check(rc(d,['allowwebsite',ORDINARY,'blockXXX','once'])==0 and not blocked(d,ORDINARY) and blocked(d),'an ordinary exception needs no PIN and does not open noXXX sites')
check(rc(d,['localcustom','','example.org'])==0,'an Allow rule for an ordinary site needs no PIN')
check(rc(d,['localcustom','new-bad.example',''])==0,'a Block rule needs no PIN')
check(rc(d,['mode','allowY+blockXXX'])==0 and blocked(d),'adding an option to noXXX needs no PIN')
check(rc(d,['mode','blockApple+blockXXX'])==0 and blocked(d),'changing the other options of noXXX needs no PIN')
check(rc(d,['enable'])==0 and blocked(d),'enable needs no PIN')
check(rc(d,['revokewebsite',ORDINARY])==0,'removing an exception needs no PIN')
# no PIN configured: nothing at all is gated
d=fresh();check(all(rc(d,a)==0 for a in (['mode','Default'],['mode','blockXXX'],['disable'],['enable'])),'without a PIN nothing is ever gated')
# a PIN set while protection is OFF or noXXX is not selected does not gate anything
d=fresh('Default');rc(d,['pinset'],PIN);check(rc(d,['disable'])==0 and rc(d,['mode','blockApple'])==0,'a PIN does not gate changes while noXXX is not in use')
# ---------------------------------------------------------------------------------------------------------------------
# 7. temporary noXXX access expires and blocking is restored
for dur,secs in (('once',120),('temp',900)):
    d=protected();rc(d,['pinauth',f'allow:{HOST}'],PIN)
    check(rc(d,['allowwebsite',HOST,'blockXXX',dur])==0 and not blocked(d),f'{dur}: the PIN opens the site')
    check(web(d).endswith('temp=1'),f'{dur}: stored as a temporary exception')
    rc(d,['pruneexpired'],t=secs-5);check(not blocked(d),f'{dur}: still open just before it ends')
    rc(d,['pruneexpired'],t=secs+2);check(blocked(d) and web(d)=='domains=0 temp=0',f'{dur}: blocking is restored when it ends ({web(d)})')
    check(rc(d,['allowwebsite',HOST,'blockXXX',dur],t=secs+3)==90,f'{dur}: and a new exception needs the PIN again')
d=protected();rc(d,['pinauth',f'allow:{HOST}'],PIN);rc(d,['allowwebsite',HOST,'blockXXX','once'])
rc(d,['pruneexpired'],t=10,boot='boot-B');check(blocked(d),'a reboot ends temporary access at once')
# ---------------------------------------------------------------------------------------------------------------------
# 8. protection survives recovery, repair and interrupted operations
d=protected();rc(d,['--reboot']);r=R(d,['startuprecover'],extra={'MYB_TEST_VERIFY':'applied'});check(r.returncode==0 and blocked(d),'startup recovery after a reboot restores noXXX with the PIN still set')
check('enabled=1' in R(d,['pinstatus']).stdout and rc(d,['pinauth','mode'],PIN)==0,'... and the PIN still works after recovery')
d=protected();rc(d,['pinauth','mode'],PIN);b=snap(d)  # the approval is not protection state; snapshot what the failed apply must leave alone
check(rc(d,['mode','Default'],extra={'MYB_TEST_RESTART_RESULT':'69'})!=0,'an interrupted (failed) apply reports failure')
print('DIAG interrupted apply: snapshot same=',snap(d)==b,'blocked=',blocked(d),'status=',status_line(d),'verdict=',verdict(d)) if not(snap(d)==b and blocked(d)) else None;check(snap(d)==b and blocked(d),'an interrupted apply leaves the previous protection in place');check('enabled=1' in R(d,['pinstatus']).stdout,'... and the PIN')
check(rc(d,['mode','Default'])==90,'the approval was spent by the interrupted attempt: the next try asks for the PIN again')
# ---------------------------------------------------------------------------------------------------------------------
# 9. the blocked page: one end-to-end flow, PIN only in a request header on the page's own origin
def http(method,target,host,headers='',port=18021):
    with socket.create_connection(('127.0.0.1',port),3) as s:
        s.sendall(f'{method} {target} HTTP/1.1\r\nHost: {host}\r\n{headers}\r\n'.encode());s.shutdown(socket.SHUT_WR);data=b''
        while True:
            b=s.recv(65536)
            if not b:break
            data+=b
    head,_,body=data.partition(b'\r\n\r\n');return int(head.split(b' ')[1]),body
def serve(root):
    env=dict(os.environ,MYB_FIXTURE_ROOT=root,MYB_TEST_HELPER=helper,MYB_TEST_PACS=pacs,MYB_TEST_WALL=str(T0),MYB_TEST_MONO=str(M0),MYB_TEST_BOOT='boot-A',MYB_TEST_NO_SLEEP='1')
    p=subprocess.Popen([blockd],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    for _ in range(100):
        try:socket.create_connection(('127.0.0.1',18788),.1).close();return p
        except OSError:time.sleep(.05)
    p.terminate();raise AssertionError('bridge did not start')
def page_secret(host):
    _,page=http('GET',f'http://{host}/x?a=1',host,'Accept: text/html\r\n')
    m=re.search(rb'mybloxx-allow\?request=([a-f0-9]{64})',page);assert m,'no allow link on the blocked page'
    _,conf=http('GET','/mybloxx-allow?request='+m.group(1).decode(),'127.0.0.1:18021');return re.search(rb'data-secret="([a-f0-9]{64})"',conf).group(1).decode(),conf
ORIGIN='Origin: http://127.0.0.1:18021\r\n'
def apply(secret,duration='once',pin=None,target='/mybloxx-allow-apply',host='127.0.0.1:18021',origin=ORIGIN):
    h=origin+f'X-MYbloXX-Allow-Token: {secret}\r\nX-MYbloXX-Allow-Duration: {duration}\r\n'+(f'X-MYbloXX-Allow-Pin: {pin}\r\n' if pin is not None else '')
    return http('POST',target,host,h)
def poll(secret,want=('success','error','pin')):
    for _ in range(300):
        code,body=http('GET','/mybloxx-allow-status','127.0.0.1:18021',f'X-MYbloXX-Allow-Token: {secret}\r\n')
        if code==200:
            j=json.loads(body)
            if j['phase'] in want:return j,body
        time.sleep(.1)
    return {},b''
d=protected();srv=serve(d)
try:
    secret,conf=page_secret(HOST)
    check(b'id="pinbox"' in conf and b'X-MYbloXX-Allow-Pin' in conf and b'Enter PIN to Allow' in conf,'the shipped page carries the PIN step and sends the PIN in a header')
    check(not re.search(rb'(location|href|src)[^;]{0,80}pin',conf,re.I) and b'?pin' not in conf and b'&pin' not in conf,'the page never builds a URL containing the PIN')
    b=snap(d)
    code,_=apply(secret,'once');j,body=poll(secret)
    check(code==202 and j.get('phase')=='pin' and j.get('code')==90 and 'message' not in j,f'without a PIN the page is told the site is restricted by noXXX ({j})')
    check(blocked(d) and snap(d)==b,'nothing changed without a PIN')
    code,_=apply(secret,'once',pin='0000');j,body=poll(secret)
    check(code==202 and j.get('phase')=='pin' and 'not correct' in j.get('message',''),f'a wrong PIN is refused with a plain message ({j})');check(PIN.encode() not in body,'the reply never contains a PIN')
    code,_=http('POST','/mybloxx-allow-apply?pin='+PIN,'127.0.0.1:18021',ORIGIN+f'X-MYbloXX-Allow-Token: {secret}\r\nX-MYbloXX-Allow-Duration: once\r\n')
    j,_=poll(secret);check(j.get('phase')=='pin' and blocked(d),'a PIN in the URL is ignored: it cannot authorise anything')
    check(apply(secret,'once',pin='12')[0]==403,'a malformed PIN is refused before the helper is involved')
    check(apply(secret,'once',pin='abcd')[0]==403,'a non-numeric PIN is refused')
    # foreign pages and replays cannot submit
    check(apply(secret,'once',pin=PIN,origin='Origin: http://evil.example\r\n')[0]==403,'a request from another origin is refused')
    check(apply(secret,'once',pin=PIN,origin='')[0]==403,'a request with no origin is refused')
    check(apply(secret,'once',pin=PIN,host='evil.example')[0]==403,'a request with a foreign Host is refused')
    check(apply('0'*64,'once',pin=PIN)[0]==403,'a request with an unknown token is refused')
    check(http('GET','/mybloxx-allow-apply','127.0.0.1:18021',ORIGIN+f'X-MYbloXX-Allow-Token: {secret}\r\nX-MYbloXX-Allow-Pin: {PIN}\r\n')[0]==403,'GET cannot apply')
    check(blocked(d) and snap(d)==b,'every refused request left protection untouched')
    code,_=apply(secret,'once',pin=PIN);j,body=poll(secret)
    check(code==202 and j.get('phase')=='success',f'the right PIN allows the site through the page ({j})');check(PIN.encode() not in body,'the success reply never contains a PIN')
    check(not blocked(d) and web(d).endswith('temp=1'),'the live PAC now allows the site, temporarily')
    check(apply(secret,'once',pin=PIN)[0]==409,'the same request cannot be replayed once it has succeeded')
    code,body=http('GET','/mybloxx-status','127.0.0.1:18021');txt=body.decode('utf8','ignore');js=json.loads(txt)
    check(js['status'].get('pin')=={'enabled':True},f'the status page shows only that the PIN is enabled ({js["status"].get("pin")})')
    check(PIN not in re.sub(r'\d{6,}','',txt) and 'verifier' not in txt and 'lockedFor' not in txt and 'salt' not in txt,'status carries no credential material, lock state or counts')
    rc(d,['pruneexpired'],t=121);check(blocked(d),'two minutes later the site is blocked again')
    # lockout through the page
    secret,_=page_secret(HOST)
    for i in range(3):
        apply(secret,'once',pin=f'000{i+1}');j,_=poll(secret)
    check(j.get('phase')=='pin' and 'Try again' in j.get('message',''),f'repeated wrong PINs on the page lock further tries ({j})')
    apply(secret,'once',pin=PIN);j,_=poll(secret);check(j.get('phase')=='pin' and 'Try again' in j.get('message','') and blocked(d),'the right PIN is refused while locked')
    # an ordinary site needs no PIN through the page
finally:
    srv.terminate();srv.wait(timeout=5)
d=protected();srv=serve(d)
try:
    secret,_=page_secret(ORDINARY);code,_=apply(secret,'temp');j,_=poll(secret)
    check(j.get('phase')=='success' and not blocked(d,ORDINARY),f'an ordinary site is allowed through the page with no PIN ({j})')
    code,body=http('GET','/mybloxx-status','127.0.0.1:18021');check(json.loads(body)['status'].get('pin')=={'enabled':True},'status page still shows the PIN as enabled')
finally:
    srv.terminate();srv.wait(timeout=5)
d=fresh();srv=serve(d)
try:
    code,body=http('GET','/mybloxx-status','127.0.0.1:18021');check(json.loads(body)['status'].get('pin')=={'enabled':False},'with no PIN the status page says Off')
finally:
    srv.terminate();srv.wait(timeout=5)
print(f'noXXX PIN end-to-end checks {"FAILED" if fails else "passed"} ({passed[0]} passed, {len(fails)} failed)');sys.exit(1 if fails else 0)
