//
//  GeofenceModel.h
//  RNBackgroundLocation
//
//  Geofence Data Model
//  Android GeofenceModel.java benzeri
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GeofenceModel : NSObject

@property (nonatomic, assign) NSInteger id;
@property (nonatomic, strong) NSString *identifier;

@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, assign) float radius;

@property (nonatomic, assign) BOOL notifyOnEntry;
@property (nonatomic, assign) BOOL notifyOnExit;
@property (nonatomic, assign) BOOL notifyOnDwell;
@property (nonatomic, assign) NSInteger loiteringDelay; // milliseconds

@property (nonatomic, strong, nullable) NSString *extras;

// Initializers
- (instancetype)init;

// JSON conversion
- (NSDictionary *)toDictionary;
+ (nullable instancetype)fromDictionary:(NSDictionary *)dictionary;

// CLLocationRegion conversion
- (CLLocationCoordinate2D)coordinate;
- (CLLocationDistance)radiusInMeters;

@end

NS_ASSUME_NONNULL_END





