//
//  HSCPayloadPatcher.m
//  HSCore
//
//  Created by Dmitry Rodionov on 8/23/14.
//  Copyright (c) 2014 HoneySound. All rights reserved.
//
#import <dlfcn.h>
#import <pthread.h>
#import <objc/message.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/AudioHardware.h>
#import <AudioToolbox/AudioToolbox.h>

#import "HSCPayloadNotificationsObserver.h"
#import "HSCPayloadPatcher.h"
#import "rd_get_symbols.h"
#import "memory_patch.h"
#import "rd_route.h"

static CFMutableDictionaryRef callbacks_dictionary = NULL;

/** Private CoreAudio stuff */
#define kCoreAudioBundleID @"com.apple.audio.CoreAudio"
static uintptr_t (*HALObjectMap_CopyObjectByObjectID)(uintptr_t) = NULL;
static uintptr_t (*HALC_ShellObjectMap_CopyObjectByObjectID)(uintptr_t) = NULL;
static uintptr_t (*HALC_ProxyObjectMap_CopyObjectByObjectID)(uintptr_t) = NULL;
static BOOL      (*HALC_ProxyObject_IsSubClass)(uintptr_t, uintptr_t)   = NULL;

static OSStatus (*original_AudioDeviceAddIOProc)(uint32_t, void*, void*) = NULL;
static OSStatus (*original_AudioDeviceCreateIOProcID)(uint32_t, void*, void*, AudioDeviceIOProcID*) = NULL;

/** Private AudioToolbox stuff */
#define kAudioToolboxBundleID @"com.apple.audio.toolbox.AudioToolbox"
static uintptr_t (*AQMEIO_IOProc)(void) = NULL;
static uintptr_t (*AQMEIO_HAL_IOProc)(uintptr_t, void*, void*, void*, void*) = NULL;

static void hook_IOProc(AudioDeviceIOProc callback);

@implementation HSCPayloadPatcher

+ (BOOL)patchAudioLibraries
{
    static BOOL result = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result |= [self _hookMainAudioDeviceIOCallbacks];
        if (!result) return;
        result |= [self _hookAlertAndSystemSoundsOutputLevel];
        if (!result) return;
    });

    return result;
}

