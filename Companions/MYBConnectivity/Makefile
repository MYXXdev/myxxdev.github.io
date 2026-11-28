TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBConnectivity
MYBConnectivity_FILES = Tweak.xm
MYBConnectivity_CFLAGS = -fobjc-arc
MYBConnectivity_FRAMEWORKS = UIKit Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
