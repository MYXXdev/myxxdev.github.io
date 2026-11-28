"""One-shot, documented merge of the CustomV55 and ad-test-screenshot candidates into rules/canonical.json.
Decisions are explicit lists (below), not a text diff. Re-running is idempotent. Output provenance lives in canonical['hybrid'].
Policy: Default stays the foundation. A candidate is merged only if it is an ad, tracker, telemetry, fingerprinting or miner
endpoint that is not auth, certificate, OS update, Apple, payment, media delivery or shared infrastructure. Everything else is held
(needs device evidence) or excluded (documented reason). Adult hosts go to the noXXX option only. Nothing here weakens the
8.8.8.8 bypass or the blocking sink."""
import json, re
from pathlib import Path
R = Path(__file__).parent; C = json.loads((R / 'canonical.json').read_text())
UP = Path('/mnt/user-data/uploads')

def covered(h, S):
    p = h.split('.'); return any('.'.join(p[i:]) in S for i in range(len(p)))

# ---- screenshot decisions (109 recorded red rows) ---------------------------------------------------------------------
SCREEN_BLOCK = '''c.bing.com fyber.com contextweb.com stackadapt.com c.clarity.ms s.clarity.ms api.amplitude.com api2.amplitude.com
cdn.segment.com segment.io quantcast.com cloudflareinsights.com app.posthog.com eu.posthog.com us.i.posthog.com cdn.rudderlabs.com
pippio.com uidapi.com kochava.com wzrkt.com lr-ingest.com coinimp.com mineralt.io clickadu.com tr.facebook.com tr.snapchat.com
snap.licdn.com pixel.quora.com qevents.quora.com px.srvcs.tumblr.com top-fwz1.mail.ru ngfts.lge.com smartclip.com
device-metrics-us.amazon.com device-metrics-us-2.amazon.com g.jwpsrv.com metrics.brightcove.com ad.linksynergy.com s.skimresources.com
t.skimresources.com cdn.viglink.com api.viglink.com api.partnerstack.com zenaps.com t.pepperjamnetwork.com logx.optimizely.com
events.launchdarkly.com track.hubspot.com track.customer.io browser-intake-datadoghq.com browser.events.data.msn.com'''.split()
# Round 2 (user ad-test re-run, 87%): reachable trackers/telemetry/vendor hosts moved from held to blocked.
ROUND2 = '''statdynamic.com pangleglobal.com customer.io partnerstack.com refersion.com rudderstack.com mcs-va.tiktokv.com mon.tiktokv.com vortex.data.microsoft.com api.optimizely.com cdn.optimizely.com fls-na.amazon.com'''.split()
SCREEN_BLOCK += ROUND2
SCREEN_HELD = {  # host: reason (needs device evidence or breaks function)
 's.youtube.com': 'YouTube playback statistics and watch history; YouTube must keep working',
 'redirector.googlevideo.com': 'video delivery redirector; blocking breaks playback',
 'dai.google.com': 'dynamic ad insertion inside video streams; blocking can break live and streamed video',
 'tagmanager.google.com': 'Tag Manager editor for site owners, not a tracker',
 'ssl.p.jwpcdn.com': 'JW Player library CDN; blocking breaks embedded players',
 'graph.facebook.com': 'Facebook Graph API used for sign in and apps; kept DIRECT in every mode except blockAdSense (exact_allow_unless)',
 'connect.facebook.net': 'Facebook SDK used for sign in; held, no decision to block',
 'i.instagram.com': 'Instagram app API host; blocking breaks the app, so it is held (noSocials is the choice for people who want Instagram blocked)',
 'd.reddit.com': 'Reddit deep-link redirector',
 'analytics.twitter.com': 'deliberately allowed by an existing Default exemption (analytics.twitter)',
 'mcs-va.tiktokv.com': 'TikTok app telemetry; app behaviour unverified', 'mon.tiktokv.com': 'TikTok app telemetry; app behaviour unverified',
 'xp.apple.com': 'Apple service host; Apple is never blocked in Default (see noApple)',
 'vortex.data.microsoft.com': 'operating-system telemetry shared with updates and sign in',
 'fls-na.amazon.com': 'Amazon shopping app logging; shared Amazon infrastructure',
 'geolocation.onetrust.com': 'consent management platform', 'privacyportal.onetrust.com': 'consent management platform',
 'consent.trustarc.com': 'consent management platform', 'sdk.privacy-center.org': 'consent management platform',
 'cdn.privacy-mgmt.com': 'consent management platform (Sourcepoint)', 'app.usercentrics.eu': 'consent management platform', 'cmp.osano.com': 'consent management platform',
 'www.anrdoezrs.net': 'affiliate click redirector; blocking strands the tapped link', 'www.dpbolvw.net': 'affiliate click redirector', 'www.tkqlhce.com': 'affiliate click redirector',
 'click.linksynergy.com': 'affiliate click redirector', 'track.linksynergy.com': 'affiliate click redirector', 'shareasale.com': 'affiliate click redirector and merchant dashboards',
 'www.awin1.com': 'affiliate click redirector', 'prf.hn': 'affiliate click redirector', 'go.skimresources.com': 'affiliate click redirector', 'go.redirectingat.com': 'affiliate click redirector',
 'redirect.viglink.com': 'affiliate click redirector', 'redirector.skimresources.com': 'affiliate click redirector', 'click.mailchimp.com': 'email link redirector',
 'partnerstack.com': 'vendor site', 'refersion.com': 'vendor site', 'customer.io': 'vendor site', 'rudderstack.com': 'vendor site',
 'fingerprintjs.com': 'fraud signal used in sign in and payments; needs a payment-flow device test', 'fpjs.io': 'fraud signal; needs a payment-flow device test',
 'siftscience.com': 'fraud signal; needs a payment-flow device test', 'cdn.siftscience.com': 'fraud signal; needs a payment-flow device test',
 'cdn.optimizely.com': 'experiment script that pages wait for; blocking can stall rendering', 'api.optimizely.com': 'experiment API',
 'clientstream.launchdarkly.com': 'feature-flag stream that apps need to start',
 'widget.intercom.io': 'support chat widget', 'js.driftt.com': 'support chat widget', 'cdn.onesignal.com': 'push notification SDK', 'api.onesignal.com': 'push notification service for apps',
 'app.adjust.com': 'deliberately allowed by an existing Default exemption (app.adjust)', 'bnc.lt': 'Branch short links open apps; an existing compatibility exception family',
 'vk.com/rtrg': 'path on vk.com; a PAC cannot see https paths and vk.com itself must stay reachable',
}
for _h in ROUND2: SCREEN_HELD.pop(_h, None)
# ---- V55 domain candidates ---------------------------------------------------------------------------------------------
V55_EXCLUDE = '''appattest.apple.com crl.apple.com gdmf.apple.com mesu.apple.com ocsp.apple.com ocsp2.apple.com valid.apple.com vpp.itunes.apple.com
guzzoni-apple-com.v.aaplimg.com ocsp.digicert.com ocsp.r2m02.amazontrust.com search.app.goo.gl firebaselogging-pa.googleapis.com
firehose.ap-southeast-1.amazonaws.com kinesis.ap-southeast-1.amazonaws.com iu6xoulkc1.execute-api.us-east-1.amazonaws.com d18t35yyry2k49.cloudfront.net
ddgattach.s3.amazonaws.com p.typekit.net code.createjs.com content.uplynk.com pusher.com dcard6281.zendesk.com www.cool3c.com gw.line.naver.jp
a.line.me lan.line.me ts.line.me ts.line-apps.com crs-event.line.me crs-hometab-event.line.me tivan.naver.com ssl.pstatic.net staticfile.qq.com
btrace.qq.com h.trace.qq.com news.ssp.qq.com api.like.co button.like.co ec-api.dcard.tw stake.com hotcoin.com 88p2p.com 54647.io 54647joy.com 98pro.cc iqq1.me
api.onesignal.com v55.mybloxx.invalid anrdoezrs.net lduhtrp.net wos.go.link nmetrics.samsung.com mz.unity3d.com mediation.unity3d.com isx.unity3d.com offerwall.unity3d.com
operate-sdk-telemetry.unity3d.com search.fanyafree.com frog.wix.com bundler.wix-code.com pixel.wp.com static.mailerlite.com track.mailerlite.com
js.hs-scripts.com cm.lndata.com dthepeoplewhoc.org interstitial-content.otherlevels.com smart-placements-sdk.ex.co corgi.gaii.ai medium.gaii.ai
widgets.lendingtree.com cdn.bncloudfl.com cdn.pncloudfl.com c2shb-oao.ssp.yahoo.com yahoo-match.dotomi.com pbs.yahoo.com pbd.yahoo.com consent.cmp.oath.com
mon.tiktokv.com log-upload.tiktokv.com chimpstatic.com acsbapp.com pdst.fm go-shop.tw host886.com s.click.aliexpress.com clarity.ms'''.split()
V55_EXCLUDE_WHY = 'Also held: chimpstatic.com (Mailchimp form assets), acsbapp.com (accessibility overlay), pdst.fm (podcast download redirect), s.click.aliexpress.com (affiliate redirect), clarity.ms (vendor dashboard; c. and s. are blocked). Apple/certificate/update/OS services, shared cloud or CDN infrastructure, messaging cores, fonts and libraries, regional app back ends, legitimate sites, feature SDK back ends, and TikTok telemetry are not merged without device evidence'
XXX_RAW = '''19sex.live avtv.cc celebs.live cdn3.r34comix.com chat4meets.com xlivesex.com jerkmatelive.org javhdporn.live markswebcams.com mrlsexdoll.com
stripchat.com strpst.com swag.live perksdating.com glowdate.com haveameet.com make-love.club l.erodatalabs.com arkrecode3.ero-labs.com
roe.ero-labs.one l.h-ero.games www.djpcraze.com labadena.com'''.split()

