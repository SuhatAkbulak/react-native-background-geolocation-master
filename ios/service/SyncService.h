//
//  SyncService.h
//  RNBackgroundLocation
//
//  HTTP Sync Service
//  Android SyncService.java benzeri
//  LOCKING mekanizmalı batch sync
//

#import <Foundation/Foundation.h>
@class HttpResponseEvent;

NS_ASSUME_NONNULL_BEGIN

@interface SyncService : NSObject

// Callback (iOS pattern - Android EventBus yerine)
@property (nonatomic, copy, nullable) void(^onHttpCallback)(HttpResponseEvent *);

+ (instancetype)sharedInstance;
+ (void)sync;
- (void)sync;

@end

NS_ASSUME_NONNULL_END





