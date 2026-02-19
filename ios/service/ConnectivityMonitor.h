//
//  ConnectivityMonitor.h
//  RNBackgroundLocation
//
//  Connectivity Monitor
//  Android ConnectivityMonitor.java benzeri
//  Network monitoring
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
@class ConnectivityChangeEvent;

NS_ASSUME_NONNULL_BEGIN

@interface ConnectivityMonitor : NSObject

// Callback (iOS pattern - Android EventBus yerine)
@property (nonatomic, copy, nullable) void(^onConnectivityChangeCallback)(ConnectivityChangeEvent *);

+ (instancetype)sharedInstance;
- (void)startMonitoring;
- (void)stopMonitoring;
- (BOOL)isNetworkAvailable;

@end

NS_ASSUME_NONNULL_END





