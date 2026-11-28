TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBShieldRedirects
MYBShieldRedirects_FILES = Tweak.xm
MYBShieldRedirects_CFLAGS = -fobjc-arc -Wall -Wextra
MYBShieldRedirects_FRAMEWORKS = UIKit Foundation
include $(THEOS_MAKE_PATH)/tweak.mk
