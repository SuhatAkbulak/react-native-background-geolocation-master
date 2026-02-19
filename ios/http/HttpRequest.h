//
//  HttpRequest.h
//  RNBackgroundLocation
//
//  HTTP Request wrapper
//  ExampleIOS/HttpRequest.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import "HttpResponse.h"

@interface HttpRequest : NSObject

@property (nonatomic) id requestData;
@property (nonatomic) NSURL *url;

+ (void)execute:(NSArray *)records callback:(void(^)(HttpRequest*, HttpResponse*))callback;
- (instancetype)initWithRecords:(NSArray *)records callback:(void(^)(HttpRequest*, HttpResponse*))callback;
- (instancetype)init;

@end

