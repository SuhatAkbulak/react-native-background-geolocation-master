//
//  HeartbeatEvent.h
//  RNBackgroundLocation
//
//  Heartbeat Event
//  Android HeartbeatEvent.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HeartbeatEvent : NSObject

@property (nonatomic, strong, nullable) NSDictionary *location;

- (instancetype)init;
- (instancetype)initWithLocation:(NSDictionary *)location;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;

@end

NS_ASSUME_NONNULL_END





