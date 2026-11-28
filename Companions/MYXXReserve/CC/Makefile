TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MYXXReserveCC
MYXXReserveCC_FILES = RSVCCModule.m
MYXXReserveCC_CFLAGS = -fobjc-arc -Wall
MYXXReserveCC_FRAMEWORKS = UIKit Foundation
MYXXReserveCC_LDFLAGS = -Wl,-undefined,dynamic_lookup
MYXXReserveCC_INSTALL_PATH = /Library/ControlCenter/Bundles
MYXXReserveCC_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
