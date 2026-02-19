//
//  LogQuery.m
//  RNBackgroundLocation
//
//  Log Query - ExampleIOS/LogQuery.h pattern'ine göre
//

#import "LogQuery.h"

@implementation LogQuery

- (instancetype)init {
    self = [super init];
    if (self) {
        _tableName = @"logs";
        _orderColumn = @"id";
        _timestampColumn = @"timestamp";
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary*)params {
    self = [super initWithDictionary:params];
    if (self) {
        _tableName = @"logs";
        _orderColumn = @"id";
        _timestampColumn = @"timestamp";
    }
    return self;
}

@end






