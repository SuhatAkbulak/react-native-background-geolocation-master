//
//  ActivityRecognitionService.m
//  RNBackgroundLocation
//
//  Activity Recognition Service
//  Android ActivityRecognitionService.java benzeri
//  iOS CoreMotion kullanarak
//

#import "ActivityRecognitionService.h"
#import "TSConfig.h"
#import "ActivityChangeEvent.h"
#import "MotionChangeEvent.h"
#import "LogHelper.h"
#import "LocationService.h"
#import "SQLiteLocationDAO.h"
#import <CoreMotion/CoreMotion.h>
#import <UserNotifications/UserNotifications.h>

@interface ActivityRecognitionService ()
@property (nonatomic, strong) CMMotionActivityManager *motionActivityManager;
@property (nonatomic, strong) NSOperationQueue *motionQueue;
@property (nonatomic, strong, nullable) CMMotionActivity *lastActivity;
@property (nonatomic, assign) BOOL isStarted;
@end

@implementation ActivityRecognitionService

+ (instancetype)sharedInstance {
    static ActivityRecognitionService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ActivityRecognitionService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _motionActivityManager = [[CMMotionActivityManager alloc] init];
        _motionQueue = [[NSOperationQueue alloc] init];
        _motionQueue.name = @"ActivityRecognitionQueue";
        _isStarted = NO;
    }
    return self;
}

+ (void)start {
    [[self sharedInstance] start];
}

+ (void)stop {
    [[self sharedInstance] stop];
}

+ (BOOL)isStarted {
    return [[self sharedInstance] isStarted];
}

+ (CMMotionActivity *)getLastActivity {
    return [[self sharedInstance] lastActivity];
}

+ (CMMotionActivity *)getMostProbableActivity {
    return [[self sharedInstance] lastActivity];
}

+ (BOOL)isMoving {
    ActivityRecognitionService *instance = [self sharedInstance];
    if (!instance.lastActivity) {
        return NO;
    }
    
    return instance.lastActivity.walking ||
           instance.lastActivity.running ||
           instance.lastActivity.automotive ||
           instance.lastActivity.cycling;
}

- (void)start {
    TSConfig *config = [TSConfig sharedInstance];
    
    // Check if motion activity updates are disabled
    if (config.disableMotionActivityUpdates) {
        [LogHelper d:@"ActivityRecognitionService" message:@"Motion activity updates disabled"];
        return;
    }
    
    // Check if motion activity is available
    if (![CMMotionActivityManager isActivityAvailable]) {
        [LogHelper w:@"ActivityRecognitionService" message:@"Motion activity not available on this device"];
        return;
    }
    
    if (self.isStarted) {
        return; // Already started
    }
    
    [LogHelper i:@"ActivityRecognitionService" message:@"✅ Start motion-activity updates"];
    
    __typeof(self) __weak me = self;
    
    // Query current activity first ()
    // CoreMotion sometimes doesn't send initial activity immediately
    NSDate *now = [NSDate date];
    NSDate *startDate = [NSDate dateWithTimeInterval:-300 sinceDate:now]; // Last 5 minutes
    
    [self.motionActivityManager queryActivityStartingFromDate:startDate
                                                        toDate:now
                                                       toQueue:self.motionQueue
                                                   withHandler:^(NSArray<CMMotionActivity *> *activities, NSError *error) {
        if (error) {
            [LogHelper w:@"ActivityRecognitionService" message:[NSString stringWithFormat:@"⚠️ Query activity error: %@", error.localizedDescription]];
        } else if (activities && activities.count > 0) {
            // Use the most recent activity
            CMMotionActivity *mostRecent = activities.lastObject;
            [me handleActivityUpdate:mostRecent];
            [LogHelper d:@"ActivityRecognitionService" message:[NSString stringWithFormat:@"📊 Queried %lu historical activities, using most recent", (unsigned long)activities.count]];
        }
    }];
    
    // Start listening for activity updates
    [self.motionActivityManager startActivityUpdatesToQueue:self.motionQueue withHandler:^(CMMotionActivity *activity) {
        [me handleActivityUpdate:activity];
    }];
    
    self.isStarted = YES;
}

- (void)stop {
    if (!self.isStarted) {
        return;
    }
    
    [LogHelper i:@"ActivityRecognitionService" message:@"🔴 Stop motion-activity updates"];
    
    [self.motionActivityManager stopActivityUpdates];
    self.isStarted = NO;
}

