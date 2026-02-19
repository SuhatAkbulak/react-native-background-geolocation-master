//
//  TSAuthorizationEvent.h
//  RNBackgroundLocation
//
//  Authorization Event
//  Transistorsoft TSAuthorizationEvent.h benzeri (sadeleştirilmiş)
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSAuthorizationEvent : NSObject

@property (nonatomic, readonly) NSInteger status;
@property (nonatomic, strong, readonly, nullable) NSError *error;
@property (nonatomic, strong, readonly, nullable) NSDictionary *response;

- (instancetype)initWithResponse:(NSDictionary *)response status:(NSInteger)status;
- (instancetype)initWithError:(NSError *)error status:(NSInteger)status;
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END

