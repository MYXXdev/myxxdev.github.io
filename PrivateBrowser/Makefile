TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = MYBPrivateBrowser
include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MYBPrivateBrowser
MYBPrivateBrowser_FILES = main.m MYBPBAppDelegate.m MYBPBBrowserController.m
MYBPrivateBrowser_FRAMEWORKS = UIKit Foundation WebKit
MYBPrivateBrowser_CFLAGS = -fobjc-arc -Wall -Wextra

include $(THEOS_MAKE_PATH)/application.mk
