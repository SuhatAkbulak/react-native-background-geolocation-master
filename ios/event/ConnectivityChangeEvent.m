//
//  ConnectivityChangeEvent.m
//  RNBackgroundLocation
//
//  Connectivity Change Event
//  Android ConnectivityChangeEvent.java benzeri
//

#import "ConnectivityChangeEvent.h"

@implementation ConnectivityChangeEvent

- (instancetype)initWithConnected:(BOOL)connected {
    self = [super init];
    if (self) {
        _connected = connected;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"connected": @(self.connected)
    };
}

- (NSString *)getEventName {
    return @"connectivitychange";
}

@end





