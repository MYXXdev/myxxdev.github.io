"""Browser inclusion/exclusion policy: the injection filter, the runtime checks and the diagnostics must all come from
Shared/MYBBrowserPolicy.h. Fails if they drift, if an unrelated process would be injected, or if a stale identifier remains."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
policy=(root/'Shared/MYBBrowserPolicy.h').read_text()
ids=re.findall(r'B\(@"([^"]+)"',policy)
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg);print('FAIL:',msg)
need(len(ids)==len(set(ids)) and len(ids)>=8,'policy lists each browser once')
plist=(root/'Companions/MYBShieldBrowser/MYBShieldBrowser.plist').read_text()
filt=re.findall(r'"([^"]+)"',plist)
need(sorted(filt)==sorted(ids),f'injection filter equals the policy list ({sorted(set(filt)^set(ids))})')
for must in ('com.apple.mobilesafari','org.mozilla.ios.Firefox','com.google.chrome.ios','com.microsoft.msedge','com.brave.ios.browser','com.opera.OperaTouch','com.duckduckgo.mobile.ios'):
    need(must in ids,f'{must} is covered')
for never in ('com.apple.springboard','com.apple.Preferences','com.apple.mobilemail','com.apple.SafariViewService','com.apple.mobileslideshow','com.apple.MobileSMS','com.apple.AppStore','com.apple.mobilephone'):
    need(never not in ids and never not in filt,f'{never} is never injected (not a browser / shared view service)')
need('*' not in plist and 'Executables' not in plist and 'Classes' not in plist,'filter is an explicit bundle list, never a wildcard or class filter')
tweak=(root/'Companions/MYBShieldBrowser/Tweak.xm').read_text()
need('MYBBrowserInjects(hostBundle())' in tweak,'ctor injects only policy browsers')
need('isEqual:@"com.apple.mobilesafari"' not in tweak and 'containsObject:NSBundle.mainBundle.bundleIdentifier' not in tweak,'no hard-coded Safari-only runtime restriction remains')
need('MYBBrowserSupports(hostBundle(),@"popups")' in tweak and 'MYBBrowserSupports(hostBundle(),@"page")' in tweak,'popup and blocked-page paths consult the policy per capability')
bridge=(root/'BlockedServer/BrowserBridge.h').read_text()
need('"B22"' not in bridge and '@"B22"' not in bridge and '@"RC3"' not in bridge and '@"RC3"' not in (root/'BlockedServer/main.m').read_text(),'no hard-coded B22/RC3 identifiers in diagnostics')
need('MYBBrowserInjects(app)' in bridge,'telemetry accepts exactly the policy browsers')
for phase in ('window_hook_seen','popup_allowed','popup_blocked','permission_consumed','host_unsupported','shield_off','popup_trace'):
    need(f'@"{phase}"' in bridge,f'telemetry allowlist accepts {phase}')
    need(phase in tweak,f'tweak emits {phase}')
ver=re.search(r'MYB_COMPONENT_VERSION "([^"]+)"',(root/'Shared/MYBVersion.h').read_text()).group(1)
ctl=re.search(r'^Version: (.+)$',(root/'control').read_text(),re.M).group(1).strip()
need(ver==ctl,f'component version {ver} equals package version {ctl}')
print('Browser policy checks '+('FAILED' if bad else 'passed'));sys.exit(1 if bad else 0)
