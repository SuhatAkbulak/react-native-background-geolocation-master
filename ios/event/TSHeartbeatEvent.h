//
//  TSHeartbeatEvent.h
//  RNBackgroundLocation
//
//  Heartbeat Event - ExampleIOS/TSHeartbeatEvent.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import "TSLocation.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * TSHeartbeatEvent
 * ExampleIOS/TSHeartbeatEvent.h pattern'ine göre implement edildi
 */
@interface TSHeartbeatEvent : NSObject

@property (nonatomic, readonly) TSLocation* location;

- (id)initWithLocation:(CLLocation*)location;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
