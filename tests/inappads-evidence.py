"""Every hook each in-app ad module installs has a cited interface source; the three newest modules may not rely on evidence from a different app;
no module claims device verification; the evidence generates from the sources; all eight modules are built, filtered and visible."""
import json, re, subprocess, sys
from pathlib import Path
import os; root = Path(os.environ.get('MYB_ROOT',str(Path(__file__).resolve().parents[1]))); bad = []
def need(c, m):
    if not c: bad.append(m)
import tempfile
tmp = tempfile.mkdtemp()
r = subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / 'tools/generate-inappads-evidence.py'), '--out', tmp], capture_output=True, text=True)
need(r.returncode == 0, 'the evidence generator failed: ' + r.stderr[-300:])
E = json.loads((Path(tmp) / 'evidence.json').read_text())['modules']
cat = re.findall(r'@\{@"module":@"(\w+)"', (root / 'Shared/MYBInAppAds.h').read_text())
need(sorted(E) == sorted(cat) and len(cat) == 18, 'evidence covers exactly the eighteen catalogue modules (got %s)' % list(E))
for m, v in E.items():
    need(v['device_verified'] == '', m + ': no module is marked device-verified')
    need(v['hooks'] or m == 'appstore', m + ': has hooks')  # appstore is discovery only: no hooks by design
    for h, e in v['hooks'].items():
        need(e['sources'], '%s: hook %s has no cited interface source' % (m, h))
        for s in e['sources']: need((s['url'].startswith('https://github.com/') or s['url'].startswith('https://developer.apple.com/')) and s['repo_commit'] and s['repo_last_commit'] and s['shows'], '%s: %s source is incomplete' % (m, h))
    need(not re.search(r'[Pp]rotected|guarantee|always|verified on', v['note']) or 'unverified' in v['note'] or 'unproven' in v['note'] or 'not ' in v['note'], m + ': note does not overclaim')
# YouTube Music may only use interfaces seen in a YouTube Music dump, never a YouTube-app-only source
for h, e in E['youtubemusic']['hooks'].items():
    need(any('YouTube%20Music' in s['url'] or 'youtubemusic' in s['url'] for s in e['sources']), 'youtubemusic: ' + h + ' has no YouTube Music source')
need(set(E['youtubemusic']['hooks']) == {'YTIPlayerResponse playerAdsArray', 'YTIPlayerResponse adIntroRenderer', 'YTIPlayerResponse isMonetized', 'YTAdsInnerTubeContextDecorator decorateContext:'}, 'youtubemusic: only the four class-dump-backed hooks')
# X and Messenger sources must be for those apps
need(all('X' in s['kind'] for h in E['x']['hooks'].values() for s in h['sources']), 'x: sources are X tweaks')
need(all('Messenger' in s['kind'] for h in E['messenger']['hooks'].values() for s in h['sources']), 'messenger: sources are Messenger tweaks')
if bad: print('\n'.join('FAIL ' + b for b in bad)); sys.exit(1)
print('in-app ad evidence: %d modules, %d hooks, every hook has a cited source; none device-verified' % (len(E), sum(len(v['hooks']) for v in E.values())))
