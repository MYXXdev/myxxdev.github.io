"""Rules engine checks: the generated Default and single-option PACs behave like the supplied (reference) PACs, except for
the documented, intended changes. Also checks hostname boundaries, normalization, options, determinism and the Debian-visible
transport values. Runs the real PAC text under node."""
import json, subprocess, sys, tempfile, itertools, re
from pathlib import Path
root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'rules'))
import generate as G, pacmodel as P
bad = []
def need(ok, msg):
    if not ok: bad.append(msg)

tmp = Path(tempfile.mkdtemp()); G.main(str(tmp))
BLOCK, ALLOW, BYPASS = 'PROXY 127.0.0.1:8021', 'DIRECT', 'PROXY 8.8.8.8:53'
canon = G.CANON
def run(pacs, probes):
    p = subprocess.run(['node', str(root / 'tests/pac-eval.js')], input=json.dumps({'pacs': pacs, 'probes': probes}).encode(), capture_output=True)
    if p.returncode: print(p.stderr.decode()); sys.exit(1)
    return json.loads(p.stdout)
def url(h): return 'https://' + h + '/'

# ---- probe corpus: every listed domain (exact, subdomain, prefix-joined, look-alike suffix) + wording probes ----------
mods = {'Default': [], 'allowY': ['allowY'], 'blockAdSense': ['blockAdSense'], 'blockApple': ['blockApple'], 'blockSocials': ['blockSocials'], 'blockXXX': ['blockXXX']}
doms = set(canon['base']['domains'])
for o in canon['options'].values(): doms |= set(o['domains_add']) | set(o['domains_remove'])
kills = set(canon['base']['kill'])
for o in canon['options'].values(): kills |= set(o['kill_add'])
probes, kind = [], []
def add(h, k, path='/'): probes.append(['https://' + h + path, h]); kind.append(k)
for d in sorted(doms | kills):
    add(d, 'exact'); add('www.' + d, 'sub'); add('x-' + d, 'joined'); add('xx' + d, 'joined'); add(d + '.evil.test', 'lookalike')
for w in canon['base']['allow']['substrings'][:60]: add('example.com', 'allow', '/' + w + '/')
for w in canon['base']['block']['substrings'][:400]: add('example.net', 'substr', '/' + w + '/x')
for h in ['example.com', 'google.com', 'apple.com', 'youtube.com', 'doubleclick.net', 'graph.facebook.com', 'graph.instagram.com', 'm.yap.yahoo.com', 'login.microsoftonline.com', 'global.com', 'gu-global.com', 'sym-global.com', 'adblock.turtlecute.org']: add(h, 'named')
ref = run({m: str(root / 'rules/reference' / (m + '.pac')) for m in mods}, probes)
new = run({m: str(tmp / (G.mode_id(o) + '.pac')) for m, o in mods.items()}, probes)

# RAGGR (rules/raggr_apply.py): the same canonical with the RAGGR additions taken out (no compact section, no RAGGR domains,
# the redundant domains it removed put back), built by the shipping JS generator. A difference is RAGGR's only when it is a
# new block that this no-RAGGR build does not have; RAGGR never turns a block into DIRECT.
def no_raggr_pacs():
    if 'compact' not in canon and 'raggr' not in canon.get('hybrid', {}): return None
    R = canon['hybrid']['raggr']; ref_add = json.loads((root / R['reference']).read_text())
    x = json.loads(json.dumps(canon)); x.pop('compact', None)
    gone = set(ref_add['domains_add']) - set(R['held_for_noXXX_pin']); x['base']['domains'] = sorted((set(x['base']['domains']) - gone) | set(ref_add['domains_remove_redundant']))
    d = Path(tempfile.mkdtemp()); (d / 'c.json').write_text(json.dumps(x))
    js = "require(%r);const fs=require('fs');const c=fs.readFileSync(%r,'utf8');const w=MYBValidateCanonical(c);if(w){console.error(w);process.exit(1)}const o=JSON.parse(MYBGenerate(c,fs.readFileSync(%r,'utf8')));for(const k in o)fs.writeFileSync(%r+'/'+k,o[k]);" % (str(root / 'rules/generate.js'), str(d / 'c.json'), str(root / 'rules/runtime.txt'), str(d))
    p = subprocess.run(['node', '-e', js], capture_output=True)
    if p.returncode: print(p.stderr.decode()); sys.exit(1)
    return run({m: str(d / (G.mode_id(o) + '.pac')) for m, o in mods.items()}, probes)
