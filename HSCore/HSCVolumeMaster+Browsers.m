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
#import "HSCSharedNotifications.h"
#import "HSCVolumeMaster+Private.h"
#import "HSCVolumeMaster+Browsers.h"

#define kDelayTimeout (2)
#define kSafariMainBundleID @"com.apple.Safari"
#define kChromeMainBundleID @"com.google.Chrome"

static NSArray* HSCSafariBundleIDs(void);
static NSArray* HSCChromeBundleIDs(void);
static NSArray* HSCSafariProcesses(void);
static NSArray* HSCChromeProcesses(void);

@implementation NSRunningApplication (Browsers)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /* Replace +runningApplicationsWithBundleIdentifier: */
        Method original_sel =
        class_getInstanceMethod(objc_getMetaClass(class_getName(self.class)),
                                @selector(runningApplicationsWithBundleIdentifier:));
        Method hook_sel =
        class_getClassMethod(objc_getMetaClass(class_getName(self.class)),
                             @selector(browsers_runningApplicationsWithBundleIdentifier:));
        if (!original_sel || !hook_sel) {
            return;
        }
        method_exchangeImplementations(original_sel, hook_sel);
    });
}

+ (NSArray *)browsers_runningApplicationsWithBundleIdentifier: (NSString *)bundleIdentifier
{
    NSLog(@"requested %@", bundleIdentifier);
    if ([bundleIdentifier isEqualToString: kSafariMainBundleID]) {
        return HSCSafariProcesses();
    }
    if ([bundleIdentifier isEqualToString: kChromeMainBundleID]) {
        NSAssert(NO, @"Google Chrome muting is not supported yet");
        return HSCChromeProcesses();
    }

    return [self browsers_runningApplicationsWithBundleIdentifier: bundleIdentifier];
}
@end

@implementation HSCVolumeMaster (Browsers)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /* Replace -_publishVolumeChangesForBundle: */
        Method original_publish =
            class_getInstanceMethod(self, @selector(_publishVolumeChangesForBundle:));
        Method hook_publish =
            class_getInstanceMethod(self, @selector(browsers_publishVolumeChangesForBundle:));
        if (!original_publish || !hook_publish) {
            return;
        }
        method_exchangeImplementations(original_publish, hook_publish);
    });
}

- (void)browsers_publishVolumeChangesForBundle: (NSString *)bundleIdentifer
{
    NSArray *targets = nil;
    CGFloat volumeLevel = 1.0f;
    if ([bundleIdentifer isEqualToString: kSafariMainBundleID]) {
        targets = HSCSafariBundleIDs();
        volumeLevel = [self.registry volumeLevelForBundle: kSafariMainBundleID];
    }
    if ([bundleIdentifer isEqualToString: kChromeMainBundleID]) {
        NSAssert(NO, @"Google Chrome muting is not supported yet");

        targets = HSCChromeBundleIDs();
        volumeLevel = [self.registry volumeLevelForBundle: kChromeMainBundleID];
    }
    if (!targets) {
        /* Fallback to original implemetation */
        [self browsers_publishVolumeChangesForBundle: bundleIdentifer];
        return;
    }
    [targets enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        NSDictionary *userInfo = @{kHSKUserInfoBundleIDKey : item,
                                   kHSKUserInfoVolumeLevelKey : @(volumeLevel)};
        NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
        [center postNotificationName: kHSCVolumeChangeNotificationName
                              object: nil
                            userInfo: userInfo];
    }];
}
@end

#pragma mark - Private 

//__attribute__((const))
static NSArray* HSCSafariBundleIDs(void)
{
    return @[@"com.apple.WebKit.WebContent", @"com.apple.WebKit.PluginProcess"];
}

//__attribute__((const))
static NSArray* HSCChromeBundleIDs(void)
{
    return @[@"org.chromium.pdf_plugin",
             @"com.macromedia.PepperFlashPlayer.pepper", @"com.google.Chrome.helper",
             @"com.google.Chrome.helper.EH", @"com.google.Chrome.helper.NP"];
}

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
static NSArray* HSCSafariProcesses(void)
{
    NSArray *targets = HSCSafariBundleIDs();
    NSPredicate *onlySafaryStuff = [NSPredicate predicateWithFormat:
                                    @"localizedName CONTAINS 'Safari'"];
    NSMutableArray *results = [NSMutableArray new];
    [targets enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        NSArray *apps = [NSRunningApplication browsers_runningApplicationsWithBundleIdentifier: item];
        [results addObjectsFromArray: [apps filteredArrayUsingPredicate: onlySafaryStuff]];
    }];

    return results;
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
static NSArray* HSCChromeProcesses(void)
{
    NSArray *targets = HSCChromeBundleIDs();
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
            free(buffer);
            NSUInteger idx = [str rangeOfString: @"Contents/MacOS"].location;
            if (idx != NSNotFound) {
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
    }
    return procs;
}

