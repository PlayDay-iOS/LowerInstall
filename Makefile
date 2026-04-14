export ARCHS           = armv7 armv7s arm64 arm64e
export TARGET          = iphone:12.4:9.0
export PACKAGE_VERSION = 1.0.1

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += tweak
SUBPROJECTS += settings

include $(THEOS_MAKE_PATH)/aggregate.mk
