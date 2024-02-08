/**
 * CoreTelephony notification support.
 *
 * Copyright (c) 2013-2014 Cykey (David Murray)
 * All rights reserved.
 */

#ifndef CTTELEPHONYCENTER_H_
#define CTTELEPHONYCENTER_H_

#include <CoreFoundation/CoreFoundation.h>

#if __cplusplus
extern "C" {
#endif

#pragma mark - API

    /* This API is a mimic of CFNotificationCenter. */

    CFNotificationCenterRef CTTelephonyCenterGetDefault();
    void CTTelephonyCenterAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack, CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior);
    void CTTelephonyCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFStringRef name, const void *object);
    void CTTelephonyCenterRemoveEveryObserver(CFNotificationCenterRef center, const void *observer);

#if __cplusplus
}
#endif

#endif /* CTTELEPHONYCENTER_H_ */