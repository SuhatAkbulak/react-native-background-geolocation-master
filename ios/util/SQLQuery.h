//
//  SQLQuery.h
//  RNBackgroundLocation
//
//  SQL Query Builder - ExampleIOS/SQLQuery.h pattern'ine göre
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum SQLQueryOrder : NSInteger {
    tsSQLQueryOrderDESC = -1,
    tsSQLQueryOrderASC = 1
} SQLQueryOrder;

/**
 * SQLQuery
 * ExampleIOS/SQLQuery.h pattern'ine göre implement edildi
 */
@interface SQLQuery : NSObject
{
    @protected
    NSString *_tableName;
    NSString *_orderColumn;
    NSString *_timestampColumn;
    NSMutableArray *_arguments;
}

@property (nonatomic) double start;
@property (nonatomic) double end;
@property (nonatomic) int limit;
@property (nonatomic) SQLQueryOrder order;

- (instancetype)init;
- (instancetype)initWithDictionary:(NSDictionary*)params;

- (void)addArgument:(id)argument;
- (NSString*)render;
- (NSArray*)arguments;
- (NSString*)toString;

@end

NS_ASSUME_NONNULL_END


