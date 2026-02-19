//
//  LocationModel.m
//  RNBackgroundLocation
//
//  Location Data Model with LOCKING support
//  Android LocationModel.java benzeri
//

#import "LocationModel.h"

@implementation LocationModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _uuid = [[NSUUID UUID] UUIDString];
        _timestamp = [[NSDate date] timeIntervalSince1970] * 1000; // milliseconds
        _locked = NO;
        _synced = NO;
        _isMoving = NO;
        _odometer = 0.0;
        _batteryLevel = 0.0;
        _batteryIsCharging = NO;
        _locationType = LOCATION_TYPE_TRACKING; // Default type
        _event = @"location"; // Default event
    }
    return self;
}

- (instancetype)initWithCLLocation:(CLLocation *)location {
    self = [self init];
    if (self) {
        _latitude = location.coordinate.latitude;
        _longitude = location.coordinate.longitude;
        _accuracy = location.horizontalAccuracy;
        _speed = location.speed;
        _heading = location.course;
        _altitude = location.altitude;
        _altitudeAccuracy = location.verticalAccuracy;
        _timestamp = [location.timestamp timeIntervalSince1970] * 1000; // milliseconds
        
        // CRITICAL: iOS 15+ - Extract location source information for debugging
        // This helps identify if location is simulated (test/simulator) or from external GPS
        if (@available(iOS 15.0, *)) {
            CLLocationSourceInformation *sourceInfo = location.sourceInformation;
            if (sourceInfo) {
                _isSimulatedBySoftware = sourceInfo.isSimulatedBySoftware;
                _isProducedByAccessory = sourceInfo.isProducedByAccessory;
            } else {
                _isSimulatedBySoftware = NO;
                _isProducedByAccessory = NO;
            }
        } else {
            _isSimulatedBySoftware = NO;
            _isProducedByAccessory = NO;
        }
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    json[@"uuid"] = self.uuid;
    json[@"timestamp"] = @(self.timestamp);
    json[@"is_moving"] = @(self.isMoving);
    json[@"odometer"] = @(self.odometer);
    
    // Location Type ()
    json[@"type"] = @(self.locationType);
    if (self.event) {
        json[@"event"] = self.event;
    }
    
    // Coordinates
    NSMutableDictionary *coords = [NSMutableDictionary dictionary];
    coords[@"latitude"] = @(self.latitude);
    coords[@"longitude"] = @(self.longitude);
    coords[@"accuracy"] = @(self.accuracy);
    coords[@"speed"] = @(self.speed);
    coords[@"heading"] = @(self.heading);
    coords[@"altitude"] = @(self.altitude);
    coords[@"altitude_accuracy"] = @(self.altitudeAccuracy);
    json[@"coords"] = coords;
    
    // Activity
    if (self.activityType) {
        NSMutableDictionary *activity = [NSMutableDictionary dictionary];
        activity[@"type"] = self.activityType;
        activity[@"confidence"] = @(self.activityConfidence);
        json[@"activity"] = activity;
    }
    
    // Battery
    NSMutableDictionary *battery = [NSMutableDictionary dictionary];
    battery[@"level"] = @(self.batteryLevel);
    battery[@"is_charging"] = @(self.batteryIsCharging);
    json[@"battery"] = battery;
    
    // Extras
    if (self.extras && self.extras.length > 0) {
        NSData *data = [self.extras dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            NSError *error;
            NSDictionary *extrasDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!error) {
                json[@"extras"] = extrasDict;
            }
        }
    }
    
    return json;
}

+ (nullable instancetype)fromDictionary:(NSDictionary *)dictionary {
    LocationModel *location = [[LocationModel alloc] init];
    
    if (dictionary[@"uuid"]) {
        location.uuid = dictionary[@"uuid"];
    }
    if (dictionary[@"timestamp"]) {
        location.timestamp = [dictionary[@"timestamp"] doubleValue];
    }
    if (dictionary[@"is_moving"]) {
        location.isMoving = [dictionary[@"is_moving"] boolValue];
    }
    if (dictionary[@"odometer"]) {
        location.odometer = [dictionary[@"odometer"] floatValue];
    }
    
    // Location Type
    if (dictionary[@"type"]) {
        location.locationType = [dictionary[@"type"] integerValue];
    }
    if (dictionary[@"event"]) {
        location.event = dictionary[@"event"];
    }
    
    // Coordinates
    if (dictionary[@"coords"]) {
        NSDictionary *coords = dictionary[@"coords"];
        location.latitude = [coords[@"latitude"] doubleValue];
        location.longitude = [coords[@"longitude"] doubleValue];
        location.accuracy = [coords[@"accuracy"] floatValue];
        location.speed = [coords[@"speed"] ?: @0 floatValue];
        location.heading = [coords[@"heading"] ?: @0 floatValue];
        location.altitude = [coords[@"altitude"] ?: @0 doubleValue];
        location.altitudeAccuracy = [coords[@"altitude_accuracy"] ?: @0 floatValue];
    }
    
    // Activity
    if (dictionary[@"activity"]) {
        NSDictionary *activity = dictionary[@"activity"];
        location.activityType = activity[@"type"];
        location.activityConfidence = [activity[@"confidence"] integerValue];
    }
    
    // Battery
    if (dictionary[@"battery"]) {
        NSDictionary *battery = dictionary[@"battery"];
        location.batteryLevel = [battery[@"level"] floatValue];
        location.batteryIsCharging = [battery[@"is_charging"] boolValue];
    }
    
    // Extras
    if (dictionary[@"extras"]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary[@"extras"] options:0 error:&error];
        if (!error) {
            location.extras = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    
    return location;
}

@end

