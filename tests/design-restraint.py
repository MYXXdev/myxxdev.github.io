#!/usr/bin/env python3
"""Source-level guards for the restrained design (RC5.2). Each one is a defect that reached a device screenshot."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
R=lambda p:(root/p).read_text()
bad=[]
def need(c,m):
    if not c:bad.append(m)
d=R('Preferences/MYBDesign.m');g=R('Preferences/MYBGlass.m')
# 1. the system separator must really be switched off: a `//` earlier on the line comments the statement out
sep=[l for l in d.split('\n') if 'separatorStyle=UITableViewCellSeparatorStyleNone' in l]
need(sep and all('//' not in l.split('separatorStyle')[0] for l in sep),'table separators must be disabled by live code, not a commented-out statement')
# 2. a statement must never share a line after a // comment in the design files (that is how #1 happened)
for f in ['MYBDesign.m','MYBGlass.m','MYBPrismCell.m','MYBMenuBase.m','MYBModernController.m','MYBModeInfoController.m','MYBTroubleshootingController.m']:
    for n,l in enumerate(R('Preferences/'+f).split('\n'),1):
        code=re.sub(r'"(?:[^"\\]|\\.)*"','""',l)
        m=re.search(r'//(.*)$',code)
        if m and re.search(r';\s*[A-Za-z_\[]',m.group(1)) and 'http' not in l and not m.group(1).strip().startswith(('(','Never','Rows','no ','static','one ','plain')):
            if re.search(r'\w+\.\w+=.*;\s*\w+\.\w+=',m.group(1)):bad.append(f'{f}:{n} statement-looking code inside a // comment')
# 3. nothing animates forever
for f in (root/'Preferences').glob('*.m'):
    t=f.read_text()
    need('HUGE_VALF' not in t and 'repeatCount' not in t,f'{f.name}: continuous animation')
need('MYBPulse' not in d+g and 'MYBAmbientView' not in d+g,'ambient/pulse effects are gone')
# 4. glass is for floating sheets only
for f in (root/'Preferences').glob('*.m'):
    if f.name in('MYBDesign.m','MYBGlass.m'):continue
    need('MYBGlassView' not in f.read_text(),f'{f.name}: glass surface outside a sheet')
need(sum('MYBGlassView' in l for l in d.split('\n'))==1,'MYBDesign.m uses glass only for the sheet card')
# 5. the dashboard is short and does not list modes
m=R('Preferences/MYBModernController.m')
body=m[m.index('- (NSArray *)buildSections{'):m.index('- (void)rebuildMenu{')]
need(body.count('@"title":@"')<=22,'dashboard is long')
need('modesExpanded' in m and 'BOOL modesExpanded' in m and '@"title":@"Custom Rules"' in body,'Blocking Mode expands inline and Custom Rules follows it directly')
need('performBatchUpdates' in m and 'setContentOffset' not in m[m.index('- (void)toggleModes'):m.index('- (void)styleExpander')],'expanding animates rows without moving the scroll offset')
# 6. modes screen: icons and casing, Custom Rules not a mode
cat=R('Shared/MYBModeCatalog.h')
mo=R('Preferences/MYBModeInfoController.m')+cat # the catalogue moved to Shared so Legacy Mode uses the same names and descriptions
tbl=cat[cat.index('MYBModeTable(void){'):cat.index('// Shown before')]
need('@"allowY",@"icon":@"y.circle"' in tbl and 'play.rectangle' not in tbl,'allowY is Yahoo!-related: no YouTube-style play icon')
need('blockAdSense' in tbl and 'blockAdsense' not in mo,'blockAdSense casing')
need('Custom Rules' not in tbl,'Custom Rules is not a blocking mode')
# 7. identifiers and PAC content untouched by presentation
need(re.findall(r'@"mode":@"(\w+)"',tbl)==['Default','allowY','blockAdSense','blockApple','blockSocials','blockXXX'],'mode identifiers unchanged')
# 8. one title treatment everywhere: bar title visible at rest, no tall in-content title
need('brandedHeader?UIColor.clearColor:UIColor.whiteColor' in d and 'mybHasBrandedHeader' in R('Preferences/MYBModernController.m'),'bar title is white on every screen except the dashboard, whose branded header owns the top')
need('MYBRoundedFont(34' not in d,'no 34pt in-content titles')
need('shadowColor=[UIColor colorWithWhite:1 alpha:.08]' not in d,'no hairline under the navigation bar')
# 9. headers: dashboard header has no card or pills
hero=d[d.index('UIView *MYBDashboardHero'):d.index('@implementation MYBSectionHeaderView')]
need('MYBGlassView' not in hero and 'pill(' not in hero,'dashboard header is plain')
# 9b. restrained glass: grouped rows are one translucent surface with no border; glass sheets stay the only blur
pc=R('Preferences/MYBPrismCell.m')
need('MYBGroupFill()' in pc and 'panel.layer.borderWidth' not in pc and 'borderWidth=.5' not in pc,'rows use the group fill and carry no border')
need('UIVisualEffectView' not in pc and 'UIVisualEffectView' not in d,'no blur per row or in the dashboard')
need('MYBReduceTransparency()?MYBPanel()' in g,'group fill is solid under Reduce Transparency')
# 10. selective colour: row icons are violet unless flagged
mb=R('Preferences/MYBMenuBase.m');need('accent' in mb,'icon colour is selective')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Design restraint checks passed.')
