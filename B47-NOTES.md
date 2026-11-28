# MYbloXX B47

App Control now observes SpringBoard foreground-change events. Home, lock and Settings restore the preceding protection state. No synchronous SpringBoardServices query runs inside SpringBoard. A background helper serializes transitions, coalesces rapid changes, retries failures, and has an eight-second timeout. A cached foreground heartbeat renews the existing 45-second restoration watchdog. Unsupported foreground hook signatures leave bypass inactive.

Preferences are rebuilt normally with Theos on macOS, including custom gradient switches, headers, cards and backgrounds. No load commands are patched into the bundle.

Supervision & Appearance contains separate Spoof Supervision and Hide Supervision Message controls. Hiding uses a Settings-only footer view hook and does not alter supervision. It follows the dedicated PSUIFooterHyperlinkView approach; other Settings content using that class may also be hidden. Reopen Settings after changing it. Actual supervision access now checks native RootHide system groups and includes system-group storage entitlements. Existing supervision not owned by MYbloXX is never removed.

PAC generation and validation require FallBackAllowed=1. Installation migrates the existing MYbloXX localhost PAC target while preserving activation, mode, URL revisions and custom rules. External proxies are left alone.

Validation includes native regression suites and a full arm64/arm64e RootHide build on macOS. Device behavior, Settings rendering and the private foreground hook still require on-device validation. Test one selected app first, then Home, Settings, lock/unlock and two selected apps. Check both previously-enabled and previously-disabled protection, plus a manual protection change while in an app.
