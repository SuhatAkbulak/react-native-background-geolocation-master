//
//  TSConfig.h
//  RNBackgroundLocation
//
//  Configuration Management Class
//  ExampleIOS/TSConfig.h pattern'ine göre güncellendi
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>

@class TSAuthorization;

NS_ASSUME_NONNULL_BEGIN

/**
 * TSSettingType enum
 */
typedef enum TSSettingType : NSInteger {
    tsSettingTypeString = 0,
    tsSettingTypeInteger,
    tsSettingTypeUInteger,
    tsSettingTypeBoolean,
    tsSettingTypeDouble,
    tsSettingTypeFloat,
    tsSettingTypeLong,
    tsSettingTypeDictionary,
    tsSettingTypeArray,
    tsSettingTypeModule
} TSSettingType;

typedef enum TSTrackingMode : NSInteger {
    tsTrackingModeGeofence = 0,
    tsTrackingModeLocation
} TSTrackingMode;

typedef enum TSLogLevel : NSInteger {
    tsLogLevelOff = 0,
    tsLogLevelError,
    tsLogLevelWarning,
    tsLogLevelInfo,
    tsLogLevelDebug,
    tsLogLevelVerbose
} TSLogLevel;

typedef enum TSPersistMode : NSInteger {
    tsPersistModeNone = 0,
    tsPersistModeAll = 2,
    tsPersistModeLocation = 1,
    tsPersistModeGeofence = -1
} TSPersistMode;

/**
 * TSConfigBuilder
 * ExampleIOS/TSConfig.h pattern'ine göre eklendi
 */
@interface TSConfigBuilder : NSObject

/// @name Properties

// Geolocation
@property (nonatomic) CLLocationAccuracy desiredAccuracy;
@property (nonatomic) CLLocationDistance distanceFilter;
@property (nonatomic) CLLocationDistance stationaryRadius;
@property (nonatomic) NSTimeInterval locationTimeout;
@property (nonatomic) BOOL useSignificantChangesOnly;
@property (nonatomic) BOOL pausesLocationUpdatesAutomatically;
@property (nonatomic) BOOL disableElasticity;
@property (nonatomic) double elasticityMultiplier;
@property (nonatomic) NSTimeInterval stopAfterElapsedMinutes;
@property (nonatomic, nullable) NSString* locationAuthorizationRequest;
@property (nonatomic, nullable) NSDictionary* locationAuthorizationAlert;
@property (nonatomic) BOOL disableLocationAuthorizationAlert;
@property (nonatomic) CLLocationDistance geofenceProximityRadius;
@property (nonatomic) BOOL geofenceInitialTriggerEntry;
@property (nonatomic) CLLocationAccuracy desiredOdometerAccuracy;
@property (nonatomic) BOOL enableTimestampMeta;
@property (nonatomic) BOOL showsBackgroundLocationIndicator;

// ActivityRecognition
@property (nonatomic) BOOL isMoving;
@property (nonatomic) CLActivityType activityType;
@property (nonatomic) NSTimeInterval stopDetectionDelay;
@property (nonatomic) NSTimeInterval stopTimeout;
@property (nonatomic) NSTimeInterval activityRecognitionInterval;
@property (nonatomic) NSInteger minimumActivityRecognitionConfidence;
@property (nonatomic) BOOL disableMotionActivityUpdates;
@property (nonatomic) BOOL disableStopDetection;
@property (nonatomic) BOOL stopOnStationary;

// HTTP & Persistence
@property (nonatomic, nullable) NSString* url;
@property (nonatomic, nullable) NSString* method;
@property (nonatomic, nullable) NSString* httpRootProperty;
@property (nonatomic, nullable) NSDictionary* params;
@property (nonatomic, nullable) NSDictionary* headers;
@property (nonatomic, nullable) NSDictionary* extras;
@property (nonatomic) BOOL autoSync;
@property (nonatomic) NSInteger autoSyncThreshold;
@property (nonatomic) BOOL batchSync;
@property (nonatomic) NSInteger maxBatchSize;
@property (nonatomic, nullable) NSString *locationTemplate;
@property (nonatomic, nullable) NSString *geofenceTemplate;
@property (nonatomic) NSInteger maxDaysToPersist;
@property (nonatomic) NSInteger maxRecordsToPersist;
@property (nonatomic, nullable) NSString* locationsOrderDirection;
@property (nonatomic) NSInteger httpTimeout;
@property (nonatomic) TSPersistMode persistMode;
@property (nonatomic) BOOL disableAutoSyncOnCellular;
@property (nonatomic, nullable) TSAuthorization* authorization;

