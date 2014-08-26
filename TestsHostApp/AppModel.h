//
//  AppModel.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/22/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AppModel : NSObject

@property (strong) NSString *title;
@property (strong) NSString *bundleID;
@property (assign) CGFloat volumeLevel;

+ (instancetype)modelWithURL: (NSURL *)applicationURL;
@end
