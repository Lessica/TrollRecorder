/*
 $Id: DTMFDecoder.m 125 2010-09-19 00:01:02Z veg $

 Dreadtech DTMF Decoder - Copyright 2010 Martin Wellard

 This file is part of Dreadtech DTMF Decoder.

 Dreadtech DTMF Decoder is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Dreadtech DTMF Decoder is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Dreadtech DTMF Decoder.  If not, see <http://www.gnu.org/licenses/>.
 */

/* NOTE: VoLTE must be disabled to validate the DTMF tones. */

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioToolbox/AudioQueue.h>
#import <Foundation/Foundation.h>
#import <HBLog.h>

#import "ATAudioTap.h"
#import "ATAudioTapDescription.h"
#import "AudioQueue+Private.h"

#define SAMPLING_RATE 8000.0
#define NUM_BUFFERS 40
#define DETECTBUFFERLEN 8192

#define MIN_TONE_LENGTH 0.045
#define FRAMES_PER_TONE 2
#define BYTES_PER_CHANNEL 2
#define BUFFER_SIZE ((int)(MIN_TONE_LENGTH * SAMPLING_RATE * BYTES_PER_CHANNEL) / FRAMES_PER_TONE)

#define NUM_FREQS 8

#define kMinNoiseToleranceFactor 1.5
#define kMaxNoiseToleranceFactor 6.5

struct FilterCoefficientsEntry {
    double unityGainCorrection;
    double coeff1;
    double coeff2;
};

typedef struct {
    AudioStreamBasicDescription dataFormat;
    AudioQueueRef queue;
    AudioQueueBufferRef buffers[NUM_BUFFERS];
    BOOL isRecording;
    SInt64 currentPacket;
    short filteredBuffer[BUFFER_SIZE];
    char *detectBuffer;
    BOOL bufferChanged;
    ATAudioTap *audioTap;
} RecordState;

static double powers[NUM_FREQS];     // Location to store the powers for all the frequencies.
static double filterBuf0[NUM_FREQS]; // Buffer for the IIR filter slot 0.
static double filterBuf1[NUM_FREQS]; // Buffer for the IIR filter slot 1.
static char holdingBuffer[2];
static int holdingBufferCount[2];
static int powerMeasurementMethod; // 0 = Peak Value -> RMS, 1 = Sqrt of Sum of Squares, 2 = Sum of Abs Values
static BOOL rawOutput;
static double noiseToleranceFactor;

// Filter coefficients
static const struct FilterCoefficientsEntry filterCoefficients[NUM_FREQS] = {
    {0.002729634465943104, 1.703076309365611, 0.994540731068114},   // 697 Hz
    {0.003014658069540622, 1.640321076289727, 0.9939706838609188},  // 770 Hz
    {0.003334626751652912, 1.563455998285116, 0.9933307464966943},  // 852 Hz
    {0.003681676706860666, 1.472762296913335, 0.9926366465862788},  // 941 Hz
    {0.00472526211613835, 1.158603326387692, 0.9905494757677233},   // 1209 Hz
    {0.005219030413485972, 0.991170124246961, 0.989561939173028},   // 1336 Hz
    {0.005766653227008568, 0.7940130339147109, 0.9884666935459827}, // 1477 Hz
    {0.006371827557152048, 0.5649101144069607, 0.9872563448856961}  // 1633 Hz
};

static const char dtmfCodes[4][4] = {
    {'1', '2', '3', 'A'},
    {'4', '5', '6', 'B'},
    {'7', '8', '9', 'C'},
    {'*', '0', '#', 'D'},
};

// BpRe/100/frequency == Bandpass resonator, Q=100 (0=>Inf), frequency
// e.g. ./fiview 8000 -i BpRe/100/1336
// Generated using  http://uazu.net/fiview/
static double bandPassFilter(register double val, int filterIndex) {
    register double tmp, fir, iir;
    tmp = filterBuf0[filterIndex];
    filterBuf0[filterIndex] = filterBuf1[filterIndex];
    val *= filterCoefficients[filterIndex].unityGainCorrection;
    iir = val + filterCoefficients[filterIndex].coeff1 * filterBuf0[filterIndex] -
          filterCoefficients[filterIndex].coeff2 * tmp;
    fir = iir - tmp;
    filterBuf1[filterIndex] = iir;
    val = fir;
    return val;
}