// Application
@property (nonatomic) BOOL stopOnTerminate;
@property (nonatomic) BOOL startOnBoot;
@property (nonatomic) BOOL preventSuspend;
@property (nonatomic) NSTimeInterval heartbeatInterval;
@property (nonatomic, nullable) NSArray *schedule;
@property (nonatomic, nullable) NSString *triggerActivities;

// Logging & Debug
@property (nonatomic) BOOL debug;
@property (nonatomic) TSLogLevel logLevel;
@property (nonatomic) NSInteger logMaxDays;

/// :nodoc:
+ (void)eachProperty:(Class)mClass callback:(void(^)(NSString*, TSSettingType))block;
/// :nodoc:
+ (TSSettingType)getPropertyType:(objc_property_t)property;
/// :nodoc:
+ (CLLocationAccuracy)decodeDesiredAccuracy:(NSNumber*)accuracy;
/// :nodoc:
+ (CLActivityType)decodeActivityType:(NSString*)activityType;
/// :nodoc:
+ (BOOL)value:(id)value1 isEqualTo:(id)value2 withType:(TSSettingType)type;

- (NSDictionary*)toDictionary;
- (void)eachDirtyProperty:(void(^)(NSString* propertyName, TSSettingType type))block;
- (id)valueForKey:(NSString*)key withType:(TSSettingType)type;
- (BOOL)isDirty:(NSString*)propertyName;

@end

#pragma mark - TSConfig

/**
 * The SDK's Configuration API.
 * ExampleIOS/TSConfig.h pattern'ine göre güncellendi
 */
@interface TSConfig : NSObject <NSCoding>

#pragma mark - Singleton

/// Returns the singleton instance.
+ (TSConfig *)sharedInstance;
/// :nodoc:
+ (Class)classForPropertyName:(NSString*)name fromObject:(id)object;
+ (NSUserDefaults*)userDefaults;
/// :nodoc:
+ (CLLocationAccuracy)decodeDesiredAccuracy:(NSNumber*)accuracy;

/**
 * `YES` when the SDK is in the *location + geofence* tracking mode, where `-[TSLocationManager start]` was called.
 * `NO` when the SDK is in *geofences-only* tracking mode, where `-[TSLocationManager startGeofences]` was called.
 */
- (BOOL)isLocationTrackingMode;
/**
 * `YES` when this is the first launch after initial installation of you application.
 */
- (BOOL)isFirstBoot;
/**
 * `YES` when the application was launched in the background.
 */
- (BOOL)didLaunchInBackground;

#pragma mark - Initializers

/**
 * Update the SDK with new configuration options.
 */
- (void)updateWithBlock:(void(^)(TSConfigBuilder*))block;
/// :nodoc:
- (void)updateWithDictionary:(NSDictionary*)config;

/**
 * Resets the SDK's configuration to default values.
 */
- (void)reset;
/// :nodoc:
- (void)reset:(BOOL)silent;

#pragma mark - Geolocation methods
/// :nodoc:
- (BOOL)getPausesLocationUpdates;

#pragma mark - Events
/// :nodoc:
- (void)onChange:(NSString*)property callback:(void(^)(id))block;
/// :nodoc:
- (void)removeListeners;

#pragma mark - State methods
/// :nodoc:
- (void)incrementOdometer:(CLLocationDistance)distance;
/// :nodoc:
- (BOOL)hasValidUrl;
/// :nodoc:
- (BOOL)hasSchedule;
/// :nodoc:
- (NSDictionary*)getLocationAuthorizationAlertStrings;
- (BOOL)didDeviceReboot;

#pragma mark - Utility methods
/**
 * Returns an `NSDictionary` representation of the configuration options.
 */
- (NSDictionary*)toDictionary;
/// :nodoc:
- (NSDictionary*)toDictionary:(BOOL)redact;
/// :nodoc:
- (NSString*)toJson;
/// :nodoc:
- (void)registerPlugin:(NSString*)pluginName;
/// :nodoc:
- (BOOL)hasPluginForEvent:(NSString*)eventName;
- (BOOL)hasTriggerActivities;

