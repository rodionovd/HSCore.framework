//
//  AppModel.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/22/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "AppModel.h"

@implementation AppModel

+ (instancetype)modelWithURL: (NSURL *)applicationURL
{
    NSBundle *bundle = [NSBundle bundleWithURL: applicationURL];
    if (bundle.bundleIdentifier.length == 0) {
        return nil;
    }
    NSString *title = [bundle infoDictionary][@"CFBundleName"];
    if (title.length == 0) {
        title = @"Unknown";
    }
    return [[[self class] alloc] initWithBundleID: bundle.bundleIdentifier title: title];
}

- (instancetype)initWithBundleID: (NSString *)bundleID title: (NSString *)title
{
    if ((self = [super init])) {
        _bundleID = bundleID;
        _title = title;
        _volumeLevel = 100.0f;
    }

    return self;
}
@end
