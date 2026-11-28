# B38 regression repair - 2026-11-13

The B37 system-wide symlink and Files AppGroup installation method remain unchanged.

- **Enable error 69:** the B36 fast PAC HTTP probe mistakenly sent literal backslash-r/backslash-n instead of HTTP CRLF. Corrected the request and increased the bounded response window.
- **Custom Rules:** restored a privileged, validated, atomic `localcustom` transaction, which updates applied+draft storage immediately for every edit. Removed the obsolete Apply button. The running local PAC server overlays blocked/allowed domains on the selected base mode without replacing original PAC files.
- **Shield isolation:** system PAC Allow Website and global custom rules do not write into Safari/Shield's independent rules plist. Legacy Shield entries previously synchronized are not automatically deleted.
- **Settings:** Custom Rules now sits directly under Blocking Mode.
- **Blocked page:** new animated luminous glass/shield design, respects reduced-motion, retains server-generated CSP hashes, one-use confirmation tickets, and original URL validation. After helper success, waits 4.2 seconds before reopening to allow for asynchronous configd propagation. This is a conservative delay, not proof CFNetwork has reloaded.
- **Repair:** dedicated action verifies the actual owned symlink/PAC state, synchronizes markers and performs full network refresh. Optional missing daemons no longer make a successful configd restart report failure.
- **Updates:** reads the actual linked system enable state, preserves existing legacy Custom PAC without demanding a prior manual Apply, and logs HTTP/download validation failures.
- **Supervision:** discovers the native iOS configurationprofiles SystemGroup using container metadata when UUID-based. If iOS doesn't expose a safe writable original directory, Supervision remains unavailable by design, with diagnostic path logged.

**Validation:** Native build and regression tests required. A successful CI build does not verify runtime behavior on the user's RootHide iPhone; do not call this system-wide fixed until device-tested. Avoid manually modifying managed preferences or supervision records to force tests to pass.

---

# B32 - RootHide Files-app storage repair (system PAC NOT YET VERIFIED)

Based on the original B5 installer included in `mybloxx.zip`. RootHide mirrors `/var/mobile/Containers` into the original iOS data volume, but does **not** mirror `/var/Managed Preferences`. Previous B27–B31 implementations attempted to write the original iOS Files folder and MYbloXX-owned state via `/rootfs/private/var` and failed with `EROFS`.

B32 separates those independent responsibilities:

- `preparefiles` now discovers `group.com.apple.FileProvider.LocalStorage` from metadata under the **mirrored** `/var/mobile/Containers/Shared/AppGroup`, creates `File Provider Storage/MYbloXX`, copies/stages `MYbloXX.plist` and `README.txt`. It DOES NOT attempt to write the original iOS managed preferences or create a system-wide symlink. This is the Files storage mechanism present in original B5.
- MYbloXX-owned state, logs, status markers, custom preferences return to writable RootHide-managed `jbroot(...)` paths. Settings and browser bridge resolve the same preference storage instead of assuming writable `/rootfs`.
- The stock system-wide managed-preferences symlink activation remains guarded and **is expected to fail until a verified writable original-iOS mechanism exists**. A private/bootstrap symlink is not treated as proof of system-wide blocking. No stock filesystem remounting or other privilege bypass is attempted.
- `control.log` records failures; Files folder creation can succeed independently and should be tested before attempting Enable.
- The hosted PAC, modes, and original enable/disable logic are retained. B32 is **not** a validated system-wide solution and should not be described as one.

Validation: install, inspect Files > On My iPhone > MYbloXX; run `MYXXdev preparefiles` and inspect `FILES_PREPARE` logs. Do **not** assume system-wide PAC activation until an owned symlink exists in the original iOS `/var/Managed Preferences/mobile` path and network requests have been verified across apps.

---

# B28: Files discovery and Safari Guard UI repair

B27 could fail before creating anything because `MYBFilesFolder()` required Apple's `File Provider Storage` folder to already exist. B28 discovers the LocalStorage AppGroup using `MCMMetadataIdentifier`, then creates `File Provider Storage/MYbloXX` if absent and prepares `MYbloXX.plist` and `README.txt` during post-install via a new non-activating `preparefiles` helper action.

The installer **does not** create the original iOS managed-preferences symlink on its own. The user must explicitly select Enable. On failure, `control.log` now includes `FILES_DISCOVERY` and `FILES_PREPARE` diagnostics and the operation refuses to modify the system proxy. The original B5 folder exposure remains unverified on iOS 16 RootHide.

The Safari Guard/Rules screen no longer has a second `viewDidLayoutSubviews` header-frame modifier that competed with `MYBMenuBase` and could cause repeated layout passes and a frozen Settings UI.

