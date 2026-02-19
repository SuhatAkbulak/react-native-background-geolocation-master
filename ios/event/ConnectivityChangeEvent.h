//
//  ConnectivityChangeEvent.h
//  RNBackgroundLocation
//
//  Connectivity Change Event
//  Android ConnectivityChangeEvent.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConnectivityChangeEvent : NSObject

@property (nonatomic, assign) BOOL connected;

- (instancetype)initWithConnected:(BOOL)connected;
- (NSDictionary *)toDictionary;
- (NSString *)getEventName;

@end

NS_ASSUME_NONNULL_END





