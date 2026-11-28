#!/usr/bin/env python3
"""B50 regression checks for the defects seen in B49 screenshots (static, runs anywhere)."""
import re, sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
P = root / 'Preferences'
src = {f.name: f.read_text() for f in P.glob('*.m')}
fail = []
def check(ok, msg):
    if not ok: fail.append(msg)

# 1. Stray arcs/corner outlines/cross shapes came from hand-built CAShapeLayer outlines in reused cells.
for n, t in src.items():
    check('CAShapeLayer' not in t, f'{n}: CAShapeLayer reintroduced (card outlines must use cornerRadius + maskedCorners)')
check('maskedCorners' in src['MYBPrismCell.m'], 'MYBPrismCell must round groups with maskedCorners')
# 2. Footer overlap came from plain-style tables floating footers over content.
for n, t in src.items():
    check('UITableViewStylePlain' not in t, f'{n}: plain table style floats footers over rows')
check('UITableViewStyleGrouped' in src['MYBMenuBase.m'], 'MYBMenuBase must be a grouped table')
check('titleForHeaderInSection' not in ''.join(src.values()) and 'titleForFooterInSection' not in ''.join(src.values()), 'UIKit section titles must not duplicate custom header/footer labels')
# 3. One navigation treatment: appearance is per navigationItem, never global.
check('UINavigationBar appearance' not in ''.join(src.values()), 'global UINavigationBar appearance proxy leaks into Settings')
check('[UINavigationBar appearance' not in ''.join(src.values()), 'global UINavigationBar appearance proxy')
# 4. No swizzling / global UIKit hooks.
for n, t in src.items():
    check('method_exchangeImplementations' not in t and 'class_replaceMethod' not in t, f'{n}: swizzling')
# 5. Switch identity by key, not by row tag (cell reuse).
for n in ('MYBAppControlController.m', 'MYBUpdatesController.m', 'MYBLegacyController.m', 'MYBModernController.m'):
    check(re.search(r'\.key\s*=', src[n]) is not None, f'{n}: switches must carry a key')
    check('.tag=' not in src[n].replace(' ', '') or 'MYBPrismSwitch' not in src[n].split('.tag=')[0][-200:], f'{n}: row tag used to identify switches')
# 6. Helper must never block the main thread or hang forever.
base = src['MYBMenuBase.m']
check('WNOHANG' in base and 'kMYBHelperTimeout' in base, 'helper runner needs non-blocking waitpid + watchdog')
check('dispatch_semaphore' not in ''.join(src.values()), 'synchronous waits are forbidden')
# 7. Removed features stay removed.
check(not re.search(r'[Ff]orce.?[Ii]nline|include native video|IncludeNative', ''.join(src.values())), 'removed App Control options reintroduced')
check('Rules Updates' not in ''.join(src.values()), 'use "Automatic Updates"')
for s in ('Automatic Updates', 'Checking Updates', 'MYbloXX® is up to date', 'MYbloXX® Updated'):
    check(s in ''.join(src.values()), f'missing required string: {s}')
for s in ('Back Up Now', 'Restore Backup', 'Export Backup'):
    check(s in src['MYBBackupController.m'], f'missing backup row: {s}')
# 8. Icons, per consumer. In-app mark: opaque (the view clips it once). Settings row icon: pre-masked iOS squircle,
#    transparent corners, opaque centre, optically centred. Control Centre glyph: transparent white template, centred.
try:
    from PIL import Image
    import numpy as np
    def optical(a):
        h, w = a.shape;ys, xs = np.nonzero(a > .5);wy, wx = np.mgrid[0:h, 0:w]
        bx, by = (xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2
        cx, cy = (a * wx).sum() / a.sum() + .5, (a * wy).sum() / a.sum() + .5
        return ((bx + cx) / 2 - w / 2) / w, ((by + cy) / 2 - h / 2) / h
    for f in sorted((P / 'Resources').glob('MYBIcon*.png')):
        im = Image.open(f).convert('RGBA'); a = im.getchannel('A')
        check(a.getextrema()[0] == 255, f'{f.name}: in-app mark is opaque (MYBMarkView clips it once)')
    for folder in (P / 'Resources', P.parent / 'layout/Library/PreferenceLoader/Preferences'):
        icons = sorted(folder.glob('MYBSettingsIcon*.png'))
        check(len(icons) == 3, f'{folder.name}: Settings icon at 1x/2x/3x')
        for f in icons:
            im = Image.open(f).convert('RGBA'); w, h = im.size; a = np.asarray(im.getchannel('A')).astype(float)
            check(w == h and w in (29, 58, 87), f'{f.name}: square canvas at a Settings size ({w}x{h})')
            check(a[0, 0] == 0 and a[0, w - 1] == 0 and a[h - 1, 0] == 0 and a[h - 1, w - 1] == 0, f'{f.name}: corners are transparent (pre-masked)')
            check(a[h // 2, 0] == 255 and a[0, w // 2] == 255 and a[h // 2, w - 1] == 255 and a[h - 1, w // 2] == 255, f'{f.name}: edge midpoints are opaque (full bleed, no halo)')
            c = int(w * .22); check(a[c:w - c, c:h - c].min() == 255, f'{f.name}: interior is fully opaque')
            check(.92 < (a > 127).mean() < .975, f'{f.name}: coverage {(a > 127).mean():.2f} matches an iOS squircle (not a plain square)')
            rgb = np.asarray(im.convert('RGB')).astype(int); glyph = (rgb.sum(axis=2) > 300) & (a > 250)
            ox, oy = optical(glyph.astype(float)); check(abs(ox) <= .02 and abs(oy) <= .02, f'{f.name}: glyph optically centred (offset {ox:+.3f}, {oy:+.3f})')
    for f in sorted((P.parent / 'CCPreview' / 'Resources').glob('icon*.png')):
        im = Image.open(f).convert('RGBA'); a = im.getchannel('A'); w, h = im.size; al = np.asarray(a).astype(float) / 255
        check(a.getextrema()[0] == 0, f'CC {f.name}: glyph has a transparent background')
        ox, oy = optical(al); check(abs(ox) <= .02 and abs(oy) <= .02, f'CC {f.name}: glyph optically centred (offset {ox:+.3f}, {oy:+.3f})')
        l, t, r, b = a.getbbox(); check(max(r - l, b - t) <= w * .8 and min(l, t, w - r, h - b) >= w * .08, f'CC {f.name}: glyph has padding')
        px = [q for q in im.getdata() if q[3] > 200]; check(all(q[0] > 240 and q[1] > 240 and q[2] > 240 for q in px), f'CC {f.name}: glyph is a white template')
except ImportError:
    print('PIL not installed: icon opacity check skipped')
# 9. Makefile lists exactly the existing sources.
mk = (P / 'Makefile').read_text(); listed = set(re.search(r'_FILES\s*=\s*(.*)', mk).group(1).split())
check(listed == set(src), f'Makefile/source mismatch: {sorted(listed ^ set(src))}')
if fail:
    print('\n'.join('FAIL: ' + f for f in fail)); sys.exit(1)
print('B50 design/defect regression checks passed')
