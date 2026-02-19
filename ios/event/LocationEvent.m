//
//  LocationEvent.m
//  RNBackgroundLocation
//
//  Location Event
//  Android LocationEvent.java benzeri
//

#import "LocationEvent.h"
#import "LocationModel.h"

@implementation LocationEvent

- (instancetype)initWithLocation:(LocationModel *)location {
    self = [super init];
    if (self) {
        _location = location;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return [self.location toDictionary];
}

- (NSString *)getEventName {
    return @"location";
}

@end
