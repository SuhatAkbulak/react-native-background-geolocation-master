//
//  EnabledChangeEvent.h
//  RNBackgroundLocation
//
//  Enabled Change Event
//  Android EnabledChangeEvent.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EnabledChangeEvent : NSObject

@property (nonatomic, assign) BOOL enabled;

- (instancetype)initWithEnabled:(BOOL)enabled;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;

@end

NS_ASSUME_NONNULL_END





