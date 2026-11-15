include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = FluidX

FluidX_FILES = main.m FXAppDelegate.m FXSettingsController.m FXPrefs.m
FluidX_FRAMEWORKS = UIKit Foundation
FluidX_CFLAGS = -fobjc-arc -Wall
FluidX_INSTALL_PATH = /Applications
FluidX_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
