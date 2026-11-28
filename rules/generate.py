"""Deterministic PAC generator. Reads rules/canonical.json only.

    python3 rules/generate.py [outdir]

Writes every option combination (32 files, named by MYBModeID: "Default", "allowY", "allowY+blockAdSense", ...), the six
historical standalone names (the single-option ids are the same files) and the legacy aliases (byte copies).
The same code path builds the modern effective PAC base and the standalone legacy PACs, so they cannot drift.
"""
import itertools, json, re, sys
from datetime import datetime
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import pacmodel as P

ROOT = Path(__file__).parent
CANON = json.loads((ROOT / 'canonical.json').read_text())
STAMP_FORMAT = '%Y/%m/%d - %H:%M UTC'
stamp = datetime.strptime(CANON['stamp'], STAMP_FORMAT)
if not 2000 <= stamp.year <= 2099 or stamp.strftime(STAMP_FORMAT) != CANON['stamp']:
    raise ValueError('bad UTC stamp')
ORDER = CANON['order']

def mode_id(options):
    chosen = [o for o in ORDER if o in options]
    return '+'.join(chosen) if chosen else 'Default'

def all_ids():
    out = []
    for n in range(len(ORDER) + 1):
        for combo in itertools.combinations(ORDER, n):
            out.append(mode_id(combo))
    return sorted(out, key=lambda i: (i.count('+') if i != 'Default' else -1, i))

def _antichain(entries):
    """Drop entries already covered by a parent entry (a.b.c when b.c is listed). The PAC tables find the entry just below the
    queried reversed host, so a child sorted between a parent and its other subdomains would hide the parent."""
    S = set(entries)
    return {d for d in S if not any('.'.join(d.split('.')[i:]) in S for i in range(1, len(d.split('.'))))}

def effective(options):
    """The effective rule model for a set of options. Precedence between options is explicit and order independent:
    every option's exemptions (domains_remove) are applied to the Default domain list first, then every option's
    additions are applied. So an option that BLOCKS something always wins over another option's exemption of it."""
    b = CANON['base']
    sel = [CANON['options'][o] for o in ORDER if o in options]
    domains = set(b['domains'])
    for o in sel: domains -= set(o['domains_remove'])
    for o in sel: domains |= set(o['domains_add'])
    kill = set(b['kill']); subs = set(b['block']['substrings']); chains = [list(c) for c in b['block']['chains']]
    for o in sel:
        kill |= set(o['kill_add']); subs |= set(o['substrings_add'])
        for c in o['chains_add']:
            if c not in chains: chains.append(c)
    X = CANON.get('compact') or {}
    subs |= set(X.get('substrings_add', []))
    for c in X.get('chains_add', []):
        if c not in chains: chains.append(list(c))
    domains, kill = _antichain(domains), _antichain(kill)
    return {'domains': sorted(domains), 'kill': sorted(kill), 'substrings': sorted(subs), 'chains': chains}

def effective_exact_allow(options):
    """Exact-host exceptions for a mode: the always-on list plus hosts that stay DIRECT unless one of the named options is chosen."""
    hosts = set(CANON['exact_allow'])
    for h, unless in CANON.get('exact_allow_unless', {}).items():
        if not any(o in options for o in unless): hosts.add(h)
    return hosts

def _table(entries_forward):
    rev = sorted(e[::-1] + '.' for e in set(entries_forward))
    return P.front_encode(rev)

def _arr(name, entries):
    if not entries: return 'var %s=[]' % name
    return 'var %s="%s".split(",")' % (name, ','.join(entries))

# ---- optional "compact" section (engine 2): byte-for-byte twin of the same code in rules/generate.js ----
HOST_HOOK = 'matchesPattern(u,BLOCK_PATTERNS)||'
DICT_FN = 'function MYBd(s,R){for(var i=R.length-1,k;i>=0;i--){k=R[i].charAt(0)=="~"?2:1;s=s.split(R[i].substring(0,k)).join(R[i].substring(k))}return s}'
CC2 = r'(?!(?:com?|gov|ac|org|net|edu|go|gob|or|ne|blogspot)\.[a-z]{2,3}$)'

def dict_code(r): return r[:2] if r[0] == '~' else r[0]
def dict_encode(s, R):
    for r in R:
        k = dict_code(r); s = s.replace(r[len(k):], k)
    return s
def dict_decode(s, R):
    for r in reversed(R):
        k = dict_code(r); s = s.replace(k, r[len(k):])
    return s

def _esc(ch): return '\\' + ch if ch in '.\\/+*?[](){}|^$' else ch