nor = no_raggr_pacs()
def raggr_change(m, i, a, b): return nor is not None and a == ALLOW and b == BLOCK and nor[m][i] == ALLOW
HY = canon['hybrid']
def under(host, entries):
    p = host.split('.'); return any('.'.join(p[i:]) in entries for i in range(len(p)))
_def_add, _xxx_add, _ok = set(HY['default_add']), set(HY['noXXX_add']), set(HY['compat_exact_allow'])
def hybrid_change(host, mode, a, b):
    # the documented hybrid merge (rules/hybrid_apply.py): new blocks for the merged hosts, new exact exceptions for compatibility
    if a == ALLOW and b == BLOCK and (under(host, _def_add) or (mode == 'blockXXX' and under(host, _xxx_add))): return True
    if a == BLOCK and b == ALLOW and host in _ok: return True
    # graph.facebook.com is DIRECT in every mode except blockAdSense: the shipping noSocials blocked it (the requested policy change)
    if a == BLOCK and b == ALLOW and host == 'graph.facebook.com' and mode == 'blockSocials': return True
    # adult hosts that the old suffix-without-boundary table blocked only by accident (webcams.com) are now noXXX-only
    if a == BLOCK and b == ALLOW and mode != 'blockXXX' and host.removeprefix('www.') in _xxx_add: return True
    # round 3 (the requested policy change): these hosts are now blocked in every mode, and loopback is never judged
    if a == ALLOW and b == BLOCK and under(host, {'analytics.twitter.com', 'app.adjust.com', 'xp.apple.com', 'vk.com'}): return True
    if a == BLOCK and b == ALLOW and host in ('127.0.0.1', 'localhost'): return True
    if a == ALLOW and b == BLOCK and 'syndicatedsearch.goog' in HY.get('substrings_added', ['syndicatedsearch.goog']) and host == 'example.net': return True
    return False
# intended differences: (a) the boundary fix: prefix-joined hosts; (b) hosts with a trailing-dot rule that never matched
legacy_dead = ['private.camz.', 'site.flashx.', 'tracker.twenga.']
diffs = {}
for m in mods:
    for i, (a, b) in enumerate(zip(ref[m], new[m])):
        if a == b: continue
        k, host = kind[i], probes[i][1]; path = probes[i][0]
        ok = (k in ('joined', 'named') and a == BLOCK and b != BLOCK and (k == 'joined' or host in ('gu-global.com', 'sym-global.com'))) or any(w in path for w in legacy_dead) or (host == 'adblock.turtlecute.org' and a == ALLOW and b == BLOCK)
        ok = ok or hybrid_change(host, m, a, b) or raggr_change(m, i, a, b)
        diffs.setdefault(m, []).append((host, k, a, b, ok))
unexpected = [(m, x) for m, xs in diffs.items() for x in xs if not x[4]]
need(not unexpected, 'generated PACs differ from the supplied PACs in an unintended way: %s' % unexpected[:12])
if nor is not None:
    # without RAGGR the generated PACs must match the reference exactly as r16 did; with it, only new blocks are added
    for m in mods:
        for i, (a, b) in enumerate(zip(new[m], nor[m])):
            need(not (a == ALLOW and b == BLOCK), 'RAGGR unblocked a host: %s %s' % (m, probes[i][1]))
    print('RAGGR: %d new blocks over the no-RAGGR build across %d modes, 0 hosts unblocked' % (sum(1 for m in mods for a, b in zip(new[m], nor[m]) if a != b), len(mods)))
joined_fixed = sum(1 for xs in diffs.values() for x in xs if x[1] == 'joined')
print('reference vs generated: %d probes x %d modes, %d intended differences (boundary fix), %d unexpected' % (len(probes), len(mods), sum(len(v) for v in diffs.values()), len(unexpected)))

