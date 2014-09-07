//
//  HSCRunningApplication.h
//  HSCore
//
//  Created by Dmitry Rodionov on 9/7/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

@import Cocoa;
/**
 * Mutable subclass of NSRunningApplication.
 */
@interface HSCRunningApplication : NSRunningApplication

- (NSString *)bundleIdentifier;
- (pid_t)processIdentifier;

+ (instancetype)applicationWithProcessIdentifier: (pid_t)pid
                                       bundleIdentifer: (NSString *)bundleID;
@end
