//
//  TSLocationManager.h
//  RNBackgroundLocation
//
//  Main API interface - ExampleIOS/TSLocationManager.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TSConfig.h"
#import "TSGeofenceManager.h"
#import "TSLocation.h"
#import "TSGeofence.h"
#import "TSCurrentPositionRequest.h"
#import "TSWatchPositionRequest.h"
#import "TSCallback.h"
#import "TSActivityChangeEvent.h"
#import "TSProviderChangeEvent.h"
#import "TSHttpEvent.h"
#import "TSHeartbeatEvent.h"
#import "TSScheduleEvent.h"
#import "TSGeofencesChangeEvent.h"
#import "TSPowerSaveChangeEvent.h"
#import "TSConnectivityChangeEvent.h"
#import "TSEnabledChangeEvent.h"
#import "TSGeofenceEvent.h"
#import "TSAuthorizationEvent.h"
#import "TSDeviceInfo.h"
#import "TSAuthorization.h"
#import "LocationManager.h"

// Forward declarations
@class LogQuery;
@class TSHttpService;
@class LocationService;

NS_ASSUME_NONNULL_BEGIN

/**
 * The main API interface.
 * ExampleIOS/TSLocationManager.h pattern'ine göre implement edildi.
 */
@interface TSLocationManager : NSObject

#pragma mark - Properties

// Flags
@property (atomic, readonly) BOOL enabled;
@property (atomic, readonly) BOOL isConfigured;
@property (atomic, readonly) BOOL isDebuggingMotionDetection;
@property (atomic, readonly) BOOL isUpdatingLocation;
@property (atomic, readonly) BOOL isRequestingLocation;
@property (atomic, readonly) BOOL isMonitoringSignificantLocationChanges;
@property (atomic, readonly, nullable) NSDate *suspendedAt;
@property (atomic, readonly) BOOL isLaunchedInBackground;

// LocationManagers
@property (nonatomic, strong, readonly) CLLocationManager *locationManager;
@property (atomic) CLLocationDistance distanceFilter;
@property (nonatomic, strong, readonly) LocationManager *currentPositionManager;
@property (nonatomic, strong, readonly) LocationManager *watchPositionManager;
@property (nonatomic, strong, readonly) LocationManager *stateManager;

// Location Resources
@property (atomic, strong, readonly, nullable) CLLocation *stationaryLocation;
@property (atomic, strong, readonly, nullable) CLLocation *lastLocation;
@property (atomic, strong, readonly, nullable) CLLocation *lastGoodLocation;
@property (atomic, strong, readonly, nullable) CLLocation *lastOdometerLocation;

// GeofenceManager
@property (nonatomic, strong, readonly) TSGeofenceManager *geofenceManager;

@property (nonatomic, nullable) UIViewController* viewController;
@property (atomic, nullable) NSDate *stoppedAt;
@property (atomic) UIBackgroundTaskIdentifier preventSuspendTask;
@property (atomic, readonly) BOOL clientReady;
@property (atomic, readonly) BOOL isAcquiringState;
@property (atomic, readonly) BOOL wasAcquiringState;
@property (atomic, readonly) BOOL isAcquiringBackgroundTime;
@property (atomic, readonly) BOOL isAcquiringStationaryLocation;
@property (atomic, readonly) BOOL isAcquiringSpeed;
@property (atomic, readonly) BOOL isHeartbeatEnabled;

// Events listeners
@property (atomic, readonly) NSMutableSet *currentPositionRequests;
@property (atomic, readonly) NSMutableArray *watchPositionRequests;
@property (atomic, readonly) NSMutableSet *locationListeners;
@property (atomic, readonly) NSMutableSet *motionChangeListeners;
@property (atomic, readonly) NSMutableSet *activityChangeListeners;
@property (atomic, readonly) NSMutableSet *providerChangeListeners;
@property (atomic, readonly) NSMutableSet *httpListeners;
@property (atomic, readonly) NSMutableSet *scheduleListeners;
@property (atomic, readonly) NSMutableSet *heartbeatListeners;
@property (atomic, readonly) NSMutableSet *powerSaveChangeListeners;
@property (atomic, readonly) NSMutableSet *enabledChangeListeners;

/// [Optional] User-supplied block to render location-data for SQLite database / Firebase adapter INSERT.
@property (copy, nullable) NSDictionary* (^beforeInsertBlock) (TSLocation *location);

/// Callback for requestPermission.
@property (atomic, nullable) TSCallback *requestPermissionCallback;

/// Event Queue
@property (atomic, readonly) NSMutableSet *eventQueue;
@property (atomic) NSInteger currentMotionType; // SOMotionType enum değeri

/// Returns the API's singleton instance.
+ (TSLocationManager *)sharedInstance;

#pragma mark - Event Listener Methods

- (void)onLocation:(void(^)(TSLocation* location))success failure:(void(^)(NSError*))failure;
- (void)onHttp:(void(^)(TSHttpEvent* event))success;
- (void)onGeofence:(void(^)(TSGeofenceEvent* event))success;
- (void)onHeartbeat:(void(^)(TSHeartbeatEvent* event))success;
- (void)onMotionChange:(void(^)(TSLocation* event))success;
- (void)onActivityChange:(void(^)(TSActivityChangeEvent* event))success;
- (void)onProviderChange:(void(^)(TSProviderChangeEvent* event))success;
- (void)onGeofencesChange:(void(^)(TSGeofencesChangeEvent* event))success;
- (void)onSchedule:(void(^)(TSScheduleEvent* event))success;
- (void)onPowerSaveChange:(void(^)(TSPowerSaveChangeEvent* event))success;
- (void)onConnectivityChange:(void(^)(TSConnectivityChangeEvent* event))success;
- (void)onEnabledChange:(void(^)(TSEnabledChangeEvent* event))success;
- (void)onAuthorization:(void(^)(TSAuthorizationEvent*))callback;

