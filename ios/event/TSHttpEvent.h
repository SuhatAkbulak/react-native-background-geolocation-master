//
//  TSHttpEvent.h
//  RNBackgroundLocation
//
//  HTTP Event - ExampleIOS/TSHttpEvent.h pattern'ine göre
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TSHttpEvent
 * ExampleIOS/TSHttpEvent.h pattern'ine göre implement edildi
 */
@interface TSHttpEvent : NSObject

@property (nonatomic, readonly) BOOL isSuccess;
@property (nonatomic, readonly) NSInteger statusCode;
@property (nonatomic, readonly, nullable) NSDictionary *requestData;
@property (nonatomic, readonly, nullable) NSString *responseText;
@property (nonatomic, readonly, nullable) NSError *error;

- (id)initWithStatusCode:(NSInteger)statusCode requestData:(nullable NSDictionary*)requestData responseData:(nullable NSData*)responseData error:(nullable NSError*)error;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
