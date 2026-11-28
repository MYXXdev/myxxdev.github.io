#!/usr/bin/env python3
"""Verify the built RootHide DEB: identity, version, slices, libroot linkage, entitlements, scripts."""
import subprocess,sys,tempfile,os,glob,hashlib,re,plistlib
from pathlib import Path
pkgdir=Path(sys.argv[1]);debs=sorted(pkgdir.glob('*.deb'))
fails=[]
def need(c,m):
    if not c:fails.append(m)
need(len(debs)==1,'expected exactly one DEB, found %d'%len(debs))
if not debs:print('\n'.join(fails));sys.exit(1)
deb=debs[0]
ctl=subprocess.check_output(['dpkg-deb','-f',str(deb)]).decode()
need(re.search(r'^Package: net\.myxxdev\.mybloxx15$',ctl,re.M),'package identity')
need('Version: 6.11252026-64-RH' in ctl,'version')
need('Name: MYbloXX® (RootHide)' in ctl,'display name')
hdr=Path('Shared/MYBVersion.h').read_text() if Path('Shared/MYBVersion.h').exists() else ''
need('#define MYB_RELEASE_LABEL "RH-15-112526"' in hdr and '#define MYB_COMPONENT_VERSION "6.11252026-64-RH"' in hdr and '#define MYB_DISPLAY_NAME "MYbloXX® (RootHide)"' in hdr,'release identity constants')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.060924-22-RC5.5-polish']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.060924-21-RC5.4-polish']).returncode==0,'package version sorts newer than RC5.4 and RC5.5')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.111626-19-RH']).returncode==0,'release is above the earlier build 6.111626-19-RH, so an upgrade is distinguishable')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.111626-15-RH-EXP1']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.111626-15-RH-EXP2']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.111626-16-RH']).returncode==0,'the release sorts newer than the preserved EXP1 and EXP2 builds (an upgrade, not a downgrade)')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-6-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-11-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-10-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-9-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-8-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-7-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-5-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-4-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-3-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-2-RH']).returncode==0 and subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-1-RH']).returncode==0,'the update installs over the builds that were tested')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.111526-15-RH']).returncode==0,'release sorts newer than the RH-15-111526 release build')
need(all(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt',old]).returncode==0 for old in ['6.11192026-15-RH','6.11192026-15-RH-UI1','6.11192026-19-RH']),'release sorts above the plain build, the UI1 build and the hybrid build, so it upgrades each of them')
need(re.search(r'^Architecture: iphoneos-arm64e$',ctl,re.M),'architecture (RootHide scheme)')
need('RootHide: true' in ctl,'RootHide flag')
x=Path(tempfile.mkdtemp(prefix='mybloxx-deb-'))
subprocess.check_call(['dpkg-deb','-x',str(deb),str(x)]);subprocess.check_call(['dpkg-deb','-e',str(deb),str(x/'CTL')])
for s in ('postinst','prerm','postrm'):
    m=(x/'CTL'/s).stat().st_mode&0o777;need(m&0o111==0o111 and m&0o022==0,'%s mode %o'%(s,m))
    need(subprocess.run(['sh','-n',str(x/'CTL'/s)]).returncode==0,s+' syntax')
need('migrateinline' in (x/'CTL'/'postinst').read_text(),'postinst invokes inline migration')
need('migrate47' not in (x/'CTL'/'postinst').read_text(),'postinst has obsolete migration')
post=(x/'CTL'/'postinst').read_text()
order=[post.find(t) for t in ('"$HELPER" initdefaults','"$HELPER" refreshbundled','"$HELPER" preparefiles','"$HELPER" migrateinline','bootstrap system "$UPDATE_DAEMON"')]
need(all(i>=0 for i in order) and order==sorted(order),'shipping postinst order: defaults, bundled rules, files, inline migration, then the update schedule is loaded (%s)'%order)
need(post.find('initdefaults')<post.find('launchctl bootstrap')and 'net.myxxdev.mybloxx.updates' in post,'daily update job is installed by the shipping postinst after the defaults are written')
need(not [f for f in x.rglob('*') if 'youtopia' in f.name.lower()],'the retired YouTopia component is not shipped')
need(not [f for f in x.rglob('*') if f.name.lower().startswith('mybloxx-wao') or 'wifialwayson' in str(f).lower()],'the retired Wi-Fi Always On (WAO) component is not shipped')
need([f for f in x.rglob('MYbloXX.dylib')],'Data+ (MYbloXX.dylib) is still shipped')
need('MYbloXX-WAO' in post and 'MYbloXX-WAO' in Path('layout/DEBIAN/postrm').read_text(),'install and removal clean up a leftover WAO copy (exact paths only)')
need('YouTopia' in post and 'rm -f "$RETIRED"' in post,'postinst removes the retired YouTopia files on upgrade (exact paths only)')
postrm=(x/'CTL'/'postrm').read_text();prerm=(x/'CTL'/'prerm').read_text()
need('remove|purge' in postrm and 'Backups' in postrm and 'rm -rf "$BASE/Library/MYbloXX"' not in postrm,'postrm cleans owned data on removal and keeps the safety backups and Files folder')
need(re.search(r'^ deconfigure\)\n(?:\s*#.*\n)*\s*;;',prerm,re.M) is not None,'prerm does nothing destructive for deconfigure')
for name,text in (('control',ctl),('postinst',post)):need('EXP' not in text and 'experimental' not in text.lower(),name+' carries no experimental wording')
bins=[]
for f in x.rglob('*'):
    if f.is_file() and not f.is_symlink():
        h=f.open('rb').read(4)
        if h in (b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca'):bins.append(f)
need(bins,'no Mach-O found')
helper=[b for b in bins if b.name=='MYXXdev']
need(len(helper)==1,'helper binary missing')
for b in bins:
    if b.suffix=='.dylib' or b.name in('MYXXdev','mybloxx-pacd','mybloxx-blockd') or 'bundle' in str(b):
        info=subprocess.run(['lipo','-archs',str(b)],capture_output=True,text=True).stdout.split()
        need('arm64e' in info,'%s slices %s lack arm64e'%(b.name,info))
        if b.name=='MYBInAppAds.dylib':
            # injected into App Store apps, which are arm64 executables unless the app itself ships arm64e: both slices are required
            need('arm64' in info and 'arm64e' in info,'%s must ship both arm64 and arm64e slices, has %s'%(b.name,info))
        if b.suffix=='.dylib':print('SLICES %-28s %s'%(b.name,' '.join(info)))
        link=subprocess.run(['otool','-L',str(b)],capture_output=True,text=True).stdout
        if b.name=='MYXXdev':need('libroot' in link,'helper not linked to libroot')
for h in helper:
    ent=subprocess.run(['ldid','-e',str(h)],capture_output=True,text=True).stdout
    need('platform-application' in ent or 'com.apple.private' in ent or 'no-sandbox' in ent,'helper entitlements missing')
    print('helper entitlements:',sorted(set(re.findall(r'<key>([^<]+)</key>',ent))))
    need(h.stat().st_mode&0o4000,'helper is not setuid-root in the package ('+oct(h.stat().st_mode)+')') if False else None
# The Settings supervision message: the tweak and its filter (Settings only) must both be in the package, or iOS's own text stays.
sdl=[f for f in x.rglob('MYBSupervisionSign.dylib')];spl=[f for f in x.rglob('MYBSupervisionSign.plist')]
need(len(sdl)==1 and len(spl)==1,'MYBSupervisionSign.dylib and its filter plist are both packaged (found %d and %d)'%(len(sdl),len(spl)))
import plistlib
need(spl and 'com.apple.Preferences' in plistlib.loads(spl[0].read_bytes()).get('Filter',{}).get('Bundles',[]),'the supervision message filter targets Settings (com.apple.Preferences)')
pmd=[f for f in x.rglob('MYBPrivateMessages.dylib')];pmp=[f for f in x.rglob('MYBPrivateMessages.plist')]
need(len(pmd)==1 and len(pmp)==1,'MYBPrivateMessages.dylib and its filter plist are both packaged (found %d and %d)'%(len(pmd),len(pmp)))
need(pmp and plistlib.loads(pmp[0].read_bytes()).get('Filter',{}).get('Bundles',[])==['com.apple.MobileSMS'] and not plistlib.loads(pmp[0].read_bytes()).get('Filter',{}).get('Executables') and not plistlib.loads(pmp[0].read_bytes()).get('Filter',{}).get('Classes'),'Private Conversations loads in Messages (com.apple.MobileSMS) and nowhere else')
need(len(list(x.rglob('MYBPrivateAudioProbe.dylib')))==1 and __import__('plistlib').loads(next(x.rglob('MYBPrivateAudioProbe.plist')).read_bytes()).get('Filter',{}).get('Executables')==['mediaserverd'],'the read-only audio probe is packaged for mediaserverd only')
csd=[f for f in x.rglob('MYBPrivateCallService.dylib')];csp=[f for f in x.rglob('MYBPrivateCallService.plist')]
need(len(csd)==1 and len(csp)==1 and __import__('plistlib').loads(csp[0].read_bytes()).get('Filter',{}).get('Executables')==['callservicesd'],'the call-service part is packaged and loads only in callservicesd (found %d and %d)'%(len(csd),len(csp)))
pcd=[f for f in x.rglob('MYBPrivateCalls.dylib')];pcp=[f for f in x.rglob('MYBPrivateCalls.plist')]
need(len(pcd)==1 and len(pcp)==1,'MYBPrivateCalls.dylib and its filter plist are both packaged (found %d and %d)'%(len(pcd),len(pcp)))
import plistlib as _pl
need(pcp and sorted(_pl.loads(pcp[0].read_bytes()).get('Filter',{}).get('Bundles',[]))==['com.apple.InCallService','com.apple.mobilephone'] and not _pl.loads(pcp[0].read_bytes()).get('Filter',{}).get('Executables') and not _pl.loads(pcp[0].read_bytes()).get('Filter',{}).get('Classes'),'Private Calls loads only in Phone and the incoming-call app')
spd=[f for f in x.rglob('MYBPrivateSpotlight.dylib')];spp=[f for f in x.rglob('MYBPrivateSpotlight.plist')]
need(len(spd)==1 and len(spp)==1,'MYBPrivateSpotlight.dylib and its filter plist are both packaged (found %d and %d)'%(len(spd),len(spp)))
need(spp and sorted(plistlib.loads(spp[0].read_bytes()).get('Filter',{}).get('Bundles',[]))==['com.apple.Spotlight','com.apple.springboard'] and not plistlib.loads(spp[0].read_bytes()).get('Filter',{}).get('Executables'),'the Spotlight filter loads only in the home-screen search UI (SpringBoard and Spotlight), never in a daemon')
spb=spd[0].read_bytes() if spd else b''
need(spb and not any(w in spb for w in (b'CommCenter',b'CarrierBundle',b'CTCellularPlan',b'CTTelephony',b'IMDaemon',b'imagent',b'CoreTelephony',b'IMDPersistence',b'searchd',b'sms.db')),'the Spotlight filter carries no CommCenter, carrier, eSIM, telephony, delivery, indexer or database code')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-12-RH']).returncode==0,'release sorts above pass twelve')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-13-RH']).returncode==0,'release sorts above pass thirteen')
for dyl,bundles in (('MYBBrowserCleanup',['com.apple.mobilesafari']),('MYBPrivacyCover',['net.myxxdev.mybloxx.no-app-selected'])):
    d=[f for f in x.rglob(dyl+'.dylib')];pp=[f for f in x.rglob(dyl+'.plist')]
    need(len(d)==1 and len(pp)==1,dyl+'.dylib and its filter plist are both packaged (found %d and %d)'%(len(d),len(pp)))
    flt=plistlib.loads(pp[0].read_bytes()).get('Filter',{}) if pp else {}
    need(flt.get('Bundles')==bundles and not flt.get('Executables') and not flt.get('Classes'),dyl+' loads only where it must: '+','.join(bundles))
    b=d[0].read_bytes() if d else b''
    need(b and not any(w in b for w in (b'CommCenter',b'CarrierBundle',b'CTCellularPlan',b'CTTelephony',b'IMDaemon',b'imagent',b'CoreTelephony',b'IMDPersistence',b'sms.db')),dyl+' carries no CommCenter, carrier, eSIM, telephony or message-delivery code')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-14-RH']).returncode==0,'release sorts above pass fourteen')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-15-RH']).returncode==0,'release sorts above pass fifteen')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-17-RH']).returncode==0,'release sorts above r17')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-18-RH']).returncode==0,'release sorts above r18, so Private Calls installs as an in-place upgrade')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-19-RH']).returncode==0,'release sorts above r19')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-20-RH']).returncode==0,'release sorts above r20')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-21-RH']).returncode==0,'release sorts above r21')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-22-RH']).returncode==0,'release sorts above r22')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-23-RH']).returncode==0,'release sorts above r23')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-24-RH']).returncode==0,'release sorts above r24')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-25-RH']).returncode==0,'release sorts above r25')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-26-RH']).returncode==0,'release sorts above r26')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-27-RH']).returncode==0,'release sorts above r27')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-28-RH']).returncode==0,'release sorts above r28')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-29-RH']).returncode==0,'release sorts above r29')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-30-RH']).returncode==0,'release sorts above r30')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-31-RH']).returncode==0,'release sorts above r31')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-32-RH']).returncode==0,'release sorts above r32')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-33-RH']).returncode==0,'release sorts above r33')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-34-RH']).returncode==0,'release sorts above r34')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-35-RH']).returncode==0,'release sorts above r35')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-36-RH']).returncode==0,'release sorts above r36')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-37-RH']).returncode==0,'release sorts above r37')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-38-RH']).returncode==0,'release sorts above r38')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-39-RH']).returncode==0,'release sorts above r39')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-40-RH']).returncode==0,'release sorts above r40')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-41-RH']).returncode==0,'release sorts above r41')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-42-RH']).returncode==0,'release sorts above r42')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-47-RH']).returncode==0,'release sorts above r47')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-46-RH']).returncode==0,'release sorts above r46')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-45-RH']).returncode==0,'release sorts above r45')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-44-RH']).returncode==0,'release sorts above r44')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-43-RH']).returncode==0,'release sorts above r43')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-16-RH']).returncode==0,'release sorts above r16, so RAGGR installs as an in-place upgrade')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-48-RH']).returncode==0,'r50 sorts above r48')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-50-RH','gt','6.11252026-49-RH']).returncode==0,'r50 sorts above r49 (r49 shipped a Settings-bundle crash: undefined MYXXShowChoice symbol)')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-51-RH','gt','6.11252026-50-RH']).returncode==0,'r51 sorts above r50')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-52-RH','gt','6.11252026-51-RH']).returncode==0,'r52 sorts above r51')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-53-RH','gt','6.11252026-52-RH']).returncode==0,'r53 sorts above r52')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-54-RH','gt','6.11252026-53-RH']).returncode==0,'r54 sorts above r53')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-55-RH','gt','6.11252026-54-RH']).returncode==0,'r55 sorts above r54')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-56-RH','gt','6.11252026-55-RH']).returncode==0,'r56 sorts above r55')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-57-RH','gt','6.11252026-56-RH']).returncode==0,'r57 sorts above r56')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-58-RH','gt','6.11252026-57-RH']).returncode==0,'r58 sorts above r57')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-59-RH','gt','6.11252026-58-RH']).returncode==0,'r59 sorts above r58')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-60-RH','gt','6.11252026-59-RH']).returncode==0,'r60 sorts above r59')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-61-RH','gt','6.11252026-60-RH']).returncode==0,'r61 sorts above r60')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-62-RH','gt','6.11252026-61-RH']).returncode==0,'r62 sorts above r61')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-63-RH','gt','6.11252026-62-RH']).returncode==0,'r63 sorts above r62')
