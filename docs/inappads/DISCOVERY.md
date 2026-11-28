# Discovery: finding where an app's ads live

Some ad placements cannot be removed without knowing the exact class and method the app uses, and that cannot be known from here:
the App Store's sponsored search results and Today cards, and the Facebook News Feed's real insertion path. Discovery is an opt-in
collector that writes bounded names to the system log so one short device log is enough to write a precise hook.

## What it collects (and nothing else)
- Class names that look advertising-related (sponsor, advert, promoted, placement, impression, ad as a whole word such as AdSlot or isAd).
- Method names on those classes with their type signatures, for example `-insertItems:atIndexPaths: v@:@@`.
- View class names with counts, and the class chain (superclass names) of ad-like views.
- Facebook only: the class behind the feed list and its item-related methods, and counts of model class names with whether each carried
  its classification when created.
- The app version and iOS version.

It never reads a string from the app's content: no account names, search text, app or post text, prices, images, messages, URLs,
headers, tokens or cookies. Every list is capped (60 entries, one log line under 7000 characters), so a collection stays short.

## Run a session from the iPhone (no Mac needed)
1. Settings > MYbloXX > In-App Ad Blocking > Status > **DISCOVERY (ADVANCED)** > **Start a 10-minute session**. The session ends by
   itself after 10 minutes; **Stop now** ends it early.
2. Within those 10 minutes, open the app and use it. An app that is already open starts collecting by itself (MYbloXX® tells it with a
   notification). If its row still says "Waiting for the app" after a minute, it was opened before MYbloXX® was installed or updated:
   close it fully and open it again.

| App | Do this after opening it | It reports at |
|---|---|---|
| App Store | Open the **Search** tab, tap the search field and scroll once (do not sign in or buy anything) | right away ("started"), 30 s and 100 s |
| Facebook | Scroll the News Feed for about 20 seconds, then open Marketplace and scroll once | right away, 25 s and 80 s |
| Amazon | Search for anything and scroll the results (no ad switch needed) | right away, then every 20 s for two minutes |

   None of the three needs its ad switch: with a switch off nothing is hooked or blocked and only interface names or marker counts are
   gathered (Facebook's model counts do need its hooks, so they stay empty). Amazon's collector reads the app's web views directly.
3. Come back to Status. Each app shows how many collections arrived ("Waiting for the app" until the first). **Started** means the collector ran and its message reached MYbloXX®; it does not prove the screen you meant was open. Only a collection with details does.. **Copy collected details**
   puts them on the clipboard; **Share or save to Files** opens the share sheet (Save to Files, AirDrop, Messages). Send me that text.
4. **Clear collected details** deletes them and ends a running session. They are also dropped when MYbloXX's service restarts.

How it travels: each app sends its lines, in pieces of at most 700 characters, to MYbloXX's own local service (127.0.0.1) with the same
bridge header the Shield and ad reports use. The service keeps them in memory only (at most 24 lines, about 90 KB, never written to disk),
accepts a piece only while a session is open and only if it carries that session's id (each Start makes a new one; Stop and Clear forget it, so a delayed report cannot repopulate), only from the module's own app, only as one `MYBAdsDiscovery <module> {json}` line,
and refuses anything containing a web address or non-ASCII text. If an app cannot reach the service (the App Store is sandboxed; this is
unverified), nothing arrives; the same line is still written to the system log, so the Mac route below remains as a fallback.

"The collector loaded in the App Store" is shown by the "started" line that arrives the moment the App Store opens during a session.
The shared library's filter names `com.apple.AppStore`, the catalogue maps it to the `appstore` module, and a dispatch test proves
the module starts; whether iOS lets the App Store process load it and reach the service is only known from a session on the device.

## Fallback: the system log (needs a Mac)
With the iPhone connected to a Mac (Terminal):

    log stream --device --predicate 'eventMessage CONTAINS "MYBAdsDiscovery"'

or open Console, choose the iPhone and search for `MYBAdsDiscovery`.

## Disable
Nothing runs outside a session. A session that is left alone ends after 10 minutes; a time stored more than one session ahead is ignored.

## What happens with the result
- App Store: the ad-like classes, the sponsored lockup's methods and the view hierarchy identify the placement; a hook that hides only
  that placement is then added to the App Store module, and its switch added to the everyday list.
- Facebook: the data-source class and its insertion or update selector (with full signature) are what the late-classification filter
  must be attached to. Until then that filter is tested but not connected, so Facebook is covered at model creation only.

Session identity: Start writes the end time and an 8-hex session id to the ad preferences. A collector remembers the id it started under and re-reads the preferences before every sample and every piece it sends; if the session ended or another began, it sends nothing. Implemented, awaiting device verification.
