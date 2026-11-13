ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VolumeDownFloater
VolumeDownFloater_FILES = VolumeDownFloater.xm
VolumeDownFloater_CFLAGS = -fobjc-arc -Wno-everything

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += ccmodule
include $(THEOS_MAKE_PATH)/aggregate.mk