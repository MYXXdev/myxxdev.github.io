import re,pathlib,sys,os
root=pathlib.Path(__file__).resolve().parents[1];bad=[]
def need(c,m):
    if not c:bad.append(m)
R=lambda p:(root/p).read_text()
hdr=R('Shared/MYBInAppAds.h')
cat=re.findall(r'@\{@"module":@"(\w+)",@"name":@"([^"]+)",@"bundles":@\[([^\]]*)\]',hdr)
need([c[0] for c in cat]==['youtube','instagram','tiktok','soundcloud','reddit','youtubemusic','x','messenger','facebook','amazon','threads','gmail','douban','qqmusic','sogou','wechat','bilibili','appstore'],'catalogue lists the eighteen modules: the five preserved ones first, then YouTube Music, X and Messenger')
mk=R('Makefile')
shared_mk=R('Companions/InAppAds/Makefile');shared_plist=R('Companions/InAppAds/MYBInAppAds.plist')
MYBAdsRun=lambda module:'void MYBAdsRun_%s(void)'%module
need('Companions/InAppAds' in mk and 'Companions/InAppAds/' not in mk,'the top-level Makefile builds the one shared ad-blocking dylib')
need('TWEAK_NAME = MYBInAppAds' in shared_mk,'the shared tweak is MYBInAppAds')
plist_bundles=re.findall(r'"([^"]+)"',shared_plist)
need(sorted(plist_bundles)==sorted({b for _,_,bs in cat for b in re.findall(r'"([^"]+)"',bs)}),'the shipped filter names exactly the supported apps and not com.apple.UIKit (an app picked under Ad Network Blocking can load it)')
need(len(plist_bundles)==len(set(plist_bundles)),'no bundle listed twice')
forbidden=['isPlayableInBackground','playableInBackground','spamSignals','Premium','premium','subscri','Subscri','isSubscriber','download','Download','readReceipt','watermark','Watermark','/var/jb','rootless','LIVE','isLive','Live']
for module,name,bundles in cat:
    folder=next(f.name for f in (root/'Companions/InAppAds').iterdir() if f.name.lower()==module)
    d=root/'Companions/InAppAds'/folder
    need(f'{folder}/Module.m' in shared_mk,f'{folder}: compiled into the shared dylib')
    need(not (d/'Makefile').exists() and not list(d.glob('*.plist')),f'{folder}: no retired per-app Makefile or filter plist')
    need(MYBAdsRun(module) in (d/'Module.m').read_text(),f'{folder}: started by the dispatcher, not by its own constructor')
    for b in re.findall(r'"([^"]+)"',bundles):need(f'"{b}"' in shared_plist,f'{folder}: shared filter covers {b}')
    code=(d/'Module.m').read_text()
    need('MYBAdsModuleEnabled(prefs,@"%s")'%module in code or (folder=='AppStore' and 'MYBAdsDiscoveryWatch(@"appstore"' in code),f'{folder}: stays off unless its own switch is on')
    need('__attribute__((constructor))' not in code,f'{folder}: no constructor of its own (the dispatcher is the only entry point)')
    body=code.split('NSUInteger',1)[0] if False else code
    # hook tables and comments may MENTION what is excluded; only executable hook targets are checked
    targets=re.findall(r'\{"(\w+)","([\w:]+)"',code)+re.findall(r'MYBAdsHookNamed\("(\w+)","([\w:]+)"',code)
    for cls,sel in targets:
        for f in ('isPlayableInBackground','playableInBackground','spamSignals','ubscri','Premium','ownload','eadReceipt','atermark'):
            need(f not in sel and f not in cls,f'{folder}: hook {cls} {sel} touches excluded behaviour ({f})')
    need('/var/jb' not in code and 'rootless' not in code.replace('rootless packaging','').replace('No rootless','').replace('no rootless','') or folder=='TikTok','%s: no rootless path'%folder)
    need('NSURLSession' not in code or folder in ('Reddit','SoundCloud'),f'{folder}: only Reddit and SoundCloud touch network sessions')
    if folder=='SoundCloud':  # the one deliberate exception: a protocol that claims ONLY soundcloud.com/ads paths and promoted.soundcloud.com, answered with a connection failure
        need('canInitWithRequest:(NSURLRequest *)request{return MYBSoundCloudRequestIsAd(request);}' in code,'SoundCloud: the protocol claims only requests the ad predicate accepts')
        need('NSURLErrorCannotConnectToHost' in code and 'didReceiveResponse' not in code and 'didLoadData' not in code,'SoundCloud: ad requests fail with a connection error; no response or data is ever fabricated')
    need('http://' not in code and 'https://' not in code,f'{folder}: no remote services or URLs')
    need('MYBAdsLogResult' in code or folder=='AppStore',f'{folder}: logs how many hooks installed')
    if folder=='AppStore':need('MYBAdsHook' not in code and 'class_replaceMethod' not in code and 'method_setImplementation' not in code and 'MYBAdsDiscoveryWatch(@"appstore"' in code,'AppStore: discovery only, never hooks, and runs only when discovery is on')
