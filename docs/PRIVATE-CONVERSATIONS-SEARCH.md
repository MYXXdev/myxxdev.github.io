# Private Conversations in search (RH-15-112526, pass 13)

Implemented, awaiting live verification.

- **Messages search:** rows for private threads are removed from any list or table data source in Messages, by chat or conversation identity.
- **Spotlight:** a separate, removable component (`MYBPrivateSpotlight`) loads only in SpringBoard and Spotlight. It hides a result on screen when its own
  identifier matches a private conversation by the same salted hash Messages keeps. It never reads or changes the search index, message database,
  delivery services, CommCenter, carrier or SIM settings.
- **Not covered:** Siri suggestions, the search index itself, Apple Watch, Mac and iPad.
- **Diagnostics:** Settings > Extra Privacy Protection > Copy Messages Diagnostics adds `searchShapes`, `searchClasses` and a `spotlight` block (names and
  lengths only). If a private thread still shows in Spotlight, that block says what the results look like so the filter can be made exact.
