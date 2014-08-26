//
//  HSCVolumeMaster.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

@import Cocoa;

/**
 *
 * @param bundles the array of objects conformed to HSCBundleModelProtocol
 */
typedef void (^HSCVolumeLevelInfoForBundlesCallback)(NSArray *bundles);
typedef void (^HSCUpdateVolumeLevelInfoCallback)(BOOL succeeded,
                                                 NSArray *bundlesWeFailedToChangeVolumeLevelOf);


@interface HSCVolumeMaster : NSObject

+ (instancetype)sharedMaster;

- (void)setVolumeLevel: (CGFloat)level
             forBundle: (NSString *)bundleID
            completion: (void(^)(BOOL succeeded))handler;

// Increase volume level by 10%
- (void)increaseVolumeLevelForBundle: (NSString *)bundleID;
// Decrease volume level by 10%
- (void)decreaseVolumeLevelForBundle: (NSString *)bundleID;
// a shortcut for [-setVolumeLevel: 0.0f forBundle: bundleID callback: nil]
- (void)muteBundle: (NSString *)bundleID;
// restore a volume level before muting
- (void)unmuteBundle: (NSString *)bundleID;

// current volume level
- (CGFloat)volumeLevelForBundle: (NSString *)bundleID;

// @return dictionary with the following format: keys are bundleIDs and
// values are NSNumbers wrapped volumeLevels
- (NSDictionary *)volumeLevelsForBundles: (NSArray *)bundleIDs;

// params: {@"bundleID1" : @(0.3f), @"bundleID2" : @(0.7f), ...};
- (void)setVolumeLevelsForBundles: (NSDictionary *)bundlesInformation
                       completion: (void(^)(void))handler
                          failure: (void(^)(NSArray *failedBundles))failure;
// remove injection from a single bundle
- (void)revertVolumeChangesForBundle: (NSString *)bundleID;
// remove specific injections
- (void)revertVolumeChangesForBundles: (NSArray *)bundleIDs;
// remove all the injection (useful when user quit HoneySound)
- (void)revertAllVolumeChanges;

@end
