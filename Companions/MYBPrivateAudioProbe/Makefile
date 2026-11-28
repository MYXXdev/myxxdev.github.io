TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBPrivateAudioProbe
MYBPrivateAudioProbe_FILES = Tweak.m
MYBPrivateAudioProbe_FRAMEWORKS = Foundation
MYBPrivateAudioProbe_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
