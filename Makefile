THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Preferences
include $(THEOS)/makefiles/common.mk
SUBPROJECTS = Preferences Helper PACServer BlockedServer CCPreview PrivateBrowser Companions/SpeedyAds Companions/MYBShieldBrowser Companions/MYBShieldRedirects Companions/MYBAppControl Companions/MYBConnectivity Companions/MYBPrivatePhotos Companions/MYBPrivateMessages Companions/MYBPrivateCalls Companions/MYBPrivateCallService Companions/MYBPrivateAudioProbe Companions/MYBMessageProbe Companions/MYBMessageFirewall Companions/MYBPrivateSpotlight Companions/MYBBrowserCleanup Companions/MYBPrivacyCover Companions/InAppAds Companions/MYBSupervisionSign Companions/MYBProfileAlert Companions/MYXXReserve
include $(THEOS_MAKE_PATH)/aggregate.mk

# The Reserve power helper must start as root (iOS refuses the power-management connection to a process running as mobile).
after-stage::
	chmod 4755 "$(THEOS_STAGING_DIR)/usr/libexec/myxxreserved"
