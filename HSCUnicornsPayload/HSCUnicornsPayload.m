//
//  HSCUnicornsPayload.m
//  HSCUnicornsPayload
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCUnicornsPayload.h"

@implementation HSCUnicornsPayload

+ (void)load {
    @autoreleasepool {
        NSLog(@"Hello from %@", [[NSRunningApplication currentApplication] localizedName]);
    }
}

@end
