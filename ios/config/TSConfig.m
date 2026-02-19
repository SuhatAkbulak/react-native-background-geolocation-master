//
//  TSConfig.m
//  RNBackgroundLocation
//
//  Configuration Management Class
//  Android Config.java benzeri
//

#import "TSConfig.h"
#import "TSAuthorization.h"

static NSString *const PREFS_NAME = @"BackgroundLocationConfig";
static NSString *const KEY_CONFIG = @"config";

@interface TSConfig () <NSCoding>
@property (nonatomic, strong) NSUserDefaults *userDefaults;
// CRITICAL: Orijinal TSConfig pattern - onChange callbacks storage
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<void(^)(id)> *> *onChangeCallbacks;

// Internal storage for readonly properties (from TSConfigBuilder)
@property (nonatomic, assign) CLLocationAccuracy _desiredAccuracy;
@property (nonatomic, assign) CLLocationDistance _distanceFilter;
@property (nonatomic, assign) CLLocationDistance _stationaryRadius;
@property (nonatomic, assign) NSTimeInterval _locationTimeout;
@property (nonatomic, assign) BOOL _useSignificantChangesOnly;
@property (nonatomic, assign) BOOL _pausesLocationUpdatesAutomatically;
@property (nonatomic, assign) BOOL _disableElasticity;
@property (nonatomic, assign) double _elasticityMultiplier;
@property (nonatomic, assign) NSTimeInterval _stopAfterElapsedMinutes;
@property (nonatomic, strong) NSString* _locationAuthorizationRequest;
@property (nonatomic, strong) NSDictionary* _locationAuthorizationAlert;
@property (nonatomic, assign) BOOL _disableLocationAuthorizationAlert;
@property (nonatomic, assign) CLLocationDistance _geofenceProximityRadius;
@property (nonatomic, assign) BOOL _geofenceInitialTriggerEntry;
@property (nonatomic, assign) CLLocationAccuracy _desiredOdometerAccuracy;
@property (nonatomic, assign) CLActivityType _activityType;
@property (nonatomic, assign) NSTimeInterval _stopDetectionDelay;
@property (nonatomic, assign) NSTimeInterval _stopTimeout;
@property (nonatomic, assign) NSTimeInterval _activityRecognitionInterval;
@property (nonatomic, assign) NSInteger _minimumActivityRecognitionConfidence;
@property (nonatomic, assign) BOOL _disableMotionActivityUpdates;
@property (nonatomic, assign) BOOL _disableStopDetection;
@property (nonatomic, assign) BOOL _stopOnStationary;
@property (nonatomic, strong) NSString* _url;
@property (nonatomic, strong) NSString* _method;
@property (nonatomic, strong) NSString* _httpRootProperty;
@property (nonatomic, strong) NSString* _paramsString; // Stored as JSON string
@property (nonatomic, strong) NSString* _headersString; // Stored as JSON string
@property (nonatomic, strong) NSString* _extrasString; // Stored as JSON string
@property (nonatomic, assign) BOOL _autoSync;
@property (nonatomic, assign) NSInteger _autoSyncThreshold;
@property (nonatomic, assign) BOOL _batchSync;
@property (nonatomic, assign) NSInteger _maxBatchSize;
@property (nonatomic, strong) NSString* _locationTemplate;
@property (nonatomic, strong) NSString* _geofenceTemplate;
@property (nonatomic, assign) NSInteger _maxDaysToPersist;
@property (nonatomic, assign) NSInteger _maxRecordsToPersist;
@property (nonatomic, strong) NSString* _locationsOrderDirection;
@property (nonatomic, assign) NSInteger _httpTimeout;
@property (nonatomic, assign) BOOL _disableAutoSyncOnCellular;
@property (nonatomic, assign) BOOL _stopOnTerminate;
@property (nonatomic, assign) BOOL _startOnBoot;
@property (nonatomic, assign) BOOL _preventSuspend;
@property (nonatomic, assign) NSTimeInterval _heartbeatInterval;
@property (nonatomic, strong) NSArray* _schedule;
@property (nonatomic, strong) NSString* _triggerActivities;
@property (nonatomic, assign) BOOL _debug;
@property (nonatomic, assign) TSLogLevel _logLevel;
@property (nonatomic, assign) NSInteger _logMaxDays;
@property (nonatomic, assign) BOOL _enableTimestampMeta;
@property (nonatomic, assign) BOOL _showsBackgroundLocationIndicator;
@property (nonatomic, assign) TSPersistMode _persistMode;
@property (nonatomic, strong) TSAuthorization* _authorization;
// Orijinal Transistorsoft field isimleri (title, text, color, smallIcon, largeIcon, priority, channelName, channelId)
@property (nonatomic, strong) NSString* _title;
@property (nonatomic, strong) NSString* _text;
@property (nonatomic, strong) NSString* _smallIcon;
@property (nonatomic, strong) NSString* _largeIcon;
@property (nonatomic, strong) NSString* _color;
@property (nonatomic, assign) NSInteger _priority;
@property (nonatomic, strong) NSString* _channelName;
@property (nonatomic, strong) NSString* _channelId;
// Backward compatibility: Eski field isimlerini de destekle (deprecated)
@property (nonatomic, strong) NSString* _notificationTitle;
@property (nonatomic, strong) NSString* _notificationText;
@property (nonatomic, strong) NSString* _notificationIcon;
@property (nonatomic, strong) NSString* _notificationColor;
@property (nonatomic, assign) NSInteger _notificationPriority;
@property (nonatomic, strong) NSString* _notificationChannelName;
@property (nonatomic, strong) NSString* _notificationChannelId;
// CRITICAL: Flag to prevent onChange callbacks during load
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation TSConfig

// Explicit ivar names so underscore-named properties use _title (not __title)
@synthesize _title = _title, _text = _text, _smallIcon = _smallIcon, _largeIcon = _largeIcon;
@synthesize _color = _color, _priority = _priority, _channelName = _channelName, _channelId = _channelId;

