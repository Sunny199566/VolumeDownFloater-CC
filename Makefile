ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VolumeDownFloater
# ✅ 追加 GestureRecord.m，原有 xm 文件保留
VolumeDownFloater_FILES = VolumeDownFloater.xm GestureRecord.m
VolumeDownFloater_FRAMEWORKS = UIKit CoreHaptics CoreGraphics Foundation
VolumeDownFloater_CFLAGS = -fobjc-arc -Wno-everything

include $(THEOS_MAKE_PATH)/tweak.mk