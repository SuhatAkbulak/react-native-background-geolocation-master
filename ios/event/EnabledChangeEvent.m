//
//  EnabledChangeEvent.m
//  RNBackgroundLocation
//
//  Enabled Change Event
//  Android EnabledChangeEvent.java benzeri
//

#import "EnabledChangeEvent.h"

@implementation EnabledChangeEvent

- (instancetype)initWithEnabled:(BOOL)enabled {
    self = [super init];
    if (self) {
        _enabled = enabled;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"enabled": @(self.enabled)
    };
}

- (NSString *)getEventName {
    return @"enabledchange";
}

@end





