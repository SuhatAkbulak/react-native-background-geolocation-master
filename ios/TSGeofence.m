//
//  TSGeofence.m
//  RNBackgroundLocation
//
//  TSGeofence - ExampleIOS/TSGeofence.h pattern'ine göre
//

#import "TSGeofence.h"

@implementation TSGeofence

- (instancetype)initWithIdentifier:(NSString*)identifier
                            radius:(CLLocationDistance)radius
                          latitude:(CLLocationDegrees)latitude
                         longitude:(CLLocationDegrees)longitude
                     notifyOnEntry:(BOOL)notifyOnEntry
                      notifyOnExit:(BOOL)notifyOnExit
                     notifyOnDwell:(BOOL)notifyOnDwell
                    loiteringDelay:(double)loiteringDelay {
    return [self initWithIdentifier:identifier
                              radius:radius
                            latitude:latitude
                           longitude:longitude
                       notifyOnEntry:notifyOnEntry
                        notifyOnExit:notifyOnExit
                       notifyOnDwell:notifyOnDwell
                      loiteringDelay:loiteringDelay
                              extras:nil
                            vertices:nil];
}

- (instancetype)initWithIdentifier:(NSString*)identifier
                            radius:(CLLocationDistance)radius
                          latitude:(CLLocationDegrees)latitude
                         longitude:(CLLocationDegrees)longitude
                     notifyOnEntry:(BOOL)notifyOnEntry
                      notifyOnExit:(BOOL)notifyOnExit
                     notifyOnDwell:(BOOL)notifyOnDwell
                    loiteringDelay:(double)loiteringDelay
                            extras:(NSDictionary*)extras
                          vertices:(NSArray*)vertices {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _radius = radius;
        _latitude = latitude;
        _longitude = longitude;
        _notifyOnEntry = notifyOnEntry;
        _notifyOnExit = notifyOnExit;
        _notifyOnDwell = notifyOnDwell;
        _loiteringDelay = loiteringDelay;
        _extras = extras;
        _vertices = vertices;
    }
    return self;
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    json[@"identifier"] = self.identifier;
    json[@"radius"] = @(self.radius);
    json[@"latitude"] = @(self.latitude);
    json[@"longitude"] = @(self.longitude);
    json[@"notifyOnEntry"] = @(self.notifyOnEntry);
    json[@"notifyOnExit"] = @(self.notifyOnExit);
    json[@"notifyOnDwell"] = @(self.notifyOnDwell);
    json[@"loiteringDelay"] = @(self.loiteringDelay);
    
    if (self.extras) {
        json[@"extras"] = self.extras;
    }
    
    if (self.vertices) {
        json[@"vertices"] = self.vertices;
    }
    
    return json;
}

- (BOOL)isPolygon {
    return self.vertices != nil && self.vertices.count > 0;
}

@end

