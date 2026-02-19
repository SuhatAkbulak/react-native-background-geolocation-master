//
//  LocationManager.h
//  RNBackgroundLocation
//
//  LocationManager wrapper - ExampleIOS/LocationManager.h pattern'ine göre
//  CLLocationManager'ı wrap eden sınıf
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class TSWatchPositionRequest;
@class TSCurrentPositionRequest;

NS_ASSUME_NONNULL_BEGIN

/// LocationManager wrapper class
/// ExampleIOS/LocationManager.h pattern'ine göre implement edildi
@interface LocationManager : NSObject <CLLocationManagerDelegate>

// Error codes
typedef enum tsLocationError : NSInteger {
    TS_LOCATION_ERROR_ACCEPTABLE_ACCURACY = 100,
    TS_LOCATION_ERROR_TIMEOUT = 408
} tsLocationError;

@property (readonly) NSInteger currentAttempts;
@property (atomic, nullable) NSTimer *timeoutTimer;
@property (atomic, nullable) NSTimer *watchPositionTimer;
@property (atomic) NSTimeInterval locationTimeout;

@property (atomic, readonly) BOOL isAcquiringBackgroundTime;
@property (atomic, readonly, nullable) NSTimer *preventSuspendTimer;

@property (strong, atomic, readonly) CLLocationManager* locationManager;
@property (atomic, readonly) UIBackgroundTaskIdentifier preventSuspendTask;
@property (strong, atomic, readonly, nullable) CLLocation* lastLocation;
@property (strong, atomic, readonly, nullable) CLLocation* bestLocation;
@property (atomic) NSInteger maxLocationAttempts;
@property (atomic) CLLocationDistance distanceFilter;
@property (atomic) CLLocationAccuracy desiredAccuracy;
@property (atomic) CLActivityType activityType;
@property (readonly) BOOL isUpdating;
@property (readonly) BOOL isWatchingPosition;

@property (copy, nullable) void (^locationChangedBlock) (LocationManager* manager, CLLocation* location, BOOL isSample);
@property (copy, nullable) void (^errorBlock) (LocationManager* manager, NSError* error);

- (void)watchPosition:(TSWatchPositionRequest*)request;
- (void)requestLocation;
- (void)stopWatchPosition;
- (void)startUpdatingLocation;
- (void)startUpdatingLocation:(NSInteger)samples;
- (void)startUpdatingLocation:(NSInteger)samples timeout:(NSTimeInterval)timeout;
- (void)startUpdatingLocation:(NSInteger)samples timeout:(NSTimeInterval)timeout desiredAccuracy:(CLLocationAccuracy)desiredAccuracy;
- (void)stopUpdatingLocation;

@end

NS_ASSUME_NONNULL_END





