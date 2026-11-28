# Ad SDK audit: App Control and SpeedyAds

Status: audit finished. A per-app, run-time gated SDK load blocker is now IMPLEMENTED (see "What was built" at the end), covering Google Mobile Ads and Meta Audience Network loads only. It is not device-verified. Evidence tier for the rest: source inspected.

## What exists today

**App Control** (Preferences/MYBAppControlController.m, Shared/MYBAppControl.h, Helper) lets the user pick apps. While a picked app is in front,
MYbloXX® blocking is paused for the whole device and SpeedyAds is armed for that app. It is a per-app *pause plus acceleration*, not an ad blocker.

**SpeedyAds** (Companions/SpeedyAds/Tweak.xm) used to be injected through the `com.apple.UIKit` filter (every UIKit app). Its filter now names exactly the apps selected in App Control (docs/inappads/LOADING.md). It is also gated at run
time: `active` is true only when the app is selected in App Control and is not in the background. When inactive, its hooks answer with the app's own
result. What it does when active:

| Behaviour | Hook | Notes |
|---|---|---|
| Plays video faster while a full-screen ad is showing | `AVPlayer setRate:` and view-controller counters on `GADFullScreenAdViewController` (Google Mobile Ads) and `MAFullscreenAdViewController` (AppLovin MAX) | Only those two SDKs are recognised. Unity, ironSource, Meta Audience Network, IMA, Vungle and Mintegral screens are not, so their ads are not accelerated. |
| Speeds up timers inside web views | injected script scaling `setTimeout`, `setInterval`, `Date.now`, `performance.now`, media rate | Every `WKWebView` in the selected app, including SDK ad web views. |
| Reports "not jailbroken" to some SDKs | `bu_isJailBroken`, `isJailBroken`, `isJailbroken`, `isPirated`, `jailBroken`, `isDeviceJailBreak`, `isAppPirate` on 8 named SDK classes | Only boolean getters with no arguments; original called when inactive. |

## Findings against the brief

- **No fake rewards.** SpeedyAds never calls a reward callback, never fabricates a completion and never edits server traffic. A shortened ad that the ad server
  does not consider watched simply gives no reward. Nothing to remove.
- **No failure callbacks needed today.** SpeedyAds does not block loads, so it has no failure path to get wrong.
- **System-wide injection is checked, not unchecked.** The dylib loads everywhere, but every behaviour is gated by an explicit user selection and by the app being
  in the foreground. The remaining cost is that the hooks (`AVPlayer`, `WKWebView`) exist in every UIKit process even while inactive. That is existing behaviour and was
  left unchanged: narrowing the filter would break selecting an app without a respring.
- **SDK coverage gap.** Only two SDKs are recognised for acceleration. No SDK has a blocking path.

## Why no SDK blocking module was added

1. A module that fails ad loads (for example completing a Google Mobile Ads loader with an error) must be loaded into arbitrary game and utility apps. The shared
   in-app dylib is filtered to named apps. Loading it everywhere needs the same run-time gating SpeedyAds uses plus its own per-app list, because App Control means
   "pause blocking here", the opposite meaning.
2. That is a new injection surface for every app on the device and a new Settings screen. It was not built without the per-app list and a device to confirm
   it does not destabilise games.
3. The interfaces (public SDK headers for Google Mobile Ads, AppLovin MAX and Meta Audience Network loaders with their failure callbacks) are documented, so this is
   feasible. Unity, ironSource, IMA and Mintegral have no header checked: they stay unsupported, each with its specific blocker listed below. Vungle / Liftoff interstitial and rewarded are covered (see below).

## If it is built later

- A separate per-app list (not App Control), default empty, loaded through run-time gating.
- Google Mobile Ads: complete `GADInterstitialAd`, `GADRewardedAd`, `GADRewardedInterstitialAd` and `GADAppOpenAd` load handlers with a no-fill error. Never call the
  reward handler. Banner views: fail through the view's delegate.
- AppLovin MAX and Meta Audience Network: call the SDK's own did-fail-to-load delegate method with an SDK error, once.
- Tests: handler called exactly once with an error, no success path, no reward path, unrelated loads untouched.

## What was built (Shared/MYBAdSDK.h, Companions/InAppAds/SDK/Module.m, Settings > In-App Ad Blocking > Ad Network Blocking)

- **Selection:** a separate per-app list (not App Control), default empty. Key `ads-sdk-<bundle id>` in the In-App Ad Blocking preferences. System apps,
  SpringBoard and MYbloXX's own processes can never be selected. An app reads its switch when it starts.
- **Loading:** it lives in the one shared MYBInAppAds.dylib (SpeedyAds carries no SDK code). That library's filter names the catalogue apps plus exactly the apps selected here (the helper writes it; `com.apple.UIKit` is never named, see docs/inappads/LOADING.md); `MYBAdSDKStart` still returns immediately for system apps, MYbloXX and any app that is not selected. Late-loading SDK frameworks are picked up when their image loads, and at 2, 6 and 15 seconds after launch.
- **Established SDK entry points** (public headers, exact signatures checked before installing): `GADInterstitialAd`, `GADRewardedAd`,
  `GADRewardedInterstitialAd`, `GADAppOpenAd` `+loadWithAdUnitID:request:completionHandler:` (handler called once, later, with no ad and an error);
  `GADBannerView -loadRequest:` (delegate told through `bannerView:didFailToReceiveAdWithError:`); `FBInterstitialAd`, `FBRewardedVideoAd`, `FBAdView -loadAd`
  (delegate told through its did-fail-with-error method).
