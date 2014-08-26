//
//  HSCVolumeMasterTests.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/18/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

@import Cocoa;
@import XCTest;
@import HSCore;

#import "HSCBundlesRegistry.h"
#import "HSCBundlesRegistry+HSC_CleanUp.h"

@interface HSCVolumeMasterTests : XCTestCase
@property (strong) HSCVolumeMaster *volumeMaster;
@property (strong) NSArray *demoTargets;
@end

@implementation HSCVolumeMasterTests

- (void)setUp
{
    [super setUp];

    self.volumeMaster = [HSCVolumeMaster sharedMaster];
    self.demoTargets = @[@"com.apple.TextEdit", @"com.apple.Notes", @"com.apple.Terminal"];
    // For some reason, +bundleWithIdentifier: returns nil...
    NSArray *correspondingTargetPaths = @[@"/Applications/TextEdit.app", @"/Applications/Notes.app",
                                          @"/Applications/Utilities/Terminal.app"];
    // Launch demo targets
    [self.demoTargets enumerateObjectsUsingBlock: ^(NSString *bundleID, NSUInteger idx, BOOL *stop) {
        NSBundle *bundle = [NSBundle bundleWithPath: correspondingTargetPaths[idx]];
        if (!bundle) {
            @throw [NSException exceptionWithName: @"EPICFAIL" reason: @"Where're the Apple default apps?" userInfo: nil];
            return;
        }
        NSError *error = nil;
        [[NSWorkspace sharedWorkspace] launchApplicationAtURL: bundle.bundleURL
                                                      options: (NSWorkspaceLaunchDefault | NSWorkspaceLaunchAndHide | NSWorkspaceLaunchNewInstance)
                                                configuration: nil
                                                        error: &error];
        if (error) {
            @throw [NSException exceptionWithName: @"EPICFAIL1"
                                           reason: @"Unable to launch default application"
                                         userInfo: nil];
        }
    }];

    [[HSCBundlesRegistry defaultRegistry] _cleanupItems];
    [[HSCBundlesRegistry defaultRegistry] _cleanupDefaults];
    [NSThread sleepForTimeInterval: 2];
}

- (void)tearDown
{
    [[HSCBundlesRegistry defaultRegistry] _cleanupItems];
    [[HSCBundlesRegistry defaultRegistry] _cleanupDefaults];
    // Terminate demo targets
    [self.demoTargets enumerateObjectsUsingBlock: ^(NSString *bundleID, NSUInteger idx, BOOL *stop) {
        NSArray *allInstances = [NSRunningApplication runningApplicationsWithBundleIdentifier: bundleID];
        [allInstances enumerateObjectsUsingBlock: ^(NSRunningApplication *app, NSUInteger idx, BOOL *stop) {
            [app terminate];
        }];
    }];
    [NSThread sleepForTimeInterval: 1];
    [super tearDown];
}

- (void)testAddingNewBundleAndSettingItsVolumeLevel
{
    // given
    CGFloat testVolumeLevel = 0.42;
    XCTestExpectation *expectation = [self expectationWithDescription:  @"callbackWasCalled"];
    __block BOOL result = NO;
    // when
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: self.demoTargets[0]
                           completion:
     ^(BOOL succeeded) {
         result = succeeded;
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[0]],
                       testVolumeLevel);
    }];
}

- (void)testSettingVolumeLevelForExistingBundle
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42, oneMoreVolumeLevel = 0.84;
    __block BOOL result = NO;
    // when
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: self.demoTargets[0]
                           completion: nil];
    sleep(2);
    [self.volumeMaster setVolumeLevel: oneMoreVolumeLevel
                            forBundle: self.demoTargets[0]
                           completion:
     ^(BOOL succeeded) {
         result = succeeded;
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[0]], oneMoreVolumeLevel);
    }];
}

- (void)testIncreasingVolumeLevelForBundleBy10Percent
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42;
    __block BOOL result = NO;
    __weak typeof(self) welf = self;
    // when
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: self.demoTargets[0]
                           completion:
     ^(BOOL succeeded) {
         __strong typeof(welf) strongSelf = welf;
         result = succeeded;
         [strongSelf.volumeMaster increaseVolumeLevelForBundle: strongSelf.demoTargets[0]];
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[0]],
                       (1.1) * testVolumeLevel);
    }];
}

- (void)testDecreasingVolumeLevelForBundleBy10Percent
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42;
    __block BOOL result = NO;
    __weak typeof(self) welf = self;
    // when
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: self.demoTargets[0]
                           completion:
     ^(BOOL succeeded) {
         __strong typeof(welf) strongSelf = welf;
         result = succeeded;
         [strongSelf.volumeMaster decreaseVolumeLevelForBundle: strongSelf.demoTargets[0]];
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[0]],
                       (0.9) * testVolumeLevel);
    }];
}

/**
 *
 * This test (as well as -testUnmutingBundle) require us to deal with real applications,
 * injecting a volume level infofmation inside of them and getting it back, so let's
 * skip these tests until we're done with everything else.
 */

- (void)testMutingBundle
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42;
    // when
    __block BOOL result = NO;
    __weak typeof(self) welf = self;
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: self.demoTargets[0]
                           completion:
     ^(BOOL succeeded) {
         __strong typeof(welf) strongSelf = welf;
         result = succeeded;
         [strongSelf.volumeMaster muteBundle: strongSelf.demoTargets[0]];
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[0]],
                       0.0);
    }];
}