need(subprocess.run(['dpkg','--compare-versions','6.11252026-64-RH','gt','6.11252026-63-RH']).returncode==0,'r64 sorts above r63')
# Optimized PAC set: 40 files, the UTC header, one code line, the generator and rules file the updater regenerates from.
_pacs=[Path(q) for q in glob.glob(str(x)+'/**/usr/share/mybloxx/pacs',recursive=True)];_gens=[Path(q) for q in glob.glob(str(x)+'/**/usr/share/mybloxx/generator',recursive=True)]
need(len(_pacs)==1 and len(_gens)==1,'the PAC set and the generator are packaged')
if len(_pacs)==1 and len(_gens)==1:
    _files=sorted(_pacs[0].glob('*.pac'));need(len(_files)==40,'40 bundled PAC files, found %d'%len(_files))
    import json as _json
    _canon=_json.loads((_gens[0]/'canonical.json').read_text());_stamp=_canon.get('stamp','')
    need(re.fullmatch(r'\d{4}/\d{2}/\d{2} - \d{2}:\d{2} UTC',_stamp) is not None,'the packaged rules file carries a UTC date')
    for _f in _files:
        _t=_f.read_text();_l=_t.split('\n')
        need(len(_l)==7 and _l[0]=='//' and _l[2]=='// Updated: '+_stamp and _l[3]=='// Support Development: myxxfm.com/donate' and _l[4]=='//' and _l[5].startswith('var ') and _l[6]=='' and 'MYB_STAMP' not in _t and '\r' not in _t,_f.name+' has the UTC header and exactly one code line')
    _want=dict(l.split()[::-1] for l in Path('tests/raggr-pacs.sha256').read_text().splitlines() if l.strip())
    import hashlib as _h
    need(len(_want)==40 and {f.name for f in _files}==set(_want),'the packaged PAC names are exactly the 40 RAGGR names')
    for _f in _files:need(_h.sha256(_f.read_bytes()).hexdigest()==_want.get(_f.name),_f.name+' is byte-identical to the finished RAGGR bundle output')
    _c=_canon.get('compact');need(isinstance(_c,dict) and _c.get('format',0)>=2 and len(_c.get('host_labels',[]))>0,'the packaged rules file is RAGGR (engine-2 compact section)')
    need(_canon['stamp']=='2026/11/26 - 18:10 UTC','the packaged rules date is the RAGGR release date')
    for _n in ('generate.js','runtime.txt'):need((_gens[0]/_n).stat().st_size>1000,_n+' is packaged for on-device generation')
