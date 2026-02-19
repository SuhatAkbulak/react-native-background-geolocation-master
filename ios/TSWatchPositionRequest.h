//
//  TSWatchPositionRequest.h
//  RNBackgroundLocation
//
//  Watch Position Request - ExampleIOS/TSWatchPositionRequest.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "TSLocation.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * TSWatchPositionRequest
 * ExampleIOS/TSWatchPositionRequest.h pattern'ine göre implement edildi
 */
@interface TSWatchPositionRequest : NSObject

@property (nonatomic) double interval;
@property (atomic) CLLocationAccuracy desiredAccuracy;
@property (atomic) BOOL persist;
@property (atomic, nullable) NSDictionary* extras;
@property (atomic) double timeout;
@property (atomic, copy, nullable) void (^success)(TSLocation*);
@property (atomic, copy, nullable) void (^failure)(NSError*);

- (instancetype)init;
- (instancetype)initWithSuccess:(void (^)(TSLocation*))success failure:(void (^)(NSError*))failure;
- (instancetype)initWithInterval:(double)interval
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure;
- (instancetype)initWithInterval:(double)interval
                        persist:(BOOL)persist
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure;
- (instancetype)initWithInterval:(double)interval
                        persist:(BOOL)persist
                 desiredAccuracy:(CLLocationAccuracy)desiredAccuracy
                         extras:(nullable NSDictionary*)extras
                         timeout:(double)timeout
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure;

@end

NS_ASSUME_NONNULL_END
