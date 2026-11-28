"""Blocked page -> authenticated request -> REAL helper process (real argv/argc) -> exception transaction ->
inline-PAC apply -> result -> retry. usage: website-allow-e2e.py <blockd test binary> <helper process binary> <pacs dir>
Everything between the HTTP request and the effective PAC is shipping code: the bridge spawns the helper with the
same argument builder it uses in production; the helper is the real entry point run as a process (fixture root,
injected configd restart result). The 'retry' is evaluating the live effective PAC for the original host."""
import json,os,re,socket,subprocess,sys,tempfile,time
from pathlib import Path
blockd,helper,pacs=sys.argv[1:4]
DOMAIN='100widgets.com'
fails=[]
def check(ok,msg):
    if not ok:fails.append(msg);print('FAIL:',msg)
def H(args,root,extra=None,expect=None):
    env=dict(os.environ,MYB_FIXTURE_ROOT=root,MYB_TEST_PACS=pacs);env.update(extra or {})
    r=subprocess.run([helper]+args,env=env,capture_output=True,text=True,timeout=60);return r
def fresh():
    d=tempfile.mkdtemp(prefix='mybe2e-');r=H(['--init'],d);assert r.returncode==0,r.stdout+r.stderr;return d
def verdict(root,host=DOMAIN):return H(['--verdict',host],root).stdout.strip()
def snap(root):return H(['--snapshot'],root).stdout.strip()
def web(root):return H(['--websites'],root).stdout.strip()
def http(method,target,host,headers='',port=18021,expected=None):
    with socket.create_connection(('127.0.0.1',port),3) as s:
        s.sendall(f'{method} {target} HTTP/1.1\r\nHost: {host}\r\n{headers}\r\n'.encode());s.shutdown(socket.SHUT_WR);data=b''
        while True:
            b=s.recv(65536)
            if not b:break
            data+=b
    head,_,body=data.partition(b'\r\n\r\n');code=int(head.split(b' ')[1])
    if expected is not None and code!=expected:raise AssertionError(f'{method} {target}: {code} != {expected}')
    return code,body
