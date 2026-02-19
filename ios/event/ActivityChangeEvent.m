//
//  ActivityChangeEvent.m
//  RNBackgroundLocation
//
//  Activity Change Event
//  Android ActivityChangeEvent.java benzeri
//

#import "ActivityChangeEvent.h"

static NSString *const EVENT_NAME = @"activitychange";

@implementation ActivityChangeEvent

- (instancetype)initWithActivity:(NSString *)activity confidence:(NSInteger)confidence {
    self = [super init];
    if (self) {
        _activity = activity;
        _confidence = confidence;
        _timestamp = [[NSDate date] timeIntervalSince1970] * 1000; // milliseconds
    }
    return self;
}

- (NSString *)getEventName {
    return EVENT_NAME;
}

- (NSDictionary *)toDictionary {
    return @{
        @"activity": self.activity ?: @"unknown",
        @"confidence": @(self.confidence),
        @"timestamp": @(self.timestamp)
    };
}

@end





