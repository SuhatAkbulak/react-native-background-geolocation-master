//
//  TSScheduleEvent.h
//  RNBackgroundLocation
//
//  Schedule Event - ExampleIOS/TSScheduleEvent.h pattern'ine göre
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TSSchedule;

/**
 * TSScheduleEvent
 * ExampleIOS/TSScheduleEvent.h pattern'ine göre implement edildi
 */
@interface TSScheduleEvent : NSObject

@property (nonatomic, readonly, nullable) TSSchedule* schedule;
@property (nonatomic, readonly, nullable) NSDictionary* state;

- (id)initWithSchedule:(nullable TSSchedule*)schedule state:(nullable NSDictionary*)state;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