- (void)testUnmutingBundle
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42;
    // when
    __block BOOL result = NO;
    __weak typeof(self) welf = self;
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: self.demoTargets[0]
                           completion:
     ^(BOOL succeeded) {
         __strong typeof(welf) strongSelf = welf;
         result = succeeded;
         [strongSelf.volumeMaster muteBundle: strongSelf.demoTargets[0]];
         [strongSelf.volumeMaster unmuteBundle: strongSelf.demoTargets[0]];
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertTrue(result);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[0]], testVolumeLevel);
    }];
}


- (void)testGettingVolumeLevelForUnknownBundle
{
    // given
    CGFloat level = 0.0;
    // when
    level = [self.volumeMaster volumeLevelForBundle: self.demoTargets[0]];
    // then
    XCTAssertEqual(level, 1.0);
}

- (void)testGettingVolumeLevelForMultipleExistingBundles
{
    // given
    NSCountedSet *setOriginal = [NSCountedSet setWithArray: self.demoTargets];
    CGFloat testVolumeLevel = 0.42;
    XCTestExpectation *firstExpectation = [self expectationWithDescription: @"firstCallbackWasCalled"];
    XCTestExpectation *secondExpectation = [self expectationWithDescription: @"secondCallbackWasCalled"];
    XCTestExpectation *thirdExpectation = [self expectationWithDescription: @"thirdCallbackWasCalled"];
    // when
    [self.volumeMaster setVolumeLevel: 1.0
                            forBundle: self.demoTargets[0]
                           completion: ^(BOOL succeeded) { [firstExpectation fulfill]; }];
    [self.volumeMaster setVolumeLevel: testVolumeLevel
                            forBundle: self.demoTargets[1]
                           completion: ^(BOOL succeeded) { [secondExpectation fulfill]; }];
    [self.volumeMaster setVolumeLevel: 1.0
                            forBundle: self.demoTargets[2]
                           completion: ^(BOOL succeeded) { [thirdExpectation fulfill]; }];
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        NSDictionary *result = [self.volumeMaster volumeLevelsForBundles: self.demoTargets];
        // then
        NSCountedSet *setResult = [NSCountedSet setWithArray: [result allKeys]];
        XCTAssertNotNil(setResult);
        XCTAssertEqualObjects(setOriginal, setResult); // we don't care about order of the items
        XCTAssertEqual([[result objectForKey: self.demoTargets[0]] doubleValue], 1.0);
        XCTAssertEqual([[result objectForKey: self.demoTargets[1]] doubleValue], testVolumeLevel);
        XCTAssertEqual([[result objectForKey: self.demoTargets[2]] doubleValue], 1.0);
    }];

}

- (void)testSettingVolumeLevelForMultipleNewBundles
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42, oneMoreTestVolumeLevel = 0.84;
    NSDictionary *params = @{
                             self.demoTargets[0] : @(testVolumeLevel),
                             self.demoTargets[1] : @(testVolumeLevel),
                             self.demoTargets[2] : @(oneMoreTestVolumeLevel),
                             };
    __block NSArray *fails = nil;
    // when
    [self.volumeMaster setVolumeLevelsForBundles: params
                                      completion: ^() {
        [expectation fulfill];
    } failure:
     ^(NSArray *failedBundles) {
         fails = [failedBundles copy];
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertNil(fails, @"%@", fails);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[0]],
                       testVolumeLevel);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[1]],
                       testVolumeLevel);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[2]],
                       oneMoreTestVolumeLevel);
    }];
}

- (void)testSettingVolumeLevelForMultipleExistingBundles
{
    // given
    XCTestExpectation *expectation = [self expectationWithDescription: @"callbackWasCalled"];
    CGFloat testVolumeLevel = 0.42, oneMoreTestVolumeLevel = 0.84;
    NSDictionary *params = @{
        self.demoTargets[0] : @(testVolumeLevel),
        self.demoTargets[1] : @(1.0),
        self.demoTargets[2] : @(oneMoreTestVolumeLevel),
    };
    __block NSArray *fails = nil;
    // when
    [self.demoTargets enumerateObjectsUsingBlock: ^(NSString *item, NSUInteger idx, BOOL *stop) {
        [self.volumeMaster setVolumeLevel: 1.0 forBundle: item completion: nil];
    }];
    sleep(2);
    [self.volumeMaster setVolumeLevelsForBundles: params completion: ^(){
        [expectation fulfill];
    } failure:
     ^(NSArray *failedBundles) {
         fails = [failedBundles copy];
         [expectation fulfill];
     }];
    // then
    [self waitForExpectationsWithTimeout: 10 handler: ^(NSError *error) {
        XCTAssertNil(fails);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[0]],
                       testVolumeLevel);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[1]],
                       1.0);
        XCTAssertEqual([self.volumeMaster volumeLevelForBundle: self.demoTargets[2]],
                       oneMoreTestVolumeLevel);
    }];
}

- (void)testSettingVolumeLevelForMultipleBundlesWithEmptyParameters
{
    // when
    NSDictionary *params = @{};
    // then
    XCTAssertThrows([self.volumeMaster setVolumeLevelsForBundles: params completion: nil failure: nil]);
}

- (void)testSettingVolumeLevelForMultipleBundlesWithNilParameters
{
    // when
    NSDictionary *params = nil;
    // then
    XCTAssertThrows([self.volumeMaster setVolumeLevelsForBundles: params completion: nil failure: nil]);
}

@end
