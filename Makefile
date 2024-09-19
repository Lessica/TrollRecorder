ARCHS := arm64  # arm64e
TARGET := iphone:clang:latest:15.0

INSTALL_TARGET_PROCESSES += audio-player
INSTALL_TARGET_PROCESSES += audio-recorder
INSTALL_TARGET_PROCESSES += audio-mixer

INSTALL_TARGET_PROCESSES += call-recorder
INSTALL_TARGET_PROCESSES += call-monitor

INSTALL_TARGET_PROCESSES += dtmf-decoder

include $(THEOS)/makefiles/common.mk

TOOL_NAME += audio-player
TOOL_NAME += audio-recorder
TOOL_NAME += audio-mixer

TOOL_NAME += call-recorder
TOOL_NAME += call-monitor

TOOL_NAME += dtmf-decoder

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

call-recorder_USE_MODULES := 0
call-recorder_FILES += cli/call-recorder.mm
call-recorder_CFLAGS += -fobjc-arc
call-recorder_CFLAGS += -Iinclude
call-recorder_CCFLAGS += -std=gnu++17
call-recorder_CODESIGN_FLAGS += -Scli/call-recorder.plist
call-recorder_FRAMEWORKS += AudioToolbox AVFAudio
call-recorder_INSTALL_PATH += /usr/local/bin

call-monitor_USE_MODULES := 0
call-monitor_FILES += cli/call-monitor.mm
call-monitor_CFLAGS += -fobjc-arc
call-monitor_CFLAGS += -Iinclude
call-monitor_CCFLAGS += -std=gnu++17
call-monitor_CODESIGN_FLAGS += -Scli/call-monitor.plist
call-monitor_FRAMEWORKS += Foundation CallKit CoreTelephony
call-monitor_INSTALL_PATH += /usr/local/bin

dtmf-decoder_USE_MODULES := 0
dtmf-decoder_FILES += cli/dtmf-decoder.mm
dtmf-decoder_CFLAGS += -fobjc-arc
dtmf-decoder_CFLAGS += -Iinclude
dtmf-decoder_CFLAGS += -Wno-unused-variable
dtmf-decoder_CFLAGS += -Wno-unused-but-set-variable
dtmf-decoder_CODESIGN_FLAGS += -Scli/dtmf-decoder.plist
dtmf-decoder_FRAMEWORKS += AudioToolbox AVFAudio
dtmf-decoder_INSTALL_PATH += /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk