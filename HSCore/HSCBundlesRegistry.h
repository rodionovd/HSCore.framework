//
//  HSCBundlesRegistry.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kHSCInvalidVolumeLevel (-1)

@interface HSCBundlesRegistry : NSObject

// supports items backup to User Defaults
+ (instancetype)defaultRegistry;

- (void)addBundle: (NSString *)bundleID;
- (void)addBundles: (NSArray *)bundleIDS;
- (void)removeBundle: (NSString *)bundleID;

- (BOOL)containsBundle: (NSString *)bundleID;
- (NSArray *)registeredBundles;

- (void)muteBundle: (NSString *)bundle;
- (void)unmuteBundle: (NSString *)bundle;
/// returns 0.0 if muted
- (CGFloat)volumeLevelForBundle: (NSString *)bundleID;
- (void)setVolumeLevel: (CGFloat)volume forBundleAtIndex: (NSUInteger)idx;
- (void)setVolumeLevel: (CGFloat)volume forBundle: (NSString *)bundleID;

@end