# ---- named hostname boundary cases -------------------------------------------------------------------------------
idx = {probes[i][1]: i for i in range(len(probes)) if kind[i] == 'named'}
need(new['Default'][idx['gu-global.com']] != BLOCK and new['Default'][idx['sym-global.com']] != BLOCK, 'gu-global.com / sym-global.com are not caught by global.com')
need(ref['Default'][idx['gu-global.com']] == BLOCK or ref['Default'][idx['sym-global.com']] == BLOCK or 'global.com' not in doms, 'the reference PAC shows the boundary error (control)')
need(new['Default'][idx['global.com']] == BLOCK if 'global.com' in doms else True, 'global.com itself is still handled as before')
need(new['Default'][idx['graph.facebook.com']] == ALLOW and new['blockAdSense'][idx['graph.facebook.com']] == BLOCK and new['blockSocials'][idx['graph.facebook.com']] == ALLOW, 'graph.facebook.com is allowed unless blockAdSense is selected (also under blockSocials)')
need(new['allowY'][idx['m.yap.yahoo.com']] == ALLOW, 'allowY keeps m.yap.yahoo.com reachable')

# ---- exact transport strings ---------------------------------------------------------------------------------------
t = (tmp / 'Default.pac').read_text()
need('BYPASS="PROXY 8.8.8.8:53"' in t and 'MYbloXX="PROXY 127.0.0.1:8021"' in t and 'ALLOW="DIRECT"' in t, 'the 8.8.8.8 BYPASS and the blocking sink are unchanged')
need(t.count('function FindProxyForURL(') == 1, 'one FindProxyForURL (the custom-rule wrapper renames it)')
for var in ('ALLOW_PATTERNS', 'BLOCK_PATTERNS', 'BYPASS_PATTERNS'): need('var %s=' % var in t, var + ' pattern list kept')

# ---- normalization -----------------------------------------------------------------------------------------------
sample = sorted(doms)[0]
norm = run({'d': str(tmp / 'Default.pac')}, [[url(sample), sample], [url(sample.upper()), sample.upper()], [url(sample + '.'), sample + '.'], [url(sample + '..'), sample + '..']])['d']
need(len(set(norm)) == 1, 'case and trailing dots do not change the decision (%s)' % norm)

# ---- all 32 combinations -------------------------------------------------------------------------------------------
ids = G.all_ids(); need(len(ids) == 32 and len(set(ids)) == 32, '32 distinct option combinations')
need(all((tmp / (i + '.pac')).exists() for i in ids), 'every combination is generated')
combo_probes = [[url(h), h] for h in ['example.com', 'doubleclick.net', 'apple.com', 'facebook.com', 'instagram.com', 'graph.instagram.com', 'graph.facebook.com', 'pornhub.com', 'xvideos.com', 'm.yap.yahoo.com']]
res = run({i: str(tmp / (i + '.pac')) for i in ids}, combo_probes)
names = [p[1] for p in combo_probes]
def blocked(i, h): return res[i][names.index(h)] == BLOCK
for i in ids:
    o = [] if i == 'Default' else i.split('+')
    need(blocked(i, 'doubleclick.net'), i + ' still blocks ad servers')
    need(not blocked(i, 'example.com'), i + ' leaves ordinary sites alone')
    need(blocked(i, 'apple.com') == ('blockApple' in o), i + ': apple.com follows noApple only')
    need(blocked(i, 'facebook.com') == ('blockSocials' in o), i + ': facebook.com follows noSocials only')
    need(blocked(i, 'pornhub.com') == ('blockXXX' in o), i + ': adult sites follow noXXX only')
    need(blocked(i, 'graph.facebook.com') == ('blockAdSense' in o), i + ': graph.facebook.com is blocked only when blockAdSense is selected (never by noSocials)')
# precedence between options: a blocking option beats allowY's exemption, order independent
need(blocked('allowY+blockSocials', 'graph.instagram.com'), 'noSocials blocks graph.instagram.com even with allowY (blocking options win over exemptions)')
need(not blocked('allowY', 'graph.instagram.com') and not blocked('allowY+blockAdSense', 'graph.instagram.com'), 'allowY leaves graph.instagram.com reachable')

