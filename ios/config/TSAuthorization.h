//
//  TSAuthorization.h
//  RNBackgroundLocation
//
//  HTTP Authorization Config
//  Transistorsoft TSAuthorization.h benzeri (sadeleştirilmiş)
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Key sabitleri (konfigürasyon sözlüğü için)
extern NSString * const TS_AUTHORIZATION_STRATEGY;
extern NSString * const TS_ACCESS_TOKEN;
extern NSString * const TS_REFRESH_TOKEN;
extern NSString * const TS_REFRESH_PAYLOAD;
extern NSString * const TS_EXPIRES;
extern NSString * const TS_REFRESH_URL;
extern NSString * const TS_REFRESH_HEADERS;

@class TSAuthorizationEvent;

@interface TSAuthorization : NSObject

@property (nonatomic, strong, nullable) NSString *strategy;
@property (nonatomic, strong, nullable) NSString *accessToken;
@property (nonatomic, strong, nullable) NSString *refreshToken;
@property (nonatomic, strong, nullable) NSDictionary *refreshPayload;
@property (nonatomic, strong, nullable) NSDictionary *refreshHeaders;
@property (nonatomic, strong, nullable) NSString *refreshUrl;
@property (nonatomic, assign) NSTimeInterval expires;

- (instancetype)initWithDictionary:(NSDictionary *)values;

// HTTP isteğine Authorization header'ı uygula
- (void)apply:(NSMutableURLRequest *)request;

// JSON benzeri string temsil
- (NSString *)toString;

// HTTP response status'ine göre AuthorizationEvent üret
- (void)resolve:(NSInteger)status
        success:(void(^)(TSAuthorizationEvent *event))success
        failure:(void(^)(TSAuthorizationEvent *event))failure;

// Sözlük temsili (TSConfig.persist için)
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END





