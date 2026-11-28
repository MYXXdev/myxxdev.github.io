# MYXX Reserve 0.2.2 (build 22) — RootHide

Low-battery reserve for iOS 16.5.1 / Dopamine RootHide. When the true battery
level reaches your threshold and the phone is unplugged, the screen goes black,
wake sources are blocked and the system is put to sleep, so the jailbreak
survives. Plugging in power or pressing **Volume Up 3×** wakes it. Optional
adjusted battery percentage everywhere the phone's battery is shown.

Original code (`com.myxxdev.reserve`). No Sentinel or Reverie binaries or assets
are included; both were only disassembled to learn the behaviour.

## Components and where they run

| Piece | Installed at (jbroot-relative) | Process | Filter |
|---|---|---|---|
| Core | `/Library/MobileSubstrate/DynamicLibraries/MYXXReserve.dylib` | SpringBoard | `Bundles: com.apple.springboard` |
| Battery % display | `…/MYXXReserveDisplay.dylib` | SpringBoard (Home, Lock Screen, Control Center) and apps (in-app status bar) | `Bundles: com.apple.UIKit`; exits at once in non-.app processes |
| CPU slowdown (optional, off) | `…/MYXXReserveThermal.dylib` | thermalmonitord | `Executables: thermalmonitord` |
| Power helper | `/usr/libexec/myxxreserved` | own process, spawned by SpringBoard | entitlements: `platform-application`, `container-required=false` |
| Settings | `/Library/PreferenceBundles/MYXXReservePrefs.bundle` | Settings | PreferenceLoader |
| Control Center toggle | `/Library/ControlCenter/Bundles/MYXXReserveCC.bundle` | SpringBoard | CCSupport |

## What the baselines actually do (verified in disassembly)

**Sentinel 1.3.2** (`xyz.cypwn.sentinel`, sha256 `dbf4bea5…228f`)
* Trigger: `(double)((float)batteryLevel*100) <= threshold` (string `"3.0"`, read as int), plus a 300 s latch.
* Entry: black view on `UIRootSceneWindow`, no charging chime, lift/tap-to-wake off, Face ID auto-unlock off, DND assertion, Low Power Mode on, Airplane Mode on (prior states saved). After 1 s: `_simulateLockButtonPress`, then NSTask `SentinelRunner`.
* SentinelRunner: `setuid(0)×2, setgid(0)×2` → `IORegistryEntryFromPath("IOPower:/IOPowerConnection/IOPMrootDomain")` → set `"System Boot Complete" = true` → `IOPMFindPowerManagement` → `IOPMSleepSystem`. Signed with `platform-application`, `container-required=false`. Packaged 0755 (no setuid bit).
* Recovery: `isOnAC`, or 3 presses of UIPress type 102 (Volume Up) with force 1.0 (cumulative), then `killall backboardd`. Saved states are restored in `applicationDidFinishLaunching:`.
* Percentage: `trunc(level*100 − threshold + 1)`, applied **only** to `_UIStatusBarStringView` text containing `%`. That's why the number inside the iOS 16 battery icon never changed. The float truncation is also off by one at 53% and 59%.

**Reverie 2.4.1** (`ai.paisseon.reverie`, rootful)
* Adds wake-source blocking (tap, raise, side button single/long press, Home button, backlight), and Volume Up ×3 within a 2 s window.
* Calls `IOPMSleepSystem` from inside SpringBoard. MYXX Reserve 0.1.x did the same.
* Its "throttle CPU" calls thermalmonitord's `CommonProduct` from SpringBoard, where the captured pointer is always nil, so it never takes effect.
* On wake it forces Airplane Mode and Low Power Mode off, whatever they were before.

**Why 0.1.x did nothing (most likely):** a Linux clang build emits **old-ABI arm64e**. The Mach-O capability byte is `0x00` instead of `0x80`, and dyld on iOS 14+ refuses to load that into arm64e SpringBoard. It fails silently: no crash log, no status file. `tools/verify_deb.py` now rejects it.

## Hybrid behaviour