# MYXX Reserve (folded in): loaders only where they must be, the helper where SpringBoard expects it, no CommCenter/carrier code.
for dyl,flt in (('MYXXReserve',{'Bundles':['com.apple.springboard']}),('MYXXReserveDisplay',{'Bundles':['com.apple.springboard']}),('MYXXReserveThermal',{'Executables':['thermalmonitord']})):
    d=[f for f in x.rglob(dyl+'.dylib')];pp=[f for f in x.rglob(dyl+'.plist')]
    need(len(d)==1 and len(pp)==1,dyl+' dylib and filter are both packaged (found %d and %d)'%(len(d),len(pp)))
    got=plistlib.loads(pp[0].read_bytes()).get('Filter',{}) if pp else {}
    need(got==flt,dyl+' filter is exactly '+str(flt)+', got '+str(got))
    b=d[0].read_bytes() if d else b''
    need(b and not any(w in b for w in (b'CommCenter',b'CarrierBundle',b'CTCellularPlan',b'IMDaemon',b'imagent',b'sms.db')),dyl+' carries no CommCenter, carrier, eSIM or message-delivery code')
rh=[f for f in x.rglob('myxxreserved') if f.is_file()]
need(len(rh)==1 and str(rh[0]).endswith('usr/libexec/myxxreserved'),'Reserve power helper is packaged once at /usr/libexec/myxxreserved')
if rh:
    lst=subprocess.check_output(['dpkg-deb','-c',str(deb)]).decode()
    need(re.search(r'^-r[w-]s[r-][w-][x-][r-][w-][x-]\s.*usr/libexec/myxxreserved$',lst,re.M) is not None,'Reserve power helper keeps its setuid bit in the package')
    rent=subprocess.run(['ldid','-e',str(rh[0])],capture_output=True,text=True).stdout
    need('platform-application' in rent and 'RootDomainUserClient' in rent,'Reserve power helper carries the power-management entitlements')
