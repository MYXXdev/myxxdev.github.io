from pathlib import Path
root=Path(__file__).resolve().parents[1]
app=(root/'Companions/MYBAppControl/Tweak.xm').read_text()
assert 'SBSCopyFrontmostApplicationDisplayIdentifier' not in app
assert 'SpringBoardServices.framework' not in app
assert '_accessibilityFrontMostApplication' not in app
assert 'frontDisplayDidChange:' in app and 'WNOHANG' in app
assert 'if(pending)return' in app and 'MYBTarget() isEqual:event' in app
assert 'timeInterval:0.5' not in app
prefs=(root/'Preferences/Makefile').read_text()
assert 'MYBPrismSwitch.m' in prefs and 'MYBPrism.dylib' not in prefs
assert 'MYBSupervisionSign' in (root/'Makefile').read_text()
print('B47 foreground, helper timeout and source-built preferences checks passed')
