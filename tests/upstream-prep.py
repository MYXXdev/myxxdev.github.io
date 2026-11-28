"""The upstream rules tree is complete: every standalone mode and EVERY historical alias is regenerated, aliases are byte copies of their target,
the set of PAC names covers every name a published profile references, and canonical.json travels with them."""
import json, subprocess, sys, tempfile
from pathlib import Path
root = Path(__file__).resolve().parents[1]; tmp = Path(tempfile.mkdtemp())
subprocess.run([sys.executable, str(root / 'tools/prepare-upstream.py'), str(tmp)], check=True, stdout=subprocess.DEVNULL)
d = tmp / 'MYbloXX'; C = json.loads((root / 'rules/canonical.json').read_text()); bad = []
def need(c, m):
    if not c: bad.append(m)
names = {p.stem for p in d.glob('*.pac')}
expect = {'Default', 'allowY', 'blockAdSense', 'blockApple', 'blockSocials', 'blockXXX'} | set(C['aliases'])
need(names == expect, 'published PAC names differ: missing %s extra %s' % (sorted(expect - names), sorted(names - expect)))
need(len(C['aliases']) == 8 and len(names) == 14, 'eight aliases and fourteen published PACs (got %d / %d)' % (len(C['aliases']), len(names)))
for a, t in C['aliases'].items():
    need((d / (a + '.pac')).read_bytes() == (d / (t + '.pac')).read_bytes(), '%s.pac is not a byte copy of %s.pac' % (a, t))
    need((d / (a + '.pac')).read_bytes() == (root / 'layout/usr/share/mybloxx/pacs' / (a + '.pac')).read_bytes(), '%s.pac differs from the bundled alias' % a)
for n in ('MYbloXXTest', 'MYbloXXallowFB', 'MYbloXXnoFB'):
    need((d / (n + '.pac')).exists(), n + '.pac is regenerated')
need((d / 'canonical.json').read_bytes() == (root / 'rules/canonical.json').read_bytes(), 'canonical.json travels with the PACs')
# every published profile points at one of these names (profile list from the app's own legacy mapping test data)
src = json.loads((root / 'tests/pac-sources.json').read_text())['aliases']
need(set(src) == set(C['aliases']), 'the app test data and canonical agree on the aliases')
txt = (d / 'RULES.md').read_text()
need(all(a + '.pac' in txt for a in C['aliases']), 'RULES.md lists every alias file')
if bad: print('\n'.join('FAIL ' + b for b in bad)); sys.exit(1)
print('upstream tree: 14 PACs (6 standalone + 8 aliases), aliases are byte copies, canonical.json included')
