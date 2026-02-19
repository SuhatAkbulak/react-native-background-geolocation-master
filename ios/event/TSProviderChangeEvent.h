//
//  TSProviderChangeEvent.h
//  RNBackgroundLocation
//
//  Provider Change Event - ExampleIOS/TSProviderChangeEvent.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TSProviderChangeEvent
 * ExampleIOS/TSProviderChangeEvent.h pattern'ine göre implement edildi
 */
@interface TSProviderChangeEvent : NSObject

@property (nonatomic, readonly) CLAuthorizationStatus status;
@property (nonatomic, readonly) NSInteger accuracyAuthorization;
@property (nonatomic, readonly) BOOL gps;
@property (nonatomic, readonly) BOOL network;
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) CLLocationManager* manager;

- (id)initWithManager:(CLLocationManager*)manager status:(CLAuthorizationStatus)status authorizationRequest:(nullable NSString*)authorizationRequest;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
