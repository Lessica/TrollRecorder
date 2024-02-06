#import <AVFAudio/AVFAudio.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

static const int kNumberOfBuffers = 3;
static const int kMaximumBufferSize = 0x50000;
static const int kMinimumBufferSize = 0x4000;

static AudioStreamBasicDescription mDataFormat = {0};
static AudioQueueRef mQueueRef = NULL;
static AudioQueueBufferRef mBuffers[kNumberOfBuffers] = {0};
static AudioFileID mAudioFile = 0;
static UInt32 mBufferByteSize = 0;
static SInt64 mCurrentPacket = 0;
static UInt32 mPacketsToRead = 0;
static AudioStreamPacketDescription *mPacketDescs = NULL;
static bool mIsPlaying = false;
static bool mIsPaused = false;
static Float64 mFileDuration = 0;
static AudioTimeStamp mPlayedTime = {0};
static Float32 mGain = 1.0f;

__used static void _PlayerCallback(void *ptr, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {

    UInt32 numBytesReadFromFile = 0;
    UInt32 numPackets = 0;
    OSStatus status = noErr;

    numBytesReadFromFile = mBufferByteSize;
    numPackets = mPacketsToRead;

    status = AudioFileReadPacketData(mAudioFile, false, &numBytesReadFromFile, mPacketDescs, mCurrentPacket,
                                     &numPackets, inBuffer->mAudioData);

    if (status != noErr) {
        NSLog(@"AudioFileReadPacketData (%d)", status);
    }

    if (numPackets > 0) {
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
        mCurrentPacket += numPackets;
        status = AudioQueueEnqueueBuffer(mQueueRef, inBuffer, mPacketDescs ? numPackets : 0, mPacketDescs);

        // if (status != noErr) {
        //     NSLog(@"AudioQueueEnqueueBuffer (%d)", status);
        // }
    } else {
        status = AudioQueueStop(mQueueRef, false);

        if (status != noErr) {
            NSLog(@"AudioQueueStop (%d)", status);
        }
    }
}

__used static void _PlayerListenerCallback(void *user_data, AudioQueueRef queue, AudioQueuePropertyID prop) {

    UInt32 res = 0;
    UInt32 resSize = 0;
    OSStatus status = noErr;

    resSize = sizeof(res);

    status = AudioQueueGetProperty(queue, kAudioQueueProperty_IsRunning, &res, &resSize);

    if (status != noErr) {
        NSLog(@"AudioQueueGetProperty (%d)", status);
    }

    NSLog(@"_PlayerListenerCallback: %d", res);

    if (status == noErr && res == 0) {
        mIsPlaying = false;
    }
}

__used static void _CalculatePlayerBufferSize(AudioStreamBasicDescription basicDesc, UInt32 maxPacketSize,
                                              Float64 seconds, UInt32 *outBufferSize, UInt32 *outNumPacketsToRead) {

    Float64 numPacketsForTime = 0;

    if (basicDesc.mFramesPerPacket != 0) {
        numPacketsForTime = basicDesc.mSampleRate / basicDesc.mFramesPerPacket * seconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        *outBufferSize = kMaximumBufferSize > maxPacketSize ? kMaximumBufferSize : maxPacketSize;
    }

    if (*outBufferSize > kMaximumBufferSize && *outBufferSize > maxPacketSize) {
        *outBufferSize = kMaximumBufferSize;
    } else {
        if (*outBufferSize < kMinimumBufferSize) {
            *outBufferSize = kMinimumBufferSize;
        }
    }

    *outNumPacketsToRead = *outBufferSize / maxPacketSize;
}

__used static OSStatus _PlayerSetup(CFURLRef fileURL) {

    OSStatus status = noErr;
    UInt32 dataFormatSize = 0;
    UInt32 maxPacketSize = 0;
    UInt32 propertySize = 0;
    UInt64 nPackets = 0;
    UInt32 *magicCookie = NULL;
    UInt32 cookieSize = 0;
    bool isVBRFormat = false;

    status = AudioFileOpenURL(fileURL, kAudioFileReadPermission, kAudioFileCAFType, &mAudioFile);

    if (status != noErr) {
        NSLog(@"AudioFileOpenURL (%d)", status);
        return status;
    }

    dataFormatSize = sizeof(mDataFormat);
    AudioFileGetProperty(mAudioFile, kAudioFilePropertyDataFormat, &dataFormatSize, &mDataFormat);

    status = AudioQueueNewOutput(&mDataFormat, _PlayerCallback, NULL, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0,
                                 &mQueueRef);

    if (status != noErr) {
        NSLog(@"AudioQueueNewOutput (%d)", status);
        AudioFileClose(mAudioFile);
        return status;
    }

    propertySize = sizeof(maxPacketSize);
    status = AudioFileGetProperty(mAudioFile, kAudioFilePropertyPacketSizeUpperBound, &propertySize, &maxPacketSize);

    if (status != noErr) {
        NSLog(@"AudioFileGetProperty (%d)", status);
        AudioFileClose(mAudioFile);
        AudioQueueDispose(mQueueRef, true);
        return status;
    }

    _CalculatePlayerBufferSize(mDataFormat, maxPacketSize, 0.5, &mBufferByteSize, &mPacketsToRead);

    mCurrentPacket = 0;

    isVBRFormat = mDataFormat.mBytesPerPacket == 0 || mDataFormat.mFramesPerPacket == 0;

    if (isVBRFormat) {
        mPacketDescs = (AudioStreamPacketDescription *)malloc(mPacketsToRead * sizeof(AudioStreamPacketDescription));
    } else {
        mPacketDescs = NULL;
    }

    propertySize = sizeof(nPackets);
    status = AudioFileGetProperty(mAudioFile, kAudioFilePropertyAudioDataPacketCount, &propertySize, &nPackets);

    if (status != noErr) {
        NSLog(@"AudioFileGetProperty (%d)", status);
        AudioFileClose(mAudioFile);
        AudioQueueDispose(mQueueRef, true);
        return status;
    }

    mFileDuration = (nPackets * mDataFormat.mFramesPerPacket) / mDataFormat.mSampleRate;

    cookieSize = sizeof(UInt32);
    status = AudioFileGetPropertyInfo(mAudioFile, kAudioFilePropertyMagicCookieData, &cookieSize, NULL);
    if (status == noErr && cookieSize) {
        magicCookie = (UInt32 *)malloc(cookieSize);

        status = AudioFileGetProperty(mAudioFile, kAudioFilePropertyMagicCookieData, &cookieSize, magicCookie);
        if (status == noErr) {
            status = AudioQueueSetProperty(mQueueRef, kAudioQueueProperty_MagicCookie, magicCookie, cookieSize);
            if (status != noErr) {
                NSLog(@"AudioQueueSetProperty (%d)", status);
            }
        } else {
            NSLog(@"AudioFileGetProperty (%d)", status);
        }

        free(magicCookie);
    } else {
        NSLog(@"AudioFileGetPropertyInfo (%d)", status);
    }

    // Ignore the error
    status = noErr;

    for (int i = 0; i < kNumberOfBuffers; i++) {
        AudioQueueAllocateBuffer(mQueueRef, mBufferByteSize, &mBuffers[i]);
        _PlayerCallback(NULL, mQueueRef, mBuffers[i]);
    }

    status = AudioQueueSetParameter(mQueueRef, kAudioQueueParam_Volume, mGain);

    if (status != noErr) {
        NSLog(@"AudioQueueSetParameter (%d)", status);
    }

    status = AudioQueueAddPropertyListener(mQueueRef, kAudioQueueProperty_IsRunning, _PlayerListenerCallback, NULL);

    if (status != noErr) {
        NSLog(@"AudioQueueAddPropertyListener (%d)", status);
    }

    // Ignore the error
    status = noErr;

    return status;
}

__used static OSStatus _PlayerStart(void) {

    if (mIsPlaying) {
        return noErr;
    }

    OSStatus status = noErr;
    NSError *error = nil;
    BOOL succeed = NO;

    succeed = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];

    if (!succeed) {
        NSLog(@"- [AVAudioSession setCategory:error:] error = %@", error);
        return -1;
    }

    succeed = [[AVAudioSession sharedInstance] setActive:YES
                                             withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                   error:&error];
    if (!succeed) {
        NSLog(@"- [AVAudioSession setActive:withOptions:error:] error = %@", error);
        return -1;
    }

    status = AudioQueueStart(mQueueRef, mPlayedTime.mHostTime > 0 ? &mPlayedTime : NULL);

    if (status != noErr) {
        NSLog(@"AudioQueueStart (%d)", status);
        return status;
    }

    mIsPaused = false;
    mIsPlaying = true;

    return status;
}

