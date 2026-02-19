//
//  TSHttpEvent.m
//  RNBackgroundLocation
//
//  HTTP Event - ExampleIOS/TSHttpEvent.h pattern'ine göre
//

#import "TSHttpEvent.h"

@implementation TSHttpEvent {
    BOOL _isSuccess;
    NSInteger _statusCode;
    NSDictionary *_requestData;
    NSString *_responseText;
    NSError *_error;
}

- (id)initWithStatusCode:(NSInteger)statusCode requestData:(NSDictionary*)requestData responseData:(NSData*)responseData error:(NSError*)error {
    self = [super init];
    if (self) {
        _statusCode = statusCode;
        _requestData = requestData;
        _error = error;
        
        // Determine success (2xx status codes)
        _isSuccess = (statusCode >= 200 && statusCode < 300) && error == nil;
        
        // Parse response text
        if (responseData) {
            _responseText = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        }
    }
    return self;
}

- (BOOL)isSuccess {
    return _isSuccess;
}

- (NSInteger)statusCode {
    return _statusCode;
}

- (NSDictionary*)requestData {
    return _requestData;
}

- (NSString*)responseText {
    return _responseText;
}

- (NSError*)error {
    return _error;
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    json[@"success"] = @(_isSuccess);
    json[@"status"] = @(_statusCode);
    
    if (self.requestData) {
        json[@"requestData"] = self.requestData;
    }
    
    if (self.responseText) {
        json[@"responseText"] = self.responseText;
    }
    
    if (self.error) {
        json[@"error"] = @{
            @"code": @(self.error.code),
            @"domain": self.error.domain,
            @"localizedDescription": self.error.localizedDescription ?: @""
        };
    }
    
    return json;
}

@end