- (void)handleActivityUpdate:(CMMotionActivity *)activity {
    if (!activity) {
        return;
    }
    
    self.lastActivity = activity;
    
    // Determine activity type
    NSString *activityType = [self getActivityType:activity];
    NSInteger confidence = [self getConfidence:activity];
    
    // Debug: Log raw activity flags to understand what CoreMotion is sending
    TSConfig *config = [TSConfig sharedInstance];
    if (config.debug) {
        NSString *flags = [NSString stringWithFormat:@"🚶 walking:%d 🏃 running:%d 🚗 automotive:%d 🚴 cycling:%d 🛑 stationary:%d unknown:%d confidence:%ld",
                          activity.walking ? 1 : 0,
                          activity.running ? 1 : 0,
                          activity.automotive ? 1 : 0,
                          activity.cycling ? 1 : 0,
                          activity.stationary ? 1 : 0,
                          activity.unknown ? 1 : 0,
                          (long)activity.confidence];
        [LogHelper d:@"ActivityRecognitionService" message:[NSString stringWithFormat:@"📊 Raw Activity Update: %@", flags]];
    }
    
    [LogHelper d:@"ActivityRecognitionService" message:[NSString stringWithFormat:@"Activity: %@ (confidence: %ld)", activityType, (long)confidence]];
    
    // Create ActivityChangeEvent
    ActivityChangeEvent *activityEvent = [[ActivityChangeEvent alloc] initWithActivity:activityType confidence:confidence];
    
    // Debug notification for activity change ()
    if (config.debug) {
        NSString *emoji = @"❓";
        if ([activityType isEqualToString:@"in_vehicle"]) emoji = @"🚗";
        else if ([activityType isEqualToString:@"on_bicycle"]) emoji = @"🚴";
        else if ([activityType isEqualToString:@"running"]) emoji = @"🏃";
        else if ([activityType isEqualToString:@"walking"]) emoji = @"🚶";
        else if ([activityType isEqualToString:@"still"]) emoji = @"🛑";
        
        NSString *debugBody = [NSString stringWithFormat:@"%@ %@\n📊 Confidence: %ld%%",
                               emoji,
                               activityType,
                               (long)confidence];
        
        [self showDebugNotification:@"🚶 Activity Change" body:debugBody];
    }
    
    // CRITICAL: Always call callback - let TSLocationManager decide if enabled
    // This ensures we don't miss any sensor updates
    if (self.onActivityChange) {
        self.onActivityChange(activityEvent);
    } else {
        if (config.debug) {
            [LogHelper w:@"ActivityRecognitionService" message:@"⚠️ Activity update received but no callback set"];
        }
    }
    
    // Check if this is a "moving" activity
    BOOL isMoving = activity.walking || activity.running || activity.automotive || activity.cycling;
    
    // Update config if needed
    if (config.isMoving != isMoving) {
        config.isMoving = isMoving;
        [config save];
        
        // Create MotionChangeEvent
        NSDictionary *locationJson = @{
            @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000),
            @"is_moving": @(isMoving),
            @"activity": activityType
        };
        
        MotionChangeEvent *motionEvent = [[MotionChangeEvent alloc] initWithIsMoving:isMoving location:locationJson];
        
        // Debug notification for motion change ()
        if (config.debug) {
            NSString *emoji = isMoving ? @"🏃" : @"🛑";
            NSString *status = isMoving ? @"MOVING" : @"STATIONARY";
            NSString *debugBody = [NSString stringWithFormat:@"%@ %@\n🚶 Activity: %@",
                                   emoji,
                                   status,
                                   activityType];
            
            [self showDebugNotification:@"🔄 Motion Change" body:debugBody];
        }
        
        // Call callback
        if (self.onMotionChange) {
            self.onMotionChange(isMoving, locationJson);
        }
    }
}

#pragma mark - Debug Notifications Helper

- (void)showDebugNotification:(NSString *)title body:(NSString *)body {
    TSConfig *config = [TSConfig sharedInstance];
    if (!config.debug) {
        return; // Only show in debug mode
    }
    
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
                content.title = title;
                content.body = body;
                content.sound = nil; // Silent
                
                // Get location count from SQLiteLocationDAO
                SQLiteLocationDAO *database = [SQLiteLocationDAO sharedInstance];
                if (database) {
                    NSInteger locationCount = [database count];
                    content.badge = @(locationCount);
                }
                
                // Use unique identifier for each notification (so they stack)
                NSString *identifier = [NSString stringWithFormat:@"DebugNotification_%ld", (long)([[NSDate date] timeIntervalSince1970] * 1000)];
                
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                                      content:content
                                                                                      trigger:nil];
                
                [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        [LogHelper e:@"ActivityRecognitionService" message:[NSString stringWithFormat:@"❌ Failed to show debug notification: %@", error.localizedDescription] error:error];
                    } else {
                        [LogHelper d:@"ActivityRecognitionService" message:[NSString stringWithFormat:@"🔔 Debug notification: %@", title]];
                    }
                }];
            }
        }];
    }
}

- (NSString *)getActivityType:(CMMotionActivity *)activity {
    // CoreMotion can have multiple flags true at once
    // Priority: automotive > cycling > running > walking > stationary > unknown
    // This matches Android's DetectedActivity pattern and Transistorsoft's behavior
    if (activity.automotive) {
        return @"in_vehicle";
    }
    if (activity.cycling) {
        return @"on_bicycle";
    }
    if (activity.running) {
        return @"running";
    }
    if (activity.walking) {
        return @"walking";
    }
    if (activity.stationary) {
        return @"still";
    }
    if (activity.unknown) {
        return @"unknown";
    }
    // Fallback: if no flags are set (shouldn't happen, but just in case)
    return @"unknown";
}

- (NSInteger)getConfidence:(CMMotionActivity *)activity {
    // CMMotionActivity doesn't provide confidence directly
    // We'll use a simple heuristic based on activity types
    if (activity.automotive && activity.confidence == CMMotionActivityConfidenceHigh) {
        return 100;
    } else if (activity.confidence == CMMotionActivityConfidenceHigh) {
        return 90;
    } else if (activity.confidence == CMMotionActivityConfidenceMedium) {
        return 70;
    } else {
        return 50;
    }
}

@end

