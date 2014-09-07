//
//  HSCVolumeMaster+Browsers.m
//  HSCore
//
//  Created by Dmitry Rodionov on 9/2/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import <libproc.h>
#import <objc/runtime.h>
#import "HSCRunningApplication.h"
#import "HSCVolumeMaster+Private.h"
#import "HSCVolumeMaster+Browsers.h"

#define kDelayTimeout (2)

@implementation HSCVolumeMaster (Browsers)

#pragma mark - Method swizzling

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /* Replace -setVolumeLevel:forBundle:completion: */
        Method original_setVolume =
            class_getInstanceMethod(self, @selector(setVolumeLevel:forBundle:completion:));
        Method hook_setVolume =
            class_getInstanceMethod(self, @selector(browsers_setVolumeLevel:forBundle:completion:));
        if (!original_setVolume || !hook_setVolume) {
            return;
        }
        method_exchangeImplementations(original_setVolume, hook_setVolume);

        /* Replace -_someApplicationDidLaunch: */
        Method original_didLaunch =
            class_getInstanceMethod(self,  @selector(_someApplicationDidLaunch:));
        Method hook_didLaunch =
            class_getInstanceMethod(self, @selector(browsers_someApplicationDidLaunch:));
        if (!original_didLaunch || !hook_didLaunch) {
            return;
        }
        method_exchangeImplementations(original_didLaunch, hook_didLaunch);
    });
}

- (void)browsers_setVolumeLevel: (CGFloat)level
                      forBundle: (NSString *)bundleID
                     completion: (void(^)(BOOL succeeded))handler
{
    CGFloat normalizedLevel = [self.class _normalizeVolumeLevel: level];
    if ([bundleID isEqualToString: @"com.apple.Safari"]) {
        [self setSafariVolumeLevel: level completion: handler];
        return;
    }
    if ([bundleID isEqualToString: @"com.google.Chrome"]) {
        [self setChromeVolumeLevel: normalizedLevel completion: handler];
        return;
    }
    /* Fallback to original method */
    [self browsers_setVolumeLevel: level
                        forBundle: bundleID
                       completion: handler];
}

- (void)browsers_someApplicationDidLaunch: (NSNotification *)notification
{
    NSRunningApplication *app = notification.userInfo[NSWorkspaceApplicationKey];
    NSString *bundleID = app.bundleIdentifier;
    if ([[self.class safariRelatedBundleIDs] containsObject: bundleID]) {
        /* Let the browser create its sub-processes */
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDelayTimeout * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            NSArray *targets = [self.class safariRelatedProcesses];
            [targets enumerateObjectsUsingBlock: ^(NSRunningApplication *item, NSUInteger idx, BOOL *stop) {
                NSNotification *fakeNotification =
                    [NSNotification notificationWithName: notification.name
                                                  object: notification.object
                                                userInfo: @{NSWorkspaceApplicationKey : item}];
                [self browsers_someApplicationDidLaunch: fakeNotification];
            }];
        });
    }

    [self browsers_someApplicationDidLaunch: notification];
}

#pragma mark - Hooks

- (void)setSafariVolumeLevel: (CGFloat)level completion:(void (^)(BOOL))handler
{
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT);

    NSMutableArray *failures = [NSMutableArray new];
    NSArray *bundles = [self.class safariRelatedBundleIDs];
    [bundles enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        dispatch_group_wait(group, (kDelayTimeout * NSEC_PER_SEC));
        dispatch_group_enter(group);
        dispatch_group_async(group, queue, ^{
            [self browsers_setVolumeLevel: level
                                forBundle: item
                               completion: ^(BOOL succeeded) {
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
                if (handler) handler(YES);
            } else {
                NSLog(@"Failures: %@", failures);
                if (handler) handler(NO);
            }
        });
    });

}

- (void)setChromeVolumeLevel: (CGFloat)level
                  completion: (void(^)(BOOL succeeded))handler
{
    NSLog(@"%@", [self.class chromeRelatedProcesses]);
}


#pragma mark - Private


/**
 * @abstract
 * List of processes that belong to Safari browser workflow;
 * @discuss
 * This list includes:
 * -- all instances of Web Content related to Safari;
 * -- all Safari plugins;
 * @return
 * An array of NSRunningApplication objects; it may be empty.
 */
+ (NSArray *)safariRelatedProcesses
{
    NSArray *targets = [self safariRelatedBundleIDs];
    NSPredicate *onlySafaryStuff = [NSPredicate predicateWithFormat:
                                    @"localizedName CONTAINS 'Safari'"];
    NSMutableArray *results = [NSMutableArray new];
    [targets enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier: item];
        [results addObjectsFromArray: [apps filteredArrayUsingPredicate: onlySafaryStuff]];
    }];

    return results;
}

+ (NSArray *)safariRelatedBundleIDs
{
    return @[@"com.apple.Safari", @"com.apple.WebKit.WebContent", @"com.apple.WebKit.PluginProcess"];
}

/**
 * @abstract
 * List of processes that belong to Chrome browser workflow;
 * @discuss
 * This list includes:
 * -- all instances of Chrome Helpers;
 * @return
 * An array of NSRunningApplication (HSCRunningApplication) objects; it may be empty.
 */
+ (NSArray *)chromeRelatedProcesses
{
    NSArray *targets = [self chromeRelatedBundleIDs];
    NSMutableArray *procs = [NSMutableArray new];
    /**
     * Since Chrome processes aren't registered with LaunchServices
     * we can't list them via NSRunningApplication API.
     * So fallback to iterating proc_listpids()'s list to find them out.
     */
    int procs_count = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    int size = sizeof(pid_t) * procs_count;
    pid_t *pid_list = malloc(size);
    int err = proc_listpids(PROC_ALL_PIDS, 0, pid_list, size);
    if (err <= 0) {
        return @[];
    }
    for (int i = 0; i < procs_count && (pid_list[i] != 0); ++i) {
        int buffer_size = sizeof(char) * PROC_PIDPATHINFO_MAXSIZE;
        char *buffer = malloc(buffer_size);
        err = proc_pidpath(pid_list[i], buffer, buffer_size);
        if (err <= 0 || strlen(buffer) == 0) {
            continue;
        }
        @autoreleasepool {
            NSString *str = [NSString stringWithUTF8String: buffer];
            NSUInteger idx = [str rangeOfString: @"Contents/MacOS"].location;
            if (idx == NSNotFound) {
                continue;
            }
            NSString *path = [str substringToIndex: idx];
            NSBundle *bundle = [NSBundle bundleWithPath: path];
            if ([targets containsObject: bundle.bundleIdentifier]) {
                HSCRunningApplication *app =
                [HSCRunningApplication applicationWithProcessIdentifier: pid_list[i]
                                                        bundleIdentifer: bundle.bundleIdentifier];
                [procs addObject: app];
            }

        }
    }
    return procs;
}
+ (NSArray *)chromeRelatedBundleIDs
{
    return @[@"org.chromium.pdf_plugin",
             @"com.macromedia.PepperFlashPlayer.pepper", @"com.google.Chrome.helper",
             @"com.google.Chrome.helper.EH", @"com.google.Chrome.helper.NP",];
}

@end