XXX = [h for h in XXX_RAW if not any(h != o and h.endswith('.' + o) for o in XXX_RAW)]  # apex entries already cover their subdomains
s = (UP / 'fab7fcaa-CustomV55.pac').read_text()
bd = s[s.index('var BD={') + 8:s.index('};\n\nfunction bH')]
v55 = set(re.findall(r'"([^"]+)":1', bd))
base = set(C['base']['domains'])
# the base before this script ran (so re-running is stable)
prior = set(C.get('hybrid', {}).get('default_add', []))
base0 = base - prior
v55_only = sorted(h for h in v55 if not covered(h, base0))
excl = set(V55_EXCLUDE) | set(XXX_RAW)
v55_merge = [h for h in v55_only if h not in excl and not any(h.endswith('.' + x) for x in XXX_RAW) and not re.fullmatch(r'[\d.]+', h)]
v55_ip = [h for h in v55_only if re.fullmatch(r'[\d.]+', h)]
default_add = sorted(set(v55_merge) | set(SCREEN_BLOCK))
default_add = [h for h in default_add if not covered(h, base0) or h in SCREEN_BLOCK]
# compatibility exceptions found in the V55 whitelist that the shipping Default really blocks (verified against the shipping PAC)
# Compatibility exceptions: each exact host is tied to the V55 whitelist token it comes from. V55 matches the token anywhere in
# the URL; the exact-host list cannot, so every real host of the site is listed (apex and www where the site uses both).
COMPAT = {
 'marketing-gw.jkopay.com': ['marketing-gw.jkopay.com'], 'marketingplatform.google.com': ['marketingplatform.google.com'],
 'adssettings.google.com': ['adssettings.google.com'], 'ads.google.com': ['ads.google.com'],
 'marketingweek': ['marketingweek.com', 'www.marketingweek.com'], 'yieldstreet': ['yieldstreet.com', 'www.yieldstreet.com'],
 'impression.co.uk': ['impression.co.uk', 'www.impression.co.uk'], 'sponsorunited': ['sponsorunited.com', 'www.sponsorunited.com'],
 'marketingturkiye': ['marketingturkiye.com.tr', 'www.marketingturkiye.com.tr'],  # the magazine's site is .com.tr; .com is a different domain
 'cdn.branch.io': ['cdn.branch.io'], 'msg.ettoday.net': ['msg.ettoday.net'], 'video-api.yql.yahoo.com': ['video-api.yql.yahoo.com'],
 'aadcdn.msauth.net': ['aadcdn.msauth.net'], 'aadcdn.msfauth.net': ['aadcdn.msfauth.net'], 'm.buy123': ['m.buy123.com.tw'],
 'gu-global.com': ['gu-global.com', 'www.gu-global.com'], 'tw.sym-global.com': ['tw.sym-global.com'],
}
exact_allow = sorted({'superadblocktest.com', 'www.superadblocktest.com', '127.0.0.1', 'localhost'} | {h for v in COMPAT.values() for h in v})
# Hosts that stay DIRECT unless a named option is selected (that option's purpose is to block them).
C['exact_allow_unless'] = {'graph.facebook.com': ['blockAdSense']}
C['options']['blockSocials']['domains_add'] = sorted(set(C['options']['blockSocials']['domains_add']) - {'graph.facebook.com'})
C['base']['domains'] = sorted((base0 | set(default_add)))
C['exact_allow'] = exact_allow
x = C['options']['blockXXX']; x['domains_add'] = sorted(set(x['domains_add']) | set(XXX))
x['kill_add'] = sorted(set(x['kill_add']) | set(XXX))  # adult hosts join the existing noXXX kill list (wins over allow rules)
C['hybrid'] = {
 'sources': ['CustomV55.pac (friend PAC, 2026/09/08)', '27 ad-test screenshots at superadblocktest.com (109 red rows, read visually)'],
 'default_add': default_add, 'noXXX_add': sorted(XXX),
 'compat_exact_allow': sorted({h for v in COMPAT.values() for h in v}), 'compat_tokens': COMPAT,
 'screenshot_held': SCREEN_HELD, 'v55_excluded': sorted(set(V55_EXCLUDE) & set(v55_only)), 'v55_excluded_reason': V55_EXCLUDE_WHY,
 'v55_not_domain_rules': {'ip_literals': v55_ip, 'regex_substrings': 'every V55 RX token is already in Default except syndicatedsearch.goog (merged as a substring)'},
}
sub = set(C['base']['block']['substrings']); sub.add('syndicatedsearch.goog'); C['base']['block']['substrings'] = sorted(sub)
(R / 'canonical.json').write_text(json.dumps(C, indent=1, sort_keys=True) + '\n')
print('default_add', len(default_add), 'noXXX_add', len(XXX), 'exact_allow', len(exact_allow), 'excluded', len(C['hybrid']['v55_excluded']), 'ip', v55_ip)