static char lookupDTMFCode(void) {
    // Find the highest powered frequency index.
    int max1Index = 0;
    for (int i = 0; i < NUM_FREQS; i++) {
        if (powers[i] >= powers[max1Index])
            max1Index = i;
    }

    // Find the 2nd highest powered frequency index.
    int max2Index;

    if (max1Index == 0) {
        max2Index = 1;
    } else {
        max2Index = 0;
    }

    for (int i = 0; i < NUM_FREQS; i++) {
        if ((powers[i] >= powers[max2Index]) && (i != max1Index))
            max2Index = i;
    }

    // Check that fequency 1 and 2 are substantially bigger than any other frequencies.
    BOOL valid = YES;
    for (int i = 0; i < NUM_FREQS; i++) {
        if ((i == max1Index) || (i == max2Index))
            continue;

        if (powers[i] > (powers[max2Index] / noiseToleranceFactor)) {
            valid = NO;
            break;
        }
    }

    if (valid) {
        HBLogDebug(@"Highest frequencies found: %d %d", max1Index, max2Index);

        // Figure out which one is a row and which one is a column.
        int row = -1;
        int col = -1;
        if ((max1Index >= 0) && (max1Index <= 3)) {
            row = max1Index;
        } else {
            col = max1Index;
        }

        if ((max2Index >= 4) && (max2Index <= 7)) {
            col = max2Index;
        } else {
            row = max2Index;
        }

        // Check we have both the row and column and fail if we have 2 rows or 2 columns.
        if ((row == -1) || (col == -1)) {
            // We have to rows or 2 cols, fail.
            HBLogError(@"We have 2 rows or 2 columns, must have gotten it wrong.");
        } else {
            HBLogDebug(@"DTMF code %c", dtmfCodes[row][col - 4]);
            return dtmfCodes[row][col - 4];
        }
    }

    return ' ';
}

static void AudioInputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer,
                               const AudioTimeStamp *inStartTime, UInt32 inNumberPacketDescriptions,
                               const AudioStreamPacketDescription *inPacketDescs) {

    RecordState *recordState = (RecordState *)inUserData;

    if (!recordState->isRecording) {
        HBLogError(@"Not recording, returning.");
    }

    recordState->currentPacket += inNumberPacketDescriptions;

    size_t i, numberOfSamples = inBuffer->mAudioDataByteSize / 2;
    short *p = (short *)inBuffer->mAudioData;
    short min, max;

    // Normalize - AKA Automatic Gain
    min = p[0];
    max = p[0];
    long zerocount = 0;
    for (i = 0L; i < numberOfSamples; i++) {
        if (p[i] == 0)
            zerocount++;
        if (p[i] < min)
            min = p[i];
        if (p[i] > max)
            max = p[i];
    }
    min = abs(min);
    max = abs(max);
    if (max < min) {
        max = min; // Pick bigger of max and min.
    }

    for (i = 0L; i < numberOfSamples; i++) {
        p[i] = (short)(((double)p[i] / (double)max) * (double)32767);
    }

    HBLogDebug(@"%d %d %ld %lf", min, max, zerocount, inStartTime->mSampleTime);

    // Reset all previous power calculations.
    int t;
    double val;

    for (t = 0; t < NUM_FREQS; t++) {
        powers[t] = (double)0.0;
    }

    // Run the bandpass filter and calculate the power.
    for (i = 0L; i < numberOfSamples; i++) {
        for (t = 0; t < NUM_FREQS; t++) {

            // Find the highest value.
            switch (powerMeasurementMethod) {
            case 0:
                val = fabs(bandPassFilter((double)p[i], t));
                if (val > powers[t])
                    powers[t] = val;
                break;
            case 1:
                val = bandPassFilter((double)p[i], t);
                powers[t] += val * val;
                break;
            default:
                powers[t] += fabs(bandPassFilter((double)p[i], t));
                break;
            }
        }
    }

    // Scale 0 - 1, then convert into an power value.
    for (t = 0; t < NUM_FREQS; t++) {
        switch (powerMeasurementMethod) {
        case 0:
            powers[t] = (powers[t] / (double)32768.0) * ((double)1.0 / sqrt((double)2.0));
            break;
        case 1:
            powers[t] = sqrt(powers[t] / (double)numberOfSamples) / (double)32768.0;
            break;
        default:
            powers[t] = (powers[t] / (double)numberOfSamples) / (double)32768.0;
            break;
        }
    }

    HBLogDebug(@"HB %d %d", holdingBuffer[0], holdingBuffer[1]);
    HBLogDebug(@"RMS Powers: %0.3lf, %0.3lf, %0.3lf, %0.3lf, %0.3lf, %0.3lf, %0.3lf, %0.3lf", powers[0], powers[1],
               powers[2], powers[3], powers[4], powers[5], powers[6], powers[7]);

    // Figure out the dtmf code <space> is nothing recognized.
    char chr = lookupDTMFCode();

    // Add it to the buffer.
    BOOL showBuffer = NO;

    if (chr == holdingBuffer[1]) {
        holdingBufferCount[1]++;
        // To deal with the case where we've received nothing for a while,
        // spit out the buffer.
        if ((holdingBuffer[1] == ' ') && (holdingBufferCount[1] >= 40))
            showBuffer = YES;
    } else {
        showBuffer = YES;
    }

    if (showBuffer) {
        // Combine the buffer entries if they're the same.
        if (holdingBuffer[1] == holdingBuffer[0]) {
            holdingBufferCount[1] += holdingBufferCount[0];
            holdingBuffer[0] = 0;
            holdingBufferCount[0] = 0;
        }

        // Archive the current value if we have more than 2 samples.
        if ((holdingBufferCount[1] > 1) || (rawOutput)) {
            if ((holdingBuffer[0] != 0) && (holdingBuffer[0] != ' ')) {
                char tmp[20] = "";
                if (rawOutput) {
                    snprintf(tmp, 20, "%c(%d) ", holdingBuffer[0], holdingBufferCount[0]);
                } else {
                    snprintf(tmp, 20, "%c", holdingBuffer[0]);
                }
                if (strlen(recordState->detectBuffer) + strlen(tmp) < DETECTBUFFERLEN) {
                    strcat(recordState->detectBuffer, tmp);
                    recordState->bufferChanged = YES;
                }
            }

            holdingBuffer[0] = holdingBuffer[1];
            holdingBufferCount[0] = holdingBufferCount[1];
        }

        holdingBuffer[1] = chr;
        holdingBufferCount[1] = 1;
    }

    AudioQueueEnqueueBuffer(recordState->queue, inBuffer, 0, NULL);
}

