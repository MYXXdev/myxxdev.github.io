#!/usr/bin/env python3
"""Writes the files the rules repository (MYXXdev/myxxdev.github.io, folder MYbloXX/) must carry for these rules, from rules/canonical.json.
Usage: prepare-upstream.py DEST      DEST is a checkout of the rules repository; only DEST/MYbloXX is touched. Nothing is committed or pushed.
Every PAC name a published profile or older consumer may fetch is regenerated: the six standalone modes and every historical alias
(MYbloXX, MYbloXXTest, MYbloXXallowFB, MYbloXXnoFB, MYbloXXallowY, MYbloXXnoApple, MYbloXXnoSocials, MYbloXXnoXXX). Aliases are byte copies of their
standalone target, so no old rule set can remain behind under an alias name. The 26 combination PACs are generated on the device and are not published."""
import json, shutil, sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]; sys.path.insert(0, str(root / 'rules'))
import generate as G

STANDALONE = ['Default'] + list(G.ORDER)

def published_names():
    return STANDALONE + sorted(G.CANON['aliases'])

def render_readme():
    by = {}
    for a, t in sorted(G.CANON['aliases'].items()): by.setdefault(t, []).append(a)
    rows = ['| %s | %s |' % (', '.join(['%s.pac' % m] + ['%s.pac' % a for a in by.get(m, [])]), m) for m in STANDALONE]
    return ('# MYbloXX rules\n\n`canonical.json` is the single source of the MYbloXX rules. Every PAC in this folder is generated from it by the generator in the\n'
            'MYbloXX package (`rules/generate.py`, byte-identical `rules/generate.js`); do not edit them by hand.\n\n'
            '| Published files | Standalone mode |\n|---|---|\n' + '\n'.join(rows) + '\n\n'
            'Historical alias files are byte copies of their target and are kept so existing profiles and links keep working.\n'
            'Legacy Mode profiles (`*.mobileconfig`) reference these files through jsDelivr and are unchanged.\n')

def main(dest):
    d = Path(dest) / 'MYbloXX'; d.mkdir(parents=True, exist_ok=True)
    gen = Path(__import__('tempfile').mkdtemp()); G.main(str(gen))
    for n in published_names(): shutil.copyfile(gen / (n + '.pac'), d / (n + '.pac'))
    shutil.copyfile(root / 'rules/canonical.json', d / 'canonical.json')
    (d / 'RULES.md').write_text(render_readme())
    print('wrote %d PACs, canonical.json and RULES.md to %s' % (len(published_names()), d))

if __name__ == '__main__':
    if len(sys.argv) != 2: sys.exit(__doc__)
    main(sys.argv[1])
