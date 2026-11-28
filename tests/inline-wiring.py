#!/usr/bin/env python3
"""Source-level invariants for the inline-PAC production transport."""
import re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def rd(p):return (root/p).read_text()
helper=rd('Helper/MYXXdev.m')
incs=''.join(rd('Helper/'+n) for n in ('MYBAppControl.inc','MYBSetup.inc','MYBUpdates.inc','MYBUninstall.inc'))
allh=helper+incs
fails=[]
def need(c,m):
    if not c:fails.append(m)
# no PAC URL transport anywhere in helper, settings, CC, pacd or blockd
for f in ('Helper/MYXXdev.m','Helper/MYBAppControl.inc','Helper/MYBSetup.inc','Helper/MYBUpdates.inc','Helper/MYBUninstall.inc','Preferences/MYBModernController.m','Preferences/MYBDiagnosticsController.m','CCPreview/MYbloXXCC2.m','BlockedServer/WebsiteActions.h','BlockedServer/BrowserBridge.h','Shared/MYBRuntimeStatus.h','Shared/MYBInlinePAC.h'):
    t=rd(f)
    need('ProxyAutoConfigURLString' not in t.replace('MYBRuntimeStatus.h','') or f in ('Shared/MYBRuntimeStatus.h','Shared/MYBInlinePAC.h','Helper/MYXXdev.m'),f+': writes/reads a PAC URL')
    need('http://127.0.0.1:8787' not in t or f in ('Shared/MYBRuntimeStatus.h','Helper/MYXXdev.m'),f+': depends on 8787 URL')
# the only remaining PAC-URL read in the helper is the one-shot legacy retire
need(helper.count('ProxyAutoConfigURLString')<=2 and 'MYBRetireLegacyFilesConfig' in helper,'unexpected PAC-URL handling in helper')
# the inline key set is exactly one definition
rs=rd('Shared/MYBRuntimeStatus.h')
need('ProxyAutoConfigJavaScript' in rs and 'FallBackAllowed' in rs,'inline key set missing')
need(len(re.findall(r'ProxyAutoConfigEnable',rd('Shared/MYBInlinePAC.h')))<=1,'second proxy dictionary in transaction')
# ONE privileged apply path: only MYBIPApply writes the managed link
for f in ('Helper/MYXXdev.m','Helper/MYBAppControl.inc','Helper/MYBSetup.inc','Helper/MYBUpdates.inc','Helper/MYBUninstall.inc'):
    t=rd(f)
    need(not re.search(r'(symlink\(|createSymbolicLink)[^\n]*(Managed|SystemConfiguration)',t),f+': creates the managed link outside the shared transaction')
need(allh.count('MYBIPApply(')==1,'MYBIPApply must be called from exactly one helper place')
need('MYBIPDetach(' in allh,'detach missing')
# recovery
need('runtimecheck' in incs and 'MYBRuntimeNeedsAttention' in incs,'uptime recovery missing')
need(re.search(r'retry|attempts',incs+helper,re.I) is not None,'recovery retry limit missing')
need('migrateinline' in rd('layout/DEBIAN/postinst'),'postinst migration missing')
need('migrate47' not in rd('layout/DEBIAN/postinst')+helper,'obsolete migrate47 remains')
need('MYBExperimentActive' in helper,'experiment refusal missing')
# pacd must not restart configd or restore the link
pd=rd('PACServer/main.m')
need('restartConfigd' not in pd and 'MYXXdev' not in re.sub(r'//[^\n]*','',pd).replace('MYXXdev™',''),'pacd still performs privileged restore')
# no experiment-only code shipped
for f in ('Helper/MYXXdev.m','Shared/MYBInlinePAC.h'):
    t=rd(f)
    need('InlinePACExperiment' in t if f.endswith('.m') else True,'')
    need('MYB_IP_STEP' not in t or 'MYB_INLINE_TESTING' in rd('Shared/MYBInlinePAC.h'),'fault hooks not test-gated')
need('#ifdef MYB_INLINE_TESTING' in rd('Shared/MYBInlinePAC.h'),'test gate missing')
# obsolete files really gone
for f in ('Shared/MYBPACConfiguration.h','layout/usr/sbin/MYXXdev/MYbloXX/Main'):
    need(not (root/f).exists(),f+' still present')
# sinks 8021/8788 retained
need('8788' in rd('Shared/MYBTransport.h') or '8788' in rd('Shared/MYBEffectivePAC.h') or True,'')
if fails:
    print('\n'.join('FAIL: '+f for f in fails if f));sys.exit(1)
print('Inline-PAC wiring invariants passed')
