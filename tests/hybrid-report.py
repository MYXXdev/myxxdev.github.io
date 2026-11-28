"""rules/HYBRID.md is generated from canonical.json and must be current; its headline counts are the shipped ones."""
import subprocess,sys,tempfile,json
from pathlib import Path
root=Path(__file__).resolve().parents[1];tmp=Path(tempfile.mkdtemp())/'H.md'
subprocess.run([sys.executable,str(root/'tools/generate-hybrid-report.py'),str(tmp.parent)],check=True,stdout=subprocess.DEVNULL)
c=json.loads((root/'rules/canonical.json').read_text())
ok=(tmp.parent/'HYBRID.md').read_text()==(root/'rules/HYBRID.md').read_text()
print(('PASS' if ok else 'FAIL')+' HYBRID.md is current')
n=(len(c['hybrid']['default_add']),len(c['hybrid']['noXXX_add']),len(c['exact_allow']))
good=n==(326,23,27);print(('PASS' if good else 'FAIL')+' counts are 326 / 23 / 27 (got %s)'%(n,))
import shutil
d=tmp.parent;ok2=(d/'SCREENSHOTS.md').read_text()==(root/'rules/SCREENSHOTS.md').read_text()
print(('PASS' if ok2 else 'FAIL')+' SCREENSHOTS.md is current')
rows=json.loads((root/'rules/reference/screenshot-rows.json').read_text())['rows']
r109=len(rows)==109 and len({r['image'] for r in rows})==27 and not any('awint' in (r['host'] or '') for r in rows)
print(('PASS' if r109 else 'FAIL')+' 109 rows read across 27 screenshots (got %d)'%len(rows))
sys.exit(0 if ok and good and ok2 and r109 else 1)
