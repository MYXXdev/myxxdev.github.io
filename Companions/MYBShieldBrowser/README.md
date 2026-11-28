# MYbloXX Shield: browser component

Written for MYbloXX® by MYXXdev™.

It runs inside the browsers listed in `Shared/MYBBrowserPolicy.h` (the injection filter in `MYBShieldBrowser.plist` is
checked against that list by `tests/browser-policy.py`). It applies the Shield rules the user keeps in Settings:
blocked and allowed domains, URL prefixes, popup handling (Strict or Standard) and the blocked-navigation notice.
A new install enables Shield by default; every switch is stored in `net.myxxdev.mybloxx.safariguard.plist`.

It is a navigation guard, not a subresource content blocker. Network ad domains are still handled by the MYbloXX PAC.
It relies on public WebKit navigation hooks, so coverage inside a given browser is confirmed only by testing on a device.

## Compatibility identifiers

The component used to be called Safari Guard. These identifiers keep that name on purpose, because existing settings and
backups use them: the preferences file `net.myxxdev.mybloxx.safariguard.plist`, the Darwin notification
`net.myxxdev.mybloxx.safariguard.changed`, and the package id `net.myxxdev.mybloxx.safariguard`.
