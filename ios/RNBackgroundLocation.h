//
//  RNBackgroundLocation.h
//  RNBackgroundLocation
//
//  React Native Background Location Module
//  Android RNBackgroundLocationModule.java benzeri
//

#import <Foundation/Foundation.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTInvalidating.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@class TSConfig;
@class TSLocationManager;
@class SQLiteLocationDAO;
@class SQLiteGeofenceDAO;

@interface RNBackgroundLocation : RCTEventEmitter <RCTInvalidating>

@property (nonatomic, strong) TSConfig *config;
@property (nonatomic, strong) TSLocationManager *tsLocationManager; // ExampleIOS pattern - only iOS pattern
@property (nonatomic, strong) SQLiteLocationDAO *locationDatabase;
@property (nonatomic, strong) SQLiteGeofenceDAO *geofenceDatabase;
@property (nonatomic, assign) BOOL isReady;

@end

NS_ASSUME_NONNULL_END
