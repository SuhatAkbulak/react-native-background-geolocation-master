//
//  TSGeofence.h
//  RNBackgroundLocation
//
//  TSGeofence - ExampleIOS/TSGeofence.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TSGeofence
 * ExampleIOS/TSGeofence.h pattern'ine göre implement edildi
 */
@interface TSGeofence : NSObject

@property (nonatomic) NSString* identifier;
@property (nonatomic) CLLocationDistance radius;
@property (nonatomic) CLLocationDegrees latitude;
@property (nonatomic) CLLocationDegrees longitude;
@property (nonatomic) BOOL notifyOnEntry;
@property (nonatomic) BOOL notifyOnExit;
@property (nonatomic) BOOL notifyOnDwell;
@property (nonatomic) double loiteringDelay;
@property (nonatomic, nullable) NSDictionary* extras;
@property (nonatomic, nullable) NSArray* vertices;

- (instancetype)initWithIdentifier:(NSString*)identifier
                            radius:(CLLocationDistance)radius
                          latitude:(CLLocationDegrees)latitude
                         longitude:(CLLocationDegrees)longitude
                     notifyOnEntry:(BOOL)notifyOnEntry
                      notifyOnExit:(BOOL)notifyOnExit
                     notifyOnDwell:(BOOL)notifyOnDwell
                    loiteringDelay:(double)loiteringDelay;

- (instancetype)initWithIdentifier:(NSString*)identifier
                            radius:(CLLocationDistance)radius
                          latitude:(CLLocationDegrees)latitude
                         longitude:(CLLocationDegrees)longitude
                     notifyOnEntry:(BOOL)notifyOnEntry
                      notifyOnExit:(BOOL)notifyOnExit
                     notifyOnDwell:(BOOL)notifyOnDwell
                    loiteringDelay:(double)loiteringDelay
                            extras:(nullable NSDictionary*)extras
                          vertices:(nullable NSArray*)vertices;

- (NSDictionary*)toDictionary;
- (BOOL)isPolygon;

@end

NS_ASSUME_NONNULL_END





