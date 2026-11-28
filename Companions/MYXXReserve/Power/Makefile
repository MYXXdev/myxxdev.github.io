TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

TOOL_NAME = myxxreserved
myxxreserved_FILES = main.c
myxxreserved_CFLAGS = -Wall
myxxreserved_FRAMEWORKS = CoreFoundation IOKit
myxxreserved_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/Companions/MYXXReserve/Power/entitlements.plist
myxxreserved_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/tool.mk
