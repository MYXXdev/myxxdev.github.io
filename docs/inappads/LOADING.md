# Which processes load MYbloXX's libraries (narrow loading)

## The constraint (verified from the loader's documented behaviour)

* A tweak library has a filter plist beside it (`<name>.plist`, key `Filter` → `Bundles` / `Classes` / `Executables`). The injector reads it when a
  process starts. There is no per-process, run-time "ask the library whether it wants this process" hook: the decision is made from the file.
* A filter that names `com.apple.UIKit` matches **every process that links UIKit**. Returning early from a constructor prevents hooks, not the
  load itself: the image is mapped, its dependencies are loaded and its constructors run. The Substrate developer notes warn about exactly this.
* Nothing in this project invents a dynamic filter. The supported mechanism is a static filter file that names the exact apps.

## What is implemented (implemented, awaiting device verification)

| Library | Before | Now |
|---|---|---|
| `MYBInAppAds.dylib` (shared, one dylib, separate app controls kept) | catalogue apps **plus `com.apple.UIKit`** (so a selected app could load it) | catalogue apps **plus exactly the apps switched on under Ad Network Blocking**; never `com.apple.UIKit` |
| `MYBSpeedyAds.dylib` (App Control acceleration) | `com.apple.UIKit` (every UIKit app; its constructor installed AVPlayer/WKWebView hooks everywhere) | exactly the apps selected in App Control; one non-existent identifier when none is selected |

* The package ships the catalogue-only InAppAds filter and a SpeedyAds filter with the sentinel `net.myxxdev.mybloxx.no-app-selected`.
* The root helper action `adsfilter` rebuilds both filters from the saved selections (Shared/MYBAdsFilter.h). It writes to a temporary file, renames it
  over the old one, reads it back, and returns an error (previous filter untouched) on any failure.
* It runs: when an Ad Network Blocking switch or an App Control switch changes (the Settings screen reports a failure and, for Ad Network Blocking, restores the
  previous choice), after install/upgrade (postinst, because an upgrade ships the default filter), after a settings restore, and after Restore Default Settings.
* The Ad Network Blocking switch is therefore only "on" once the filter was written and read back; otherwise it is put back and the reason shown.
* An app already running when its switch changes has to be closed and reopened (the filter is read at process start). The footer says so.

## Audit of what runs when the dylib is loaded

* `MYBInAppAds.dylib`: one constructor (`MYBAdsDispatch`). It looks up the exact bundle id in the catalogue, runs that one module, then `MYBAdSDKStart()`
  which returns immediately for `com.apple.*`, `net.myxxdev.*` and any app that is not selected, **before reading preferences**. Discovery only starts
  from a module that is running for its own app. Dependencies: Foundation, UIKit (already loaded in an app). No networking, preference writes or hook
  installation happen in a process the filter does not name; with the narrow filter such a process no longer loads it at all.
* `MYBSpeedyAds.dylib`: one `%ctor` that installs its hooks and reads preferences. With the narrow filter this happens only in selected apps.
  Its own run-time gate (`MYBAppControlSelected`) is unchanged.
* System processes and app extensions: the filter names exact bundle ids, so extensions (longer ids) and system processes never match. The loader's own
  exclusions (safe mode, platform daemons) are unchanged.

## What still needs a device

* That Dopamine RootHide re-reads the rewritten filter on the next launch of a selected app (expected from the documented loader behaviour).
* That the dylib is no longer mapped into an unrelated UIKit app (check with a loaded-images listing in an app that is not selected).
* Startup time and memory of a UIKit app before and after (we expect less, because the library is no longer mapped everywhere); no figure is claimed.

## When a changed filter takes effect (what is known and what is not)
- **Written:** the helper writes `MYBInAppAds.plist` from the catalogue plus the selected apps that are actually installed (found in the
  installed apps' Info.plists; if that scan fails the saved selection is used and the log says so). The write goes to a side file, is
  flushed, given owner root and mode 0644, moved over the old file in one step and read back (contents, mode, owner). An interrupted or
  failed write removes the side file and leaves the previous filter; the next run repairs a wrong mode.
- **Read:** the loader reads a filter when a process starts, so a change applies to the NEXT launch of that app. The app must be closed
  fully (swipe it away) and opened again. No respring is required by this design, and none is requested; whether Dopamine/RootHide
  really re-reads the file on every launch (rather than caching it until userspace reboot) is **not verified**. It is exactly what the
  device session must settle.
- **How the device settles it:** Settings > Ad Network Blocking shows an app as **Active** only after the library itself, running inside
  that app, reports to MYbloXX®'s service. Until then the row says "On, not loaded yet. Close and reopen the app". **Diagnostics** (top
  right) copies the filter contents and mode, whether each selected app is in it and installed, and which apps have reported loading.
  Session: switch an app on, force-close and reopen it (expect Active), switch it off and fully restart the app, and note whether the
  row's report stops arriving after a restart of MYbloXX®'s service (the service's memory resets, so the row falls back to "not loaded yet"
  until the app is opened again). An unselected app that still appears in Diagnostics "seen" after being closed and reopened means
  the old filter is still being honoured; if that happens, a userspace reboot is the fallback and the finding goes in the report.
- **After upgrade or re-jailbreak:** the install script runs `adsfilter` before `refreshbundled`; the helper also checks the filter at every start-up
  recovery and on Repair, rewriting it only if it differs (a package reinstall or a re-jailbreak that restores the shipped catalogue-only filter is therefore corrected). Not yet verified on a device.