need(any(True for f in x.rglob('MYXXReserveCC.bundle')),'Reserve Control Center toggle is packaged')
need(not any(x.rglob('MYXXReservePrefs.bundle')),'the standalone Reserve Settings bundle is not shipped (Settings is inside MYbloXX)')
need(all(w in ctl for w in ('xyz.cypwn.sentinel','ai.paisseon.reverie')) and re.search(r'^Conflicts:.*com\.myxxdev\.reserve',ctl,re.M) is not None,'control: Reserve replaces the standalone package and conflicts with Sentinel and Reverie')
pmb=pmd[0].read_bytes() if pmd else b''
need(pmb and not any(w in pmb for w in (b'CommCenter',b'CarrierBundle',b'CTCellularPlan',b'CTTelephony',b'IMDaemon',b'imagent',b'CoreTelephony')),'Private Conversations carries no CommCenter, carrier, eSIM, telephony or message-delivery code')
sbin=sdl[0].read_bytes() if sdl else b'' # constant strings that contain the registered sign are stored as UTF-16
need(b'PSUIFooterHyperlinkView' in sbin and (b'shielded by MYbloXX' in sbin or 'shielded by MYbloXX'.encode('utf-16-le') in sbin),'the packaged supervision tweak hooks the Settings footer and carries the exact message')
# One shared in-app ad dylib replaces the eight per-app ones: it ships exactly once, its filter plist names exactly the supported apps
# (the union of the catalogue bundle ids), and none of the retired per-app binaries or plists are packaged.
catalogue=re.findall(r'@\{@"module":@"(\w+)",@"name":@"[^"]+",@"bundles":@\[([^\]]*)\]',(Path(__file__).resolve().parents[1]/'Shared/MYBInAppAds.h').read_text())
need(len(catalogue)>=10,'catalogue lists the in-app ad modules')
dl=[f for f in x.rglob('MYBInAppAds.dylib')];pl=[f for f in x.rglob('MYBInAppAds.plist')]
need(len(dl)==1,'MYBInAppAds.dylib is packaged exactly once (found %d)'%len(dl))
need(len(pl)==1,'MYBInAppAds.plist is packaged exactly once (found %d)'%len(pl))
if pl:
    import plistlib;got=sorted(plistlib.loads(pl[0].read_bytes()).get('Filter',{}).get('Bundles',[]));want=sorted({b for _,bundles in catalogue for b in re.findall(r'"([^"]+)"',bundles)})  # no com.apple.UIKit: the helper adds only the apps the person selects. Theos packages filters as binary plists
    need(got==want and 'com.apple.UIKit' not in got,'MYBInAppAds.plist filters %s, expected %s'%(got,want))
