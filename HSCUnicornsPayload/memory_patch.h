//
//  memory_patch.h
//  HSCore
//
//  Created by Dmitry Rodionov on 8/24/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#ifndef __HSCore__memory_patch__
#define __HSCore__memory_patch__

#include <stdio.h>

int memory_patch(void *address, unsigned int count, uint8_t *new_bytes);

#endif /* defined(__HSCore__memory_patch__) */
