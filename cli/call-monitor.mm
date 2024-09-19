//
//  call-monitor.mm
//  TrollRecorder
//
//  Created by Lessica on 2024/2/10.
//

#import "CTCall.h"
#import "CTSetting.h"
#import "CTTelephonyCenter.h"
#import <CallKit/CXCall.h>
#import <CallKit/CXCallController.h>
#import <CallKit/CXCallObserver.h>

static NSString *_CTCallStatusStringRepresentation(CTCallStatus status) {
    switch (status) {
    case kCTCallStatusUnknown:
        return @"Unknown";
    case kCTCallStatusAnswered:
        return @"Answered";
    case kCTCallStatusDroppedInterrupted:
        return @"Dropped Interrupted";
    case kCTCallStatusOutgoingInitiated:
        return @"Outgoing Initiated";
    case kCTCallStatusIncomingCall:
        return @"Incoming";
    case kCTCallStatusIncomingCallEnded:
        return @"Incoming Ended";
    default:
        return @"Unknown";
    }
}

static NSString *_CTCallTypeStringRepresentation(CTCallType type) {
    if (CFStringCompare(type, kCTCallTypeNormal, 0) == kCFCompareEqualTo)
        return @"Normal";
    else if (CFStringCompare(type, kCTCallTypeVOIP, 0) == kCFCompareEqualTo)
        return @"VOIP";
    else if (CFStringCompare(type, kCTCallTypeVideoConference, 0) == kCFCompareEqualTo)
        return @"Video Conference";
    else if (CFStringCompare(type, kCTCallTypeVoicemail, 0) == kCFCompareEqualTo)
        return @"Voicemail";
    else
        return @"Unknown";
}

static void _TelephonyEventCallback(CFNotificationCenterRef center, void *observer, CFStringRef name,
                                    const void *object, CFDictionaryRef userInfo) {

    NSLog(@"CoreTelephony event name = %@", name);

    if (CFStringCompare(name, kCTCallIdentificationChangeNotification, 0) == kCFCompareEqualTo ||
        CFStringCompare(name, kCTCallStatusChangeNotification, 0) == kCFCompareEqualTo) {

        CTCallRef call = (CTCallRef)object;

        BOOL callIsTheOnlyCall = [[(__bridge NSDictionary *)userInfo objectForKey:@"kCTCallIsTheOnlyCall"] boolValue];
        int callCount = CTGetCurrentCallCount();

        CTCallStatus callStatus =
            (CTCallStatus)[[(__bridge NSDictionary *)userInfo objectForKey:@"kCTCallStatus"] integerValue];
        CTCallType callType = CTCallGetCallType(call);

        CFStringRef callAddress = CTCallCopyAddress(kCFAllocatorDefault, call);
        CFStringRef callName = CTCallCopyName(kCFAllocatorDefault, call);
        CFStringRef callCountryCode = CTCallCopyCountryCode(kCFAllocatorDefault, call);
        CFStringRef callNetworkCode = CTCallCopyNetworkCode(kCFAllocatorDefault, call);
        CFStringRef callUniqueStringID = CTCallCopyUniqueStringID(kCFAllocatorDefault, call);

        NSLog(@"  Count = %d", callCount);
        NSLog(@"  IsTheOnlyCall = %@", callIsTheOnlyCall ? @"YES" : @"NO");

        NSLog(@"  Status = %@", _CTCallStatusStringRepresentation(callStatus));
        NSLog(@"  Type = %@", _CTCallTypeStringRepresentation(callType));

        NSLog(@"  Name = %@", callName);
        NSLog(@"  Address = %@", callAddress);
        NSLog(@"  CountryCode = %@", callCountryCode);
        NSLog(@"  NetworkCode = %@", callNetworkCode);
        NSLog(@"  UniqueStringID = %@", callUniqueStringID);

        if (callAddress)
            CFRelease(callAddress);

        if (callName)
            CFRelease(callName);

        if (callCountryCode)
            CFRelease(callCountryCode);

        if (callNetworkCode)
            CFRelease(callNetworkCode);

        if (callUniqueStringID)
            CFRelease(callUniqueStringID);

    } else {
        NSLog(@"  object = %@", object);
        NSLog(@"  userInfo = %@", userInfo);
    }
}

static NSString *_CXCallStatusStringRepresentation(CXCall *call) {
    if (!call.outgoing && !call.onHold && !call.hasConnected && !call.hasEnded) {
        return @"Incoming";
    } else if (!call.outgoing && !call.onHold && !call.hasConnected && call.hasEnded) {
        return @"Incoming Terminated";
    } else if (!call.outgoing && !call.onHold && call.hasConnected && !call.hasEnded) {
        return @"Incoming Answered";
    } else if (!call.outgoing && !call.onHold && call.hasConnected && call.hasEnded) {
        return @"Incoming Ended";
    } else if (call.outgoing && !call.onHold && !call.hasConnected && !call.hasEnded) {
        return @"Outgoing Initiated";
    } else if (call.outgoing && !call.onHold && !call.hasConnected && call.hasEnded) {
        return @"Outgoing Terminated";
    } else if (call.outgoing && !call.onHold && call.hasConnected && !call.hasEnded) {
        return @"Outgoing Answered";
    } else if (call.outgoing && !call.onHold && call.hasConnected && call.hasEnded) {
        return @"Outgoing Ended";
    }
    return @"Unknown";
}

@interface CXCallController (Private)
- (void)setCallObserver:(CXCallObserver *)arg1;
@end

@interface CallMonitorCallObserverDelegate : NSObject <CXCallObserverDelegate>
@end

@implementation CallMonitorCallObserverDelegate

- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call {
    NSLog(@"CallKit call changed");

    NSLog(@"  Count = %lu", callObserver.calls.count);
    NSLog(@"  IsTheOnlyCall = %@", callObserver.calls.count <= 1 ? @"YES" : @"NO");

    NSLog(@"  Status = %@", _CXCallStatusStringRepresentation(call));
    NSLog(@"  Type = %@", @"CallKit");

    NSLog(@"  UniqueStringID = %@", call.UUID.UUIDString);
}

@end

int main(int argc, const char *argv[]) {

    @autoreleasepool {

        /* Register for CoreTelephony notifications */
        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, _TelephonyEventCallback,
                                     kCTCallStatusChangeNotification, NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);

        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, _TelephonyEventCallback,
                                     kCTCallIdentificationChangeNotification, NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);

        /* Register for CallKit notifications */
        static CXCallController *mCallController = [[CXCallController alloc] initWithQueue:dispatch_get_main_queue()];
        static CallMonitorCallObserverDelegate *mCallObserverDelegate = [CallMonitorCallObserverDelegate new];
        [mCallController.callObserver setDelegate:mCallObserverDelegate queue:dispatch_get_main_queue()];

        CFRunLoopRun();
    }
    return 0;
}