"""Apply the RAGGR rule set (rules/reference/raggr-2026-11.json) to rules/canonical.json.

    python3 rules/raggr_apply.py "YYYY/MM/DD - HH:MM UTC" [--labels-cc2]

Idempotent. Base rules (domains, family chains, words, one allow word) go where every generator, including the one inside r16,
can use them. Host-only rules (labels, tokens, shapes) and the table dictionary go in the optional "compact" section that only
an engine-2 generator reads. Token and shape patterns are merged into equivalent shorter regexes (same matches, fewer bytes);
tests/raggr-rules.py proves the equivalence on the feed and the allow corpus samples.
"""
import collections, json, re, sys
from pathlib import Path
ROOT = Path(__file__).parent
sys.path.insert(0, str(ROOT))
import pacmodel as P

TOKEN = re.compile(r'^\(\?:\^\|\[\.-\]\)([a-z0-9]+)\(\?:-\[\^\.\]\*\)\?\\\.(\(\?!.*\))\[\^\.\]\+\\\.\[\^\.\]$')
SHAPE = re.compile(r'^\(\?:\^\|\\\.\)(\[[a-z0-9-]+\]|\\d)\{(\d+)\}\\\.([a-z.\\]+)\$$')

def merge_patterns(raw):
    """Tokens -> one trie pattern; label-aligned shapes on the same class and ending -> one pattern with length runs."""
    toks, guard, shapes, other = [], None, collections.defaultdict(list), []
    for p in raw:
        p2 = p.replace('\\-', '-')
        m = TOKEN.match(p2)
        if m:
            toks.append(m.group(1)); assert guard in (None, m.group(2)); guard = m.group(2); continue
        m = SHAPE.match(p2)
        if m: shapes[(m.group(1), m.group(3))].append(int(m.group(2))); continue
        other.append(p2)
    out = []
    if toks: out.append('(?:^|[.-])%s(?:-[^.]*)?\\.%s[^.]+\\.[^.]' % (P.literals_regex(toks)[1:-1], guard))
    for (cls, end), lens in sorted(shapes.items()):
        lens = sorted(set(lens)); runs = []
        for n in lens:
            if runs and n == runs[-1][1] + 1: runs[-1][1] = n
            else: runs.append([n, n])
        alts = ['%s{%d}' % (cls, a) if a == b else '%s{%d,%d}' % (cls, a, b) for a, b in runs]
        out.append('(?:^|\\.)%s\\.%s$' % (alts[0] if len(alts) == 1 else '(?:' + '|'.join(alts) + ')', end))
    return out + sorted(other)

FREE = list("!#$%&'()*+/:;<=>?@[]^_`{}~WYZ")
def sdict(s, maxlen=12, max_rules=400):
    """Greedy substring dictionary (the research codec): replace the substring with the best net saving by an unused code."""
    singles = [c for c in FREE if c != '~' and c not in s]
    pool2 = list("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,-./:;<=>?@[]^_`{|}'")
    rules, used2 = [], 0
    assert '~' not in s and '"' not in s and '\\' not in s and ' ' not in s
    while len(rules) < max_rules:
        if singles: code = singles[0]
        elif used2 < len(pool2): code = '~' + pool2[used2]
        else: break
        cnt = collections.Counter(); n = len(s)
        for L in range(2, maxlen + 1):
            for i in range(0, n - L + 1): cnt[s[i:i + L]] += 1
        best, gain = None, 0
        for w, f in cnt.items():
            if f < 3 or len(w) <= len(code): continue
            if f * (len(w) - len(code)) - (len(w) + len(code) + 1) <= gain: continue
            g = s.count(w) * (len(w) - len(code)) - (len(w) + len(code) + 1)
            if g > gain: best, gain = w, g
        if not best: break
        s = s.replace(best, code); rules.append(code + best)
        if len(code) == 1: singles.pop(0)
        else: used2 += 1
    return s, rules

