# Hybrid rules accounting

Generated from `rules/canonical.json` by `tools/generate-hybrid-report.py`. Do not edit by hand.

Sources: CustomV55.pac (friend PAC, 2026/09/08); 27 ad-test screenshots at superadblocktest.com (109 red rows, read visually); ad-test re-run at superadblocktest.com (87%: 428 blocked, 54 reachable): 12 more hosts blocked, the rest stay held with stated reasons.

| List | Count |
|---|---|
| Default additions (all modes) | 326 |
| noXXX-only additions | 23 |
| Exact-host exceptions (every mode) | 27 |
| Conditional exceptions (DIRECT unless the named option is on) | 1 |
| Screenshot rows held with a stated reason | 1 |
| CustomV55 candidates excluded | 88 |

Screenshot accounting, row by row, is in `rules/SCREENSHOTS.md`.

## Conditional exceptions

- `graph.facebook.com`: DIRECT in every mode except when blockAdSense is selected. Applied by the generator (`exact_allow_unless`), so it holds in all 32 combinations and the standalone files.

## Exact-host exceptions (27)

Each host is tied to the CustomV55 whitelist token it comes from. V55 matches the token anywhere in a URL; an exact host cannot, so every real host of a site is listed (apex and www where the site uses both).

| V55 token | Hosts |
|---|---|
| `aadcdn.msauth.net` | `aadcdn.msauth.net` |
| `aadcdn.msfauth.net` | `aadcdn.msfauth.net` |
| `ads.google.com` | `ads.google.com` |
| `adssettings.google.com` | `adssettings.google.com` |
| `cdn.branch.io` | `cdn.branch.io` |
| `gu-global.com` | `gu-global.com`, `www.gu-global.com` |
| `impression.co.uk` | `impression.co.uk`, `www.impression.co.uk` |
| `m.buy123` | `m.buy123.com.tw` |
| `marketing-gw.jkopay.com` | `marketing-gw.jkopay.com` |
| `marketingplatform.google.com` | `marketingplatform.google.com` |
| `marketingturkiye` | `marketingturkiye.com.tr`, `www.marketingturkiye.com.tr` |
| `marketingweek` | `marketingweek.com`, `www.marketingweek.com` |
| `msg.ettoday.net` | `msg.ettoday.net` |
| `sponsorunited` | `sponsorunited.com`, `www.sponsorunited.com` |
| `tw.sym-global.com` | `tw.sym-global.com` |
| `video-api.yql.yahoo.com` | `video-api.yql.yahoo.com` |
| `yieldstreet` | `yieldstreet.com`, `www.yieldstreet.com` |
| (ad-test page) | `superadblocktest.com`, `www.superadblocktest.com` |

Checked by `tests/policy-exceptions.js`: every host is DIRECT in all 40 PAC files; apex/www pairs are complete; `marketingturkiye.com` (a different domain) is not exempt.

## Default additions (326)

