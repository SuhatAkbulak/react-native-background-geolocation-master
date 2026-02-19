//
//  TSHttpService.h
//  RNBackgroundLocation
//
//  HTTP Sync Service
//  ExampleIOS/TSHttpService.h pattern'ine göre
//  iOS_PRECEDUR pattern - 61 fonksiyon
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class TSConnectivityChangeEvent;
@class TSAuthorizationEvent;
@class AtomicBoolean;
@class HttpRequest;
@class HttpResponse;
@class TSReachability;
@class TSCallback;

@class TSHttpService;

@interface TSHttpService : NSObject

#pragma mark - Singleton
+ (TSHttpService *)sharedInstance;

#pragma mark - Properties

@property (copy) void (^httpResponseBlock) (HttpRequest *request, HttpResponse *response);

@property (nonatomic) AtomicBoolean *isBusy;
@property (nonatomic) BOOL hasNetworkConnection;

@property (nonatomic, readonly) NSMutableArray *syncedRecords;
@property (nonatomic, readonly) TSReachability *reachability;
@property (nonatomic, readonly) UIBackgroundTaskIdentifier bgTask;

@property (nonatomic, readonly) NSMutableSet *connectivityChangeListeners;
@property (nonatomic, readonly) NSMutableSet *authorizationListeners;

@property (nonatomic) TSCallback *callback;
@property (nonatomic) long autoSyncThreshold;

#pragma mark - Methods
- (void)flush;
- (void)flush:(BOOL)overrideSyncThreshold;
- (void)flush:(void(^)(NSArray*))success failure:(void(^)(NSError*))failure;
- (void)startMonitoring;
- (void)stopMonitoring;

- (void)onConnectivityChange:(void (^)(TSConnectivityChangeEvent*))success;
- (void)onAuthorization:(void(^)(TSAuthorizationEvent*))callback;
- (void)un:(NSString*)event callback:(void(^)(id))callback;
- (void)removeListeners;
- (void)removeListeners:(NSString*)event;

@end

