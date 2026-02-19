//
//  SQLiteGeofenceDAO.h
//  RNBackgroundLocation
//
//  SQLite Geofence DAO
//  Android SQLiteGeofenceDAO.java benzeri
//

#import <Foundation/Foundation.h>
@class GeofenceModel;

NS_ASSUME_NONNULL_BEGIN

@interface SQLiteGeofenceDAO : NSObject

+ (instancetype)sharedInstance;

// Get all geofences
- (NSArray<GeofenceModel *> *)all;

// Get specific geofence
- (nullable GeofenceModel *)get:(NSString *)identifier;

// Insert/Update geofence
- (BOOL)persist:(GeofenceModel *)geofence;

// Delete geofence
- (BOOL)destroy:(NSString *)identifier;

// Clear all geofences
- (BOOL)clear;

// Check if geofence exists
- (BOOL)exists:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END





