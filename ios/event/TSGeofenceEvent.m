//
//  TSGeofenceEvent.m
//  RNBackgroundLocation
//
//  Geofence Event - ExampleIOS/TSGeofenceEvent.h pattern'ine göre
//

#import "TSGeofenceEvent.h"

@implementation TSGeofenceEvent {
    TSLocation *_location;
    TSGeofence *_geofence;
    CLCircularRegion *_region;
    NSDate *_timestamp;
    NSString *_action;
    BOOL _isLoitering;
    BOOL _isFinishedLoitering;
    CLLocation *_triggerLocation;
    NSTimer *_loiteringTimer;
    void (^_loiteringCallback)(void);
}

- (instancetype)initWithGeofence:(TSGeofence*)geofence region:(CLCircularRegion*)circularRegion action:(NSString*)actionName {
    self = [super init];
    if (self) {
        _geofence = geofence;
        _region = circularRegion;
        _action = actionName;
        _timestamp = [NSDate date];
        _isLoitering = NO;
        _isFinishedLoitering = NO;
    }
    return self;
}

- (instancetype)initWithGeofence:(TSGeofence*)geofence action:(NSString*)actionName {
    // Create region from geofence
    CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(geofence.latitude, geofence.longitude)
                                                                 radius:geofence.radius
                                                             identifier:geofence.identifier];
    return [self initWithGeofence:geofence region:region action:actionName];
}

- (TSLocation*)location {
    return _location;
}

- (void)setLocation:(TSLocation*)location {
    _location = location;
}

- (TSGeofence*)geofence {
    return _geofence;
}

- (CLCircularRegion*)region {
    return _region;
}

- (NSDate*)timestamp {
    return _timestamp;
}

- (void)setTimestamp:(NSDate*)timestamp {
    _timestamp = timestamp;
}

- (NSString*)action {
    return _action;
}

- (BOOL)isLoitering {
    return _isLoitering;
}

- (BOOL)isFinishedLoitering {
    return _isFinishedLoitering;
}

- (void)startLoiteringAt:(CLLocation*)location callback:(void (^)(void))callback {
    _isLoitering = YES;
    _triggerLocation = location;
    _loiteringCallback = callback;
    
    // Start loitering timer if geofence has loitering delay
    if (_geofence.loiteringDelay > 0) {
        NSTimeInterval delay = _geofence.loiteringDelay;
        _loiteringTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                           target:self
                                                         selector:@selector(onLoiteringTimer:)
                                                         userInfo:nil
                                                          repeats:NO];
    } else {
        // No delay, immediately finish
        _isFinishedLoitering = YES;
        if (callback) {
            callback();
        }
    }
}

- (void)onLoiteringTimer:(NSTimer*)timer {
    _isFinishedLoitering = YES;
    if (_loiteringCallback) {
        _loiteringCallback();
    }
}

- (BOOL)isLoiteringAt:(CLLocation*)location {
    if (!_isLoitering || !_triggerLocation) {
        return NO;
    }
    
    // Check if still within geofence
    return [_region containsCoordinate:location.coordinate];
}

- (void)setTriggerLocation:(CLLocation*)location {
    _triggerLocation = location;
}

- (void)cancel {
    if (_loiteringTimer) {
        [_loiteringTimer invalidate];
        _loiteringTimer = nil;
    }
    _isLoitering = NO;
    _isFinishedLoitering = NO;
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    json[@"action"] = self.action;
    json[@"identifier"] = self.geofence.identifier;
    
    if (self.location) {
        json[@"location"] = [self.location toDictionary];
    }
    
    if (self.geofence) {
        json[@"geofence"] = [self.geofence toDictionary];
    }
    
    if (self.timestamp) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS'Z'";
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        json[@"timestamp"] = [formatter stringFromDate:self.timestamp];
    }
    
    return json;
}

- (void)dealloc {
    [self cancel];
}

@end
