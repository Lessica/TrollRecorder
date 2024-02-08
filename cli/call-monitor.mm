#import "CTCall.h"
#import "CTSetting.h"
#import "CTTelephonyCenter.h"
#import <Foundation/Foundation.h>

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
        return @"Incoming Call";
    case kCTCallStatusIncomingCallEnded:
        return @"Incoming Call Ended";
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

    NSLog(@"Telephony event name = %@", name);

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

int main(int argc, const char *argv[]) {

    @autoreleasepool {

        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, _TelephonyEventCallback,
                                     kCTCallStatusChangeNotification, NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);

        CTTelephonyCenterAddObserver(CTTelephonyCenterGetDefault(), NULL, _TelephonyEventCallback,
                                     kCTCallIdentificationChangeNotification, NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);

        CFRunLoopRun();
    }
    return 0;
}