#import <AVFAudio/AVFAudio.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "ATAudioTap.h"
#import "ATAudioTapDescription.h"
#import "AudioQueue+Private.h"

static const int kNumberOfBuffers = 3;
static const int kMaximumBufferSize = 0x50000;
static const int kMinimumBufferSize = 0x4000;

static AudioStreamBasicDescription mDataFormat = {0};
static AudioQueueRef mQueueRef = NULL;
static AudioQueueBufferRef mBuffers[kNumberOfBuffers] = {0};
static AudioFileID mAudioFile = 0;
static UInt32 mBufferByteSize = 0;
static SInt64 mCurrentPacket = 0;
static bool mIsRecording = false;
static bool mIsPaused = false;
static int mATAudioTapDescriptionPID = 0;
static AudioTimeStamp mRecordedTime = {0};

__used static void _RecorderCallback(void *ptr, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer,
                                     const AudioTimeStamp *timestamp, UInt32 inNumPackets,
                                     const AudioStreamPacketDescription *inPacketDesc) {

    OSStatus status = noErr;

    if (inNumPackets == 0 && mDataFormat.mBytesPerPacket != 0) {
        inNumPackets = inBuffer->mAudioDataByteSize / mDataFormat.mBytesPerPacket;
    }

    status = AudioFileWritePackets(mAudioFile, false, inBuffer->mAudioDataByteSize, inPacketDesc, mCurrentPacket,
                                   &inNumPackets, inBuffer->mAudioData);

    if (status == noErr) {
        mCurrentPacket += inNumPackets;
    } else {
        // NSLog(@"AudioFileWritePackets (%d)", status);
    }

    if (mIsRecording) {
        status = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);

        // if (status != noErr) {
        //     NSLog(@"AudioQueueEnqueueBuffer (%d)", status);
        // }
    }
}

__used static void _RecorderListenerCallback(void *user_data, AudioQueueRef queue, AudioQueuePropertyID prop) {

    UInt32 res = 0;
    UInt32 resSize = 0;
    OSStatus status = noErr;

    resSize = sizeof(res);

    status = AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &res, &resSize);

    if (status != noErr) {
        NSLog(@"AudioQueueGetProperty (%d)", status);
    }

    NSLog(@"_RecorderListenerCallback: %d", res);
    if (status == noErr && res == 0) {
        mIsRecording = false;
    }
}

__used static void _CalculateDerivedBufferSize(AudioQueueRef audioQueue, AudioStreamBasicDescription streamDesc,
                                               Float64 seconds, UInt32 *outBufferSize) {

    UInt32 maxPacketSize = 0;
    UInt32 maxVBRPacketSize = 0;
    Float64 numBytesForTime = 0;
    OSStatus status = noErr;

    maxPacketSize = streamDesc.mBytesPerPacket;

    if (maxPacketSize == 0) {
        maxVBRPacketSize = sizeof(maxPacketSize);

        status = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,
                                       &maxVBRPacketSize);

        if (status != noErr) {
            // NSLog(@"AudioQueueGetProperty (%d)", status);
        }
    }

    numBytesForTime = streamDesc.mSampleRate * maxPacketSize * seconds;

    if (numBytesForTime < kMinimumBufferSize) {
        *outBufferSize = kMinimumBufferSize;
    } else if (numBytesForTime > kMaximumBufferSize) {
        *outBufferSize = kMaximumBufferSize;
    } else {
        *outBufferSize = numBytesForTime;
    }
}