- (void)removeListener:(NSString*)event callback:(void(^)(id))callback;
- (void)un:(NSString*)event callback:(void(^)(id))callback;
- (void)removeListeners:(NSString*)event;
- (void)removeListenersForEvent:(NSString*)event;
- (void)removeListeners;
- (NSArray*)getListeners:(NSString*)event;

#pragma mark - Core API Methods

- (void)configure:(NSDictionary*)params;
- (void)ready;
- (void)start;
- (void)stop;
- (void)startSchedule;
- (void)stopSchedule;
- (void)startGeofences;
- (NSMutableDictionary*)getState;

#pragma mark - Geolocation Methods

- (void)changePace:(BOOL)value;
- (void)getCurrentPosition:(TSCurrentPositionRequest*)request;
- (void)setOdometer:(CLLocationDistance)odometer request:(TSCurrentPositionRequest*)request;
- (CLLocationDistance)getOdometer;
- (void)watchPosition:(TSWatchPositionRequest*)request;
- (void)stopWatchPosition;
- (NSDictionary*)getStationaryLocation;
- (TSProviderChangeEvent*)getProviderState;
- (void)requestPermission:(void(^)(NSNumber *status))success failure:(void(^)(NSNumber *status))failure;
- (void)requestTemporaryFullAccuracy:(NSString*)purpose success:(void(^)(NSInteger))success failure:(void(^)(NSError*))failure;

#pragma mark - HTTP & Persistence Methods

- (void)sync:(void(^)(NSArray* locations))success failure:(void(^)(NSError* error))failure;
- (void)getLocations:(void(^)(NSArray* locations))success failure:(void(^)(NSString* error))failure;
- (BOOL)clearDatabase;
- (BOOL)destroyLocations;
- (void)destroyLocations:(void(^)(void))success failure:(void(^)(NSString* error))failure;
- (void)destroyLocation:(NSString*)uuid;
- (void)destroyLocation:(NSString*)uuid success:(void(^)(void))success failure:(void(^)(NSString* error))failure;
- (void)insertLocation:(NSDictionary*)params success:(void(^)(NSString* uuid))success failure:(void(^)(NSString* error))failure;
- (void)persistLocation:(TSLocation*)location;
- (int)getCount;

#pragma mark - Application Methods

- (UIBackgroundTaskIdentifier)createBackgroundTask;
- (void)stopBackgroundTask:(UIBackgroundTaskIdentifier)taskId;
- (BOOL)isPowerSaveMode;

#pragma mark - Logging & Debug Methods

- (void)getLog:(void(^)(NSString* log))success failure:(void(^)(NSString* error))failure;
- (void)getLog:(LogQuery*)query success:(void(^)(NSString* log))success failure:(void(^)(NSString* error))failure;
- (void)emailLog:(NSString*)email success:(void(^)(void))success failure:(void(^)(NSString* error))failure;
- (void)emailLog:(NSString*)email query:(LogQuery*)query success:(void(^)(void))success failure:(void(^)(NSString* error))failure;
- (void)uploadLog:(NSString*)url query:(LogQuery*)query success:(void(^)(void))success failure:(void(^)(NSString* error))failure;
- (BOOL)destroyLog;
- (void)setLogLevel:(NSInteger)level; // TSLogLevel enum
- (void)playSound:(SystemSoundID)soundId;
- (void)error:(UIBackgroundTaskIdentifier)taskId message:(NSString*)message;
- (void)log:(NSString*)level message:(NSString*)message;

#pragma mark - Geofencing Methods

- (void)addGeofence:(TSGeofence*)geofence success:(void (^)(void))success failure:(void (^)(NSString* error))failure;
- (void)addGeofences:(NSArray*)geofences success:(void (^)(void))success failure:(void (^)(NSString* error))failure;
- (void)removeGeofence:(NSString*)identifier success:(void (^)(void))success failure:(void (^)(NSString* error))failure;
- (void)removeGeofences:(NSArray*)identifiers success:(void (^)(void))success failure:(void (^)(NSString* error))failure;
- (void)removeGeofences;
- (NSArray*)getGeofences;
- (void)getGeofences:(void (^)(NSArray*))success failure:(void (^)(NSString*))failure;
- (void)getGeofence:(NSString*)identifier success:(void (^)(TSGeofence*))success failure:(void (^)(NSString*))failure;
- (void)geofenceExists:(NSString*)identifier callback:(void (^)(BOOL))callback;

#pragma mark - Sensor Methods

- (BOOL)isMotionHardwareAvailable;
- (BOOL)isDeviceMotionAvailable;
- (BOOL)isAccelerometerAvailable;
- (BOOL)isGyroAvailable;
- (BOOL)isMagnetometerAvailable;

#pragma mark - Application life-cycle callbacks

- (void)onSuspend:(NSNotification *)notification;
- (void)onResume:(NSNotification *)notification;
- (void)onAppTerminate;

#pragma mark - Private Methods

- (void)fireMotionActivityChangeEvent:(TSActivityChangeEvent*)event;

@end

NS_ASSUME_NONNULL_END

