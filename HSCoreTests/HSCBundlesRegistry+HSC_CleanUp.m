//
//  HSCBundlesRegistry+HSC_CleanUp.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/18/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#import "HSCBundlesRegistry+HSC_CleanUp.h"

@implementation HSCBundlesRegistry (HSC_CleanUp)

- (void)_cleanupItems
{
    [(NSMutableArray *)self.items removeAllObjects];
}

- (void)_cleanupDefaults
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: kHSCRegistryItemsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
