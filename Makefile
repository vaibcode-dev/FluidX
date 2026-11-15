# FluidX — rootless tweak for iPhone 7 / iOS 15.x
# Жесты iPhone X + настройки внешнего вида

export ARCHS = arm64
export TARGET = iphone:clang:15.6:15.0
export THEOS_PACKAGE_SCHEME = rootless
export INSTALL_TARGET_PROCESSES = SpringBoard

# ВАЖНО: Theos читает SUBPROJECTS в момент подключения common.mk,
# поэтому объявлять их нужно ДО include, иначе сабпроект игнорируется.
SUBPROJECTS += prefs
SUBPROJECTS += diag

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FluidX
FluidX_FILES = Tweak.x
FluidX_CFLAGS = -fobjc-arc -Wall
FluidX_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

# Без этого include подпроекты (prefs) не собираются вообще:
# именно aggregate.mk создаёт правила internal-all/stage для SUBPROJECTS.
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
