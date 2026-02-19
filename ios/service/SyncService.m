//
//  SyncService.m
//  RNBackgroundLocation
//
//  HTTP Sync Service
//  Android SyncService.java benzeri
//   LOCKING mekanizmalı batch sync
//

#import "SyncService.h"
#import "TSConfig.h"
#import "TSAuthorization.h"
#import "LocationModel.h"
#import "SQLiteLocationDAO.h"
#import "HttpResponseEvent.h"
#import "LogHelper.h"
#import "TSReachability.h"

@interface SyncService ()
@property (nonatomic, strong) TSConfig *config;
@property (nonatomic, strong) SQLiteLocationDAO *database;
@property (nonatomic, assign) BOOL isSyncing; // AtomicBoolean benzeri (iOS'ta @synchronized kullanacağız)
@property (nonatomic, assign) BOOL isRecursiveSync; // Flag to skip threshold check in recursive calls
@end

@implementation SyncService

+ (instancetype)sharedInstance {
    static SyncService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SyncService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _config = [TSConfig sharedInstance];
        _database = [SQLiteLocationDAO sharedInstance];
        _isSyncing = NO;
    }
    return self;
}

+ (void)sync {
    [[self sharedInstance] sync];
}

- (void)sync {
    // Thread-safe check (Android AtomicBoolean.compareAndSet benzeri)
    @synchronized(self) {
        if (self.isSyncing) {
            [LogHelper i:@"SyncService" message:@"⏸️ HttpService is busy, skipping"];
            return;
        }
        self.isSyncing = YES;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performSync];
    });
}

