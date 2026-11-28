import os,json, platform, plistlib, subprocess, tempfile, time, shutil, base64
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'packages/UI-Previews';out.mkdir(parents=True,exist_ok=True)
def run(*args):return subprocess.check_output(args,text=True).strip()
runtimes=json.loads(run('xcrun','simctl','list','runtimes','--json'))['runtimes'];ios=[r for r in runtimes if r.get('isAvailable') and '.iOS-' in r['identifier']];assert ios,'No iOS runtime'
ios16=[r for r in ios if r['version'].split('.')[0]=='16']  # the user's device runs iOS 16.5.1: prefer an iOS 16 runtime
runtime=max(ios16 or ios,key=lambda r:tuple(int(p) for p in r['version'].split('.')))
print('SIMULATOR RUNTIME:',runtime['name'],runtime['version'],'(iOS 16 runtime)' if ios16 else '(no iOS 16 runtime installed; newest used)')
# Use the actual user's screen class, rather than the first small/large simulator.
device=run('xcrun','simctl','create','MYbloXX B50 Visual QA','com.apple.CoreSimulator.SimDeviceType.iPhone-14-Pro-Max',runtime['identifier'])
subprocess.run(['xcrun','simctl','boot',device],check=True);subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True,timeout=int(os.environ.get('MYB_SIM_BOOT_TIMEOUT','180')))  # slower hosts (hosted Intel) get more time to boot; nothing is asserted about speed
try:
 with tempfile.TemporaryDirectory() as temp:
  app=Path(temp)/'MYBPreview.app';app.mkdir();sdk=run('xcrun','--sdk','iphonesimulator','--show-sdk-path');arch='arm64' if platform.machine()=='arm64' else 'x86_64'
  names=['MYBDesign','MYBGlass','MYBPrismCell','MYBPrismSwitch','MYBMenuBase','MYBModernController','MYBModeInfoController','MYBTroubleshootingController','MYBBackupController','MYBUpdatesController','MYBDiagnosticsController','MYBRulesController','MYBTileBase','MYBPopupControlController','MYBRedirectController','MYBMoreSettingsController','MYBAppControlController','MYBInAppAdsController','MYBProxyOverrideController','MYBLegacyController','MYBPopupStrictnessController','MYBDNSController','MYBPACViewController','MYBHelpController','MYBWebController']
  args=['xcrun','--sdk','iphonesimulator','clang','-target',arch+'-apple-ios15.0-simulator','-isysroot',sdk,'-fobjc-arc','-DMYB_PREVIEW_HARNESS=1','-I'+str(root/'tests/preview-include')]
  for framework in ['UIKit','Foundation','QuartzCore','CoreGraphics','UniformTypeIdentifiers','WebKit','AVFoundation']:args+=['-framework',framework]
  subprocess.run(args+[str(root/'tests/preview-ui.m')]+[str(root/'Preferences'/(name+'.m')) for name in names]+['-o',str(app/'MYBPreview')],check=True)
  for image in (root/'Preferences/Resources').glob('*.png'):shutil.copy2(image,app/image.name)
  (app/'video-probe.mp4').write_bytes(base64.b64decode((root/'tests/video-probe.b64').read_text()));shutil.copy2(root/'Companions/SpeedyAds/Acceleration.js',app/'Acceleration.js')
  info={'CFBundleIdentifier':'net.myxxdev.mybloxx.preview','CFBundleExecutable':'MYBPreview','CFBundleName':'MYBPreview','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','MinimumOSVersion':'15.0','CFBundleSupportedPlatforms':['iPhoneSimulator'],'UIDeviceFamily':[1,2],'LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait']}
  (app/'Info.plist').write_bytes(plistlib.dumps(info));subprocess.run(['codesign','--force','--sign','-',str(app)],check=True);subprocess.run(['xcrun','simctl','install',device,str(app)],check=True)
  subprocess.run(['xcrun','simctl','status_bar',device,'override','--time','9:41','--batteryState','charged','--batteryLevel','100'],check=True)
  failures=[]
  for page in ['restraint','restraint-solid','restraint-still','modes','modeinfo','troubleshooting','shieldsheet','shieldsheet-solid','dashboard','rules','shield','apps','inappads','updates','status','backup','supervision','proxy','redirects','notice','form','strictness','dns','media','dashboard-scrolled','sheet-centre','inappads-status','legacy-prompt']:
   subprocess.run(['xcrun','simctl','terminate',device,'net.myxxdev.mybloxx.preview'],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   subprocess.run(['xcrun','simctl','launch',device,'net.myxxdev.mybloxx.preview',page],check=True)
   container=Path(run('xcrun','simctl','get_app_container',device,'net.myxxdev.mybloxx.preview','data'));result=container/'Documents/layout-result.txt'
   for attempt in range(600):  # up to 60 s per page on a slow host
    if result.exists():break
    time.sleep(.1)
   text=result.read_text();print(page,text)
   if not text.startswith('PASS:'):failures.append(page+': '+text)
   if page=='media':
    media=container/'Documents/media-result.json'
    for attempt in range(700):  # the page may need up to 60 s to be ready on a slow host
     if media.exists():break
     time.sleep(.1)
    report=json.loads(media.read_text());print('REAL PLAYER PROBE:',report);assert report.get('requested')==100 and report.get('webRate',0)>1,report
    shutil.copy2(media,out/'Media-Rate-Probe.json')
   else:
    time.sleep(.6);subprocess.run(['xcrun','simctl','io',device,'screenshot',str(out/(page+'.png'))],check=True)
   result.unlink()
  assert not failures, failures
finally:
 subprocess.run(['xcrun','simctl','shutdown',device],check=False);subprocess.run(['xcrun','simctl','delete',device],check=False)
