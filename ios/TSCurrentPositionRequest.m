//
//  TSCurrentPositionRequest.m
//  RNBackgroundLocation
//
//  Current Position Request - ExampleIOS/TSCurrentPositionRequest.h pattern'ine göre
//

#import "TSCurrentPositionRequest.h"

@implementation TSCurrentPositionRequest

- (instancetype)init {
    return [self initWithSuccess:nil failure:nil];
}

- (instancetype)initWithSuccess:(void (^)(TSLocation*))success failure:(void (^)(NSError*))failure {
    return [self initWithPersist:NO success:success failure:failure];
}

- (instancetype)initWithPersist:(BOOL)persist
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure {
    return [self initWithPersist:persist samples:1 success:success failure:failure];
}

- (instancetype)initWithPersist:(BOOL)persist
                        samples:(int)samples
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure {
    return [self initWithTimeout:60
                     maximumAge:0
                        persist:persist
                        samples:samples
                desiredAccuracy:kCLLocationAccuracyBest
                         extras:nil
                        success:success
                        failure:failure];
}

- (instancetype)initWithTimeout:(int)timeout
           maximumAge:(double)maximumAge
              persist:(BOOL)persist
              samples:(int)samples
      desiredAccuracy:(CLLocationAccuracy)desiredAccuracy
               extras:(NSDictionary*)extras
              success:(void (^)(TSLocation*))success
              failure:(void (^)(NSError*))failure {
    self = [super init];
    if (self) {
        _timeout = timeout;
        _maximumAge = maximumAge;
        _persist = persist;
        _samples = samples;
        _desiredAccuracy = desiredAccuracy;
        _extras = extras;
        _success = success;
        _failure = failure;
    }
    return self;
}

@end






