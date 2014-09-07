//
//  HSCVolumeMaster+PrivateSelectors.h
//  HSCore
//
//  Created by Dmitry Rodionov on 9/3/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCore.h"
#import "HSCBundlesRegistry.h"

@interface HSCVolumeMaster (Private)

- (dispatch_queue_t)callbacksQueue;
- (HSCBundlesRegistry *)registry;

+ (CGFloat)_normalizeVolumeLevel: (CGFloat)level;

- (void)_someApplicationDidLaunch: (NSNotification *)notification;

- (BOOL)_registerBundleIfNeeded: (NSString *)bundleID
                withVolumeLevel: (CGFloat)level;

- (BOOL)_hookBundleID: (NSString *)bundleID
          volumeLevel: (CGFloat)level
           completion: (void(^)(BOOL succeeded))handler;

- (void)_initializeBundle: (NSString *)bundleID
              volumeLevel: (CGFloat)volume
               completion: (void(^)(BOOL succeeded))handler;

- (void)_publishVolumeChangesForBundle: (NSString *)bundleID;

- (void)_injectBundle: (NSString *)bundleID
           completion: (void(^)(BOOL succeeded))handler;

- (void)_injectProcesses: (NSArray *)processes
              completion: (void(^)(BOOL succeeded))handler;
@end
