# MYbloXX B50 - design system and PreferenceLoader repair

## Root causes fixed (from the B49 screenshots)
| Symptom | Root cause | Fix |
|---|---|---|
| Arcs / corner outlines / cross-star shapes left of cards | Per-cell `CAShapeLayer` card outlines positioned in a coordinate space that changed with cell reuse and row height | No shape layers. One panel view per cell, rounded with `cornerRadius` + `maskedCorners` (group position set in `willDisplayCell`), reset in `prepareForReuse` |
| Footer text over "Add Allowed Domain" | Plain-style table floats section footers over rows | Grouped table; footer/header views are real `UITableViewHeaderFooterView`s with estimated heights |
| Artifacts near the home indicator | Host `PSListController` scroll view and the embedded table both adjusted for safe area | Host scroll view is locked and inset-free; the embedded table owns the safe area, bottom inset 24 |
| Different navigation treatment main vs child | Global bar tint plus per-screen tweaks | Single `MYBStyleNavigation`, per-`navigationItem` appearance only; parent passes `setContentScrollView:forEdge:` |
| Icon/no-icon rows misaligned | Row text leading differed with and without a tile | Text leading is anchored to one `words` view; separator leading follows it |
| Icons with halos | Transparent rounded corners were pre-baked, then masked again by iOS | Opaque full-bleed icons (`tools/generate-icons.py`); the in-app mark is clipped exactly once |
| Switch state mix-ups on scroll | Switches identified by row `tag` | Identified by `key` |
| Helper could hang UI | Unbounded wait | `waitpid(WNOHANG)` polling on a background queue, 150 s watchdog |

Preference keys, helper commands, backup format and uninstall logic are unchanged.

## Validation status
Run on Linux: Preferences bundle cross-compiled for arm64 against iPhoneOS16.5.sdk with `-Wall -Wextra` (clean); harness sources syntax-checked; `tests/b47-source.py`, `tests/b50-source.py`, `tests/prerm-lifecycle.py`, `tests/acceleration.js`, `tests/pac-regression.js`.

NOT run (needs macOS/Xcode or a device): iOS Simulator screenshots, native Foundation tests, `tests/pac-service.py`, `tests/blocked-response.py`, Apple tooling validation, the arm64e link and DEB packaging (LLVM on Linux cannot emit Apple's arm64e pointer-authentication ABI). Build the DEB with `.github/workflows/build-roothide.yml` on macOS. Nothing here has been run inside real PreferenceLoader; the host-view diagnosis is from reading the code.

## macOS integration repair
The first real UIKit screenshots showed duplicate section headings and footers. UITableView populated default labels from data-source title callbacks on the custom UITableViewHeaderFooterView instances. Section text now uses private MYbloXX accessors instead of those UIKit callbacks. Simulator checks require exactly one visible text label per custom section header/footer.
