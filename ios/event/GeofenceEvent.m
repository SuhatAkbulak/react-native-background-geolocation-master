//
//  GeofenceEvent.m
//  RNBackgroundLocation
//
//  Geofence Event
//  Android GeofenceEvent.java benzeri
//

#import "GeofenceEvent.h"
#import "LocationModel.h"

@implementation GeofenceEvent

- (instancetype)initWithIdentifier:(NSString *)identifier 
                             action:(GeofenceAction)action 
                           location:(LocationModel *)location {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _action = action;
        _location = location;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"identifier"] = self.identifier;
    dict[@"action"] = [self actionString];
    dict[@"location"] = [self.location toDictionary];
    return dict;
}

- (NSString *)getEventName {
    return @"geofence";
}

- (NSString *)actionString {
    switch (self.action) {
        case GeofenceActionEnter:
            return @"ENTER";
        case GeofenceActionExit:
            return @"EXIT";
        case GeofenceActionDwell:
            return @"DWELL";
        default:
            return @"UNKNOWN";
    }
}

@end
