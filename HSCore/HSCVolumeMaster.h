//
//  HSCVolumeMaster.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^HSCVolumeChangeCallback)(BOOL succeeded);

@interface HSCVolumeMaster : NSObject

+ (instancetype)sharedMaster;

- (void)setVolumeLevel: (CGFloat)level
             forBundle: (NSString *)bundleID
              callback: (HSCVolumeChangeCallback)callback;

// Increase volume level by 10%
- (void)increaseVolumeLevelForBundle: (NSString *)bundleID;
// Decrease volume level by 10%
- (void)decreaseVolumeLevelForBundle: (NSString *)bundleID;
// a shortcut for [-setVolumeLevel: 0.0f forBundle: bundleID callback: nil]
- (void)muteBundle: (NSString *)bundleID;
// restore a volume level before muting
- (void)unmuteBundle: (NSString *)bundleID;

// current volume level
// @iCyberon >> The applications that are not injected should return 100% or null;
- (CGFloat)volumeLevelForBundle: (NSString *)bundleID;
// current volume level
// @iCyberon >> The applications that are not injected should return 100% or null;
- (void)volumeLeveslForBundles: (NSString *)bundleID callback: (id)callback;

// params: {@"bundleID1" : @(0.3f), @"bundleID2" : @(0.7f), ...};
- (void)setVolumeLevelsForBundles: (NSDictionary *)params callback: (id)callback;
// remove injection from a single bundle
- (void)revertVolumeChangesForBundle: (NSString *)bundleID;
// remove specific injections
- (void)revertVolumeChangesForBundles: (NSArray *)bundleIDs;
// remove all the injection (useful when user quit HoneySound)
- (void)revertAllVolumeChanges;


@end
