//
//  TSScheduler.m
//  RNBackgroundLocation
//
//  Scheduler - ExampleIOS pattern'ine göre
//

#import "TSScheduler.h"
#import "TSSchedule.h"
#import "TSConfig.h"
#import "TSLocationManager.h"
#import "LogHelper.h"
#import <UserNotifications/UserNotifications.h>

@interface TSScheduler ()
@property (nonatomic, strong) NSMutableArray<TSSchedule*> *schedules;
@property (nonatomic, assign) BOOL isStarted;
@property (nonatomic, strong) NSTimer *evaluationTimer;
@end

@implementation TSScheduler

+ (instancetype)sharedInstance {
    static TSScheduler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TSScheduler alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _schedules = [NSMutableArray array];
        _isStarted = NO;
    }
    return self;
}

- (void)parse:(NSArray*)scheduleArray {
    [_schedules removeAllObjects];
    
    if (!scheduleArray || scheduleArray.count == 0) {
        [LogHelper w:@"TSScheduler" message:@"Received an empty schedule"];
        return;
    }
    
    __typeof(self) __weak weakSelf = self;
    for (NSString *scheduleString in scheduleArray) {
        if ([scheduleString isKindOfClass:[NSString class]] && scheduleString.length > 0) {
            TSSchedule *schedule = [[TSSchedule alloc] initWithRecord:scheduleString andHandler:^(TSSchedule *s) {
                __typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                
                // Handle schedule trigger
                TSLocationManager *manager = [TSLocationManager sharedInstance];
                TSConfig *config = [TSConfig sharedInstance];
                
                if (s.triggered) {
                    // Enable tracking
                    if (!config.enabled) {
                        [LogHelper d:@"TSScheduler" message:@"Schedule triggered: ENABLING tracking"];
                        [manager start];
                    }
                } else {
                    // Disable tracking
                    if (config.enabled) {
                        [LogHelper d:@"TSScheduler" message:@"Schedule triggered: DISABLING tracking"];
                        [manager stop];
                    }
                }
            }];
            
            // Skip expired literal dates
            if (![schedule isLiteralDate] || ![schedule expired]) {
                [_schedules addObject:schedule];
            }
        }
    }
    
    // Sort schedules by onTime
    [_schedules sortUsingComparator:^NSComparisonResult(TSSchedule *s1, TSSchedule *s2) {
        if (!s1.onTime || !s2.onTime) {
            return NSOrderedSame;
        }
        
        NSInteger s1Minutes = s1.onTime.hour * 60 + s1.onTime.minute;
        NSInteger s2Minutes = s2.onTime.hour * 60 + s2.onTime.minute;
        
        if (s1Minutes < s2Minutes) {
            return NSOrderedAscending;
        } else if (s1Minutes > s2Minutes) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    
    [LogHelper d:@"TSScheduler" message:[NSString stringWithFormat:@"Parsed %lu schedules", (unsigned long)_schedules.count]];
}

- (void)start {
    if (_isStarted) {
        return;
    }
    
    TSConfig *config = [TSConfig sharedInstance];
    if (!config.hasSchedule) {
        [LogHelper w:@"TSScheduler" message:@"Cannot start scheduler: no schedule configured"];
        return;
    }
    
    // Parse schedules from config
    [self parse:config.schedule];
    
    if (_schedules.count == 0) {
        [LogHelper w:@"TSScheduler" message:@"Cannot start scheduler: no valid schedules"];
        return;
    }
    
    _isStarted = YES;
    
    // Start evaluation timer (check every minute)
    _evaluationTimer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                         target:self
                                                       selector:@selector(evaluate)
                                                       userInfo:nil
                                                        repeats:YES];
    
    // Initial evaluation
    [self evaluate];
    
    [LogHelper i:@"TSScheduler" message:@"✅ Scheduler started"];
}

- (void)stop {
    if (!_isStarted) {
        return;
    }
    
    _isStarted = NO;
    
    // Stop evaluation timer
    if (_evaluationTimer) {
        [_evaluationTimer invalidate];
        _evaluationTimer = nil;
    }
    
    // Cancel all notifications
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllPendingNotificationRequests];
    
    [LogHelper i:@"TSScheduler" message:@"⏸️ Scheduler stopped"];
}

