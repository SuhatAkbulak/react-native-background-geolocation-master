//
//  TSPowerSaveChangeEvent.m
//  RNBackgroundLocation
//
//  Power Save Change Event
//  Transistorsoft TSPowerSaveChangeEvent.m benzeri
//

#import "TSPowerSaveChangeEvent.h"

@implementation TSPowerSaveChangeEvent

- (instancetype)initWithIsPowerSaveMode:(BOOL)isPowerSaveMode {
    self = [super init];
    if (self) {
        _isPowerSaveMode = isPowerSaveMode;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"isPowerSaveMode": @(self.isPowerSaveMode)
    };
}

@end





