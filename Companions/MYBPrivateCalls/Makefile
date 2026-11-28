TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBPrivateCalls
MYBPrivateCalls_FILES = Tweak.m PCStore.m PCPhone.m PCCall.m ../MYBPrivatePhotos/PrivateUI.m
MYBPrivateCalls_FRAMEWORKS = UIKit LocalAuthentication Contacts ContactsUI
MYBPrivateCalls_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
