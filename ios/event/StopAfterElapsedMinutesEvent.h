//
//  StopAfterElapsedMinutesEvent.h
//  RNBackgroundLocation
//
//  Stop After Elapsed Minutes Event
//  Android StopAfterElapsedMinutesEvent.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StopAfterElapsedMinutesEvent : NSObject

- (instancetype)init;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;

@end

NS_ASSUME_NONNULL_END

