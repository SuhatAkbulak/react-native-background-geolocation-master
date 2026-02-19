//
//  TSEnabledChangeEvent.h
//  RNBackgroundLocation
//
//  Enabled Change Event - ExampleIOS/TSEnabledChangeEvent.h pattern'ine göre
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TSEnabledChangeEvent
 * ExampleIOS/TSEnabledChangeEvent.h pattern'ine göre implement edildi
 */
@interface TSEnabledChangeEvent : NSObject

@property (nonatomic, readonly) BOOL enabled;

- (id)initWithEnabled:(BOOL)enabled;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
