TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard splashboardd

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TwitterRebrand
TwitterRebrand_FILES = SpringBoard.x App.x Splash.x TRCommon.m TRSVG.m TRLaunch.m
TwitterRebrand_FRAMEWORKS = UIKit Foundation CoreGraphics
TwitterRebrand_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

# make TR_DEBUG=1 to log what the hooks see/replace to TwitterRebrand.log
ifeq ($(TR_DEBUG),1)
TwitterRebrand_CFLAGS += -DTR_DEBUG=1
endif

include $(THEOS_MAKE_PATH)/tweak.mk

# The artwork (Glyphs/, Icons/, Launch/) is not part of this repository: put it in
# assets/ (git-ignored) or point TR_ASSETS at it. It is copied into the package.
TR_ASSETS ?= $(THEOS_PROJECT_DIR)/assets

internal-stage::
	@[ -d "$(TR_ASSETS)/Glyphs" ] && [ -d "$(TR_ASSETS)/Icons" ] && [ -d "$(TR_ASSETS)/Launch" ] || { \
		echo "TwitterRebrand: artwork not found in '$(TR_ASSETS)' (needs Glyphs/, Icons/, Launch/). Set TR_ASSETS=<dir>."; \
		exit 1; }
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/Application Support/TwitterRebrand"$(ECHO_END)
	$(ECHO_NOTHING)rsync -a --exclude .DS_Store "$(TR_ASSETS)/" "$(THEOS_STAGING_DIR)/Library/Application Support/TwitterRebrand/"$(ECHO_END)
