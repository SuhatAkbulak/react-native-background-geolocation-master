//
//  TSAuthorizationEvent.m
//  RNBackgroundLocation
//
//  Authorization Event
//  Transistorsoft TSAuthorizationEvent.m benzeri (sadeleştirilmiş)
//

#import "TSAuthorizationEvent.h"

@implementation TSAuthorizationEvent

- (instancetype)initWithResponse:(NSDictionary *)response status:(NSInteger)status {
    self = [super init];
    if (self) {
        _status = status;
        _response = response;
        _error = nil;
    }
    return self;
}

- (instancetype)initWithError:(NSError *)error status:(NSInteger)status {
    self = [super init];
    if (self) {
        _status = status;
        _error = error;
        _response = nil;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"status"] = @(_status);
    if (_response) {
        dict[@"response"] = _response;
    }
    if (_error) {
        dict[@"error"] = _error.localizedDescription ?: @"Unknown error";
    }
    return dict;
}

@end

