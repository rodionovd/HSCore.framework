//
//  HSCVolumeMaster+Browsers.h
//  HSCore
//
//  Created by Dmitry Rodionov on 9/2/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

@import Foundation;
#import <HSCore/HSCVolumeMaster.h>

@interface HSCVolumeMaster (Browsers)
/**
 * Swizzle the following selectors:
 *     -_publishVolumeChangesForBundle:
 */
@end

@interface NSRunningApplication (Browsers)
/**
 * Swizzle the following selectors:
 *     +runningApplicationsWithBundleIdentifier:
 */
@end

