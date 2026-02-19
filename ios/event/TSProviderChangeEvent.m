//
//  TSProviderChangeEvent.m
//  RNBackgroundLocation
//
//  Provider Change Event - ExampleIOS/TSProviderChangeEvent.h pattern'ine göre
//

#import "TSProviderChangeEvent.h"

@implementation TSProviderChangeEvent {
    CLAuthorizationStatus _status;
    NSInteger _accuracyAuthorization;
    BOOL _gps;
    BOOL _network;
    BOOL _enabled;
    CLLocationManager* _manager;
}

- (id)initWithManager:(CLLocationManager*)manager status:(CLAuthorizationStatus)status authorizationRequest:(NSString*)authorizationRequest {
    self = [super init];
    if (self) {
        _manager = manager;
        _status = status;
        _enabled = (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse);
        _gps = YES; // iOS'ta GPS her zaman mevcut
        _network = YES; // iOS'ta network location her zaman mevcut
        
        // iOS 14+ accuracy authorization
        if (@available(iOS 14.0, *)) {
            _accuracyAuthorization = (NSInteger)manager.accuracyAuthorization;
        } else {
            _accuracyAuthorization = 0; // Full accuracy (pre-iOS 14)
        }
    }
    return self;
}

- (CLAuthorizationStatus)status {
    return _status;
}

- (NSInteger)accuracyAuthorization {
    return _accuracyAuthorization;
}

- (BOOL)gps {
    return _gps;
}

- (BOOL)network {
    return _network;
}

- (BOOL)enabled {
    return _enabled;
}

- (CLLocationManager*)manager {
    return _manager;
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"status"] = @((NSInteger)_status);
    json[@"accuracyAuthorization"] = @(_accuracyAuthorization);
    json[@"gps"] = @(_gps);
    json[@"network"] = @(_network);
    json[@"enabled"] = @(_enabled);
    return json;
}

@end