On device test:
1. Install package. In Files > On My iPhone look for MYbloXX/MYbloXX.plist and README.txt.
2. If missing, run `/usr/sbin/MYXXdev/MYbloXX/MYXXdev preparefiles; echo $?` in NewTerm and read `tail -40 /rootfs/var/mobile/Library/MYbloXX/control.log`.
3. Enable MYbloXX. Inspect **original iOS** `/rootfs/var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist` with `ls -l`, verify its target is the Files LocalStorage plist, and inspect `ProxyAutoConfigEnable`.
4. Disable, verify the symlink persists but `ProxyAutoConfigEnable` becomes 0.
5. Open MYbloXX Shield/Safari Guard in Settings and verify immediate load and interaction.

**Stock mode remains unverified:** the system-managed symlink persists after Disable; its target is in the original iOS Files provider. Test with a recovery plan before rebooting without the jailbreak.

---

# B27 - Original MYbloXX B5 Files-app storage (experimental)

The user's original `mybloxx.zip` includes MYbloXX v5.092622-13-B5 in `mybloxx/b5/layout/DEBIAN/postinst`. That script locates `group.com.apple.FileProvider.LocalStorage` by reading each AppGroup's `.com.apple.mobile_container_manager.metadata.plist`, creates `File Provider Storage/MYbloXX`, writes `MYbloXX.plist` and `README.txt`, and points the iOS managed-preferences symlink at the Files-app plist.

B27 restores that exact **location strategy**, not the B5 installer code that deleted/replaced foreign files or modified system daemons. The helper resolves the AppGroup dynamically every time; UUIDs are not hardcoded. B27 inherits B26's system-wide hosted HTTPS PAC and PaiBloxx-style `ProxyAutoConfigEnable` flag toggling, which retains the managed symlink on normal Disable.

Migration from B26: The helper recognizes the exact legacy `/var/mobile/Media/MYbloXX/ActiveConfiguration.plist` symlink, copies its target plist into Files if not present, and switches the owned link to the Files target. The old Media file is left untouched as a backup. It refuses to overwrite unrelated managed policies and attempts to restore the old link if migration fails. The system-managed link is only activated on explicit Enable (or when migrating an already owned B26 link).

Normal Files app path: **On My iPhone > MYbloXX > MYbloXX.plist** and `README.txt`. The physical path depends on the LocalStorage AppGroup UUID and is under `/var/mobile/Containers/Shared/AppGroup/<UUID>/File Provider Storage/MYbloXX/`. Only the main PAC configuration and readme live there; helper binaries and private state stay in their existing protected locations. Do not delete or modify the main plist without understanding its impact on system networking.

**Not stock-boot certified:** B5's text claims the Files app sandbox automatically disables this proxy in stock mode, but that has not been verified on iOS 16 RootHide. A stock-visible symlink still exists, and the hosted PAC can remain enabled on stock iOS. Before stock boot, disable protection and verify connectivity and the disable flag. Do not assume that putting a file in Files automatically makes it inaccessible to configd.

---

# B26 - Persistent system PAC toggle (experimental)

B26 retains the system-wide PAC architecture introduced in B25 and adopts PaiBloxx's normal on/off semantics:

- The managed symlink at `/var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist` points to `/var/mobile/Media/MYbloXX/ActiveConfiguration.plist`.
- **Enable:** When the selected PAC URL matches the installed mode, change `Proxies.ProxyAutoConfigEnable` from 0 to 1 in the existing target plist; leave the symlink intact.
- **Disable:** Change `ProxyAutoConfigEnable` to 0; leave the symlink intact.
- **Change blocking mode:** Replace the hosted HTTPS PAC URL in the same real plist and set the enable flag to 1. Preserve the symlink.
- **Uninstall:** Remove only the exact MYbloXX-owned symlink and restore any previously backed-up managed configuration (same as B25).
- Safety: stock iOS can still see the managed symlink even with blocking off. When enabled it can still use the hosted PAC in stock mode. **Do not claim zero stock footprint or guaranteed stock-boot connectivity.**
- Existing local-only custom PAC and proxy override activation remain blocked with code 79; do not silently route stock-iOS traffic through jailbreak-only services.
- The legacy localhost health probe and unused local-custom transaction wrapper are removed; custom rule files, existing rule editor and original PAC sources are preserved.

For on-device validation: first confirm a backup/recovery route, install B26; enable; inspect target `Proxies.ProxyAutoConfigEnable=1`; disable; inspect the same file `ProxyAutoConfigEnable=0` and verify the **same** symlink remains. Change modes and verify the PAC URL changes. Observe real cross-app ad blocking separately-successful filesystem changes are not themselves proof that iOS loaded the PAC.

---

# B25: PaiBloxx-style SYSTEM-WIDE PAC experiment (NOT stock-boot verified)

Based on Paisseon/PaiBloxx (emt branch), specifically the symlink from the original iOS `/var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist` to a **regular stock-accessible file**. B25 points to `/var/mobile/Media/MYbloXX/ActiveConfiguration.plist`. The native helper writes this via `/rootfs/var/mobile/Media/MYbloXX/ActiveConfiguration.plist` in RootHide. This differs from B23 which linked private paths unseen by iOS.

