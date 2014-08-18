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
#import "HSCBundleModel.h"

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
    [super tearDown];
}

- (void)testAddingOneItemToRegistry
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    // when
    [bundleIDs enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        [self.registry addBundle: item];
    }];
    //then
    XCTAssert([self.registry registeredBundles].count == 2);
    XCTAssertEqualObjects([self.registry registeredBundles][0], bundleIDs[0], @"First item bundleID mismatch");
    XCTAssertEqualObjects([self.registry registeredBundles][1], bundleIDs[1], @"Second item bundleID mismatch");
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[0]], 1.0f);
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[1]], 1.0f);
}

- (void)testAddingItemsFromArrayToRegistry
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    // when
    [self.registry addBundles: bundleIDs];
    //then
    XCTAssert([self.registry registeredBundles].count == 2);
    XCTAssertEqualObjects([self.registry registeredBundles][0], bundleIDs[0], @"First item bundleID mismatch");
    XCTAssertEqualObjects([self.registry registeredBundles][1], bundleIDs[1], @"Second item bundleID mismatch");
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
    // when
    [self.registry addBundles: bundleIDs];
    NSArray *registeredBundles = [self.registry registeredBundles];
    // then
    XCTAssert([bundleIDs isEqualToArray: registeredBundles]);
}

- (void)testGetInitialVolumeLevelForModelFromRegistry
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    // when
    [self.registry addBundles: bundleIDs];
    // then
    XCTAssertEqual([self.registry volumeLevelForBundle: bundleIDs[0]], 1.0f);
}

- (void)testGetCustomVolumeLevelForModelFromRegistry
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
    CGFloat testVolumeLevel = 0.42f;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // when
    [self.registry addBundles: bundleIDs];
    [self.registry setVolumeLevel: testVolumeLevel forBundle: bundleIDs[1]];
    [NSThread sleepForTimeInterval: 0.5f]; // what until items saved
    [self.registry _cleanupItems];
    [self.registry _loadRegistryItems];
    // then
    XCTAssert([[defaults objectForKey: kHSCRegistryItemsKey] isKindOfClass: NSArray.class],
              @"Saved items should be kind of NSArray");
    XCTAssertEqual([[defaults objectForKey: kHSCRegistryItemsKey] count],
                   [self.registry registeredBundles].count,
                   @"Some items were lost during saving");
    XCTAssertEqualObjects([self.registry registeredBundles][0], bundleIDs[0],
                          @"Items ware not load properly");
}

@end