__used static OSStatus _RecorderSetup(CFURLRef fileURL) {

    OSStatus status = noErr;
    UInt32 dataFormatSize = 0;
    UInt32 *magicCookie = NULL;
    UInt32 cookieSize = 0;

    Float64 sampleRate = 0;
    UInt32 numberOfChannels = 0;

    sampleRate = 44100.0;
    numberOfChannels = (mATAudioTapDescriptionPID == kATAudioTapDescriptionPIDMicrophone ? 1 : 2);  // built-in mono microphone

    mDataFormat.mFormatID = kAudioFormatMPEG4AAC;
    mDataFormat.mSampleRate = sampleRate;
    mDataFormat.mChannelsPerFrame = numberOfChannels;

    dataFormatSize = sizeof(mDataFormat);

    status = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &dataFormatSize, &mDataFormat);

    if (status != noErr) {
        NSLog(@"AudioFormatGetProperty (%d)", status);
        return status;
    }

    mCurrentPacket = 0;

    status = AudioQueueNewInput(&mDataFormat, _RecorderCallback, NULL, NULL, NULL, 0, &mQueueRef);

    if (status != noErr) {
        NSLog(@"AudioQueueNewInput (%d)", status);
        return status;
    }

    _CalculateDerivedBufferSize(mQueueRef, mDataFormat, 0.5, &mBufferByteSize);

    for (int i = 0; i < kNumberOfBuffers; i++) {
        AudioQueueAllocateBuffer(mQueueRef, mBufferByteSize, &mBuffers[i]);
        AudioQueueEnqueueBuffer(mQueueRef, mBuffers[i], 0, NULL);
    }

    status = AudioFileCreateWithURL(fileURL, kAudioFileCAFType, &mDataFormat, kAudioFileFlags_EraseFile, &mAudioFile);

    if (status != noErr) {
        NSLog(@"AudioFileCreateWithURL (%d)", status);
        return status;
    }

    cookieSize = sizeof(UInt32);
    status = AudioQueueGetPropertySize(mQueueRef, kAudioQueueProperty_MagicCookie, &cookieSize);

    if (status == noErr) {
        magicCookie = (UInt32 *)malloc(cookieSize);

        status = AudioQueueGetProperty(mQueueRef, kAudioQueueProperty_MagicCookie, magicCookie, &cookieSize);
        if (status == noErr) {
            status = AudioFileSetProperty(mAudioFile, kAudioFilePropertyMagicCookieData, cookieSize, magicCookie);

            if (status != noErr) {
                NSLog(@"AudioFileSetProperty (%d)", status);
            }
        } else {
            NSLog(@"AudioQueueGetProperty (%d)", status);
        }

        free(magicCookie);
    } else {
        // NSLog(@"AudioQueueGetPropertySize (%d)", status);
    }

    // Ignore the error
    status = noErr;

    status = AudioQueueAddPropertyListener(mQueueRef, kAudioQueueProperty_IsRunning, _RecorderListenerCallback, NULL);

    if (status != noErr) {
        NSLog(@"AudioQueueAddPropertyListener (%d)", status);
    }

    // Ignore the error
    status = noErr;

    return status;
}

__used static OSStatus _RecorderStart(void) {

    if (mIsRecording) {
        return noErr;
    }

    NSError *error = nil;
    BOOL succeed = NO;
    OSStatus status = noErr;

    /* FIXME: We need some additional setup to avoid AVAudioSession activation here. */
    /* I removed some codes shamefully stolen from AudioRecorder XS by @limneos... */
    /* See _headers_ for further details. */

    succeed = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                                      mode:AVAudioSessionModeDefault
                                                   options:AVAudioSessionCategoryOptionMixWithOthers
                                                     error:&error];

    if (!succeed) {
        NSLog(@"- [AVAudioSession setCategory:error:] error = %@", error);
        return -1;
    }

    succeed = [[AVAudioSession sharedInstance] setActive:YES error:&error];

    if (!succeed) {
        NSLog(@"- [AVAudioSession setActive:error:] error = %@", error);
        return -1;
    }

    status = AudioQueueStart(mQueueRef, NULL);

    if (status != noErr) {
        NSLog(@"AudioQueueStart (%d)", status);
        return status;
    }

    mIsPaused = false;
    mIsRecording = true;

    return status;
}

__used static OSStatus _RecorderPause(void) {

    if (!mIsRecording || mIsPaused) {
        return noErr;
    }

    OSStatus status = noErr;
    NSError *error = nil;
    BOOL succeed = NO;

    status = AudioQueuePause(mQueueRef);

    if (status != noErr) {
        NSLog(@"AudioQueuePause (%d)", status);
    }

    mIsPaused = true;
    mIsRecording = false;

    succeed = [[AVAudioSession sharedInstance] setActive:NO
                                             withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                   error:&error];

    if (!succeed) {
        NSLog(@"- [AVAudioSession setActive:withOptions:error:] error = %@", error);
    }

    return status;
}

__used static OSStatus _RecorderStop(bool stopImmediately, bool deactivateSession) {

    if (!mIsRecording) {
        return noErr;
    }

    OSStatus status = noErr;
    NSError *error = nil;
    BOOL succeed = NO;

    UInt32 *magicCookie = NULL;
    UInt32 cookieSize = 0;

    status = AudioQueueStop(mQueueRef, stopImmediately);

    if (status != noErr) {
        NSLog(@"AudioQueueStop (%d)", status);
    }

    cookieSize = sizeof(UInt32);
    status = AudioQueueGetPropertySize(mQueueRef, kAudioQueueProperty_MagicCookie, &cookieSize);

    if (status == noErr) {
        magicCookie = (UInt32 *)malloc(cookieSize);

        status = AudioQueueGetProperty(mQueueRef, kAudioQueueProperty_MagicCookie, magicCookie, &cookieSize);
        if (status == noErr) {
            status = AudioFileSetProperty(mAudioFile, kAudioFilePropertyMagicCookieData, cookieSize, magicCookie);
            if (status != noErr) {
                NSLog(@"AudioFileSetProperty (%d)", status);
            }
        } else {
            NSLog(@"AudioQueueGetProperty (%d)", status);
        }

        free(magicCookie);
    } else {
        NSLog(@"AudioQueueGetPropertySize (%d)", status);
    }

    // Ignore the error
    status = noErr;

    if (deactivateSession) {
        succeed = [[AVAudioSession sharedInstance] setActive:NO
                                             withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                   error:&error];

        if (!succeed) {
            NSLog(@"- [AVAudioSession setActive:withOptions:error:] error = %@", error);
        }
    }

    if (stopImmediately) {
        mIsPaused = false;
        mIsRecording = false;
    }

    return status;
}

