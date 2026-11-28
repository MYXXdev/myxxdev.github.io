"""One-time import: decode the six supplied PACs (rules/reference/) into rules/canonical.json.

After the import canonical.json is the source of truth and is edited by hand; rules/generate.py never reads the
reference PACs. The import is kept so the decoding can be re-run and audited.
"""
import json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import pacmodel as P

root = Path(__file__).parent
MODES = {'Default': None, 'allowY': 'allowY', 'blockAdSense': 'blockAdSense', 'blockApple': 'noApple',
         'blockSocials': 'noSocials', 'blockXXX': 'noXXX'}
M = {m: P.decode((root / 'reference' / (m + '.pac')).read_text()) for m in MODES}

def fwd(entry):           # stored reversed, optionally with a leading '.' once un-reversed (boundary marker)
    return entry[::-1].strip('.')

base = M['Default']
# The three entries in the unbounded table that carry a boundary dot ("tracker.twenga.") are host PREFIXES by intent
# and never matched anything. They become literal substrings.
legacy_dead = sorted(e[::-1] for e in base['suffixes'] if e[::-1].endswith('.') or e.endswith('.') )
domains = sorted({e[::-1] for e in base['suffixes'] if not e.endswith('.') and not e[::-1].endswith('.')} |
                 {fwd(e) for e in base['domains']})
canon = {
    'format': 1,
    'stamp': '11/15/26 - 11:25 MST',
    'transport': base['transport'],
    'base': {
        'allow': base['allow'], 'bypass': base['bypass'],
        'block': {'substrings': sorted(set(base['block']['substrings']) | set(legacy_dead)),
                  'chains': base['block']['chains'], 'file': base['block']['file']},
        'domains': domains,
        'kill': sorted(fwd(e) for e in base['kill']),
    },
    'order': ['allowY', 'blockAdSense', 'blockApple', 'blockSocials', 'blockXXX'],
    'options': {}, 'aliases': {}, 'exact_allow': [],
}
for mode, label in MODES.items():
    if mode == 'Default': continue
    m = M[mode]
    def dom(x): return {e[::-1] for e in x['suffixes'] if not e.endswith('.') and not e[::-1].endswith('.')} | {fwd(e) for e in x['domains']}
    add = sorted(dom(m) - dom(base)); rem = sorted(dom(base) - dom(m))
    kill = sorted({fwd(e) for e in m['kill']} - {fwd(e) for e in base['kill']})
    subs = sorted(set(m['block']['substrings']) - set(base['block']['substrings']))
    chains = [c for c in m['block']['chains'] if c not in base['block']['chains']]
    for k in ('allow', 'bypass'):
        for part in ('substrings', 'chains'):
            assert m[k][part] == base[k][part], (mode, k, part)   # no option changes the allow or bypass layers
    canon['options'][mode] = {'label': label, 'domains_add': add, 'domains_remove': rem, 'kill_add': kill,
                              'substrings_add': subs, 'chains_add': chains}
al = json.loads((Path(__file__).parent.parent / 'tests' / 'pac-sources.json').read_text())['aliases']
canon['aliases'] = al
(root / 'canonical.json').write_text(json.dumps(canon, indent=1, sort_keys=True, ensure_ascii=False) + '\n')
print('legacy dead entries made substrings:', legacy_dead)
print({k: (len(v['domains_add']), len(v['domains_remove']), len(v['kill_add']), len(v['substrings_add']), len(v['chains_add'])) for k, v in canon['options'].items()})
print('base domains', len(domains), 'kill', len(canon['base']['kill']))
