//
//  HSCVolumeMaster.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCVolumeMaster.h"
#import "HSCBundlesRegistry.h"
#import "HSCSharedNotifications.h"

#define kMaxVolumeLevel (1.0)
#define kMaxVolumeLevelDiffToSayTheyAreDifferent (0.05)
static char * const kHSCCallbacksQueueLabel = "com.HoneySound.HSCore.HSCVolumeMaster.callbacksQueue";

@interface HSCVolumeMaster()
@property (strong) HSCBundlesRegistry *registry;
@property (strong) dispatch_queue_t callbacksQueue;

- (void)_initializeBundle: (NSString *)bundleID
              volumeLevel: (CGFloat)volume
                 callback: (HSCVolumeChangeCallback)callback;

- (void)_publishVolumeLevel: (CGFloat)level forBundleID: (NSString *)bundleID;
- (void)_publishVolumeChangesForBundle: (NSString *)bundleID;

- (void)_injectBundle: (NSString *)bundleID callback: (HSCVolumeChangeCallback)callback;
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

        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                               selector: @selector(_someApplicationDidLaunch:)
                                                                   name: NSWorkspaceDidLaunchApplicationNotification
                                                                 object: nil];
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
    if (newLevel > kMaxVolumeLevel) {
        // Converting [0..100] range to [0..1]
        newLevel /= 100;
    }
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
    [self.registry setVolumeLevel: newLevel forBundle: bundleID];
    [self _publishVolumeChangesForBundle: bundleID];
    dispatch_async(self.callbacksQueue, ^{
        if (callback) callback(YES);
    });
}

- (void)increaseVolumeLevelForBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return;
    }
    // increased by 10%
    CGFloat newVolume = (1.1) * [self.registry volumeLevelForBundle: bundleID];
    if (newVolume > kMaxVolumeLevel) {
        newVolume = kMaxVolumeLevel;
    }
    [self.registry setVolumeLevel: newVolume forBundle: bundleID];
    [self _publishVolumeChangesForBundle: bundleID];
}

- (void)decreaseVolumeLevelForBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return;
    }
    // decreased by 10%
    CGFloat newVolume = (0.9) * [self.registry volumeLevelForBundle: bundleID];
    [self.registry setVolumeLevel: newVolume forBundle: bundleID];
    [self _publishVolumeChangesForBundle: bundleID];
}

- (void)muteBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return;
    }
    CGFloat mutedLevel = 0.0f;
    [self _publishVolumeLevel: mutedLevel forBundleID: bundleID];
}

- (void)unmuteBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return;
    }
    [self _publishVolumeChangesForBundle: bundleID];
}

- (CGFloat)volumeLevelForBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return 0.0;
    }
    return [self.registry volumeLevelForBundle: bundleID];
}

- (void)volumeLeveslForBundles: (NSString *)bundleID callback: (id)callback
{
    @throw [NSException exceptionWithName: @"Unimplemented method"
                                   reason: @"Method is not implemented yet"
                                 userInfo: nil];
}

- (void)setVolumeLevelsForBundles: (NSDictionary *)params callback: (id)callback
{
    @throw [NSException exceptionWithName: @"Unimplemented method"
                                   reason: @"Method is not implemented yet"
                                 userInfo: nil];
}

- (void)revertVolumeChangesForBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return;
    }
    CGFloat originalVolumeLevel = kMaxVolumeLevel;
    [self.registry setVolumeLevel: originalVolumeLevel forBundle: bundleID];
    // publish the changes
    [self _publishVolumeChangesForBundle: bundleID];
    // don't keep reference to this bundle anymore
    [self.registry removeBundle: bundleID];
}

- (void)revertVolumeChangesForBundles: (NSArray *)bundleIDs
{
    [bundleIDs enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        [self revertVolumeChangesForBundle: item];
    }];
}

- (void)revertAllVolumeChanges
{
    NSArray *allBundles = [self.registry registeredBundles];
    [self revertVolumeChangesForBundles: allBundles];
}


#pragma mark - Private implementation

- (void)_someApplicationDidLaunch: (NSNotification *)notification
{
    NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];
    NSLog(@"<%@> was launched and is in the registry", app.localizedName);
    NSString *bundleID = app.bundleIdentifier;
    if ([self.registry containsBundle: bundleID]) {
        // initial injection for this instance of the application
        [self _injectBundle: bundleID callback: ^(BOOL succeeded) {
            if (!succeeded) {
                NSLog(@"Unable to re-inject <%@>", bundleID);
            } else {
                [self _publishVolumeChangesForBundle: bundleID];
            }
        }];
    }
}

- (void)_initializeBundle: (NSString *)bundleID
              volumeLevel: (CGFloat)volume
                 callback: (HSCVolumeChangeCallback)callback
{
    [self.registry addBundle: bundleID];
    [self.registry setVolumeLevel: volume forBundle: bundleID];
    [self _injectBundle: bundleID callback: callback];
    [self _publishVolumeChangesForBundle: bundleID];
}

- (void)_publishVolumeLevel: (CGFloat)level forBundleID: (NSString *)bundleID
{
    NSDictionary *userInfo = @{kHSKUserInfoBundleIDKey : bundleID,
                            kHSKUserInfoVolumeLevelKey : @(level)};
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center postNotificationName: kHSCVolumeChangeNotificationName object: nil userInfo: userInfo];
}

- (void)_publishVolumeChangesForBundle:(NSString *)bundleID
{
    CGFloat volumeLevel = [self.registry volumeLevelForBundle: bundleID];
    [self _publishVolumeLevel: volumeLevel forBundleID: bundleID];
}

- (void)_injectBundle: (NSString *)bundleID
             callback: (HSCVolumeChangeCallback)callback
{
    dispatch_async(self.callbacksQueue, ^{
        if (callback) callback(NO);
    });
}

@end
