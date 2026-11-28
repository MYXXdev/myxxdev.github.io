TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TOOL_NAME = mybloxx-pacd
mybloxx-pacd_FILES = main.m
mybloxx-pacd_FRAMEWORKS = Foundation
mybloxx-pacd_CFLAGS = -fobjc-arc -Wall -Wextra
mybloxx-pacd_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/PACServer/entitlements.plist
mybloxx-pacd_INSTALL_PATH = /usr/libexec
include $(THEOS_MAKE_PATH)/tool.mk
