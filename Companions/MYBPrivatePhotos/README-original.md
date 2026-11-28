# MYXX Private Photos 0.2.31

An experimental iOS 16 Photos tweak for RootHide and rootless. It upgrades
MYXX Empty Recently Deleted using the same package ID.

## Open or hide the album

Tap **Albums** five times quickly to open Private Album. It closes when
Photos goes into the background.

On **Albums**, hold the **Recently Deleted** row under **Utilities** for three seconds.
The confirmation disappears automatically. Open Recently Deleted to see the change in the same Photos session.

## Move photos and videos

1. In Private Album, tap **+**, select photos or videos in the in-app library grid, and tap **Move**. Wait for the private
   copies to finish. The picker may download an original from iCloud.
2. After checking the private copies, the tweak requests permanent removal
   of eligible originals. If Photos rejects the request, the private copy stays saved.

Live Photos preserve their still and paired motion files. Playback uses the native Live Photo view when Photos recognizes the pair, with the
paired video as a fallback. Share sends the still and movie as separate files. Edited
assets and items with additional resources keep their Photos originals.
If you use iCloud Photos, removing the Photos original syncs across the
devices that use that library. The private copy stays in a local private folder under Application Support or Photos’
PhotoData directory. It has no expiry or private-album iCloud sync. Back up important
items using Share before erasing the device.

## Browse, share, restore, and delete

Tap an item to preview it. Swipe left or right to browse, swipe down at normal zoom to return to the grid, pinch or double-tap to zoom,
and tap the picture to hide or show the bars. The bottom toolbar has Share
Info, and Trash. Tap Select in the album grid to share or delete multiple items.
More includes Restore to Library. Trash asks before permanently removing
private copies.

## Build and device verification

The GitHub Actions workflow builds both variants with macOS and Xcode.
For a local build, use Xcode, RootHide's Theos fork, GNU Make, ldid and dpkg.
Set THEOS to that installation, then run the appropriate command.

```sh
gmake clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
gmake clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

The Linux-built beta packages use Theos's toolchain and allemande's arm64e
ABI conversion. An Xcode build is the native arm64e alternative if the beta
does not load on your device.

First test on iOS 16.5.1 with a disposable screenshot and short video. Check
the toggle, previews, video playback, sharing, import and restore before
permanently deleting any originals. After purging the disposable originals,
reboot to stock and check that the album entry and the items are absent from
Photos. Re-enable the jailbreak and verify the private items are available.
The Photos Recently Deleted screen hook and on-device Photos permissions
require device testing.
