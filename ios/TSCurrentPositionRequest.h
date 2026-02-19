//
//  TSCurrentPositionRequest.h
//  RNBackgroundLocation
//
//  Current Position Request - ExampleIOS/TSCurrentPositionRequest.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "TSLocation.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * TSCurrentPositionRequest
 * ExampleIOS/TSCurrentPositionRequest.h pattern'ine göre implement edildi
 */
@interface TSCurrentPositionRequest : NSObject

@property (atomic) NSTimeInterval timeout;
@property (atomic) double maximumAge;
@property (atomic) BOOL persist;
@property (atomic) int samples;
@property (atomic) CLLocationAccuracy desiredAccuracy;
@property (atomic, nullable) NSDictionary* extras;
@property (atomic, copy, nullable) void (^success)(TSLocation*);
@property (atomic, copy, nullable) void (^failure)(NSError*);

- (instancetype)init;
- (instancetype)initWithSuccess:(void (^)(TSLocation*))success failure:(void (^)(NSError*))failure;
- (instancetype)initWithPersist:(BOOL)persist
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure;
- (instancetype)initWithPersist:(BOOL)persist
                        samples:(int)samples
                        success:(void (^)(TSLocation*))success
                        failure:(void (^)(NSError*))failure;
- (instancetype)initWithTimeout:(int)timeout
           maximumAge:(double)maximumAge
              persist:(BOOL)persist
              samples:(int)samples
      desiredAccuracy:(CLLocationAccuracy)desiredAccuracy
               extras:(nullable NSDictionary*)extras
              success:(void (^)(TSLocation*))success
              failure:(void (^)(NSError*))failure;

@end

NS_ASSUME_NONNULL_END
