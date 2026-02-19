//
//  HttpResponse.m
//  RNBackgroundLocation
//
//  HTTP Response wrapper
//  ExampleIOS/HttpResponse.h pattern'ine göre
//

#import "HttpResponse.h"

@implementation HttpResponse

- (instancetype)initWithData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    self = [super init];
    if (self) {
        _data = data;
        _response = (NSHTTPURLResponse *)response;
        _error = error;
        _status = _response ? _response.statusCode : 0;
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data statusCode:(NSInteger)statusCode error:(NSError *)error {
    self = [super init];
    if (self) {
        _data = data;
        _error = error;
        _status = statusCode;
        // Create a mock NSHTTPURLResponse for statusCode
        if (statusCode > 0) {
            NSURL *url = [NSURL URLWithString:@"http://localhost"];
            _response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:nil];
        }
    }
    return self;
}

@end