+ (BOOL)_hookMainAudioDeviceIOCallbacks
{
    if (![self _lookupCoreAudioPrivateStuff]) {
        return NO;
    }

    AudioObjectID mainAudioDeviceID = 0;
    int err = KERN_FAILURE;
    uint32_t property_size = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress property_address = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    err = AudioObjectGetPropertyData(kAudioObjectSystemObject, &property_address,
                                     0, NULL, &property_size, &mainAudioDeviceID);
    if (err != kAudioHardwareNoError || mainAudioDeviceID == kAudioDeviceUnknown) {
        NSLog(@"Could not find a main output audio device");
        return NO;
    }
    uintptr_t HALDevice = HALObjectMap_CopyObjectByObjectID(mainAudioDeviceID);
    uintptr_t HALDeviceID = *((uintptr_t *)(HALDevice + 0xC));
    uintptr_t HALCShellObject = HALC_ShellObjectMap_CopyObjectByObjectID(HALDeviceID);
    if (!HALCShellObject) {
        NSLog(@"Could not locate a shell object for device ID: %p", (void *)HALDeviceID);
        return NO;
    }
    NSInteger minorOSXVersion = [self currentMinorOSXVersion];
    if (minorOSXVersion < 9) {
        NSLog(@"Sorry, we don't support OS X version prior to 10.9");
        return NO;
    }
    uintptr_t ShellObjectIDOffset = 0;
    if (minorOSXVersion == 9 || minorOSXVersion == 10) {
        /* 10.9 & 10.10 */
        ShellObjectIDOffset = 0x128;
    } else {
        NSLog(@"Error: Unknown OS X version. Fallback to 10.10 values");
        ShellObjectIDOffset = 0x128;
    }

    uintptr_t ShellDeviceID = *((uintptr_t *)(HALCShellObject + ShellObjectIDOffset));
    uintptr_t HALCShellObjectProxy = HALC_ProxyObjectMap_CopyObjectByObjectID(ShellDeviceID);
    if (HALCShellObjectProxy == 0 ||
        HALC_ProxyObject_IsSubClass(HALCShellObjectProxy, 'ioct') == false) {
        NSLog(@"Invalid shell object proxy: %p (offset = %p, id = %p)", (void *)HALCShellObjectProxy,
              (void*)ShellObjectIDOffset, (void *)ShellDeviceID);
        return NO;
    }
    /**
     * Iterate the list of callbacks (`IOProc`s) within the shell proxy,
     * and replace them with our wrapper.
     */
    uintptr_t IOProcListStartOffset = 0x70;
    uintptr_t IOProcListPtr = *((uintptr_t *)(HALCShellObjectProxy + IOProcListStartOffset));
    uintptr_t IOProcListEnd = *((uintptr_t *)(HALCShellObjectProxy + IOProcListStartOffset + sizeof(uintptr_t)));
    NSLog(@"[%p :: %p]", (void *)IOProcListPtr, (void *)IOProcListEnd);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wint-conversion"
    while (IOProcListPtr < IOProcListEnd) {
        AudioDeviceIOProc original_proc_ptr = *(uintptr_t *)(IOProcListPtr);
        uintptr_t imp_offset = 0x0;
        /**
         * New CoreAudio API will place an ID of the callback in first 8 bytes
         * and its implementation address in the next 8 (4 for 32-bit runtime).
         * The old API doesn't use IDs, and the address offset is zero.
         */
        uintptr_t max_id = 0xFFF;
        /* if this address is not even an address but an ID */
        NSLog(@"original_proc_ptr = %p", (void *)original_proc_ptr);
        if ((uintptr_t)original_proc_ptr <= max_id) {
            imp_offset = sizeof(uintptr_t);
        }
        /* Replace the original callback implementation with our one */
        uintptr_t original_imp = *(uintptr_t *)(IOProcListPtr + imp_offset);
        NSLog(@"original_imp = %p", (void *)original_imp);
        hook_IOProc(original_imp);

        /* Go to next list item */
        #define IOProcListItemSize 0x60
        IOProcListPtr += IOProcListItemSize;
    }
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    /**
     * Hook IOProc-adding functions so we can pre-patch any future callback
     */
    err = rd_route(AudioDeviceCreateIOProcID,
                   HS_AudioDeviceCreateIOProcID,
                   (void **)&original_AudioDeviceCreateIOProcID);
    if (err != KERN_SUCCESS) {
        NSLog(@"[line %3d] rd_route() failed with error: %d", __LINE__, err);
        return NO;
    }
    err = rd_route(AudioDeviceAddIOProc,
                   HS_AudioDeviceAddIOProc,
                   (void **)&original_AudioDeviceAddIOProc);
    if (err != KERN_SUCCESS) {
        NSLog(@"[line %3d] rd_route() failed with error: %d", __LINE__, err);
        return NO;
    }
#pragma clang diagnostic pop

    return YES;
}

+ (BOOL)_hookAlertAndSystemSoundsOutputLevel
{
    if (![self _lookupAudioToolboxPrivateStuff]) {
        return NO;
    }
    ///TODO: change alerts volume level

    return YES;
}

#pragma mark - Main hook

