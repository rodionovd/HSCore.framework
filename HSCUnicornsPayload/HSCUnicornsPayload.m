//
//  HSCUnicornsPayload.m
//  HSCUnicornsPayload
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCPayloadPatcher.h"
#import "HSCUnicornsPayload.h"
#import "HSCPayloadNotificationsObserver.h"

@implementation HSCUnicornsPayload

+ (void)load
{
    NSLog(@"Hello from %@", [[NSRunningApplication currentApplication] localizedName]);
    dispatch_async(dispatch_get_main_queue(), ^{
        [HSCPayloadNotificationsObserver observer];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if ([HSCPayloadPatcher patchAudioLibraries]) {
                NSLog(@"SUCC");
            } else {
                NSLog(@"Patching failed");
            }
        });

    });
}

@end
