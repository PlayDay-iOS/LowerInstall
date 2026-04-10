include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LowerInstall

$(TWEAK_NAME)_FILES = LowerInstall.xm
$(TWEAK_NAME)_FRAMEWORKS = Foundation UIKit
$(TWEAK_NAME)_LIBRARIES += substrate
$(TWEAK_NAME)_LDFLAGS = -Wl,-segalign,4000 -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
