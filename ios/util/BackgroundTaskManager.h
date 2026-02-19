//
//  BackgroundTaskManager.h
//  RNBackgroundLocation
//
//  Background task management
//  iOS_PRECEDUR pattern - 31 fonksiyon
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@class BackgroundTaskManager;

@interface BackgroundTaskManager : NSObject

#pragma mark - Singleton
+ (instancetype)sharedInstance;

#pragma mark - Properties
@property (nonatomic, readonly) UIBackgroundTaskIdentifier bgTask;
@property (nonatomic, strong) CLLocationManager *locationManager;

#pragma mark - Background Task Methods
- (UIBackgroundTaskIdentifier)createBackgroundTask;
- (void)stopBackgroundTask:(UIBackgroundTaskIdentifier)taskId;

#pragma mark - Prevent Suspend Methods
- (void)startPreventSuspend:(NSTimeInterval)interval;
- (void)stopPreventSuspend;

#pragma mark - Keep Alive Methods
- (void)startKeepAlive;
- (void)stopKeepAlive;

#pragma mark - Lifecycle Methods
- (void)onSuspend:(NSNotification *)notification;
- (void)onResume:(NSNotification *)notification;

#pragma mark - Utility Methods
- (void)acquireBackgroundTime;
- (void)pleaseStayAwake;

@end





