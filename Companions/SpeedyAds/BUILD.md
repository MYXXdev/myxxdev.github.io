# Building MYbloXX SpeedyAds

SpeedyAds is built as part of the complete MYbloXX package using the root Makefile and RootHide GitHub Actions workflow. The matching Settings interface is `Preferences/MYBAppControlController.m` in the main MYbloXX preference bundle.

Use the same RootHide Theos environment and arm64/arm64e architectures as the parent package. The original SDK hook behavior remains in Tweak.xm; app opt-in and preferences are read at process launch. Existing B20 preference files remain a migration fallback until the unified editor saves the new namespace.

