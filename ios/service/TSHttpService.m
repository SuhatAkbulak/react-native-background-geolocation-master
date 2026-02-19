//
//  TSHttpService.m
//  RNBackgroundLocation
//
//  HTTP Sync Service
//  ExampleIOS/TSHttpService.h pattern'ine göre
//  iOS_PRECEDUR pattern - 61 fonksiyon
//

#import "TSHttpService.h"
#import "TSConfig.h"
#import "LocationModel.h"
#import "SQLiteLocationDAO.h"
#import "HttpResponseEvent.h"
#import "TSHttpEvent.h"
#import "TSAuthorizationEvent.h"
#import "TSConnectivityChangeEvent.h"
#import "LogHelper.h"
#import "TSQueue.h"
#import "BackgroundTaskManager.h"
#import "TSTemplate.h"
#import "TSReachability.h"
#import "AtomicBoolean.h"
#import "HttpRequest.h"
#import "HttpResponse.h"
#import "SyncService.h"

@interface TSHttpService ()
@property (nonatomic, strong) TSConfig *config;
@property (nonatomic, strong) SQLiteLocationDAO *database;
@property (nonatomic, strong) SyncService *syncService;
@property (nonatomic, strong) TSReachability *reachability;
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;
@end

@implementation TSHttpService

#pragma mark - Singleton

+ (TSHttpService *)sharedInstance {
    static TSHttpService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TSHttpService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _config = [TSConfig sharedInstance];
        _database = [SQLiteLocationDAO sharedInstance];
        _syncService = [SyncService sharedInstance];
        _isBusy = [[AtomicBoolean alloc] initWithValue:NO];
        _hasNetworkConnection = NO;
        _syncedRecords = [NSMutableArray array];
        _connectivityChangeListeners = [NSMutableSet set];
        _authorizationListeners = [NSMutableSet set];
        _autoSyncThreshold = 0;
        _bgTask = UIBackgroundTaskInvalid;
        
        // Initialize reachability
        _reachability = [TSReachability reachabilityForInternetConnection];
        [self updateNetworkConnection];
    }
    return self;
}

#pragma mark - Methods

/**
 * Flush (sync) locations
 * iOS_PRECEDUR pattern: -[TSHttpService flush]
 */
- (void)flush {
    [self flush:NO];
}

/**
 * Flush with override threshold
 * iOS_PRECEDUR pattern: -[TSHttpService flush:overrideSyncThreshold]
 */
- (void)flush:(BOOL)overrideSyncThreshold {
    [self flush:overrideSyncThreshold success:nil failure:nil];
}

/**
 * Flush with callbacks
 * iOS_PRECEDUR pattern: -[TSHttpService flush:success:failure:]
 */
- (void)flush:(void(^)(NSArray*))success failure:(void(^)(NSError*))failure {
    [self flush:NO success:success failure:failure];
}

