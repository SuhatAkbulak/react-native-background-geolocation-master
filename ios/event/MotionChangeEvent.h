//
//  MotionChangeEvent.h
//  RNBackgroundLocation
//
//  Motion Change Event
//  Android MotionChangeEvent.java benzeri
//

#import <Foundation/Foundation.h>
@class LocationModel;

NS_ASSUME_NONNULL_BEGIN

@interface MotionChangeEvent : NSObject

@property (nonatomic, assign) BOOL isMoving;
@property (nonatomic, strong) LocationModel *location;

- (instancetype)initWithIsMoving:(BOOL)isMoving location:(LocationModel *)location;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;

@end

NS_ASSUME_NONNULL_END





