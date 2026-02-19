//
//  TSSchedule.m
//  RNBackgroundLocation
//
//  Schedule Model - ExampleIOS/TSSchedule.h pattern'ine göre
//

#import "TSSchedule.h"
#import "TSConfig.h"
#import "LogHelper.h"

@implementation TSSchedule

- (instancetype)init {
    self = [super init];
    if (self) {
        _triggered = NO;
        _trackingMode = tsTrackingModeLocation;
    }
    return self;
}

- (instancetype)initWithRecord:(NSString*)data andHandler:(void (^)(TSSchedule*))handler {
    self = [self init];
    if (self) {
        _handlerBlock = handler;
        
        // Parse schedule string format: "1-7 09:00-17:00" or "2019-01-01 09:00-17:00"
        // Format: [days] [startTime]-[endTime] or [date] [startTime]-[endTime]
        NSArray *components = [data componentsSeparatedByString:@" "];
        
        if (components.count >= 2) {
            NSString *dayOrDate = components[0];
            NSString *timeRange = components[1];
            
            // Parse time range (e.g., "09:00-17:00")
            NSArray *times = [timeRange componentsSeparatedByString:@"-"];
            if (times.count == 2) {
                NSString *startTimeStr = times[0];
                NSString *endTimeStr = times[1];
                
                // Parse start time
                NSArray *startComponents = [startTimeStr componentsSeparatedByString:@":"];
                if (startComponents.count == 2) {
                    NSInteger hour = [startComponents[0] integerValue];
                    NSInteger minute = [startComponents[1] integerValue];
                    
                    _onTime = [[NSDateComponents alloc] init];
                    _onTime.hour = hour;
                    _onTime.minute = minute;
                }
                
                // Parse end time
                NSArray *endComponents = [endTimeStr componentsSeparatedByString:@":"];
                if (endComponents.count == 2) {
                    NSInteger hour = [endComponents[0] integerValue];
                    NSInteger minute = [endComponents[1] integerValue];
                    
                    _offTime = [[NSDateComponents alloc] init];
                    _offTime.hour = hour;
                    _offTime.minute = minute;
                }
            }
            
            // Check if dayOrDate is a literal date (YYYY-MM-DD) or day range (1-7)
            NSArray *dateComponents = [dayOrDate componentsSeparatedByString:@"-"];
            if (dateComponents.count == 3) {
                // Literal date: YYYY-MM-DD
                NSInteger year = [dateComponents[0] integerValue];
                NSInteger month = [dateComponents[1] integerValue];
                NSInteger day = [dateComponents[2] integerValue];
                
                NSCalendar *calendar = [NSCalendar currentCalendar];
                _onDate = [calendar dateWithEra:1 year:year month:month day:day hour:0 minute:0 second:0 nanosecond:0];
                
                // Set offDate to same day
                _offDate = _onDate;
            }
        }
    }
    return self;
}

- (void)make:(NSDateComponents*)dateComponents {
    // Set day of week from dateComponents
    if (dateComponents.weekday) {
        // weekday is 1-7 (Sunday=1, Monday=2, etc.)
        // Store in onTime/offTime if needed
    }
}

- (BOOL)isNext:(NSDate*)now {
    if (!_onTime || !_offTime) {
        return NO;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *nowComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitWeekday fromDate:now];
    
    // Check if current time is within schedule window
    NSInteger nowMinutes = nowComponents.hour * 60 + nowComponents.minute;
    NSInteger onMinutes = _onTime.hour * 60 + _onTime.minute;
    NSInteger offMinutes = _offTime.hour * 60 + _offTime.minute;
    
    // Handle day check if needed
    if ([self hasDay:nowComponents.weekday]) {
        return (nowMinutes >= onMinutes && nowMinutes < offMinutes);
    }
    
    return NO;
}

- (BOOL)isLiteralDate {
    return _onDate != nil;
}

- (BOOL)hasDay:(NSInteger)day {
    // For now, accept all days
    // In full implementation, this would check against parsed day range
    return YES;
}

- (BOOL)startsBefore:(NSDate*)now {
    if (!_onTime) {
        return NO;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *nowComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:now];
    
    NSInteger nowMinutes = nowComponents.hour * 60 + nowComponents.minute;
    NSInteger onMinutes = _onTime.hour * 60 + _onTime.minute;
    
    return nowMinutes < onMinutes;
}

- (BOOL)startsAfter:(NSDate*)now {
    if (!_onTime) {
        return NO;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *nowComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:now];
    
    NSInteger nowMinutes = nowComponents.hour * 60 + nowComponents.minute;
    NSInteger onMinutes = _onTime.hour * 60 + _onTime.minute;
    
    return nowMinutes > onMinutes;
}

- (BOOL)endsBefore:(NSDate*)now {
    if (!_offTime) {
        return NO;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *nowComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:now];
    
    NSInteger nowMinutes = nowComponents.hour * 60 + nowComponents.minute;
    NSInteger offMinutes = _offTime.hour * 60 + _offTime.minute;
    
    return nowMinutes < offMinutes;
}

- (BOOL)endsAfter:(NSDate*)now {
    if (!_offTime) {
        return NO;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *nowComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:now];
    
    NSInteger nowMinutes = nowComponents.hour * 60 + nowComponents.minute;
    NSInteger offMinutes = _offTime.hour * 60 + _offTime.minute;
    
    return nowMinutes > offMinutes;
}

- (BOOL)expired {
    if (!_onDate) {
        return NO;
    }
    
    NSDate *now = [NSDate date];
    return [now compare:_onDate] == NSOrderedDescending;
}

- (void)trigger:(BOOL)enabled {
    _triggered = enabled;
    
    if (_handlerBlock) {
        _handlerBlock(self);
    }
}

- (void)reset {
    _triggered = NO;
}

- (void)evaluate {
    NSDate *now = [NSDate date];
    
    if ([self isNext:now]) {
        if (!_triggered) {
            [self trigger:YES];
        }
    } else {
        if (_triggered) {
            [self trigger:NO];
        }
    }
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    if (_onTime) {
        NSMutableDictionary *onTimeDict = [NSMutableDictionary dictionary];
        onTimeDict[@"hour"] = @(_onTime.hour);
        onTimeDict[@"minute"] = @(_onTime.minute);
        json[@"onTime"] = onTimeDict;
    }
    
    if (_offTime) {
        NSMutableDictionary *offTimeDict = [NSMutableDictionary dictionary];
        offTimeDict[@"hour"] = @(_offTime.hour);
        offTimeDict[@"minute"] = @(_offTime.minute);
        json[@"offTime"] = offTimeDict;
    }
    
    if (_onDate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd";
        json[@"onDate"] = [formatter stringFromDate:_onDate];
    }
    
    if (_offDate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd";
        json[@"offDate"] = [formatter stringFromDate:_offDate];
    }
    
    json[@"triggered"] = @(_triggered);
    json[@"trackingMode"] = @(_trackingMode);
    
    return json;
}

@end