def serve(root,extra=None):
    env=dict(os.environ,MYB_FIXTURE_ROOT=root,MYB_TEST_HELPER=helper,MYB_TEST_PACS=pacs);env.update(extra or {})
    p=subprocess.Popen([blockd],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    for _ in range(100):
        try:socket.create_connection(('127.0.0.1',18788),.1).close();return p
        except OSError:time.sleep(.05)
    p.terminate();raise AssertionError('bridge did not start')
def allow_through_page(root,duration,extra=None):
    p=serve(root,extra)
    try:
        _,page=http('GET',f'http://{DOMAIN}/x?a=1',DOMAIN,'Accept: text/html\r\n',expected=200)
        ticket=re.search(rb'mybloxx-allow\?request=([a-f0-9]{64})',page).group(1).decode()
        _,conf=http('GET','/mybloxx-allow?request='+ticket,'127.0.0.1:18021',expected=200)
        secret=re.search(rb'data-secret="([a-f0-9]{64})"',conf).group(1).decode()
        good=f'Origin: http://127.0.0.1:18021\r\nX-MYbloXX-Allow-Token: {secret}\r\nX-MYbloXX-Allow-Duration: {duration}\r\n'
        http('POST','/mybloxx-allow-apply','127.0.0.1:18021',good,expected=202)
        result={}
        for _ in range(300):
            _,body=http('GET','/mybloxx-allow-status','127.0.0.1:18021',f'X-MYbloXX-Allow-Token: {secret}\r\n',expected=200);result=json.loads(body)
            if result['phase'] in('success','error'):break
            time.sleep(.1)
        return result
    finally:
        p.terminate();p.wait(timeout=5)
# ---------------- 1. through the blocked page: 2 minutes, 15 minutes, always ----------------
for duration,tmp,perm in (('once',1,0),('temp',1,0),('always',0,1)):
    root=fresh();check(verdict(root).startswith('PROXY'),f'{duration}: host is blocked before the exception')
    result=allow_through_page(root,duration)
    check(result.get('phase')=='success' and result.get('code')==0,f'{duration}: helper process succeeded through the page ({result})')
    check(result.get('url')==f'http://{DOMAIN}/x?a=1','original GET URL preserved for the retry')
    check(not verdict(root).startswith('PROXY'),f'{duration}: after success the retry is allowed by the live effective PAC')
    check(web(root)==f'domains={perm} temp={tmp}',f'{duration}: stored as {"permanent" if perm else "temporary"} ({web(root)})')
    if duration!='always':
        check(H(['revokewebsite',DOMAIN],root).returncode==0 and verdict(root).startswith('PROXY'),f'{duration}: revoke restores blocking')
# ---------------- 2. failure through the page: previous state kept, code surfaced ----------------
root=fresh();before=snap(root)
result=allow_through_page(root,'temp',{'MYB_TEST_RESTART_RESULT':'69'})
check(result.get('phase')=='error' and result.get('code')==69,f'failure reports the helper error code 69 ({result})')
check(snap(root)==before and verdict(root).startswith('PROXY'),'failed apply leaves every file and the live PAC as they were')
# ---------------- 3. the helper as a process: valid and malformed argv ----------------
root=fresh()
def rc(args,extra=None):return H(args,root,extra).returncode
check(rc(['allowwebsite',DOMAIN,'Default','once'])==0,'argc=5 once is accepted by the real entry point')
check(rc(['revokewebsite',DOMAIN])==0,'revoke')
check(rc(['allowwebsite',DOMAIN,'Default','temp'])==0,'argc=5 temp (15 minutes) accepted')
check(rc(['revokewebsite',DOMAIN])==0,'revoke')
check(rc(['allowwebsite',DOMAIN,'Default','always'])==0,'argc=5 always accepted')
check(rc(['revokewebsite',DOMAIN])==0,'revoke permanent')
check(rc(['allowwebsite',DOMAIN,'Default'])==0,'legacy argc=4 invocation (no duration) still works')
check(rc(['revokewebsite',DOMAIN])==0,'revoke legacy')
check(rc(['status'])==0 and rc(['diagnose'])==0,'status and diagnose run through the real entry point')
import plistlib
rs=Path(root)/'var/mobile/Library/MYbloXX/RuntimeStatus.plist'
check(rc(['statuspublish'])==0,'statuspublish (read-only verification request from Settings) is accepted')
try:
    rec=plistlib.loads(rs.read_bytes())
    check(rec.get('state')=='configured' and rec.get('verification') in('applied','identity-unavailable','stale','not-applied') and 'verifiedAt' in rec and 'time' in rec,f'RuntimeStatus.plist is published with a verification result ({rec.get("state")}/{rec.get("verification")})')
    check(oct(rs.stat().st_mode&0o777)=='0o644','the published record is world-readable for the sandboxed reader')
except Exception as e:
    check(False,f'RuntimeStatus.plist unreadable after statuspublish: {e}')
before=snap(root)
big='a'*64+'.com'
bad=[[],['bogus'],['allowwebsite'],['allowwebsite',DOMAIN],['allowwebsite',DOMAIN,'Default','once','extra'],['allowwebsite',DOMAIN,'Default','once','extra','more'],
 ['allowwebsite','Example.COM','Default','once'],['allowwebsite','nodot','Default','once'],['allowwebsite','a b.com','Default','once'],['allowwebsite','../x.com','Default','once'],
 ['allowwebsite','a..com','Default','once'],['allowwebsite','-a.com','Default','once'],['allowwebsite',big,'Default','once'],['allowwebsite','x'*250+'.com','Default','once'],
 ['allowwebsite',DOMAIN,'NoSuchMode','once'],['allowwebsite',DOMAIN,'../Default','once'],['allowwebsite',DOMAIN,'Default','forever'],['allowwebsite',DOMAIN,'Default','900'],['allowwebsite',DOMAIN,'Default',''],
 ['revokewebsite'],['revokewebsite',DOMAIN,'x'],['revokewebsite','not a domain'],['status','extra'],['mode'],['mode','Default','x'],['mode','NoSuchMode'],['enable','x'],
 ['updatepolicy','maybe'],['updatepolicy'],['component','Anything'],['pruneexpired','x'],['mode','Default','x','y']]
for args in bad:check(rc(args)==64,f'malformed invocation refused with 64: {args[:2]}...{len(args)}')
check(snap(root)==before,'refused invocations changed nothing')
# a refusal explains itself without echoing the value
r=H(['allowwebsite','a b.com','Default','once'],root)
log=(Path(root)/'var/mobile/Library/MYbloXX').rglob('*.log')
text=''.join(p.read_text(errors='ignore') for p in log)
check('a b.com' not in text,'diagnostics never echo the rejected domain')
print('Website Allow end-to-end checks '+('FAILED' if fails else 'passed'));sys.exit(1 if fails else 0)
