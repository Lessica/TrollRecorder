ARCHS := arm64  # arm64e
TARGET := iphone:clang:latest:15.0

INSTALL_TARGET_PROCESSES += audio-player
INSTALL_TARGET_PROCESSES += audio-recorder
INSTALL_TARGET_PROCESSES += audio-mixer
INSTALL_TARGET_PROCESSES += call-monitor

include $(THEOS)/makefiles/common.mk

TOOL_NAME += audio-player
TOOL_NAME += audio-recorder
TOOL_NAME += audio-mixer
TOOL_NAME += call-monitor

audio-player_USE_MODULES := 0
audio-player_FILES += cli/player.mm
audio-player_CFLAGS += -fobjc-arc
audio-player_CFLAGS += -Iinclude
audio-player_CCFLAGS += -std=gnu++17
audio-player_CODESIGN_FLAGS += -Scli/player.plist
audio-player_FRAMEWORKS += AudioToolbox AVFAudio
audio-player_INSTALL_PATH += /usr/local/bin

audio-recorder_USE_MODULES := 0
audio-recorder_FILES += cli/recorder.mm
audio-recorder_CFLAGS += -fobjc-arc
audio-recorder_CFLAGS += -Iinclude
audio-recorder_CCFLAGS += -std=gnu++17
audio-recorder_CODESIGN_FLAGS += -Scli/recorder.plist
audio-recorder_FRAMEWORKS += AudioToolbox AVFAudio
audio-recorder_INSTALL_PATH += /usr/local/bin

audio-mixer_USE_MODULES := 0
audio-mixer_FILES += cli/mixer.mm
audio-mixer_CFLAGS += -fobjc-arc
audio-mixer_CFLAGS += -Iinclude
audio-mixer_CCFLAGS += -std=gnu++17
audio-mixer_CODESIGN_FLAGS += -Scli/mixer.plist
audio-mixer_FRAMEWORKS += AudioToolbox AVFAudio
audio-mixer_INSTALL_PATH += /usr/local/bin

call-monitor_USE_MODULES := 0
call-monitor_FILES += cli/call-monitor.mm
call-monitor_CFLAGS += -fobjc-arc
call-monitor_CFLAGS += -Iinclude
call-monitor_CCFLAGS += -std=gnu++17
call-monitor_CODESIGN_FLAGS += -Scli/call-monitor.plist
call-monitor_FRAMEWORKS += Foundation CoreTelephony
call-monitor_INSTALL_PATH += /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk