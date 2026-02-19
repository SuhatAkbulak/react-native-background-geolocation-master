//
//  TSPowerSaveChangeEvent.h
//  RNBackgroundLocation
//
//  Power Save Change Event
//  Transistorsoft TSPowerSaveChangeEvent.h benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSPowerSaveChangeEvent : NSObject

@property (nonatomic, readonly) BOOL isPowerSaveMode;

- (instancetype)initWithIsPowerSaveMode:(BOOL)isPowerSaveMode;
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END





