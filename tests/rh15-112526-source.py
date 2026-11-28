"""RH-15-112526 source checks: the label, the retired Browser Rules switch, inline browser rules, redirect history allows, page memory,
Export Domains, the Photos look and gestures, and the Move safeguards. Source-level only: nothing here claims on-device behaviour."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
R=lambda p:(root/p).read_text()
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg)
LABEL='RH-15-112526'
# ---- label: one visible label everywhere, no suffix or prefix
need(f'#define MYB_RELEASE_LABEL "{LABEL}"' in R('Shared/MYBVersion.h'),'release label')
need(f'RELEASE_LABEL="{LABEL}"' in R('layout/DEBIAN/postinst') or f'RELEASE_LABEL={LABEL}' in R('layout/DEBIAN/postinst'),'installer label')
for f in ('Depiction/net.myxxdev.mybloxx15.json','.github/workflows/build-deb-only.yml'):
    need(LABEL in R(f),'label in '+f)
visible=''.join(R(f) for f in ('Preferences/MYBHelpController.m','Preferences/MYBModernController.m','Shared/MYBHelp.h','Depiction/net.myxxdev.mybloxx15.json'))
need('RH-15-111926' not in visible and 'RH-15-111626' not in visible,'no older visible label')
need(not re.search(r'RH-15-112526[-_ ][A-Za-z0-9]',R('Shared/MYBVersion.h')),'label has no suffix')
need(re.search(r'^Version: 6\.11252026',R('control'),re.M) is not None,'Debian version sorts above the installed build')
# ---- Browser Rules switch retired, readers de-gated, migration and restore normalize
shield=R('Shared/MYBShield.h')
need('MYBShieldNormalizedRules' in shield,'normalizer exists')
verdict=shield[shield.index('MYBShieldPopupVerdict(NSDictionary'):][:600]
need('Enabled' not in verdict.split('}')[0] and 'BlockPopups' in verdict,'popup verdict needs only BlockPopups')
need('MYBMigrateBrowserRules' in R('Helper/MYBDefaults.inc') and R('Helper/MYBDefaults.inc').index('MYBMigrateBrowserRules();')<R('Helper/MYBDefaults.inc').index('MYBFillAbsentDefaults(&') ,'migration runs first in initDefaults')
setup=R('Helper/MYBSetup.inc')
need('MYBShieldNormalizedRules' in setup and 'MYBNoteBrowserRulesWereOff' in setup,'restoring a backup normalizes and notes it')
tweak=R('Companions/MYBShieldBrowser/Tweak.xm')
need('shouldBlock' in tweak and not re.search(r'\[\s*\w+\s*objectForKey:@"Enabled"\]|\[@"Enabled"\]',tweak),'browser tweak does not read Enabled')
allm=''.join(f.read_text() for f in (root/'Preferences').glob('*.m'))
need('Use My Browser Rules' not in allm.replace('Use My Browser Rules, ','') and '"Blocked Page Notices"' not in allm and 'MYBBrowserRulesController' not in allm,'retired rows and submenu are gone')
pc=R('Preferences/MYBPopupControlController.m')
order=[pc.index(x) for x in ('BLOCK BROWSER POP-UPS','WEBSITE RULES IN YOUR BROWSER','POP-UP PERMISSIONS')]
need(order==sorted(order),'page order: Block Browser Pop-Ups, Website Rules, Pop-Up Permissions')
need('MYBTileStrip' in pc and 'UISegmentedControl' not in pc and '@"action":@"add"' in pc and 'editKind' in R('Preferences/MYBRulesController.m'),'inline list with Add, same editor')
# ---- App Redirect Protection: history allow is scoped and shares the live store
rd=R('Preferences/MYBRedirectController.m')
need('MYBShieldAddGrantFor' in rd and 'offerAllowForEntry' in rd and 'Allow Once' in rd and 'Always Allow' in rd,'history allow uses the shared permission store')
need(re.search(r'scheme\s*\?|hasScheme|@"scheme"\]',rd) is not None,'Allow Once depends on a recorded scheme')
need('tap the original link again' in rd,'history allow says tap the link again')
need('MYBShieldDismissActivity' in rd and 'MYBShieldClearActivityTypes' in rd,'dismiss one entry; clear history events only')
need('Opened' not in re.sub(r'//.*','',rd),'never claims Opened without evidence')
# ---- page memory
mb=R('Preferences/MYBMenuBase.m')
need('MYBNavRestore' in mb and 'MYBNavSave' in mb and 'WillEnterForeground' in mb and 'mybRefreshInPlace' in mb,'page memory and in-place refresh')
wl=mb[mb.index('setWithArray:@[@"MYBRulesController"'):][:900]
need('MYBPinController' not in wl and 'MYBLegacyController' not in wl and 'MYBPACViewController' not in wl,'PIN, Legacy and PAC screens are never restored')
need('12*3600' in mb.replace(' ','') or '43200' in mb,'saved route expires')
need('MYBNavClear' in R('Preferences/MYBModernController.m'),'root appearance clears stale state')
# ---- Export Domains
rc=R('Preferences/MYBRulesController.m')
need('Export Domains' in rc and 'exportTextForBlocked' in rc and 'UIActivityViewController' in rc and '[pattern]' in rc,'Export Domains: text, share, patterns')
need('writeToFile' in rc and 'removeItemAtURL' in rc or 'removeItemAtPath' in rc,'temporary export file is removed')
need('Nothing to Export' in rc,'empty export is explained')
# ---- Photos: shared look, top-title gesture with fallback, Move safeguards, scoping
pa=R('Companions/MYBPrivatePhotos/PrivateAlbum.m');tw=R('Companions/MYBPrivatePhotos/Tweak.x');ui=R('Companions/MYBPrivatePhotos/PrivateUI.m')
need('UIAlertController' not in pa and 'UIAlertController' not in tw,'Photos uses MYbloXX® sheets, not stock alerts')
need('MYBShieldSheet.h' in ui and 'MYBShield' in ui,'Photos shares the Shield sheet code')
need('Recently Deleted: Visible' in tw and 'Recently Deleted: Hidden' in tw and 'minimumPressDuration = 3' in tw,'exact Recently Deleted text and 3-second hold')
need('myxx_titleTaps' in tw and 'numberOfTapsRequired = 5' in tw and 'AlbumsTitleLabel' in tw and 'TouchOnAlbumsTitle' in tw,'five taps on the Albums title')
need('AlbumsTitleAvailable' in tw,'tab gesture only remains as a fallback when the title cannot be found')
need('UIApplicationDidEnterBackgroundNotification' in tw,'backgrounding resets the count and locks the album')
need('Copied to Private Album' in pa and 'The original is still in Photos.' in pa and 'Moved to Private Album' in pa,'Move failure and success wording')
need('fileSize' in pa and pa.count('fetchAssetsWithLocalIdentifiers')>=2,'Move verifies size and confirms removal')
need('com.apple.mobileslideshow' in tw and 'com.apple.mobileslideshow' in R('Companions/MYBPrivatePhotos/MYBPrivatePhotos.plist'),'hooks are scoped to Photos')
need('Move' in pa and 'permanently removed from Photos' in pa,'Move asks first and says what happens')
# ---- tips and tour
need('MYBTipShowOnce' in pc and 'MYBTipShowOnce' in rd and 'MYBTipsReplay' in R('Preferences/MYBTroubleshootingController.m'),'tips with replay')
need('Dismissed' in R('Preferences/MYBTips.m') and 'ReplayCount' in R('Preferences/MYBTips.m') and 'ReplayCount' in R('Companions/MYBPrivatePhotos/PrivateUI.m'),'dismissal is remembered; Photos honours Replay Tips')
wc=R('Companions/MYBShieldRedirects/Welcome.h')
need('MYXXdev™ suggests blockAdSense' in wc and 'graph.facebook.com' in wc and 'Facebook and Messenger sign-in' in wc and 'Your choice' in wc,'tour recommends blockAdSense, says what it changes, warns about sign-in and leaves the choice')
need('MYBTourPageCount' in wc and wc.count('@"h":@"')==6 and 'UIAccessibilityIsReduceMotionEnabled' in wc and 'accessibilityViewIsModal' in wc and 'UIAccessibilityTraitHeader' in wc and 'UIFontMetrics' in wc and 'UIContentSizeCategoryIsAccessibilityCategory' in wc,'tour is six short pages and works with Reduce Motion, VoiceOver and larger text')
need('settleIntro' in wc and 'UISwipeGestureRecognizer' in wc and 'viewTapped' in wc and 'secondaryClose' in wc and 'swapGen' in wc,'taps, swipes and Skip work during the opening and page changes')
need(all(k in wc for k in ('MYBTourBlocked','MYBTourPopups','MYBTourApps','playBadge','flourish')),'each page has one badge with its own one-shot flourish, inside its own slot')
need('net.myxxdev.mybloxx.welcome.replay' in wc and 'net.myxxdev.mybloxx.welcome.replay' in R('Preferences/MYBTroubleshootingController.m') and 'welcomeObserveReplay()' in R('Companions/MYBShieldRedirects/Tweak.xm'),'the tour can be replayed from Help & Repair')
need('*Recommended' in R('Preferences/MYBModernController.m') and 'blockAdSenseRecommended' in R('Preferences/MYBModernController.m') and 'TourSawRecommendation' in R('Preferences/MYBModernController.m') and 'TourSawRecommendation' in wc,'*Recommended label plus a one-time tip that is skipped when the tour already said it')
need('Advanced Diagnostics' in R('Preferences/MYBDiagnosticsController.m') and 'Advanced Diagnostics' in R('Preferences/MYBTroubleshootingController.m') and 'PAC Script' in R('Preferences/MYBDiagnosticsController.m') and 'MYBHelpController' not in R('Preferences/MYBModernController.m'),'Help & Repair has one destination; logs, traces and the PAC are under Advanced Diagnostics')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('RH-15-112526 source checks passed.')
