//
//  TSEnabledChangeEvent.m
//  RNBackgroundLocation
//
//  Enabled Change Event - ExampleIOS/TSEnabledChangeEvent.h pattern'ine göre
//

#import "TSEnabledChangeEvent.h"

@implementation TSEnabledChangeEvent {
    BOOL _enabled;
}

- (id)initWithEnabled:(BOOL)enabled {
    self = [super init];
    if (self) {
        _enabled = enabled;
    }
    return self;
}

- (BOOL)enabled {
    return _enabled;
}

- (NSDictionary*)toDictionary {
    return @{
        @"enabled": @(_enabled)
    };
}

@end
