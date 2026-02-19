//
//  TSCallback.m
//  RNBackgroundLocation
//
//  Callback wrapper
//  ExampleIOS/TSCallback.h pattern'ine göre
//

#import "TSCallback.h"

@implementation TSCallback

- (id)initWithSuccess:(void(^)(id))success failure:(void(^)(id))failure {
    return [self initWithSuccess:success failure:failure options:nil];
}

- (id)initWithSuccess:(void(^)(id))success failure:(void(^)(id))failure options:(NSDictionary*)options {
    self = [super init];
    if (self) {
        _success = success;
        _failure = failure;
        _options = options;
    }
    return self;
}

@end





