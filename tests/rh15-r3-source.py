# RH-15-112526 (third pass): defaults, supervision first install, subpage titles, Photos tip, support rows, copy.
import re,sys,pathlib
R=lambda p:pathlib.Path(p).read_text()
bad=[]
def need(c,m):
    if not c:bad.append(m);print('FAIL:',m)
d=R('Shared/MYBDefaults.h');inc=R('Helper/MYBDefaults.inc');sup=R('Shared/MYBSupervision.h');keys=R('Shared/MYBSupervisionKeys.h')
# fresh-install defaults
need('enabled-' not in d and '@"speedyAds"' in inc and 'd[@"speedyAds"]=@{}' in inc,'every App Switch Control app starts unselected')
need('@"mode":@"Default"' in d and 'Hide' not in d and 'PrivateAlbum' not in d and 'Proxy' not in d,'defaults apply no optional mode, no Photos hiding and no proxy')
need('d[@"preferences"]=@{}' in inc,'no saved preference (private photos, proxy override) is set by a default')
# supervision on a fresh install: only management keys block it; bookkeeping keys do not
need('MYBSupervisionHasManagementKeys(details)' in sup and 'details.count>' not in sup,'iOS bookkeeping keys no longer make the device ineligible (the first-install regression)')
need('"Organization"' in keys.replace('@"','"') and 'MDM' in keys and 'ConfigurationURL' in keys,'organisation, MDM and enrolment keys mark a managed device')
need('MYBSupervisionEligibleForDefault' in inc and inc.index('MYBSupervisionEligibleForDefault')<inc.index('int rc=MYBApplyDefaultsSetup(setup,exceptions);',inc.index('MYBSupervisionEligibleForDefault')),'first install asks for eligibility before applying')
msg=R('Shared/MYBSupervisionMessage.h')
need('This device is supervised and shielded by MYbloXX®' in msg and 'MYB_SUPERVISION_TEXT_EXISTING_ON' in msg,'branded banner text and the truthful text for someone else\'s supervision')
tw=R('Companions/MYBSupervisionSign/Tweak.xm')
need('systemBlueColor' in tw and 'UITapGestureRecognizer' in tw and 'openMYbloXXSettings' in tw,'the MYbloXX® word is tappable and opens the pane')
# subpage title reveal
mb=R('Preferences/MYBMenuBase.m')
need('mybRevealsTitle' in mb and 'scrollViewDidScroll' in mb and 'subTitleLabel' in mb and 'CGRectGetMidY(h)' in mb,'subpages reveal the small title from the middle of the hero title, like the main screen')
need('mybRevealsTitle' in R('Preferences/MYBDesign.m'),'the bar draws no title at rest on subpages')
# Photos tip: both gestures, one sheet
pt=R('Companions/MYBPrivatePhotos/Tweak.x')
need('hold Recently Deleted for three seconds to hide or show its items' in pt and 'Tap the Albums title at the top five times' in pt and 'Utilities' in pt and pt.count('MYXXShowTipFactsOnce')>=1,'the Photos tip shows both gestures in one sheet')
# support rows: only destinations the project names
hr=R('Preferences/MYBTroubleshootingController.m')
need('https://t.me/MYXXdevSupport"' in hr and 'https://myxxfm.com/donate' in hr and 'https://discord.gg/s33Xn4sX5f' in hr,'Help & Repair ships Discord, Telegram and the donation page')
# tour: the older compact card, one size on every page, demonstrations that play once and cancel on leaving
wc=R('Companions/MYBShieldRedirects/Welcome.h')
need('textMin' in wc and 'swapGen' in wc and 'pulseGen' in wc and 'playBadge' in wc and 'skipTop' not in wc and 'canvas' not in wc,'tour card keeps one size, page swaps cancel each other, one flourish per page in a fixed slot')
need('UIBlurEffect' not in wc and 'HUGE_VALF' not in wc,'no glass blur and nothing that loops')
# settings: no second rebuild during a push, title view exists before the push, dashboard does not rebuild unchanged
need('viewWillAppear' not in R('Preferences/MYBTileBase.m'),'tile pages are not rebuilt a second time while they are pushed')
need('- (UINavigationItem *)navigationItem' in mb and '- (void)setTitle:' in mb and 'heroNameLabel' in mb,'subpage title view is ready before the push and the hero label is found once')
md=R('Preferences/MYBModernController.m')
need('[self.menuSections isEqual:next]' in md and 'Return to Native Protection' not in md,'the dashboard is not rebuilt when nothing changed and has one Supervision & Legacy Mode row')
# banner: falls back on the helper status when Settings cannot read the system file
need('statusOwned' in tw and 'net.myxxdev.mybloxx.supervision.plist' in tw and '@"managed"' in R('Shared/MYBSupervision.h'),'the banner falls back on the helper status when Settings cannot read iOS files')
need('MYBSupervisionSign' in R('Makefile'),'the banner component is part of the package build')
# copy
shipped=''.join(R(f) for f in __import__('glob').glob('Preferences/*.m'))+R('Shared/MYBHelp.h')+R('Companions/MYBShieldRedirects/Welcome.h')
need('…' not in shipped and '—' not in shipped,'literal three dots and no em dashes in app text')
need("MYB_RELEASE_LABEL \"RH-15-112526\"" in R('Shared/MYBVersion.h'),'exact release label')
sys.exit(1 if bad else print('RH-15-112526 pass-three source checks passed.') or 0)