* **Activation** uses the true level from `UIDevice`: `round(level*100) <= threshold`, unplugged. Sources are SBUIController `updateBatteryState:`/`ACPowerChanged` plus the UIDevice battery notifications.
* **Sleep** follows Sentinel's exact helper sequence and process context. A wake that nobody acts on is re-slept after 60 s.
* **Screen stays dark** (Reverie): tap, raise and side-button wakes are blocked during reserve.
* **Recovery:** charger, or Volume Up ×3 within 4 s. Settings are restored in place first, then backboardd is restarted as Sentinel does. Enter, recover and restore are idempotent.
* **Journal:** before Low Power Mode, Airplane Mode, Do Not Disturb or CPU slowdown is changed, the change is written to `com.myxxdev.reserve.journal`. Only journaled items are reverted, including after a respring or crash. DND uses MYXX Reserve's own client ID, so your own Focus is never cleared. Airplane Mode is **off by default**. Carrier bundles, eSIM and CommCenter are not touched.
* **No instant retrigger:** after a manual wake at low battery, auto-entry waits N minutes (default 10; 0 = until charged). Charging or rising above the threshold re-arms it.
* **Percentage:** one function, `RSVDisplayedPercent(truePct, threshold)` = `truePct − threshold + 1` (clamped 0–100), feeds the icon (`_UIBatteryView.chargePercent`) and the text (`percentView`). The input is always the true capacity carried in the status-bar update, so the offset can't be applied twice. With the option off, the views are never touched. `showsPercentage` is never changed, so the iOS Battery Percentage switch still decides. Only `_UIStatusBarBatteryItem` is hooked, so widgets and AirPods/accessory batteries are unaffected.

## Build

The arm64e slices **must** come from Apple's clang (Xcode 12+). Upstream and older Linux clang emit the old ABI.

**CI (recommended):** push this folder to a GitHub repo and the workflow `.github/workflows/build.yml` runs on `macos-14` with Xcode 15.4. It uses RootHide Theos pinned to `958fea4f…` and the iOS 16.5 SDK, builds, then runs `tools/verify_deb.py` as a hard gate. The artifact contains the `.deb`, `verify.txt`, `sha256.txt` and `loadcommands.txt`.

**Local Mac:**
```sh
export THEOS=~/theos-roothide   # git clone --recursive https://github.com/roothide/theos
# put iPhoneOS16.5.sdk in $THEOS/sdks
make package FINALPACKAGE=1
python3 -I tools/verify_deb.py packages/*.deb --ldid "$(command -v ldid)"
```

## Phone acceptance test (no Mac, no terminal)

1. Remove Sentinel/Reverie (the package declares `Conflicts`). Install the `.deb` in Sileo and respring.
2. Settings → MYXX Reserve. The status block must say **Installed: 0.2.2 (build 22)** and **SpringBoard: ✓ LOADED this version — <time>**, and show **Battery % hook: active in SpringBoard**.
   * *NO STARTUP SIGNAL* → the dylib isn't being injected. *Older build* → respring.
3. Tap **Check connection to SpringBoard**. The status should change to *TEST REQUEST RECEIVED* with a fresh time.
4. Tap **Run quick test**. The screen goes black and locks. After 10 s the status must read **QUICK TEST PASSED** and *Power helper: ✓ power system reachable (ran as root/mobile)*. Run it again and press Volume Up 3× during the test: the status shows *(ended with Volume Up ×3)*.
5. Turn on **Show adjusted percentage** with a reserve level of 3. Compare the number inside the battery icon on the Home Screen, Lock Screen, Control Center and inside an app: all should read the real value − 2. Turn it off: all return to stock.
6. Unplug and tap **Run full reserve test**. Wait about 30 s, then press Volume Up 3×. The phone resprings, and the status shows **RECOVERED** with Low Power Mode etc. back as before. Repeat and wake it by plugging in. Repeat and leave it alone: it wakes by itself after 2 minutes (test only).
7. Overnight check (real drain): leave the phone in the full test or in real reserve and compare the battery drop with Sentinel.

## Verified vs needs your phone

Verified here: compiles and links against the iOS 16.5 SDK with `-Wall -Werror` (local arm64 build), package layout, filters, helper path and entitlements (ldid), percentage math (all thresholds 1–20 × 0–100%), and the verifier's ABI gate against Sentinel (passes) and a Linux-clang arm64e build (fails).

**Needs the CI build and your phone. None of this is proven:**
* the arm64e build itself
* SpringBoard injection
* helper privilege context
* `IOPMSleepSystem` acceptance on 16.5.1
* real deep sleep and standby drain
* Volume Up and charger recovery
* that the iOS 16 hook selectors exist (tap/raise/side-button blocks, `_UIStatusBarBatteryItem -applyUpdate:toDisplayItem:`, thermalmonitord `CommonProduct`)

Missing selectors are listed in Settings under "Not available on this iOS".
