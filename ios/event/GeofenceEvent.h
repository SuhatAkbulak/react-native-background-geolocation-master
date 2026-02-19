//
//  GeofenceEvent.h
//  RNBackgroundLocation
//
//  Geofence Event
//  Android GeofenceEvent.java benzeri
//

#import <Foundation/Foundation.h>
@class LocationModel;
@class GeofenceModel;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GeofenceAction) {
    GeofenceActionEnter,
    GeofenceActionExit,
    GeofenceActionDwell
};

@interface GeofenceEvent : NSObject

@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, assign) GeofenceAction action;
@property (nonatomic, strong) LocationModel *location;

- (instancetype)initWithIdentifier:(NSString *)identifier 
                             action:(GeofenceAction)action 
                           location:(LocationModel *)location;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;
- (NSString *)actionString;

@end

NS_ASSUME_NONNULL_END





