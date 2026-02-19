//
//  TSLocation.m
//  RNBackgroundLocation
//
//  TSLocation - ExampleIOS/TSLocation.h pattern'ine göre
//

#import "TSLocation.h"
#import <UIKit/UIDevice.h>
#import "util/TSDeviceInfo.h"

@implementation TSLocation {
    CLLocation *_location;
    NSString *_uuid;
    NSString *_timestamp;
    NSNumber *_age;
    enum tsLocationType _type;
    BOOL _isMoving;
    NSDictionary *_extras;
    NSDictionary *_geofence;
    BOOL _batteryIsCharging;
    NSNumber *_batteryLevel;
    NSString *_activityType;
    NSNumber *_activityConfidence;
    BOOL _isSample;
    BOOL _mock;
    BOOL _isHeartbeat;
    NSNumber *_odometer;
    NSString *_event;
}

- (instancetype)initWithLocation:(CLLocation*)location {
    return [self initWithLocation:location type:TS_LOCATION_TYPE_TRACKING extras:nil];
}

- (instancetype)initWithLocation:(CLLocation*)location type:(enum tsLocationType)type extras:(NSDictionary*)extras {
    self = [super init];
    if (self) {
        _location = location;
        _uuid = [[NSUUID UUID] UUIDString];
        
        // ISO-8601 UTC format timestamp
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        _timestamp = [formatter stringFromDate:location.timestamp];
        
        // Age in seconds
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:location.timestamp];
        _age = @(age);
        
        _type = type;
        _isMoving = NO; // Will be set by caller
        _extras = extras;
        _geofence = nil;
        
        // Battery info
        UIDevice *device = [UIDevice currentDevice];
        device.batteryMonitoringEnabled = YES;
        _batteryIsCharging = device.batteryState == UIDeviceBatteryStateCharging;
        _batteryLevel = @(device.batteryLevel);
        
        // Activity (will be set by caller if available)
        _activityType = nil;
        _activityConfidence = nil;
        
        _isSample = (type == TS_LOCATION_TYPE_SAMPLE);
        _mock = NO;
        _isHeartbeat = (type == TS_LOCATION_TYPE_HEARTBEAT);
        _odometer = @0.0; // Will be set by caller
        _event = @"location"; // Default, will be set by caller
    }
    return self;
}

- (instancetype)initWithLocation:(CLLocation*)location geofence:(NSDictionary*)geofenceData {
    self = [self initWithLocation:location type:TS_LOCATION_TYPE_GEOFENCE extras:nil];
    if (self) {
        _geofence = geofenceData;
        _event = @"geofence";
    }
    return self;
}

- (CLLocation*)location {
    return _location;
}

- (NSString*)uuid {
    return _uuid;
}

- (NSString*)timestamp {
    return _timestamp;
}

- (NSNumber*)age {
    return _age;
}

- (enum tsLocationType)type {
    return _type;
}

- (BOOL)isMoving {
    return _isMoving;
}

- (void)setIsMoving:(BOOL)isMoving {
    _isMoving = isMoving;
}

- (NSDictionary*)extras {
    return _extras;
}

- (NSDictionary*)geofence {
    return _geofence;
}

- (BOOL)batteryIsCharging {
    return _batteryIsCharging;
}

- (NSNumber*)batteryLevel {
    return _batteryLevel;
}

- (NSString*)activityType {
    return _activityType;
}

- (void)setActivityType:(NSString*)activityType {
    _activityType = activityType;
}

- (NSNumber*)activityConfidence {
    return _activityConfidence;
}

- (void)setActivityConfidence:(NSNumber*)activityConfidence {
    _activityConfidence = activityConfidence;
}

- (BOOL)isSample {
    return _isSample;
}

- (BOOL)mock {
    return _mock;
}

- (BOOL)isHeartbeat {
    return _isHeartbeat;
}

- (NSNumber*)odometer {
    return _odometer;
}

- (void)setOdometer:(NSNumber*)odometer {
    _odometer = odometer;
}

- (NSString*)event {
    return _event;
}

- (void)setEvent:(NSString*)event {
    _event = event;
}

- (NSData*)toJson:(NSError**)error {
    NSDictionary *dict = [self toDictionary];
    return [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:error];
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    json[@"uuid"] = self.uuid;
    json[@"timestamp"] = self.timestamp;
    json[@"age"] = self.age;
    json[@"type"] = @(self.type);
    json[@"is_moving"] = @(self.isMoving);
    json[@"is_sample"] = @(self.isSample);
    json[@"mock"] = @(self.mock);
    json[@"is_heartbeat"] = @(self.isHeartbeat);
    
    if (self.odometer) {
        json[@"odometer"] = self.odometer;
    }
    
    if (self.event) {
        json[@"event"] = self.event;
    }
    
    // Coordinates
    NSMutableDictionary *coords = [NSMutableDictionary dictionary];
    coords[@"latitude"] = @(self.location.coordinate.latitude);
    coords[@"longitude"] = @(self.location.coordinate.longitude);
    coords[@"accuracy"] = @(self.location.horizontalAccuracy);
    coords[@"speed"] = @(self.location.speed);
    coords[@"heading"] = @(self.location.course);
    coords[@"altitude"] = @(self.location.altitude);
    coords[@"altitude_accuracy"] = @(self.location.verticalAccuracy);
    json[@"coords"] = coords;
    
    // Activity
    if (self.activityType) {
        NSMutableDictionary *activity = [NSMutableDictionary dictionary];
        activity[@"type"] = self.activityType;
        if (self.activityConfidence) {
            activity[@"confidence"] = self.activityConfidence;
        }
        json[@"activity"] = activity;
    }
    
    // Battery
    NSMutableDictionary *battery = [NSMutableDictionary dictionary];
    battery[@"level"] = self.batteryLevel;
    battery[@"is_charging"] = @(self.batteryIsCharging);
    json[@"battery"] = battery;
    
    // Extras
    if (self.extras) {
        json[@"extras"] = self.extras;
    }
    
    // Geofence
    if (self.geofence) {
        json[@"geofence"] = self.geofence;
    }
    
    return json;
}

@end






