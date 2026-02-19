//
//  MotionChangeEvent.m
//  RNBackgroundLocation
//
//  Motion Change Event
//  Android MotionChangeEvent.java benzeri
//

#import "MotionChangeEvent.h"
#import "LocationModel.h"

@implementation MotionChangeEvent

- (instancetype)initWithIsMoving:(BOOL)isMoving location:(LocationModel *)location {
    self = [super init];
    if (self) {
        _isMoving = isMoving;
        _location = location;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [[self.location toDictionary] mutableCopy];
    dict[@"isMoving"] = @(self.isMoving);
    return dict;
}

- (NSString *)getEventName {
    return @"motionchange";
}

@end
