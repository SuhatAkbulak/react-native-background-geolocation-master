//
//  TSGeofenceEvent.h
//  RNBackgroundLocation
//
//  Geofence Event - ExampleIOS/TSGeofenceEvent.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "TSLocation.h"
#import "TSGeofence.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * TSGeofenceEvent
 * ExampleIOS/TSGeofenceEvent.h pattern'ine göre implement edildi
 */
@interface TSGeofenceEvent : NSObject

/// The location associated with this geofence event.
@property (nonatomic, readonly) TSLocation* location;
/// The triggered geofence
@property (nonatomic, readonly) TSGeofence* geofence;
/// The region instance.
@property (nonatomic, readonly) CLCircularRegion* region;
@property (nonatomic) NSDate *timestamp;
/// The geofence transition (eg: "ENTER", "EXIT", "DWELL"
@property (nonatomic, readonly) NSString* action;
@property (nonatomic, readonly) BOOL isLoitering;
@property (nonatomic, readonly) BOOL isFinishedLoitering;

- (instancetype)initWithGeofence:(TSGeofence*)geofence region:(CLCircularRegion*)circularRegion action:(NSString*)actionName;
- (instancetype)initWithGeofence:(TSGeofence*)geofence action:(NSString*)actionName;

- (void)setLocation:(TSLocation*)location;
- (void)startLoiteringAt:(CLLocation*)location callback:(void (^)(void))callback;
- (BOOL)isLoiteringAt:(CLLocation*)location;
- (void)setTriggerLocation:(CLLocation*)location;
- (void)cancel;

- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