def host_regex(X):
    parts = []
    if X['host_labels']: parts.append('^' + P.literals_regex(X['host_labels'])[1:-1] + '\\.' + (CC2 if X.get('labels_cc2') else '') + '[^.]+\\.')
    return '|'.join(parts + list(X['host_patterns']))

def chain_regex(chains):
    groups = {}
    for c in chains: groups.setdefault(c[1][1], []).append(c[1][0])
    return '|'.join(P.literals_regex(groups[s])[1:-1] + '.*' + ''.join(_esc(ch) for ch in s) for s in sorted(groups))

def apply_compact(out, eff, A, T):
    X = CANON.get('compact')
    if not X: return '', ''
    merge = [c for c in eff['chains'] if c[0] and len(c[1]) == 2]; keep = [c for c in eff['chains'] if not (c[0] and len(c[1]) == 2)]
    for i, line in enumerate(out):
        if line.startswith('var BLOCK_PATTERNS='): out[i] = 'var BLOCK_PATTERNS=%s;' % json.dumps(keep, separators=(',', ':'))
    extra = hook = ''
    if merge: extra += 'var BLOCK_CHAIN_RE=/%s/;' % chain_regex(merge); hook += 'BLOCK_CHAIN_RE.test(u)||'
    hr = host_regex(X)
    if hr: extra += 'var HOST_BLOCK=/%s/;' % hr; hook += 'HOST_BLOCK.test(h)||'
    if X['table_dict'] and A:
        payload = ','.join(A) + '|' + ','.join(T); enc = dict_encode(payload, X['table_dict'])
        if dict_decode(enc, X['table_dict']) == payload:
            for i, line in enumerate(out):
                if line.startswith('var BLOCKED_DOMAIN_ROOTS='):
                    out[i] = ('var Q=MYBd("%s","%s".split(" ")).split("|");var BLOCKED_DOMAIN_ROOTS=Q[0].split(","),BLOCKED_DOMAIN_SUFFIXES=Q[1].split(",");' % (enc, ' '.join(X['table_dict']))) + DICT_FN + 'var BLOCKED_DOMAIN_CACHE=[];'
    return extra, hook

COMPACT_GUARD = ['example.com', 'www.example.com', 'login.microsoftonline.com', 'raw.githubusercontent.com', 'www.apple.com', 'www.icloud.com', 'www.google.com', 'www.facebook.com', 'www.instagram.com', 'www.youtube.com', 'm.youtube.com', 'dns.google']
PROTECTED = ['apple.com', 'icloud.com', 'mzstatic.com', 'ocsp.apple.com', 'googleapis.com', 'github.com', 'githubusercontent.com', 'microsoftonline.com', 'login.live.com', 'facebook.com', 'instagram.com', 'youtube.com', 'google.com']

def validate_compact(C):
    """Same acceptance rules as validateCompact in rules/generate.js; '' when acceptable."""
    if 'compact' not in C: return ''
    X = C['compact']
    if not isinstance(X, dict) or X.get('format') != 2 or not all(isinstance(X.get(k), list) for k in ('host_labels', 'host_patterns', 'table_dict')): return 'compact rules are malformed'
    if 'labels_cc2' in X and not isinstance(X['labels_cc2'], bool): return 'compact rules are malformed'
    for k in ('substrings_add', 'allow_substrings_add'):
        v = X.get(k, [])
        if not isinstance(v, list) or any(not isinstance(e, str) or not e or len(e) > 253 for e in v): return 'compact %s has a bad entry' % ('words' if k == 'substrings_add' else 'allow words')
    ch = X.get('chains_add', [])
    if not isinstance(ch, list) or any(not (isinstance(e, list) and len(e) == 2 and isinstance(e[0], bool) and isinstance(e[1], list) and e[1] and all(isinstance(x, str) and x and len(x) <= 253 for x in e[1])) for e in ch): return 'compact patterns has a bad entry'
    if len(X['host_labels']) > 2000 or len(X['host_patterns']) > 500 or len(X['table_dict']) > 1000: return 'compact rules are too large'
    for l in X['host_labels']:
        if not isinstance(l, str) or not re.fullmatch(r'[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?', l): return 'compact rules have a bad host label'
    for p in X['host_patterns']:
        if not isinstance(p, str) or not p or len(p) > 400 or not re.fullmatch(r'[a-z0-9^$|?:*+()\[\]{}\\.,=!-]+', p): return 'compact rules have a bad host pattern'
        try: re.compile(p)
        except re.error: return 'compact rules have a bad host pattern'
    codes = set()
    for r in X['table_dict']:
        if not isinstance(r, str) or not re.fullmatch(r'[!#-\[\]-~]+', r) or len(r) < (3 if r[0] == '~' else 2): return 'compact rules have a bad dictionary entry'
        k = dict_code(r)
        if k in codes: return 'compact rules have a bad dictionary entry'
        codes.add(k)
    hr = host_regex(X)
    if hr:
        rx = re.compile(hr)
        for h in COMPACT_GUARD + PROTECTED:
            if rx.search(h): return 'a protected service is blocked in Default: ' + h
    return ''