- Standard modes reference the original hosted HTTPS MYbloXX PAC, not `127.0.0.1:8787`. `FallBackAllowed=1` requests direct fallback when PAC retrieval fails; connectivity in stock mode is NOT guaranteed until tested.
- `disable` removes only the exact MYbloXX-owned managed symlink and restores any safely backed-up prior configuration.
- Package removal does the same on a true uninstall, not package upgrades.
- Custom HTTPS PAC URLs remain supported; local generated/custom PAC and HTTP proxy override are disabled in this experiment (exit 79), since they are unsafe/unavailable when stock booted.
- The original iOS managed symlink *persists in stock mode while MYbloXX is enabled*. This is not an ephemeral jailbreak-only activation. The stock-visible HTTPS PAC may continue to block ads outside jailbroken state.
- No stock system managed file or symlink is modified merely by installing B25; the restore daemon requires a one-time explicit B25 Enable action recorded in `B25SystemPACOptIn`. This guard prevents an old B23 enabled-state preference from unexpectedly installing a stock-visible link on upgrade. Back up the original managed preference before testing.
- Do not copy unsafe PaiBloxx `FallBackAllowed=0` or remove unrelated device configurations.

Validation: use Filza to inspect `/var/Managed Preferences/mobile/com.apple.SystemConfiguration.plist` (symbolic link), target `/var/mobile/Media/MYbloXX/ActiveConfiguration.plist`, check active system PAC, inspect stock-boot connectivity with an off-device recovery option available.

---
# B23 latest-branch RootHide-private plist test

This branch begins at `codex/runtime-only-pac-experiment` so that later B22 UI, PAC server, and browser-bridge fixes are preserved.

The former dynamic-store PAC experiment and MYBNetworkProbe are removed. The native helper now creates its MYbloXX managed-preferences link only under RootHide's private `/var/Managed Preferences/mobile` path, with a guard checking for RootHide's separate original filesystem at `/rootfs`. The old shell dispatcher is disabled. The private active config is kept under `/var/mobile/Library/MYbloXX/ActiveConfiguration.plist`.

**Important**: The original root filesystem is not modified by *new activation writes*, but this build does NOT clean up a pre-existing stock managed-preferences link left from prior versions. Also, Apple's network processes may not read RootHide-private managed preferences, so system-wide blocking is **not verified**. Use only for on-device testing, not production release.

# MYbloXX B21 integration preview

Based on working B19.3 RootHide source and original bundled PACs.

Implemented: native protection switch, expanding standard mode selector, custom-rule Apply including empty lists, applied-rule snapshots, config restoration on failed Custom apply, operation serialization, staged opt-in automatic GitHub PAC updates, rollback, canonical Settings artwork and a curved ribbon CC glyph. Obsolete external PAC UI and old companion binaries are removed.

Companions: MYbloXX SpeedyAds provides per-app ad acceleration for App Control. The MYbloXX Shield browser component (called Safari Guard in earlier builds; see Companions/MYBShieldBrowser/README.md) is an original navigation guard, enabled by default on new installs; it is not a full subresource blocker and its coverage in each browser needs on-device testing.

Build the complete package with the RootHide integration workflow. Release artifacts must include the modified SpeedyAds corresponding source archive. Do not describe the preview as device-verified until tested on iOS 16.5.1 RootHide.

Built-in rules: the bundled PACs (rules date in `YYYY/MM/DD - HH:MM UTC`, see `docs/RULES-UPDATES.md`) are generated from `rules/canonical.json`; `tests/pac-sources.json` pins each mode to its source hash and each legacy alias to its mode. On upgrade the helper (`refreshbundled`) makes the bundled set the active generation once, keeping the replaced generation as the rollback target, preserving settings, mode, custom rules, exceptions and Custom PAC, and never downgrading a newer downloaded generation. The updater refuses any upstream file whose `// Updated:` stamp is older than the built-in or active rules (reported in Updates, automatic updates stay on); the matching upstream change must be published to MYbloXX/ for updates to resume. Rules update source: MYXXdev/myxxdev.github.io, master, MYbloXX/*.pac. Downloads are pinned to one commit, matched against Git blob SHA-1 from GitHub metadata, syntax checked, and staged before atomic activation. Applied custom rules are rebuilt against Default. Drafts remain in Settings until Apply. Automatic updates default off and check daily, retrying failures hourly while jailbroken.

B21 adds a shared purple glass Settings system, ribbon-M progress overlay, automatic success dismissal, matching Custom Rules/Safari Guard editors, and a unified searchable SpeedyAds app selector. Rules backup/import/export and notices links are removed from Settings; license/provenance files remain installed with the source companion.

A loopback-only 8021 service returns branded HTML for explicit HTTP document navigations, and an empty 403 for CONNECT, frames, images and unclassified requests. It never forwards traffic or decrypts TLS. Safari Guard can show a native blocked notice for main-frame navigation matching its own rules or the verified, active local MYbloXX PAC. PAC evaluation is cached, time-limited and skipped if the time-limit API is unavailable; HTTPS checks use the origin to avoid claiming a path-specific block. Safari's internal navigation coverage still needs device validation.
