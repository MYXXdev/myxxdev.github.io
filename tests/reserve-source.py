#!/usr/bin/env python3
# MYXX Reserve (folded into MYbloXX, pass 15): scope, wiring, honest copy, nothing near delivery or carrier code.
import re,sys,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
def R(p):return (ROOT/p).read_text(encoding='utf-8')
bad=[]
def need(c,m):
    print(('ok   ' if c else 'FAIL ')+m)
    if not c:bad.append(m)
D='Companions/MYXXReserve/'
strip=lambda t:re.sub(r'//[^\n]*','',re.sub(r'/\*.*?\*/','',t,flags=re.S))
src=''.join(strip(R(D+f)) for f in ('Core/Tweak.m','Display/Display.m','Thermal/Thermal.m','Power/main.c','CC/RSVCCModule.m'))+strip(R('Preferences/MYBReserveController.m'))
need(not re.search(r'CommCenter|CarrierBundle|CTCellularPlan|CoreTelephony|IMDaemon|imagent|sms\.db|sqlite3',src),'Reserve has no CommCenter, carrier, eSIM, telephony or message-delivery code')
for f in ('Core/MYXXReserve.plist','Display/MYXXReserveDisplay.plist'):need('com.apple.springboard' in R(D+f) and 'UIKit' not in R(D+f),f+' loads in SpringBoard only, never every UIKit process')
need('thermalmonitord' in R(D+'Thermal/MYXXReserveThermal.plist') and 'Bundles' not in R(D+'Thermal/MYXXReserveThermal.plist'),'the CPU slowdown hook loads in thermalmonitord only')
need('Companions/MYXXReserve' in R('Makefile') and 'chmod 4755' in R('Makefile') and 'usr/libexec/myxxreserved' in R('Makefile'),'built with the package; the helper is made setuid so it starts as root')
need('MYBReserveController.m' in R('Preferences/Makefile') and '@"page":@"MYBReserveController"' in R('Preferences/MYBModernController.m'),'MYXX Reserve has a row on the main page and its screen is built')
ctl=R('control');need('com.myxxdev.reserve' in ctl and 'xyz.cypwn.sentinel' in ctl and 'ai.paisseon.reverie' in ctl,'the package replaces standalone Reserve and conflicts with Sentinel and Reverie')
ui=R('Preferences/MYBReserveController.m')
for k in ('enabled','autoEnter','spoofPercent','blockWakes','lowPowerMode','silenceFocus','pauseMedia','radioIsolation','throttleCPU','threshold','rearmMinutes'):need('"%s"'%k in ui or '@"%s"'%k in ui,'Settings controls '+k)
need('RSVRequestQuickTest' in ui and 'RSVRequestFullTest' in ui and 'RSVRequestPing' in ui,'the tests and the connection check are wired to SpringBoard')
need('@"radioIsolation",[NSNumber numberWithBool:NO]' in ui or '[NSNumber numberWithBool:NO],@"radioIsolation"' in ui,'Airplane Mode is off by default')
need('inside apps' in ui and 'MYBReserveDisplayBundles' in R('Helper/MYBAdsFilter.inc') and 'MYXXReserveDisplay.plist' in R('Helper/MYBAdsFilter.inc') and 'com.apple.UIKit' not in R('Shared/MYBAdsFilter.h').split('MYBReserveDisplayBundles')[1].split('MYBFilterDataMatches')[0].replace('![b isEqual:@"com.apple.UIKit"]',''),'the adjusted percentage reaches apps through a helper-written app list, never every UIKit process')
need('syncAppFilter' in ui and ui.count('adsfilter')>=1,'switching the adjusted percentage updates the app list')
need('RSV_VERSION' in ui and '0.2.2' in R(D+'Shared/RSVShared.h') and 'RSV_BUILD 22' in R(D+'Shared/RSVShared.h'),'Reserve 0.2.2 (build 22) is the version shown')
need('Sentinel or Reverie binaries' in R(D+'README-upstream-0.2.2.md'),'provenance note: original code, no Sentinel or Reverie binaries')
sys.exit(1 if bad else 0)
