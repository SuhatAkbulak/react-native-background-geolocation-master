//
//  TSGeofencesChangeEvent.m
//  RNBackgroundLocation
//
//  Geofences Change Event - ExampleIOS/TSGeofencesChangeEvent.h pattern'ine göre
//

#import "TSGeofencesChangeEvent.h"

@implementation TSGeofencesChangeEvent {
    NSArray *_on;
    NSArray *_off;
}

- (id)initWithOn:(NSArray*)on off:(NSArray*)off {
    self = [super init];
    if (self) {
        _on = on;
        _off = off;
    }
    return self;
}

- (NSArray*)on {
    return _on;
}

- (NSArray*)off {
    return _off;
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    if (_on) {
        NSMutableArray *onArray = [NSMutableArray array];
        for (id geofence in _on) {
            if ([geofence respondsToSelector:@selector(toDictionary)]) {
                [onArray addObject:[geofence toDictionary]];
            } else {
                [onArray addObject:geofence];
            }
        }
        json[@"on"] = onArray;
    }
    
    if (_off) {
        NSMutableArray *offArray = [NSMutableArray array];
        for (id geofence in _off) {
            if ([geofence respondsToSelector:@selector(toDictionary)]) {
                [offArray addObject:[geofence toDictionary]];
            } else {
                [offArray addObject:geofence];
            }
        }
        json[@"off"] = offArray;
    }
    
    return json;
}

@end
