TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TOOL_NAME = MYXXdev
MYXXdev_FILES = MYXXdev.m
MYXXdev_FRAMEWORKS = Foundation JavaScriptCore SystemConfiguration CFNetwork
MYXXdev_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-deprecated-declarations
MYXXdev_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/Helper/entitlements.plist
MYXXdev_INSTALL_PATH = /usr/sbin/MYXXdev/MYbloXX
include $(THEOS_MAKE_PATH)/tool.mk
