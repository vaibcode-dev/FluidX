# FluidXKeyboard — маленький отдельный твик.
#
# Он грузится не только в SpringBoard, а в приложения, потому что клавиатура
# рисуется внутри процесса приложения. Сделано отдельным dylib, чтобы хуки
# клавиатуры не тащили в каждое приложение остальные хуки FluidX.

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FluidXKeyboard
FluidXKeyboard_FILES = Tweak.x
FluidXKeyboard_CFLAGS = -fobjc-arc -Wall
FluidXKeyboard_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
