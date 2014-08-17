//
//  HSCBundleModel.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/17/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HSCBundleModel : NSObject <NSSecureCoding>
@property (readonly, copy) NSString *bundleID;
@property (readwrite, assign) CGFloat volume; // [0..1], default is 1

+ (instancetype)modelForBundleID: (NSString *)bundleID;
@end