- (void)flush:(BOOL)overrideSyncThreshold success:(void(^)(NSArray*))success failure:(void(^)(NSError*))failure {
    // Check if busy
    if (![self.isBusy compareTo:NO andSetValue:YES]) {
        if (failure) {
            NSError *error = [NSError errorWithDomain:@"TSHttpService" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Sync already in progress"}];
            failure(error);
        }
        return;
    }
    
    // Check network connection
    if (!self.hasNetworkConnection) {
        [self.isBusy setValue:NO];
        if (failure) {
            NSError *error = [NSError errorWithDomain:@"TSHttpService" code:2 userInfo:@{NSLocalizedDescriptionKey: @"No network connection"}];
            failure(error);
        }
        return;
    }
    
    // Check threshold
    NSInteger unlockedCount = [self.database countOnlyUnlocked:YES];
    if (!overrideSyncThreshold && self.autoSyncThreshold > 0 && unlockedCount < self.autoSyncThreshold) {
        [self.isBusy setValue:NO];
        if (failure) {
            NSError *error = [NSError errorWithDomain:@"TSHttpService" code:TSHttpServiceErrorSyncInProgress userInfo:@{NSLocalizedDescriptionKey: @"Below sync threshold"}];
            failure(error);
        }
        return;
    }
    
    // Create background task
    BackgroundTaskManager *bgTaskManager = [BackgroundTaskManager sharedInstance];
    self.bgTask = [bgTaskManager createBackgroundTask];
    
    // Setup sync service callback
    __weak typeof(self) weakSelf = self;
    self.syncService.onHttpCallback = ^(HttpResponseEvent *event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Create HttpRequest and HttpResponse
        HttpRequest *request = [[HttpRequest alloc] init];
        request.requestData = event.requestData;
        request.url = [NSURL URLWithString:strongSelf.config.url];
        
        HttpResponse *response = [[HttpResponse alloc] initWithData:event.responseData
                                                         statusCode:event.statusCode
                                                               error:event.error];
        
        // Fire httpResponseBlock
        if (strongSelf.httpResponseBlock) {
            strongSelf.httpResponseBlock(request, response);
        }
        
        // Handle success/failure
        if (event.success || event.isSuccess) {
            if (success) {
                success(strongSelf.syncedRecords);
            }
        } else {
            if (failure) {
                NSError *error = event.error ?: [NSError errorWithDomain:@"TSHttpService" code:TSHttpServiceErrorResponse userInfo:@{NSLocalizedDescriptionKey: @"HTTP request failed"}];
                failure(error);
            }
        }
        
        // Release busy flag
        [strongSelf.isBusy setValue:NO];
        
        // Stop background task
        if (strongSelf.bgTask != UIBackgroundTaskInvalid) {
            [bgTaskManager stopBackgroundTask:strongSelf.bgTask];
            strongSelf.bgTask = UIBackgroundTaskInvalid;
        }
    };
    
    // Perform sync
    [self.syncService sync];
}

#pragma mark - Monitoring

/**
 * Start monitoring
 * iOS_PRECEDUR pattern: -[TSHttpService startMonitoring]
 */
- (void)startMonitoring {
    [self.reachability startMonitoring];
    
    __weak typeof(self) weakSelf = self;
    self.reachability.reachabilityChangedBlock = ^(TSReachability *reachability) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateNetworkConnection];
        
        // Fire connectivity change event
        TSConnectivityChangeEvent *event = [[TSConnectivityChangeEvent alloc] initWithConnected:strongSelf.hasNetworkConnection];
        
        for (void (^listener)(TSConnectivityChangeEvent*) in strongSelf.connectivityChangeListeners) {
            listener(event);
        }
    };
}

/**
 * Stop monitoring
 * iOS_PRECEDUR pattern: -[TSHttpService stopMonitoring]
 */
- (void)stopMonitoring {
    [self.reachability stopMonitoring];
}

#pragma mark - Event Listeners

/**
 * On connectivity change
 * iOS_PRECEDUR pattern: -[TSHttpService onConnectivityChange:]
 */
- (void)onConnectivityChange:(void (^)(TSConnectivityChangeEvent*))success {
    if (success) {
        [self.connectivityChangeListeners addObject:success];
    }
}

/**
 * On authorization
 * iOS_PRECEDUR pattern: -[TSHttpService onAuthorization:]
 */
- (void)onAuthorization:(void(^)(TSAuthorizationEvent*))callback {
    if (callback) {
        [self.authorizationListeners addObject:callback];
    }
}

/**
 * Remove listener
 * iOS_PRECEDUR pattern: -[TSHttpService un:callback:]
 */
- (void)un:(NSString*)event callback:(void(^)(id))callback {
    if ([event isEqualToString:@"connectivitychange"]) {
        [self.connectivityChangeListeners removeObject:callback];
    } else if ([event isEqualToString:@"authorization"]) {
        [self.authorizationListeners removeObject:callback];
    }
}

/**
 * Remove all listeners
 * iOS_PRECEDUR pattern: -[TSHttpService removeListeners]
 */
- (void)removeListeners {
    [self.connectivityChangeListeners removeAllObjects];
    [self.authorizationListeners removeAllObjects];
}

/**
 * Remove listeners for event
 * iOS_PRECEDUR pattern: -[TSHttpService removeListeners:]
 */
- (void)removeListeners:(NSString*)event {
    if ([event isEqualToString:@"connectivitychange"]) {
        [self.connectivityChangeListeners removeAllObjects];
    } else if ([event isEqualToString:@"authorization"]) {
        [self.authorizationListeners removeAllObjects];
    }
}

#pragma mark - Private Methods

- (void)updateNetworkConnection {
    self.hasNetworkConnection = [self.reachability isReachable];
}

@end