static void hook_IOProc(AudioDeviceIOProc callback)
{
    if (!callback) {
        NSLog(@"[line %3d] hook_IOProc: callback is NULL", __LINE__);
        return;
    }
    int err = KERN_FAILURE;
    /**
     * As for 10.9 and modern AQMEIO API we use a workaround to hook
     * an AQMEIO::IOProc wrapper instead of hooking the callback itself.
     */
    if (init_AQMEIO_workaround() != KERN_SUCCESS) {
        NSLog(@"[line %3d]: init_AQMEIO_workaround failed", __LINE__);
        return;
    }
    if ((uintptr_t)callback == (uintptr_t)AQMEIO_IOProc) {
        err = rd_route(AQMEIO_IOProc, HS_AQMEIO_IOProc, NULL);
        if (err != KERN_SUCCESS) {
            NSLog(@"Error: unable to route AQMEIO::IOProc()");
        }
        return;
    }

    /**
     * For applications which don't use modern AQMEIO API, we have to manually hook
     * any single IO callback (aka IOProc).
     */
    AudioDeviceIOProc fallback = 0;
    err = rd_duplicate_function((void *)callback, (void **)&fallback);
    NSLog(@"Fallback for (%p) = %p", (void *)callback, (void *)fallback);
    if (err != KERN_SUCCESS) {
        NSLog(@"rd_duplicate_function() failed with error: %d", err);
        return;
    }

    /**
     * Since we are going to use one `muter_IOProc` to mute all the original callbacks,
     * we need to somehow recognize what was the original callback.
     * My solution is:
     *    before jumping into `muter_IOProc()` we'll save a "callback_address : duplicated_address" pair
     *    into RDCallbacks dict. Then we save the callback's address in ECX register and do the jump.
     * Later, inside `muter_IOProc()` we read ECX and get the duplicated implementation address from RDCallbacks.
     */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        callbacks_dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
    });
    if (!callbacks_dictionary) {
        NSLog(@"Unable to create callbacks dictionary, abort");
        return;
    }

    static pthread_mutex_t callbacks_dict_lock = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&callbacks_dict_lock);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wint-to-pointer-cast"
    const void *key = (const void *)((int)callback);
    CFDictionaryAddValue(callbacks_dictionary, (const void *)key, fallback);
    pthread_mutex_unlock(&callbacks_dict_lock);
#pragma clang diagnostic pop

    unsigned char opcodes[11] = {0x0};
#if defined(__LP64__) || defined (__X86_64__)
    // mov rcx, original_ptr
    opcodes[0] = 0xB9;
#else
    // mov esi, original_ptr
    opcodes[0] = 0xBE;
#endif
    *((int*)&opcodes[1]) = (int)callback;
    // jmp mute_callback
    int offset = (int)(muter_IOProc - callback - 10);
    opcodes[5] = 0xE9;
    *((int*)&opcodes[6]) = offset;

    memory_patch((void *)callback, 11, opcodes);
}

#pragma mark - AQMEIO workaround (new CoreAudio API)

static int init_AQMEIO_workaround(void)
{
    static int result = KERN_FAILURE;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *audioToolboxBundle = [NSBundle bundleWithIdentifier: kAudioToolboxBundleID];
        NSURL *frameworkURL = [[audioToolboxBundle executableURL] URLByResolvingSymlinksInPath];
        const char * framework_path = [[frameworkURL path] UTF8String];
        int count = 2;
        struct rd_named_symbol symbols[] = {
            /* AQMEIO::IOProc */
            {"__ZN10AQMEIO_HAL7_IOProcEjPK14AudioTimeStampPK15AudioBufferListS2_PS3_S2_Pv"},
            /* AQMEIO::HAL::IOProc */
            {"__ZN10AQMEIO_HAL6IOProcEPK15AudioBufferListPK14AudioTimeStampPS0_S5_"}
        };
        int err = rd_get_symbols_from_image(framework_path, &count, symbols);
        if (err != KERN_SUCCESS || count != 2) {
            NSLog(@"AQMEIO workaround failed. It's OK if you're running OS X version 10.8 and"
                  @"older, but for OS X 10.9+ that means a fatal error");
            return;
        }
        AQMEIO_IOProc = (void *)symbols[0].nvalue;
        AQMEIO_HAL_IOProc = (void *)symbols[1].nvalue;
        result = KERN_SUCCESS;
    });

    return result;
}


