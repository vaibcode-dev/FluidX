# CustomGestures — rootless tweak for iPhone 7 / iOS 15.x
# Жесты iPhone X + настройки внешнего вида

export ARCHS = arm64
export TARGET = iphone:clang:15.6:15.0
export THEOS_PACKAGE_SCHEME = rootless
export INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomGestures
CustomGestures_FILES = Tweak.x
CustomGestures_CFLAGS = -fobjc-arc -Wall
CustomGestures_FRAMEWORKS = UIKit

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
