#!/usr/bin/env python3
# Private Conversations in search: in-app search filter, and the Spotlight display filter that must stay out of delivery, indexing and carrier code.
import re,sys,pathlib
ROOT=pathlib.Path(__file__).resolve().parent.parent
def R(p):return (ROOT/p).read_text(encoding='utf-8')
bad=[]
def need(c,m):
    print(('ok   ' if c else 'FAIL ')+m)
    if not c:bad.append(m)
strip=lambda t:re.sub(r'//[^\n]*','',re.sub(r'/\*.*?\*/','',t,flags=re.S))
sp=R('Companions/MYBPrivateSpotlight/Tweak.m');spc=strip(sp);pl=R('Companions/MYBPrivateSpotlight/MYBPrivateSpotlight.plist');core=R('Companions/MYBPrivateMessages/PMCore.m');adv=R('Preferences/MYBAdvancedController.m')
need('com.apple.springboard' in pl and 'com.apple.Spotlight' in pl and pl.count('com.apple.')==2 and 'Executables' not in pl,'filter plist names only SpringBoard and Spotlight')
need(bool(re.search(r'isEqualToString:@"com.apple.springboard"\] && !\[bundle isEqualToString:@"com.apple.Spotlight"\]\) return;',sp)) and 'majorVersion != 16' in sp,'the tweak returns at once in any other process or iOS version') if False else need('return;' in sp and 'com.apple.springboard' in sp and 'majorVersion != 16' in sp,'the tweak returns at once in any other process or iOS version')
need(not re.search(r'CommCenter|CarrierBundle|CTCellularPlan|CoreTelephony|CTTelephony|imagent|IMDaemon|IMDPersistence|searchd|sqlite3|sms\.db|CSSearchableIndex|deleteSearchableItems',spc),'no CommCenter, carrier, telephony, delivery, indexer or database access')
need('CC_SHA256' in sp and '%@|%@' in sp and 'MYBPMSalt' in sp and 'MYBPMEntries' in sp and '"state"' in sp.replace("@\"state\"",'"state"'),'matches only by the same salted hash Messages keeps; no names, numbers or text are compared or stored')
need('MYB_PRIV_KEY_MESSAGES' in sp and 'return nil' in sp.split('static NSSet *PrivateSet')[1][:900],'does nothing while the Private Conversations switch is off')
need('deleteItemsWithIdentifiers' in sp and 'UITableViewDiffableDataSourceReference' in sp and 'UICollectionViewDiffableDataSourceReference' in sp,'hides rows on screen only, from collection and table data sources')
need('PrivateSpotlightProbe.plist' in sp and 'componentsJoinedByString' in sp and 'NSStringFromClass' in sp,'writes a names-and-lengths probe')
need(not re.search(r'writeToFile:[^;]*(text|body|snippet|displayName|title)',spc),'the probe never writes result text')
need('Companions/MYBPrivateSpotlight' in R('Makefile'),'built with the package')
need('searchShapes' in core and 'searchClasses' in core and 'UITableViewDiffableDataSourceReference' in core and 'ObjectHidden' in core,'Messages search results are filtered and probed in-app')
need('PrivateSpotlightProbe.plist' in adv and 'status[@"spotlight"]' in adv,'Copy Messages Diagnostics includes the Spotlight probe')
need('Siri suggestions, the search index itself' in adv and 'still being verified' in adv,'the Settings footer says what is and is not covered')
sys.exit(1 if bad else 0)
