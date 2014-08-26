//
//  HSCPayloadVolumeController.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/21/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//
#import <Foundation/Foundation.h>

@interface HSCPayloadNotificationsObserver : NSObject
@property (readonly, nonatomic) CGFloat volumeLevel;
+ (instancetype)observer __attribute__((const));
@end