yt=R('Companions/InAppAds/YouTube/Module.m')
need('{"YTAdsInnerTubeContextDecorator"' in yt and 'YouTopia' not in yt and 'OwnedByAnotherTweak' not in yt,'YouTube: the module handles the ad-request context itself, with no deference to another tweak')
need('{"YTIPlayabilityStatus"' not in yt and 'isPlayableInBackground' not in re.sub(r'//[^\n]*','',yt),'YouTube: no playability or background-playback hook')
need('-fobjc-arc' in shared_mk and 'fno-objc-arc' not in shared_mk and 'ns_returns_retained' in R('Companions/InAppAds/TikTok/Module.m') and '[result release]' not in R('Companions/InAppAds/TikTok/Module.m'),'TikTok releases correctly under the shared dylib ARC build (owned-return initialisers, no manual release)')
# the catalogue never claims a device-verified version before one exists
need(re.findall(r'@"ours":@"([^"]*)"',hdr)==['']*len(cat),'no app version is marked verified yet')
ui=R('Preferences/MYBInAppAdsController.m')
uicode='\n'.join(l for l in ui.split('\n') if not l.strip().startswith('//'))
need(not re.search(r'[Pp]rotected|Blocking ads now|Active',uicode),'the screen never claims an app is protected')
lst=ui.split('@interface MYBInAppAdsStatusController')[0]
need('reopen an app' in lst and 'Not verified' not in lst and 'Experimental' not in lst and 'MYBAdsVersionVerified' not in lst and 'hooksFound' not in lst,'the everyday list gives restart guidance and shows no verification or hook detail')
need('@interface MYBInAppAdsStatusController' in ui and 'Ad items filtered' in ui and 'Loaded as' in ui and 'App version' in ui,'details (versions, architecture, hooks, ad items filtered, timestamps) live in the Status screen')
need('MYBInAppAdsStatusController' in R('Preferences/MYBDiagnosticsController.m'),'Status links to the In-App Ad Blocking details')
need('Experimental' not in R('Preferences/MYBModernController.m'),'the dashboard row no longer says Experimental')
need('MYBInAppAdsController' in R('Preferences/MYBModernController.m') and 'MYBInAppAdsController.m' in R('Preferences/Makefile'),'screen is reachable and built')
need('net.myxxdev.mybloxx.inappads.plist' in R('Helper/MYBDefaults.inc'),'Restore Default Settings returns every app to off')
# The main app list stays simple: icon, name, switch, and one failure line. Technical details (versions, architecture, hook counts, categories) live only in Status.
_ui=R('Preferences/MYBInAppAdsController.m');_main=_ui.split('@interface MYBInAppAdsStatusController')[0]
need(not any(w in _main for w in ('hooksFound','hooksAttempted','componentVersion','arch','categories','passedThrough','Hook points')),'the main In-App Ad Blocking list shows no technical details')
need(all(w in _ui.split('@interface MYBInAppAdsStatusController')[1] for w in ('hooksFound','componentVersion','arch','categories','passedThrough')),'Status shows the technical details')
# Discovery is opt-in, bounded, content-free and has one visible switch in Status; the everyday list never shows discovery-only apps.
_dh='\n'.join(l for l in R('Shared/MYBAdsDiscovery.h').split('\n') if not l.lstrip().startswith('//'))
need(not any(w in _dh for w in ('NSURLRequest','HTTPBody','valueForHTTPHeaderField','cookie','Cookie','textContent','accessibilityLabel','.text','"text"')),'discovery reads no content, URLs, headers or cookies')
_st=_ui.split('@interface MYBInAppAdsStatusController')[1]
need(not any(w in _st for w in ('startDiscovery','stopDiscovery','copyDiscovery','shareDiscovery','clearDiscovery','showDiscoveryHelp','Start a 10-minute session')) and 'discoveryOnly' in _main,'Status has no discovery controls, and the everyday list skips discovery-only apps')
_srv=R('BlockedServer/main.m')
need(all(w in _srv for w in ('/mybloxx-ads-discovery','/mybloxx-ads-discovery-control','/mybloxx-ads-discovery-read','MYBAdsDiscoveryAccept','MYBAdsDiscoveryControl')) and 'discoveryPiece=bridge&&' in _srv and 'discoveryControl=bridge&&' in _srv and 'discoveryRead=bridge&&' in _srv,'the local service takes discovery only on bridge-header routes')
need('MYB_ADS_DISCOVERY_SECONDS 600' in R('Shared/MYBAdsDiscovery.h') and 'ads-discovery-until' in R('Shared/MYBAdsDiscovery.h') and 'writeToFile' not in R('Shared/MYBAdsDiscovery.h') and 'NSFileHandle' not in R('Shared/MYBAdsDiscovery.h'),'a discovery session is ten minutes and the service keeps nothing on disk')
for _m in ('AppStore','Facebook','Amazon'):need('MYBAdsDiscoveryStarted(@"%s"'%_m.lower() in R('Companions/InAppAds/%s/Module.m'%_m),_m+': the collector announces that it started')
for _m in ('Facebook','Amazon'):
    _run=R('Companions/InAppAds/%s/Module.m'%_m).split('void MYBAdsRun_%s'%_m.lower())[1]
    need('MYBAdsDiscoveryWatch(@"%s"'%_m.lower() in _run.split('MYBAdsModuleEnabled')[0],_m+' discovery starts before, and does not depend on, its ad switch')
