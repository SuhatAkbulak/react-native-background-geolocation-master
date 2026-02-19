//
//  LifecycleManager.h
//  RNBackgroundLocation
//
//  Lifecycle Manager
//  Android LifecycleManager.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LifecycleManagerDelegate <NSObject>
@optional
- (void)onHeadlessChange:(BOOL)isHeadless;
- (void)onStateChange:(BOOL)isBackground;
- (void)onAppTerminate; // iOS_PRECEDUR pattern - app terminate callback
@end

@interface LifecycleManager : NSObject

// Singleton
+ (instancetype)sharedInstance;

// Initialize
- (void)initialize;

// Status
- (BOOL)isBackground;
- (BOOL)isHeadless;

// Manual control
- (void)setHeadless:(BOOL)headless;
- (void)pause;
- (void)resume;

// Delegate
@property (nonatomic, weak, nullable) id<LifecycleManagerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
