TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBPrivacyCover
MYBPrivacyCover_FILES = Tweak.xm
MYBPrivacyCover_FRAMEWORKS = UIKit LocalAuthentication
MYBPrivacyCover_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
