"""Source checks for the tappable MYbloXX word in the Settings supervision message. Nothing here is a device check."""
import sys
from pathlib import Path
r=Path(__file__).resolve().parents[1];bad=[]
t=(r/'Companions/MYBSupervisionSign/Tweak.xm').read_text()
def need(c,m):
    if not c:bad.append(m)
need('NSParagraphStyleAttributeName' in t and 'style.alignment=alignment' in t and 'textAlignment' in t,'the drawn text and the hit area use the same alignment')
need('used.size.height' in t and 'a label centres its text vertically' in t,'the hit area follows a label\'s vertical centring')
need('v.userInteractionEnabled=YES' in t and '![v isKindOfClass:UITableView.class]' in t,'every view between the text and the table accepts touches')
need(t.count('route=')>=3 and 'row-select' in t and 'showController' in t and 'prefs:root=MYbloXX%C2%AE' in t,'three routes to the MYbloXX page, each logged')
need('[supervision-tap]' in t and 'hit=%d' in t,'each tap writes what was hit')
need('ENABLE_LINK' not in t and 'enableProtection' not in t,'the message has no enable link: only the MYbloXX word is tappable')
need('MYBInstalledMYbloXXProfile' in t,'the message asks iOS whether a MYbloXX profile is installed')
if bad:
    print('\n'.join('FAIL '+b for b in bad));sys.exit(1)
print('Supervision tap source checks passed.')
