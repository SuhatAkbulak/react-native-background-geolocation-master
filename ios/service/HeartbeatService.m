//
//  HeartbeatService.m
//  RNBackgroundLocation
//
//  Heartbeat Service
//  Android HeartbeatService.java benzeri
//

#import "HeartbeatService.h"
#import "TSConfig.h"
#import "LocationModel.h"
#import "HeartbeatEvent.h"
#import "SyncService.h"
#import "ActivityRecognitionService.h"
#import "LogHelper.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>

static NSString *const ACTION = @"HEARTBEAT";

@interface HeartbeatService ()
@property (nonatomic, strong) NSTimer *heartbeatTimer;
@property (nonatomic, strong) CLLocationManager *locationManager;
@end

@implementation HeartbeatService

+ (instancetype)sharedInstance {
    static HeartbeatService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HeartbeatService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return self;
}

+ (void)start {
    [[self sharedInstance] start];
}

+ (void)stop {
    [[self sharedInstance] stop];
}

+ (void)onHeartbeat {
    [[self sharedInstance] onHeartbeat];
}

- (void)start {
    TSConfig *config = [TSConfig sharedInstance];
    NSInteger interval = config.heartbeatInterval;
    
    if (interval <= 0) {
        [self stop];
        return;
    }
    
    [LogHelper i:@"HeartbeatService" message:[NSString stringWithFormat:@"✅ Start heartbeat (%lds)", (long)interval]];
    
    // Cancel existing timer
    [self stop];
    
    // Schedule heartbeat
    __typeof(self) __weak me = self;
    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                           repeats:YES
                                                             block:^(NSTimer * _Nonnull timer) {
        [me onHeartbeat];
    }];
}

- (void)stop {
    [LogHelper i:@"HeartbeatService" message:@"🔴 Stop heartbeat"];
    
    if (self.heartbeatTimer) {
        [self.heartbeatTimer invalidate];
        self.heartbeatTimer = nil;
    }
}

- (void)onHeartbeat {
    TSConfig *config = [TSConfig sharedInstance];
    NSInteger interval = config.heartbeatInterval;
    
    if (interval <= 0) {
        [self stop];
        return;
    }
    
    // CRITICAL: Sadece enabled=true iken heartbeat gönder
    // Bu, start() çağrılmadan önce heartbeat event'lerini engeller
    if (!config.enabled) {
        if (config.debug) {
            [LogHelper d:@"HeartbeatService" message:@"⏸️ Heartbeat ignored (enabled=false)"];
        }
        return;
    }
    
    [LogHelper d:@"HeartbeatService" message:@"❤️ Heartbeat triggered"];
    
    // Get last location
    CLLocation *lastLocation = self.locationManager.location;
    
    if (!lastLocation) {
        [LogHelper w:@"HeartbeatService" message:@"Last location is null"];
        return;
    }
    
    // Create location model
    LocationModel *locationModel = [[LocationModel alloc] initWithCLLocation:lastLocation];
    locationModel.isMoving = config.isMoving;
    locationModel.locationType = LOCATION_TYPE_HEARTBEAT; // 
    locationModel.event = @"heartbeat";
    
    // Get activity from ActivityRecognitionService if available
    CMMotionActivity *lastActivity = [ActivityRecognitionService getLastActivity];
    if (lastActivity) {
        locationModel.activityType = [self getActivityName:lastActivity];
    }
    
    // Set event type to "heartbeat"
    NSMutableDictionary *locationDict = [[locationModel toDictionary] mutableCopy];
    
    // Create heartbeat event
    HeartbeatEvent *heartbeatEvent = [[HeartbeatEvent alloc] initWithLocation:locationDict];
    
    // Call callback
    if (self.onHeartbeatCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onHeartbeatCallback(heartbeatEvent);
        });
    }
    
    // Auto-sync if enabled
    if (config.autoSync && config.url.length > 0) {
        [SyncService sync];
    }
}

- (NSString *)getActivityName:(CMMotionActivity *)activity {
    if (activity.automotive) {
        return @"in_vehicle";
    } else if (activity.cycling) {
        return @"on_bicycle";
    } else if (activity.running) {
        return @"running";
    } else if (activity.walking) {
        return @"walking";
    } else if (activity.stationary) {
        return @"still";
    } else {
        return @"unknown";
    }
}

@end

