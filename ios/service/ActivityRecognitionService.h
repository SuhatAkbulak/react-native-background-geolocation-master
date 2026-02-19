//
//  ActivityRecognitionService.h
//  RNBackgroundLocation
//
//  Activity Recognition Service
//  Android ActivityRecognitionService.java benzeri
//  iOS CoreMotion kullanarak
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

NS_ASSUME_NONNULL_BEGIN

@class ActivityChangeEvent;

@interface ActivityRecognitionService : NSObject

// Singleton
+ (instancetype)sharedInstance;

// Start/Stop
+ (void)start;
+ (void)stop;

// Status
+ (BOOL)isStarted;
+ (CMMotionActivity *)getLastActivity;
+ (CMMotionActivity *)getMostProbableActivity;
+ (BOOL)isMoving;

// Callback
@property (nonatomic, copy, nullable) void (^onActivityChange)(ActivityChangeEvent *event);
@property (nonatomic, copy, nullable) void (^onMotionChange)(BOOL isMoving, NSDictionary *location);

@end

NS_ASSUME_NONNULL_END





