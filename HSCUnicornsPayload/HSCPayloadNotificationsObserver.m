//
//  HSCPayloadVolumeController.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/21/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//
#import "HSCSharedNotifications.h"
#import "HSCPayloadNotificationsObserver.h"

@interface HSCPayloadNotificationsObserver()
@end

@implementation HSCPayloadNotificationsObserver

+ (instancetype)observer
{
    static id observer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        observer = [[self class] new];
    });

    return observer;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _volumeLevel = 1.0f;
        NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
        [center addObserver: self
                   selector: @selector(volumeDidChange:)
                       name: kHSCVolumeChangeNotificationName
                     object: nil
         suspensionBehavior: NSNotificationSuspensionBehaviorDeliverImmediately];
    }

    return self;
}

- (void)dealloc
{
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center removeObserver: self];
}

#pragma mark - Distributed notifications

- (void)volumeDidChange: (NSNotification *)notification
{
    static NSString *hostBundleID = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hostBundleID = [[NSBundle mainBundle] bundleIdentifier];
    });

    NSString *target = notification.userInfo[kHSKUserInfoBundleIDKey];
    if ([target isEqualToString: hostBundleID]) {
        CGFloat newVolumeLevel = [notification.userInfo[kHSKUserInfoVolumeLevelKey] doubleValue];
        _volumeLevel = newVolumeLevel;
    }
}

@end
