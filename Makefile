ARCHS := arm64  # arm64e
INSTALL_TARGET_PROCESSES := audio-player audio-recorder audio-mixer

include $(THEOS)/makefiles/common.mk

TOOL_NAME := audio-player audio-recorder audio-mixer

audio-player_USE_MODULES := 0
audio-player_FILES += cli/player.mm
audio-player_CFLAGS += -fobjc-arc
audio-player_CFLAGS += -Iinclude
audio-player_CCFLAGS += -std=gnu++17
ifeq ($(TARGET_CODESIGN),ldid)
audio-player_CODESIGN_FLAGS += -Scli/player.plist
else
audio-player_CODESIGN_FLAGS += --entitlements cli/player.plist $(TARGET_CODESIGN_FLAGS)
endif
audio-player_FRAMEWORKS += AudioToolbox AVFAudio
audio-player_INSTALL_PATH += /usr/local/bin

audio-recorder_USE_MODULES := 0
audio-recorder_FILES += cli/recorder.mm
audio-recorder_CFLAGS += -fobjc-arc
audio-recorder_CFLAGS += -Iinclude
audio-recorder_CCFLAGS += -std=gnu++17
ifeq ($(TARGET_CODESIGN),ldid)
audio-recorder_CODESIGN_FLAGS += -Scli/recorder.plist
else
audio-recorder_CODESIGN_FLAGS += --entitlements cli/recorder.plist $(TARGET_CODESIGN_FLAGS)
endif
audio-recorder_FRAMEWORKS += AudioToolbox AVFAudio
audio-recorder_INSTALL_PATH += /usr/local/bin

audio-mixer_USE_MODULES := 0
audio-mixer_FILES += cli/mixer.mm
audio-mixer_CFLAGS += -fobjc-arc
audio-mixer_CFLAGS += -Iinclude
audio-mixer_CCFLAGS += -std=gnu++17
ifeq ($(TARGET_CODESIGN),ldid)
audio-mixer_CODESIGN_FLAGS += -Scli/mixer.plist
else
audio-mixer_CODESIGN_FLAGS += --entitlements cli/mixer.plist $(TARGET_CODESIGN_FLAGS)
endif
audio-mixer_FRAMEWORKS += AudioToolbox AVFAudio
audio-mixer_INSTALL_PATH += /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk

# LIBRARY_NAME := libroothide

# libroothide_USE_MODULES := 0
# libroothide_FILES += roothide/roothide.m
# libroothide_CFLAGS += -fobjc-arc -fobjc-arc-exceptions
# libroothide_CFLAGS += -Iinclude
# libroothide_CCFLAGS += -std=gnu++17
# libroothide_INSTALL_PATH += /usr/local/lib

# include $(THEOS_MAKE_PATH)/library.mk
