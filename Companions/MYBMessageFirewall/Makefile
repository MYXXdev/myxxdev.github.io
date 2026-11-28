TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBMessageFirewall
MYBMessageFirewall_FILES = Tweak.m
MYBMessageFirewall_FRAMEWORKS = Foundation
MYBMessageFirewall_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
