"""One tile pattern: the same component and selection behaviour wherever a screen switches between views of one list."""
import sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
R=lambda p:(root/p).read_text()
bad=[]
def need(ok,msg):
    if not ok:bad.append(msg)
d=R('Preferences/MYBDesign.m');h=R('Preferences/MYBDesign.h')
need('MYBTileStrip' in h and 'MYBTileApplySelection' in h,'shared tile strip is declared')
sel=d[d.index('void MYBTileApplySelection'):][:700]
need('.55' in sel and 'UIAccessibilityTraitSelected' in sel,'selected tile is bright, others dim, and VoiceOver hears Selected')
need('MYBTileStrip(tileSpecs' in d[d.index('UIView *MYBStatHero'):],'the stat header is built from the same strip')
pc=R('Preferences/MYBPopupControlController.m');rd=R('Preferences/MYBRedirectController.m');rc=R('Preferences/MYBRulesController.m');ac=R('Preferences/MYBActivityController.m')
need('MYBTileStrip' in pc and 'UISegmentedControl' not in pc and 'Blocked' in pc and 'URLs' in pc,'Pop-Up Control uses Blocked / Allowed / URLs tiles, no segmented control')
need('MYBTileApplySelection' in rd and 'UISegmentedControl' not in rd,'App Redirect Protection uses the shared selection')
need('selectedList' in rc and 'segmentTitles{return @[]' in rc,'Custom Rules picks its list with tiles, no segmented control')
need('MYBTileApplySelection' in rc and 'MYBTileApplySelection' in ac,'Custom Rules and Activity apply the shared selection')
need('filter' in ac and 'tileSelection' in ac,'Activity app pages pick their view with tiles')
need('mybNavExtras' in rc and 'mybNavExtras' in rd and 'filter' in ac,'the selected tile survives leaving and returning')
need('accessibilityValue=count' in pc or 'accessibilityValue=texts' in R('Preferences/MYBTileBase.m')+ac,'each tile speaks its count')
labels=['Sites Allowed to Open Windows','Sites Always Blocked from Windows','Recent Pop-Up Attempts','history only, not rules','separate from Website Rules']
need(all(l in pc.replace('They are','They are') or l in pc for l in labels[:4]) and 'separate from Website Rules' in pc,'popup permissions and history are labelled by scope')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Tile pattern checks passed.')