static OSStatus HS_AQMEIO_IOProc(AudioDeviceID device, AudioTimeStamp *now,
                                 AudioBufferList *input_data, AudioTimeStamp *input_time,
                                 AudioBufferList *output_data, AudioTimeStamp *output_time,
                                 void *client_data)
{
#pragma unused(device)
#pragma unused(client_data)
#pragma unused(now)
    /* Current AQMEIO context lies inside the RBP register */
    int64_t context = 0x0;
    asm("leaq (%%rbp), %0;": "=r"(context));
    int HALDeviceOffset = 0x10;

    if (!AQMEIO_HAL_IOProc) {
        return KERN_FAILURE;
    }
    /* Obtain a HAL device ID and call the original callback for it */
    AQMEIO_HAL_IOProc(*(long *)(context + HALDeviceOffset), input_data,
                      input_time, output_data, output_time);
    if (!output_data) {
        return KERN_SUCCESS;
    }
    /* Mute the output */
    uint32_t buffersCount = output_data->mNumberBuffers;
    if (buffersCount == 0) {
        return KERN_SUCCESS;
    }

    HSCPayloadNotificationsObserver *observer = [HSCPayloadNotificationsObserver observer];
    // In case the observer failed to initialize
    CGFloat level = observer ? [observer volumeLevel] : 1.0f;

    for (uint32_t idx = 0; idx < buffersCount; idx++) {
        float *muted_data = (float *)(output_data->mBuffers[idx].mData);
        if (!muted_data) continue;
        uint32_t byte_size = output_data->mBuffers[idx].mDataByteSize;
        for (int k = 0; k < byte_size; k++) {
            muted_data[k] = muted_data[k] * level;
        }
    }
    return KERN_SUCCESS;
}

#pragma mark - Muter callback

static OSStatus muter_IOProc(AudioDeviceID device, const AudioTimeStamp *now,
                             const AudioBufferList *input_data, const AudioTimeStamp *input_time,
                             AudioBufferList *output_data, const AudioTimeStamp *output_time,
                             void *client_data)
{
    int tmp = 0;
    asm("movl %%ecx, %0;" : "=r" (tmp) : );
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wint-to-pointer-cast"
    const void *key = (const void *)tmp;
#pragma clang diagnostic pop

    AudioDeviceIOProc source_callback = 0;
    Boolean key_exists = CFDictionaryGetValueIfPresent(callbacks_dictionary,
                                                       (const void *)key,
                                                       (const void **)&source_callback);
    if (!key_exists) {
        return KERN_FAILURE;
    }

    int err = source_callback(device, now, input_data, input_time, output_data,
                              output_time, client_data);
    /* Mute the output */
    uint32_t buffersCount = output_data->mNumberBuffers;
    if (buffersCount == 0) {
        return KERN_SUCCESS;
    }

    HSCPayloadNotificationsObserver *observer = [HSCPayloadNotificationsObserver observer];
    CGFloat level = observer ? [observer volumeLevel] : 1.0f;

    for (uint32_t idx = 0; idx < buffersCount; idx++) {
        float *muted_data = (float *)(output_data->mBuffers[idx].mData);
        if (!muted_data) continue;
        uint32_t byte_size = output_data->mBuffers[idx].mDataByteSize;
        for (int k = 0; k < byte_size; k++) {
            muted_data[k] = muted_data[k] * level;
        }
    }

    return err;
}

#pragma mark - Create/Add IOProc hooks

static OSStatus HS_AudioDeviceCreateIOProcID(AudioObjectID inDevice, AudioDeviceIOProc inProc, void *inClientData,AudioDeviceIOProcID *outIOProcID)
{
    hook_IOProc(inProc);
    if (original_AudioDeviceCreateIOProcID) {
        return original_AudioDeviceCreateIOProcID(inDevice, inProc, inClientData, outIOProcID);
    } else {
        NSLog(@"Oh, shitshitshit %s", __PRETTY_FUNCTION__);
        return KERN_FAILURE;
    }
}

