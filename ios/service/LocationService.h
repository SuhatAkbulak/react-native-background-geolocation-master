//
//  LocationService.h
//  RNBackgroundLocation
//
//  Location Tracking Service
//  Android LocationService.java benzeri
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "LifecycleManager.h"
@class TSConfig;
@class LocationModel;
@class LocationEvent;
@class EnabledChangeEvent;
@class TSPowerSaveChangeEvent;

NS_ASSUME_NONNULL_BEGIN

@interface LocationService : NSObject <CLLocationManagerDelegate, LifecycleManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) TSConfig *config;
@property (nonatomic, strong) CLLocation *lastLocation;
@property (nonatomic, strong) CLLocation *stationaryLocation; // Stationary detection için referans noktası
@property (nonatomic, assign) double totalDistance;
@property (nonatomic, assign) NSTimeInterval trackingStartTime;

// Callbacks (iOS pattern - Android EventBus yerine)
@property (nonatomic, copy, nullable) void(^onLocationCallback)(LocationEvent *);
@property (nonatomic, copy, nullable) void(^onEnabledChangeCallback)(EnabledChangeEvent *);
@property (nonatomic, copy, nullable) void(^onPowerSaveChangeCallback)(TSPowerSaveChangeEvent *);

+ (instancetype)sharedInstance;
- (void)start;
- (void)stop;
- (void)scheduleAutoStop; // stopAfterElapsedMinutes
- (BOOL)isPowerSaveMode; // iOS Low Power Mode check
- (BOOL)isTracking; // Check if location tracking is active
- (void)startPowerSaveMonitoring; // Start monitoring power save mode changes
- (void)setupForegroundNotification; // Setup foreground notification for debug mode
- (void)showDebugNotification:(NSString *)title body:(NSString *)body; // Show debug notification
- (void)startHeartbeatTimer; // Start heartbeat timer

@end

NS_ASSUME_NONNULL_END


