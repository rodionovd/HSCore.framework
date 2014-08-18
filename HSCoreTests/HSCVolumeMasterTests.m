//
//  HSCVolumeMasterTests.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/18/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <HSCore/HSCVolumeMaster.h>
#import "HSCBundlesRegistry.h"
#import "HSCBundlesRegistry+HSC_CleanUp.h"

@interface HSCVolumeMasterTests : XCTestCase
@property (strong) HSCVolumeMaster *volumeMaster;
@end

@implementation HSCVolumeMasterTests

- (void)setUp
{
    self.volumeMaster = [HSCVolumeMaster sharedMaster];
    [super setUp];
}

- (void)tearDown
{
    [[HSCBundlesRegistry defaultRegistry] _cleanupItems];
    [[HSCBundlesRegistry defaultRegistry] _cleanupDefaults];
    [super tearDown];
}

- (void)testAddingNewBundleAndSettingItsVolumeLevel
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    CGFloat testVolumeLevel = 0.42;
    XCTestExpectation *expectation = [self expectationWithDescription:  @"callbackWasCalled"];
    // when
    __block BOOL result = NO;
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: bundleIDs[0]
                             callback:
     ^(BOOL succeeded) {
         result = succeeded;
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: bundleIDs[0]],
                       testVolumeLevel);
    }];
}

- (void)testSettingVolumeLevelForExistedBundle
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42, oneMoreVolumeLevel = 0.84;
    __block BOOL result = NO;
    // when
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: bundleIDs[0]
                             callback: nil];
    [self.volumeMaster setVolumeLevel: oneMoreVolumeLevel
                            forBundle: bundleIDs[0]
                             callback:
     ^(BOOL succeeded) {
         result = succeeded;
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: bundleIDs[0]], oneMoreVolumeLevel);
    }];
}

- (void)testIncreasingVolumeLevelForBundleBy10Percent
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42;
    // when
    __block BOOL result = NO;
    __weak typeof(self) welf = self;
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: bundleIDs[0]
                             callback:
     ^(BOOL succeeded) {
         __strong typeof(welf) strongSelf = welf;
         result = succeeded;
         [strongSelf.volumeMaster increaseVolumeLevelForBundle: bundleIDs[0]];
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: bundleIDs[0]],
                       (1.1) * testVolumeLevel);
    }];
}

- (void)testDecreasingVolumeLevelForBundleBy10Percent
{
    // given
    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42;
    // when
    __block BOOL result = NO;
    __weak typeof(self) welf = self;
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: bundleIDs[0]
                             callback:
     ^(BOOL succeeded) {
         __strong typeof(welf) strongSelf = welf;
         result = succeeded;
         [strongSelf.volumeMaster decreaseVolumeLevelForBundle: bundleIDs[0]];
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: bundleIDs[0]],
                       (0.9) * testVolumeLevel);
    }];
}

/**
 *
 * This test (as well as -testUnmutingBundle) required us to deal with real applications,
 * injecting a volume level infofmation inside of them and getting it back, so let's
 * skip these tests until we're done with everything else.
 */

//- (void)testMutingBundle
//{
//    // given
//    NSArray *bundleIDs = @[@"first.bundle.id", @"second.bundle.id"];
//    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
//    CGFloat testVolumeLevel = 0.42;
//    // when
//    __block BOOL result = NO;
//    __weak typeof(self) welf = self;
//    [self.volumeMaster setVolumeLevel: testVolumeLevel
//                            forBundle: bundleIDs[0]
//                             callback:
//     ^(BOOL succeeded) {
//         __strong typeof(welf) strongSelf = welf;
//         result = succeeded;
//         [strongSelf.volumeMaster muteBundle: bundleIDs[0]];
//         [expectation fulfill];
//     }];
//    // then
//    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
//        XCTAssertTrue(result);
//        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: bundleIDs[0]],
//                       0.0);
//    }];
//}

//- (void)testUnmutingBundle
//{
//}


- (void)testGettingVolumeLevel
{
    // used inside other tests, so already tested
    XCTAssert(true);
}

- (void)testGettingVolumeLevelForMultipleBundles
{
    XCTFail(@"Not implemented yet");
}

- (void)testSettingVolumeLevelForMultipleBundles
{
    XCTFail(@"Not implemented yet");
}

- (void)testRevertingVolumeChangesForBundle
{
    XCTFail(@"Not implemented yet");
}

- (void)testRevertingVolumeChangesForMultipleBundles
{
    XCTFail(@"Not implemented yet");
}

- (void)testRevertingEverything
{
    XCTFail(@"Not implemented yet");
}

@end
