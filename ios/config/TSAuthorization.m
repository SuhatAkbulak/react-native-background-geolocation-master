//
//  TSAuthorization.m
//  RNBackgroundLocation
//
//  HTTP Authorization Config
//  Transistorsoft TSAuthorization.m benzeri (sadeleştirilmiş)
//

#import "TSAuthorization.h"
#import "TSAuthorizationEvent.h"

NSString * const TS_AUTHORIZATION_STRATEGY   = @"strategy";
NSString * const TS_ACCESS_TOKEN             = @"accessToken";
NSString * const TS_REFRESH_TOKEN            = @"refreshToken";
NSString * const TS_REFRESH_PAYLOAD          = @"refreshPayload";
NSString * const TS_EXPIRES                  = @"expires";
NSString * const TS_REFRESH_URL              = @"refreshUrl";
NSString * const TS_REFRESH_HEADERS          = @"refreshHeaders";

@implementation TSAuthorization

- (instancetype)initWithDictionary:(NSDictionary *)values {
    self = [super init];
    if (self) {
        _strategy = values[TS_AUTHORIZATION_STRATEGY];
        _accessToken = values[TS_ACCESS_TOKEN];
        _refreshToken = values[TS_REFRESH_TOKEN];
        _refreshPayload = values[TS_REFRESH_PAYLOAD];
        _refreshHeaders = values[TS_REFRESH_HEADERS];
        _refreshUrl = values[TS_REFRESH_URL];
        id expiresValue = values[TS_EXPIRES];
        if ([expiresValue respondsToSelector:@selector(doubleValue)]) {
            _expires = [expiresValue doubleValue];
        } else {
            _expires = 0;
        }
    }
    return self;
}

- (void)apply:(NSMutableURLRequest *)request {
    if (!self.strategy || self.strategy.length == 0) {
        return;
    }
    
    NSString *lowerStrategy = [self.strategy lowercaseString];
    
    if ([lowerStrategy isEqualToString:@"bearer"] && self.accessToken.length > 0) {
        NSString *value = [NSString stringWithFormat:@"Bearer %@", self.accessToken];
        [request setValue:value forHTTPHeaderField:@"Authorization"];
    } else if ([lowerStrategy isEqualToString:@"basic"] && self.accessToken.length > 0) {
        // accessToken burada "user:pass" veya direkt Base64 string olabilir.
        NSString *token = self.accessToken;
        // Eğer içinde ':' varsa, Base64'e çevir
        if ([token containsString:@":"]) {
            NSData *data = [token dataUsingEncoding:NSUTF8StringEncoding];
            token = [data base64EncodedStringWithOptions:0];
        }
        NSString *value = [NSString stringWithFormat:@"Basic %@", token];
        [request setValue:value forHTTPHeaderField:@"Authorization"];
    }
    
    // Ek refreshHeaders varsa, onları da uygula
    if (self.refreshHeaders) {
        for (NSString *key in self.refreshHeaders) {
            id headerValue = self.refreshHeaders[key];
            if ([headerValue isKindOfClass:[NSString class]]) {
                [request setValue:headerValue forHTTPHeaderField:key];
            }
        }
    }
}

- (NSString *)toString {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self toDictionary] options:0 error:&error];
    if (error || !data) {
        return @"{}";
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)resolve:(NSInteger)status
        success:(void(^)(TSAuthorizationEvent *event))success
        failure:(void(^)(TSAuthorizationEvent *event))failure {
    // Basit implementasyon:
    // 2xx → success
    // 401 / 403 → failure (auth ile ilgili)
    // Diğer kodlar için event üretme, SyncService zaten HTTP event üretiyor.
    
    if (status >= 200 && status < 300) {
        if (success) {
            TSAuthorizationEvent *event = [[TSAuthorizationEvent alloc] initWithResponse:@{} status:status];
            success(event);
        }
    } else if (status == 401 || status == 403) {
        if (failure) {
            NSError *error = [NSError errorWithDomain:@"TSAuthorization"
                                                 code:status
                                             userInfo:@{NSLocalizedDescriptionKey: @"Unauthorized / Forbidden"}];
            TSAuthorizationEvent *event = [[TSAuthorizationEvent alloc] initWithError:error status:status];
            failure(event);
        }
    }
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.strategy) {
        dict[TS_AUTHORIZATION_STRATEGY] = self.strategy;
    }
    if (self.accessToken) {
        dict[TS_ACCESS_TOKEN] = self.accessToken;
    }
    if (self.refreshToken) {
        dict[TS_REFRESH_TOKEN] = self.refreshToken;
    }
    if (self.refreshPayload) {
        dict[TS_REFRESH_PAYLOAD] = self.refreshPayload;
    }
    if (self.refreshHeaders) {
        dict[TS_REFRESH_HEADERS] = self.refreshHeaders;
    }
    if (self.refreshUrl) {
        dict[TS_REFRESH_URL] = self.refreshUrl;
    }
    if (self.expires > 0) {
        dict[TS_EXPIRES] = @(self.expires);
    }
    return dict;
}

@end


