//
//  TSHeartbeatEvent.m
//  RNBackgroundLocation
//
//  Heartbeat Event - ExampleIOS/TSHeartbeatEvent.h pattern'ine göre
//

#import "TSHeartbeatEvent.h"
#import "TSLocation.h"

@implementation TSHeartbeatEvent {
    TSLocation *_location;
}

- (id)initWithLocation:(CLLocation*)location {
    self = [super init];
    if (self) {
        _location = [[TSLocation alloc] initWithLocation:location type:TS_LOCATION_TYPE_HEARTBEAT extras:nil];
        [_location setEvent:@"heartbeat"];
    }
    return self;
}

- (TSLocation*)location {
    return _location;
}

- (NSDictionary*)toDictionary {
    return [self.location toDictionary];
}

@end
