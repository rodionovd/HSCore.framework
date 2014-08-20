//
//  HSCBundlesRegistryTests.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "HSCBundlesRegistry+HSC_CleanUp.h"
#import "HSCBundlesRegistry.h"
#import "HSCInternalBundleModel.h"

@interface HSCBundlesRegistry (LoadItems)
- (void)_loadRegistryItems;
@end

@interface HSCBundlesRegistryTests : XCTestCase
@property (strong) HSCBundlesRegistry *registry;
@end

@implementation HSCBundlesRegistryTests

- (void)setUp
{
    self.registry = [HSCBundlesRegistry defaultRegistry];
    [super setUp];
}

- (void)tearDown
{
    [self.registry _cleanupItems];
    [self.registry _cleanupDefaults];
    [NSThread sleepForTimeInterval: 0.5f];
    [super tearDown];
}

- (void)testAddingOneItemToRegistry
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    NSCountedSet *setOriginal = [NSCountedSet setWithObject: bundleIDs[0]];
    NSCountedSet *setResult = nil;
    // when
    [self.registry addBundle: bundleIDs[0]];
    setResult = [NSCountedSet setWithArray: [self.registry registeredBundles]];
    //then
    XCTAssert([self.registry registeredBundles].count == 1);
    XCTAssertEqualObjects(setResult, setOriginal);
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[0]], 1.0f);
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[1]], kHSCInvalidVolumeLevel);
}

- (void)testAddingItemsFromArrayToRegistry
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    NSCountedSet *setOriginal = [NSCountedSet setWithArray: bundleIDs];
    NSCountedSet *setResult = nil;
    // when
    [self.registry addBundles: bundleIDs];
    setResult = [NSCountedSet setWithArray: [self.registry registeredBundles]];
    //then
    XCTAssertEqual([self.registry registeredBundles].count, 2);
    XCTAssertEqualObjects(setResult, setOriginal);
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[0]], 1.0f);
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[1]], 1.0f);
}

- (void)testRemovingItemFromRegistry
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    // when
    [self.registry addBundles: bundleIDs];
    [self.registry removeBundle: bundleIDs[0]];
    // then
    XCTAssert([self.registry registeredBundles].count == 1);
    XCTAssertEqualObjects([self.registry registeredBundles][0], bundleIDs[1],
                          @"Second bundleID should be the first and only one");
}

- (void)testRegistryContainsItem
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    // when
    [self.registry addBundles: bundleIDs];
    // then
    XCTAssertEqual([self.registry containsBundle: bundleIDs[1]], YES);
}

- (void)testRegisteredBundlesList
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    NSCountedSet *setOriginal = [NSCountedSet setWithArray: bundleIDs];
    NSCountedSet *setResult = nil;
    // when
    [self.registry addBundles: bundleIDs];
    setResult = [NSCountedSet setWithArray: [self.registry registeredBundles]];
    // then
    XCTAssertEqualObjects(setResult, setOriginal);
}

- (void)testGettingInitialVolumeLevelForModelFromRegistry
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    // when
    [self.registry addBundles: bundleIDs];
    // then
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[0]], 1.0f);
}

- (void)testGettingCustomVolumeLevelForModelFromRegistry
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    CGFloat testVolumeLevel = 0.42f;
    // when
    [self.registry addBundles: bundleIDs];
    [self.registry setVolumeLevel: testVolumeLevel forBundle: bundleIDs[1]];
    // then
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[0]], 1.0f);
}

- (void)testMutingModelFromRegistry
{
    // given
    NSString *bundle = @"first.bundle.id";
    // when
    [self.registry addBundle: bundle];
    [self.registry muteBundle: bundle];
    // then
    XCTAssertEqual([self.registry volumeLevelForBundle: bundle], 0.0);
}

- (void)testUnmutingModelFromRegistry
{
    // given
    NSString *bundle = @"first.bundle.id";
    CGFloat testVolumeLevel = 0.42f;
    // when
    [self.registry addBundle: bundle];
    [self.registry setVolumeLevel: testVolumeLevel forBundle: bundle];
    [self.registry muteBundle: bundle];
    [self.registry unmuteBundle: bundle];
    // then
    XCTAssertEqual([self.registry volumeLevelForBundle: bundle], testVolumeLevel);
}

- (void)testChangingVolumeLevelWhileModelIsMuted
{
    // given
    NSString *bundle = @"first.bundle.id";
    CGFloat testVolumeLevel = 0.42f;
    // when
    [self.registry addBundle: bundle];
    [self.registry muteBundle: bundle];
    [self.registry setVolumeLevel: testVolumeLevel forBundle: bundle];
    // then
    XCTAssertEqual([self.registry volumeLevelForBundle: bundle], testVolumeLevel);
}

- (void)testSettingVolumeLevelForItemFromRegistryViaBundleID
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    CGFloat testVolumeLevelFirst  = 0.42f;
    CGFloat testVolumeLevelSecond = 0.84f;
    // when
    [self.registry addBundles: bundleIDs];
    [self.registry setVolumeLevel: testVolumeLevelFirst forBundle: bundleIDs[0]];
    [self.registry setVolumeLevel: testVolumeLevelSecond forBundle: bundleIDs[1]];
    // then
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[0]], testVolumeLevelFirst);
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[1]], testVolumeLevelSecond);
}

- (void)testSettingVolumeLevelForItemFromRegistryViaIndex
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    CGFloat testVolumeLevel = 0.42f;
    // when
    [self.registry addBundles: bundleIDs];
    [self.registry setVolumeLevel: testVolumeLevel forBundleAtIndex: 1];
    // then
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[1]], testVolumeLevel);
}

- (void)testSaveRegistryItemsToUserDefaults
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    CGFloat testVolumeLevel = 0.42f;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // when
    [self.registry addBundles: bundleIDs];
    [self.registry setVolumeLevel: testVolumeLevel forBundle: bundleIDs[1]];
    [NSThread sleepForTimeInterval: 0.5f]; // what until items saved
    // then
    XCTAssert([[defaults objectForKey: kHSCRegistryItemsKey] isKindOfClass: NSArray.class],
                   @"Saved items should be kind of NSArray");
    XCTAssertEqual([[defaults objectForKey: kHSCRegistryItemsKey] count],
                   [self.registry registeredBundles].count, @"Some items were lost during saving");
}

- (void)testReadRegistryItemsFromUserDefaults
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    NSCountedSet *setOriginal = [NSCountedSet setWithArray: bundleIDs];
    NSCountedSet *setResult = nil;
    CGFloat testVolumeLevel = 0.42f;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // when
    [self.registry addBundles: bundleIDs];
    [self.registry setVolumeLevel: testVolumeLevel forBundle: bundleIDs[1]];
    [NSThread sleepForTimeInterval: 0.5f]; // what until items saved
    [self.registry _cleanupItems];
    [self.registry _loadRegistryItems];
    setResult = [NSCountedSet setWithArray: [self.registry registeredBundles]];
    // then
    XCTAssert([[defaults objectForKey: kHSCRegistryItemsKey] isKindOfClass: NSArray.class],
              @"Saved items should be kind of NSArray");
    XCTAssertEqual([[defaults objectForKey: kHSCRegistryItemsKey] count],
                   [self.registry registeredBundles].count,
                   @"Some items were lost during saving");
    XCTAssertEqualObjects(setOriginal, setResult,
                          @"Items ware not load properly");
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[1]], testVolumeLevel);
}

@end
