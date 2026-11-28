"""Source guards for the profile presentation flow (UIKit cannot run on CI; the rules themselves are tested by tests/sheet-flow-native.m)."""
import re,sys
from pathlib import Path
r=Path(__file__).resolve().parents[1];f=[]
def rd(p):return (r/p).read_text()
def c(ok,m):
    print(('PASS ' if ok else 'FAIL ')+m)
    if not ok:f.append(m)
d=rd('Preferences/MYBDesign.m');leg=rd('Preferences/MYBLegacyController.m');dns=rd('Preferences/MYBDNSController.m');web=rd('Preferences/MYBWebController.m');base=rd('Preferences/MYBMenuBase.m')
c('MYBSheetFlowModel' in d and 'requestDecision' in d and 'requestStatus' in d and 'decisionGone' in d,'every sheet goes through the one flow model')
c('sheetTopmost(sheet)' in d and d.count('dismissViewControllerAnimated:YES completion:nil];})')>=1 and 'if(sheet.generation==generation&&sheetTopmost(sheet))' in d,'the auto-dismiss timer never dismisses a sheet that has another sheet above it')
c('if(sheetTopmost(sheet))[sheet dismissViewControllerAnimated:NO' in d,'MYBDismissStatus never takes down a covered sheet')
c('self.gone' in d and 'viewDidDisappear' in d,'a decision sheet reports when it has left the screen')
c('MYBDeliverProfileFile' in leg and 'MYBDeliverProfileFile' in dns,'DNS and Legacy both deliver through the one coordinator')
c('Save Profile to Files' in web and 'Copy Profile Link' in web and 'Open Device Management' in web,'Save to Files, Copy Link and Open Device Management fallbacks are kept')
c('static BOOL MYBProfileBusy' in web and 'if(MYBProfileBusy)return;' in web,'repeated taps while a profile is being prepared are ignored')
c('@"legacyprepare"' in base.split('BOOL quiet=')[1].split(';')[0],'the prerequisite step (legacyprepare) shows no separate Applied sheet')
c('MYBProgress(self,@"Preparing Profile")' in leg,'the Legacy prerequisite and the delivery share one progress sheet')
c('pendingPath' in leg and 'wanted' in leg and 'supervised' in leg,'the chosen profile survives the supervision step and continues afterwards')
sys.exit(1 if f else 0)