+ (instancetype)sharedInstance {
    static TSConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TSConfig alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userDefaults = [NSUserDefaults standardUserDefaults];
        _onChangeCallbacks = [NSMutableDictionary dictionary];
        self.isLoading = YES; // CRITICAL: Set loading flag BEFORE any operations
        
        [self setDefaults];
        [self load];
        
        self.isLoading = NO; // CRITICAL: Clear loading flag AFTER load completes
        
        // Observe state properties (iOS_PRECEDUR pattern)
        // CRITICAL: Add observers AFTER load to prevent duplicate events
        [self observeStateProperties];
    }
    return self;
}

- (void)setDefaults {
    // Use TSConfigBuilder to set defaults
    TSConfigBuilder *builder = [[TSConfigBuilder alloc] init];
    [self applyBuilderValues:builder];
    
    // Additional defaults (not in TSConfigBuilder)
    _locationUpdateInterval = 10000; // milliseconds
    _fastestLocationUpdateInterval = 5000; // milliseconds
    _foregroundService = YES;
    // Orijinal Transistorsoft field isimleri (title, text, color, smallIcon, largeIcon, priority, channelName, channelId)
    _title = @"Location Tracking";
    _text = @"Your location is being tracked";
    _smallIcon = @"";
    _largeIcon = @"";
    _color = @"#3498db";
    _priority = 0;
    _channelName = @"";
    _channelId = @"";
    // Backward compatibility: Eski field isimlerini de destekle (deprecated)
    _notificationTitle = @"Location Tracking";
    _notificationText = @"Your location is being tracked";
    _notificationIcon = @"";
    _notificationColor = @"#3498db";
    _notificationPriority = 0;
    _notificationChannelName = @"";
    _notificationChannelId = @"";
    _deferTime = 0;
    _allowIdenticalLocations = NO;
    _enableHeadless = NO;
    _scheduleUseAlarmManager = YES;
    _clearLocationsOnStart = NO;
    self._headersString = @"{}";
    self._paramsString = @"{}";
    self._extrasString = @"{}";
    
    // State
    _enabled = NO;
    _isMoving = NO;
    _odometer = 0.0;
    _schedulerEnabled = NO;
    _trackingMode = tsTrackingModeLocation;
    _lastLocationAuthorizationStatus = kCLAuthorizationStatusNotDetermined;
    _iOSHasWarnedLocationServicesOff = NO;
    _didRequestUpgradeLocationAuthorization = NO;
    _didLaunchInBackground = NO;
}

- (void)reset {
    [self reset:NO];
}

- (void)reset:(BOOL)silent {
    [self setDefaults];
    if (!silent) {
        [self save];
    }
}

- (void)updateWithBlock:(void(^)(TSConfigBuilder*))block {
    TSConfigBuilder *builder = [[TSConfigBuilder alloc] init];
    
    // Copy current values to builder
    builder.desiredAccuracy = self._desiredAccuracy;
    builder.distanceFilter = self._distanceFilter;
    builder.stationaryRadius = self._stationaryRadius;
    builder.locationTimeout = self._locationTimeout;
    builder.useSignificantChangesOnly = self._useSignificantChangesOnly;
    builder.pausesLocationUpdatesAutomatically = self._pausesLocationUpdatesAutomatically;
    builder.disableElasticity = self._disableElasticity;
    builder.elasticityMultiplier = self._elasticityMultiplier;
    builder.stopAfterElapsedMinutes = self._stopAfterElapsedMinutes;
    builder.locationAuthorizationRequest = self._locationAuthorizationRequest;
    builder.locationAuthorizationAlert = self._locationAuthorizationAlert;
    builder.disableLocationAuthorizationAlert = self._disableLocationAuthorizationAlert;
    builder.geofenceProximityRadius = self._geofenceProximityRadius;
    builder.geofenceInitialTriggerEntry = self._geofenceInitialTriggerEntry;
    builder.desiredOdometerAccuracy = self._desiredOdometerAccuracy;
    builder.enableTimestampMeta = self._enableTimestampMeta;
    builder.showsBackgroundLocationIndicator = self._showsBackgroundLocationIndicator;
    builder.isMoving = self.isMoving;
    builder.activityType = self._activityType;
    builder.stopDetectionDelay = self._stopDetectionDelay;
    builder.stopTimeout = self._stopTimeout;
    builder.activityRecognitionInterval = self._activityRecognitionInterval;
    builder.minimumActivityRecognitionConfidence = self._minimumActivityRecognitionConfidence;
    builder.disableMotionActivityUpdates = self._disableMotionActivityUpdates;
    builder.disableStopDetection = self._disableStopDetection;
    builder.stopOnStationary = self._stopOnStationary;
    builder.url = self._url;
    builder.method = self._method;
    builder.httpRootProperty = self._httpRootProperty;
    // Convert JSON strings to NSDictionary for builder
    if (self._paramsString) {
        NSError *error;
        NSData *jsonData = [self._paramsString dataUsingEncoding:NSUTF8StringEncoding];
        builder.params = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    }
    if (self._headersString) {
        NSError *error;
        NSData *jsonData = [self._headersString dataUsingEncoding:NSUTF8StringEncoding];
        builder.headers = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    }
    if (self._extrasString) {
        NSError *error;
        NSData *jsonData = [self._extrasString dataUsingEncoding:NSUTF8StringEncoding];
        builder.extras = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    }
    builder.autoSync = self._autoSync;
    builder.autoSyncThreshold = self._autoSyncThreshold;
    builder.batchSync = self._batchSync;
    builder.maxBatchSize = self._maxBatchSize;
    builder.locationTemplate = self._locationTemplate;
    builder.geofenceTemplate = self._geofenceTemplate;
    builder.maxDaysToPersist = self._maxDaysToPersist;
    builder.maxRecordsToPersist = self._maxRecordsToPersist;
    builder.locationsOrderDirection = self._locationsOrderDirection;
    builder.httpTimeout = self._httpTimeout;
    builder.persistMode = self._persistMode;
    builder.disableAutoSyncOnCellular = self._disableAutoSyncOnCellular;
    builder.authorization = self._authorization;
    builder.stopOnTerminate = self._stopOnTerminate;
    builder.startOnBoot = self._startOnBoot;
    builder.preventSuspend = self._preventSuspend;
    builder.heartbeatInterval = self._heartbeatInterval;
    builder.schedule = self._schedule;
    builder.triggerActivities = self._triggerActivities;
    builder.debug = self._debug;
    builder.logLevel = self._logLevel;
    builder.logMaxDays = self._logMaxDays;
    
    // Apply block
    if (block) {
        block(builder);
    }
    
    // Copy builder values back to config
    [self applyBuilderValues:builder];
    [self save];
}

