#import <AudioToolbox/AudioToolbox.h>

#define kATAudioTapDescriptionPIDMicrophone 0xFFFFFFFD
#define kATAudioTapDescriptionPIDSpeaker 0xFFFFFFFE

@interface ATAudioTapDescription : NSObject
- (instancetype)initTapInternalWithFormat:(AVAudioFormat *)arg1 PIDs:(id)arg2;  // iOS 16+
- (instancetype)initProcessTapInternalWithFormat:(AVAudioFormat *)arg1 PID:(int)arg2;
@end
