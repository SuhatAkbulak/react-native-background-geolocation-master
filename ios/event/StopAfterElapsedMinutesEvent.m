//
//  StopAfterElapsedMinutesEvent.m
//  RNBackgroundLocation
//
//  Stop After Elapsed Minutes Event
//  Android StopAfterElapsedMinutesEvent.java benzeri
//

#import "StopAfterElapsedMinutesEvent.h"

@implementation StopAfterElapsedMinutesEvent

- (instancetype)init {
    self = [super init];
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"stopped": @YES
    };
}

- (NSString *)getEventName {
    return @"stopAfterElapsedMinutes";
}

@end

