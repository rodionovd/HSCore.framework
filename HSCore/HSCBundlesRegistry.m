//
//  HSCBundlesRegistry.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCBundlesRegistry.h"
#import "HSCBundleModel.h"

static char * const kHSCUserDefaultsQueueLabel = "com.HoneySound.HSCore.HSCBundlesRegistry.userDefaultsQueue";;
static NSString * const kHSCRegistryItemsKey = @"kHSCRegistryItemsKey";

@interface HSCBundlesRegistry()
@property (copy) NSMutableArray *items;
@property (strong) NSLock *itemsAccessLock;
@property (strong) dispatch_queue_t userDefaultsQueue;

- (NSUInteger)_indexOfModelWithBundleID: (NSString *)bundleID;
// User defaults
- (void)_loadRegistryItems;
- (void)_saveRegistryItems;
@end

@implementation HSCBundlesRegistry

+ (instancetype)defaultRegistry
{
    static HSCBundlesRegistry *defaultRegistry = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultRegistry = [HSCBundlesRegistry new];
        [defaultRegistry _loadRegistryItems];
    });

    return defaultRegistry;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _items = [NSMutableArray new];
        _itemsAccessLock = [NSLock new];
        _userDefaultsQueue = dispatch_queue_create(kHSCUserDefaultsQueueLabel, DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

#pragma mark - Public implementation

- (void)addBundle: (NSString *)bundleID
{
    [self.itemsAccessLock lock];
    NSUInteger idx = [self _indexOfModelWithBundleID: bundleID];
    if (idx != NSNotFound) {
        [self.itemsAccessLock unlock];
        return;
    }
    [(NSMutableArray *)self.items addObject: [HSCBundleModel modelForBundleID: bundleID]];
    [self.itemsAccessLock unlock];

    [self _saveRegistryItems];
}

- (void)addBundles: (NSArray *)bundleIDS
{
    [bundleIDS enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        [self addBundle: item];
    }];
}

- (void)removeBundle: (NSString *)bundleID
{
    [self.itemsAccessLock lock];
    NSUInteger idx = [self _indexOfModelWithBundleID: bundleID];
    if (idx == NSNotFound) {
        [self.itemsAccessLock unlock];
        return;
    }
    [(NSMutableArray *)self.items removeObjectAtIndex: idx];
    [self.itemsAccessLock unlock];

    [self _saveRegistryItems];
}

- (BOOL)containsBundle: (NSString *)bundleID
{
    [self.itemsAccessLock lock];
    NSUInteger idx = [self _indexOfModelWithBundleID: bundleID];
    [self.itemsAccessLock unlock];

    return (idx != NSNotFound);
}

- (NSArray *)registeredBundles
{
    [self.itemsAccessLock lock];
    NSUInteger count = self.items.count;
    if (count == 0) {
        [self.itemsAccessLock unlock];
        return @[];
    }
    NSMutableArray *result = [NSMutableArray arrayWithCapacity: count];
    [self.items enumerateObjectsUsingBlock: ^(HSCBundleModel *model, NSUInteger idx, BOOL *stop) {
        [result addObject: model.bundleID];
    }];
    [self.itemsAccessLock unlock];

    return [result copy];
}

- (HSCBundleModel *)modelForBundle: (NSString *)bundleID
{
    [self.itemsAccessLock lock];
    NSUInteger idx = [self _indexOfModelWithBundleID: bundleID];
    if (idx == NSNotFound) {
        [self.itemsAccessLock unlock];
        return nil;
    } else {
        HSCBundleModel *result = self.items[idx];
        [self.itemsAccessLock unlock];

        return result;
    }
}

- (CGFloat)volumeLevelForBundle: (NSString *)bundleID
{
    [self.itemsAccessLock lock];
    NSUInteger idx = [self _indexOfModelWithBundleID: bundleID];
    if (idx == NSNotFound) {
        [self.itemsAccessLock unlock];
        return kHSCInvalidVolumeLevel;
    } else {
        HSCBundleModel *model = self.items[idx];
        [self.itemsAccessLock unlock];
        return model.volume;
    }
}

- (void)setVolumeLevel: (CGFloat)volume forBundleAtIndex: (NSUInteger)idx
{
    [self.itemsAccessLock lock];
    if (self.items.count <= idx) {
        [self.itemsAccessLock unlock];
        return;
    }
    HSCBundleModel *bundle = [self.items objectAtIndex: idx];
    [self.itemsAccessLock unlock];
    [bundle setVolume: volume];

    [self _saveRegistryItems];
}

- (void)setVolumeLevel:(CGFloat)volume forBundle:(NSString *)bundleID
{
    [self.itemsAccessLock lock];
    NSUInteger idx = [self _indexOfModelWithBundleID: bundleID];
    if (idx == NSNotFound) {
        [self.itemsAccessLock unlock];
        return;
    }
    HSCBundleModel *bundle = [self.items objectAtIndex: idx];
    [self.itemsAccessLock unlock];
    [bundle setVolume: volume];

    [self _saveRegistryItems];
}

- (NSUInteger)_indexOfModelWithBundleID: (NSString *)bundleID
{
    NSUInteger idx = [self.items indexOfObjectPassingTest:
                      ^BOOL(HSCBundleModel *model, NSUInteger idx, BOOL *stop) {
                          return [model.bundleID isEqualToString: bundleID];
                      }];
    return idx;
}

#pragma mark - Private implementaion

- (void)_saveRegistryItems
{
    NSUInteger count = self.items.count;
    if (count == 0) {
        return;
    }
    [self.itemsAccessLock lock];
    NSArray *copiedItems = [self.items copy];
    [self.itemsAccessLock unlock];

    dispatch_sync(self.userDefaultsQueue, ^{
        NSMutableArray *list = [NSMutableArray arrayWithCapacity: count];
        [copiedItems enumerateObjectsUsingBlock: ^(HSCBundleModel *model, NSUInteger idx, BOOL *stop) {
            [list addObject: [NSKeyedArchiver archivedDataWithRootObject: model]];
        }];
        [[NSUserDefaults standardUserDefaults] setObject: list
                                                  forKey: kHSCRegistryItemsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (void)_loadRegistryItems
{
    NSArray *items = [[NSUserDefaults standardUserDefaults] objectForKey: kHSCRegistryItemsKey];
    if (items.count == 0) return;
    
    [self.itemsAccessLock lock];
    [items enumerateObjectsUsingBlock: ^(NSData *data, NSUInteger idx, BOOL *stop) {
        HSCBundleModel *model = [NSKeyedUnarchiver unarchiveObjectWithData: data];
        if (!model) return;
        [(NSMutableArray *)self.items addObject: model];
    }];
    [self.itemsAccessLock unlock];
}

@end