sp=[f for f in x.rglob('MYBSpeedyAds.plist') if f.is_file()]
need(len(sp)==1,'MYBSpeedyAds.plist is packaged exactly once')
if sp:
    import plistlib;g=plistlib.loads(sp[0].read_bytes()).get('Filter',{}).get('Bundles',[])
    need(g==['net.myxxdev.mybloxx.no-app-selected'] and 'com.apple.UIKit' not in g,'MYBSpeedyAds.plist names no app until one is selected in App Control (never com.apple.UIKit): %s'%g)
# No loader of this project may load into every UIKit process. The one exception is Data+ (MYbloXX.plist), the original component
# that ships unmodified: it is held to being byte-for-byte the filter of the preserved source rather than being exempt unchecked.
from pathlib import Path as _P
_orig=plistlib.loads((_P(__file__).resolve().parents[1]/'Sources/PrebuiltTweaks/DataPlus/MYbloXX.plist').read_bytes()).get('Filter',{}).get('Bundles',[])
for f in x.rglob('*.plist'):
    if f.parent.name=='DynamicLibraries':
        try:b=plistlib.loads(f.read_bytes()).get('Filter',{}).get('Bundles',[])
        except Exception:continue
        if f.name=='MYbloXX.plist':
            need(b==_orig,'Data+ MYbloXX.plist differs from the preserved original filter: %s vs %s'%(b,_orig));continue
        need('com.apple.UIKit' not in b,'%s must not load into every UIKit process'%f.name)