__used static OSStatus _PlayerPause(void) {

    if (!mIsPlaying || mIsPaused) {
        return noErr;
    }

    OSStatus status = noErr;
    NSError *error = nil;
    BOOL succeed = NO;

    status = AudioQueueGetCurrentTime(mQueueRef, NULL, &mPlayedTime, NULL);

    if (status != noErr) {
        NSLog(@"AudioQueueGetCurrentTime (%d)", status);
    }

    status = AudioQueuePause(mQueueRef);

    if (status != noErr) {
        NSLog(@"AudioQueuePause (%d)", status);
    }

    mIsPaused = true;
    mIsPlaying = false;

    succeed = [[AVAudioSession sharedInstance] setActive:NO
                                             withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                   error:&error];

    if (!succeed) {
        NSLog(@"- [AVAudioSession setActive:withOptions:error:] error = %@", error);
    }

    return status;
}

__used static OSStatus _PlayerStop(bool stopImmediately) {

    if (!mIsPlaying) {
        return noErr;
    }

    OSStatus status = noErr;
    NSError *error = nil;
    BOOL succeed = NO;

    status = AudioQueueStop(mQueueRef, stopImmediately);

    if (status != noErr) {
        NSLog(@"AudioQueueStop (%d)", status);
    }

    succeed = [[AVAudioSession sharedInstance] setActive:NO
                                             withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                                   error:&error];

    if (!succeed) {
        NSLog(@"- [AVAudioSession setActive:withOptions:error:] error = %@", error);
    }

    if (stopImmediately) {
        mIsPaused = false;
        mIsPlaying = false;
    }

    return status;
}