@interface DTMFDecoder : NSObject {
    AudioStreamBasicDescription mAudioFormat;
    RecordState mRecordState;
    float mNoiseLevel;
    NSInteger mPowerMethod;
}

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (void)resetBuffer;
- (void)startRecording;
- (void)stopRecording;
- (NSString *)copyBuffer;

- (BOOL)isRecording;

@property(nonatomic, assign, getter=getBufferChanged) BOOL bufferChanged;
@property(nonatomic, assign, getter=getNoiseLevel) float noiseLevel;
@property(nonatomic, assign, getter=getPowerMethod) NSInteger powerMethod;

@end

@implementation DTMFDecoder

- (instancetype)init {
    self = [super init];
    if (self) {
        mRecordState.detectBuffer = (char *)calloc(1, DETECTBUFFERLEN);
        [self setNoiseLevel:0];
        [self setPowerMethod:0];
        [self resetBuffer];
    }
    return self;
}

- (void)startRecording {
    if (mRecordState.isRecording) {
        return;
    }

    for (int i = 0; i < 2; i++) {
        holdingBufferCount[i] = 0;
        holdingBuffer[i] = ' ';
    }

    AudioQueueBufferRef qref[NUM_BUFFERS];

    mAudioFormat.mSampleRate = SAMPLING_RATE;
    mAudioFormat.mFormatID = kAudioFormatLinearPCM;
    mAudioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    mAudioFormat.mFramesPerPacket = 1;
    mAudioFormat.mChannelsPerFrame = 1;
    mAudioFormat.mBitsPerChannel = 16;
    mAudioFormat.mBytesPerPacket = 2;
    mAudioFormat.mBytesPerFrame = 2;
    mAudioFormat.mReserved = 0;

    AVAudioFormat *avAudioFormat = [[AVAudioFormat alloc] initWithStreamDescription:&mAudioFormat];

    ATAudioTapDescription *audioTapDescription = nil;
    if ([ATAudioTapDescription instancesRespondToSelector:@selector(initTapInternalWithFormat:PIDs:)]) {
        audioTapDescription =
            [[ATAudioTapDescription alloc] initTapInternalWithFormat:avAudioFormat
                                                                PIDs:@[ @(kATAudioTapDescriptionPIDSpeaker) ]];
    } else {
        audioTapDescription =
            [[ATAudioTapDescription alloc] initProcessTapInternalWithFormat:avAudioFormat
                                                                        PID:kATAudioTapDescriptionPIDSpeaker];
    }

    mRecordState.audioTap = [[ATAudioTap alloc] initWithTapDescription:audioTapDescription];

    OSStatus status;
    status = AudioQueueNewInput(&mAudioFormat, AudioInputCallback,
                                &mRecordState, // User Data
                                CFRunLoopGetCurrent(), kCFRunLoopCommonModes,
                                0x800, // Reserved
                                &mRecordState.queue);

    if (status != noErr) {
        HBLogError(@"AudioQueueNewInput (%d)", status);
        return;
    }

    status = AudioQueueSetProperty(mRecordState.queue, kAudioQueueProperty_TapOutputBypass,
                                   (__bridge void *)mRecordState.audioTap, 8);

    if (status != noErr) {
        HBLogError(@"AudioQueueSetProperty (%d)", status);
        return;
    }

    // Get the *actual* recording format back from the queue's audio converter.
    // We may not have been given what we asked for.
    UInt32 fsize = sizeof(mAudioFormat);

    AudioQueueGetProperty(mRecordState.queue, kAudioQueueProperty_StreamDescription, &mAudioFormat, &fsize);

    if (mAudioFormat.mSampleRate != SAMPLING_RATE) {
        return;
    }

    for (int i = 0; i < NUM_BUFFERS; ++i) {
        // Allocate buffer. Size is in bytes.
        AudioQueueAllocateBuffer(mRecordState.queue, BUFFER_SIZE, &qref[i]);
        AudioQueueEnqueueBuffer(mRecordState.queue, qref[i], 0, NULL);
    }

    AudioQueueStart(mRecordState.queue, NULL);
    mRecordState.isRecording = YES;
}

