# Remaining app leads: what was assessed and what was done

Each lead was read for its advertising-only portion separately. Unlock, premium and jailbreak-hiding code in the same project was never
a reason to skip an app; it was simply not used. Nothing here is device-verified.

| App (bundle id) | Lead | Ad-only portion | Result |
|---|---|---|---|
| Threads (com.burbn.barcelona) | ThreadsPulse (no licence file; names only) | request, sponsored items, feed insertion | **Implemented** (6 rules) |
| Gmail (com.google.Gmail) | gmail-no-ads (2021; names only) | ad row height | **Implemented** (4 rules); classes may no longer exist |
| Douban (com.douban.frodo) | doubanNoads (MIT) | launch ad, commercial and review-list ads | **Implemented** (5 rules) |
| QQ Music (com.tencent.QQMusic) | QQMusicNoAds (MIT) | launch ad | **Implemented** (1 rule); the audio-quality unlock was not used |
| Sogou Input (com.sogou.sogouinput) | sougouinputNoAds (MIT) | launch ad, native ad cells | **Implemented** (4 rules); jailbreak and purchase flags not used |
| WeChat (com.tencent.xin) | WechatNoAds (MIT, 2023) | launch ad, Moments ad data and requests | **Implemented** (11 rules); jailbreak hiding not used |
| Douyin (com.ss.iphone.ugc.Aweme, lite) | DYYY (MIT) | ad classification of the video model | **Implemented** by extending the TikTok module's classifier (three extra selectors) and its bundle list |
| App Store (com.apple.AppStore) | none found | sponsored search results, Today ads | **Discovery only** (opt-in): no published interface to hook. See DISCOVERY.md |
| LINE (jp.naver.line) | NEIN | ad views | **Not implemented.** Obstacle: NEIN removes ads by matching view class names against loose patterns (AdView, AdCell, HomeTabAd...), not by an exact interface, so it can hide views that are not ads; no exact class or selector is published. Google Mobile Ads loads inside LINE can be covered by choosing LINE under Ad Network Blocking. Needs a device class list. |
| Twitch (tv.twitch) | TwitchAdBlock (MIT) | home headliner ad; video ads | **Not implemented.** Obstacles: video ads are removed by rewriting stream playlists through a remote proxy service, which is not an on-device change and sends viewing traffic to a third party; the headliner hook sets a Swift instance variable to nil, which is unsafe if that variable is not optional in the installed version, and cannot be checked without a device. |
| LinkedIn (com.linkedin.LinkedIn) | linkedin-pro-ios (GPL-3.0, Swift) | sponsored and promoted sweep | **Not implemented.** Obstacle: its ad hiding is a runtime sweep over Swift view-model and view types found by probing, not a stable published interface; no class list for the current LinkedIn is available here. Needs a device class list. |
| Spotify (com.spotify.client) | EeveeSpotifyNext (GPL-3.0) | none separable | **Not implemented, and not implementable as an ad-only change.** The project removes ads by making the app believe the account is Premium (product-state and plan responses). That is account-state spoofing, not an ad hook, and no separable ad placement exists in it. |
| Gaode / AMap (com.autonavi.amap) | GaodeClean (MIT) | splash and operations banner | **Not implemented.** Obstacle: it identifies ad views by geometry and an obfuscated string table, with no stable class or selector names; reimplementing it independently needs a device view dump. |
| Bilibili | cxz/BiliBiliTweak 9062479 and BiliBiliMApp 37b8d31 (MIT) | tv.danmaku.bilianime | **Implemented, awaiting device verification** (ad-only part). Read in full for ad code. Adopted: the home-feed response (`https://app.bilibili.com/x/v2/feed/index`) loses `cm_v1`/`cm_v2` cards, `cm_double_v7`/`v9` cards carrying `ad_info`, and banner items flagged `is_ad`; search results lose `video_ad`, `picture_ad` and `brand_ad_giant` items. Not adopted because they are not advertising decisions: the rating, push-guide, teen-mode and tab-bubble popups, removal of every `banner_v8` banner, live-room panels and appointment buttons, `special_s` cards, related-game and goods cards, search default words, and its playback, skin and account features. The feed hook wraps a request's completion handler, so it assumes the app still builds `BFCRequest` with that initialiser; each hook is off if its signature differs. |
| Telegram forks (mxgram) | mxgram | not an ad blocker | Out of scope: a client fork, no ad-only content. |

Ad SDK blocking (Google Mobile Ads, Meta Audience Network, Vungle/Liftoff, Unity Ads, Mintegral and LevelPlay loads, per app, default on) is a separate infrastructure feature. See SDK-AUDIT.md.
