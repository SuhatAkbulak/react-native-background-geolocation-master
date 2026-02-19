//
//  TSSchedule.h
//  RNBackgroundLocation
//
//  Schedule Model - ExampleIOS/TSSchedule.h pattern'ine göre
//

#import <Foundation/Foundation.h>
#import "TSConfig.h"
@class TSAuthorization;

NS_ASSUME_NONNULL_BEGIN

/**
 * TSSchedule
 * ExampleIOS/TSSchedule.h pattern'ine göre implement edildi
 */
@interface TSSchedule : NSObject

@property (nonatomic, nullable) NSDateComponents* onTime;
@property (nonatomic, nullable) NSDate* onDate;

@property (nonatomic, nullable) NSDateComponents* offTime;
@property (nonatomic, nullable) NSDate* offDate;
@property (nonatomic) BOOL triggered;
@property (nonatomic) TSTrackingMode trackingMode;

@property (copy, nullable) void (^handlerBlock) (TSSchedule *schedule);

- (instancetype)initWithRecord:(NSString*)data andHandler:(void (^)(TSSchedule*))handler;

- (void)make:(NSDateComponents*)dateComponents;
- (BOOL)isNext:(NSDate*)now;
- (BOOL)isLiteralDate;
- (BOOL)hasDay:(NSInteger)day;
- (BOOL)startsBefore:(NSDate*)now;
- (BOOL)startsAfter:(NSDate*)now;
- (BOOL)endsBefore:(NSDate*)now;
- (BOOL)endsAfter:(NSDate*)now;
- (BOOL)expired;
- (void)trigger:(BOOL)enabled;
- (void)reset;
- (void)evaluate;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
