# Prebuilt tweak sources (preserved from the original MYbloXX® archive)

These two tweaks ship in the package as prebuilt binaries. Their source is kept here, unmodified, from the original
MYbloXX® working archive (`dataplus/` and `wao/`), so the package can be audited against it.

| Folder | Ships as | What it does | Author |
|---|---|---|---|
| `DataPlus/` | `MYbloXX.dylib` (filter: com.apple.UIKit) | Hooks `CUTTelephonyManager` so cellular fast dormancy stays disabled, and `UIDevice`, `NSURLSessionConfiguration`, `NSURLSessionTask` and `_NSHTTPConnectionInfo` to keep connections from idling | MYXXdev™ |
| `WiFiAlwaysOn/` | `MYbloXX-WAO.dylib` (filter: com.apple.springboard) | Hooks `SBControlCenterSystemAgent` and `SBWiFiManager` so SpringBoard reports Wi-Fi as powered | MYXXdev™ |

## Authorship and licence

Written by MYXXdev™ (the `control` files name the author and maintainer as MYXXdev). No third-party code, copyright
header or licence file was found in these sources or elsewhere in the archive, and no open-source licence has been
applied to them here. They are not covered by the GPL or MIT texts that apply to SpeedyAds and the redirect module.
Their licence is the author's to decide.

## Provenance of the shipped binaries

`layout/Library/MobileSubstrate/DynamicLibraries/MYbloXX.dylib` and `MYbloXX-WAO.dylib` are byte-identical to the copies
in the archive's b6 package. Each binary contains exactly the hooked class and selector names found in the matching
source. The binaries were not rebuilt from this source for this release, so this is a symbol-level match, not a
reproducible-build proof.

These folders are not part of the Theos build (`SUBPROJECTS` in the top-level Makefile does not list them), so they do
not change the package.
