"""Source wiring for Advanced > Connectivity and Extra Privacy Protection. Reads real files; nothing here is a device check."""
import sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
R=lambda p:(root/p).read_text()
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg)
tw=R('Companions/MYBConnectivity/Tweak.xm')
need('sf_isChinaRegionCellularDevice' in tw and '%group SettingsGate' in tw,'network gate hook is its own group')
need('"com.apple.Preferences"' in R('Companions/MYBConnectivity/MYBConnectivity.plist'),'plist filter includes Settings')
need('isEqual:@"com.apple.Preferences"' in tw and 'installGate();' in tw,'gate installs only in the Settings process')
need('if(!switchOn(MYB_CONN_KEY_NETWORK_MENU))return %orig;' in tw,'gate answers only while the switch is on')
need('MobileGestalt' not in tw.replace('MobileGestalt, the device region','').replace('//',''),'no MobileGestalt override')
need('isEqual:@"com.apple.springboard"' in tw and 'startHotspotWatcher' in tw,'hotspot watcher only in SpringBoard')
need('NetworkClientActive' in tw and 'TimeoutSeconds' in tw,'self-expiring assertion')
need('PreventUserIdleSystemSleep' not in tw and 'PreventSystemSleep' not in tw,'no sleep prevention assertion')
need('MYBHotspotShouldHold(on,up,devices)' in tw,'hold decision is the tested rule')
need('dropAssertion();holding=NO;' in tw,'assertion released when the rule stops holding')
need('MYBConnFlag' in R('Shared/MYBConnectivity.h') and 'return switchOn&&hotspotUp&&clients>0' in R('Shared/MYBConnectivity.h'),'shared model')
ui=R('Preferences/MYBAdvancedController.m')
for name in('MYBAdvancedController','MYBConnectivityController','MYBExtraPrivacyController'):
    need(f'@interface {name}' in ui and name in R('Preferences/MYBMenuBase.m'),f'{name} exists and has a header style')
need('MYBAdvancedController.m' in R('Preferences/Makefile'),'controller is in the Preferences Makefile')
need('MYBConnectivityController' in R('Preferences/MYBMoreSettingsController.m') and 'MYBExtraPrivacyController' in R('Preferences/MYBModernController.m'),'Connectivity is in More Settings; Extra Privacy is on the main page')
need('Turn Off Anyway' in ui and 'Review in Settings' in ui,'hiding the network menu warns and offers review')
need('MOBILE_DATA_SETTINGS_ID' in ui,'link to the stock cellular page')
mk=R('Makefile');need('Companions/MYBConnectivity' in mk and 'Companions/MYBPrivatePhotos' in mk,'companions are built')
ph=R('Companions/MYBPrivatePhotos/Tweak.x')
need('DeletedSwitchOn() && HideChosen()' in ph,'hide needs the switch and the choice')
need('!AlbumSwitchOn()' in ph and 'DeletedSwitchOn() &&' in ph,'both gestures follow their switch')
need('MYXXEmptyRecentlyDeleted' in ph,'double hook guard')
pa=R('Companions/MYBPrivatePhotos/PrivateAlbum.m')
need('The original is still in Photos.' in pa and 'Permanent removal failed' not in pa,'Move failure wording')
need('remaining) success = NO' in pa,'Moved is claimed only after the originals are confirmed gone')
need('NSURLFileSizeKey' in pa,'copy size is checked')
ctl=R('control');need('com.myxxdev.emptyrecentlydeleted' in ctl.split('Conflicts:')[1].split('\n')[0] and 'Replaces:' in ctl,'package replaces the standalone Private Photos')
need('connectivity' in R('Helper/MYBDefaults.inc') and 'privacy' in R('Helper/MYBDefaults.inc'),'restore defaults turns the switches off')
need('Connectivity' in R('Shared/MYBHelp.h') and 'Extra Privacy Protection' in R('Shared/MYBHelp.h'),'Help covers the new tools')
if bad:
    print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Connectivity wiring checks passed')
