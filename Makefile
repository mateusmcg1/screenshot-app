include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ScreenshotMonitor
ScreenshotMonitor_FILES = ScreenshotMonitor.x
ScreenshotMonitor_CFLAGS = -fobjc-arc
ScreenshotMonitor_TARGET = iphone:clang:16.7:14.0

# Prevent version auto-increment
THEOS_PACKAGE_BASE_VERSION = 0.0.1
THEOS_PACKAGE_BUILD_VERSION = 1

ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS_MAKE_PATH)/tweak.mk