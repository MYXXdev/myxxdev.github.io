# Privacy suite baseline (RH-15-112526, from r13 commit 1afcaf0)

| # | Module | Already in the build | Still to build |
|---|---|---|---|
| 1 | Face ID App Lock | Shared LocalAuthentication prompt exists only inside Private Conversations (`PMUI.m`) | Everything: app list, per-app switches, cover, launch-route handling |
| 2 | Private Previews | Opaque cover on resign-active in Messages and Photos private views | App Lock selections, opt-in masking for other apps, branded cover shared by all |
| 3 | Private Items | Private Album, Recently Deleted privacy, Private Conversations (r12/r13, awaiting phone verification) | Optional Face ID on Photos views using the shared logic; Messages audit once the r13 test is back |
| 4 | Notification Privacy | Nothing (Messages thread muting only, which stays independent) | Per-app Hide Preview / Silence Alerts |
| 5 | Clean Share | Nothing | Clean Link, Share Without Location, Redact Screenshot |
| 6 | Connection Inspector | Activity screen with recorded events | Detail view, attribution, opt-in diagnostic session, export preview |
| 7 | Safari Cleanup | Browser protection and popup rules | Cookie banner, Open in App, clutter rules, per-site exception, undo |
| 8 | Local Network Check | Diagnostics screen | Read-only review tool |
| 9 | Settings structure | Extra Privacy Protection row | Four-card front door; Inspector in Activity, Cleanup in browser protection, Local Network Check in Diagnostics |