- (void)applyBuilderValues:(TSConfigBuilder*)builder {
    self._desiredAccuracy = builder.desiredAccuracy;
    self._distanceFilter = builder.distanceFilter;
    self._stationaryRadius = builder.stationaryRadius;
    self._locationTimeout = builder.locationTimeout;
    self._useSignificantChangesOnly = builder.useSignificantChangesOnly;
    self._pausesLocationUpdatesAutomatically = builder.pausesLocationUpdatesAutomatically;
    self._disableElasticity = builder.disableElasticity;
    self._elasticityMultiplier = builder.elasticityMultiplier;
    self._stopAfterElapsedMinutes = builder.stopAfterElapsedMinutes;
    self._locationAuthorizationRequest = builder.locationAuthorizationRequest;
    self._locationAuthorizationAlert = builder.locationAuthorizationAlert;
    self._disableLocationAuthorizationAlert = builder.disableLocationAuthorizationAlert;
    self._geofenceProximityRadius = builder.geofenceProximityRadius;
    self._geofenceInitialTriggerEntry = builder.geofenceInitialTriggerEntry;
    self._desiredOdometerAccuracy = builder.desiredOdometerAccuracy;
    self._enableTimestampMeta = builder.enableTimestampMeta;
    self._showsBackgroundLocationIndicator = builder.showsBackgroundLocationIndicator;
    self._activityType = builder.activityType;
    self._stopDetectionDelay = builder.stopDetectionDelay;
    self._stopTimeout = builder.stopTimeout;
    self._activityRecognitionInterval = builder.activityRecognitionInterval;
    self._minimumActivityRecognitionConfidence = builder.minimumActivityRecognitionConfidence;
    self._disableMotionActivityUpdates = builder.disableMotionActivityUpdates;
    self._disableStopDetection = builder.disableStopDetection;
    self._stopOnStationary = builder.stopOnStationary;
    self._url = builder.url;
    self._method = builder.method;
    self._httpRootProperty = builder.httpRootProperty;
    // Convert NSDictionary to JSON string for storage
    if (builder.params) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:builder.params options:0 error:&error];
        if (!error) {
            self._paramsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    if (builder.headers) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:builder.headers options:0 error:&error];
        if (!error) {
            self._headersString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    if (builder.extras) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:builder.extras options:0 error:&error];
        if (!error) {
            self._extrasString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    self._autoSync = builder.autoSync;
    self._autoSyncThreshold = builder.autoSyncThreshold;
    self._batchSync = builder.batchSync;
    self._maxBatchSize = builder.maxBatchSize;
    self._locationTemplate = builder.locationTemplate;
    self._geofenceTemplate = builder.geofenceTemplate;
    self._maxDaysToPersist = builder.maxDaysToPersist;
    self._maxRecordsToPersist = builder.maxRecordsToPersist;
    self._locationsOrderDirection = builder.locationsOrderDirection;
    self._httpTimeout = builder.httpTimeout;
    self._persistMode = builder.persistMode;
    self._disableAutoSyncOnCellular = builder.disableAutoSyncOnCellular;
    self._authorization = builder.authorization;
    self._stopOnTerminate = builder.stopOnTerminate;
    self._startOnBoot = builder.startOnBoot;
    self._preventSuspend = builder.preventSuspend;
    self._heartbeatInterval = builder.heartbeatInterval;
    self._schedule = builder.schedule;
    self._triggerActivities = builder.triggerActivities;
    self._debug = builder.debug;
    self._logLevel = builder.logLevel;
    self._logMaxDays = builder.logMaxDays;
}

#pragma mark - Readonly Property Getters

- (CLLocationAccuracy)desiredAccuracy {
    return self._desiredAccuracy;
}

- (CLLocationDistance)distanceFilter {
    return self._distanceFilter;
}

- (CLLocationDistance)stationaryRadius {
    return self._stationaryRadius;
}

- (NSTimeInterval)locationTimeout {
    return self._locationTimeout;
}

- (BOOL)useSignificantChangesOnly {
    return self._useSignificantChangesOnly;
}

- (BOOL)pausesLocationUpdatesAutomatically {
    return self._pausesLocationUpdatesAutomatically;
}

- (BOOL)disableElasticity {
    return self._disableElasticity;
}

- (double)elasticityMultiplier {
    return self._elasticityMultiplier;
}

- (NSTimeInterval)stopAfterElapsedMinutes {
    return self._stopAfterElapsedMinutes;
}

- (NSString*)locationAuthorizationRequest {
    return self._locationAuthorizationRequest;
}

- (NSDictionary*)locationAuthorizationAlert {
    return self._locationAuthorizationAlert;
}

- (BOOL)disableLocationAuthorizationAlert {
    return self._disableLocationAuthorizationAlert;
}

- (CLLocationDistance)geofenceProximityRadius {
    return self._geofenceProximityRadius;
}

- (BOOL)geofenceInitialTriggerEntry {
    return self._geofenceInitialTriggerEntry;
}

- (CLLocationAccuracy)desiredOdometerAccuracy {
    return self._desiredOdometerAccuracy;
}

- (CLActivityType)activityType {
    return self._activityType;
}

- (NSTimeInterval)stopDetectionDelay {
    return self._stopDetectionDelay;
}

- (NSTimeInterval)stopTimeout {
    return self._stopTimeout;
}

- (NSTimeInterval)activityRecognitionInterval {
    return self._activityRecognitionInterval;
}

- (NSInteger)minimumActivityRecognitionConfidence {
    return self._minimumActivityRecognitionConfidence;
}

- (BOOL)disableMotionActivityUpdates {
    return self._disableMotionActivityUpdates;
}

- (BOOL)disableStopDetection {
    return self._disableStopDetection;
}

