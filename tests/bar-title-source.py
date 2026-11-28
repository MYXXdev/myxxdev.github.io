"""Source check: the main MYbloXX screen never draws a system bar title, so nothing shows before the header scrolls away."""
import sys
from pathlib import Path
r=Path(__file__).resolve().parents[1];bad=[]
d=(r/'Preferences/MYBDesign.m').read_text();m=(r/'Preferences/MYBModernController.m').read_text()
def need(c,m_):
    if not c:bad.append(m_)
need('scrolled.titleTextAttributes=@{NSForegroundColorAttributeName:brandedHeader?UIColor.clearColor:UIColor.whiteColor' in d,'the scrolled (standard) appearance hides the system title on the branded screen, so it cannot show on first load')
need('top.titleTextAttributes=@{NSForegroundColorAttributeName:brandedHeader?UIColor.clearColor' in d,'the at-rest appearance hides it too')
need(m.count('self.navigationItem.titleView=self.titleHost')>=2,'the faded bar title is kept as the title view on appearance and on scroll')
need('barTitle.alpha=0' in m,'the bar title starts invisible')
need('self.userScrolled?' in m and 'userScrolled=YES' in m,'the bar title stays at alpha 0 until the first real touch scroll')
need('self.navigationItem.title=@""' in m and 'backButtonTitle' in m,'no system title text; back label kept')
need('(void)mybEnsureBarTitle' in m and '(void)setSpecifier:' in m and 'setSpecifier:specifier];[self mybEnsureBarTitle]' in m,'the faded title view exists before the screen is pushed, so the stock title never draws')
if bad:
    print('\n'.join('FAIL '+b for b in bad));sys.exit(1)
print('Bar title source checks passed.')
