//
//  HSCBundleModel.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCInternalBundleModel.h"

@interface HSCInternalBundleModel()
@property (readwrite) NSString *bundleID;
@end

@implementation HSCInternalBundleModel

+ (instancetype)modelForBundleID: (NSString *)bundleID
{
    return [[HSCInternalBundleModel alloc] initWithBundleID: bundleID];
}

- (instancetype)initWithBundleID: (NSString *)bundleID
{
    if ((self = [super init])) {
        _bundleID = [bundleID copy];
        _volume = 1.0f;
        _muted = NO;
    }

    return self;
}

#pragma mark - NSSecureCoding's

#define kBundleIDKey @"bundleID"
#define kVolumeLevelKey @"volumeLevel"
#define kMutedKey @"muted"

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
    BOOL muted = [decoder decodeBoolForKey: kMutedKey];
    self = [self initWithBundleID: bundleID];
    self.volume = volumeLevel;
    self.muted = muted;

    return self;
}

- (void)encodeWithCoder: (NSCoder *)encoder
{
    [encoder encodeObject: self.bundleID forKey: kBundleIDKey];
    [encoder encodeDouble: self.volume   forKey: kVolumeLevelKey];
    [encoder encodeBool:   self.muted    forKey: kMutedKey];
}
@end
