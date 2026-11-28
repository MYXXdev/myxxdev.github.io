"""Legacy names must not return to owned source. Compatibility identifiers that must keep the old spelling are listed explicitly."""
import subprocess,sys,re
from pathlib import Path
root=Path(__file__).resolve().parent.parent
files=[f for f in subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0') if f and not f.startswith(('Sources/','tests/branding.py')) and not f.endswith(('.dylib','.png','.pdf','.mobileconfig'))]
bad=[]
# 1. retired component names appear only where they are provenance or compatibility statements
retired={'MYBSafariGuard':set(),'NoAppRedirects':set(),'Safari Guard':{'COMPONENTS.md','Companions/MYBShieldBrowser/README.md','README.md'},'SafariBlocker':{'Companions/MYBShieldBrowser/Tweak.xm','Companions/MYBShieldBrowser/README.md','README.md'}}
for f in files:
    p=root/f
    try:t=p.read_text()
    except Exception:continue
    for name,allowed in retired.items():
        if name in t and f not in allowed and not f.startswith('tests/'):bad.append(f'{f}: legacy name {name}')
# 2. runtime identifiers that existing settings depend on must still be spelled the old way
need={'net.myxxdev.mybloxx.safariguard.plist':'Shared/MYBDefaults.h','net.myxxdev.mybloxx.safariguard.changed':'Companions/MYBShieldBrowser/Tweak.xm'}
for ident,f in need.items():
    if ident not in (root/f).read_text():bad.append(f'{f}: compatibility identifier {ident} was changed')
# 3. every owned component dir builds under its own name
mk=(root/'Makefile').read_text()
for d in re.findall(r'Companions/(\w+)\b(?!/)',mk):
    if d=='InAppAds':continue # grouped: one tweak per app, checked by tests/inappads-source.py
    m=(root/'Companions'/d/'Makefile').read_text()
    if f'TWEAK_NAME = {d}' not in m and 'TWEAK_NAME' in m and d not in('SpeedyAds','MYBAppControl','MYBSupervisionSign'):bad.append(f'Companions/{d}: tweak name does not match its folder')
# 4. licence and notice resources must be present where the shipped code needs them (see tests/provenance.py)
# 5. visible names: the first MYbloXX in every user-visible string carries (R), MYXXdev carries (TM), and allowY always has its !
import glob
vis=glob.glob(str(root/'Preferences/*.m'))+[str(root/f) for f in ('Shared/MYBOutcomeText.h','Shared/MYBStatusModel.h','Shared/MYBHelp.h','Shared/MYBModeCatalog.h','Shared/MYBPACDecision.h','Shared/MYBProxyCheck.h','Companions/MYBShieldRedirects/Tweak.xm')]
barebrand=re.compile(r'MYbloXX(?!®|\\u00ae|[A-Za-z0-9_/\-]|\.[A-Za-z0-9])')
for f in vis:
    for n,l in enumerate(Path(f).read_text().split('\n'),1):
        if l.strip().startswith('//') or 'logLine(' in l or '#import' in l:continue
        for m in re.finditer(r'@?"((?:[^"\\]|\\.)*)"',l):
            lit=m.group(1)
            if '®' in lit or '\\u00ae' in lit or any(x in lit for x in ('.plist','File Provider','On My iPhone','MYbloXX-Settings','MYbloXX.pac')):continue
            if barebrand.search(lit):bad.append(f'{Path(f).relative_to(root)}:{n}: product name without (R): {lit[:60]}')
            if re.search(r'MYXXdev(?!™|\\u2122|[A-Za-z0-9_/.\-])',lit) and ' ' in lit:bad.append(f'{Path(f).relative_to(root)}:{n}: author name without (TM): {lit[:60]}')
            if re.search(r'\ballowY\b(?!!)',lit) and ' ' in lit and 'allowY\"' not in lit:bad.append(f'{Path(f).relative_to(root)}:{n}: allowY without !: {lit[:60]}')
for f in ('BlockedServer/StatusPage.html','BlockedServer/BlockedPage.html'):
    t=(root/f).read_text()
    for lit in re.findall(r"'((?:[^'\\\n]|\\.)*)'",t):
        if barebrand.search(lit) and '®' not in lit and not re.search(r'[/=<>{}]',lit):bad.append(f'{f}: product name without (R): {lit[:60]}')
# 6. one release identity on every surface
hdr=(root/'Shared/MYBVersion.h').read_text()
label=re.search(r'MYB_RELEASE_LABEL "([^"]+)"',hdr).group(1);ver=re.search(r'MYB_COMPONENT_VERSION "([^"]+)"',hdr).group(1)
need_in={'layout/DEBIAN/postinst':f'RELEASE_LABEL="{label}"','Depiction/net.myxxdev.mybloxx15.json':label,'control':f'Version: {ver}'}
for f,token in need_in.items():
    if token not in (root/f).read_text():bad.append(f'{f}: release identity {token} missing')
_label=(root/'layout/Library/PreferenceLoader/Preferences/MYbloXXDiagnostics.plist').read_text()
if 'Name: MYbloXX® (RootHide)' not in (root/'control').read_text():bad.append('the package-manager name is no longer MYbloXX® (RootHide)')
if '<key>label</key><string>MYbloXX®</string>' not in _label or 'RootHide' in _label:bad.append('the Settings entry must read MYbloXX® with no (RootHide)')
if bad:print('\n'.join('FAIL: '+b for b in bad));sys.exit(1)
print('Branding and provenance checks passed.')
