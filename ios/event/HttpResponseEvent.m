//
//  HttpResponseEvent.m
//  RNBackgroundLocation
//
//  HTTP Response Event
//  Android HttpResponseEvent.java benzeri
//

#import "HttpResponseEvent.h"

@implementation HttpResponseEvent

- (instancetype)initWithStatusCode:(NSInteger)status 
                            success:(BOOL)success 
                       responseText:(NSString *)responseText {
    self = [super init];
    if (self) {
        _statusCode = status;
        _status = status;
        _success = success;
        _isSuccess = success;
        _responseText = responseText ?: @"";
        _requestData = nil;
        _responseData = nil;
        _error = nil;
        _locations = nil;
    }
    return self;
}

- (instancetype)initWithStatusCode:(NSInteger)statusCode
                         requestData:(NSDictionary*)requestData
                        responseData:(NSData*)responseData
                               error:(NSError*)error {
    self = [super init];
    if (self) {
        _statusCode = statusCode;
        _status = statusCode;
        _requestData = requestData;
        _responseData = responseData;
        _error = error;
        _success = (statusCode >= 200 && statusCode < 300) && (error == nil);
        _isSuccess = _success;
        
        if (responseData) {
            _responseText = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] ?: @"";
        } else {
            _responseText = @"";
        }
        
        _locations = nil;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"status": @(self.status),
        @"success": @(self.success),
        @"responseText": self.responseText
    };
}

- (NSString *)getEventName {
    return @"http";
}

@end