/// @name State Properties

// Location Settings (readonly properties are defined below)
@property (nonatomic, assign) NSTimeInterval locationUpdateInterval; // milliseconds (default: 10000)
@property (nonatomic, assign) NSTimeInterval fastestLocationUpdateInterval; // milliseconds (default: 5000)

// Foreground Service / Background Modes
@property (nonatomic, assign) BOOL foregroundService; // default: YES
// Orijinal Transistorsoft field isimleri (title, text, color, smallIcon, largeIcon, priority, channelName, channelId)
@property (nonatomic, strong) NSString *title; // default: "Location Tracking" (backward compatibility: notificationTitle)
@property (nonatomic, strong) NSString *text; // default: "Your location is being tracked" (backward compatibility: notificationText)
@property (nonatomic, strong) NSString *smallIcon; // default: "" (backward compatibility: notificationIcon)
@property (nonatomic, strong) NSString *largeIcon; // default: "" (backward compatibility: notificationLargeIcon)
@property (nonatomic, strong) NSString *color; // default: "#3498db" (backward compatibility: notificationColor)
@property (nonatomic, assign) NSInteger priority; // default: 0 (backward compatibility: notificationPriority)
@property (nonatomic, strong) NSString *channelName; // default: "" (backward compatibility: notificationChannelName)
@property (nonatomic, strong) NSString *channelId; // default: "" (backward compatibility: notificationChannelId)

// Backward compatibility: Eski field isimlerini de destekle (deprecated)
@property (nonatomic, strong) NSString *notificationTitle __deprecated_msg("Use 'title' instead");
@property (nonatomic, strong) NSString *notificationText __deprecated_msg("Use 'text' instead");
@property (nonatomic, strong) NSString *notificationIcon __deprecated_msg("Use 'smallIcon' instead");
@property (nonatomic, strong) NSString *notificationColor __deprecated_msg("Use 'color' instead");
@property (nonatomic, assign) NSInteger notificationPriority __deprecated_msg("Use 'priority' instead");
@property (nonatomic, strong) NSString *notificationChannelName __deprecated_msg("Use 'channelName' instead");
@property (nonatomic, strong) NSString *notificationChannelId __deprecated_msg("Use 'channelId' instead");

// Power Management
@property (nonatomic, assign) NSTimeInterval deferTime; // default: 0
@property (nonatomic, assign) BOOL allowIdenticalLocations; // default: NO

// Platform Specific
@property (nonatomic, assign) BOOL enableHeadless; // default: NO

// Advanced
@property (nonatomic, assign) BOOL scheduleUseAlarmManager; // default: YES

// Session / DB management
@property (nonatomic, assign) BOOL clearLocationsOnStart; // default: NO

/// @name State Properties

/**
 * enabled is tracking enabled?
 */
@property (nonatomic) BOOL enabled;
/**
 * State of plugin, moving or stationary.
 */
@property (nonatomic) BOOL isMoving;
/**
 * True when scheduler is enabled
 */
@property (nonatomic) BOOL schedulerEnabled;

@property (nonatomic) CLLocationDistance odometer;
@property (nonatomic) TSTrackingMode trackingMode;
@property (nonatomic) CLAuthorizationStatus lastLocationAuthorizationStatus;
@property (nonatomic) BOOL iOSHasWarnedLocationServicesOff;
@property (nonatomic) BOOL didRequestUpgradeLocationAuthorization;
@property (nonatomic) BOOL didLaunchInBackground;

