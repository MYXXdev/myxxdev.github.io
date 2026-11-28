import json,os,pathlib,plistlib,shutil,socket,subprocess,sys,tempfile,time
server,bundled,profiles=sys.argv[1:];port=18787
with tempfile.TemporaryDirectory() as tmp:
 root=pathlib.Path(tmp);shutil.copytree(bundled,root/'usr/share/mybloxx/pacs');shutil.copytree(profiles,root/'usr/share/mybloxx/profiles');shutil.copytree(pathlib.Path(profiles).parent/'dns',root/'usr/share/mybloxx/dns');prefs=root/'var/mobile/Library/Preferences';prefs.mkdir(parents=True)
 settings={'Enabled':True,'AppControlEnabled':True,'enabled-test.app':True,'test.app-VideoRate':4,'enabled-other.app':True,'other.app-VideoRate':8,'MYB2-proxy':'private'}
 (prefs/'net.myxxdev.mybloxx.speedyads.plist').write_bytes(plistlib.dumps(settings));env=dict(os.environ,MYB_FIXTURE_ROOT=tmp)
 proc=subprocess.Popen([server],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 def request(path,fragment=False):
  with socket.create_connection(('127.0.0.1',port),timeout=2) as s:
   data=f'GET {path} HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n'.encode()
   if fragment:
    for i in range(0,len(data),7):s.sendall(data[i:i+7]);time.sleep(.001)
   else:s.sendall(data)
   result=b''
   while True:
    chunk=s.recv(65536)
    if not chunk:break
    result+=chunk
  return result.split(b'\r\n\r\n',1)
 try:
  for _ in range(50):
   try:
    if b'200' in request('/health')[0]:break
   except OSError:time.sleep(.05)
  else:raise AssertionError('PAC service did not start')
  header,body=request('/Default.pac',True);assert b'200 OK' in header and b'function FindProxyForURL' in body
  for name,mode in {'Default':'Default','allowY':'allowY','blockAdSense':'blockAdSense','noApple':'blockApple','noSocials':'blockSocials','noXXX':'blockXXX'}.items():
   h,b=request(f'/profiles/{name}.mobileconfig');p=plistlib.loads(b);assert b'application/x-apple-aspen-config' in h;payload=p['PayloadContent'][0];assert payload['ProxyType']=='Auto' and payload['ProxyPACURL']==f'https://cdn.jsdelivr.net/gh/MYXXdev/myxxdev.github.io@master/MYbloXX/{mode}.pac' and '127.0.0.1' not in b.decode() and 'localhost' not in b.decode().lower() and p['PayloadIdentifier']=='net.myxxdev.mybloxx'
  EXPECT={'Cloudflare':('https://cloudflare-dns.com/dns-query',['1.1.1.1','1.0.0.1','2606:4700:4700::1111','2606:4700:4700::1001']),'Google':('https://dns.google/dns-query',['8.8.8.8','8.8.4.4','2001:4860:4860::8888','2001:4860:4860::8844']),'Quad9':('https://dns.quad9.net/dns-query',['9.9.9.9','149.112.112.112','2620:fe::fe','2620:fe::9'])}
  for name,(url,addrs) in EXPECT.items():
   h,b=request(f'/dns/{name}.mobileconfig');p=plistlib.loads(b);pl=p['PayloadContent'][0];d=pl['DNSSettings']
   assert b'application/x-apple-aspen-config' in h and pl['PayloadType']=='com.apple.dnsSettings.managed' and d['DNSProtocol']=='HTTPS' and d['ServerURL']==url and d['ServerAddresses']==addrs
   assert p['PayloadRemovalDisallowed'] is False and 'OnDemandRules' not in p and 'OnDemandRules' not in pl and 'ProhibitDisablement' not in d and p['PayloadIdentifier']==f'net.myxxdev.mybloxx.dns.{name.lower()}' and len(p['PayloadContent'])==1
   assert b'127.0.0.1' not in b and b'ProxyPACURL' not in b  # a DNS profile never touches the PAC/proxy configuration
  assert b'404' in request('/dns/../../Default.mobileconfig')[0] and b'404' in request('/dns/Evil.mobileconfig')[0] and b'404' in request('/dns/Cloudflare.mobileconfig/../Google.mobileconfig')[0]
  h,b=request('/app-config?app=test.app');j=json.loads(b);assert j=={k:v for k,v in settings.items() if k in ['Uninstalling','enabled-test.app']};assert 'other.app' not in b.decode() and 'private' not in b.decode()
  assert b'404' in request('/profiles/../../config.mobileconfig')[0]
  # A temporary native pause never poisons the cached PAC with DIRECT.
  data=root/'var/mobile/Library/MYbloXX';data.mkdir(parents=True,exist_ok=True);(data/'AppControlSession.plist').write_bytes(plistlib.dumps({'active':True,'previousEnabled':True}));assert request('/Default.pac')[1]==body
  print('Local PAC HTTP fragmentation, all six legacy and three DNS mobileconfig downloads, per-app bridge isolation and unchanged pause-time PAC checks passed')
 finally:
  proc.terminate();proc.wait(timeout=5)