- (void)performSync {
    @try {
        // CRITICAL: Check network connection FIRST
        // If no internet, don't try to sync - locations are already saved in SQLite
        TSReachability *reachability = [TSReachability reachabilityForInternetConnection];
        BOOL hasNetwork = [reachability isReachable];
        
        if (!hasNetwork) {
            [LogHelper w:@"SyncService" message:@"📵 No network connection, skipping sync (locations saved in SQLite for later)"];
            [self releaseSync];
            return;
        }
        
        // 1. Get unlocked count ()
        NSInteger unlockedCount = [self.database countOnlyUnlocked:YES];
        
        [LogHelper i:@"SyncService" message:[NSString stringWithFormat:@"📊 Unlocked locations: %ld (recursive: %@)", (long)unlockedCount, self.isRecursiveSync ? @"YES" : @"NO"]];
        
        // CRITICAL: Check threshold ONLY for initial sync trigger (NOT in recursive calls)
        // If autoSyncThreshold > 0, only start sync if count >= threshold
        // BUT: Once sync starts (recursive), continue until ALL locations are synced
        // This ensures offline locations are all synced when internet returns
        // CRITICAL: Skip threshold check if this is a recursive sync call
        if (!self.isRecursiveSync && self.config.autoSyncThreshold > 0 && unlockedCount < self.config.autoSyncThreshold) {
            [LogHelper i:@"SyncService" message:[NSString stringWithFormat:@"⏸️ Below threshold (%ld < %ld), skipping sync", (long)unlockedCount, (long)self.config.autoSyncThreshold]];
            [self releaseSync];
            return;
        }
        
        // If we have locations to sync (even if below threshold in recursive calls), continue
        if (unlockedCount == 0) {
            [LogHelper i:@"SyncService" message:@"ℹ️ No locations to sync"];
            [self releaseSync];
            return;
        }
        
        // 2. CRITICAL: Get locations WITH LOCKING ()
        // This will SELECT WHERE locked=0 and UPDATE SET locked=1
        NSArray<LocationModel *> *locations = [self.database allWithLocking:self.config.maxBatchSize];
        
        if (locations.count == 0) {
            [LogHelper i:@"SyncService" message:@"ℹ️ No locations to sync"];
            [self releaseSync];
            return;
        }
        
        [LogHelper i:@"SyncService" message:[NSString stringWithFormat:@"🔒 Locked %lu records (allWithLocking)", (unsigned long)locations.count]];
        
        // 3. Convert to JSON array (batch)
        NSMutableArray *jsonArray = [NSMutableArray array];
        for (LocationModel *location in locations) {
            [jsonArray addObject:[location toDictionary]];
        }
        
        // 4. Prepare request body
        NSMutableDictionary *body = [NSMutableDictionary dictionary];
        
        // Check batchSync mode
        if (self.config.batchSync) {
            // Batch mode: wrap in "locations" array
            body[@"locations"] = jsonArray;
        } else {
            // Single mode: send first location only
            if (jsonArray.count > 0) {
                body = [jsonArray.firstObject mutableCopy];
            }
        }
        
        // Merge params from config
        NSDictionary *params = [self.config getParamsDictionary];
        if (params.count > 0) {
            [body addEntriesFromDictionary:params];
        }
        
        // 5. Create URL request
        NSURL *url = [NSURL URLWithString:self.config.url];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = self.config.method ?: @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        // Add headers from config
        NSDictionary *headers = [self.config getHeadersDictionary];
        for (NSString *key in headers) {
            [request setValue:headers[key] forHTTPHeaderField:key];
        }
        
        // Apply authorization (TSAuthorization pattern)
        if (self.config.authorization) {
            [self.config.authorization apply:request];
        }
        
        // Body
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        if (error) {
            [LogHelper e:@"SyncService" message:[NSString stringWithFormat:@"❌ Failed to serialize JSON: %@", error.localizedDescription] error:error];
            [self unlockLocations:locations];
            [self releaseSync];
            return;
        }
        request.HTTPBody = jsonData;
        
        [LogHelper i:@"SyncService" message:[NSString stringWithFormat:@"HTTP %@ batch (%lu) to %@", self.config.method, (unsigned long)locations.count, self.config.url]];
        
        // 6. Execute request
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 30.0;
        
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request 
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSInteger statusCode = httpResponse.statusCode;
            NSString *responseText = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
            
            BOOL success = (statusCode >= 200 && statusCode < 300) && (error == nil);
            
            [LogHelper i:@"SyncService" message:[NSString stringWithFormat:@"HTTP Response: %ld - %@", (long)statusCode, success ? @"SUCCESS" : @"FAILED"]];
            
            // 7. Emit HTTP event (Android EventBus yerine callback)
            HttpResponseEvent *httpEvent = [[HttpResponseEvent alloc] initWithStatusCode:statusCode 
                                                                                  success:success 
                                                                            responseText:responseText];
            if (self.onHttpCallback) {
                self.onHttpCallback(httpEvent);
            }
            
            if (success) {
                // 8. SUCCESS: Delete synced locations ()
                [self.database destroyAll:locations];
                [LogHelper i:@"SyncService" message:[NSString stringWithFormat:@"✅ DELETED %lu synced records", (unsigned long)locations.count]];
                
                // CRITICAL: Check if there are more to sync (Transistorsoft recursive pattern)
                // Recursive sync should continue until ALL pending locations are synced
                // Don't check threshold here - if there are any remaining locations, sync them
                NSInteger remaining = [self.database countOnlyUnlocked:YES];
                if (remaining > 0) {
                    // Recursively sync more - continue until all locations are synced
                    [LogHelper i:@"SyncService" message:[NSString stringWithFormat:@"🔄 More locations to sync (%ld), continuing recursive sync...", (long)remaining]];
                    // CRITICAL: Set recursive flag BEFORE recursive call
                    self.isRecursiveSync = YES;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                        [self performSync]; // Recursive call - will sync ALL remaining locations (threshold check skipped)
                    });
                    return; // Don't release sync yet, continue syncing
                } else {
                    [LogHelper i:@"SyncService" message:@"✅ All locations synced successfully"];
                    // CRITICAL: Reset recursive flag when all locations are synced
                    self.isRecursiveSync = NO;
                }
            } else {
                // 9. FAILURE: Unlock locations for retry ()
                [self unlockLocations:locations];
                [LogHelper w:@"SyncService" message:[NSString stringWithFormat:@"🔓 UNLOCKED %lu records (will retry later)", (unsigned long)locations.count]];
            }
            
            [self releaseSync];
        }];
        
        [task resume];
        
    } @catch (NSException *exception) {
        [LogHelper e:@"SyncService" message:[NSString stringWithFormat:@"❌ Sync exception: %@", exception.reason]];
        
        // On exception, unlock all to be safe ()
        @try {
            [self.database unlockAll];
            [LogHelper w:@"SyncService" message:@"🔓 Unlocked all locations due to exception"];
        } @catch (NSException *ex) {
            [LogHelper e:@"SyncService" message:[NSString stringWithFormat:@"❌ Failed to unlock: %@", ex.reason]];
        }
        
        [self releaseSync];
    }
}

- (void)unlockLocations:(NSArray<LocationModel *> *)locations {
    [self.database unlock:locations];
}

- (void)releaseSync {
    @synchronized(self) {
        self.isSyncing = NO;
        // CRITICAL: Reset recursive flag when sync is released
        // This ensures next sync starts fresh (with threshold check)
        self.isRecursiveSync = NO;
    }
}

@end

