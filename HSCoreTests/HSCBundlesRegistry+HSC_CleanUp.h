//
//  HSCBundlesRegistry+HSC_CleanUp.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/18/14.
//  Copyright (c) 2014 honeysound. All rights reserved.
//

#import <HSCore/HSCore.h>
#import "HSCBundlesRegistry.h"

static NSString * const kHSCRegistryItemsKey = @"kHSCRegistryItemsKey";

@interface HSCBundlesRegistry (HSC_CleanUp)
- (void)_cleanupItems;
- (void)_cleanupDefaults;
@end
