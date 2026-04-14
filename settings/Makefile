include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LowerInstallSettings
$(BUNDLE_NAME)_FILES               = LowerInstallSettings.mm
$(BUNDLE_NAME)_INSTALL_PATH        = /Library/PreferenceBundles
$(BUNDLE_NAME)_FRAMEWORKS          = UIKit QuartzCore CoreGraphics
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS  = Preferences
$(BUNDLE_NAME)_CFLAGS              = -fobjc-arc
$(BUNDLE_NAME)_LDFLAGS             = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
