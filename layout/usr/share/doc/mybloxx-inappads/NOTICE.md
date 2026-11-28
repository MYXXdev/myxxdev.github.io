# In-App Ad Blocking: provenance and licences

MYbloXX® In-App Ad Blocking is maintained by MYXXdev™. It ships as ONE dylib, `MYBInAppAds.dylib`, with one module per app.
This notice says, module by module, where each came from. It does not claim independence that does not exist: a module that follows
another project's code or approach is called an adaptation here, whatever its files are named.

## Adapted modules (licence follows the source)

| Module | Adapted from | Project licence | Notice kept |
|---|---|---|---|
| YouTube | PoomSmart/YouTube-X (copyright (c) 2022-2026 PoomSmart); itzzace/ytkace (copyright (c) 2026 YTKACE contributors) | MIT, MIT | LICENSES.md |
| TikTok | Selandros/TikTokClean (copyright (c) 2026 selandros) | MIT | LICENSES.md |
| Reddit | level3tjg/RedditFilter (copyright (c) 2025 level3tjg) and its newer fork and101/RedditFilter (copyright (c) 2026 and101, read at e1b597f) | MIT | LICENSES.md |
| Instagram | SoCuul/SCInsta (copyright (C) SoCuul) | GPL-3.0 | COPYING |
| SoundCloud | pstepanovum/PSSoundcloud (copyright (C) 2026 Pavel Stepanov; itself derived from SCInsta by SoCuul) | GPL-3.0 | COPYING |
| Facebook (News Feed, Watch, Stories) | Facebook-Plus (revision 1a3a98605e5d0073af32b681e4604f02fc609111; GPL-3.0): the classes, the model initialiser hook, the sponsored test and the Watch and Stories hooks | GPL-3.0 | COPYING |

## Consequence of the single dylib

The Instagram, SoundCloud and Facebook modules adapt GPL-3.0 code. They are compiled into the same dylib as every other module, so
**the whole of `MYBInAppAds.dylib` is distributed under the GNU General Public License v3**, together with the MYXXdev™ headers it
compiles in (Shared/MYBInAppAds.h, Shared/MYBAdsReport.h, Shared/MYBVersion.h). The MIT-licensed modules are compatible with that, and
their MIT notices stay in LICENSES.md. The corresponding source for the dylib is in the source archive published with each build
(Companions/InAppAds and Shared). Before the modules were merged, the GPL obligation applied to two separate dylibs only; merging them
extended it to the whole dylib. Replacing the GPL-derived modules with genuinely independent code would end that.

## Modules written against interface evidence

These were written for MYbloXX® from runtime class and selector names that other projects or class-dump headers publish, and share no
source text with them. They still implement the same decisions on the same selectors, so they are listed here as interface-derived, not
as independent designs. No licence applies to the names themselves, but the owner should treat "independent" as unproven.

| Module | Interface evidence from |
|---|---|
| YouTube Music | class-dump headers of YouTube Music (iCrazeiOS/Class-Dumped-Apps, Nosskirneh/ios-app-headers) |
| X | BHTwitter (BandarHL, no licence file) for the TFNItemsDataViewController hooks and the promoted tests |
| Messenger | FlowReconstructed (Win98Plus) for the inbox row hook and the ads_renderer unit key; SNMessenger (NguyenASang, MIT) for the advertisement story-bucket decision |
| Amazon Shopping (web content) | the marker names (data-ad-placement-metadata, data-ad-feedback-label-id) from the amznkiller selector list named in the project brief. That project could not be read or pinned, so no revision is recorded and no text is used |
| Facebook Marketplace | adamsardo/MarketplaceAdBlock (no licence file): the idea of answering ad queries by handler and filtering Marketplace responses follows it; no source text is used. Because that project carries no licence, this part is the one to replace or remove if the owner wants no reliance on it |
| Douban, QQ Music, Sogou Input | doubanNoads, QQMusicNoAds, sougouinputNoAds (iOS宝藏, MIT): class and selector names of the advertising methods only |
| WeChat | WechatNoAds (hopeless, MIT): class and selector names of the advertising methods only |
| Bilibili | BiliBiliTweak (cxz, MIT, copyright (c) 2025 cxz) and BiliBiliMApp (MIT): class names, the home feed address, and the card-type and field names of advertising cards only; the code is written independently |
| Threads | ThreadsPulse (no licence file): class and selector names only |
| Gmail | gmail-no-ads (Hao Nguyen): class names and row-height selectors only |
| App Store | no source; discovery only |
| Douyin (via the TikTok module) | DYYY (huami, MIT): the names of the three extra ad-classification selectors only |

## Research only

Projects with no licence file (for example dayanch96/YTLite, BandarHL/BHTikTok, kunihir0/DouX, Aj3radi/TGExtra) were read as research
leads and nothing from them is used. Other GPL projects read for research (dayanch96/YTMusicUltimate, appsilo/fork-FacebookPlus,
SideloadLabs/EeveeSpotifyReincarnated) are not the source of any module.

What differs from each source is listed at the top of the module's Module.m (the "PROVENANCE" comment).

## SDK/Module.m and Shared/MYBAdSDK.h (Ad Network Blocking)

Separate code written for MYbloXX from the public headers of the Google Mobile Ads and Meta Audience Network SDKs. It shares no text with any tweak. It lives in this one shared library (not in MYBSpeedyAds) and acts only in apps selected under Ad Network Blocking; this library's bundle filter names com.apple.UIKit so a selected app can load it, and every other process returns before doing anything.
