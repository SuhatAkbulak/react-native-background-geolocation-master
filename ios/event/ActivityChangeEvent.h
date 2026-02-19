//
//  ActivityChangeEvent.h
//  RNBackgroundLocation
//
//  Activity Change Event
//  Android ActivityChangeEvent.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ActivityChangeEvent : NSObject

@property (nonatomic, strong) NSString *activity; // "still", "walking", "running", "on_foot", "in_vehicle", "on_bicycle", "unknown"
@property (nonatomic, assign) NSInteger confidence; // 0-100
@property (nonatomic, assign) NSTimeInterval timestamp;

- (instancetype)initWithActivity:(NSString *)activity confidence:(NSInteger)confidence;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;

@end

NS_ASSUME_NONNULL_END

