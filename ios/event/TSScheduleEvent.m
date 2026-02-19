//
//  TSScheduleEvent.m
//  RNBackgroundLocation
//
//  Schedule Event - ExampleIOS/TSScheduleEvent.h pattern'ine göre
//

#import "TSScheduleEvent.h"
#import "TSSchedule.h"

@implementation TSScheduleEvent {
    TSSchedule *_schedule;
    NSDictionary *_state;
}

- (id)initWithSchedule:(TSSchedule*)schedule state:(NSDictionary*)state {
    self = [super init];
    if (self) {
        _schedule = schedule;
        _state = state;
    }
    return self;
}

- (TSSchedule*)schedule {
    return _schedule;
}

- (NSDictionary*)state {
    return _state;
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    if (_schedule) {
        json[@"schedule"] = [_schedule toDictionary];
    }
    if (_state) {
        json[@"state"] = _state;
    }
    return json;
}

@end
