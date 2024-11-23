#import <AudioToolbox/AudioToolbox.h>

#define kATAudioTapDescriptionPIDMicrophone 0xFFFFFFFD  // -3
#define kATAudioTapDescriptionPIDSpeaker 0xFFFFFFFE     // -2
#define kATAudioTapDescriptionPIDSystemAudio 0xFFFFFFFF // -1

@interface ATAudioTapDescription : NSObject
- (instancetype)initTapInternalWithFormat:(AVAudioFormat *)arg1 PIDs:(id)arg2;  // iOS 16+
- (instancetype)initProcessTapInternalWithFormat:(AVAudioFormat *)arg1 PID:(int)arg2;
@end
