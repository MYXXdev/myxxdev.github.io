TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBMessageProbe
MYBMessageProbe_FILES = Tweak.m
MYBMessageProbe_FRAMEWORKS = Foundation
MYBMessageProbe_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
