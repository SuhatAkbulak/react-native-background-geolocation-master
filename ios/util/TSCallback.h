//
//  TSCallback.h
//  RNBackgroundLocation
//
//  Callback wrapper
//  ExampleIOS/TSCallback.h pattern'ine göre
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSCallback : NSObject

@property (nonatomic, copy, nullable) void (^success)(id);
@property (nonatomic, copy, nullable) void (^failure)(id);
@property (nonatomic, readonly, nullable) NSDictionary *options;

- (id)initWithSuccess:(void(^)(id))success failure:(void(^)(id))failure;
- (id)initWithSuccess:(void(^)(id))success failure:(void(^)(id))failure options:(nullable NSDictionary*)options;

@end

NS_ASSUME_NONNULL_END





