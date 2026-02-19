//
//  TSConfigBuilder.m
//  RNBackgroundLocation
//
//  TSConfigBuilder - ExampleIOS/TSConfig.h pattern'ine göre
//

#import "TSConfig.h"
#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>

@interface TSConfigBuilder ()
@property (nonatomic, strong) NSMutableSet *dirtyProperties;
@end

@implementation TSConfigBuilder

- (instancetype)init {
    self = [super init];
    if (self) {
        _dirtyProperties = [NSMutableSet set];
        [self applyDefaults];
        
        // Observe all properties for dirty tracking (iOS_PRECEDUR pattern)
        __typeof(self) __weak weakSelf = self;
        [TSConfigBuilder eachProperty:[self class] callback:^(NSString *propertyName, TSSettingType type) {
            __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf addObserver:strongSelf forKeyPath:propertyName options:NSKeyValueObservingOptionNew context:nil];
            }
        }];
    }
    return self;
}

- (void)dealloc {
    // Remove KVO observers
    // CRITICAL: Don't use weakSelf in dealloc - self is already being deallocated
    // Collect property names first, then remove observers
    NSMutableArray *propertyNames = [NSMutableArray array];
    [TSConfigBuilder eachProperty:[self class] callback:^(NSString *propertyName, TSSettingType type) {
        [propertyNames addObject:propertyName];
    }];
    
    // Now remove observers using self directly (safe in dealloc)
    for (NSString *propertyName in propertyNames) {
        @try {
            [self removeObserver:self forKeyPath:propertyName];
        } @catch (NSException *exception) {
            // Already removed or never added
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    // Mark property as dirty (iOS_PRECEDUR pattern)
    [self setDirty:keyPath];
}

- (void)setDirty:(NSString*)propertyName {
    if (propertyName) {
        [_dirtyProperties addObject:propertyName];
    }
}

- (BOOL)isDirty:(NSString*)propertyName {
    return [_dirtyProperties containsObject:propertyName];
}

- (void)eachDirtyProperty:(void(^)(NSString* propertyName, TSSettingType type))block {
    for (NSString *propertyName in _dirtyProperties) {
        // Get property type
        objc_property_t property = class_getProperty([self class], [propertyName UTF8String]);
        if (property) {
            TSSettingType type = [TSConfigBuilder getPropertyType:property];
            if (block) {
                block(propertyName, type);
            }
        }
    }
}

- (id)valueForKey:(NSString*)key withType:(TSSettingType)type {
    id value = [self valueForKey:key];
    
    // Convert based on type if needed
    if (type == tsSettingTypeBoolean && [value isKindOfClass:[NSNumber class]]) {
        return @([value boolValue]);
    } else if ((type == tsSettingTypeInteger || type == tsSettingTypeUInteger) && [value isKindOfClass:[NSNumber class]]) {
        return @([value integerValue]);
    } else if ((type == tsSettingTypeDouble || type == tsSettingTypeFloat) && [value isKindOfClass:[NSNumber class]]) {
        return @([value doubleValue]);
    }
    
    return value;
}

+ (BOOL)value:(id)value1 isEqualTo:(id)value2 withType:(TSSettingType)type {
    if (value1 == nil && value2 == nil) {
        return YES;
    }
    if (value1 == nil || value2 == nil) {
        return NO;
    }
    
    // Compare based on type
    if (type == tsSettingTypeBoolean) {
        BOOL b1 = [value1 boolValue];
        BOOL b2 = [value2 boolValue];
        return b1 == b2;
    } else if (type == tsSettingTypeInteger || type == tsSettingTypeUInteger) {
        NSInteger i1 = [value1 integerValue];
        NSInteger i2 = [value2 integerValue];
        return i1 == i2;
    } else if (type == tsSettingTypeDouble || type == tsSettingTypeFloat) {
        double d1 = [value1 doubleValue];
        double d2 = [value2 doubleValue];
        return fabs(d1 - d2) < 0.0001; // Floating point comparison
    } else if (type == tsSettingTypeString) {
        return [value1 isEqualToString:value2];
    } else {
        return [value1 isEqual:value2];
    }
}

+ (CLActivityType)decodeActivityType:(NSString*)activityType {
    if (!activityType) {
        return CLActivityTypeOther;
    }
    
    NSString *lower = [activityType lowercaseString];
    
    if ([lower isEqualToString:@"automotive"] || [lower isEqualToString:@"in_vehicle"]) {
        return CLActivityTypeAutomotiveNavigation;
    } else if ([lower isEqualToString:@"fitness"] || [lower isEqualToString:@"on_foot"] || [lower isEqualToString:@"walking"] || [lower isEqualToString:@"running"]) {
        return CLActivityTypeFitness;
    } else if ([lower isEqualToString:@"other"]) {
        return CLActivityTypeOther;
    } else {
        return CLActivityTypeOther;
    }
}

- (void)applyDefaults {
    // Geolocation defaults
    _desiredAccuracy = kCLLocationAccuracyBest;
    _distanceFilter = 10.0;
    _stationaryRadius = 25.0;
    _locationTimeout = 60.0;
    _useSignificantChangesOnly = NO;
    _pausesLocationUpdatesAutomatically = NO;
    _disableElasticity = NO;
    _elasticityMultiplier = 1.0;
    _stopAfterElapsedMinutes = 0;
    _locationAuthorizationRequest = @"Always";
    _locationAuthorizationAlert = nil;
    _disableLocationAuthorizationAlert = NO;
    _geofenceProximityRadius = 1000.0;
    _geofenceInitialTriggerEntry = YES;
    _desiredOdometerAccuracy = kCLLocationAccuracyBest;
    _enableTimestampMeta = YES;
    _showsBackgroundLocationIndicator = YES;
    
    // ActivityRecognition defaults
    _isMoving = NO;
    _activityType = CLActivityTypeOther;
    _stopDetectionDelay = 0;
    _stopTimeout = 5 * 60; // 5 minutes in seconds
    _activityRecognitionInterval = 10000; // milliseconds
    _minimumActivityRecognitionConfidence = 75;
    _disableMotionActivityUpdates = NO;
    _disableStopDetection = NO;
    _stopOnStationary = NO;
    
    // HTTP & Persistence defaults
    _url = nil;
    _method = @"POST";
    _httpRootProperty = nil;
    _params = nil;
    _headers = nil;
    _extras = nil;
    _autoSync = YES;
    _autoSyncThreshold = 0;
    _batchSync = NO;
    _maxBatchSize = 250;
    _locationTemplate = nil;
    _geofenceTemplate = nil;
    _maxDaysToPersist = 1;
    _maxRecordsToPersist = 10000;
    _locationsOrderDirection = @"ASC";
    _httpTimeout = 60000; // milliseconds
    _persistMode = tsPersistModeAll;
    _disableAutoSyncOnCellular = NO;
    _authorization = nil;
    
    // Application defaults
    _stopOnTerminate = YES;
    _startOnBoot = NO;
    _preventSuspend = NO;
    _heartbeatInterval = 60; // seconds
    _schedule = nil;
    _triggerActivities = nil;
    
    // Logging & Debug defaults
    _debug = NO;
    _logLevel = tsLogLevelInfo;
    _logMaxDays = 3;
}

+ (void)eachProperty:(Class)mClass callback:(void(^)(NSString*, TSSettingType))block {
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(mClass, &count);
    
    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
        TSSettingType type = [self getPropertyType:property];
        
        if (block) {
            block(propertyName, type);
        }
    }
    
    free(properties);
}

+ (TSSettingType)getPropertyType:(objc_property_t)property {
    const char *attributes = property_getAttributes(property);
    NSString *attributesString = [NSString stringWithUTF8String:attributes];
    
    // Parse type from attributes
    if ([attributesString containsString:@"T@\"NSString\""]) {
        return tsSettingTypeString;
    } else if ([attributesString containsString:@"Ti"] || [attributesString containsString:@"Tq"]) {
        return tsSettingTypeInteger;
    } else if ([attributesString containsString:@"TI"] || [attributesString containsString:@"TQ"]) {
        return tsSettingTypeUInteger;
    } else if ([attributesString containsString:@"TB"] || [attributesString containsString:@"Tc"]) {
        return tsSettingTypeBoolean;
    } else if ([attributesString containsString:@"Td"]) {
        return tsSettingTypeDouble;
    } else if ([attributesString containsString:@"Tf"]) {
        return tsSettingTypeFloat;
    } else if ([attributesString containsString:@"Tl"]) {
        return tsSettingTypeLong;
    } else if ([attributesString containsString:@"T@\"NSDictionary\""]) {
        return tsSettingTypeDictionary;
    } else if ([attributesString containsString:@"T@\"NSArray\""]) {
        return tsSettingTypeArray;
    } else if ([attributesString containsString:@"T@"]) {
        return tsSettingTypeModule;
    }
    
    return tsSettingTypeString; // Default
}

+ (CLLocationAccuracy)decodeDesiredAccuracy:(NSNumber*)accuracy {
    if (!accuracy) {
        return kCLLocationAccuracyBest;
    }
    
    double value = [accuracy doubleValue];
    
    if (value <= 0) {
        return kCLLocationAccuracyBest;
    } else if (value <= 10) {
        return kCLLocationAccuracyNearestTenMeters;
    } else if (value <= 100) {
        return kCLLocationAccuracyHundredMeters;
    } else if (value <= 1000) {
        return kCLLocationAccuracyKilometer;
    } else if (value <= 3000) {
        return kCLLocationAccuracyThreeKilometers;
    } else {
        return kCLLocationAccuracyReduced;
    }
}

- (NSDictionary*)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Use runtime to get all properties
    [TSConfigBuilder eachProperty:[self class] callback:^(NSString *propertyName, TSSettingType type) {
        id value = [self valueForKey:propertyName];
        if (value) {
            // Convert value based on type
            if (type == tsSettingTypeBoolean) {
                dict[propertyName] = @([value boolValue]);
            } else if (type == tsSettingTypeInteger || type == tsSettingTypeUInteger) {
                dict[propertyName] = @([value integerValue]);
            } else if (type == tsSettingTypeDouble || type == tsSettingTypeFloat) {
                dict[propertyName] = @([value doubleValue]);
            } else if (type == tsSettingTypeString) {
                dict[propertyName] = value;
            } else if (type == tsSettingTypeDictionary || type == tsSettingTypeArray) {
                dict[propertyName] = value;
            } else if (type == tsSettingTypeModule) {
                // For module types, convert to dictionary if possible
                if ([value respondsToSelector:@selector(toDictionary)]) {
                    dict[propertyName] = [value toDictionary];
                } else {
                    dict[propertyName] = value;
                }
            }
        }
    }];
    
    return dict;
}

@end

