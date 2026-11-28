#!/usr/bin/env python3
"""The Shield tokens must equal the Settings implementation (MYBDesign.m), not an invented palette."""
import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
t=json.loads((root/'Brand/design-tokens.json').read_text())['dark']
src=(root/'Preferences/MYBDesign.m').read_text()
def fn(name):
    m=re.search(r'UIColor \*%s\(void\)\{return \[UIColor colorWithRed:([\d.]+) green:([\d.]+) blue:([\d.]+) alpha:1\];\}'%name,src);assert m,name
    return [float(x) for x in m.groups()]
pairs={'background':'MYBBackground','panel':'MYBPanel','panelHighlight':'MYBPanelHighlight','accent':'MYBAccent','muted':'MYBMuted','positive':'MYBPositive','warning':'MYBWarning','danger':'MYBDanger'}
fails=[]
for k,f in pairs.items():
    if fn(f)!=t[k]:fails.append(f'{k}: tokens {t[k]} != Settings {fn(f)}')
rose=re.search(r'case MYBToneRose:return \[UIColor colorWithRed:([\d.]+) green:([\d.]+) blue:([\d.]+)',src);
if [float(x) for x in rose.groups()]!=t['rose']:fails.append('rose tone differs')
if 'colorWithWhite:1 alpha:.07' not in src or t['hairlineAlpha']!=0.07:fails.append('hairline differs')
hdr_src=(root/'Preferences/MYBDesign.h').read_text()
glass=(root/'Preferences/MYBGlass.m').read_text()
if 'self.radius=28' not in glass or not re.search(r'MYBCardRadius\s+20\.0',hdr_src):fails.append('radii changed in Settings')
css=(root/'BlockedServer/tokens.generated.css').read_text();hdr=(root/'Shared/MYBShieldTheme.h').read_text()
for name in ('#090B10','#B59EFF'):
    if name not in css:fails.append('css lacks '+name)
if 'MYBShieldAccent' not in hdr:fails.append('UIKit header missing')
if fails:print('\n'.join('FAIL: '+f for f in fails));sys.exit(1)
print('Design tokens match the Settings implementation')
