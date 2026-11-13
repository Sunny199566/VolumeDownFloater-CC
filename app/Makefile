ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = VolumeSwitch

VolumeSwitch_FILES = main.m
VolumeSwitch_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "uicache -p /Applications/VolumeSwitch.app"