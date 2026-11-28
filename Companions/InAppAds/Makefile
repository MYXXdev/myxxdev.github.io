TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBInAppAds
MYBInAppAds_FILES = Dispatcher.m YouTube/Module.m Instagram/Module.m TikTok/Module.m SoundCloud/Module.m Reddit/Module.m YouTubeMusic/Module.m X/Module.m Messenger/Module.m Facebook/Module.m Amazon/Module.m Threads/Module.m Gmail/Module.m Douban/Module.m QQMusic/Module.m Sogou/Module.m WeChat/Module.m Bilibili/Module.m AppStore/Module.m SDK/Module.m
MYBInAppAds_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter
MYBInAppAds_FRAMEWORKS = Foundation UIKit
include $(THEOS_MAKE_PATH)/tweak.mk
