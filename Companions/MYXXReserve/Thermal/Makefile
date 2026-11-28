TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MYXXReserveThermal
MYXXReserveThermal_FILES = Thermal.m
MYXXReserveThermal_CFLAGS = -fobjc-arc -Wall -Wno-unused-function
MYXXReserveThermal_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