- (void)evaluate {
    if (!_isStarted || _schedules.count == 0) {
        return;
    }
    
    NSDate *now = [NSDate date];
    TSConfig *config = [TSConfig sharedInstance];
    BOOL currentlyEnabled = config.enabled;
    
    TSSchedule *nextSchedule = [self findNextSchedule:now];
    
    if (nextSchedule) {
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *nowComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:now];
        
        NSInteger nowMinutes = nowComponents.hour * 60 + nowComponents.minute;
        NSInteger onMinutes = nextSchedule.onTime.hour * 60 + nextSchedule.onTime.minute;
        NSInteger offMinutes = nextSchedule.offTime.hour * 60 + nextSchedule.offTime.minute;
        
        if (nowMinutes >= onMinutes && nowMinutes < offMinutes) {
            // Currently in schedule window
            if (!currentlyEnabled) {
                [LogHelper d:@"TSScheduler" message:@"Scheduler says we should be ENABLED but we are NOT"];
                TSTrackingMode trackingMode = nextSchedule.trackingMode;
                [self scheduleAlarm:YES date:now trackingMode:trackingMode];
            } else {
                // Schedule next alarm for offTime
                NSDate *offDate = [self getDateForTime:nextSchedule.offTime onDate:now];
                TSTrackingMode trackingMode = nextSchedule.trackingMode;
                [self scheduleAlarm:NO date:offDate trackingMode:trackingMode];
            }
        } else if (nowMinutes < onMinutes) {
            // Before schedule window
            if (currentlyEnabled) {
                [LogHelper d:@"TSScheduler" message:@"Scheduler says we should be DISABLED but we are NOT"];
                TSTrackingMode trackingMode = nextSchedule.trackingMode;
                [self scheduleAlarm:NO date:now trackingMode:trackingMode];
            } else {
                // Schedule alarm for onTime
                NSDate *onDate = [self getDateForTime:nextSchedule.onTime onDate:now];
                TSTrackingMode trackingMode = nextSchedule.trackingMode;
                [self scheduleAlarm:YES date:onDate trackingMode:trackingMode];
            }
        } else if (nowMinutes >= offMinutes) {
            // After schedule window - check tomorrow
            [LogHelper d:@"TSScheduler" message:@"Scheduler failed to find any alarms today. Checking tomorrow..."];
            NSDate *tomorrow = [self getTomorrow:now];
            [self evaluateForDate:tomorrow enabled:currentlyEnabled];
        }
    } else {
        // No schedule found for today
        if (currentlyEnabled) {
            [LogHelper d:@"TSScheduler" message:@"Scheduler says we should be DISABLED but we are NOT"];
            [self scheduleAlarm:NO date:now trackingMode:tsTrackingModeLocation];
        } else {
            // Try tomorrow
            NSDate *tomorrow = [self getTomorrow:now];
            [self evaluateForDate:tomorrow enabled:currentlyEnabled];
        }
    }
}

- (void)evaluateForDate:(NSDate*)date enabled:(BOOL)enabled {
    // Recursive evaluation for next day
    // Limit recursion to prevent infinite loops
    static NSInteger recursionDepth = 0;
    if (recursionDepth > 7) {
        [LogHelper w:@"TSScheduler" message:@"Failed to find a schedule. Giving up."];
        recursionDepth = 0;
        return;
    }
    
    recursionDepth++;
    
    TSSchedule *nextSchedule = [self findNextSchedule:date];
    if (nextSchedule) {
        NSDate *onDate = [self getDateForTime:nextSchedule.onTime onDate:date];
        TSTrackingMode trackingMode = nextSchedule.trackingMode;
        [self scheduleAlarm:YES date:onDate trackingMode:trackingMode];
    }
    
    recursionDepth--;
}

- (nullable TSSchedule*)findNextSchedule:(NSDate*)now {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *nowComponents = [calendar components:NSCalendarUnitWeekday fromDate:now];
    NSInteger currentDay = nowComponents.weekday;
    
    for (TSSchedule *schedule in _schedules) {
        if ([schedule hasDay:currentDay] && [schedule isNext:now]) {
            return schedule;
        }
    }
    
    return nil;
}

- (NSCalendar*)getCalendar {
    return [NSCalendar currentCalendar];
}

- (NSDate*)getTomorrow:(NSDate*)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.day = 1;
    return [calendar dateByAddingComponents:components toDate:date options:0];
}

- (NSDate*)getDateForTime:(NSDateComponents*)timeComponents onDate:(NSDate*)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    components.hour = timeComponents.hour;
    components.minute = timeComponents.minute;
    components.second = 0;
    
    return [calendar dateFromComponents:components];
}

- (void)scheduleAlarm:(BOOL)enabled date:(NSDate*)date trackingMode:(TSTrackingMode)trackingMode {
    // Use UNUserNotificationCenter for iOS scheduling
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = enabled ? @"Location Tracking Started" : @"Location Tracking Stopped";
    content.body = enabled ? @"Scheduler enabled location tracking" : @"Scheduler disabled location tracking";
    content.sound = [UNNotificationSound defaultSound];
    
    // Add userInfo for handling
    content.userInfo = @{
        @"action": enabled ? @"ENABLE" : @"DISABLE",
        @"trackingMode": @(trackingMode)
    };
    
    // Create trigger for specific date
    NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute fromDate:date];
    UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:dateComponents repeats:NO];
    
    // Create request
    NSString *identifier = [NSString stringWithFormat:@"schedule_%@_%ld", enabled ? @"enable" : @"disable", (long)[date timeIntervalSince1970]];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
    
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            [LogHelper e:@"TSScheduler" message:[NSString stringWithFormat:@"Failed to schedule alarm: %@", error.localizedDescription] error:error];
        } else {
            [LogHelper d:@"TSScheduler" message:[NSString stringWithFormat:@"Scheduled alarm for %@: %@", enabled ? @"ENABLE" : @"DISABLE", date]];
        }
    }];
}

- (void)handleEvent:(NSDictionary*)event {
    NSString *action = event[@"action"];
    NSNumber *trackingModeNum = event[@"trackingMode"];
    TSTrackingMode trackingMode = trackingModeNum ? [trackingModeNum integerValue] : tsTrackingModeLocation;
    
    TSLocationManager *manager = [TSLocationManager sharedInstance];
    
    if ([action isEqualToString:@"ENABLE"]) {
        [manager start];
    } else if ([action isEqualToString:@"DISABLE"]) {
        [manager stop];
    }
}

@end

