TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBPrivateSpotlight
MYBPrivateSpotlight_FILES = Tweak.m
MYBPrivateSpotlight_FRAMEWORKS = UIKit
MYBPrivateSpotlight_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
