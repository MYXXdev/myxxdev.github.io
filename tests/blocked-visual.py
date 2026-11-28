# Renders the real blocked page (dumped by blocked-response.py) in headless Chrome at iPhone widths and checks:
# no horizontal overflow, nothing wider than the viewport (long URLs), 200% text still fits, and dark + light render.
# Screenshots are saved for review. This is a browser-engine check, not an iOS device check.
import subprocess,sys,re,shutil
from pathlib import Path
src,out=Path(sys.argv[1]),Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
chrome=next((c for c in ('google-chrome','chromium','chromium-browser','/Applications/Google Chrome.app/Contents/MacOS/Google Chrome') if shutil.which(c) or Path(c).exists()),None)
if not chrome:print('SKIP: no Chrome available');sys.exit(0)
probe='<script>document.addEventListener("DOMContentLoaded",()=>{const w=document.documentElement.clientWidth;let wide=0;document.querySelectorAll("*").forEach(e=>{const r=e.getBoundingClientRect();if(r.right>w+1||r.left<-1)wide++});document.body.setAttribute("data-wide",wide);document.body.setAttribute("data-scroll",document.documentElement.scrollWidth>w+1?"1":"0");})</script>'
fail=[]
if not list(src.glob('*.html')):print('FAIL: no rendered pages found in',src);sys.exit(1)
for page in sorted(src.glob('*.html')):
    html=page.read_text()
    for scheme in ('dark','light'):
      for zoom in (1,2):
        for width in (320,375,430):
            f=out/f'{page.stem}-{scheme}-{width}-x{zoom}.html'
            css=f'<style>html{{font-size:{100*zoom}%}}</style>'
            doc=html.replace('</body>',probe+'</body>')
            doc=doc.replace('<head>','<head><meta name="color-scheme" content="%s">'%scheme+css,1)
            f.write_text(doc)
            args=[chrome,'--headless=new','--no-sandbox','--disable-gpu','--hide-scrollbars',f'--blink-settings=preferredColorScheme={1 if scheme=="dark" else 0}',f'--window-size={width},900','--virtual-time-budget=2000']
            dom=subprocess.run(args+['--dump-dom',f.as_uri()],capture_output=True,text=True,timeout=60).stdout
            m=re.search(r'data-wide="(\d+)"[^>]*data-scroll="(\d)"|data-scroll="(\d)"[^>]*data-wide="(\d+)"',dom)
            if not m:fail.append(f'{f.name}: probe did not run');continue
            wide=int(m.group(1) or m.group(4));scroll=(m.group(2) or m.group(3))
            if scroll=='1' or wide:fail.append(f'{f.name}: overflow (elements past viewport={wide}, horizontal scroll={scroll})')
            if zoom==1 and scheme=='dark':
                subprocess.run(args+[f'--screenshot={out/(f.stem+".png")}',f.as_uri()],capture_output=True,timeout=60)
if fail:print('\n'.join(fail));sys.exit(1)
print('Blocked page: no horizontal overflow at 320/375/430 px, dark and light, normal and 200% text.')
