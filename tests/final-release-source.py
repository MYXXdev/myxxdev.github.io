"""Source-level checks for the RH-15-112526 final release. They read the real files; nothing here is a device check."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
R=lambda p:(root/p).read_text()
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg)
visible=['Preferences','Shared','BlockedServer','CCPreview','Helper']
# YouTopia is gone everywhere except the exact retired-file cleanup
for d in visible+['Companions']:
    for f in (root/d).rglob('*'):
        if f.is_file() and f.suffix in('.m','.h','.inc','.xm','.js','.plist') and 'YouTopia' in f.read_text(errors='ignore'):
            need(f.name=='MYBUninstall.inc',f'{f.relative_to(root)} still mentions YouTopia')
need('youTopiaChanged' not in R('Preferences/MYBModernController.m') and '@"youtopia"' not in R('Preferences/MYBModernController.m'),'no YouTopia switch on the dashboard')
need(not (root/'layout/Library/MobileSubstrate/DynamicLibraries/YouTopia.dylib').exists(),'YouTopia dylib is not in the package payload')
# no experimental wording on screens
for f in ['Preferences/MYBInAppAdsController.m','Preferences/MYBModernController.m','Shared/MYBHelp.h']:
    t=R(f);need('Experimental' not in t and 'experimental' not in t.lower().replace('// ',''),f'{f} shows experimental wording')
ia=R('Preferences/MYBInAppAdsController.m')
need('Hide ads inside supported apps' in R('Preferences/MYBModernController.m') and 'Experimental, per app' not in ia,'In-App Ad Blocking wording')
listing=ia.split('@interface MYBInAppAdsStatusController')[0]
lits=re.findall(r'@"([^"]*)"',listing)
need(not [l for l in lits if re.search(r'not verified|hooks? found|no hooks',l,re.I) and l not in('no-hooks-found',)],'the per-app list carries no verification label or hook counts; those live on the details screen')
need('MYBInAppAdsStatusController' in R('Preferences/MYBDiagnosticsController.m') or 'In-App Ad Blocking' in R('Preferences/MYBDiagnosticsController.m'),'diagnostics links to the In-App Ad Blocking details')
# Help and versions
need('github.com' not in R('Preferences/MYBHelpController.m') and 'MYBPACViewController' in (R('Preferences/MYBTroubleshootingController.m')+R('Preferences/MYBHelpController.m')+R('Preferences/MYBDiagnosticsController.m')),'no GitHub rules link; the read-only PAC viewer is kept')
need('MYB_RELEASE_LABEL' in R('Preferences/MYBTroubleshootingController.m') and 'Version & Licences' not in R('Preferences/MYBTroubleshootingController.m'),'Help & Repair shows a plain Release row')
ver=R('Shared/MYBVersion.h');need('EXP' not in ver.replace('EXPLORE','').split('#define MYB_RELEASE_LABEL')[1],'version constants carry no experimental suffix')
# supervision prerequisite
leg=R('Preferences/MYBLegacyController.m')
need('Enable Supervision & Continue' in leg and '@"spoof"' in leg and 'supervisionstatus' in leg and 'pendingPath' in leg and 'downloadProfile' in leg,'legacy: prerequisite, spoof action, status check and continuation')
need('settingsrefresh' not in leg,'legacy: enabling supervision no longer closes Settings')
need('Supervision Not Enabled' in leg and 'Supervision Not Confirmed' in leg,'legacy: failure is explained and not shown as ready')
need('UIApplication.sharedApplication openURL' not in leg and 'MYBDeliverProfile' in leg,'legacy profiles use the link / Save to Files delivery, never the default browser')
need('MYBDeliverProfile' in R('Preferences/MYBDNSController.m'),'DNS profiles use the same handoff')
# embedded web screen
web=R('Preferences/MYBWebController.m')
need('nonPersistentDataStore' in web and 'loadRequest' in web.split('- (void)viewDidLoad')[1],'web screen: private data store, Open in Browser, requests only when shown')
need('SFSafariViewController' not in web and 'SafariServices' not in web and 'Copy Profile Link' in web and 'Save Profile to Files' in web and 'UIActivityViewController' in web,'profiles: no in-app Safari view; copy link and Save to Files instead')
need('openURL' not in web.split('void MYBDeliverProfile')[1],'profile delivery never opens the default browser')
need('Open in Safari' not in R('Preferences/MYBWebController.m')+R('Preferences/MYBMenuBase.m')+R('Preferences/MYBDNSController.m')+R('Preferences/MYBLegacyController.m'),'nothing is labelled Open in Safari')
need('MYBDeliverProfile' in R('Preferences/MYBDNSController.m'),'DNS profiles use the same delivery')
tr=R('Preferences/MYBTroubleshootingController.m')
need('[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"http://127.0.0.1:8788/mybloxx-window-test"]' in tr and 'MYBPushWeb(self,@"https://testpages' not in tr,'the popup test opens in the default external browser')
sheet=R('Preferences/MYBDesign.m')
need('self.kind==MYBSheetSuccess;' in sheet and 'MAX(wait,4.5)' in sheet,'success sheets carry no button and dismiss themselves (longer with VoiceOver)')
need('if(ok){ _buttons=[NSMutableArray array];' in R('Shared/MYBShieldSheet.h'),'Shield success results dismiss themselves')
need('MYBPushWeb(self,@"https://superadblocktest.com",@"AdBlock Test",nil)' in R('Preferences/MYBTroubleshootingController.m'),'the Ad Blocker Test opens directly inside MYbloXX®, with no popup first')
# App Control
ac=R('Companions/MYBAppControl/Tweak.xm')
need('MYBAppPrep' in ac and 'Preparing %@' in ac and 'cancelPrep' in ac and 'retryPrep' in ac and 'continuePrep' in ac,'App Control: preparation overlay with Cancel, Retry and Continue')
need('initWithWindowScene:scene' in ac and 'MYBTrace(' in ac and 'Window created WITHOUT a scene' in ac and 'passthrough' in ac,'App Control: the overlay window is attached to the live scene, has diagnostics and a non-blocking confirmation')
need('250*NSEC_PER_MSEC' not in ac and 'if(needed)MYBShowPrep(0)' in ac and 'transition=entering&&![event isEqual:sentApp]' in ac,'App Control: no artificial delay, and heartbeat refreshes never show the overlay')
need('App Switch Raw Trace' in R('Preferences/MYBDiagnosticsController.m') and 'MYBAppSwitchActivityController' in R('Preferences/MYBAppControlController.m') and 'MYBAppControlTraceController' in R('Preferences/MYBAppControlController.m'),'App Control activity is visible in Status & Diagnostics')
need('SIGSTOP' not in ac and 'usleep(' in ac.split('static int MYBRunFocus')[1].split('static NSString *MYBTarget')[0],'App Control: nothing freezes an app; the helper wait is bounded and off the main thread')
need('MYBAppControlSelected(prefs,foreground)&&!MYBLocked()){MYBSubmit();return;}' in ac,'App Control: entering a selected app starts at once')
need('!=UIApplicationStateBackground' in R('Companions/SpeedyAds/Tweak.xm') and 'refreshRuntime(loadPrefs())' in R('Companions/SpeedyAds/Tweak.xm'),'SpeedyAds is armed as the library loads')
# scripts
post=R('layout/DEBIAN/postinst');need('quiet "$HELPER" initdefaults' in post and 'install.log' in post,'installer: routine helper output goes to a log')
need('remove)' in R('layout/DEBIAN/prerm') and 'deconfigure)' in R('layout/DEBIAN/prerm') and (root/'layout/DEBIAN/postrm').exists(),'lifecycle scripts distinguish removal from deconfigure and upgrade')
if bad:
    print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Final release source checks passed')
