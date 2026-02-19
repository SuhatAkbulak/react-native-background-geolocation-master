//
//  LocationModel.h
//  RNBackgroundLocation
//
//  Location Data Model with LOCKING support
//  Android LocationModel.java benzeri
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

// Location types (Transistorsoft TSLocation pattern)
typedef enum LocationType : NSInteger {
    LOCATION_TYPE_MOTIONCHANGE   = 0,
    LOCATION_TYPE_TRACKING       = 1,
    LOCATION_TYPE_CURRENT        = 2,
    LOCATION_TYPE_SAMPLE         = 3,
    LOCATION_TYPE_WATCH          = 4,
    LOCATION_TYPE_GEOFENCE       = 5,
    LOCATION_TYPE_HEARTBEAT      = 6
} LocationType;

@interface LocationModel : NSObject

@property (nonatomic, assign) NSInteger id;
@property (nonatomic, strong) NSString *uuid;

// Coordinates
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, assign) float accuracy;
@property (nonatomic, assign) float speed;
@property (nonatomic, assign) float heading;
@property (nonatomic, assign) double altitude;
@property (nonatomic, assign) float altitudeAccuracy;
@property (nonatomic, assign) NSTimeInterval timestamp;

// Activity
@property (nonatomic, strong, nullable) NSString *activityType;
@property (nonatomic, assign) NSInteger activityConfidence;

// Battery
@property (nonatomic, assign) float batteryLevel;
@property (nonatomic, assign) BOOL batteryIsCharging;

// Motion
@property (nonatomic, assign) BOOL isMoving;
@property (nonatomic, assign) float odometer;

// Location Type
@property (nonatomic, assign) LocationType locationType;
@property (nonatomic, strong, nullable) NSString *event; // "location" | "motionchange" | "heartbeat" | "geofence"

// Extras
@property (nonatomic, strong, nullable) NSString *extras;

// Location Source Information (iOS 15+)
@property (nonatomic, assign) BOOL isSimulatedBySoftware; // iOS 15+ - Konum simüle edilmiş mi?
@property (nonatomic, assign) BOOL isProducedByAccessory; // iOS 15+ - Harici GPS alıcısından mı?

// LOCKING mekanizması için
@property (nonatomic, assign) BOOL locked;

// Senkronizasyon durumu
@property (nonatomic, assign) BOOL synced;

// Initializers
- (instancetype)init;
- (instancetype)initWithCLLocation:(CLLocation *)location;

// JSON conversion
- (NSDictionary *)toDictionary;
+ (nullable instancetype)fromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END

