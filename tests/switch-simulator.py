import os,json, platform, plistlib, subprocess, tempfile, time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def run(*args):return subprocess.check_output(args,text=True).strip()
runtimes=json.loads(run('xcrun','simctl','list','runtimes','--json'))['runtimes']
ios=[r for r in runtimes if r.get('isAvailable') and '.iOS-' in r['identifier']]
if not ios:raise SystemExit('No installed iOS Simulator runtime: switch runtime checks could not run')
ios16=[r for r in ios if r['version'].split('.')[0]=='16']
runtime=max(ios16 or ios,key=lambda r:tuple(int(p) for p in r['version'].split('.')))
print('SIMULATOR RUNTIME:',runtime['name'],runtime['version'])
devices=json.loads(run('xcrun','simctl','list','devices','available','--json'))['devices'].get(runtime['identifier'],[])
phones=[d for d in devices if 'iPhone' in d['name']]
created=False
if phones:device=phones[0]['udid']
else:
    device=run('xcrun','simctl','create','MYbloXX B50 Switch Test','com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro',runtime['identifier']);created=True
subprocess.run(['xcrun','simctl','boot',device],check=False)
subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True,timeout=int(os.environ.get('MYB_SIM_BOOT_TIMEOUT','180')))  # slower hosts (hosted Intel) get more time to boot; nothing is asserted about speed
try:
    with tempfile.TemporaryDirectory() as temp:
        app=Path(temp)/'MYBSwitchTest.app';app.mkdir();sdk=run('xcrun','--sdk','iphonesimulator','--show-sdk-path')
        arch='arm64' if platform.machine()=='arm64' else 'x86_64'
        subprocess.run(['xcrun','--sdk','iphonesimulator','clang','-target',arch+'-apple-ios15.0-simulator','-isysroot',sdk,'-fobjc-arc','-I'+str(root/'tests/preview-include'),'-framework','UIKit','-framework','Foundation','-framework','QuartzCore','-framework','CoreGraphics',str(root/'tests/switch-ui.m'),str(root/'Preferences/MYBPrismSwitch.m'),str(root/'Preferences/MYBPrismCell.m'),str(root/'Preferences/MYBDesign.m'),str(root/'Preferences/MYBGlass.m'),'-o',str(app/'MYBSwitchTest')],check=True)
        info={'CFBundleIdentifier':'net.myxxdev.mybloxx.switchtests','CFBundleExecutable':'MYBSwitchTest','CFBundleName':'MYBSwitchTest','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','MinimumOSVersion':'15.0','CFBundleSupportedPlatforms':['iPhoneSimulator'],'UIDeviceFamily':[1,2],'LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait']}
        (app/'Info.plist').write_bytes(plistlib.dumps(info));subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
        subprocess.run(['xcrun','simctl','install',device,str(app)],check=True)
        subprocess.run(['xcrun','simctl','launch',device,'net.myxxdev.mybloxx.switchtests'],check=True)
        container=Path(run('xcrun','simctl','get_app_container',device,'net.myxxdev.mybloxx.switchtests','data'));result=container/'Documents/switch-result.txt'
        for attempt in range(150):
            if result.exists():break
            time.sleep(.2)
        text=result.read_text();print(text);assert text.startswith('PASS:'),text
finally:
    subprocess.run(['xcrun','simctl','shutdown',device],check=False)
    if created:subprocess.run(['xcrun','simctl','delete',device],check=False)
