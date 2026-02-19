//
//  TSGeofencesChangeEvent.h
//  RNBackgroundLocation
//
//  Geofences Change Event - ExampleIOS/TSGeofencesChangeEvent.h pattern'ine göre
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TSGeofencesChangeEvent
 * ExampleIOS/TSGeofencesChangeEvent.h pattern'ine göre implement edildi
 */
@interface TSGeofencesChangeEvent : NSObject

@property (nonatomic, readonly, nullable) NSArray* on;
@property (nonatomic, readonly, nullable) NSArray* off;

- (id)initWithOn:(nullable NSArray*)on off:(nullable NSArray*)off;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
