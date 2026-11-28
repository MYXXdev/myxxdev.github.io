TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBPrivateCallService
MYBPrivateCallService_FILES = Tweak.m
MYBPrivateCallService_FRAMEWORKS = Foundation
MYBPrivateCallService_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
