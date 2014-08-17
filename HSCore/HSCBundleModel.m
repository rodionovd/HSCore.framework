//
//  HSCBundleModel.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 honeysound. All rights reserved.
//

#import "HSCBundleModel.h"

@interface HSCBundleModel()
@property (readwrite) NSString *bundleID;
@end

@implementation HSCBundleModel

+ (instancetype)modelForBundleID: (NSString *)bundleID
{
    return [[HSCBundleModel alloc] initWithBundleID: bundleID];
}

- (instancetype)initWithBundleID: (NSString *)bundleID
{
    if ((self = [super init])) {
        _bundleID = [bundleID copy];
        _volume = 1.0f;
    }

    return self;
}

#pragma mark - NSSecureCoding's

#define kBundleIDKey @"bundleID"
#define kVolumeLevelKey @"volumeLevel"

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder: (NSCoder *)decoder
{
    NSString *bundleID = [decoder decodeObjectOfClass: NSString.class forKey: kBundleIDKey];
    if (!bundleID) return nil;
    // We assume that CGFloat is double - and that is true on 64 bit.
    // (this framework is not supposed to be compiled in 32 bit mode anyway)
    CGFloat volumeLevel = [decoder decodeDoubleForKey: kVolumeLevelKey];
    self = [self initWithBundleID: bundleID];
    self.volume = volumeLevel;

    return self;
}

- (void)encodeWithCoder: (NSCoder *)encoder
{
    [encoder encodeObject: self.bundleID forKey: kBundleIDKey];
    [encoder encodeDouble: self.volume   forKey: kVolumeLevelKey];
}
@end
