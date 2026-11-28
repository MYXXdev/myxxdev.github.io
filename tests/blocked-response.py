import errno,json,socket,subprocess,time,sys,tempfile,os,plistlib,re,hashlib,base64
from pathlib import Path
fixture=tempfile.TemporaryDirectory();os.environ["MYB_FIXTURE_ROOT"]=fixture.name
prefs=Path(fixture.name)/"var/mobile/Library/Preferences";prefs.mkdir(parents=True)
(prefs/"net.myxxdev.mybloxx.safariguard.plist").write_bytes(plistlib.dumps({"Enabled":True,"Blocked":["example.com"],"Allowed":[],"ShowBlocked":True}))
binary=sys.argv[1]
def start():
    p=subprocess.Popen([binary],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    for _ in range(100):
        try:
            s=socket.create_connection(('127.0.0.1',18788),.1);s.close();return p
        except OSError:
            if p.poll() is not None:raise AssertionError('server exited before preview listener started')
            time.sleep(.02)
    p.terminate();p.wait(timeout=5);raise AssertionError('preview listener did not start')
def request(method='GET',target='http://ads.example.com/',headers='',port=18021,host='ads.example.com',expected=403):
    with socket.create_connection(('127.0.0.1',port),2) as s:
        s.sendall(f'{method} {target} HTTP/1.1\r\nHost: {host}\r\n{headers}\r\n'.encode())
        s.shutdown(socket.SHUT_WR);result=b''
        while True:
            b=s.recv(65536)
            if not b:break
            result+=b
        head,body=result.split(b'\r\n\r\n',1)
        assert head.startswith(f'HTTP/1.1 {expected}'.encode())
        assert int([l for l in head.split(b'\r\n') if l.startswith(b'Content-Length:')][0].split(b':')[1])==len(body)
        assert b'no-store' in head and b"default-src 'none'" in head
        for script in re.findall(rb'<script>(.*?)</script>',body,re.S):
            digest=base64.b64encode(hashlib.sha256(script).digest())
            assert b"script-src 'sha256-"+digest+b"'" in head
        return body
p=start()
try:
    body=request(headers='Sec-Fetch-Dest: document\r\nSec-Fetch-Mode: navigate\r\n',expected=200)
    assert b'Website blocked' in body and b'ads.example.com' in body and b'data:image/png;base64,' in body
    assert b'MYbloXX<sup>' in body and '®'.encode() in body
    assert b'prefers-reduced-motion' in body and b'id="back"' in body
    assert b'--accent:#B59EFF' in body and b'--bg:#090B10' in body and b'viewport-fit=cover' in body and b'safe-area-inset-top' in body
    assert b'MYXXdev\xe2\x84\xa2' in body and not re.search(rb'\son[a-z]+=',body)
    assert request('CONNECT','ads.example.com:443')==b''
    assert request(headers='Sec-Fetch-Dest: iframe\r\n')==b''
    assert request(headers='Sec-Fetch-Dest: image\r\n')==b''
    assert b'Website blocked' in request(headers='Accept: text/html\r\n',expected=200)
    assert b'Website blocked' in request(headers='Accept: application/xhtml+xml, text/html;q=0.9\r\n',expected=200)
    assert request(headers='Accept: image/avif,image/webp,*/*\r\n')==b''
    assert request(headers='Accept: text/html\r\nSec-Fetch-Dest: iframe\r\n')==b''
    assert request(headers='Accept: text/html\r\nSec-Fetch-Dest: empty\r\n')==b''
    assert request(headers='Accept: text/html\r\nSec-Fetch-Mode: cors\r\n')==b''
    assert request('POST',headers='Sec-Fetch-Dest: document\r\n')==b''
    assert request(headers='Sec-Fetch-Dest: document\r\nSec-Fetch-Mode: cors\r\n')==b''
    evil=request(target='/',headers='Host: <script>.example\r\nSec-Fetch-Dest: document\r\n',expected=200)
    assert b'<script>.example' not in evil and b'&lt;script&gt;.example' in evil
    page=request(target='/mybloxx-preview',port=18788,host='127.0.0.1:18788',expected=200)
    assert b'Website blocked' in page and b'data:image/png;base64,' in page
    assert request(target='http://ads.example.com/mybloxx-preview')==b''
    state=json.loads(request(target='/mybloxx-status',port=18788,host='127.0.0.1:18788',expected=200))
    assert state['ports']['18021']['listening'] and state['ports']['18788']['listening']
    notice=request(target='/mybloxx-blocked?host=example.com',port=18788,host='127.0.0.1:18788',expected=200)
    assert b'example.com' in notice and b'Website blocked' in notice and b'MYbloXX\xc2\xae protection blocks this website.' in notice
    assert request(target='/mybloxx-browser-config',port=18788,host='127.0.0.1:18788')==b''
    config=json.loads(request(target='/mybloxx-browser-config',headers='X-MYbloXX-Bridge: 1\r\n',port=18788,host='127.0.0.1:18788',expected=200))
    assert config['rules']['Blocked']==['example.com'] and config['rules']['Enabled']
    assert not config['pac']['active'] and re.fullmatch(r'[a-f0-9]{64}',config['bridgeSecret'])
    bridge_secret=config['bridgeSecret']
    native=subprocess.run([sys.argv[2],'18788','/mybloxx-browser-config'],capture_output=True,text=True,timeout=5)
    assert native.returncode==0 and json.loads(native.stdout)['rules']['Blocked']==['example.com']
    request(target='/mybloxx-browser-event?app=com.apple.mobilesafari&phase=loaded',headers='X-MYbloXX-Bridge: 1\r\n',port=18788,host='127.0.0.1:18788',expected=200)
    state=json.loads(request(target='/mybloxx-status',port=18788,host='127.0.0.1:18788',expected=200))
    assert state['browsers']['com.apple.mobilesafari']['loaded'] and state['guardSettings']['blockedCount']==1
    # ---- diagnostics: per-browser states, new event names, popup trace, versions ----
    def ev(query,expected=200):return request(target='/mybloxx-browser-event?'+query,headers='X-MYbloXX-Bridge: 1\r\n',port=18788,host='127.0.0.1:18788',expected=expected)
    def snapshot():return json.loads(request(target='/mybloxx-status',port=18788,host='127.0.0.1:18788',expected=200))
    before=snapshot()
    assert before['browserStates']['org.mozilla.ios.Firefox']['state']=='not-observed' and before['browserStates']['com.google.chrome.ios']['state']=='not-observed'  # unknown, not "failed"
    assert before['browserStates']['com.apple.mobilesafari']['state']=='loaded'
    assert before['browserStates']['com.apple.mobilesafari']['componentVersion']=='unknown'  # this event carried no version
    for phase in ('window_hook_seen','popup_allowed','popup_blocked','permission_consumed','shield_off','host_unsupported'):
        ev('app=com.google.chrome.ios&phase='+phase+'&ver=6.11192026-15-RH')
    ev('app=com.apple.mobilesafari&phase=navigation_seen&ver=6.11192026-15-RH')
    ev('app=com.apple.mobilesafari&phase=window_hook_seen&ver=6.11192026-15-RH')
    ev('app=com.apple.mobilesafari&phase=popup_blocked&ver=6.11192026-15-RH')
    snap=snapshot()
    assert snap['browserStates']['com.apple.mobilesafari']['state']=='window-hook-observed' and snap['browserStates']['com.apple.mobilesafari']['popupsBlocked']==1
    assert snap['browserStates']['com.apple.mobilesafari']['componentVersion']=='6.11192026-15-RH' and snap['bridgeVersion']=='6.11192026-15-RH'
    assert snap['browserStates']['com.google.chrome.ios']['state']=='host-callback-unsupported'
    ev('app=com.apple.mobilesafari&phase=bridge_failed');assert snapshot()['browserStates']['com.apple.mobilesafari']['state']=='bridge-unavailable'
    ev('app=com.apple.mobilesafari&phase=bridge_ready');assert snapshot()['browserStates']['com.apple.mobilesafari']['state']=='window-hook-observed'
    assert 'RC3' not in json.dumps(snap) and 'B22' not in json.dumps(snap)  # no stale hard-coded build names
    # not accepted: unknown app, unknown phase, malformed trace
    for q in ('app=com.example.notabrowser&phase=loaded','app=com.apple.mobilesafari&phase=made_up_event','app=org.mozilla.ios.Firefox&phase=popup_trace&layer=bogus&type=0&tf=nil&gest=0&result=block'):
        ev(q,expected=403)
    n=len(snapshot()['popupTrace'])
    ev('app=com.apple.mobilesafari&phase=popup_trace&layer=nav&type=0&tf=nil&gest=1&result=policy-allow&src=testpages.kzar.co.uk&dst=testpages.kzar.co.uk&ver=x')
    ev('app=com.apple.mobilesafari&phase=popup_trace&layer=create&type=5&tf=nil&gest=1&result=token&src=testpages.kzar.co.uk&dst=testpages.kzar.co.uk&ver=x')
    ev('app=com.apple.mobilesafari&phase=popup_trace&layer=create-async&type=5&tf=nil&sf=sub&gest=-1&result=block&src=a.example&dst=b.example&ver=x')
    tr=snapshot()['popupTrace'];assert len(tr)==n+3 and tr[-1]['layer']=='create-async' and tr[-1]['sourceFrame']=='sub' and tr[-1]['gesture']==-1;tr=tr[:-1]
    assert len(tr)==n+2 and tr[-2]['layer']=='nav' and tr[-1]['layer']=='create' and tr[-1]['navigationType']==5 and tr[-1]['result']=='token'
    for bad in ('layer=bogus&type=0&tf=nil&gest=0&result=block','layer=nav&type=0&tf=nil&gest=0&result=block&src=http%3A%2F%2Fevil%2Fpath','layer=nav&type=0&tf=nil&gest=0&result=secret123','layer=nav&type=abc&tf=nil&gest=0&result=block'):
        ev('app=com.apple.mobilesafari&phase=popup_trace&'+bad,expected=403)
    assert len(snapshot()['popupTrace'])==n+3  # malformed traces are dropped
    text=json.dumps(snapshot());assert bridge_secret not in text and 'bridgeSecret' not in text and 'http://' not in text.replace('http://127.0.0.1','')  # no secret, no URLs in diagnostics
    # Untrusted blocked origin receives a navigation ticket, never a write capability.
    data_dir=Path(fixture.name)/"var/mobile/Library/MYbloXX";data_dir.mkdir(parents=True,exist_ok=True)
    (data_dir/"State.plist").write_bytes(plistlib.dumps({"enabled":True,"mode":"blockXXX"}))
    page=request(headers='Accept: text/html\r\n',expected=200)
    assert b'data-secret=""' in page and b'Allow this website' in page and b'id="choices" hidden' in page
    ticket=re.search(rb'mybloxx-allow\?request=([a-f0-9]{64})',page).group(1).decode()
    assert request(target='/mybloxx-allow',host='127.0.0.1:18021')==b''
    path='/mybloxx-allow?request='+ticket
    confirmation=request(target=path,host='127.0.0.1:18021',expected=200)
    secret=re.search(rb'data-secret="([a-f0-9]{64})"',confirmation).group(1).decode()
    assert secret!=ticket and b'Allow for 2 minutes' in confirmation and b'Allow once' not in confirmation and b'Allow for 15 minutes' in confirmation and b'Always allow' in confirmation and b'Keep blocked' in confirmation and b'100widgets' not in confirmation
    assert b'id="main-actions" hidden' in confirmation
    dump=os.environ.get('MYB_DUMP_PAGES')
    if dump:
        Path(dump).mkdir(parents=True,exist_ok=True);(Path(dump)/'confirm.html').write_bytes(confirmation)
        (Path(dump)/'blocked.html').write_bytes(request(target='/mybloxx-blocked?host=ads.example.com&url=https%3A%2F%2Fads.example.com%2Fpath%3Fx%3D1',host='127.0.0.1:18021',expected=200))
        (Path(dump)/'long.html').write_bytes(request(target='/mybloxx-blocked?host='+'a'*60+'.example.com&url=https%3A%2F%2F'+'a'*60+'.example.com%2F'+'segment%2F'*40+'%3Ftoken%3D'+'x'*200,host='127.0.0.1:18021',expected=200))
    assert b'ads.example.com' in confirmation
    good='Origin: http://127.0.0.1:18021\r\nX-MYbloXX-Allow-Token: '+secret+'\r\nX-MYbloXX-Allow-Duration: temp\r\n'
    assert request('POST','/mybloxx-allow-apply',host='127.0.0.1:18021')==b''
    assert request('GET','/mybloxx-allow-apply',headers=good,host='127.0.0.1:18021')==b''
    assert request('OPTIONS','/mybloxx-allow-apply',headers=good,host='127.0.0.1:18021')==b''
    assert request('POST','/mybloxx-allow-apply',headers=good.replace('Origin: http://127.0.0.1:18021','Origin: https://evil.example'),host='127.0.0.1:18021')==b''
    assert request('POST','/mybloxx-allow-apply',headers=good.replace(secret,ticket),host='127.0.0.1:18021')==b''
    assert request('POST','/mybloxx-allow-apply',headers=good.replace('Duration: temp','Duration: forever'),host='127.0.0.1:18021')==b'' # unknown scope refused, ticket stays usable
    assert request('POST','/mybloxx-allow-apply',headers=good,host='localhost:18021')==b''
    assert request(target=path,host='127.0.0.1:18788',port=18788)==b''
    request('POST','/mybloxx-allow-apply',headers=good,host='127.0.0.1:18021',expected=202)
    request('POST','/mybloxx-allow-apply',headers=good,host='127.0.0.1:18021',expected=409)
    for _ in range(50):
        result=json.loads(request(target='/mybloxx-allow-status',headers='X-MYbloXX-Allow-Token: '+secret+'\r\n',host='127.0.0.1:18021',expected=200))
        if result['phase']=='success':break
        time.sleep(.01)
    assert result['phase']=='success' and result['url']=='http://ads.example.com/' and result['duration']=='temp' and result['expires']>time.time()+800 and result['expires']<time.time()+901
    assert request(target=path,host='127.0.0.1:18021')==b'' # consumed confirmation
    page=request(target='/mybloxx-blocked?host=ads.example.com&url=https%3A%2F%2Fads.example.com%2Fpath%3Fx%3D1',host='127.0.0.1:18021',expected=200)
    assert re.search(rb'mybloxx-allow\?request=[a-f0-9]{64}',page)
    invalid=request(target='/mybloxx-blocked?host=ads.example.com&url=https%3A%2F%2Fevil.example%2F',host='127.0.0.1:18021',expected=200)
    assert not re.search(rb'mybloxx-allow\?request=[a-f0-9]{64}',invalid)
    # Untrusted data is escaped everywhere it is displayed.
    xss=request(target='/mybloxx-blocked?host=%3Cimg%20src%3Dx%20onerror%3Dalert(1)%3E&app=%3Cb%3Eapp&url=https%3A%2F%2Fads.example.com%2F',host='127.0.0.1:18021',expected=200)
    assert b'<img src=x' not in xss and b'<b>app' not in xss
    # Shield bridge routes: POST + bridge header + private per-launch secret, never a cross-site request.
    S='127.0.0.1:18021'
    def shield(method='POST',path='/mybloxx-shield-check?kind=popup&source=src.example&dest=dst.example&reason=popup-strict',secret=bridge_secret,extra='',bridge=True,expected=403):
        h=('X-MYbloXX-Bridge: 1\r\n' if bridge else '')+('X-MYbloXX-Bridge-Secret: '+secret+'\r\n' if secret else '')+extra
        return request(method,path,headers=h,host=S,expected=expected)
    assert shield(method='GET')==b'' and shield(secret=None)==b'' and shield(secret='0'*64)==b'' and shield(bridge=False)==b''
    assert shield(extra='Origin: https://evil.example\r\n')==b'' and shield(extra='Sec-Fetch-Site: cross-site\r\n')==b''
    assert json.loads(shield(expected=200))=={'allowed':False}
    assert shield(path='/mybloxx-shield-check?kind=appstore&source=com.a.b')==b'' # popups only over the bridge
    assert shield(path='/mybloxx-shield-grant?kind=appstore&source=com.a.b&mode=always')==b'' # an app permission cannot be created from the web bridge
    assert shield(path='/mybloxx-shield-grant?kind=popup&source=bad%20host&mode=always')==b''
    assert shield(path='/mybloxx-shield-grant?kind=popup&source=src.example&mode=once',expected=200)!=b''
    assert json.loads(shield(expected=200))['allowed']==True   # consumed by the intended operation
    assert json.loads(shield(expected=200))['allowed']==False  # and gone: no reusable bypass
    act=plistlib.loads((Path(fixture.name)/'var/mobile/Library/MYbloXX/ShieldActivity.plist').read_bytes())['items']
    assert any(i['type']=='popup' and i['source']=='src.example' and i['count']>=2 for i in act)
    assert all('path' not in str(i) for i in act)
    probe=subprocess.run([binary,'--diagnose'],capture_output=True,text=True,timeout=5)
    assert probe.returncode==0
    probe_state=json.JSONDecoder().raw_decode(probe.stdout)[0]
    assert probe_state['ports']['18021']['errno']==errno.EADDRINUSE
finally:
    p.terminate();p.wait(timeout=5)
# Reproduce the phone's bind-failure condition without disturbing its owner.
occupied=socket.socket();occupied.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);occupied.bind(('127.0.0.1',18021));occupied.listen()
p=start()
try:
    state=json.loads(request(target='/mybloxx-status',port=18788,host='127.0.0.1:18788',expected=200))
    assert state['ports']['18021']['stage']=='bind'
    assert state['ports']['18021']['errno']==errno.EADDRINUSE
    assert state['ports']['18788']['listening']
    assert b'Website blocked' in request(target='/mybloxx-preview',port=18788,host='127.0.0.1:18788',expected=200)
finally:
    p.terminate();p.wait(timeout=5);occupied.close()
fixture.cleanup()
print('Responder, bridge and website-action security checks passed, including private confirmation capability, origin checks, single use and original URL retention.')
