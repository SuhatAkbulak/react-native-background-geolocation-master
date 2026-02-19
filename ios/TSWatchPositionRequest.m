//
//  TSWatchPositionRequest.m
//  RNBackgroundLocation
//
//  Watch Position Request - ExampleIOS/TSWatchPositionRequest.h pattern'ine göre
//

#import "TSWatchPositionRequest.h"

@implementation TSWatchPositionRequest

- (instancetype)init {
    return [self initWithSuccess:nil failure:nil];
}

- (instancetype)initWithSuccess:(void (^)(TSLocation*))success failure:(void (^)(NSError*))failure {
    return [self initWithInterval:1000 success:success failure:failure];
}

- (instancetype)initWithInterval:(double)interval
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure {
    return [self initWithInterval:interval persist:NO success:success failure:failure];
}

- (instancetype)initWithInterval:(double)interval
                        persist:(BOOL)persist
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure {
    return [self initWithInterval:interval
                          persist:persist
                   desiredAccuracy:kCLLocationAccuracyBest
                           extras:nil
                          timeout:0
                         success:success
                         failure:failure];
}

- (instancetype)initWithInterval:(double)interval
                        persist:(BOOL)persist
                 desiredAccuracy:(CLLocationAccuracy)desiredAccuracy
                         extras:(NSDictionary*)extras
                         timeout:(double)timeout
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure {
    self = [super init];
    if (self) {
        _interval = interval;
        _persist = persist;
        _desiredAccuracy = desiredAccuracy;
        _extras = extras;
        _timeout = timeout;
        _success = success;
        _failure = failure;
    }
    return self;
}

@end






