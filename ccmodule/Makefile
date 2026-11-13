ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = VolumeDownModule
VolumeDownModule_FILES = VolumeDownModule.m
VolumeDownModule_FRAMEWORKS = UIKit
VolumeDownModule_INSTALL_PATH = /Library/ControlCenter/Bundles

include $(THEOS_MAKE_PATH)/bundle.mk