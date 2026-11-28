TARGET = iphone:clang:latest:16.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MYBPrivatePhotos
MYBPrivatePhotos_FILES = Tweak.x PrivateAlbum.m PrivateUI.m
MYBPrivatePhotos_FRAMEWORKS = Photos PhotosUI UIKit AVKit AVFoundation ImageIO LocalAuthentication
MYBPrivatePhotos_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
