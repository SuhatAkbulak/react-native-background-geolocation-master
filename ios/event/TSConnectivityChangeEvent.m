//
//  TSConnectivityChangeEvent.m
//  RNBackgroundLocation
//
//  Connectivity Change Event - ExampleIOS pattern'ine göre
//

#import "TSConnectivityChangeEvent.h"

@implementation TSConnectivityChangeEvent {
    BOOL _connected;
}

- (id)initWithConnected:(BOOL)connected {
    self = [super init];
    if (self) {
        _connected = connected;
    }
    return self;
}

- (BOOL)connected {
    return _connected;
}

- (NSDictionary*)toDictionary {
    return @{
        @"connected": @(_connected)
    };
}

@end
