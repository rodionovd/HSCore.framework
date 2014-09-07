//
//  HSCVolumeMaster.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCVolumeMaster.h"
#import "HSCVolumeMaster+Private.h"
#import "HSCVolumeMaster+Browsers.h"
#import "HSCBundlesRegistry.h"
#import "HSCSharedNotifications.h"
#import <RDInjectionWizard/RDInjectionWizard.h>

#define kMaxVolumeLevel (1.0)
#define kDelayBeforeLazyInjection (3)
static char * const kHSCCallbacksQueueLabel = "com.HoneySound.HSCore.HSCVolumeMaster.callbacksQueue";
static NSString * const kHSCRegistryItemsKey = @"kHSCRegistryItemsKey";

@interface HSCVolumeMaster()
@property (strong) HSCBundlesRegistry *registry;
@property (strong) NSLock *registryTestLock;
@property (strong) dispatch_queue_t callbacksQueue;
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
        _registryTestLock = [NSLock new];
        _registry = [HSCBundlesRegistry defaultRegistry];
        _callbacksQueue = dispatch_queue_create(kHSCCallbacksQueueLabel, DISPATCH_QUEUE_CONCURRENT);
        NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
        [center addObserver: self
                   selector: @selector(_someApplicationDidLaunch:)
                       name: NSWorkspaceDidLaunchApplicationNotification
                     object: nil];
    }
    return self;
}

#pragma mark - Public implementation

- (void)setVolumeLevel: (CGFloat)level
             forBundle: (NSString *)bundleID
            completion: (void(^)(BOOL succeeded))handler
{
    if (bundleID.length == 0) {
        dispatch_async(self.callbacksQueue, ^{
            if (handler) handler(NO);
        });
        return;
    }

    CGFloat newLevel = [self.class _normalizeVolumeLevel: level];
    BOOL just_registered = [self _registerBundleIfNeeded: bundleID
                                         withVolumeLevel: newLevel];
    if (just_registered) {
        [self _initializeBundle: bundleID
                    volumeLevel: newLevel
                     completion: handler];
        return;
    }
    [self _publishVolumeChangesForBundle: bundleID];
    dispatch_async(self.callbacksQueue, ^{
        if (handler) handler(YES);
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
    [self.registry muteBundle: bundleID];
    [self _publishVolumeChangesForBundle: bundleID];
}

- (void)unmuteBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return;
    }
    [self.registry unmuteBundle: bundleID];
    [self _publishVolumeChangesForBundle: bundleID];
}

- (CGFloat)volumeLevelForBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return kMaxVolumeLevel;
    }
    return [self.registry volumeLevelForBundle: bundleID];
}

- (NSDictionary *)volumeLevelsForBundles: (NSArray *)bundleIDs
{
    NSUInteger count = bundleIDs.count;
    if (count == 0) {
        NSString *exceptionName = [NSString stringWithFormat: @"<%@>:<%@> Exception",
                                   self.className,  NSStringFromSelector(_cmd)];
        @throw [NSException exceptionWithName: exceptionName
                                       reason: @"Parameter `bundleIDs` should be neither nil nor empty"
                                     userInfo: nil];
        return nil;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity: count];
    [bundleIDs enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        if ([self.registry containsBundle: item]) {
            [result setObject: @([self.registry volumeLevelForBundle: item])
                       forKey: item];
        }
    }];

    return [result copy];
}

- (void)setVolumeLevelsForBundles: (NSDictionary *)bundlesInformation
                       completion: (void(^)(void))handler
                          failure: (void(^)(NSArray *failedBundles))failure
{
    NSUInteger count = bundlesInformation.count;
    if (count == 0) {
        NSString *exceptionName = [NSString stringWithFormat: @"<%@>:<%@> Exception",
                                   self.className,  NSStringFromSelector(_cmd)];
        @throw [NSException exceptionWithName: exceptionName
                                       reason: @"Parameter `bundlesInformation` should be neither nil nor empty"
                                     userInfo: nil];
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT);

    NSMutableArray *failures = [NSMutableArray arrayWithCapacity: count];
    NSArray *bundles = bundlesInformation.allKeys;
    [bundles enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        dispatch_group_wait(group, (kDelayBeforeLazyInjection * NSEC_PER_SEC));
        dispatch_group_enter(group);
        dispatch_group_async(group, queue, ^{
            [self setVolumeLevel: [bundlesInformation[item] doubleValue] forBundle: item completion: ^(BOOL succeeded) {
                if (!succeeded) {
                    [failures addObject: item];
                }
                dispatch_group_leave(group);
            }];
        });
    }];
    dispatch_group_notify(group, queue, ^{
        dispatch_async(self.callbacksQueue, ^{
            if (failures.count == 0) {
                if (handler) handler();
            } else {
                if (failure) failure(failures);
            }
        });
    });
}

