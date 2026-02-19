//
//  TSLocation.h
//  RNBackgroundLocation
//
//  TSLocation - ExampleIOS/TSLocation.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

// Location types
typedef enum tsLocationType : NSInteger {
    TS_LOCATION_TYPE_MOTIONCHANGE   = 0,
    TS_LOCATION_TYPE_TRACKING       = 1,
    TS_LOCATION_TYPE_CURRENT        = 2,
    TS_LOCATION_TYPE_SAMPLE         = 3,
    TS_LOCATION_TYPE_WATCH          = 4,
    TS_LOCATION_TYPE_GEOFENCE       = 5,
    TS_LOCATION_TYPE_HEARTBEAT      = 6
} tsLocationType;

/**
 * TSLocation
 * ExampleIOS/TSLocation.h pattern'ine göre implement edildi
 */
@interface TSLocation : NSObject

/**
 * The native CLLocation instance
 */
@property (nonatomic, readonly) CLLocation* location;
/**
 * Universally unique identifier.  The uuid is used to locate the record in the database.
 */
@property (nonatomic, readonly) NSString *uuid;
/**
 * The rendered timestamp in ISO-8851 UTC format (YYYY-MM-dd HH:mm:sssZ)
 */
@property (nonatomic, readonly) NSString *timestamp;
@property (nonatomic, readonly) NSNumber *age;
/**
 * The type of location: MOTIONCHANGE|TRACKING|CURRENT|SAMPLE|WATCH|GEOFENCE|HEARTBEAT
 */
@property (nonatomic, readonly) enum tsLocationType type;
/**
 * YES when location was recorded while device is in motion; NO otherwise.
 */
@property (nonatomic, readonly) BOOL isMoving;
/**
 * Arbitrary extras data attached to the location.
 */
@property (nonatomic, readonly, nullable) NSDictionary* extras;
/**
 * For internal use only.  Geofence data rendered to NSDictionary for posting to server.
 */
@property (nonatomic, readonly, nullable) NSDictionary* geofence;
// Battery
/**
 * YES when device is plugged into power and charging
 */
@property (nonatomic, readonly) BOOL batteryIsCharging;
/**
 * The battery level between 0 (empty) and 1 (full)
 */
@property (nonatomic, readonly) NSNumber *batteryLevel;
// Activity
/**
 * Activity type rendered as string: still|on_foot|in_vehicle|running|on_bicycle
 */
@property (nonatomic, readonly, nullable) NSString *activityType;
/**
 * Confidence of activity-type estimation as % 0-100
 */
@property (nonatomic, readonly, nullable) NSNumber *activityConfidence;
// State
/**
 * YES when recorded location is a sample.
 */
@property (nonatomic, readonly) BOOL isSample;
@property (nonatomic, readonly) BOOL mock;
/**
 * YES when this location was provided to a heartbeat event
 */
@property (nonatomic, readonly) BOOL isHeartbeat;
/**
 * The current value of the odometer in meters
 */
@property (nonatomic, readonly) NSNumber *odometer;
/**
 * The event associated with this location: location|motionchange|heartbeat|providerchange
 */
@property (nonatomic, readonly, nullable) NSString *event;

- (instancetype)initWithLocation:(CLLocation*)location;
- (instancetype)initWithLocation:(CLLocation*)location type:(enum tsLocationType)type extras:(nullable NSDictionary*)extras;
- (instancetype)initWithLocation:(CLLocation*)location geofence:(nullable NSDictionary*)geofenceData;

- (void)setEvent:(nullable NSString*)event;
- (void)setIsMoving:(BOOL)isMoving;
- (void)setOdometer:(NSNumber*)odometer;

/**
 * Render location-data as JSON string
 */
- (NSData*)toJson:(NSError**)error;
/**
 * Render location-data as NSDictionary
 */
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