_why = validate_compact(CANON)
if _why: raise ValueError(_why)

def build(options):
    eff = effective(options); b = CANON['base']; t = CANON['transport']; mid = mode_id(options)
    names = {'allowY': 'allowY!', 'blockApple': 'noApple', 'blockSocials': 'noSocials', 'blockXXX': 'noXXX'}
    title = ' + '.join(names.get(name, name) for name in mid.split('+'))
    out = ['//', '// MYbloXX by MYXXdev (%s)' % title, '// Updated: %s' % CANON['stamp'],
           '// Support Development: myxxfm.com/donate', '//']
    out.append('var MYbloXX="%s";\nvar ALLOW="%s";\nvar BYPASS="%s";' % (t['block'], t['allow'], t['bypass']))
    out.append('var ALLOW_RULES=%s;' % P.literals_regex(b['allow']['substrings'] + (CANON.get('compact') or {}).get('allow_substrings_add', [])))
    out.append('var ALLOW_PATTERNS=%s;' % json.dumps(b['allow']['chains'], separators=(',', ':')))
    out.append('var BYPASS_RULES=%s;' % P.literals_regex(b['bypass']['substrings']))
    out.append('var BYPASS_PATTERNS=%s;' % json.dumps(b['bypass']['chains'], separators=(',', ':')))
    out.append('var BLOCK_RULES=%s;' % P.literals_regex(eff['substrings']))
    out.append('var BLOCK_PATTERNS=%s;' % json.dumps(eff['chains'], separators=(',', ':')))
    out.append('var BLOCKED_FILES=%s;' % b['block']['file'])
    A, T = _table(eff['domains']); AT = (A, T); out.append(_arr('BLOCKED_DOMAIN_ROOTS', A) + ';' + _arr('BLOCKED_DOMAIN_SUFFIXES', T) + ';var BLOCKED_DOMAIN_CACHE=[];')
    if eff['kill']:
        A, T = _table(eff['kill'])
        out.append('var PRIORITY_DOMAIN_ROOTS="%s".split(",");var PRIORITY_DOMAIN_CACHE=[];' % ','.join(A)); out.append('var PRIORITY_DOMAIN_SUFFIXES="%s".split(",");' % ','.join(T))
    else:
        out.append('var PRIORITY_DOMAIN_ROOTS=[];var PRIORITY_DOMAIN_SUFFIXES=[];var PRIORITY_DOMAIN_CACHE=[];')
    ok = {h: 1 for h in sorted(effective_exact_allow(options))}
    out.append('var ALLOWED_HOSTS=%s;' % json.dumps(ok, separators=(',', ':')))
    extra, hook = apply_compact(out, eff, *AT); rt = (ROOT / 'runtime.txt').read_text().rstrip('\n')
    if extra: out.append(extra)
    if hook:
        if rt.count(HOST_HOOK) != 1: raise ValueError('runtime has no single block hook')
        rt = rt.replace(HOST_HOOK, HOST_HOOK + hook, 1)
    out.append(rt)
    return '\n'.join(out[:5]) + '\n' + ''.join(out[5:]).replace('\n', '') + '\n'

def main(outdir):
    out = Path(outdir); out.mkdir(parents=True, exist_ok=True)
    keep = set()
    for i in all_ids():
        opts = [] if i == 'Default' else i.split('+')
        (out / (i + '.pac')).write_text(build(opts)); keep.add(i + '.pac')
    for alias, target in sorted(CANON['aliases'].items()):
        (out / (alias + '.pac')).write_text((out / (target + '.pac')).read_text()); keep.add(alias + '.pac')
    for f in out.glob('*.pac'):
        if f.name not in keep: f.unlink()
    print('wrote %d PAC files to %s' % (len(keep), out))

def sync_generator(dest):
    """The package carries the canonical rules and the JavaScript generator so the device can build every combination itself."""
    import shutil
    d = Path(dest); d.mkdir(parents=True, exist_ok=True)
    for name in ('canonical.json', 'generate.js', 'runtime.txt'): shutil.copyfile(ROOT / name, d / name)

if __name__ == '__main__':
    if len(sys.argv) > 1: main(sys.argv[1])
    else:
        main(str(ROOT.parent / 'layout/usr/share/mybloxx/pacs')); sync_generator(ROOT.parent / 'layout/usr/share/mybloxx/generator')