__used static OSStatus _RecorderDispose(void) {

    OSStatus status = noErr;

    status = AudioFileClose(mAudioFile);

    if (status != noErr) {
        NSLog(@"AudioFileClose (%d)", status);
    }

    status = AudioQueueDispose(mQueueRef, true);

    if (status != noErr) {
        NSLog(@"AudioQueueDispose (%d)", status);
    }

    return status;
}

__used static void _SignalInterrupted(int signal) {

    NSLog(@"Stopped by signal %d", signal);
    _RecorderStop(false, false);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      _RecorderStop(true, true);
    });
}

__used static void _SignalStopped(int signal) {

    NSLog(@"Paused by signal %d", signal);
    _RecorderPause();
}

__used static void _SignalResumed(int signal) {

    NSLog(@"Resumed by signal %d", signal);
    _RecorderStart();
}

int main(int argc, const char *argv[]) {

    @autoreleasepool {

        if (argc < 3) {
            printf("Usage: %s <channel> <audio-file>\n", argv[0]);
            return EXIT_FAILURE;
        }

        NSString *channel = [[NSString stringWithUTF8String:argv[1]] lowercaseString];
        if ([channel isEqualToString:@"mic"] || [channel isEqualToString:@"microphone"]) {
            mATAudioTapDescriptionPID = kATAudioTapDescriptionPIDMicrophone;
        } else if ([channel isEqualToString:@"speaker"]) {
            mATAudioTapDescriptionPID = kATAudioTapDescriptionPIDSpeaker;
        } else {
            printf("Invalid channel: %s\n", argv[1]);
            return EXIT_FAILURE;
        }

        NSString *audioFilePath = [NSString stringWithUTF8String:argv[2]];
        CFURLRef fileURL =
            CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)audioFilePath, kCFURLPOSIXPathStyle, false);

        OSStatus status = _RecorderSetup(fileURL);

        if (status != noErr) {
            NSLog(@"_RecorderSetup (%d)", status);
            return EXIT_FAILURE;
        }

        status = _RecorderStart();

        if (status != noErr) {
            NSLog(@"_RecorderStart (%d)", status);
            return EXIT_FAILURE;
        }

        {
            struct sigaction act = {{0}};
            struct sigaction oldact = {{0}};
            act.sa_handler = &_SignalInterrupted;
            sigaction(SIGINT, &act, &oldact);
        }

        {
            struct sigaction act = {{0}};
            struct sigaction oldact = {{0}};
            act.sa_handler = &_SignalStopped;
            sigaction(SIGUSR1, &act, &oldact);
        }

        {
            struct sigaction act = {{0}};
            struct sigaction oldact = {{0}};
            act.sa_handler = &_SignalResumed;
            sigaction(SIGUSR2, &act, &oldact);
        }

        printf("Recording > Press <Ctrl+C> to stop.\n");

        OSStatus timingStatus = noErr;
        NSTimeInterval lastReportedTimeInSeconds = 0.0;
        NSTimeInterval currentTimeInSeconds = 0.0;

        while (mIsRecording || mIsPaused) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1e-2, true);

            timingStatus = AudioQueueGetCurrentTime(mQueueRef, NULL, &mRecordedTime, NULL);

            if (timingStatus == noErr) {
                currentTimeInSeconds = mRecordedTime.mSampleTime / mDataFormat.mSampleRate;

                if (currentTimeInSeconds - lastReportedTimeInSeconds > 1.0) {
                    lastReportedTimeInSeconds = currentTimeInSeconds;

                    printf("Recording > %02d:%02d:%02d\n", (int)currentTimeInSeconds / 3600,
                           (int)currentTimeInSeconds / 60 % 60, (int)currentTimeInSeconds % 60);
                }
            }
        }

        status = _RecorderStop(true, true);
        if (status != noErr) {
            NSLog(@"_RecorderStop (%d)", status);
            return EXIT_FAILURE;
        }

        status = _RecorderDispose();
        if (status != noErr) {
            NSLog(@"_RecorderDispose (%d)", status);
            return EXIT_FAILURE;
        }

        CFRelease(fileURL);
    }

    return EXIT_SUCCESS;
}
