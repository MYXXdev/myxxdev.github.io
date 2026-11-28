TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBBrowserCleanup
MYBBrowserCleanup_FILES = Tweak.xm
MYBBrowserCleanup_FRAMEWORKS = UIKit WebKit
MYBBrowserCleanup_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
