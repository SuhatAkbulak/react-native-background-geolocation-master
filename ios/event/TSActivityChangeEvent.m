//
//  TSActivityChangeEvent.m
//  RNBackgroundLocation
//
//  Activity Change Event - ExampleIOS/TSActivityChangeEvent.h pattern'ine göre
//

#import "TSActivityChangeEvent.h"

@implementation TSActivityChangeEvent {
    NSInteger _confidence;
    NSString *_activity;
}

- (id)initWithActivityName:(NSString*)activityName confidence:(NSInteger)confidence {
    self = [super init];
    if (self) {
        _activity = activityName;
        _confidence = confidence;
    }
    return self;
}

- (NSInteger)confidence {
    return _confidence;
}

- (NSString*)activity {
    return _activity;
}

- (NSDictionary*)toDictionary {
    return @{
        @"activity": self.activity ?: @"unknown",
        @"confidence": @(self.confidence)
    };
}

@end