__used static OSStatus _PlayerDispose(void) {

    OSStatus status = noErr;

    status = AudioFileClose(mAudioFile);

    if (status != noErr) {
        NSLog(@"AudioFileClose (%d)", status);
    }

    status = AudioQueueDispose(mQueueRef, true);

    if (status != noErr) {
        NSLog(@"AudioQueueDispose (%d)", status);
    }

    if (mPacketDescs) {
        free(mPacketDescs);
    }

    return status;
}

__used static void _SignalInterrupted(int signal) {

    NSLog(@"Stopped by signal %d", signal);
    _PlayerStop(true);
}

__used static void _SignalStopped(int signal) {

    NSLog(@"Paused by signal %d", signal);
    _PlayerPause();
}

__used static void _SignalResumed(int signal) {

    NSLog(@"Resumed by signal %d", signal);
    _PlayerStart();
}

int main(int argc, const char *argv[]) {

    @autoreleasepool {

        if (argc < 2) {
            printf("Usage: %s <audio-file> <volume>\n", argv[0]);
            return EXIT_FAILURE;
        }

        NSString *audioFilePath = [NSString stringWithUTF8String:argv[1]];
        CFURLRef fileURL =
            CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)audioFilePath, kCFURLPOSIXPathStyle, false);

        if (argc > 2) {
            mGain = MIN(MAX(atof(argv[2]), 0.0f), 1.0f);
        } else {
            mGain = 1.0f;
        }

        OSStatus status = _PlayerSetup(fileURL);

        if (status != noErr) {
            NSLog(@"_PlayerSetup (%d)", status);
            return EXIT_FAILURE;
        }

        status = _PlayerStart();

        if (status != noErr) {
            NSLog(@"_PlayerStart (%d)", status);
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

        printf("Playing > Press <Ctrl+C> to stop.\n");

        OSStatus timingStatus = noErr;
        NSTimeInterval lastReportedTimeInSeconds = 0.0;
        NSTimeInterval currentTimeInSeconds = 0.0;

        while (mIsPlaying || mIsPaused) {

            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1e-2, true);

            timingStatus = AudioQueueGetCurrentTime(mQueueRef, NULL, &mPlayedTime, NULL);

            if (timingStatus == noErr) {
                currentTimeInSeconds = mPlayedTime.mSampleTime / mDataFormat.mSampleRate;

                if (currentTimeInSeconds - lastReportedTimeInSeconds > 1.0) {
                    lastReportedTimeInSeconds = currentTimeInSeconds;

                    printf("Playing > %02d:%02d:%02d / %02d:%02d:%02d\n", (int)currentTimeInSeconds / 3600,
                           (int)currentTimeInSeconds / 60 % 60, (int)currentTimeInSeconds % 60,
                           (int)mFileDuration / 3600, (int)mFileDuration / 60 % 60, (int)mFileDuration % 60);
                }
            }
        }

        status = _PlayerStop(true);
        if (status != noErr) {
            NSLog(@"_PlayerStop (%d)", status);
            return EXIT_FAILURE;
        }

        status = _PlayerDispose();
        if (status != noErr) {
            NSLog(@"_PlayerDispose (%d)", status);
            return EXIT_FAILURE;
        }

        CFRelease(fileURL);
    }

    return EXIT_SUCCESS;
}