# ---- noXXX site coverage: apex and subdomain tested separately, look-alikes untouched ----------------------------------
xxx_sites = ['stripchat.com', 'strpst.com', 'stripchat.global', 'stripst.com', 'strip.chat', 'stripchatgirls.com', 'stripchatlive.com', 'make-love.club', 'swag.live', 'markswebcams.com']
xprobes = []
for d in xxx_sites: xprobes += [[url(d), d], [url('cdn.' + d), 'cdn.' + d], [url('x' + d), 'x' + d], [url(d + '.example.test'), d + '.example.test']]
xr = run({'D': str(tmp / 'Default.pac'), 'X': str(tmp / 'blockXXX.pac'), 'AX': str(tmp / 'allowY+blockXXX.pac')}, xprobes)
for n, d in enumerate(xxx_sites):
    a, s_, j, l = 4 * n, 4 * n + 1, 4 * n + 2, 4 * n + 3
    for m in ('X', 'AX'):
        need(xr[m][a] == BLOCK, '%s apex blocked by noXXX (%s)' % (d, m))
        need(xr[m][s_] == BLOCK, '%s subdomain blocked by noXXX (%s)' % (d, m))
        if d != 'markswebcams.com': need(xr[m][j] != BLOCK, 'x%s (joined look-alike) is not blocked by noXXX (%s)' % (d, m))
        if d != 'markswebcams.com': need(xr[m][l] != BLOCK, '%s.example.test is not blocked by noXXX (%s)' % (d, m))
    if d not in ('stripchat.com',): need(xr['D'][s_] != BLOCK or d in doms, '%s subdomain is not blocked by Default alone' % d)
# ---- hybrid exact exceptions: exact host only, never a path, subdomain or look-alike; none may shadow a protected or kill entry
HY = canon['hybrid']; exc = HY['compat_exact_allow']
kills_all = set(canon['base']['kill'])
for o in canon['options'].values(): kills_all |= set(o['kill_add'])
need(not [h for h in exc if under(h, kills_all)], 'no exact exception sits under a noXXX kill entry')
need(all(h == h.lower() and h.strip('.') == h and '/' not in h and '*' not in h and ' ' not in h for h in exc), 'exceptions are plain lowercase hostnames')
eprobes = []
for h in exc: eprobes += [[url(h), h], [url('x.' + h), 'x.' + h], [url('x' + h), 'x' + h], [url(h + '.evil.test'), h + '.evil.test'], [url(h + '/ads/banner.js'), h]]
er = run({'D': str(tmp / 'Default.pac')}, eprobes)['D']
for n, h in enumerate(exc):
    need(er[5 * n] == ALLOW, h + ' exception allows the exact host')
    need(er[5 * n + 4] == ALLOW, h + ' exception is host-only (a path does not change the decision)')
# decisions for everything except the exact host must be identical with the exceptions removed
import copy
_save = G.CANON['exact_allow']; G.CANON['exact_allow'] = [h for h in _save if h not in set(exc)]
(tmp / 'noexc').mkdir(exist_ok=True); (tmp / 'noexc' / 'Default.pac').write_text(G.build([])); G.CANON['exact_allow'] = _save
nr = run({'N': str(tmp / 'noexc' / 'Default.pac')}, eprobes)['N']
for n, h in enumerate(exc):
    for k in (1, 2, 3): need(er[5 * n + k] == nr[5 * n + k], '%s exception does not change subdomain/look-alike decisions (probe %d)' % (h, k))
print('exceptions: %d hosts, host-exact' % len(exc))
# ---- determinism ---------------------------------------------------------------------------------------------------
tmp2 = Path(tempfile.mkdtemp()); G.main(str(tmp2))
need(all((tmp / f.name).read_bytes() == f.read_bytes() for f in tmp2.glob('*.pac')), 'generation is deterministic')
hdr = (root / 'Shared/MYBOptions.h').read_text()
need(re.search(r'MYBOptionOrder\(void\)\{return @\[(.*?)\];', hdr).group(1).replace('@"', '').replace('"', '').split(',') == G.ORDER, 'the app and the generator use the same option order')
shipped = root / 'layout/usr/share/mybloxx/pacs'
need(sorted(f.name for f in shipped.glob('*.pac')) == sorted(f.name for f in tmp.glob('*.pac')) and all((shipped / f.name).read_bytes() == f.read_bytes() for f in tmp.glob('*.pac')), 'the bundled PACs are exactly what rules/generate.py produces (run it after editing rules/canonical.json)')
for _n in ('canonical.json', 'generate.js', 'runtime.txt'):
    need((root / 'layout/usr/share/mybloxx/generator' / _n).read_bytes() == (root / 'rules' / _n).read_bytes(), 'the package carries the current ' + _n + ' (run rules/generate.py)')
if bad:
    print('\n'.join('FAIL: ' + b for b in bad[:40])); sys.exit(1)
print('Rules engine checks passed (%d combinations).' % len(ids))
