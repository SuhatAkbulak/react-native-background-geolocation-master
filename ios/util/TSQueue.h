//
//  TSQueue.h
//  RNBackgroundLocation
//
//  Thread-safe queue management
//  iOS_PRECEDUR pattern - 8 fonksiyon
//

#import <Foundation/Foundation.h>

@interface TSQueue : NSObject

#pragma mark - Singleton
+ (instancetype)sharedInstance;

#pragma mark - Methods
- (void)runInBackground:(void(^)(void))block;
- (void)runInMain:(void(^)(void))block;
- (void)runOnMainQueueWithoutDeadlocking:(void(^)(void))block;

@end





