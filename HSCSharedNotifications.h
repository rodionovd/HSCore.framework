//
//  HSCSharedNotifications.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/19/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const kHSCVolumeChangeNotificationName;
// Notification's userInfo will contain the following keys:
FOUNDATION_EXPORT NSString * const kHSKUserInfoBundleIDKey; // NSString*
FOUNDATION_EXPORT NSString * const kHSKUserInfoVolumeLevelKey; // NSNumber* wrapper for CGFloat
