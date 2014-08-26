//
//  memory_patch.c
//  HSCore
//
//  Created by Dmitry Rodionov on 8/24/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//

#include "memory_patch.h"

#import <syslog.h>
#import <mach/mach_vm.h>
#import <mach/mach_init.h>

int memory_patch(void *address, mach_msg_type_number_t count, uint8_t *new_bytes)
{
    if (count == 0) {
        return KERN_SUCCESS;
    }

    kern_return_t kr = 0;
    kr = mach_vm_protect(mach_task_self(), (mach_vm_address_t)address, (mach_vm_size_t)count, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        syslog(LOG_NOTICE, "mach_vm_protect() failed with error: 0x%x", kr);
        return (kr);
    }

    kr = mach_vm_write(mach_task_self(), (mach_vm_address_t)address, (vm_offset_t)new_bytes, count);
    if (kr != KERN_SUCCESS) {
        syslog(LOG_NOTICE, "mach_vm_write() failed with error: 0x%x", kr);
        return (kr);
    }

    kr = mach_vm_protect(mach_task_self(), (mach_vm_address_t)address, (mach_vm_size_t)count, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        syslog(LOG_NOTICE, "mach_vm_protect() failed with error: 0x%x", kr);
    }
    
    return (kr);
}