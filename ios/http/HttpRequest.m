//
//  HttpRequest.m
//  RNBackgroundLocation
//
//  HTTP Request wrapper
//  ExampleIOS/HttpRequest.h pattern'ine göre
//

#import "HttpRequest.h"
#import "TSConfig.h"
#import "TSTemplate.h"
#import "LogHelper.h"

@implementation HttpRequest

+ (void)execute:(NSArray *)records callback:(void(^)(HttpRequest*, HttpResponse*))callback {
    HttpRequest *request = [[HttpRequest alloc] initWithRecords:records callback:callback];
    // Execute will be handled by TSHttpService
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestData = nil;
        _url = nil;
    }
    return self;
}

- (instancetype)initWithRecords:(NSArray *)records callback:(void(^)(HttpRequest*, HttpResponse*))callback {
    self = [super init];
    if (self) {
        _requestData = records;
        TSConfig *config = [TSConfig sharedInstance];
        _url = [NSURL URLWithString:config.url];
    }
    return self;
}

@end