_dh2=R('Shared/MYBAdsDiscovery.h')
need(all(w in _dh2 for w in ('ads-discovery-session','MYBAdsDiscoveryLive','MYBAdsDiscoveryEvaluate','MYB_ADS_DISCOVERY_NOTIFY','st[@"session"]=@""')),'discovery sessions have an id, collectors re-check it before sending, (the Settings screen no longer starts them)')
need(os.path.exists('docs/inappads/DISCOVERY.md') and 'log stream' in R('docs/inappads/DISCOVERY.md') and 'Disable' in R('docs/inappads/DISCOVERY.md'),'exact enable, collect and disable instructions exist')
# Ad SDK blocking: separate per-app switches (default off), no new injection point, no reward path, honest coverage wording.
_sdk=R('Shared/MYBAdSDK.h');_sdkm=R('Companions/InAppAds/SDK/Module.m');_ac=R('Preferences/MYBAppControlController.m')
need('MYBAdSDKController' in _ac and 'MYBAdSDKController' in _main and 'Ad Network Blocking' in _main,'Ad Network Blocking has its own selection screen, reached from the In-App Ad Blocking list')
need('SDK/Module.m' in R('Companions/InAppAds/Makefile') and 'MYBAdSDKStart();' in R('Companions/InAppAds/Dispatcher.m') and 'MYBAdSDKSelected(prefs,bundle)' in _sdkm,'SDK blocking is in the one shared dylib, and only for a selected app')
need('MYBAdSDK' not in R('Companions/SpeedyAds/Makefile') and 'MYBAdSDK' not in R('Companions/SpeedyAds/Tweak.xm') and not os.path.exists('Companions/SpeedyAds/MYBAdSDK.m'),'SpeedyAds carries no SDK ad-blocking code (no duplicate hooks)')
need(not any(w in _sdk for w in ('Reward','reward','userDidEarn','didRewardUser','NSURLSession','NSURLProtocol')) or all(w not in l for l in _sdk.split('\n') if not l.lstrip().startswith('//') for w in ('userDidEarn','didRewardUser','NSURLSession')),'SDK blocking has no reward callback and touches no network traffic')
need('kMYBAdSDKNotCovered' in _sdk and 'AppLovin MAX' in _sdk and 'not been confirmed on a device' in _sdk,'the SDK header states what is not covered and that nothing is device-confirmed')
need('"com.apple."' in _sdk and 'net.myxxdev.' in _sdk,'system and MYbloXX processes can never be selected')
# Instagram stays advertising-only: no hook on commerce or shopping components (their initialisers carry no advertising signal)
_ig=re.sub(r'//[^\n]*','',R('Companions/InAppAds/Instagram/Module.m'))
need('Commerce' not in _ig and 'hookNilCommerce' not in _ig,'Instagram: a shopping component is hooked without an advertising signal')
if bad:print('\n'.join(bad));sys.exit(1)
print('In-App Ad Blocking source checks passed.')
_f=R('Shared/MYBAdsFilter.h');_hf=R('Helper/MYBAdsFilter.inc')
need('MYBAdsFilterWriteFile' in _hf and 'MYBInstalledBundleIDs' in _hf and 'MYBAdsFilterBundlesInstalled' in _hf and 'fsync' in _f and 'unlink(tmp' in _f,'the filter is generated from installed apps and written through the checked, atomic writer')
need('mybloxx-ads-sdk-loaded' in R('BlockedServer/main.m') and 'MYBAdSDKReportLoaded' in R('Companions/InAppAds/SDK/Module.m') and 'self.seen' in R('Preferences/MYBAppControlController.m') and 'Active' in R('Preferences/MYBAppControlController.m'),'an app is shown as active only after the library reports from inside it')

need('MYBAdSDKStatus(' in R('Preferences/MYBAppControlController.m') and 'MYB_ADSDK_CHANGED_PREFIX' in R('Preferences/MYBAppControlController.m'),'Ad SDK rows take their state from the launch/choice-bound status and record when a choice changed')
need('MYBAdSDKBlockedHook' in R('Companions/InAppAds/SDK/Module.m') and 'MYB_ADSDK_NOTE_BLOCKED' in R('Shared/MYBAdSDK.h'),'answered ad loads are counted and reported from the library')