def matches_pattern(u, r):
    o = 0
    for j, s in enumerate(r[1]):
        if j == len(r[1]) - 1 and not r[0]:
            a = len(u) - len(s)
            if a < o or u[a:] != s: return False
        else:
            a = u.find(s, o)
            if a < 0: return False
        o = a + len(s)
    return True

def xxx_match(xxx, d):
    u = 'https://%s/' % d
    under = lambda h, e: h == e or h.endswith('.' + e)
    return (any(w in u for w in xxx['substrings_add']) or any(under(d, e) for e in xxx['kill_add'] + xxx['domains_add'])
            or any(matches_pattern(u, c) for c in xxx['chains_add']))

def main(stamp, labels_cc2):
    canon_path = ROOT / 'canonical.json'
    C = json.loads(canon_path.read_text()); D = json.loads((ROOT / 'reference/raggr-2026-11.json').read_text())
    b = C['base']
    named = set()
    for o in C['options'].values(): named |= set(o['domains_add']) | set(o['domains_remove'])
    red = set(D['domains_remove_redundant']); assert not red & named, 'an option names a redundant domain'
    # noXXX PIN: the helper asks for the PIN when noXXX is the reason a host is blocked (blocked with noXXX, not without).
    # A Default domain that noXXX's own rules already match would take that protection away, so it stays out of the base list
    # (noXXX keeps blocking it exactly as before).
    xxx = C['options']['blockXXX']
    keep_add = [d for d in D['domains_add'] if not xxx_match(xxx, d)]
    held_xxx = sorted(set(D['domains_add']) - set(keep_add))
    # Allow words run before every block (r16 design, kept). A domain that one of them matches for the domain AND every
    # subdomain can never block anything ("roads" in ad.broadstreetads.com): it is left out instead of shipping dead bytes.
    allow_words = b['allow']['substrings']
    dead = sorted(d for d in keep_add if any(w in 'https://%s/' % d and w in 'https://x.%s/' % d for w in allow_words))
    keep_add = [d for d in keep_add if d not in dead]
    b['domains'] = sorted((set(b['domains']) - red) | set(keep_add))
    C['stamp'] = stamp
    C['hybrid']['raggr'] = {'source': D['source'], 'reference': 'rules/reference/raggr-2026-11.json', 'items': len(D['items']),
                            'domains_add': len(keep_add), 'domains_remove_redundant': len(D['domains_remove_redundant']),
                            'held_for_noXXX_pin': held_xxx, 'dead_under_allow_words': dead}
    # Everything that is not a plain domain is engine-2 only: an older generator (r16) builds the base rules without it, so an
    # r16 device gets the extra domains and nothing that could change how its own noXXX PIN check sees a host.
    C['compact'] = {'format': 2, 'host_labels': sorted(D['host_labels']), 'host_patterns': merge_patterns(D['host_patterns_research']), 'table_dict': [],
                    'chains_add': D['chains_add'], 'substrings_add': sorted(D['substrings_add']), 'allow_substrings_add': sorted(D['allow_substrings_add'])}
    if labels_cc2: C['compact']['labels_cc2'] = True
    # The dictionary is learned once on Default's table and applied to every mode (each mode verifies its own round trip).
    import generate as G
    G.CANON = C; G.ORDER = C['order']
    A, T = G._table(G.effective([])['domains'])
    _, rules = sdict(','.join(A) + '|' + ','.join(T))
    C['compact']['table_dict'] = rules
    why = G.validate_compact(C)
    if why: raise SystemExit('compact rules rejected: ' + why)
    canon_path.write_text(json.dumps(C, indent=1, sort_keys=True) + '\n')
    print('canonical.json: %d domains, %d labels, %d host patterns, %d dictionary entries, stamp %s' % (
        len(b['domains']), len(C['compact']['host_labels']), len(C['compact']['host_patterns']), len(rules), stamp))

if __name__ == '__main__':
    main(sys.argv[1], '--labels-cc2' in sys.argv[2:])
