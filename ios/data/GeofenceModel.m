//
//  GeofenceModel.m
//  RNBackgroundLocation
//
//  Geofence Data Model
//  Android GeofenceModel.java benzeri
//

#import "GeofenceModel.h"

@implementation GeofenceModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _notifyOnEntry = YES;
        _notifyOnExit = YES;
        _notifyOnDwell = NO;
        _loiteringDelay = 0;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    json[@"identifier"] = self.identifier;
    json[@"latitude"] = @(self.latitude);
    json[@"longitude"] = @(self.longitude);
    json[@"radius"] = @(self.radius);
    json[@"notifyOnEntry"] = @(self.notifyOnEntry);
    json[@"notifyOnExit"] = @(self.notifyOnExit);
    json[@"notifyOnDwell"] = @(self.notifyOnDwell);
    json[@"loiteringDelay"] = @(self.loiteringDelay);
    
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
    GeofenceModel *geofence = [[GeofenceModel alloc] init];
    
    geofence.identifier = dictionary[@"identifier"];
    geofence.latitude = [dictionary[@"latitude"] doubleValue];
    geofence.longitude = [dictionary[@"longitude"] doubleValue];
    geofence.radius = [dictionary[@"radius"] floatValue];
    
    if (dictionary[@"notifyOnEntry"]) {
        geofence.notifyOnEntry = [dictionary[@"notifyOnEntry"] boolValue];
    }
    if (dictionary[@"notifyOnExit"]) {
        geofence.notifyOnExit = [dictionary[@"notifyOnExit"] boolValue];
    }
    if (dictionary[@"notifyOnDwell"]) {
        geofence.notifyOnDwell = [dictionary[@"notifyOnDwell"] boolValue];
    }
    if (dictionary[@"loiteringDelay"]) {
        geofence.loiteringDelay = [dictionary[@"loiteringDelay"] integerValue];
    }
    if (dictionary[@"extras"]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary[@"extras"] options:0 error:&error];
        if (!error) {
            geofence.extras = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    
    return geofence;
}

- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(self.latitude, self.longitude);
}

- (CLLocationDistance)radiusInMeters {
    return self.radius;
}

@end

