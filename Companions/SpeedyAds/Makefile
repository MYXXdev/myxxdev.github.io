TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBSpeedyAds
MYBSpeedyAds_FILES = Tweak.xm
MYBSpeedyAds_CFLAGS = -fobjc-arc
MYBSpeedyAds_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG
MYBSpeedyAds_FRAMEWORKS = UIKit QuartzCore CoreGraphics AVFoundation WebKit
include $(THEOS_MAKE_PATH)/tweak.mk

