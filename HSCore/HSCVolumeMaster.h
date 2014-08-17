//
//  HSCVolumeMaster.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 honeysound. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HSCVolumeMaster : NSObject

- (void)setVolumeLevel: (CGFloat)level forBundle: (NSString *)bundleID callback: (id)callback;
// Increase volume level by 10%
- (void)increaseVolumeLevelForBundle: (NSString *)bundleID;
// Decrease volume level by 10%
- (void)decreaseVolumeLevelForBundle: (NSString *)bundleID;
// a shortcut for [-setVolumeLevel: 0.0f forBundle: bundleID callback: nil]
- (void)muteBundle: (NSString *)bundleID;
// restore a volume level before muting
- (void)unmuteBundle: (NSString *)bundleID;
// remove injection
- (void)restoreVolumeLevelForBundle: (NSString *)bundleID;
// current volume level
// @iCyberon >> The applications that are not injected should return 100% or null;
- (CGFloat)getVolumeLevelForBundle: (NSString *)bundleID;

// params: {@"bundleID1" : @(0.3f), @"bundleID2" : @(0.7f), ...};
- (void)setVolumeLevelsForBundles: (NSDictionary *)params callback: (id)callback;
// remove all the injection (useful when user quit HoneySound)
- (void)restoreVolumeLevelForBundles: (NSString *)bundleID;
// or — not sure about this
- (void)revertInjection;
// current volume level
// @iCyberon >> The applications that are not injected should return 100% or null;
- (void)getVolumeLeveslForBundles: (NSString *)bundleID callback: (id)callback;

@end
