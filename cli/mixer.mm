//
//  mixer.mm
//  TrollRecorder
//
//  Created by Lessica on 2024/2/10.
//

#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>

#define BUFFER_SIZE 8192
static const Float64 kMaxSampleRate = 44100.0;

static bool mIsCombinerMode = false;
static Float64 mPreferredSampleRate = 0;
static AudioFileTypeID mOutputAudioFileTypeID = kAudioFileWAVEType;

__used static AVAudioFormat *_SetupStreamDescription(AudioStreamBasicDescription *audioFormatPtr, Float64 sampleRate,
                                                     UInt32 numChannels) {
    bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
    AVAudioFormat *audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                                  sampleRate:(double)sampleRate
                                                                    channels:(AVAudioChannelCount)numChannels
                                                                 interleaved:YES];
    *audioFormatPtr = *([audioFormat streamDescription]);
    return audioFormat;
}

int main(int argc, const char *argv[]) {

    @autoreleasepool {

        if (argc < 4) {
            printf("Usage: %s <input-1.caf> <input-2.caf> <output.m4a> <sample-rate>\n", argv[0]);
            return EXIT_FAILURE;
        }

        NSString *binaryPath = [NSString stringWithUTF8String:argv[0]];
        if ([binaryPath hasSuffix:@"/audio-combiner"] || [binaryPath isEqualToString:@"audio-combiner"]) {
            mIsCombinerMode = true;
            NSLog(@"Running in combiner mode");
        } else {
            mIsCombinerMode = false;
            NSLog(@"Running in mixer mode");
        }

        NSString *audioPath1 = [NSString stringWithUTF8String:argv[1]];
        NSString *audioPath2 = [NSString stringWithUTF8String:argv[2]];
        NSString *outputPath = [NSString stringWithUTF8String:argv[3]];
        NSString *outputExt = [[outputPath pathExtension] lowercaseString];

        if ([outputExt isEqualToString:@"m4a"]) {
            mOutputAudioFileTypeID = kAudioFileM4AType;
        } else if ([outputExt isEqualToString:@"wav"]) {
            mOutputAudioFileTypeID = kAudioFileWAVEType;
        } else if ([outputExt isEqualToString:@"caf"]) {
            mOutputAudioFileTypeID = kAudioFileCAFType;
        } else {
            NSLog(@"Unsupported output file type: %@", outputExt);
            return EXIT_FAILURE;
        }

        if (argc > 4) {
            mPreferredSampleRate = MIN([[NSString stringWithUTF8String:argv[4]] doubleValue], kMaxSampleRate);
        }

        OSStatus err = noErr;
        UInt32 propertySize = sizeof(AudioStreamBasicDescription);
        AudioStreamBasicDescription inputStreamDesc1 = {0};
        AudioStreamBasicDescription inputStreamDesc2 = {0};
        AudioStreamBasicDescription outStreamDesc = {0};
        AVAudioFormat *inputAudioFormat1 = nil;
        AVAudioFormat *inputAudioFormat2 = nil;
        AVAudioFormat *outputAudioFormat = nil;
        ExtAudioFileRef inputAudioFileRef1 = NULL;
        ExtAudioFileRef inputAudioFileRef2 = NULL;
        ExtAudioFileRef outputAudioFileRef = NULL;

        CFURLRef inURL1 = NULL;
        CFURLRef inURL2 = NULL;
        CFURLRef outURL = NULL;

        NSTimeInterval lastReportedTimeInSeconds = 0.0;
        NSTimeInterval currentTimeInSeconds = 0.0;

        do {
            inURL1 = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)audioPath1, kCFURLPOSIXPathStyle,
                                                   false);
            inURL2 = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)audioPath2, kCFURLPOSIXPathStyle,
                                                   false);
            outURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)outputPath, kCFURLPOSIXPathStyle,
                                                   false);

            err = ExtAudioFileOpenURL(inURL1, &inputAudioFileRef1);

            if (err != noErr) {
                NSLog(@"ExtAudioFileOpenURL (%d)", (int)err);
                break;
            }

            err = ExtAudioFileOpenURL(inURL2, &inputAudioFileRef2);

            if (err != noErr) {
                NSLog(@"ExtAudioFileOpenURL (%d)", (int)err);
                break;
            }

            bzero(&inputStreamDesc1, sizeof(inputStreamDesc1));
            err = ExtAudioFileGetProperty(inputAudioFileRef1, kExtAudioFileProperty_FileDataFormat, &propertySize,
                                          &inputStreamDesc1);

            if (err != noErr) {
                NSLog(@"ExtAudioFileGetProperty (%d)", (int)err);
                break;
            }

            bzero(&inputStreamDesc2, sizeof(inputStreamDesc2));
            err = ExtAudioFileGetProperty(inputAudioFileRef2, kExtAudioFileProperty_FileDataFormat, &propertySize,
                                          &inputStreamDesc2);
            if (err != noErr) {
                NSLog(@"ExtAudioFileGetProperty (%d)", (int)err);
                break;
            }

            UInt32 outputNumberOfChannels = 2;
            Float64 outputSampleRate =
                mPreferredSampleRate > 0
                    ? mPreferredSampleRate
                    : MIN(MAX(inputStreamDesc1.mSampleRate, inputStreamDesc2.mSampleRate), kMaxSampleRate);

            inputAudioFormat1 = _SetupStreamDescription(&inputStreamDesc1, outputSampleRate, outputNumberOfChannels);
            err = ExtAudioFileSetProperty(inputAudioFileRef1, kExtAudioFileProperty_ClientDataFormat,
                                          sizeof(inputStreamDesc1), &inputStreamDesc1);

            if (err != noErr) {
                NSLog(@"ExtAudioFileSetProperty (%d)", (int)err);
                break;
            }

            inputAudioFormat2 = _SetupStreamDescription(&inputStreamDesc2, outputSampleRate, outputNumberOfChannels);
            err = ExtAudioFileSetProperty(inputAudioFileRef2, kExtAudioFileProperty_ClientDataFormat,
                                          sizeof(inputStreamDesc2), &inputStreamDesc2);

            if (err != noErr) {
                NSLog(@"ExtAudioFileSetProperty (%d)", (int)err);
                break;
            }

            AudioChannelLayout channelLayout = {0};
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;

            outputAudioFormat = _SetupStreamDescription(&outStreamDesc, outputSampleRate, outputNumberOfChannels);
            err = ExtAudioFileCreateWithURL(outURL, mOutputAudioFileTypeID, &outStreamDesc, &channelLayout,
                                            kAudioFileFlags_EraseFile, &outputAudioFileRef);

            if (err != noErr) {
                NSLog(@"ExtAudioFileCreateWithURL (%d)", (int)err);
                break;
            }

            err = ExtAudioFileSetProperty(outputAudioFileRef, kExtAudioFileProperty_ClientDataFormat,
                                          sizeof(outStreamDesc), &outStreamDesc);

            if (err != noErr) {
                NSLog(@"ExtAudioFileSetProperty (%d)", (int)err);
                break;
            }

            AVAudioPCMBuffer *convPCMBuffer1 =
                [[AVAudioPCMBuffer alloc] initWithPCMFormat:inputAudioFormat1
                                              frameCapacity:BUFFER_SIZE / inputStreamDesc1.mBytesPerFrame];
            convPCMBuffer1.frameLength = convPCMBuffer1.frameCapacity;
            AudioBufferList *conversionBufferList1 = convPCMBuffer1.mutableAudioBufferList;
            UInt16 *conversionBuffer1 = (UInt16 *)conversionBufferList1->mBuffers[0].mData;

            AVAudioPCMBuffer *convPCMBuffer2 =
                [[AVAudioPCMBuffer alloc] initWithPCMFormat:inputAudioFormat2
                                              frameCapacity:BUFFER_SIZE / inputStreamDesc2.mBytesPerFrame];
            convPCMBuffer2.frameLength = convPCMBuffer2.frameCapacity;
            AudioBufferList *conversionBufferList2 = convPCMBuffer2.mutableAudioBufferList;
            UInt16 *conversionBuffer2 = (UInt16 *)conversionBufferList2->mBuffers[0].mData;

            AVAudioPCMBuffer *outPCMBuffer =
                [[AVAudioPCMBuffer alloc] initWithPCMFormat:outputAudioFormat
                                              frameCapacity:BUFFER_SIZE / outStreamDesc.mBytesPerFrame];
            outPCMBuffer.frameLength = outPCMBuffer.frameCapacity;
            AudioBufferList *outBufferList = outPCMBuffer.mutableAudioBufferList;
            UInt16 *outBuffer = (UInt16 *)outBufferList->mBuffers[0].mData;

            BOOL writeLeftChannel = YES;

            while (1) {

                convPCMBuffer1.frameLength = convPCMBuffer1.frameCapacity;
                convPCMBuffer2.frameLength = convPCMBuffer2.frameCapacity;
                outPCMBuffer.frameLength = outPCMBuffer.frameCapacity;

                UInt32 convFrameLength1 = convPCMBuffer1.frameLength;
                UInt32 convFrameLength2 = convPCMBuffer2.frameLength;

                err = ExtAudioFileRead(inputAudioFileRef1, &convFrameLength1, conversionBufferList1);

                if (err != noErr) {
                    NSLog(@"ExtAudioFileRead (%d)", (int)err);
                    break;
                }

                err = ExtAudioFileRead(inputAudioFileRef2, &convFrameLength2, conversionBufferList2);

                if (err != noErr) {
                    NSLog(@"ExtAudioFileRead (%d)", (int)err);
                    break;
                }

                if (convFrameLength1 == 0 && convFrameLength2 == 0) {
                    break;
                }

                UInt32 maximumFrameLength = MAX(convFrameLength1, convFrameLength2);
                UInt32 minimumFrameLength = MIN(convFrameLength1, convFrameLength2);

                outPCMBuffer.frameLength = maximumFrameLength;

                UInt32 stereoCount = maximumFrameLength * 2;
                if (mIsCombinerMode) {
                    goto combiner;
                } else {
                    goto mixer;
                }

            combiner:
                for (UInt32 j = 0; j < stereoCount; j++) {
                    if (j / 2 < minimumFrameLength) {
                        *(outBuffer + j) = writeLeftChannel ? *(conversionBuffer1 + j) : *(conversionBuffer2 + j);
                    } else {
                        if (maximumFrameLength == convFrameLength1) {
                            *(outBuffer + j) = writeLeftChannel ? *(conversionBuffer1 + j) : 0;
                        } else {
                            *(outBuffer + j) = writeLeftChannel ? 0 : *(conversionBuffer2 + j);
                        }
                    }
                    writeLeftChannel = !writeLeftChannel;
                }
                goto writer;

            mixer:
                /* FIXME: I removed the mixer code for brevity. */
                goto combiner;

            writer:
                err = ExtAudioFileWrite(outputAudioFileRef, maximumFrameLength, outBufferList);

                if (err != noErr) {
                    NSLog(@"ExtAudioFileWrite (%d)", (int)err);
                    break;
                }

                SInt64 outFrameOffset = 0;
                err = ExtAudioFileTell(outputAudioFileRef, &outFrameOffset);

                if (err != noErr) {
                    NSLog(@"ExtAudioFileTell (%d)", (int)err);
                    break;
                }

                currentTimeInSeconds = (NSTimeInterval)outFrameOffset / outStreamDesc.mSampleRate;
                if (currentTimeInSeconds - lastReportedTimeInSeconds >= 1.0) {
                    lastReportedTimeInSeconds = currentTimeInSeconds;

                    printf("Converting > %02d:%02d:%02d\n", (int)currentTimeInSeconds / 3600,
                           (int)currentTimeInSeconds / 60, (int)currentTimeInSeconds % 60);
                }
            }
        } while (NO);

        if (currentTimeInSeconds > 0) {
            printf("Converting > %02d:%02d:%02d\n", (int)currentTimeInSeconds / 3600, (int)currentTimeInSeconds / 60,
                   (int)currentTimeInSeconds % 60);
        }

        if (inURL1) {
            CFRelease(inURL1);
        }

        if (inURL2) {
            CFRelease(inURL2);
        }

        if (outURL) {
            CFRelease(outURL);
        }

        if (inputAudioFileRef1) {
            ExtAudioFileDispose(inputAudioFileRef1);
        }

        if (inputAudioFileRef2) {
            ExtAudioFileDispose(inputAudioFileRef2);
        }

        if (outputAudioFileRef) {
            ExtAudioFileDispose(outputAudioFileRef);
        }

        return err == noErr ? EXIT_SUCCESS : EXIT_FAILURE;
    }
}
