TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TOOL_NAME = mybloxx-blockd
mybloxx-blockd_FILES = main.m
mybloxx-blockd_FRAMEWORKS = Foundation Security JavaScriptCore
mybloxx-blockd_CFLAGS = -fobjc-arc -Wall -Wextra
mybloxx-blockd_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/PACServer/entitlements.plist
mybloxx-blockd_INSTALL_PATH = /usr/libexec
include $(THEOS_MAKE_PATH)/tool.mk
