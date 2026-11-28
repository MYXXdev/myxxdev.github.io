TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBShieldBrowser
MYBShieldBrowser_FILES = Tweak.xm
MYBShieldBrowser_CFLAGS = -fobjc-arc -Wall -Wextra
MYBShieldBrowser_FRAMEWORKS = Foundation WebKit UIKit QuartzCore JavaScriptCore
include $(THEOS_MAKE_PATH)/tweak.mk