/// @name Geolocation Properties
@property (nonatomic, readonly) CLLocationAccuracy desiredAccuracy;
@property (nonatomic, readonly) CLLocationDistance distanceFilter;
@property (nonatomic, readonly) CLLocationDistance stationaryRadius;
@property (nonatomic, readonly) NSTimeInterval locationTimeout;
@property (nonatomic, readonly) BOOL useSignificantChangesOnly;
@property (nonatomic, readonly) BOOL pausesLocationUpdatesAutomatically;
@property (nonatomic, readonly) BOOL disableElasticity;
@property (nonatomic, readonly) double elasticityMultiplier;
@property (nonatomic, readonly) NSTimeInterval stopAfterElapsedMinutes;
@property (nonatomic, readonly, nullable) NSString* locationAuthorizationRequest;
@property (nonatomic, readonly) BOOL disableLocationAuthorizationAlert;
@property (nonatomic, readonly, nullable) NSDictionary* locationAuthorizationAlert;
@property (nonatomic, readonly) CLLocationDistance geofenceProximityRadius;
@property (nonatomic, readonly) BOOL geofenceInitialTriggerEntry;
@property (nonatomic, readonly) CLLocationAccuracy desiredOdometerAccuracy;
@property (nonatomic, readonly) BOOL enableTimestampMeta;
@property (nonatomic, readonly) BOOL showsBackgroundLocationIndicator;

/// @name ActivityRecognition Properties
@property (nonatomic, readonly) CLActivityType activityType;
@property (nonatomic, readonly) NSTimeInterval stopDetectionDelay;
@property (nonatomic, readonly) NSTimeInterval stopTimeout;
@property (nonatomic, readonly) NSTimeInterval activityRecognitionInterval;
@property (nonatomic, readonly) NSInteger minimumActivityRecognitionConfidence;
@property (nonatomic, readonly) BOOL disableMotionActivityUpdates;
@property (nonatomic, readonly) BOOL disableStopDetection;
@property (nonatomic, readonly) BOOL stopOnStationary;

/// @name HTTP & Persistence Properties
@property (nonatomic, readonly, nullable) NSString* url;
@property (nonatomic, readonly, nullable) NSString* method;
@property (nonatomic, readonly, nullable) NSString* httpRootProperty;
@property (nonatomic, readonly, nullable) NSDictionary* params;
@property (nonatomic, readonly, nullable) NSDictionary* headers;
@property (nonatomic, readonly, nullable) NSDictionary* extras;
@property (nonatomic, readonly) BOOL autoSync;
@property (nonatomic, readonly) NSInteger autoSyncThreshold;
@property (nonatomic, readonly) BOOL batchSync;
@property (nonatomic, readonly) NSInteger maxBatchSize;
@property (nonatomic, readonly, nullable) NSString *locationTemplate;
@property (nonatomic, readonly, nullable) NSString *geofenceTemplate;
@property (nonatomic, readonly) NSInteger maxDaysToPersist;
@property (nonatomic, readonly) NSInteger maxRecordsToPersist;
@property (nonatomic, readonly, nullable) NSString* locationsOrderDirection;
@property (nonatomic, readonly) NSInteger httpTimeout;
@property (nonatomic, readonly) TSPersistMode persistMode;
@property (nonatomic, readonly) BOOL disableAutoSyncOnCellular;
@property (nonatomic, readonly, nullable) TSAuthorization* authorization;

/// @name Application Properties
@property (nonatomic, readonly) BOOL stopOnTerminate;
@property (nonatomic, readonly) BOOL startOnBoot;
@property (nonatomic, readonly) BOOL preventSuspend;
@property (nonatomic, readonly) NSTimeInterval heartbeatInterval;
@property (nonatomic, readonly, nullable) NSArray *schedule;
@property (nonatomic, readonly, nullable) NSString *triggerActivities;

/// @name Logging & Debug Properties
@property (nonatomic, readonly) BOOL debug;
@property (nonatomic, readonly) TSLogLevel logLevel;
@property (nonatomic, readonly) NSInteger logMaxDays;

// Methods
- (void)reset;
- (void)updateWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)toDictionary;
- (void)save;
- (void)load;

// Helper methods
- (NSDictionary *)getHeadersDictionary;
- (NSDictionary *)getParamsDictionary;
- (NSDictionary *)getExtrasDictionary;
- (CLLocationAccuracy)getDesiredAccuracyForCLLocationManager;

// CRITICAL: Orijinal TSConfig pattern - onChange callbacks
- (void)onChange:(NSString *)property callback:(void(^)(id value))block;

// CRITICAL: Orijinal TSConfig pattern - notify onChange callbacks (internal)
- (void)notifyOnChange:(NSString *)property value:(id)value;

// iOS_PRECEDUR Pattern Methods
- (NSArray*)getStateProperties;
- (void)observeStateProperties;

@end

NS_ASSUME_NONNULL_END



