TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBPrivateMessages
MYBPrivateMessages_FILES = Tweak.x PMCore.m PMUI.m ../MYBPrivatePhotos/PrivateUI.m
MYBPrivateMessages_FRAMEWORKS = UIKit LocalAuthentication
MYBPrivateMessages_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
