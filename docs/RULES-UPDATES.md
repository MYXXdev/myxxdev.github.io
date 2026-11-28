# Rules dates, the optimized engine and Automatic Updates

## One date format
`rules/canonical.json` (`stamp`) and every generated PAC header use `YYYY/MM/DD - HH:MM UTC`:

```
//
// MYbloXX by MYXXdev (Default)
// Updated: 2026/11/20 - 00:10 UTC
// Support Development: myxxfm.com/donate
//
<one physical line of JavaScript>
```
Internally a date is a UTC `YYYYMMDDHHMM` number (`Shared/MYBPACStamp.h`). Settings > Automatic Updates shows the date of the rules actually in use in this format.

## Reading older PACs
| Found in a PAC | Meaning |
| --- | --- |
| `// Updated: YYYY/MM/DD - HH:MM UTC` | exact |
| `// Updated: MM/DD/YY - HH:MM CET` (also CEST, UTC, GMT, EST, EDT, CST, CDT, MST, MDT, PST, PDT) | converted to UTC before any comparison: `11/20/26 - 01:10 CET` equals `2026/11/20 - 00:10 UTC` |
| `// Updated: MM/DD/YY - HH:MM` (no zone) and `var MYB_STAMP=YYYYMMDDHHMM;` | **ambiguous**: no zone was recorded. Read as CET, the zone of the newest legacy releases, so an old-engine copy of the same rules compares equal to the new set |
| unknown zone name, impossible date (month 13, 30 February, hour 24, minute 60), year outside 2000-2099, no date | not a date: the stamp is 0 |

A downloaded `canonical.json` must use the UTC format exactly; a file still in the old format is reported as "not updated yet" and changes nothing. Dates more than 7 days ahead of the phone's clock are refused.

## Engine and age are separate
* The optimized engine is recognised by the UTC header (`MYBPACEngineCurrent`). An older engine's set is converted even when its rules describe the same instant.
* Rules older than what is installed or built in are never installed. The same date is installed only to move an old-engine set to the new engine.
* Newer downloaded rules from the old engine are never replaced by the older built-in rules. They are regenerated with the new engine from the `canonical.json` stored with each generation (new in this release); an older generation without one stays active unchanged until the next rules check downloads and converts it.
* Each generation folder now holds its `canonical.json`. The replaced generation is the rollback target.

## Check Now and the daily check
Both call `updatePACs`. Steps: read the commit SHA of `MYXXdev/myxxdev.github.io` `master`; list `MYbloXX/` at that SHA; download `canonical.json` at that SHA and verify its git blob hash; check the date; generate all 40 PACs on the device and self-check them; compare engine and age; stage a generation; switch `PACCurrent` atomically; reapply; on any failure put the previous generation back. An unchanged `canonical.json` blob, or an unrelated commit to `master`, is a no-op with no reapply.

The LaunchDaemon `net.myxxdev.mybloxx.updates` runs `updateauto` at load and every 86400 s. The helper checks at most once per 23 hours (`MYBUpdateMinimumInterval`), so launchd timer jitter cannot skip a day. The Automatic Updates switch is stored in `/var/mobile/Library/MYbloXX/Updates.plist` and in setup backups; an upgrade does not touch it.

## RAGGR is the only built-in rule set (6.11252026-17-RH)
All 40 bundled PACs are generated from `rules/canonical.json` (rules date `2026/11/26 - 18:10 UTC`), which carries the engine-2 `compact` section (RAGGR host labels, shapes, families, words). `tests/raggr-pacs.sha256` pins the 40 files to the finished RAGGR bundle; `tests/verify-package.py` checks the packaged files against it.
* A generation counts as RAGGR when the `canonical.json` stored beside it has the compact section (older generations that stored none count only if their Default is the built-in Default). Cached or downloaded r16 rules never win on date: the built-in RAGGR set replaces them on upgrade, and the replaced set stays as the rollback target.
* A downloaded `canonical.json` without the compact section is refused ("the built-in RAGGR rules are kept"), by Check Now and the daily check alike. A feed that has it follows the normal age rules; r16 clients read the same file and ignore `compact`.
* Repair and Restore Defaults never touch the rules generation, so they keep whatever RAGGR generation is active.