- `1rxntv.io`
- `2443march2024.com`
- `4dex.io`
- `4f9566374d.com`
- `536435ba94.com`
- `888media.net`
- `a-mx.com`
- `a4p.adpartner.pro`
- `a64x.com`
- `ad.cardu.com.tw`
- `ad.ettoday.net`
- `ad.line-scdn.net`
- `ad.linksynergy.com`
- `ad.setn.com`
- `ad1.ettoday.net`
- `ad2.ettoday.net`
- `ad2iction.com`
- `adc.tamedia.com.tw`
- `adentifi.com`
- `adfurikun.jp`
- `adgeek.net`
- `adkernel.com`
- `admsapi.businessweekly.com.tw`
- `adncdn.net`
- `adtrafficquality.google`
- `agent.tamedia.com.tw`
- `ahmybid.net`
- `aiurl.tw`
- `ak.hetartwg.com`
- `akstat.io`
- `akumachi.com`
- `alb.reddit.com`
- `alocdn.com`
- `amoad.com`
- `amxrtb.com`
- `api-a.op-mobile.opera.com`
- `api.amplitude.com`
- `api.onesignal.com`
- `api.optimizely.com`
- `api.partnerstack.com`
- `api.viglink.com`
- `api2.amplitude.com`
- `app-vibe.com`
- `app.posthog.com`
- `app.usercentrics.eu`
- `appointeeivyspongy.com`
- `appsflyersdk.com`
- `assets.kochava.com`
- `avivid.likr.tw`
- `azotesdanian.cyou`
- `bankingbloatedcaptive.com`
- `bilanx.dcard.tw`
- `biodegradabletrick.com`
- `blismedia.com`
- `bnc.lt`
- `breaktime.com.tw`
- `browser-intake-datadoghq.com`
- `browser.events.data.msn.com`
- `c.bing.com`
- `c.clarity.ms`
- `ca7d0bd322.com`
- `cadmus.script.ac`
- `cameesse.net`
- `cdn.adbert.com.tw`
- `cdn.amplitude.com`
- `cdn.itskiddoan.club`
- `cdn.onesignal.com`
- `cdn.optimizely.com`
- `cdn.privacy-mgmt.com`
- `cdn.pubfuture-ad.com`
- `cdn.rudderlabs.com`
- `cdn.segment.com`
- `cdn.siftscience.com`
- `cdn.viglink.com`
- `chartboost.com`
- `chaseherbalpasty.com`
- `checkingvpn.com`
- `cherrytale.tferwq.com`
- `cldirplarimo.com`
- `click.linksynergy.com`
- `click.mailchimp.com`
- `click.pdc-feed.com`
- `clickadu.com`
- `clickforce.com.tw`
- `clientstream.launchdarkly.com`
- `cloudflareinsights.com`
- `cm.daexauto.com`
- `cmp.osano.com`
- `cnemicsynthol.qpon`
- `coinimp.com`
- `compass-fit.jp`
- `confiant-integrations.net`
- `connect.facebook.net`
- `consent.trustarc.com`
- `contextweb.com`
- `creative-stat1.com`
- `creative.mnaspm.com`
- `creative.xlirdr.com`
- `criteo.com`
- `customer.io`
- `cxense.com`
- `d.reddit.com`
- `dai.google.com`
- `device-metrics-us-2.amazon.com`
- `device-metrics-us.amazon.com`
- `digitalaudience.io`
- `dimpled-frame.pro`
- `dns-finder.com`
- `do-vpn.com`
- `doleyorpinc.website`
- `eedsaung.net`
- `endowmentoverhangutmost.com`
- `eu.amplitude.com`
- `eu.posthog.com`
- `events.launchdarkly.com`
- `evt-sync.quantifi-cdn.com`
- `experttrafficcounter.com`
- `eyereturn.com`
- `falcon-creative-ak.pixfs.net`
- `falcon.pixnet.net`
- `fee9cd19e4.com`
- `fingerprintjs.com`
- `fixed-anger.com`
- `flaressaltee.space`
- `fls-na.amazon.com`
- `fpjs.io`
- `fyber.com`
- `g.jwpsrv.com`
- `genieesspv.jp`
- `geo.q5media.net`
- `geolocation.onetrust.com`
- `gfxdn.pics`
- `go.imkirh.com`
- `go.kbnmnl.com`
- `go.mnaspm.com`
- `go.redirectingat.com`
- `go.rmishe.com`
- `go.rmzsglng.com`
- `go.skimresources.com`
- `go.xlirdr.com`
- `go.xlviiirdr.com`
- `gulsachpyrexia.uno`
- `hadronid.net`
- `happix-pilot-api.pixnet.cc`
- `hare200.com`
- `hbfulzie.life`
- `holahupa.com`
- `hwop4.bpeaed.com`
- `i-mobile.co.jp`
- `i.instagram.com`
- `impolitepatience.com`
- `indianlinkexchange.com`
- `indoneviler.rest`
- `ingage.tech`
- `inhouse-web.com`
- `intentiq.com`
- `interbuzznews.com`
- `invle.co`
- `islamiclyricallyvariable.com`
- `jodhpurrarish.digital`
- `js.driftt.com`
- `kdcl.pchome.com.tw`
- `kmindex.ru`
- `kochava.com`
- `krushmedia.com`
- `l.hyenadata.com`
- `l.tyrantdb.com`
- `lap-click.tr.line.me`
- `lightingstipulate.com`
- `lihi2.com`
- `links.wu4647.xyz`
- `links.wusi647gk.xyz`
- `log.mmstat.com`
- `logx.optimizely.com`
- `lr-ingest.com`
- `m.cowrp.xyz`
- `m3-beacon.adlyric.io`
- `maio.jp`
- `masterfornews.com`
- `mcs-va.tiktokv.com`
- `measureadv.com`
- `megapodacutest.digital`
- `messy-brain.com`
- `metrics.brightcove.com`
- `metricswpsh.com`
- `mia-placement-server.rubiconproject.net.akadns.net`
- `mineralt.io`
- `minutemedia-prebid.com`
- `mon.tiktokv.com`
- `monetag.com`
- `mountain.com`
- `nam.veta.naver.com`
- `nannyirrationalacquainted.com`
- `nend.net`
- `nereserv.com`
- `ngfts.lge.com`
- `ntvpforever.com`
- `nwwrtbbit.com`
- `oa.opera.com`
- `oftqkeovq.com`
- `onead.onevision.com.tw`
- `openwebmp.com`
- `optable.co`
- `optvz.com`
- `orgotitedu.info`
- `ormanizeled.com`
- `outbrain.com`
- `palatable-soft.com`
- `panel.xn--9kqw7o.com`
- `pangle.io`
- `pangleglobal.com`
- `parcookgoofah.qpon`
- `partnerstack.com`
- `pb.adriver.ru`
- `pghub.io`
- `pippio.com`
- `pixel.quora.com`
- `pixoctopus.pixnet.net`
- `polarbyte.com`
- `poorlylift.com`
- `pps-log.op-mobile.opera.com`
- `prf.hn`
- `privacyportal.onetrust.com`
- `prod.cloud.ogury.io`
- `proftrafficcounter.com`
- `prozoarasinergan.com`
- `px-collect7.nexbid.net`
- `px.srvcs.tumblr.com`
- `qevents.quora.com`
- `quantcast.com`
- `quickerapparently.com`
- `r.morexpbb.net`
- `rcrex.sgjixie1.com`
- `receptivity.io`
- `recordedthereby.com`
- `redirect.viglink.com`
- `redirector.googlevideo.com`
- `redirector.skimresources.com`
- `refersion.com`
- `rezync.com`
- `rhea-cache.advividnetwork.com`
- `rtbwise.com`
- `rudderstack.com`
- `s.aplagoon.xyz`
- `s.clarity.ms`
- `s.skimresources.com`
- `s.youtube.com`
- `sacdnssedge.com`
- `sdk.privacy-center.org`
- `sdkapi.dsp-api.moloco.com`
- `sdkopmetrics-eu.dsp-api.moloco.com`
- `securedevicevpn.com`
- `securitymobsoft.com`
- `seedtag.com`
- `segment.io`
- `servenobid.com`
- `setddg.com`
- `shakingtacklingunpeeled.com`
- `shareasale.com`
- `shhchack.digital`
- `show-creative1.com`
- `show-sb.com`
- `siftscience.com`
- `silencyboubous.space`
- `sklentspelves.digital`
- `slickstream.com`
- `smartclip.com`
- `snap.licdn.com`
- `soumehoo.net`
- `special-newseeds.com`
- `ssl.p.jwpcdn.com`
- `sta.cmh.com.tw`
- `stackadapt.com`
- `statdynamic.com`
- `sun.advividnetwork.com`
- `surftracksafe.com`
- `syenitetatler.tech`
- `syncingbridge.com`
- `t-odx.op-mobile.opera.com`
- `t.pepperjamnetwork.com`
- `t.skimresources.com`
- `t.ssp.hinet.net`
- `taboola.com`
- `tagmanager.google.com`
- `tapad.com`
- `tasterscaltha.com`
- `tf4srv.com`
- `top-fwz1.mail.ru`
- `tr.facebook.com`
- `tr.snapchat.com`
- `track.coolestdiscount.club`
- `track.customer.io`
- `track.hubspot.com`
- `track.linksynergy.com`
- `track.traffichub.club`
- `tracking.shopee.tw`
- `tracktor.me`
- `translatorenence.com`
- `trasupr.com`
- `trustedstack.com`
- `u3y8v8u4.aucdn.net`
- `ubas.setn.com`
- `ucfunnel.com`
- `uidapi.com`
- `urad.com.tw`
- `us.i.posthog.com`
- `usbrowserspeed.com`
- `uuidksinc.net`
- `v.opgaming.xyz`
- `video.saawsedge.com`
- `vip.stakeclick.com`
- `vm5apis.com`
- `vortex.data.microsoft.com`
- `vpon.com`
- `wearychallengeraise.com`
- `websecretphone.com`
- `widget.intercom.io`
- `workshopspb.ru`
- `worstideatum.com`
- `www.anrdoezrs.net`
- `www.awin1.com`
- `www.cedarfx.com`
- `www.dpbolvw.net`
- `www.tkqlhce.com`
- `wzrkt.com`
- `zenaps.com`

