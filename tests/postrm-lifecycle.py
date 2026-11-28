# postrm: removal cleans MYbloXX's own data and nothing else; upgrades never delete.
from pathlib import Path
import os, subprocess, tempfile
source=(Path(__file__).resolve().parents[1]/'layout/DEBIAN/postrm').read_text()
def run(action,root):
    s=source.replace('for BASE in /var/mobile /rootfs/var/mobile;',f'for BASE in "{root}/var/mobile";').replace('for ROOT in "" /var/jb;',f'for ROOT in "{root}/jb";')
    script=Path(root)/'postrm';script.write_text(s)
    fake=Path(root)/'bin';fake.mkdir(exist_ok=True);(fake/'launchctl').write_text('#!/bin/sh\nexit 0\n');(fake/'launchctl').chmod(0o755)
    env=dict(os.environ,PATH=str(fake)+os.pathsep+os.environ['PATH'])
    return subprocess.run(['sh',str(script),action],env=env,capture_output=True,text=True)
def build(root):
    m=Path(root)/'var/mobile'
    files={'Library/MYbloXX/State.plist':'s','Library/MYbloXX/PAC/Default.pac':'p','Library/MYbloXX/control.log':'l','Library/MYbloXX/Backups/Supervision-before-uninstall.plist':'keep',
     'Library/Caches/net.myxxdev.mybloxx/c':'c','Library/Preferences/net.myxxdev.mybloxx.speedyads.plist':'p','Library/Preferences/com.other.plist':'foreign',
     'Library/Preferences/net.myxxdev.mybloxxother.keep':'foreign','Media/MYbloXX/ActiveConfiguration.plist':'a','Media/MYbloXX/Backup.plist':'user backup',
     'Library/MyOtherApp/data':'foreign'}
    for k,v in files.items():
        f=m/k;f.parent.mkdir(parents=True,exist_ok=True);f.write_text(v)
    j=Path(root)/'jb/Library/MobileSubstrate/DynamicLibraries';j.mkdir(parents=True,exist_ok=True)
    (j/'YouTopia.dylib').write_text('x');(j/'YouTopia.disabled').write_text('x');(j/'MYbloXX-WAO.dylib').write_text('x');(j/'MYbloXX-WAO.plist').write_text('x');(j/'Other.dylib').write_text('other')
    return m,j
def ok(c,msg):
    assert c,msg
for action in ('upgrade','failed-upgrade','abort-upgrade','disappear','deconfigure',''):
    with tempfile.TemporaryDirectory() as t:
        m,j=build(t);assert run(action,t).returncode==0
        ok((m/'Library/MYbloXX/State.plist').exists() and (j/'YouTopia.dylib').exists(),f'"{action}" must not delete anything')
for action in ('remove','purge'):
    with tempfile.TemporaryDirectory() as t:
        m,j=build(t);r=run(action,t);ok(r.returncode==0,r.stderr)
        ok(not (m/'Library/MYbloXX/State.plist').exists() and not (m/'Library/MYbloXX/PAC').exists() and not (m/'Library/MYbloXX/control.log').exists(),'owned state and logs removed')
        ok((m/'Library/MYbloXX/Backups/Supervision-before-uninstall.plist').read_text()=='keep','the safety backup is kept')
        ok(not (m/'Library/Caches/net.myxxdev.mybloxx').exists() and not (m/'Library/Preferences/net.myxxdev.mybloxx.speedyads.plist').exists(),'owned caches and preferences removed')
        ok((m/'Library/Preferences/com.other.plist').exists() and (m/'Library/Preferences/net.myxxdev.mybloxxother.keep').exists() and (m/'Library/MyOtherApp/data').exists(),'foreign files with similar names are never touched')
        ok(not (m/'Media/MYbloXX/ActiveConfiguration.plist').exists() and (m/'Media/MYbloXX/Backup.plist').read_text()=='user backup','the live export goes, user backups in Files stay')
        ok(not (j/'YouTopia.dylib').exists() and not (j/'YouTopia.disabled').exists() and (j/'Other.dylib').exists(),'retired YouTopia files removed, other tweaks untouched')
        ok(not (j/'MYbloXX-WAO.dylib').exists() and not (j/'MYbloXX-WAO.plist').exists(),'retired WAO files removed on purge')
        ok('removed' in r.stdout and 'VPN' not in r.stdout and 'Files' not in r.stdout,'removal prints one plain line, no internals')
print('postrm removes only MYbloXX-owned data on removal; upgrades and deconfigure delete nothing')
