//
//  HttpResponse.h
//  RNBackgroundLocation
//
//  HTTP Response wrapper
//  ExampleIOS/HttpResponse.h pattern'ine göre
//

#import <Foundation/Foundation.h>

// Location types
typedef enum TSHttpServiceError : NSInteger {
    TSHttpServiceErrorInvalidUrl        = 1,
    TSHttpServiceErrorNetworkConnection = 2,
    TSHttpServiceErrorSyncInProgress    = 3,
    TSHttpServiceErrorResponse          = 4,
    TSHttpServiceRedirectError          = 5
} TSHttpServiceError;

@interface HttpResponse : NSObject

- (instancetype)initWithData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error;
- (instancetype)initWithData:(NSData *)data statusCode:(NSInteger)statusCode error:(NSError *)error;

@property (nonatomic) NSError *error;
@property (nonatomic) NSData *data;
@property (nonatomic) NSHTTPURLResponse *response;
@property (nonatomic) NSInteger status;

@end