## noXXX-only additions (23)

- `19sex.live`
- `arkrecode3.ero-labs.com`
- `avtv.cc`
- `cdn3.r34comix.com`
- `celebs.live`
- `chat4meets.com`
- `glowdate.com`
- `haveameet.com`
- `javhdporn.live`
- `jerkmatelive.org`
- `l.erodatalabs.com`
- `l.h-ero.games`
- `labadena.com`
- `make-love.club`
- `markswebcams.com`
- `mrlsexdoll.com`
- `perksdating.com`
- `roe.ero-labs.one`
- `stripchat.com`
- `strpst.com`
- `swag.live`
- `www.djpcraze.com`
- `xlivesex.com`

## Screenshot rows held, with the reason (1)

- `graph.facebook.com`: Facebook Graph API used for sign in and apps; kept DIRECT in every mode except blockAdSense (exact_allow_unless)

## CustomV55 candidates excluded (88)

Also held: chimpstatic.com (Mailchimp form assets), acsbapp.com (accessibility overlay), pdst.fm (podcast download redirect), s.click.aliexpress.com (affiliate redirect), clarity.ms (vendor dashboard; c. and s. are blocked). Apple/certificate/update/OS services, shared cloud or CDN infrastructure, messaging cores, fonts and libraries, regional app back ends, legitimate sites, feature SDK back ends, and TikTok telemetry are not merged without device evidence

