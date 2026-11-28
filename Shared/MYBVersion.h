// The single source of the release identity shown on every surface. tests/verify-package.py checks that the package
// version equals the Debian version in `control`, and that the visible label is the one used by the installer and Depiction.
//   MYB_DISPLAY_NAME      product name shown to people
//   MYB_RELEASE_LABEL     the visible release: RH = RootHide build, 15 = iOS 15/16 line, 112526 = 25 Nov 2026, the visible release has no suffix; the Debian version below only has to sort above earlier builds
//   MYB_COMPONENT_VERSION the Debian package version. It starts with 6.11252026, which sorts above every earlier
//                         6.060924-* package (RC5.4 and RC5.5), so dpkg treats this release as an upgrade.
#define MYB_DISPLAY_NAME "MYbloXX® (RootHide)"
#define MYB_RELEASE_LABEL "RH-15-112526"
#define MYB_COMPONENT_VERSION "6.11252026-62-RH"
