//
//  TSScheduler.h
//  RNBackgroundLocation
//
//  Scheduler - ExampleIOS pattern'ine göre
//

#import <Foundation/Foundation.h>
#import "TSConfig.h"

NS_ASSUME_NONNULL_BEGIN

@class TSSchedule;

/**
 * TSScheduler
 * ExampleIOS pattern'ine göre implement edildi
 */
@interface TSScheduler : NSObject

+ (instancetype)sharedInstance;

- (void)parse:(NSArray*)scheduleArray;
- (void)start;
- (void)stop;
- (void)evaluate;
- (nullable TSSchedule*)findNextSchedule:(NSDate*)now;
- (NSCalendar*)getCalendar;
- (NSDate*)getTomorrow:(NSDate*)date;
- (void)scheduleAlarm:(BOOL)enabled date:(NSDate*)date trackingMode:(TSTrackingMode)trackingMode;
- (void)handleEvent:(NSDictionary*)event;

@end

NS_ASSUME_NONNULL_END