- **Never done:** a reward callback is never called, no ad object is made, no network traffic is touched.
- **Not covered:** AppLovin MAX (its failure callback takes an `MAError` that cannot be built without the SDK; an NSError could crash the app), Unity Ads,
  ironSource, IMA, Mintegral, Vungle banner/inline/native, and Google Ad Manager and other load variants not listed above.
- **Infrastructure versus coverage:** the selection screen, gating, signature validation and failure delivery are infrastructure with native tests. Verified SDK
  coverage is zero: nothing has been run against a real SDK on a device.

## Not-covered SDKs and why (single source: `kMYBAdSDKNotCovered` in Shared/MYBAdSDK.h)
Each is **not covered**: nothing is hooked, so the app behaves exactly as without MYbloXX. Full signature validation is already in place for
anything added later; what is missing for these is a checked header and a safe failure object. Rewarded completion is never fabricated.

| SDK | Status | Specific blocker |
|---|---|---|
| AppLovin MAX | not covered | Load failure is reported as didFailToLoadAdForAdUnitIdentifier:withError: with an MAError, a class of the SDK that has no public initialiser; an NSError there can crash the app, and building an MAError by runtime guesswork is not done. Needs the SDK's header and a verified construction path. |
| Unity Ads | not covered | The public load call takes a delegate and reports failure through unityAdsAdFailedToLoad:withError:message: with an SDK enum; the exact selector, enum values and whether show-time cancellation must also be answered are not checked against the shipped header. |
| ironSource / LevelPlay | not covered | Loading is driven by a shared singleton with several delegate protocols (ironSource and LevelPlay generations differ); which one an app uses cannot be told from here, and the failure callbacks take SDK error objects whose construction is unchecked. |
| Google IMA | not covered | Ads are requested through IMAAdsLoader and answered by a delegate with an IMAAdLoadingErrorData object; video-player lifecycle (content must resume) is part of the failure path and has not been checked against the header. |
| Mintegral | not covered | Interstitial, rewarded and banner managers each use their own delegate selectors with an NSError, but none has been checked against a shipped header here, and a rewarded flow must not be completed by MYbloXX. |

## Evidence gathered on 2026-11-17

Sources are version-pinned vendor distributions or documentation. Where a shipped header could be read, the checksum was compared with the one the vendor's own Swift package declares.

| SDK | Source | Result |
|---|---|---|
| Unity Ads | github.com/Unity-Technologies/unity-ads-ios, tag 4.19.0, commit e9fb577, `SourceCode/Public` | **Implemented.** `+load:loadDelegate:` and `+load:options:loadDelegate:`; failure `unityAdsAdFailedToLoad:withError:withMessage:` with `UnityAdsLoadError` (NSInteger, NoFill = 3). Single-argument `+load:` has no delegate and is left alone. The header states no callback thread or delegate ownership: delivery is on the main queue and the delegate is kept until delivery. |
| Mintegral | MTGSDK / MTGSDKNewInterstitial / MTGSDKReward 8.1.9 xcframeworks from github.com/Mintegral-official/MintegralAdSDK-Swift-Package releases (MTGSDK zip SHA-256 fc66c0fb…072a matches the package) | **Implemented** for `MTGNewInterstitialAdManager -loadAd` (weak `delegate`, `newInterstitialAdLoadFail:adManager:`) and `MTGRewardAdManager -loadVideoWithPlacementId:unitId:delegate:` (`onVideoAdLoadFailed:unitId:error:`). Banner, bid and splash managers are not covered. |
| LevelPlay | IronSource9.8.0.zip from github.com/ironsource-mobile/iOS-sdk (SHA-256 3fd96d6e…d636 matches the package) | **Implemented** for `LPMInterstitialAd` and `LPMRewardedAd`. Headers state callbacks run on the main thread and the delegate is held weakly; there is no delegate getter and `adId` is a unique id, not the unit id, so the unit id and delegate are recorded from `-initWithAdUnitId:` and `-setDelegate:` on the same class. Banner ads (`LPMBannerAdView`) and the legacy `IronSource` class API are not covered. |
| Vungle / Liftoff 7.x | support.vungle.com article 360048572571 and the Rewarded page (documentation only) | **Implemented**: `VungleInterstitial` / `VungleRewarded` `load:` and `…AdDidFailToLoad:withError:` (NSError). The documentation states neither a callback thread nor ownership; delivery is on the main queue. The SDK zip (vungle2-cdn-prod.s3.amazonaws.com/…/VungleAds-7.8.0.zip) is refused by this environment's network policy (CONNECT rejected), and no public repository with its headers was reachable (`Vungle/Vungle-iOS-SDK`: authentication demanded). Banner, inline and native are not covered. |
| AppLovin MAX | github.com/AppLovin/applovin-max-sdk-ios (demo apps only); Swift package binary `https://artifacts.applovin.com/ios/com/applovin/applovin-sdk/AppLovinSDK-13.7.0.xcframework.zip` | **Not covered.** The demos confirm `didFailToLoadAdForAdUnitIdentifier:withError:(MAError *)`; the framework declaring `MAError` is refused by the network policy. Earlier raw-header URLs returned 404. No MAError is invented, and NSError is not substituted. |
| Google IMA | github.com/googleads/googleads-ima-ios samples; Swift package binary `https://imasdk.googleapis.com/downloads/ima/ios/GoogleInteractiveMediaAds-ios-v3.34.1.zip` | **Not covered.** The samples confirm `adsLoader:failedWithErrorData:` with `IMAAdLoadingErrorData`; the framework is refused by the network policy. |

Other interception points for the two remaining SDKs: the network-level rules already block their ad requests; a display-level hook (like the video-speed one for `MAFullscreenAdViewController`) does not stop loading. Neither answers the app's load callback, so neither is counted as SDK coverage.
