//
//  HeartbeatEvent.m
//  RNBackgroundLocation
//
//  Heartbeat Event
//  Android HeartbeatEvent.java benzeri
//

#import "HeartbeatEvent.h"

static NSString *const EVENT_NAME = @"heartbeat";

@implementation HeartbeatEvent

- (instancetype)init {
    self = [super init];
    if (self) {
        _location = @{};
    }
    return self;
}

- (instancetype)initWithLocation:(NSDictionary *)location {
    self = [super init];
    if (self) {
        _location = location ?: @{};
    }
    return self;
}

- (NSString *)getEventName {
    return EVENT_NAME;
}

- (NSDictionary *)toDictionary {
    return @{
        @"location": self.location ?: @{}
    };
}

@end





