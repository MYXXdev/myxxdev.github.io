#!/usr/bin/env python3
"""Provenance and licence notices must match what the source really is.

Replaces the old no-credits check, which forced notices out of the tree. This one fails if a notice that a component needs is missing,
if the packaged copy differs from the source copy, or if a module that is an adaptation lacks its PROVENANCE comment."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
bad=[]
def need(c,m):
    if not c:bad.append(m)
def R(p):return (root/p).read_text(encoding='utf-8')
def has(p):return (root/p).is_file()
# 1. In-App Ad Blocking: notice, GPL text, MIT texts, packaged copies identical to the source copies
for f in ('NOTICE.md','LICENSES.md','COPYING'):
    src,pkg=f'Companions/InAppAds/{f}',f'layout/usr/share/doc/mybloxx-inappads/{f}'
    need(has(src) and has(pkg),f'{f} is missing from the source or the package')
    if has(src) and has(pkg):need(R(src)==R(pkg),f'{f}: packaged copy differs from the source copy')
notice=R('Companions/InAppAds/NOTICE.md') if has('Companions/InAppAds/NOTICE.md') else ''
lic=R('Companions/InAppAds/LICENSES.md') if has('Companions/InAppAds/LICENSES.md') else ''
for name in ('PoomSmart/YouTube-X','itzzace/ytkace','Selandros/TikTokClean','level3tjg/RedditFilter','and101/RedditFilter','SoCuul/SCInsta','pstepanovum/PSSoundcloud','Facebook-Plus','adamsardo/MarketplaceAdBlock'):
    need(name in notice,f'NOTICE.md does not name {name}')
for holder in ('PoomSmart','selandros','level3tjg','and101'):need(holder in lic,f'LICENSES.md lacks the {holder} MIT notice')
need('whole of `MYBInAppAds.dylib` is distributed under the GNU General Public License' in notice,'NOTICE.md must state the GPL consequence of the single dylib')
need('GNU GENERAL PUBLIC LICENSE' in (R('Companions/InAppAds/COPYING') if has('Companions/InAppAds/COPYING') else ''),'COPYING is not the GPL text')
# 2. every catalogue module is accounted for, and adapted modules carry a PROVENANCE comment that names their source
hdr=R('Shared/MYBInAppAds.h')
modules=re.findall(r'@"module":@"([a-z]+)"',hdr)
sources={'youtube':'YouTube-X','instagram':'SCInsta','tiktok':'TikTokClean','reddit':'RedditFilter','soundcloud':'PSSoundcloud','facebook':'Facebook-Plus'}
dirs={'youtube':'YouTube','instagram':'Instagram','tiktok':'TikTok','reddit':'Reddit','soundcloud':'SoundCloud','facebook':'Facebook','youtubemusic':'YouTubeMusic','x':'X','messenger':'Messenger','amazon':'Amazon','threads':'Threads','gmail':'Gmail','appstore':'AppStore','douban':'Douban','qqmusic':'QQMusic','sogou':'Sogou','wechat':'WeChat','bilibili':'Bilibili'}
for m in modules:
    need(m in dirs,f'module {m} has no provenance entry in tests/provenance.py')
    p=f'Companions/InAppAds/{dirs.get(m,m)}/Module.m'
    if not has(p):bad.append(f'{p} missing');continue
    t=R(p)
    need('PROVENANCE' in t,f'{p}: no PROVENANCE comment')
    if m in sources:need(sources[m] in t,f'{p}: PROVENANCE does not name {sources[m]}')
    need(not re.search(r'independently written|original design|clean[- ]room',t,re.I),f'{p}: claims independence')
# 3. SpeedyAds (GPL-3.0) and the redirect module (MIT)
need(has('Companions/SpeedyAds/LICENSE') and 'GNU GENERAL PUBLIC LICENSE' in R('Companions/SpeedyAds/LICENSE'),'SpeedyAds: GPL text missing')
need(has('Companions/SpeedyAds/NOTICE.md') and 'Un-JailedSpeedAds' in R('Companions/SpeedyAds/NOTICE.md'),'SpeedyAds: notice missing')
need(has('layout/usr/share/doc/mybloxx-speedyads/NOTICE.md') and has('layout/usr/share/doc/mybloxx-speedyads/COPYING'),'SpeedyAds: packaged notice or GPL text missing')
need(has('Companions/MYBShieldRedirects/LICENSE') and 'MIT License' in R('Companions/MYBShieldRedirects/LICENSE') and 'i_82' in R('Companions/MYBShieldRedirects/LICENSE'),'Redirect module: MIT notice missing')
need(has('layout/usr/share/doc/mybloxx-shield-redirects/LICENSE') and has('layout/usr/share/doc/mybloxx-shield-redirects/NOTICE.md'),'Redirect module: packaged notice missing')
# 4. Facebook module must say it is derived
fb=R('Companions/InAppAds/Facebook/Module.m')
need('NOT independently derived' in fb or 'adaptation' in fb,'Facebook module must state it is an adaptation')
if bad:
    print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Provenance and licence notices match the source.')
