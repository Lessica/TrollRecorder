/**
 * CoreTelephony calling support.
 *
 * Copyright (c) 2013, Cykey (David Murray)
 * All rights reserved.
 */

#ifndef CTCALL_H_
#define CTCALL_H_

#include <CoreFoundation/CoreFoundation.h>

#if __cplusplus
extern "C" {
#endif

#pragma mark - Definitions

    /*
     * Opaque structure definition.
     */

    typedef struct __CTCall *CTCallRef;

    typedef enum {
        kCTCallStatusUnknown = 0,
        kCTCallStatusAnswered,
        kCTCallStatusDroppedInterrupted,
        kCTCallStatusOutgoingInitiated,
        kCTCallStatusIncomingCall,
        kCTCallStatusIncomingCallEnded
    } CTCallStatus;

    typedef CFStringRef CTCallType;

    extern CTCallType kCTCallTypeNormal;
    extern CTCallType kCTCallTypeVOIP;
    extern CTCallType kCTCallTypeVideoConference;
    extern CTCallType kCTCallTypeVoicemail;

    /* For use with the CoreTelephony notification system. */

    extern CFStringRef kCTCallStatusChangeNotification;
    extern CFStringRef kCTCallIdentificationChangeNotification;

#pragma mark - API

    CFArrayRef CTCopyCurrentCalls(CFAllocatorRef allocator);

    /* The 'types' argument is an array of CTCallTypes. */
    CFArrayRef CTCopyCurrentCallsWithTypes(CFAllocatorRef allocator, CFArrayRef types);

    int CTGetCurrentCallCount();

    CFStringRef CTCallCopyAddress(CFAllocatorRef allocator, CTCallRef call);
    CFStringRef CTCallCopyName(CFAllocatorRef allocator, CTCallRef call);
    CFStringRef CTCallCopyCountryCode(CFAllocatorRef allocator, CTCallRef call);
    CFStringRef CTCallCopyNetworkCode(CFAllocatorRef allocator, CTCallRef call);

    CFStringRef CTCallCopyUniqueStringID(CFAllocatorRef allocator, CTCallRef call);

    BOOL CTCallGetStartTime(CTCallRef, double *);
    BOOL CTCallGetDuration(CTCallRef, double *);

    CTCallStatus CTCallGetStatus(CTCallRef call);
    CTCallType CTCallGetCallType(CTCallRef call);

    /* Pass NULL to delete all calls. */
    void CTCallDeleteAllCallsBeforeDate(CFDateRef date);
    void CTCallHistoryInvalidateCaches();

    void CTCallTimersReset();

    void CTCallAnswer(CTCallRef call);
    void CTCallHold(CTCallRef call);
    void CTCallResume(CTCallRef call);
    void CTCallDisconnect(CTCallRef call);

    void CTCallListDisconnectAll();

    Boolean CTCallIsConferenced(CTCallRef call);
    Boolean CTCallIsAlerting(CTCallRef call);
    Boolean CTCallIsToVoicemail(CTCallRef call);
    Boolean CTCallIsOutgoing(CTCallRef call);

    void CTCallJoinConference(CTCallRef call);
    void CTCallLeaveConference(CTCallRef call);

    /*
     * The phone number passed in the dial functions must be normalized.
     * E.g. +1 (555) 555-5555 would become 15555555555.
     * One can use CPPhoneNumberCopyNormalized from AppSupport.framework to normalize phone numbers.
     */

    CTCallRef CTCallDial(CFStringRef number);
    CTCallRef CTCallDialEmergency(CFStringRef number);

    /* Returns the call history. */
    CFArrayRef _CTCallCopyAllCalls();

#if __cplusplus
}
#endif

#endif /* CTCALL_H_ */