- `54647.io`
- `54647joy.com`
- `88p2p.com`
- `98pro.cc`
- `a.line.me`
- `acsbapp.com`
- `anrdoezrs.net`
- `api.like.co`
- `api.onesignal.com`
- `appattest.apple.com`
- `btrace.qq.com`
- `bundler.wix-code.com`
- `button.like.co`
- `c2shb-oao.ssp.yahoo.com`
- `cdn.bncloudfl.com`
- `cdn.pncloudfl.com`
- `chimpstatic.com`
- `clarity.ms`
- `cm.lndata.com`
- `code.createjs.com`
- `consent.cmp.oath.com`
- `content.uplynk.com`
- `corgi.gaii.ai`
- `crl.apple.com`
- `crs-event.line.me`
- `crs-hometab-event.line.me`
- `d18t35yyry2k49.cloudfront.net`
- `dcard6281.zendesk.com`
- `ddgattach.s3.amazonaws.com`
- `dthepeoplewhoc.org`
- `ec-api.dcard.tw`
- `firebaselogging-pa.googleapis.com`
- `firehose.ap-southeast-1.amazonaws.com`
- `frog.wix.com`
- `gdmf.apple.com`
- `go-shop.tw`
- `guzzoni-apple-com.v.aaplimg.com`
- `gw.line.naver.jp`
- `h.trace.qq.com`
- `host886.com`
- `hotcoin.com`
- `interstitial-content.otherlevels.com`
- `iqq1.me`
- `isx.unity3d.com`
- `iu6xoulkc1.execute-api.us-east-1.amazonaws.com`
- `js.hs-scripts.com`
- `kinesis.ap-southeast-1.amazonaws.com`
- `lan.line.me`
- `lduhtrp.net`
- `log-upload.tiktokv.com`
- `mediation.unity3d.com`
- `medium.gaii.ai`
- `mesu.apple.com`
- `mon.tiktokv.com`
- `mz.unity3d.com`
- `news.ssp.qq.com`
- `nmetrics.samsung.com`
- `ocsp.apple.com`
- `ocsp.digicert.com`
- `ocsp.r2m02.amazontrust.com`
- `ocsp2.apple.com`
- `offerwall.unity3d.com`
- `operate-sdk-telemetry.unity3d.com`
- `p.typekit.net`
- `pbd.yahoo.com`
- `pbs.yahoo.com`
- `pdst.fm`
- `pixel.wp.com`
- `pusher.com`
- `s.click.aliexpress.com`
- `search.app.goo.gl`
- `search.fanyafree.com`
- `smart-placements-sdk.ex.co`
- `ssl.pstatic.net`
- `stake.com`
- `static.mailerlite.com`
- `staticfile.qq.com`
- `tivan.naver.com`
- `track.mailerlite.com`
- `ts.line-apps.com`
- `ts.line.me`
- `v55.mybloxx.invalid`
- `valid.apple.com`
- `vpp.itunes.apple.com`
- `widgets.lendingtree.com`
- `wos.go.link`
- `www.cool3c.com`
- `yahoo-match.dotomi.com`
