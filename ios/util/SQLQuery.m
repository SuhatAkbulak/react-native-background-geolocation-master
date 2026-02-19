//
//  SQLQuery.m
//  RNBackgroundLocation
//
//  SQL Query Builder - ExampleIOS/SQLQuery.h pattern'ine göre
//

#import "SQLQuery.h"

@implementation SQLQuery

- (instancetype)init {
    self = [super init];
    if (self) {
        _start = 0;
        _end = 0;
        _limit = 0;
        _order = tsSQLQueryOrderDESC;
        _arguments = [NSMutableArray array];
        _tableName = @"";
        _orderColumn = @"id";
        _timestampColumn = @"timestamp";
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary*)params {
    self = [self init];
    if (self) {
        if (params[@"start"]) {
            id startValue = params[@"start"];
            if ([startValue respondsToSelector:@selector(doubleValue)]) {
                _start = [startValue doubleValue];
            }
        }
        
        if (params[@"end"]) {
            id endValue = params[@"end"];
            if ([endValue respondsToSelector:@selector(doubleValue)]) {
                _end = [endValue doubleValue];
            }
        }
        
        if (params[@"limit"]) {
            id limitValue = params[@"limit"];
            if ([limitValue respondsToSelector:@selector(intValue)]) {
                _limit = [limitValue intValue];
            }
        }
        
        if (params[@"order"]) {
            NSString *orderStr = [params[@"order"] lowercaseString];
            if ([orderStr isEqualToString:@"asc"]) {
                _order = tsSQLQueryOrderASC;
            } else {
                _order = tsSQLQueryOrderDESC;
            }
        }
    }
    return self;
}

- (void)addArgument:(id)argument {
    if (argument) {
        [_arguments addObject:argument];
    }
}

- (NSString*)render {
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT * FROM %@", _tableName];
    NSMutableArray *conditions = [NSMutableArray array];
    
    // Time range conditions
    if (_start > 0) {
        [conditions addObject:[NSString stringWithFormat:@"%@ >= ?", _timestampColumn]];
        [self addArgument:@(_start)];
    }
    
    if (_end > 0) {
        [conditions addObject:[NSString stringWithFormat:@"%@ <= ?", _timestampColumn]];
        [self addArgument:@(_end)];
    }
    
    // Add WHERE clause if conditions exist
    if (conditions.count > 0) {
        [sql appendString:@" WHERE "];
        [sql appendString:[conditions componentsJoinedByString:@" AND "]];
    }
    
    // Add ORDER BY clause
    NSString *orderStr = (_order == tsSQLQueryOrderASC) ? @"ASC" : @"DESC";
    [sql appendFormat:@" ORDER BY %@ %@", _orderColumn, orderStr];
    
    // Add LIMIT clause
    if (_limit > 0) {
        [sql appendFormat:@" LIMIT %d", _limit];
    }
    
    return sql;
}

- (NSArray*)arguments {
    return [_arguments copy];
}

- (NSString*)toString {
    NSMutableString *result = [NSMutableString string];
    [result appendString:[self render]];
    [result appendString:@"\n"];
    [result appendString:@"Arguments: "];
    [result appendString:[[self arguments] description]];
    return result;
}

@end






