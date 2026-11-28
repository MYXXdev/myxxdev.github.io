"""Help text must agree with the code it describes, and the PAC Script viewer must stay read-only and private."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
R=lambda p:(root/p).read_text()
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg)
help_=R('Shared/MYBHelp.h');ctl=R('Preferences/MYBHelpController.m')
need('500' not in help_,'help does not mention a rule limit')
need('Repair MYbloXX' in help_ and 'Repair MYbloXX' in R('Preferences/MYBTroubleshootingController.m'),'Repair MYbloXX exists')
for name in ('Reset iOS Connection Cache','Restore Default Settings','Back Up Now','Check a Website','Spoof Supervision','Exact Differences'):
    need(name in help_ and any(name in f.read_text() for f in (root/'Preferences').glob('*.m')),f'help mentions "{name}" which must exist as a control')
need('api.github.com' not in help_ and 'GitHub' in help_,'privacy help names GitHub only')
tsh=R('Preferences/MYBTroubleshootingController.m')
http=re.findall(r'https?://[^\s"\\]+',help_+ctl)
need(http==[],f'the guides carry no external link: {http}')
need([u for u in re.findall(r'https?://[^\s"\\]+',tsh) if 'superadblocktest' not in u and '127.0.0.1' not in u]==['https://discord.gg/s33Xn4sX5f','https://t.me/MYXXdevSupport','https://myxxfm.com/donate'],'Help & Repair carries only the two support links the project names (Telegram group, donation page)')
need('Discord' not in help_+ctl and 'MYBPushWeb(self,row[@"url"]' in tsh,'the guides name no outside service; support links open in the Settings browser')
need('GitHub' not in ctl and 'openRules' not in ctl,'no GitHub rules row remains in Help')
# PAC viewer
v=R('Preferences/MYBPACViewController.m');h=R('Helper/MYBPACView.inc');d=R('Preferences/MYBDiagnosticsController.m')
need('editable=NO' in v and 'selectable=NO' in v,'script view is not editable or selectable')
need('unlink' in v or 'removeItemAtPath' in v,'snapshot file is deleted after reading')
need('0600' in h or '0600' in h.replace('0','0') ,'snapshot is private')
code=re.sub(r'//[^\n]*','',h)
need('HTTP' not in code and 'listen(' not in code and 'bind(' not in code,'no endpoint in the snapshot writer')
need('"pacview"' in R('Shared/MYBHelperArgs.h') or '@"pacview"' in R('Shared/MYBHelperArgs.h'),'helper action registered')
need(not re.search(r'PACView|pacview',R('Preferences/MYBDiagnosticsController.m').replace('MYBPACViewController','').replace('PAC Script','')),'diagnostics copy does not include the script')
need('Active' not in v.replace('In Use','') or 'Confirmed by iOS' in v,'viewer never calls an unconfirmed script active')
need('MYBPACViewController' in d,'viewer reachable from Status & Diagnostics')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Help and PAC viewer checks passed.')
