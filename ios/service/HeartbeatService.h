//
//  HeartbeatService.h
//  RNBackgroundLocation
//
//  Heartbeat Service
//  Android HeartbeatService.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HeartbeatEvent;

@interface HeartbeatService : NSObject

// Singleton
+ (instancetype)sharedInstance;

// Start/Stop
+ (void)start;
+ (void)stop;

// On heartbeat triggered (internal)
+ (void)onHeartbeat;

// Callback
@property (nonatomic, copy, nullable) void (^onHeartbeatCallback)(HeartbeatEvent *event);

@end

NS_ASSUME_NONNULL_END





