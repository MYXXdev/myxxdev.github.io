TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MYXXReserveDisplay
MYXXReserveDisplay_FILES = Display.m
MYXXReserveDisplay_CFLAGS = -fobjc-arc -Wall -Wno-unused-function
MYXXReserveDisplay_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