- (void)revertVolumeChangesForBundle: (NSString *)bundleID
{
    if (NO == [self.registry containsBundle: bundleID]) {
        return;
    }
    CGFloat originalVolumeLevel = kMaxVolumeLevel;
    [self.registry setVolumeLevel: originalVolumeLevel forBundle: bundleID];
    [self _publishVolumeChangesForBundle: bundleID];
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
    [allBundles enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        if (NO == [self.registry containsBundle: item]) {
            return;
        }
        CGFloat originalVolumeLevel = kMaxVolumeLevel;
        [self.registry setVolumeLevel: originalVolumeLevel forBundle: item];
        [self _publishVolumeChangesForBundle: item];
        [self.registry removeBundle: item];
    }];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: kHSCRegistryItemsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Private implementation

- (BOOL)_registerBundleIfNeeded: (NSString *)bundleID withVolumeLevel: (CGFloat)level
{
    BOOL just_registered = NO;
    if ([self.registry containsBundle: bundleID] == NO) {
        [self.registry addBundle: bundleID];
        just_registered = YES;
    }
    [self.registry setVolumeLevel: level forBundle: bundleID];

    return just_registered;
}

/** Convert [0..100] range to [0..1] */
+ (CGFloat)_normalizeVolumeLevel: (CGFloat)level
{
    CGFloat newLevel = fabs(level);
    if (newLevel > kMaxVolumeLevel) {
        newLevel /= 100;
    }
    return newLevel;
}

- (void)_someApplicationDidLaunch: (NSNotification *)notification
{
    NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];
    NSString *bundleID = app.bundleIdentifier;
    if ([self.registry containsBundle: bundleID] == NO) {
        return;
    }
    int delay_sec = 0;
    if ([self.registry volumeLevelForBundle: bundleID] == 1.0) {
        // we don't need this target to be injected right now, so do it lazily
        delay_sec = kDelayBeforeLazyInjection;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay_sec * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   ^{
                       // initial injection for this instance of the application
                       [self _injectBundle: bundleID completion: ^(BOOL succeeded) {
                           if (!succeeded) {
                               NSLog(@"Unable to re-inject <%@>", bundleID);
                           } else {
                               [self _publishVolumeChangesForBundle: bundleID];
                           }
                       }];
                   });
}

- (void)_initializeBundle: (NSString *)bundleID
              volumeLevel: (CGFloat)volume
               completion: (void(^)(BOOL succeeded))handler;
{
    [self _injectBundle: bundleID completion: ^(BOOL succeeded) {
        if (succeeded) {
            [self.registry setVolumeLevel: volume forBundle: bundleID];
            [self _publishVolumeChangesForBundle: bundleID];
        } else {
            NSLog(@"Unable to inject into %@. See logs above", bundleID);
        }
        if (handler) handler(succeeded);
    }];

}

- (void)_publishVolumeChangesForBundle:(NSString *)bundleID
{
    CGFloat volumeLevel = [self.registry volumeLevelForBundle: bundleID];
    NSDictionary *userInfo = @{kHSKUserInfoBundleIDKey : bundleID,
                               kHSKUserInfoVolumeLevelKey : @(volumeLevel)};
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center postNotificationName: kHSCVolumeChangeNotificationName
                          object: nil
                        userInfo: userInfo];
}

#pragma mark - Code injection

- (void)_injectBundle: (NSString *)bundleID
           completion: (void(^)(BOOL succeeded))handler
{
    NSArray *instances = [NSRunningApplication runningApplicationsWithBundleIdentifier: bundleID];
    if (instances.count == 0) {
        dispatch_async(self.callbacksQueue, ^{
            // pending injection
            if (handler) handler(YES);
        });
        return;
    }
    [self _injectProcesses: instances
                completion: handler];
}

- (void)_injectProcesses: (NSArray *)processes
              completion: (void(^)(BOOL succeeded))handler
{
    assert(processes.count > 0);

    NSString *payload = [[NSBundle bundleForClass: self.class] pathForResource: @"HSCUnicornsPayload"
                                                                        ofType: @"dylib"];
    if (payload.length == 0) {
        @throw [NSException exceptionWithName: @"Fuck this" reason: @"Where's my payload?" userInfo: nil];
        return;
    }

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    __block int failures = 0;
    [processes enumerateObjectsUsingBlock: ^(NSRunningApplication *item, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        dispatch_group_async(group, queue, ^{
            pid_t target = [item processIdentifier];
            RDInjectionWizard *wizard = [[RDInjectionWizard alloc] initWithTarget: target
                                                                          payload: payload];
            [wizard injectUsingCompletionBlockWithSuccess: ^{
                dispatch_group_leave(group);
            } failure: ^(RDInjectionError error) {
                ++failures;
                NSLog(@"Error: {PID: %d}, error: %d", target, error);
                dispatch_group_leave(group);
            }];
        });
    }];

    dispatch_group_notify(group, queue, ^{
        dispatch_async(self.callbacksQueue, ^{
            if (handler) handler(failures == 0);
        });
    });
}

@end
