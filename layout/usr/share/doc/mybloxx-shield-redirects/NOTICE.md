MYbloXX Shield - App Store redirect protection

The SpringBoard transition handling is adapted from NoRedirect by i_82 / Lessica,
MIT license, copyright (c) 2024 i_82.
Upstream: https://github.com/owngoal-dev/NoRedirect
Reviewed revision: 410272c25dadd57cfc48ef42ccaa1418a3d33698

MYbloXX supplies its own focused policy, per-app settings and interface. This
module limits App Store / StoreKit application transitions; it does not bundle
NoRedirect's unrelated daemon scheduling, hotspot, background-launch, database,
or banner service features. Embedded StoreKit presentations without a matching
SpringBoard application transition are outside this module's coverage.

The original permission and copyright notice is preserved in LICENSE.
