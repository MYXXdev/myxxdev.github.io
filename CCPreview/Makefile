THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = MYbloXXCC2
MYbloXXCC2_FILES = MYbloXXCC2.m
MYbloXXCC2_FRAMEWORKS = Foundation UIKit
MYbloXXCC2_LDFLAGS = -Wl,-undefined,dynamic_lookup
MYbloXXCC2_INSTALL_PATH = /Library/ControlCenter/Bundles
MYbloXXCC2_CFLAGS = -fobjc-arc -Wall -Wextra
include $(THEOS_MAKE_PATH)/bundle.mk
