//
//  HttpResponseEvent.h
//  RNBackgroundLocation
//
//  HTTP Response Event
//  Android HttpResponseEvent.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HttpResponseEvent : NSObject

@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, assign) NSInteger status; // Alias for statusCode
@property (nonatomic, assign) BOOL success;
@property (nonatomic, assign) BOOL isSuccess; // Alias for success
@property (nonatomic, strong) NSString *responseText;
@property (nonatomic, strong) NSDictionary *requestData;
@property (nonatomic, strong) NSData *responseData;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSArray *locations; // Synced locations

- (instancetype)initWithStatusCode:(NSInteger)status 
                            success:(BOOL)success 
                       responseText:(NSString *)responseText;
- (instancetype)initWithStatusCode:(NSInteger)statusCode
                         requestData:(NSDictionary*)requestData
                        responseData:(NSData*)responseData
                               error:(NSError*)error;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;

@end

NS_ASSUME_NONNULL_END
