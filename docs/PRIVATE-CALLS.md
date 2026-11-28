# Private Calls (6.11252026-18-RH)

A small, optional call filter for chosen numbers. Off until the switch in MYbloXX® Settings → Extra Privacy Protection → Private Items → Private Calls is turned on.

## What it does
- **Private Recents.** Calls from private numbers are left out of Phone → Recents (both All and Missed). Tap the Recents title, or the Recents tab, five times to open Private Recents after Face ID or your passcode. The taps only start the prompt. Private Recents closes when Phone leaves the screen or the phone locks, and an opaque cover hides it in the app switcher.
- **Adding numbers.** Settings → Private numbers (type a number, or tap one of a contact's numbers), the + in Private Recents, or swipe a call in Recents and tap **Private** (the swipe action only exists while Private Recents is unlocked this session). New numbers start on Mute.
- **Removing.** Remove a number in Settings or in Private Recents. Its calls show in Recents again. No call record is ever changed or deleted. Turning the feature off does the same.
- **Actions** (one per number): **Mute** silences the incoming call here and lets it ring for the caller; **Decline** hangs up on the call, and what the caller hears next is decided by the carrier (often voicemail).

## Where it runs
`MYBPrivateCalls.dylib` loads only in Phone (`com.apple.mobilephone`) and the incoming-call app (`com.apple.InCallService`), only on iOS 16, and does nothing unless the switch is on. It is separate from the rules, the updater, the PIN, Private Messages, Private Photos and Settings. It does not touch CommCenter, carrier settings, SIM/eSIM, the baseband, call delivery, outgoing calls, emergency calls, FaceTime or other apps' calls.

## Matching
Numbers are compared by exact key: `+` country code and digits when the country is known (international form, `00`/`011`, or national form in a known region), otherwise the very same digits in the very same region. No last-digits or prefix matching, and names are never used. A group call is hidden only when every person in it is private. A caller ID match is a rule match; it does not prove who is calling.

Numbers live on the phone: Settings' records in `net.myxxdev.mybloxx.privacy.plist` (`PrivateCallsLog`) and Phone's records in Phone's own preferences (`MYBPCLog`). The newest record for a number wins, and a removal is a record, so a removal in one place holds in the other. Nothing is logged.

## What the source can and cannot show
Traced for this iOS (headers of the call frameworks from iOS 14.5, plus the class names and notification names in the iOS 16.5 SDK stubs): Phone's history list is `TUCallHistoryController.recentCalls` (and `recentCallsWithPredicate:`, `unreadCallCount`); incoming calls are `TUCall` objects announced by `TUCallCenterCallStatusChangedNotification` and `TUCallCenterCallerIDChangedNotification`; a call can be silenced with `-[TUCall suppressRingtone]` and declined with `-[TUCallCenter disconnectCall:]`. Each hook is installed only if the method exists with the expected signature on the running iOS, otherwise that part stays stock.

- **Send to Voicemail is not offered.** The framework has no separate action for it (only `isSendToVoicemailAllowed`, a capability flag), so on this iPhone declining is the only call-ending action and the carrier decides the rest. Offering both would be one action under two names.
- **Not suppressed in this pass (blockers, not guesses):** the incoming banner or full-screen call screen, the missed-call notification and the Phone icon badge for a muted call. Their code path was not traced for 16.5 and they stay normal. Declined calls do not ring but may still be recorded as missed by Phone's own history; those entries are hidden in Recents but the missed-call notification path is unverified.
- Phone's own row/menu classes were not inspectable from here. Make Private in the press-and-hold menu is added only when the row's call can be read with certainty; Settings → Copy Calls Diagnostics lists which classes were hooked.

## Phone checklist (what only a phone can show)
1. Switch on; add a number you can call from; tap Recents five times → Face ID → Private Recents opens. Cancel the prompt → nothing opens.
2. Make a call from that number: it appears under All and Missed in Private Recents and not in Phone → Recents. A different number with the same contact name stays in Recents.
3. Lock the phone and unlock; leave Phone and return: Private Recents is closed. Check the app switcher shows the cover, not the list.
4. Remove the number: its calls are back in Recents, with their original dates.
5. Mute (default), phone unlocked, then locked: no ringtone, no vibration; the call keeps ringing for the caller; note whether the banner / lock-screen call screen, the missed-call notification and the badge still appear.
6. Decline: the call is ended once; ask the caller what they heard (voicemail or busy). Answer an unmatched call during the test: it must be untouched.
7. While on a call with someone else, have a private number call: Mute leaves it alone (call waiting), Decline ends only the waiting call.
8. Feature off: ordinary calls from a listed number ring and are listed normally.
9. Settings → Copy Calls Diagnostics after the test and paste it in. It holds only class names and counts.

## r19: one store

- **The store** is `PrivateCallsLog` in `net.myxxdev.mybloxx.privacy.plist`. Settings, Phone and the incoming-call component all read that one file. There is no second list.
- **Writes** go through one function (`MYBPCStoreMutate`: lock, read, merge, atomic write, read back, verify). Settings and the root helper call it directly. Phone calls it directly when its sandbox allows; if not, Phone leaves the request in its own preferences, posts `net.myxxdev.mybloxx.privatecalls.request`, and the root helper (appcontrol daemon, or `MYXXdev pcapply` when Settings opens Private numbers) applies it through the same function. Phone shows success only after reading the record back from the store, and withdraws the request if that does not happen in 5 s, so a number never looks private unless the rule is saved.
- **Merge rule:** newest record per number wins; removals are kept as records so an old add cannot return. Same time and different actions → **Mute** (the less disruptive one). Same time, add vs removal → removal.
- **Migration from r18:** the r18 Settings list already lives in the store. The r18 Phone list (`MYBPCLog`) is merged in by the helper, the store is marked migrated (`PrivateCallsStoreVersion` 2) only after the read-back verifies, and Phone then removes its old list. Safe to retry; an interrupted attempt leaves both lists as they were.
- **Restore Defaults:** removes the privacy file (switch off, no rules) and writes `PrivateCallsReset.plist` (a time only). Phone requests and old Phone records older than that time are dropped, so nothing comes back. Call records are never touched, so affected calls show in Recents again; Files backups are kept.
- **Diagnostics** (Copy Calls Diagnostics): store read, migrated, last save route (direct / helper / failed), counts and class names. No numbers, names or history.
- **Mute on this build:** silences the ringtone only. The incoming-call screen, missed-call notice and badge were not traced and can still appear. **Send to Voicemail** is not offered: TelephonyUtilities has no distinct action for it.

## r26: swipe, no country code, names, number format

- **Make Private is a swipe action** on Recents rows, shown only after Private Recents has been unlocked (five taps + authentication) and until Phone is left or the phone locks. All press-and-hold code was removed.
- **A country code is not required.** A number typed the way a caller shows up (612 34 56 78) and the same number with +34 are one number, for adding and for matching.
- **Format.** Numbers are shown the way Phone shows them: a number of the phone's own country has no country code (Spain: 612 34 56 78), a foreign number starts with +code. Old r18-r25 entries are re-shown in this format.
- **Names.** The contact's name is shown when it is known: from the contact you picked, from the call you swiped, or looked up live in Phone's contacts (only where the process may already read contacts; nothing is requested or stored beyond the label on the rule).
- **Logo.** The shield is drawn alone on a transparent background in the sheets, the empty Private Album and the Private Messages/Calls cover, which now blurs the screen behind it.
