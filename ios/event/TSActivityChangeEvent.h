//
//  TSActivityChangeEvent.h
//  RNBackgroundLocation
//
//  Activity Change Event - ExampleIOS/TSActivityChangeEvent.h pattern'ine göre
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * TSActivityChangeEvent
 * ExampleIOS/TSActivityChangeEvent.h pattern'ine göre implement edildi
 */
@interface TSActivityChangeEvent : NSObject

@property (nonatomic, readonly) NSInteger confidence;
@property (nonatomic, readonly) NSString *activity;

- (id)initWithActivityName:(NSString*)activityName confidence:(NSInteger)confidence;
- (NSDictionary*)toDictionary;

@end

NS_ASSUME_NONNULL_END
