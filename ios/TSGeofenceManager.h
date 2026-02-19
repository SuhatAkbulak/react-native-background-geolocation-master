//
//  TSGeofenceManager.h
//  RNBackgroundLocation
//
//  Geofence Manager - ExampleIOS/TSGeofenceManager.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class TSGeofenceEvent;
@class TSGeofencesChangeEvent;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const STATIONARY_REGION_IDENTIFIER;

/**
 * TSGeofenceManager
 * ExampleIOS/TSGeofenceManager.h pattern'ine göre implement edildi
 */
@interface TSGeofenceManager : NSObject <CLLocationManagerDelegate>

@property (copy, nullable) void (^onGeofence) (TSGeofenceEvent* event);

@property (atomic) BOOL isMoving;
@property (atomic) BOOL enabled;
@property (atomic) BOOL evaluated;
@property (atomic) BOOL isUpdatingLocation;
@property (atomic) BOOL isEvaluatingEvents;
@property (atomic) BOOL isRequestingLocation;
@property (atomic) BOOL isMonitoringSignificantChanges;
@property (atomic) BOOL willEvaluateProximity;
@property (atomic, nullable) CLLocation *lastLocation;

@property (atomic, readonly) NSMutableArray *geofencesChangeListeners;
@property (atomic, readonly) NSMutableArray *geofenceListeners;

// Event listeners
- (void)onGeofencesChange:(void (^)(TSGeofencesChangeEvent*))success;
- (void)onGeofence:(void (^)(TSGeofenceEvent*))success;
- (void)un:(NSString*)event callback:(void(^)(id))callback;
- (void)removeListeners;

- (void)start;
- (void)stop;
- (void)ready;
- (void)setLocation:(CLLocation*)location isMoving:(BOOL)isMoving;
- (void)setProximityRadius:(CLLocationDistance)radius;
- (BOOL)isMonitoringRegion:(CLCircularRegion*)region;
- (void)didBecomeStationary:(CLLocation*)location;
- (NSString*)identifierFor:(CLCircularRegion*)region;
- (void)create:(NSArray*)geofences success:(void (^)(void))success failure:(void (^)(NSString*))failure;
- (void)destroy:(NSArray*)identifiers success:(void (^)(void))success failure:(void (^)(NSString*))failure;
- (BOOL)isInfiniteMonitoring;

@end

NS_ASSUME_NONNULL_END





