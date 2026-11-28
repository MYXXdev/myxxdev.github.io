# MYbloXX B48

B47 App Control is retained unchanged: the user confirmed it no longer freezes SpringBoard.

The custom switch now owns its UIControl tap handling and on/off state. B47 hid the internal views of a UISwitch, also suppressing its interaction. Programmatic state changes do not send user callbacks; taps and VoiceOver send exactly one value-changed event. Original action handlers and confirmation behavior remain attached.

Uninstall runs native cleanup from prerm before dpkg removes the helper. Removal/deconfiguration stops the five MYbloXX jobs, waits briefly for a busy operation lock, disables App Control and clears its temporary lease, detaches MYbloXX-owned native managed configuration, restores an adopted pre-existing policy without consuming its backup, refreshes configd, removes the live MYbloXX.plist from verified Files storage, removes installed README and old live Media targets, and cleans relocated disabled components. It reverts supervision spoofing only when an MYbloXX ownership record exists. Foreign policies and external supervision are left alone. Failed cleanup stops removal with an error instead of silently abandoning live configuration.

Existing MYbloXX-Settings.plist, MYbloXX.pac, previous-policy/configuration backups, user files, rule/PAC stores and backup directories are preserved. Missing Settings/PAC exports are created before cleanup. Upgrades perform no uninstall cleanup.

Validation includes native filesystem fixtures for ownership, dangling links, prior-policy restoration, App Control pause, repeated cleanup and backup preservation; package lifecycle tests; a UIKit Simulator harness checking hit-testing, tap callbacks, programmatic state, disabled state and VoiceOver; existing regression suites; a complete RootHide arm64/arm64e build and Apple dyld validation. Actual RootHide package removal still needs a device test.
