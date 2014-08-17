//
//  HSCVolumeMaster.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 honeysound. All rights reserved.
//

#import "HSCVolumeMaster.h"
#import "HSCBundlesRegistry.h"


#define kMaxVolumeLevelDiffToSayTheyAreDifferent (0.05)
static char * const kHSCCallbacksQueueLabel = "com.HoneySound.HSCore.HSCVolumeMaster.callbacksQueue";

@interface HSCVolumeMaster()
@property (strong) HSCBundlesRegistry *registry;
@property (strong) dispatch_queue_t callbacksQueue;

- (void)_initializeBundle: (NSString *)bundleID
              volumeLevel: (CGFloat)volume
                 callback: (HSCVolumeChangeCallback)callback;

- (void)_publishVolumeChangeNotificationTargetingBundle: (NSString *)bundleID
                                            volumeLevel: (CGFloat)level;
@end

@implementation HSCVolumeMaster

+ (instancetype)sharedMaster
{
    static HSCVolumeMaster *master = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        master = [HSCVolumeMaster new];
    });

    return master;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _registry = [HSCBundlesRegistry defaultRegistry];
        _callbacksQueue = dispatch_queue_create(kHSCCallbacksQueueLabel, DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

#pragma mark - Public implementation

- (void)setVolumeLevel: (CGFloat)level
             forBundle: (NSString *)bundleID
              callback: (HSCVolumeChangeCallback)callback
{
    if (bundleID.length == 0) {
        dispatch_async(self.callbacksQueue, ^{
            if (callback) callback(NO);
        });
        return;
    }

    CGFloat oldLevel = [self.registry volumeLevelForBundle: bundleID];
    CGFloat newLevel = fabs(level);
    if (newLevel > 1.0) {
        // Converting [0..100] range to [0..1]
        newLevel /= 100;
    }

    // check if bundleID is in a registry
    if ([self.registry containsBundle: bundleID] == NO) {
        // perform initial inject
        [self _initializeBundle: bundleID volumeLevel: newLevel callback: callback];
        return;
    }

    // check if current sound level != new level
    if (fabs(oldLevel - newLevel) < kMaxVolumeLevelDiffToSayTheyAreDifferent) {
        dispatch_async(self.callbacksQueue, ^{
            if (callback) callback(YES);
        });
        return;
    }
    // do some things
    // ,,,,,,,,,,,,,,
    // ,,,,,,,,,,,,,,

    // update registry
    [self.registry setVolumeLevel: newLevel forBundle: bundleID];
    // publish change volume level notification

    // call the callback if any
    dispatch_async(self.callbacksQueue, ^{
        if (callback) callback(YES);
    });
}


#pragma mark - Private implementation

- (void)_initializeBundle: (NSString *)bundleID
              volumeLevel: (CGFloat)volume
                 callback: (HSCVolumeChangeCallback)callback
{
    // add bundle to the registry
    // perform payload injection
    // run callback
}

- (void)_publishVolumeChangeNotificationTargetingBundle: (NSString *)bundleID
                                            volumeLevel: (CGFloat)level
{

}

@end
