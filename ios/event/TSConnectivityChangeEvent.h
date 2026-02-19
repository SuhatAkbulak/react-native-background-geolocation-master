//
//  TSConnectivityChangeEvent.h
//  RNBackgroundLocation
//
//  Connectivity Change Event - ExampleIOS pattern'ine göre
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TSConnectivityChangeEvent
 * ExampleIOS pattern'ine göre implement edildi
 */
@interface TSConnectivityChangeEvent : NSObject

@property (nonatomic, readonly) BOOL connected;

- (id)initWithConnected:(BOOL)connected;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
