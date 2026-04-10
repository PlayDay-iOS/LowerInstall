export ARCHS = armv7 armv7s arm64 arm64e
export TARGET = iphone:10.3:9.0

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += lowerinstallhooks
SUBPROJECTS += lowerinstallsettings

include $(THEOS_MAKE_PATH)/aggregate.mk
