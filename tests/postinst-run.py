"""Runs the SHIPPING postinst (text-transformed only to point at a temp root) against a fake helper and a fake launchctl.
The closing message must match what actually happened: "Installed/SUCCESS" only when every step succeeded, an itemised
partial report otherwise, and no success text at all when the install cannot even start."""
import os,stat,subprocess,sys,tempfile
from pathlib import Path
root=Path(__file__).resolve().parent.parent
src=(root/'layout/DEBIAN/postinst').read_text()
assert 'for candidate in / /var/jb; do' in src and 'DATA_ROOT=/var/mobile/Library/MYbloXX/PAC' in src,'postinst layout changed; update the test transform'
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg)
def run(env_extra,helper_present=True,missing_job=None):
    t=Path(tempfile.mkdtemp(prefix='mybpi-'));jb=t/'jb';bin_=t/'bin'
    for d in ['usr/sbin/MYXXdev/MYbloXX','usr/libexec','usr/share/mybloxx/pacs','Library/LaunchDaemons']:(jb/d).mkdir(parents=True)
    bin_.mkdir()
    helper=jb/'usr/sbin/MYXXdev/MYbloXX/MYXXdev'
    if helper_present:
        helper.write_text('#!/bin/sh\nvar="FAIL_$1"\neval "rc=\\${$var:-0}"\nexit "$rc"\n');helper.chmod(0o755)
    (jb/'usr/sbin/MYXXdev/MYbloXX/MYbloXX').write_text('#!/bin/sh\n')
    for m in 'Default allowY blockAdSense blockApple blockSocials blockXXX MYbloXX MYbloXXTest MYbloXXallowFB MYbloXXallowY MYbloXXnoApple MYbloXXnoFB MYbloXXnoSocials MYbloXXnoXXX'.split():(jb/f'usr/share/mybloxx/pacs/{m}.pac').write_text('function FindProxyForURL(u,h){return "DIRECT";}')
    for lbl in ['restore','pacd','updates','blockd','appcontrol']:(jb/f'Library/LaunchDaemons/net.myxxdev.mybloxx.{lbl}.plist').write_text('<plist/>')
    (jb/'usr/libexec/mybloxx-blockd').write_text('#!/bin/sh\n')
    for name,body in {'launchctl':'#!/bin/sh\nif [ "$1" = print ]; then case "$2" in *"$MISSING_JOB") exit 113;; esac; fi\nexit 0\n','dpkg-query':'#!/bin/sh\necho 6.060924-99-TEST\n','sleep':'#!/bin/sh\nexit 0\n','chown':'#!/bin/sh\nexit 0\n','chmod':'#!/bin/sh\nexit 0\n'}.items():
        (bin_/name).write_text(body);(bin_/name).chmod(0o755)
    text=src.replace('for candidate in / /var/jb; do',f'for candidate in {jb}; do').replace('DATA_ROOT=/var/mobile/Library/MYbloXX/PAC',f'DATA_ROOT={t}/data').replace('[ -d /rootfs/var/mobile ] && DATA_ROOT=/rootfs/var/mobile/Library/MYbloXX/PAC','')
    script=t/'postinst';script.write_text(text)
    global LAST;LAST=t;dyn=jb/'Library/MobileSubstrate/DynamicLibraries';dyn.mkdir(parents=True);(dyn/'YouTopia.dylib').write_text('x');(dyn/'YouTopia.disabled').write_text('x');(dyn/'MYbloXX-WAO.dylib').write_text('x');(dyn/'MYbloXX-WAO.plist').write_text('x');(dyn/'MYbloXX-WAO.disabled').write_text('x');(dyn/'MYbloXX.dylib').write_text('d');(dyn/'Other.dylib').write_text('o')
    env=dict(os.environ,PATH=f'{bin_}:/usr/bin:/bin',MISSING_JOB=missing_job or 'NOSUCHJOB',**env_extra)
    r=subprocess.run(['/bin/sh',str(script)],capture_output=True,text=True,env=env,timeout=60)
    return r.returncode,r.stdout,r.stderr
# 1. everything succeeds
rc,out,err=run({})
need(rc==0 and 'MYbloXX® Installed!' in out and 'needing attention' not in out,'a clean install reports success')
need('MYbloXX® (RootHide) by MYXXdev™' in out and 'RH-15-112526' in out and 'EXP' not in out and 'package 6.060924-99-TEST' not in out and 'Special thanks' not in out,'banner and release label are printed, without internal package details')
need('Installing...' in out and out.index('Installing...')<out.index('Installed!'),'banner comes first')
dyn=LAST/'jb/Library/MobileSubstrate/DynamicLibraries'
need(not (dyn/'YouTopia.dylib').exists() and not (dyn/'YouTopia.disabled').exists() and (dyn/'Other.dylib').exists(),'upgrade removes the retired YouTopia files, including a disabled copy, and nothing else')
need(not [n for n in ('MYbloXX-WAO.dylib','MYbloXX-WAO.plist','MYbloXX-WAO.disabled') if (dyn/n).exists()] and (dyn/'MYbloXX.dylib').exists(),'upgrade removes the retired Wi-Fi Always On files (WAO), including a disabled copy, and keeps Data+')
need('pid' not in out.lower() and 'privilege' not in out.lower() and (LAST/'install.log').exists(),'routine helper output goes to the install log, not the screen')
# 2-5. problems never reach the installer screen (no error text, counts or log paths); they are written to the install log for the app to read
for action in ('refreshbundled','preparefiles','migrateinline','appcontrolmigrate'):
    rc,out,err=run({f'FAIL_{action}':'7'})
    need(rc==0 and 'Installed!' in out and 'needing attention' not in out and 'item(s)' not in out and 'install.log' not in out and 'not activated' not in out and 'could not' not in out.lower(),f'{action} failing shows nothing on the installer screen')
for code in ('90','65'):
    rc,out,err=run({'FAIL_initdefaults':code})
    need('Installed!' in out and 'First-install defaults' not in out and 'item(s)' not in out,f'initdefaults {code} shows nothing on the installer screen')
rc,out,err=run({},missing_job='net.myxxdev.mybloxx.appcontrol')
need('Installed!' in out and 'not running' not in out and 'item(s)' not in out,'a service that is not loaded shows nothing on the installer screen')
# 6. cannot start at all: no success text, non-zero exit
rc,out,err=run({},helper_present=False)
need(rc!=0 and 'Installed!' not in out,'a missing helper stops the install without any success text')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Postinst reporting checks passed.')