retired=[f.name for f in x.rglob('MYBAds*') if f.is_file()]
need(not retired,'retired per-app ad modules are still packaged: %s'%retired)
# Licence and notice texts travel with the code they cover (tests/provenance.py checks the source side).
for d,files in {'mybloxx-inappads':('NOTICE.md','LICENSES.md','COPYING'),'mybloxx-speedyads':('NOTICE.md','COPYING'),'mybloxx-shield-redirects':('NOTICE.md','LICENSE')}.items():
    for f in files:
        got=[g for g in x.rglob(f) if g.parent.name==d]
        need(len(got)==1,'%s/%s is packaged (found %d)'%(d,f,len(got)))
sc=[f for f in x.rglob('mybloxx-control')];need(sc and sc[0].stat().st_mode&0o111,'mybloxx-control executable')
need(not any('Main'==f.name and 'MYbloXX' in str(f.parent) for f in x.rglob('Main')),'obsolete URL template shipped')
need(not list(x.rglob('*InlinePACExperiment*')),'experiment artefacts shipped')
sha=hashlib.sha256(deb.read_bytes()).hexdigest()
(pkgdir/(deb.name+'.sha256')).write_text(sha+'  '+deb.name+'\n')
print('DEB',deb.name,'SHA-256',sha)
if fails:print('\n'.join('FAIL: '+f for f in fails));sys.exit(1)
print('Package verification passed')