- (void)resetBuffer {
    memset(mRecordState.detectBuffer, '\0', DETECTBUFFERLEN);
    mRecordState.bufferChanged = YES;
}

- (void)stopRecording {
    if (!mRecordState.isRecording) {
        return;
    }
    mRecordState.isRecording = NO;
    AudioQueueStop(mRecordState.queue, true);
    for (int i = 0; i < NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(mRecordState.queue, mRecordState.buffers[i]);
    }
    AudioQueueDispose(mRecordState.queue, true);
}

- (float)getNoiseLevel {
    return mNoiseLevel;
}

- (void)setNoiseLevel:(float)noiseLevel {
    if (noiseLevel <= 0 || noiseLevel > 1) {
        noiseLevel = 0.5;
    }
    mNoiseLevel = noiseLevel;
    noiseToleranceFactor = (double)(((1.0 - noiseLevel) * (kMaxNoiseToleranceFactor - kMinNoiseToleranceFactor)) +
                                    kMinNoiseToleranceFactor);
}

- (NSInteger)getPowerMethod {
    return mPowerMethod;
}

- (void)setPowerMethod:(NSInteger)powerMethod {
    if (powerMethod > 2 || powerMethod < 0) {
        powerMethod = 1;
    }
    mPowerMethod = powerMethod;
    powerMeasurementMethod = (int)powerMethod;
}

- (BOOL)getBufferChanged {
    return mRecordState.bufferChanged;
}

- (void)setBufferChanged:(BOOL)newData {
    mRecordState.bufferChanged = newData;
}

- (NSString *)copyBuffer {
    return @(mRecordState.detectBuffer);
}

- (BOOL)isRecording {
    return mRecordState.isRecording;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        static DTMFDecoder *gDecoder;
        gDecoder = [[DTMFDecoder alloc] init];
        [gDecoder startRecording];
        printf("DTMF > Press <Ctrl+C> to stop.\n");
        while ([gDecoder isRecording]) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1e-2, true);
            if ([gDecoder getBufferChanged]) {
                NSLog(@"%@", [gDecoder copyBuffer]);
                [gDecoder setBufferChanged:NO];
            }
        }
    }
    return EXIT_SUCCESS;
}
