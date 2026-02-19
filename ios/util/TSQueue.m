//
//  TSQueue.m
//  RNBackgroundLocation
//
//  Thread-safe queue management
//  iOS_PRECEDUR pattern - 8 fonksiyon
//  Orijinal implementasyon: TSQueue.o (iOS_PRECEDUR)
//

#import "TSQueue.h"

@implementation TSQueue

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static TSQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TSQueue alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize
    }
    return self;
}

#pragma mark - Methods

/**
 * Run block in background thread
 * iOS_PRECEDUR pattern: -[TSQueue runInBackground:]
 */
- (void)runInBackground:(void(^)(void))block {
    if (!block) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        block();
    });
}

/**
 * Run block in main thread
 * iOS_PRECEDUR pattern: -[TSQueue runInMain:]
 */
- (void)runInMain:(void(^)(void))block {
    if (!block) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        block();
    });
}

/**
 * Run block on main queue without deadlocking
 * iOS_PRECEDUR pattern: -[TSQueue runOnMainQueueWithoutDeadlocking:]
 * 
 * CRITICAL: This method prevents deadlocks when called from main thread
 * If already on main thread, execute immediately
 * Otherwise, dispatch to main queue
 */
- (void)runOnMainQueueWithoutDeadlocking:(void(^)(void))block {
    if (!block) {
        return;
    }
    
    // CRITICAL: Check if we're already on the main queue
    if ([NSThread isMainThread]) {
        // Already on main thread, execute immediately
        block();
    } else {
        // Not on main thread, dispatch to main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    }
}

@end





