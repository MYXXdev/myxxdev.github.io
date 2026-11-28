"""Static wiring checks for the RC5.3 screens: structure and wording that the rendered previews cannot assert on their own."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
R=lambda p:(root/p).read_text()
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg)
modern=R('Preferences/MYBModernController.m');body=modern[modern.index('- (NSArray *)supportRows{'):modern.index('- (UITableViewCell *)tableView')]
first=body[body.index('NSMutableArray *top='):body.index('@{@"title":@"BROWSER & APP PROTECTION"')]
titles=re.findall(r'@"title":@"([^"]+)"',first)
need([t for t in titles if t not in('YOUR BLOCKING','WEBSITE BLOCKING')]==['Protection','Blocking Mode','Custom Rules','Activity'],'dashboard group order is Protection, Blocking Mode, Custom Rules, Activity (got %s)'%titles)
need(body.index('Custom Rules')<body.index('BROWSER & APP PROTECTION'),'Custom Rules is not repeated lower down')
need(body.count('@"Custom Rules"')==1,'Custom Rules appears once')
more=R('Preferences/MYBMoreSettingsController.m')
need('Supervision & Legacy Mode' in R('Preferences/MYBModernController.m') and 'Supervision & Appearance' not in R('Preferences/MYBLegacyController.m')+body+more and 'DNS Profiles' in more and 'DNS & Profiles' not in body+more,'renamed entries (Legacy Profiles & Supervision and DNS Profiles live in More Settings)')
for name in ['Pop-Up Control','App Redirect Protection','In-App Ad Blocking','App Switch Control','Backup & Updates','More Settings','Help & Repair']:
    need(('@"title":@"%s"'%name) in body,'main menu row: '+name)
for name in ['DNS Profiles','Proxy Override','Connectivity','PIN Protection','Updates','Backup & Restore']:
    need(('@"title":@"%s"'%name) in more,'More Settings / Backup & Updates row: '+name)
need('@"title":@"App Switch Control"' not in more.split('@interface MYBBackupUpdatesController')[0] and '@"title":@"Help & Repair"' not in more and '@"title":@"Troubleshooting"' not in body and '@"title":@"Help & Tips"' not in body,'App Switch Control and Help & Repair have one home each (the main page)')
# a row that names a page must be opened by the base class, so no screen can silently ignore it again
base=R('Preferences/MYBMenuBase.m');did=base[base.index('didSelectRowAtIndexPath:(NSIndexPath *)p {'):]
need('entry[@"page"]' in did[:700] and 'pushViewController' in did[:900],'base class opens page rows (root cause of the dead Legacy PAC Profiles button: rows asked for an "openPage" selector nobody implemented)')
for f in sorted((root/'Preferences').glob('*.m')):
    t=f.read_text()
    for m in re.finditer(r'@"action":@"openPage"',t):
        need('@"page"' in t[max(0,m.start()-200):m.end()+40] ,f.name+': an openPage row without a page')
dns=R('Preferences/MYBDNSController.m');need('Legacy PAC Profiles' not in dns and 'DNS Profiles' in dns,'DNS Profiles holds DNS only; PAC profiles live in Legacy Mode')
leg=R('Preferences/MYBLegacyController.m')
need(leg.index('@"title":@"Spoof Supervision"')<leg.index('@"title":@"Hide Supervision Message"')<leg.index('STEP 2'),'Hide Supervision Message sits directly under Spoof Supervision')
need(re.search(r'Spoof Supervision.{0,400}Hide Supervision Message',leg,re.S) is not None and 'Install a local profile' not in leg,'profile rows use the Blocking Mode descriptions, not "Install a local profile"')
need('stringByAppendingString:@" Profile"' in leg and 'MYBModeTable()' in leg,'profiles are named "<mode> Profile" from the shared catalogue')
need('MYBModeWarning(mode,YES)' in leg and 'MYBModeWarning(added,NO)' in R('Preferences/MYBModernController.m'),'blockAdSense warning before applying (mode) and installing (profile)')
need('supervised"] boolValue]' in leg and 'Supervision Needed First' in leg and 'Enable Supervision & Continue' in leg and 'Supervision Not Confirmed' in leg,'a profile is not offered before supervision is on')
cat=R('Shared/MYBModeCatalog.h');need('blockAdSense may prevent Facebook and Messenger sign-in' in cat and 'switch to Default if you have trouble signing in' in cat,'warning carries the required sentences')
need(re.findall(r'Spoof|spoof',leg) and 'confirm:' in leg and 'iOS asks you to review and install it' in leg and 'installing it is your confirmation' in leg,'iOS confirmation preserved; opening a download is not described as installing')
apps=R('Preferences/MYBAppControlController.m')
need('One switch' not in apps and 'Temporarily pauses MYbloXX' in apps and 'whole phone' in apps and '_applicationIconImageForBundleIdentifier' in apps and 'NSCache' in apps,'App Control: concise explanation, cached real icons')
need(apps.count('dispatch_async(MYBIconQueue()')==1 and 'MYBIconPending' in apps,'icons load once per app off the main thread')
rules=R('Preferences/MYBPopupControlController.m')
need('MYBChoose(self,@"Popup Strictness"' not in rules and '@"pick"' in rules,'popup strictness is a selection screen, not an action sheet')
st=R('Preferences/MYBPopupStrictnessController.m')
need('Blocks every new window until you allow the site' in st and 'blocks windows that open on their own' in st.lower().replace('Blocks','blocks') and 'UITableViewCellAccessoryCheckmark' in st,'strictness wording mirrors the policy and the selection is obvious')
tr=R('Preferences/MYBTroubleshootingController.m')
need('https://superadblocktest.com' in tr and 'turtlecute' not in tr and '/mybloxx-window-test' in tr and 'MYBPushWeb' in tr and 'Open in Browser' not in R('Preferences/MYBWebController.m').split('- (void)viewDidLoad')[1].split('- (void)openInBrowser')[0],'protection test shortcuts open only when tapped')
need('MYBRevealRows(self.tableView)' not in base,'no entrance animation after arrival (the menu-entry jump)')
need(base.count('[self rebuildMenu]')<=5 and 'if(self.revealed)' in base,'viewWillAppear no longer rebuilds the menu a second time during the push')
d=R('Preferences/MYBDesign.m')
need('configureWithTransparentBackground' in d and 'configureWithOpaqueBackground' not in d,'navigation bar is transparent at rest so the screen background runs behind it')
need('borderWidth=.75' in d,'logo container has a subtle frame')
dfl=R('Helper/MYBDefaults.inc');need('MYBFillAbsentDefaults' in dfl and 'if(!have)' in dfl,'a leftover install without a baseline record is completed, not mistaken for a configured one')
rules=R('Preferences/MYBPopupControlController.m');redir=R('Preferences/MYBRedirectController.m');allsrc=''.join(f.read_text() for f in (root/'Preferences').glob('*.m'))
need('Redirect' not in rules.replace('redirects','') or 'MYBRedirectSetAsk' not in rules,'Pop-Up Control has no redirect switch')
need('MYBRedirectSetAskAppStore' in redir and 'MYBRedirectSetAskOtherApps' in redir and 'RedirectEnabled' not in redir and 'RedirectOtherApps' not in redir,'App Redirect Protection has two independent switches that go through the policy helper (older keys are never written here)')
need('@"title":@"Other App Redirects"' not in allsrc,'the two older switch names are not rows any more')
need('MYBPopupListController' in rules and 'Allowed Popup Sites' in rules and 'Always Blocked Popup Sites' in rules and 'Recent Popups' in rules,'popup lists live in Pop-Up Control')
need('MYBTileListBase' in redir and 'listIndex' in redir and 'Blocked Attempts' in redir and 'RECENT' in redir and 'ALLOWED' in redir,'redirect lists live in App Redirect Protection')
need('MYBShieldClearActivityTypes' in rules and 'MYBShieldClearActivityTypes' in redir and 'MYBShieldClearActivity(' not in rules+redir,'clearing history is scoped to its own type and never clears permissions')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('UI wiring checks passed.')
# Shield routing: the subclass must override the selector the base class actually reads (the old override of a stale name made Shield show Custom Rules).
_sh=R('Preferences/MYBPopupControlController.m');_base=R('Preferences/MYBRulesController.m')
need('- (BOOL)isShieldRules{return YES;}' in _sh,'Shield overrides isShieldRules')
for _m in re.findall(r'- \(BOOL\)(is\w+Rules)\{',_sh):
    need(('- (BOOL)%s{return NO;}'%_m) in _base,'Shield override %s exists in the base class'%_m)
need('heroTitle{return self.isShieldRules?@"MYbloXX® Shield":@"Custom Rules"' in _base,'Shield and Custom Rules have different titles')
