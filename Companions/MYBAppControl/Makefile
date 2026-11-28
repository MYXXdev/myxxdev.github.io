TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBAppControl
MYBAppControl_FILES = Tweak.xm
MYBAppControl_CFLAGS = -fobjc-arc
MYBAppControl_FRAMEWORKS = UIKit Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
