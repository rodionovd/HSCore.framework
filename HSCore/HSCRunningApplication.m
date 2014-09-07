//
//  HSCRunningApplication.m
//  HSCore
//
//  Created by Dmitry Rodionov on 9/7/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCRunningApplication.h"

@interface HSCRunningApplication()
{
    NSString *_customBundleID;
    pid_t _customPID;
}

- (instancetype)initWithProcessIdentifier: (pid_t)pid
                          bundleIdentifer: (NSString *)bundleID;

@end

@implementation HSCRunningApplication

- (NSString *)bundleIdentifier
{
    return _customBundleID;
}
- (pid_t)processIdentifier
{
    return _customPID;
}

+ (instancetype)applicationWithProcessIdentifier: (pid_t)pid
                                       bundleIdentifer: (NSString *)bundleID
{
    HSCRunningApplication *application = [[HSCRunningApplication alloc]
                                          initWithProcessIdentifier: pid
                                          bundleIdentifer: bundleID];
    return application;
}

- (instancetype)initWithProcessIdentifier:(pid_t)pid bundleIdentifer:(NSString *)bundleID
{
    if ((self = [super init])) {
        _customPID = pid;
        _customBundleID = bundleID;
    }

    return self;
}
@end
