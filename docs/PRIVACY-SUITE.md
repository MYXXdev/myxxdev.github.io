# MYbloXX® privacy suite (RH-15-112526, pass 14)

Everything is off until you turn it on, and nothing here touches CommCenter, carrier bundles, SIM or eSIM, cellular provisioning, call handling,
hotspot controls, or SMS/iMessage delivery. Items marked "awaiting phone" are implemented and compile but have not been run on a device.

| Module | Built | Checked here | Needs your phone |
|---|---|---|---|
| Face ID App Lock | Per-app switches (none chosen), cover from first frame and before switcher snapshot, ticketed unlock, pause switch, passcode only if allowed | Unlock state machine (stale result, cancel, device lock mid-prompt, rapid switching), eligibility list, process scope, package filter | Every launch route (Home, App Library, Spotlight, notification tap, link, widget, switcher), no uncovered frame, Face ID in a third-party app (needs host Info.plist key or the passcode option) |
| Private Previews | Opt-in per-app switcher cover; Photos and Messages covers unchanged | Scope and package checks | Snapshot of a chosen app in the switcher, cold launch, rapid switching |
| Private Items | Private Album, Recently Deleted, Private Conversations (r13 confirmed hiding) + optional Face ID for Album and Recently Deleted | Compile, source tests | Face ID prompt on each private view |
| Notification Privacy | Per-app lists that open the app's own iOS notification page with exact steps | Wiring, exclusions | That the deep link opens the app's page on 16.5.1 |
| Clean Share | Clean Link, Share Without Location, Redact Screenshot with preview and share | Clean Link (19 checks); Redaction and location-strip run on macOS CI | One link, one photo, one screenshot end to end |
| Connection Inspector | Domain sheet (decision, reason, app, scope), explicit empty states, 30-minute opt-in session with export preview | Session and export logic (13 checks) | A blocked domain, a session, the export preview |
| Safari Cleanup | Safari-only CSS hiding, validated rules, pause, per-site exceptions | Rules, exceptions, bad-update fallback (20 checks) | Banners hidden in Safari, scrolling and login/checkout on a cleaned page |
| Local Network Check | Read-only explanation and route to Settings | Wiring | That the Privacy & Security route opens |

Not covered: Siri suggestions, the Spotlight search index, Apple Watch/Mac/iPad alerts, screenshots and screen recording, anything while MYbloXX® or the
jailbreak is not running. A grace period for App Lock is not offered because it cannot be verified from CI.

## MYXX Reserve 0.2.2 (build 22), folded in (pass 15)

Original MYXXdev code in `Companions/MYXXReserve` (no Sentinel or Reverie binaries or assets). Settings is the native MYbloXX screen "MYXX Reserve" (main page, BATTERY).
Changes from the standalone 0.2.2: the percentage display loads in SpringBoard, and while the adjusted percentage is on the helper also lists the installed apps in its filter so the in-app status bar matches (never com.apple.UIKit);
the PreferenceLoader bundle is replaced by the native screen; the package replaces standalone `com.myxxdev.reserve` and conflicts with Sentinel and Reverie.
Reserve is on by default as in 0.2.2 (it starts at 3% when unplugged); Airplane Mode is off by default. Nothing touches CommCenter, carrier, SIM/eSIM or message delivery.
Checked here: compile of all components, filters, package layout, setuid helper and entitlements (package verification), Settings wiring. Awaiting phone: everything in `README-upstream-0.2.2.md` under "needs your phone" (injection, root helper, sleep acceptance, wake and recovery, hook selectors on 16.5.1).