static OSStatus HS_AudioDeviceAddIOProc(AudioDeviceID inDevice, AudioDeviceIOProc inProc, void *inClientData)
{
    hook_IOProc(inProc);
    if (original_AudioDeviceAddIOProc) {
        return original_AudioDeviceAddIOProc(inDevice, inProc, inClientData);
    } else {
        NSLog(@"Oh, shitshitshit: %s", __PRETTY_FUNCTION__);
        return KERN_FAILURE;
    }
}


#pragma mark - AudioServices hooks

enum {
    kAudioServicesPropertySystemSoundLevel = 'ssvl'
};


#pragma mark - Private symbols lookup

+ (BOOL)_lookupCoreAudioPrivateStuff
{
    NSBundle *coreAudioBundle = [NSBundle bundleWithIdentifier: kCoreAudioBundleID];
    NSURL *frameworkURL = [[coreAudioBundle executableURL] URLByResolvingSymlinksInPath];
    const char * framework_path = [[frameworkURL path] UTF8String];
    if (!framework_path) {
        NSLog(@"Could not locate CoreAudio framework");
        return NO;
    }

    struct rd_named_symbol symbols[4] = {
        // HALOObjectMap::CopyObjectByObjectID
        {"__ZN12HALObjectMap20CopyObjectByObjectIDEj"},
        // HALC::ShellObjectMap::CopyObjectByObjectID
        {"__ZN19HALC_ShellObjectMap20CopyObjectByObjectIDEj"},
        // HALC::ProxyObjectMap::CopyObjectByObjectID
        {"__ZN19HALC_ProxyObjectMap20CopyObjectByObjectIDEj"},
        // HALC_ProxyObject_IsSubClass
        {"__ZNK16HALC_ProxyObject10IsSubClassEj"},
    };
    int count = 4;
    int err = rd_get_symbols_from_image(framework_path, &count, symbols);
    if (err != KERN_SUCCESS || count != 4) {
        NSLog(@"Could not locate private CoreAudio symbols. Error: %d", err);
        return NO;
    }
    HALObjectMap_CopyObjectByObjectID = (void *)symbols[0].nvalue;
    HALC_ShellObjectMap_CopyObjectByObjectID = (void *)symbols[1].nvalue;
    HALC_ProxyObjectMap_CopyObjectByObjectID = (void *)symbols[2].nvalue;
    HALC_ProxyObject_IsSubClass = (void *)symbols[3].nvalue;

    return YES;
}

+ (BOOL)_lookupAudioToolboxPrivateStuff
{
//    NSBundle *coreAudioBundle = [NSBundle bundleWithIdentifier: kAudioToolboxBundleID];
//    NSURL *frameworkURL = [[coreAudioBundle executableURL] URLByResolvingSymlinksInPath];
//    const char * framework_path = [[frameworkURL path] UTF8String];
//    if (!framework_path) {
//        NSLog(@"Could not locate AudioToolbox framework");
//        return NO;
//    }
//    struct rd_named_symbol symbols[] = {
//        {"__ZN18SSSSettingsStorage15SetFloat32ValueEPK10__CFStringf"}
//    };
//    int count = 1;
//    int err = rd_get_symbols_from_image(framework_path, &count, symbols);
//    if (err != KERN_SUCCESS || count != 1) {
//        NSLog(@"Could not locate private AudioToolbox symbols. Error: %d", err);
//        return NO;
//    }

    return YES;
}

#pragma mark - Current OS X version in runtime

+ (NSInteger)currentMinorOSXVersion
{
    NSOperatingSystemVersion version;
    if ([[NSProcessInfo processInfo] respondsToSelector: @selector(operatingSystemVersion)]) {
        /* 10.10 and maybe 10.9 (via private API) */
        version = ((NSOperatingSystemVersion(*)(id, SEL))objc_msgSend_stret)
        ([NSProcessInfo processInfo], @selector(operatingSystemVersion));
    } else {
        /* 10.9 and earlier */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        Gestalt(gestaltSystemVersionMinor, (int *)&(version.minorVersion));
#pragma clang diagnostic pop
    }

    return version.minorVersion;
}

@end