- (BOOL)stopOnStationary {
    return self._stopOnStationary;
}

- (NSString*)url {
    return self._url;
}

- (NSString*)method {
    return self._method;
}

- (NSString*)httpRootProperty {
    return self._httpRootProperty;
}

- (NSDictionary*)params {
    if (!self._paramsString) {
        return nil;
    }
    NSError *error;
    NSData *jsonData = [self._paramsString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    return error ? nil : dict;
}

- (NSDictionary*)headers {
    if (!self._headersString) {
        return nil;
    }
    NSError *error;
    NSData *jsonData = [self._headersString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    return error ? nil : dict;
}

- (NSDictionary*)extras {
    if (!self._extrasString) {
        return nil;
    }
    NSError *error;
    NSData *jsonData = [self._extrasString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    return error ? nil : dict;
}

- (BOOL)autoSync {
    return self._autoSync;
}

- (NSInteger)autoSyncThreshold {
    return self._autoSyncThreshold;
}

- (BOOL)batchSync {
    return self._batchSync;
}

- (NSInteger)maxBatchSize {
    return self._maxBatchSize;
}

- (NSString*)locationTemplate {
    return self._locationTemplate;
}

- (NSString*)geofenceTemplate {
    return self._geofenceTemplate;
}

- (NSInteger)maxDaysToPersist {
    return self._maxDaysToPersist;
}

- (NSInteger)maxRecordsToPersist {
    return self._maxRecordsToPersist;
}

- (NSString*)locationsOrderDirection {
    return self._locationsOrderDirection;
}

- (NSInteger)httpTimeout {
    return self._httpTimeout;
}

- (BOOL)disableAutoSyncOnCellular {
    return self._disableAutoSyncOnCellular;
}

- (BOOL)stopOnTerminate {
    return self._stopOnTerminate;
}

- (BOOL)startOnBoot {
    return self._startOnBoot;
}

- (BOOL)preventSuspend {
    return self._preventSuspend;
}

- (NSTimeInterval)heartbeatInterval {
    return self._heartbeatInterval;
}

- (NSArray*)schedule {
    return self._schedule;
}

- (NSString*)triggerActivities {
    return self._triggerActivities;
}

- (BOOL)debug {
    return self._debug;
}

- (TSLogLevel)logLevel {
    return self._logLevel;
}

- (NSInteger)logMaxDays {
    return self._logMaxDays;
}

- (BOOL)enableTimestampMeta {
    return self._enableTimestampMeta;
}

- (BOOL)showsBackgroundLocationIndicator {
    return self._showsBackgroundLocationIndicator;
}

- (TSPersistMode)persistMode {
    return self._persistMode;
}

- (TSAuthorization*)authorization {
    return self._authorization;
}

- (void)updateWithDictionary:(NSDictionary *)dictionary {
    if (dictionary[@"desiredAccuracy"]) {
        self._desiredAccuracy = [dictionary[@"desiredAccuracy"] doubleValue];
    }
    if (dictionary[@"distanceFilter"]) {
        self._distanceFilter = [dictionary[@"distanceFilter"] doubleValue];
    }
    if (dictionary[@"stationaryRadius"]) {
        self._stationaryRadius = [dictionary[@"stationaryRadius"] doubleValue];
    }
    if (dictionary[@"locationUpdateInterval"]) {
        _locationUpdateInterval = [dictionary[@"locationUpdateInterval"] doubleValue];
    }
    if (dictionary[@"fastestLocationUpdateInterval"]) {
        _fastestLocationUpdateInterval = [dictionary[@"fastestLocationUpdateInterval"] doubleValue];
    }
    if (dictionary[@"activityRecognitionInterval"]) {
        self._activityRecognitionInterval = [dictionary[@"activityRecognitionInterval"] doubleValue];
    }
    if (dictionary[@"stopTimeout"]) {
        self._stopTimeout = [dictionary[@"stopTimeout"] integerValue];
    }
    if (dictionary[@"stopOnStationary"]) {
        self._stopOnStationary = [dictionary[@"stopOnStationary"] boolValue];
    }
    if (dictionary[@"disableMotionActivityUpdates"]) {
        self._disableMotionActivityUpdates = [dictionary[@"disableMotionActivityUpdates"] boolValue];
    }
    if (dictionary[@"triggerActivities"]) {
        self._triggerActivities = dictionary[@"triggerActivities"];
    }
    if (dictionary[@"foregroundService"]) {
        _foregroundService = [dictionary[@"foregroundService"] boolValue];
    }
    // Orijinal Transistorsoft field isimleri (title, text, color, smallIcon, largeIcon, priority, channelName, channelId)
    // Backward compatibility için eski field isimlerini de destekle
    if (dictionary[@"title"]) {
        _title = dictionary[@"title"];
    } else if (dictionary[@"notificationTitle"]) {
        _title = dictionary[@"notificationTitle"];
    }
    if (dictionary[@"text"]) {
        _text = dictionary[@"text"];
    } else if (dictionary[@"notificationText"]) {
        _text = dictionary[@"notificationText"];
    }
    if (dictionary[@"smallIcon"]) {
        _smallIcon = dictionary[@"smallIcon"];
    } else if (dictionary[@"notificationIcon"]) {
        _smallIcon = dictionary[@"notificationIcon"];
    }
    if (dictionary[@"largeIcon"]) {
        _largeIcon = dictionary[@"largeIcon"];
    } else if (dictionary[@"notificationLargeIcon"]) {
        _largeIcon = dictionary[@"notificationLargeIcon"];
    }
    if (dictionary[@"color"]) {
        _color = dictionary[@"color"];
    } else if (dictionary[@"notificationColor"]) {
        _color = dictionary[@"notificationColor"];
    }
    if (dictionary[@"priority"]) {
        _priority = [dictionary[@"priority"] integerValue];
    } else if (dictionary[@"notificationPriority"]) {
        _priority = [dictionary[@"notificationPriority"] integerValue];
    }
    if (dictionary[@"channelName"]) {
        _channelName = dictionary[@"channelName"];
    } else if (dictionary[@"notificationChannelName"]) {
        _channelName = dictionary[@"notificationChannelName"];
    }
    if (dictionary[@"channelId"]) {
        _channelId = dictionary[@"channelId"];
    } else if (dictionary[@"notificationChannelId"]) {
        _channelId = dictionary[@"notificationChannelId"];
    }
    // Backward compatibility: Eski field isimlerini de set et
    _notificationTitle = _title;
    _notificationText = _text;
    _notificationIcon = _smallIcon;
    _notificationColor = _color;
    _notificationPriority = _priority;
    _notificationChannelName = _channelName;
    _notificationChannelId = _channelId;
    if (dictionary[@"url"]) {
        self._url = dictionary[@"url"];
    }
    if (dictionary[@"method"]) {
        self._method = dictionary[@"method"];
    }
    if (dictionary[@"autoSync"]) {
        self._autoSync = [dictionary[@"autoSync"] boolValue];
    }
    if (dictionary[@"autoSyncThreshold"]) {
        self._autoSyncThreshold = [dictionary[@"autoSyncThreshold"] integerValue];
    }
    if (dictionary[@"maxBatchSize"]) {
        self._maxBatchSize = [dictionary[@"maxBatchSize"] integerValue];
    }
    if (dictionary[@"maxDaysToPersist"]) {
        self._maxDaysToPersist = [dictionary[@"maxDaysToPersist"] integerValue];
    }
    if (dictionary[@"maxRecordsToPersist"]) {
        self._maxRecordsToPersist = [dictionary[@"maxRecordsToPersist"] integerValue];
    }
    if (dictionary[@"geofenceProximityRadius"]) {
        self._geofenceProximityRadius = [dictionary[@"geofenceProximityRadius"] doubleValue];
    }
    if (dictionary[@"geofenceInitialTriggerEntry"]) {
        self._geofenceInitialTriggerEntry = [dictionary[@"geofenceInitialTriggerEntry"] boolValue];
    }
    if (dictionary[@"deferTime"]) {
        _deferTime = [dictionary[@"deferTime"] doubleValue];
    }
    if (dictionary[@"allowIdenticalLocations"]) {
        _allowIdenticalLocations = [dictionary[@"allowIdenticalLocations"] boolValue];
    }
    if (dictionary[@"debug"]) {
        self._debug = [dictionary[@"debug"] boolValue];
    }
    if (dictionary[@"logLevel"]) {
        self._logLevel = [dictionary[@"logLevel"] integerValue];
    }
    if (dictionary[@"logMaxDays"]) {
        self._logMaxDays = [dictionary[@"logMaxDays"] integerValue];
    }
    if (dictionary[@"enableHeadless"]) {
        _enableHeadless = [dictionary[@"enableHeadless"] boolValue];
    }
    if (dictionary[@"startOnBoot"]) {
        self._startOnBoot = [dictionary[@"startOnBoot"] boolValue];
    }
    if (dictionary[@"stopOnTerminate"]) {
        self._stopOnTerminate = [dictionary[@"stopOnTerminate"] boolValue];
    }
    if (dictionary[@"stopAfterElapsedMinutes"]) {
        self._stopAfterElapsedMinutes = [dictionary[@"stopAfterElapsedMinutes"] integerValue];
    }
    if (dictionary[@"isMoving"]) {
        _isMoving = [dictionary[@"isMoving"] boolValue];
    }
    if (dictionary[@"disableElasticity"]) {
        self._disableElasticity = [dictionary[@"disableElasticity"] boolValue];
    }
    if (dictionary[@"elasticityMultiplier"]) {
        self._elasticityMultiplier = [dictionary[@"elasticityMultiplier"] doubleValue];
    }
    if (dictionary[@"batchSync"]) {
        self._batchSync = [dictionary[@"batchSync"] boolValue];
    }
    if (dictionary[@"heartbeatInterval"]) {
        self._heartbeatInterval = [dictionary[@"heartbeatInterval"] integerValue];
    }
    if (dictionary[@"preventSuspend"]) {
        self._preventSuspend = [dictionary[@"preventSuspend"] boolValue];
    }
    if (dictionary[@"enableTimestampMeta"]) {
        self._enableTimestampMeta = [dictionary[@"enableTimestampMeta"] boolValue];
    }
    if (dictionary[@"scheduleUseAlarmManager"]) {
        _scheduleUseAlarmManager = [dictionary[@"scheduleUseAlarmManager"] boolValue];
    }
    if (dictionary[@"clearLocationsOnStart"]) {
        _clearLocationsOnStart = [dictionary[@"clearLocationsOnStart"] boolValue];
    }
    if (dictionary[@"headers"]) {
        if ([dictionary[@"headers"] isKindOfClass:[NSDictionary class]]) {
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary[@"headers"] options:0 error:&error];
            if (!error) {
                self._headersString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
        } else if ([dictionary[@"headers"] isKindOfClass:[NSString class]]) {
            self._headersString = dictionary[@"headers"];
        }
    }
    if (dictionary[@"params"]) {
        if ([dictionary[@"params"] isKindOfClass:[NSDictionary class]]) {
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary[@"params"] options:0 error:&error];
            if (!error) {
                self._paramsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
        } else if ([dictionary[@"params"] isKindOfClass:[NSString class]]) {
            self._paramsString = dictionary[@"params"];
        }
    }
    if (dictionary[@"extras"]) {
        if ([dictionary[@"extras"] isKindOfClass:[NSDictionary class]]) {
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary[@"extras"] options:0 error:&error];
            if (!error) {
                self._extrasString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
        } else if ([dictionary[@"extras"] isKindOfClass:[NSString class]]) {
            self._extrasString = dictionary[@"extras"];
        }
    }
    if (dictionary[@"authorization"] && [dictionary[@"authorization"] isKindOfClass:[NSDictionary class]]) {
        self._authorization = [[TSAuthorization alloc] initWithDictionary:dictionary[@"authorization"]];
    }
    
    // iOS Specific
    if (dictionary[@"locationAuthorizationRequest"]) {
        self._locationAuthorizationRequest = dictionary[@"locationAuthorizationRequest"];
    }
    if (dictionary[@"showsBackgroundLocationIndicator"]) {
        self._showsBackgroundLocationIndicator = [dictionary[@"showsBackgroundLocationIndicator"] boolValue];
    }
    if (dictionary[@"disableLocationAuthorizationAlert"]) {
        self._disableLocationAuthorizationAlert = [dictionary[@"disableLocationAuthorizationAlert"] boolValue];
    }
    
    // CRITICAL: Don't allow enabled to be set via updateWithDictionary
    // enabled should only be set by start()/stop() methods
    // This prevents ready() from starting tracking automatically
    // _enabled is NOT updated here - it remains as it was (default: NO)
    
    // CRITICAL: Save enabled state before save() to prevent override
    // updateWithDictionary() içinde save() çağrılıyor, bu enabled state'ini override edebilir
    // Bu yüzden enabled state'ini korumak için saklamalıyız
    BOOL currentEnabled = _enabled;
    
    [self save];
    
    // CRITICAL: Restore enabled state after save() to prevent override
    // save() içinde toDictionary() çağrılıyor ve bu enabled state'ini kaydediyor
    // Ama enabled state'i updateWithDictionary() içinde güncellenmiyor, bu yüzden korunmalı
    _enabled = currentEnabled;
}

- (NSDictionary *)toDictionary {
    return [self toDictionary:NO];
}

- (NSDictionary *)toDictionary:(BOOL)redact {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // TSConfigBuilder properties
    dict[@"desiredAccuracy"] = @(self.desiredAccuracy);
    dict[@"distanceFilter"] = @(self.distanceFilter);
    dict[@"stationaryRadius"] = @(self.stationaryRadius);
    dict[@"locationTimeout"] = @(self.locationTimeout);
    dict[@"useSignificantChangesOnly"] = @(self.useSignificantChangesOnly);
    dict[@"pausesLocationUpdatesAutomatically"] = @(self.pausesLocationUpdatesAutomatically);
    dict[@"disableElasticity"] = @(self.disableElasticity);
    dict[@"elasticityMultiplier"] = @(self.elasticityMultiplier);
    dict[@"stopAfterElapsedMinutes"] = @(self.stopAfterElapsedMinutes);
    if (self.locationAuthorizationRequest) {
        dict[@"locationAuthorizationRequest"] = self.locationAuthorizationRequest;
    }
    if (self.locationAuthorizationAlert) {
        dict[@"locationAuthorizationAlert"] = self.locationAuthorizationAlert;
    }
    dict[@"disableLocationAuthorizationAlert"] = @(self.disableLocationAuthorizationAlert);
    dict[@"geofenceProximityRadius"] = @(self.geofenceProximityRadius);
    dict[@"geofenceInitialTriggerEntry"] = @(self.geofenceInitialTriggerEntry);
    dict[@"desiredOdometerAccuracy"] = @(self.desiredOdometerAccuracy);
    dict[@"enableTimestampMeta"] = @(self.enableTimestampMeta);
    dict[@"showsBackgroundLocationIndicator"] = @(self.showsBackgroundLocationIndicator);
    dict[@"isMoving"] = @(self.isMoving);
    dict[@"activityType"] = @(self.activityType);
    dict[@"stopDetectionDelay"] = @(self.stopDetectionDelay);
    dict[@"stopTimeout"] = @(self.stopTimeout);
    dict[@"activityRecognitionInterval"] = @(self.activityRecognitionInterval);
    dict[@"minimumActivityRecognitionConfidence"] = @(self.minimumActivityRecognitionConfidence);
    dict[@"disableMotionActivityUpdates"] = @(self.disableMotionActivityUpdates);
    dict[@"disableStopDetection"] = @(self.disableStopDetection);
    dict[@"stopOnStationary"] = @(self.stopOnStationary);
    if (self.url) {
        dict[@"url"] = redact ? @"[REDACTED]" : self.url;
    }
    if (self.method) {
        dict[@"method"] = self.method;
    }
    if (self.httpRootProperty) {
        dict[@"httpRootProperty"] = self.httpRootProperty;
    }
    if (self.params) {
        dict[@"params"] = self.params;
    }
    if (self.headers) {
        dict[@"headers"] = self.headers;
    }
    if (self.extras) {
        dict[@"extras"] = self.extras;
    }
    dict[@"autoSync"] = @(self.autoSync);
    dict[@"autoSyncThreshold"] = @(self.autoSyncThreshold);
    dict[@"batchSync"] = @(self.batchSync);
    dict[@"maxBatchSize"] = @(self.maxBatchSize);
    if (self.locationTemplate) {
        dict[@"locationTemplate"] = self.locationTemplate;
    }
    if (self.geofenceTemplate) {
        dict[@"geofenceTemplate"] = self.geofenceTemplate;
    }
    dict[@"maxDaysToPersist"] = @(self.maxDaysToPersist);
    dict[@"maxRecordsToPersist"] = @(self.maxRecordsToPersist);
    if (self.locationsOrderDirection) {
        dict[@"locationsOrderDirection"] = self.locationsOrderDirection;
    }
    dict[@"httpTimeout"] = @(self.httpTimeout);
    dict[@"persistMode"] = @(self.persistMode);
    dict[@"disableAutoSyncOnCellular"] = @(self.disableAutoSyncOnCellular);
    if (self.authorization) {
        dict[@"authorization"] = [self.authorization toDictionary];
    }
    dict[@"stopOnTerminate"] = @(self.stopOnTerminate);
    dict[@"startOnBoot"] = @(self.startOnBoot);
    dict[@"preventSuspend"] = @(self.preventSuspend);
    dict[@"heartbeatInterval"] = @(self.heartbeatInterval);
    if (self.schedule) {
        dict[@"schedule"] = self.schedule;
    }
    if (self.triggerActivities) {
        dict[@"triggerActivities"] = self.triggerActivities;
    }
    dict[@"debug"] = @(self.debug);
    dict[@"logLevel"] = @(self.logLevel);
    dict[@"logMaxDays"] = @(self.logMaxDays);
    
    // Additional properties (not in TSConfigBuilder)
    dict[@"locationUpdateInterval"] = @(self.locationUpdateInterval);
    dict[@"fastestLocationUpdateInterval"] = @(self.fastestLocationUpdateInterval);
    dict[@"foregroundService"] = @(self.foregroundService);
    // Orijinal Transistorsoft field isimleri (title, text, color, smallIcon, largeIcon, priority, channelName, channelId)
    dict[@"title"] = self.title;
    dict[@"text"] = self.text;
    dict[@"smallIcon"] = self.smallIcon;
    dict[@"largeIcon"] = self.largeIcon;
    dict[@"color"] = self.color;
    dict[@"priority"] = @(self.priority);
    dict[@"channelName"] = self.channelName;
    dict[@"channelId"] = self.channelId;
    // Backward compatibility: Eski field isimlerini de ekle
    dict[@"notificationTitle"] = self.title;
    dict[@"notificationText"] = self.text;
    dict[@"notificationIcon"] = self.smallIcon;
    dict[@"notificationColor"] = self.color;
    dict[@"notificationPriority"] = @(self.priority);
    dict[@"notificationChannelName"] = self.channelName;
    dict[@"notificationChannelId"] = self.channelId;
    dict[@"deferTime"] = @(self.deferTime);
    dict[@"allowIdenticalLocations"] = @(self.allowIdenticalLocations);
    dict[@"enableHeadless"] = @(self.enableHeadless);
    dict[@"scheduleUseAlarmManager"] = @(self.scheduleUseAlarmManager);
    dict[@"clearLocationsOnStart"] = @(self.clearLocationsOnStart);
    dict[@"headers"] = self.headers;
    dict[@"params"] = self.params;
    dict[@"extras"] = self.extras;
    
    // State properties
    dict[@"enabled"] = @(self.enabled);
    dict[@"isMoving"] = @(self.isMoving);
    dict[@"odometer"] = @(self.odometer);
    dict[@"schedulerEnabled"] = @(self.schedulerEnabled);
    dict[@"trackingMode"] = @(self.trackingMode);
    dict[@"lastLocationAuthorizationStatus"] = @(self.lastLocationAuthorizationStatus);
    dict[@"iOSHasWarnedLocationServicesOff"] = @(self.iOSHasWarnedLocationServicesOff);
    dict[@"didRequestUpgradeLocationAuthorization"] = @(self.didRequestUpgradeLocationAuthorization);
    dict[@"didLaunchInBackground"] = @(self.didLaunchInBackground);
    
    return dict;
}

- (NSString*)toJson {
    NSDictionary *dict = [self toDictionary];
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        return @"{}";
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void)save {
    NSDictionary *dict = [self toDictionary];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self.userDefaults setObject:jsonString forKey:KEY_CONFIG];
    [self.userDefaults synchronize];
}

- (void)load {
    // CRITICAL: Loading flag is already set in init, don't set it again here
    // This prevents multiple enabledchange events when app starts
    
    NSString *jsonString = [self.userDefaults stringForKey:KEY_CONFIG];
    if (jsonString) {
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!error && dict) {
            // CRITICAL: Save enabled state before update (for stopOnTerminate: false scenario)
            BOOL savedEnabled = NO;
            if (dict[@"enabled"]) {
                savedEnabled = [dict[@"enabled"] boolValue];
            }
            
            [self updateWithDictionary:dict];
            
            // CRITICAL: iOS_PRECEDUR pattern - Restore enabled state if stopOnTerminate: false
            // NOT: Otomatik start yok - sadece enabled state'i restore et (UI'da durum gösterilsin diye)
            // Kullanıcı manuel olarak start/stop yapabilir
            // CRITICAL: Direct assignment to avoid KVO during load
            NSLog(@"🔍 [TSConfig load] stopOnTerminate=%d, savedEnabled=%d", self.stopOnTerminate, savedEnabled);
            if (!self.stopOnTerminate && savedEnabled) {
                _enabled = YES; // State'i restore et ama otomatik start yapma
                NSLog(@"✅ [TSConfig load] Restored enabled=YES (stopOnTerminate=false, savedEnabled=true)");
            } else {
                // CRITICAL: Always reset enabled to NO after load (default behavior)
                // enabled should only be set by start() method (unless stopOnTerminate: false)
                _enabled = NO;
                NSLog(@"ℹ️ [TSConfig load] Set enabled=NO (stopOnTerminate=%d, savedEnabled=%d)", self.stopOnTerminate, savedEnabled);
            }
        }
    }
    
    // CRITICAL: Loading flag is cleared in init after load, don't clear it here
}

- (NSDictionary *)getHeadersDictionary {
    // Use internal string property and parse it
    if (self._headersString) {
        NSError *error;
        NSData *jsonData = [self._headersString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (!error) {
            return dict;
        }
    }
    return @{};
}

- (NSDictionary *)getParamsDictionary {
    // Use internal string property and parse it
    if (self._paramsString) {
        NSError *error;
        NSData *jsonData = [self._paramsString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (!error) {
            return dict;
        }
    }
    return @{};
}

- (NSDictionary *)getExtrasDictionary {
    // Use internal string property and parse it
    if (self._extrasString) {
        NSError *error;
        NSData *jsonData = [self._extrasString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (!error) {
            return dict;
        }
    }
    return @{};
}

- (CLLocationAccuracy)getDesiredAccuracyForCLLocationManager {
    // Convert meters to CLLocationAccuracy
    if (self.desiredAccuracy <= 0) {
        return kCLLocationAccuracyBest;
    } else if (self.desiredAccuracy <= 10) {
        return kCLLocationAccuracyNearestTenMeters;
    } else if (self.desiredAccuracy <= 100) {
        return kCLLocationAccuracyHundredMeters;
    } else if (self.desiredAccuracy <= 1000) {
        return kCLLocationAccuracyKilometer;
    } else {
        return kCLLocationAccuracyThreeKilometers;
    }
}

#pragma mark - Orijinal TSConfig pattern - onChange callbacks

/**
 * Register onChange callback for a property (TSConfig pattern)
 * Orijinal TSConfig'dan: -[TSConfig onChange:callback:]
 * 
 * Assembly pattern:
 * - config.onChange(property, block) çağrılıyor
 * - Block'lar bir dictionary'de saklanıyor
 * - Property değiştiğinde tüm callback'ler çağrılıyor
 */
- (void)onChange:(NSString *)property callback:(void(^)(id value))block {
    if (!property || !block) {
        return;
    }
    
    @synchronized (self.onChangeCallbacks) {
        NSMutableArray *callbacks = self.onChangeCallbacks[property];
        if (!callbacks) {
            callbacks = [NSMutableArray array];
            self.onChangeCallbacks[property] = callbacks;
        }
        [callbacks addObject:[block copy]];
    }
}

/**
 * Notify onChange callbacks for a property (internal)
 */
- (void)notifyOnChange:(NSString *)property value:(id)value {
    @synchronized (self.onChangeCallbacks) {
        NSMutableArray *callbacks = self.onChangeCallbacks[property];
        if (callbacks) {
            for (void(^callback)(id) in callbacks) {
                if (callback) {
                    callback(value);
                }
            }
        }
    }
}

#pragma mark - iOS_PRECEDUR Pattern Methods

- (NSArray*)getStateProperties {
    // State properties: enabled, isMoving, odometer, trackingMode, etc.
    return @[@"enabled", @"isMoving", @"odometer", @"trackingMode", @"schedulerEnabled",
             @"lastLocationAuthorizationStatus", @"iOSHasWarnedLocationServicesOff",
             @"didRequestUpgradeLocationAuthorization", @"didLaunchInBackground"];
}

- (void)observeStateProperties {
    // Observe state properties for onChange callbacks (iOS_PRECEDUR pattern)
    NSArray *stateProperties = [self getStateProperties];
    
    for (NSString *propertyName in stateProperties) {
        @try {
            [self addObserver:self forKeyPath:propertyName options:NSKeyValueObservingOptionNew context:nil];
        } @catch (NSException *exception) {
            // Already observing
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    // CRITICAL: Don't notify onChange during load - prevents duplicate events on app start
    if (self.isLoading) {
        return;
    }
    
    // CRITICAL: "enabled" property için KVO observer'ı devre dışı bırak
    // LocationService ve TSLocationManager zaten enabledchange event'lerini gönderiyor
    // KVO observer duplicate event'lere sebep oluyor
    if ([keyPath isEqualToString:@"enabled"]) {
        // Skip KVO notification for "enabled" - LocationService handles it
        return;
    }
    
    // Notify onChange callbacks for state properties (iOS_PRECEDUR pattern)
    id newValue = change[NSKeyValueChangeNewKey];
    [self notifyOnChange:keyPath value:newValue];
}

- (void)dealloc {
    // Remove KVO observers for state properties
    NSArray *stateProperties = [self getStateProperties];
    for (NSString *propertyName in stateProperties) {
        @try {
            [self removeObserver:self forKeyPath:propertyName];
        } @catch (NSException *exception) {
            // Already removed
        }
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (CLLocationAccuracy)decodeDesiredAccuracy:(NSNumber*)accuracy {
    // Delegate to TSConfigBuilder
    return [TSConfigBuilder decodeDesiredAccuracy:accuracy];
}

#pragma mark - Orijinal Transistorsoft Notification Field Getters/Setters

- (NSString *)title {
    return _title ?: _notificationTitle ?: @"Location Tracking";
}

- (void)setTitle:(NSString *)title {
    _title = title;
    _notificationTitle = title; // Backward compatibility
}

- (NSString *)text {
    return _text ?: _notificationText ?: @"Your location is being tracked";
}

- (void)setText:(NSString *)text {
    _text = text;
    _notificationText = text; // Backward compatibility
}

- (NSString *)smallIcon {
    return _smallIcon ?: _notificationIcon ?: @"";
}

- (void)setSmallIcon:(NSString *)smallIcon {
    _smallIcon = smallIcon;
    _notificationIcon = smallIcon; // Backward compatibility
}

- (NSString *)largeIcon {
    return _largeIcon ?: @"";
}

- (void)setLargeIcon:(NSString *)largeIcon {
    _largeIcon = largeIcon;
}

- (NSString *)color {
    return _color ?: _notificationColor ?: @"#3498db";
}

- (void)setColor:(NSString *)color {
    _color = color;
    _notificationColor = color; // Backward compatibility
}

- (NSInteger)priority {
    return _priority ?: _notificationPriority ?: 0;
}

- (void)setPriority:(NSInteger)priority {
    _priority = priority;
    _notificationPriority = priority; // Backward compatibility
}

- (NSString *)channelName {
    return _channelName ?: _notificationChannelName ?: @"";
}

- (void)setChannelName:(NSString *)channelName {
    _channelName = channelName;
    _notificationChannelName = channelName; // Backward compatibility
}

- (NSString *)channelId {
    return _channelId ?: _notificationChannelId ?: @"";
}

- (void)setChannelId:(NSString *)channelId {
    _channelId = channelId;
    _notificationChannelId = channelId; // Backward compatibility
}

#pragma mark - Backward Compatibility: Eski Field İsimleri (Deprecated)

- (NSString *)notificationTitle {
    return self.title;
}

- (void)setNotificationTitle:(NSString *)notificationTitle {
    self.title = notificationTitle;
}

- (NSString *)notificationText {
    return self.text;
}

- (void)setNotificationText:(NSString *)notificationText {
    self.text = notificationText;
}

- (NSString *)notificationIcon {
    return self.smallIcon;
}

- (void)setNotificationIcon:(NSString *)notificationIcon {
    self.smallIcon = notificationIcon;
}

- (NSString *)notificationColor {
    return self.color;
}

- (void)setNotificationColor:(NSString *)notificationColor {
    self.color = notificationColor;
}

- (NSInteger)notificationPriority {
    return self.priority;
}

- (void)setNotificationPriority:(NSInteger)notificationPriority {
    self.priority = notificationPriority;
}

- (NSString *)notificationChannelName {
    return self.channelName;
}

- (void)setNotificationChannelName:(NSString *)notificationChannelName {
    self.channelName = notificationChannelName;
}

- (NSString *)notificationChannelId {
    return self.channelId;
}

- (void)setNotificationChannelId:(NSString *)notificationChannelId {
    self.channelId = notificationChannelId;
}

@end

