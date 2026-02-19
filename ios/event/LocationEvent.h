//
//  LocationEvent.h
//  RNBackgroundLocation
//
//  Location Event
//  Android LocationEvent.java benzeri
//

#import <Foundation/Foundation.h>
@class LocationModel;

NS_ASSUME_NONNULL_BEGIN

@interface LocationEvent : NSObject

@property (nonatomic, strong) LocationModel *location;

- (instancetype)initWithLocation:(LocationModel *)location;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;

@end

NS_ASSUME_NONNULL_END





