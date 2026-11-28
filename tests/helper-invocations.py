"""Every place that starts the helper must produce an argument count its validator accepts. The validator table
(Shared/MYBHelperArgs.h) is compared with the literal invocations in the sources, which is the class of bug where a caller
sends N arguments and the entry point's guard rejects them (website Allow sent argc=5 into a guard that stopped at 4)."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
hdr=(root/'Shared/MYBHelperArgs.h').read_text()
table={}
body=hdr[hdr.index('MYBHelperActionArity'):hdr.index('static inline NSString *MYBHelperArg(')]
for names,lo,hi in re.findall(r'for\(NSString \*a in @\[([^\]]+)\]\)t\[a\]=@\[@(\d+),@(\d+)\]',body):
    for n in re.findall(r'@"([a-z]+)"',names):table[n]=(int(lo),int(hi))
for n,lo,hi in re.findall(r't\[@"([a-z]+)"\]=@\[@(\d+),@(\d+)\]',body):table[n]=(int(lo),int(hi))
bad=[]
def top_level_count(s):
    depth=0;n=1 if s.strip() else 0;instr=False
    for i,c in enumerate(s):
        if c=='"' and (i==0 or s[i-1]!='\\'):instr=not instr
        if instr:continue
        if c in '[({':depth+=1
        elif c in '])}':depth-=1
        elif c==',' and depth==0:n+=1
    return n
def check(action,count,where):
    if action not in table:bad.append(f'{where}: unknown action {action}');return
    lo,hi=table[action]
    if not lo<=count-1<=hi:bad.append(f'{where}: {action} sent with {count-1} argument(s); the entry point accepts {lo}-{hi}')
srcs=list((root/'Preferences').glob('*.m'))+[root/'BlockedServer/WebsiteActions.h',root/'CCPreview/MYbloXXCC2.m']+list((root/'Companions').glob('*/Tweak.xm'))
seen=0
for f in srcs:
    t=f.read_text()
    for m in re.finditer(r'(?:runHelper:|runHelperArgs\(|silentHelper:)@\[',t):
        i=m.end();depth=1;j=i
        while depth and j<len(t):
            if t[j]=='[':depth+=1
            elif t[j]==']':depth-=1
            j+=1
        inner=t[i:j-1];first=re.match(r'\s*@"([a-z]+)"',inner)
        if first:check(first.group(1),top_level_count(inner),f.name);seen+=1
    for m in re.finditer(r'return runHelperArgs\(@\[(@"allowwebsite"[^\]]*)\]\)',t):check('allowwebsite',top_level_count(m.group(1)),f.name);seen+=1
    for m in re.finditer(r'const char \*args\[\]\s*=\s*\{"MYXXdev",\s*([^}]*)\}',t):
        parts=[p.strip() for p in m.group(1).split(',') if p.strip() and p.strip()!='NULL']
        lit=re.match(r'"([a-z]+)"',parts[0]) if parts else None
        if lit:check(lit.group(1),len(parts),f.name);seen+=1
for plist in (root/'layout/Library/LaunchDaemons').glob('*.plist'):
    strings=re.findall(r'<string>([^<]+)</string>',plist.read_text())
    if strings and strings[0].endswith('/MYXXdev') and len(strings)>1:check(strings[1],len(strings)-1,plist.name);seen+=1
for script in ('postinst','prerm'):
    for action in re.findall(r'"\$(?:HELPER|MYB_HELPER)" ([a-z]+)',(root/'layout/DEBIAN'/script).read_text()):check(action,1,script);seen+=1
assert seen>=20,f'only {seen} invocations found - the scan itself is broken'
# the entry point must not carry its own, divergent argc guard
helper=(root/'Helper/MYXXdev.m').read_text()
if re.search(r'argc\s*>\s*[0-9]\s*\)',helper[helper.index('static int MYBRun'):helper.index('static int MYBRun')+1500]):bad.append('MYBRun has its own argc upper-bound guard again')
if 'MYBHelperArgsValid(' not in helper:bad.append('MYBRun does not use the shared validator')
for b in bad:print('FAIL:',b)
print(f'Helper invocation checks {"FAILED" if bad else "passed"} ({seen} invocations compared with the validator table)');sys.exit(1 if bad else 0)
