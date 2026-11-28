TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MYXXReserve
MYXXReserve_FILES = Tweak.m
MYXXReserve_CFLAGS = -fobjc-arc -Wall -Wno-unused-function
MYXXReserve_FRAMEWORKS = UIKit Foundation CoreFoundation IOKit
MYXXReserve_LIBRARIES = roothide

include $(THEOS_MAKE_PATH)/tweak.mk
