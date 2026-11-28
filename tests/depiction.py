#!/usr/bin/env python3
"""The Sileo depiction must be valid native JSON, use only known classes, match the package version, and `control` must
not point at any external URL."""
import json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
d=json.loads((root/'Depiction/net.myxxdev.mybloxx15.json').read_text())
known={'DepictionTabView','DepictionStackView','DepictionMarkdownView','DepictionHeaderView','DepictionTableTextView'}
bad=[]
def walk(n):
    if isinstance(n,dict):
        c=n.get('class')
        if c and c not in known:bad.append('unknown class '+c)
        for v in n.values():walk(v)
    elif isinstance(n,list):
        for v in n:walk(v)
walk(d)
dump=json.dumps(d)
if 'RH-15-112526' not in dump:bad.append('depiction does not show the release RH-15-112526')
if re.search(r'EXP|RC\\d|\\bR[0-9]\\b|6\\.11252026',dump):bad.append('depiction shows an internal version or a suffix')
ctl=(root/'control').read_text()
if re.search(r'https?://',ctl) or 'Depiction:' in ctl:bad.append('control has an external URL or depiction field')
if 'every browser' in json.dumps(d).lower() and 'does not claim' not in json.dumps(d).lower():bad.append('universal browser claim')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Depiction checks passed.')
