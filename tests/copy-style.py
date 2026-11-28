"""Operator-facing copy: no em dashes in the app, the blocked page, the status page, the Shield components or the helper's messages.
(Rules data, reference files and developer notes are not operator copy.)"""
import re,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];fails=[]
files=subprocess.check_output(['git','ls-files'],cwd=root,text=True).split()
scan=[f for f in files if f.endswith(('.m','.h','.html','.xm','.inc','.css')) and f.startswith(('Preferences/','Shared/','BlockedServer/','Companions/','CCPreview/','Helper/','PACServer/')) and not f.endswith('Brand.h')]
for f in scan:
    t=(root/f).read_text(encoding='utf8',errors='ignore')
    for m in re.finditer('—',t):fails.append(f+': '+repr(t[max(0,m.start()-30):m.start()+20]))
for f in ('layout/DEBIAN/postinst','layout/DEBIAN/postrm','layout/DEBIAN/prerm'):
    if '—' in (root/f).read_text(encoding='utf8',errors='ignore'):fails.append(f)
print('\n'.join('FAIL em dash in '+x for x in fails) if fails else 'No em dashes in operator-facing copy (%d files)'%len(scan));sys.exit(1 if fails else 0)
