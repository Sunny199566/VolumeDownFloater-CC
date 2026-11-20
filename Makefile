ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VolumeDownFloater
VolumeDownFloater_FILES = VolumeDownFloater.xm GestureRecord.m
VolumeDownFloater_FRAMEWORKS = UIKit CoreHaptics CoreGraphics Foundation GraphicsServices
VolumeDownFloater_CFLAGS = -fobjc-arc -Wno-everything

include $(THEOS_MAKE_PATH)/tweak.mk