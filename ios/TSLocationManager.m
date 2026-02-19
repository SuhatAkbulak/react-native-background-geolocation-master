//
//  TSLocationManager.m
//  RNBackgroundLocation
//
//  Main API interface - ExampleIOS/TSLocationManager.h pattern'ine göre
//

#import "TSLocationManager.h"
#import "service/LocationService.h"
#import "service/SyncService.h"
#import "service/ActivityRecognitionService.h"
#import "service/HeartbeatService.h"
#import "service/ConnectivityMonitor.h"
#import "service/MotionDetectorService.h"
#import "data/sqlite/SQLiteLocationDAO.h"
#import "data/sqlite/SQLiteGeofenceDAO.h"
#import "data/LocationModel.h"
#import "data/GeofenceModel.h"
#import "event/LocationEvent.h"
#import "event/EnabledChangeEvent.h"
#import "event/TSEnabledChangeEvent.h"
#import "event/TSActivityChangeEvent.h"
#import "event/ActivityChangeEvent.h"
#import "event/TSGeofenceEvent.h"
#import "event/TSConnectivityChangeEvent.h"
#import "event/ConnectivityChangeEvent.h"
#import "event/TSHttpEvent.h"
#import "event/TSHeartbeatEvent.h"
#import "event/TSPowerSaveChangeEvent.h"
#import "event/HttpResponseEvent.h"
#import "util/LogHelper.h"
#import "util/LogQuery.h"
#import "util/TSDeviceInfo.h"
#import "util/TSCallback.h"
#import "scheduler/TSScheduler.h"
#import "lifecycle/LifecycleManager.h"
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MessageUI/MessageUI.h>
#import <UserNotifications/UserNotifications.h>
#import <CoreMotion/CoreMotion.h>

@implementation TSLocationManager {
    // Core services
    LocationService *_locationService;
    TSConfig *_config;
    TSGeofenceManager *_geofenceManager;
    SQLiteLocationDAO *_locationDatabase;
    SQLiteGeofenceDAO *_geofenceDatabase;
    TSScheduler *_scheduler;
    
    // Location managers
    LocationManager *_currentPositionManager;
    LocationManager *_watchPositionManager;
    LocationManager *_stateManager;
    CLLocationManager *_locationManager;
    
    // State flags
    BOOL _enabled;
    BOOL _isConfigured;
    BOOL _isDebuggingMotionDetection;
    BOOL _isUpdatingLocation;
    BOOL _isRequestingLocation;
    BOOL _isMonitoringSignificantLocationChanges;
    NSDate *_suspendedAt;
    BOOL _isLaunchedInBackground;
    BOOL _clientReady;
    BOOL _isAcquiringState;
    BOOL _wasAcquiringState;
    BOOL _isAcquiringBackgroundTime;
    BOOL _isAcquiringStationaryLocation;
    BOOL _isAcquiringSpeed;
    BOOL _isHeartbeatEnabled;
    
    // Location resources (stationaryLocation already defined above)
    CLLocation *_lastLocation;
    CLLocation *_lastGoodLocation;
    CLLocation *_lastOdometerLocation;
    
    // Event listeners
    NSMutableSet *_currentPositionRequests;
    NSMutableArray *_watchPositionRequests;
    NSMutableSet *_locationListeners;
    NSMutableSet *_motionChangeListeners;
    NSMutableSet *_activityChangeListeners;
    NSMutableSet *_providerChangeListeners;
    NSMutableSet *_httpListeners;
    NSMutableSet *_scheduleListeners;
    NSMutableSet *_heartbeatListeners;
    NSMutableSet *_powerSaveChangeListeners;
    NSMutableSet *_enabledChangeListeners;
    NSMutableSet *_authorizationListeners;
    NSMutableSet *_eventQueue;
    
    // Other
    UIViewController *_viewController;
    NSDate *_stoppedAt;
    UIBackgroundTaskIdentifier _preventSuspendTask;
    NSInteger _currentMotionType;
    NSDictionary* (^_beforeInsertBlock)(TSLocation*);
    TSCallback *_requestPermissionCallback;
}

#pragma mark - Singleton

+ (TSLocationManager *)sharedInstance {
    static TSLocationManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TSLocationManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize core services (ESKI PATTERN - LocationService kullan)
        _locationService = [LocationService sharedInstance];
        _config = [TSConfig sharedInstance];
        _geofenceManager = [[TSGeofenceManager alloc] init];
        _locationDatabase = [SQLiteLocationDAO sharedInstance];
        _geofenceDatabase = [SQLiteGeofenceDAO sharedInstance];
        _scheduler = [TSScheduler sharedInstance];
        
        // Initialize location managers (wrapper'lar)
        _currentPositionManager = [[LocationManager alloc] init];
        _watchPositionManager = [[LocationManager alloc] init];
        _stateManager = [[LocationManager alloc] init];
        _locationManager = _locationService.locationManager;
        
        // Initialize state
        _enabled = NO;
        _isConfigured = NO;
        _isDebuggingMotionDetection = NO;
        _isUpdatingLocation = NO;
        _isRequestingLocation = NO;
        _isMonitoringSignificantLocationChanges = NO;
        _isLaunchedInBackground = NO;
        _clientReady = NO;
        _isAcquiringState = NO;
        _wasAcquiringState = NO;
        _isAcquiringBackgroundTime = NO;
        _isAcquiringStationaryLocation = NO;
        _isAcquiringSpeed = NO;
        _isHeartbeatEnabled = NO;
        
        // Initialize event listeners
        _currentPositionRequests = [NSMutableSet set];
        _watchPositionRequests = [NSMutableArray array];
        _locationListeners = [NSMutableSet set];
        _motionChangeListeners = [NSMutableSet set];
        _activityChangeListeners = [NSMutableSet set];
        _providerChangeListeners = [NSMutableSet set];
        _httpListeners = [NSMutableSet set];
        _scheduleListeners = [NSMutableSet set];
        _heartbeatListeners = [NSMutableSet set];
        _powerSaveChangeListeners = [NSMutableSet set];
        _enabledChangeListeners = [NSMutableSet set];
        _authorizationListeners = [NSMutableSet set];
        _eventQueue = [NSMutableSet set];
        
        _preventSuspendTask = UIBackgroundTaskInvalid;
        _currentMotionType = 0;
        
        // Setup location service callbacks (ESKI PATTERN)
        [self setupLocationServiceCallbacks];
        
        // Setup lifecycle notifications
        [self setupLifecycleNotifications];
        
        // TRANSISTORSOFT LOG FORMAT - Init log
        [LogHelper i:@"TSLocationManager" message:@"ℹ️-[TSLocationManager init] "];
        [LogHelper i:@"TSLocationManager" message:@"╔═══════════════════════════════════════════════════════════"];
        [LogHelper i:@"TSLocationManager" message:@"║ TSLocationManager (build 4009)"];
        [LogHelper i:@"TSLocationManager" message:@"╠═══════════════════════════════════════════════════════════"];
    }
    return self;
}

- (void)setupLocationServiceCallbacks {
    __typeof(self) __weak weakSelf = self;
    
    // Location callback (ESKI PATTERN)
    _locationService.onLocationCallback = ^(LocationEvent *event) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Convert LocationEvent to TSLocation
        TSLocation *tsLocation = [strongSelf convertLocationEventToTSLocation:event];
        
        // Fire location listeners
        NSMutableSet *listeners = strongSelf->_locationListeners;
        for (void (^listener)(TSLocation*) in listeners) {
            listener(tsLocation);
        }
    };
    
    // Enabled change callback (ESKI PATTERN)
    _locationService.onEnabledChangeCallback = ^(EnabledChangeEvent *event) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        strongSelf->_enabled = event.enabled;
        
        // Fire enabled change listeners
        TSEnabledChangeEvent *tsEvent = [[TSEnabledChangeEvent alloc] initWithEnabled:event.enabled];
        NSMutableSet *listeners = strongSelf->_enabledChangeListeners;
        for (void (^listener)(TSEnabledChangeEvent*) in listeners) {
            listener(tsEvent);
        }
    };
    
    // CRITICAL: Activity Recognition callback (ESKİ PATTERN'DE EKSİKTİ!)
    // ActivityRecognitionService.onActivityChange callback'ini kur
    ActivityRecognitionService *activityService = [ActivityRecognitionService sharedInstance];
    activityService.onActivityChange = ^(ActivityChangeEvent *event) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Convert ActivityChangeEvent to TSActivityChangeEvent
        TSActivityChangeEvent *tsEvent = [[TSActivityChangeEvent alloc] initWithActivityName:event.activity confidence:event.confidence];
        
        // Fire activity change listeners
        NSMutableSet *listeners = strongSelf->_activityChangeListeners;
        for (void (^listener)(TSActivityChangeEvent*) in listeners) {
            listener(tsEvent);
        }
        
        // Also fire motion activity change event (for compatibility)
        [strongSelf fireMotionActivityChangeEvent:tsEvent];
    };
}

- (TSLocation*)convertLocationEventToTSLocation:(LocationEvent*)event {
    LocationModel *model = event.location;
    CLLocation *clLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(model.latitude, model.longitude)
                                                            altitude:model.altitude
                                                  horizontalAccuracy:model.accuracy
                                                    verticalAccuracy:model.altitudeAccuracy
                                                              course:model.heading
                                                               speed:model.speed
                                                           timestamp:[NSDate dateWithTimeIntervalSince1970:model.timestamp / 1000.0]];
    
    TSLocation *tsLocation = [[TSLocation alloc] initWithLocation:clLocation type:TS_LOCATION_TYPE_TRACKING extras:nil];
    [tsLocation setIsMoving:model.isMoving];
    [tsLocation setOdometer:@(model.odometer)];
    [tsLocation setEvent:model.event];
    
    return tsLocation;
}

- (void)setupLifecycleNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(onSuspend:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(onResume:) name:UIApplicationWillEnterForegroundNotification object:nil];
}


#pragma mark - Properties

- (BOOL)enabled {
    return _enabled;
}

- (BOOL)isConfigured {
    return _isConfigured;
}

- (BOOL)isDebuggingMotionDetection {
    return _isDebuggingMotionDetection;
}

- (BOOL)isUpdatingLocation {
    return _isUpdatingLocation;
}

- (BOOL)isRequestingLocation {
    return _isRequestingLocation;
}

- (BOOL)isMonitoringSignificantLocationChanges {
    return _isMonitoringSignificantLocationChanges;
}

- (NSDate*)suspendedAt {
    return _suspendedAt;
}

- (BOOL)isLaunchedInBackground {
    return _isLaunchedInBackground;
}

- (CLLocationManager*)locationManager {
    return _locationManager;
}

- (CLLocationDistance)distanceFilter {
    return _config.distanceFilter;
}

- (void)setDistanceFilter:(CLLocationDistance)distanceFilter {
    [_config updateWithDictionary:@{@"distanceFilter": @(distanceFilter)}];
    _locationManager.distanceFilter = distanceFilter;
}

- (LocationManager*)currentPositionManager {
    return _currentPositionManager;
}

- (LocationManager*)watchPositionManager {
    return _watchPositionManager;
}

- (LocationManager*)stateManager {
    return _stateManager;
}

- (CLLocation*)stationaryLocation {
    return _locationService.stationaryLocation;
}

- (CLLocation*)lastLocation {
    return _lastLocation ?: _locationService.lastLocation;
}

- (CLLocation*)lastGoodLocation {
    return _lastGoodLocation ?: self.lastLocation;
}

- (CLLocation*)lastOdometerLocation {
    return _lastOdometerLocation;
}

- (TSGeofenceManager*)geofenceManager {
    return _geofenceManager;
}

- (UIViewController*)viewController {
    return _viewController;
}

- (void)setViewController:(UIViewController*)viewController {
    _viewController = viewController;
}

- (NSDate*)stoppedAt {
    return _stoppedAt;
}

- (void)setStoppedAt:(NSDate*)stoppedAt {
    _stoppedAt = stoppedAt;
}

- (UIBackgroundTaskIdentifier)preventSuspendTask {
    return _preventSuspendTask;
}

- (void)setPreventSuspendTask:(UIBackgroundTaskIdentifier)preventSuspendTask {
    _preventSuspendTask = preventSuspendTask;
}

- (BOOL)clientReady {
    return _clientReady;
}

- (BOOL)isAcquiringState {
    return _isAcquiringState;
}

- (BOOL)wasAcquiringState {
    return _wasAcquiringState;
}

- (BOOL)isAcquiringBackgroundTime {
    return _isAcquiringBackgroundTime;
}

- (BOOL)isAcquiringStationaryLocation {
    return _isAcquiringStationaryLocation;
}

- (BOOL)isAcquiringSpeed {
    return _isAcquiringSpeed;
}

- (BOOL)isHeartbeatEnabled {
    return _isHeartbeatEnabled;
}

- (NSMutableSet*)currentPositionRequests {
    return _currentPositionRequests;
}

- (NSMutableArray*)watchPositionRequests {
    return _watchPositionRequests;
}

- (NSMutableSet*)locationListeners {
    return _locationListeners;
}

- (NSMutableSet*)motionChangeListeners {
    return _motionChangeListeners;
}

- (NSMutableSet*)activityChangeListeners {
    return _activityChangeListeners;
}

- (NSMutableSet*)providerChangeListeners {
    return _providerChangeListeners;
}

- (NSMutableSet*)httpListeners {
    return _httpListeners;
}

- (NSMutableSet*)scheduleListeners {
    return _scheduleListeners;
}

- (NSMutableSet*)heartbeatListeners {
    return _heartbeatListeners;
}

- (NSMutableSet*)powerSaveChangeListeners {
    return _powerSaveChangeListeners;
}

- (NSMutableSet*)enabledChangeListeners {
    return _enabledChangeListeners;
}

- (NSDictionary* (^)(TSLocation*))beforeInsertBlock {
    return _beforeInsertBlock;
}

- (void)setBeforeInsertBlock:(NSDictionary* (^)(TSLocation*))block {
    _beforeInsertBlock = block;
}

- (TSCallback*)requestPermissionCallback {
    return _requestPermissionCallback;
}

- (void)setRequestPermissionCallback:(TSCallback*)callback {
    _requestPermissionCallback = callback;
}

- (NSMutableSet*)eventQueue {
    return _eventQueue;
}

- (NSInteger)currentMotionType {
    return _currentMotionType;
}

- (void)setCurrentMotionType:(NSInteger)currentMotionType {
    _currentMotionType = currentMotionType;
}

#pragma mark - Core API Methods

- (void)configure:(NSDictionary*)params {
    [_config updateWithDictionary:params];
    _isConfigured = YES;
}

- (void)ready {
    _clientReady = YES;
    [_geofenceManager ready];
    
    // Start connectivity monitoring if needed
    ConnectivityMonitor *monitor = [ConnectivityMonitor sharedInstance];
    [monitor startMonitoring];
    
    // CRITICAL: _enabled state'ini _config.enabled'dan senkronize et
    _enabled = _config.enabled;
    
    // TRANSISTORSOFT LOG FORMAT
    [LogHelper i:@"TSLocationManager" message:@"🔵-[TSLocationManager ready]"];
    
    // CRITICAL: iOS stabil tracking - Uygulama açıldığında background tracking durumunu kontrol et
    // NOT: enabled state'ini değiştirme - sadece kontrol yap ve log yaz
    // enabled state'i sadece kullanıcı start()/stop() yaptığında değişmeli
    // NOT: Sadece stopOnTerminate: false ise bu kontrolü yap (stopOnTerminate: true ise tracking durmuş olmalı)
    if (!_config.stopOnTerminate) {
        // Kısa bir delay sonra kontrol et (LocationService'in initialize olması için)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL isTracking = _locationService.isTracking;
            
            // CRITICAL: Sadece kontrol yap ve log yaz - enabled state'ini değiştirme
            // enabled state'i sadece kullanıcı start()/stop() yaptığında değişmeli
            if (_config.debug) {
                [LogHelper d:@"TSLocationManager" message:[NSString stringWithFormat:@"ℹ️ Background tracking check: enabled=%@, isTracking=%@",
                                                            _config.enabled ? @"YES" : @"NO",
                                                            isTracking ? @"YES" : @"NO"]];
            }
        });
    }
}

- (void)start {
    // CRITICAL: Duplicate start'ı önle - eğer zaten tracking yapıyorsa VE enabled=true ise, tekrar start etme
    // Ama eğer enabled=false ama isTracking=true ise, start yapmalıyız (state senkronizasyonu için)
    if (_config.enabled && _locationService.isTracking) {
        if (_config.debug) {
            [LogHelper d:@"TSLocationManager" message:@"ℹ️ Already tracking and enabled, skipping start()"];
        }
        return;
    }
    
    // CRITICAL: Eğer enabled=false ama isTracking=true ise, LocationService.start() handle edecek
    // Burada sadece enabled state'ini set et, LocationService.start() geri kalanını yapacak
    // NOT: Recursive start() çağırma - LocationService.start() zaten handle ediyor
    
    // CRITICAL: iOS_PRECEDUR pattern - Orijinal log sırası
    // ╔═══════════════════════════════════════════════════════════
    // ║ -[TSLocationManager start]
    // ╚═══════════════════════════════════════════════════════════
    [LogHelper header:@"-[TSLocationManager start]"];
    
    // CRITICAL: Orijinal pattern - doStart: trackingMode
    // ℹ️-[TSLocationManager doStart:] trackingMode: 1
    TSTrackingMode trackingMode = _config.trackingMode;
    [LogHelper i:@"TSLocationManager" message:[NSString stringWithFormat:@"doStart: trackingMode: %ld", (long)trackingMode]];
    
    // CRITICAL: Orijinal pattern - TSConfig persist
    // ℹ️-[TSConfig persist]
    // CRITICAL: enabled state'ini set et (sadece bir kez)
    if (!_config.enabled) {
        _config.enabled = YES;
        [_config save];
    }
    [LogHelper i:@"TSConfig" message:@"persist"];
    
    // CRITICAL: Orijinal pattern - TSGeofenceManager start
    // 🎾-[TSGeofenceManager start]
    [_geofenceManager start];
    [LogHelper on:@"TSGeofenceManager" message:@"start"];
    
    // CRITICAL: Orijinal pattern - setPace
    // 🔵-[TSLocationManager setPace:] 0
    [self changePace:NO]; // Set isMoving to NO initially
    [LogHelper ok:@"TSLocationManager" message:[NSString stringWithFormat:@"setPace: %d", 0]];
    
    // CRITICAL: Orijinal pattern - startUpdatingLocation
    // 🎾-[TSLocationManager startUpdatingLocation] Location-services: ON
    _enabled = YES;
    [_locationService start];
    _isUpdatingLocation = YES;
    [LogHelper on:@"TSLocationManager" message:@"startUpdatingLocation Location-services: ON"];
    
    // CRITICAL: Orijinal pattern - startMonitoringSignificantLocationChanges
    // 🎾-[TSLocationManager startMonitoringSignificantLocationChanges]
    // NOT: Significant location changes LocationService.start() içinde başlatılıyor
    // Burada sadece log yaz
    if (!_config.stopOnTerminate) {
        [LogHelper on:@"TSLocationManager" message:@"startMonitoringSignificantLocationChanges"];
    }
    
    // CRITICAL: Orijinal pattern - LocationAuthorization
    // ℹ️+[LocationAuthorization run:onCancel:] status: 3
    // Note: Authorization status will be logged in LocationService authorization callback
}

- (void)stop {
    // CRITICAL: Duplicate stop'u önle - eğer zaten durmuşsa, tekrar stop etme
    if (!_config.enabled && !_locationService.isTracking) {
        if (_config.debug) {
            [LogHelper d:@"TSLocationManager" message:@"ℹ️ Already stopped, skipping stop()"];
        }
        return;
    }
    
    // CRITICAL: enabled state'ini önce set et, sonra servisi durdur
    _config.enabled = NO;
    [_config save];
    _enabled = NO;
    _isUpdatingLocation = NO;
    
    // CRITICAL: Fire enabledchange event BEFORE stopping service
    // This ensures UI gets updated immediately
    TSEnabledChangeEvent *event = [[TSEnabledChangeEvent alloc] initWithEnabled:NO];
    NSMutableSet *listeners = _enabledChangeListeners;
    for (void (^listener)(TSEnabledChangeEvent*) in listeners) {
        if (listener) {
            listener(event);
        }
    }
    
    // Servisi durdur
    [_locationService stop];
}

- (void)startSchedule {
    [_scheduler start];
}

- (void)stopSchedule {
    [_scheduler stop];
}

- (void)startGeofences {
    [_geofenceManager start];
}

- (NSMutableDictionary*)getState {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    
    // CRITICAL: getState() içinde config.load() çağırma - bu enabled state'ini reset edebilir
    // ready() zaten config.load() çağırıyor, bu yüzden burada tekrar çağırmaya gerek yok
    // Sadece mevcut state'i döndür
    
    // CRITICAL: LocationService'in gerçek tracking durumunu kontrol et
    // isTracking() metodu artık CLLocationManager'ın gerçek durumunu kontrol ediyor
    BOOL isActuallyTracking = _locationService.isTracking;
    
    // CRITICAL: _enabled state'ini _config.enabled'dan senkronize et
    _enabled = _config.enabled;
    
    // CRITICAL: Eğer config.enabled = true ama servis durmuş ise, enabled state'ini gerçek duruma göre ayarla
    // Ama getState() içinde restart yapma - ready() metodunda yapılacak
    if (_config.enabled && !isActuallyTracking) {
        if (_config.debug) {
            [LogHelper d:@"TSLocationManager" message:[NSString stringWithFormat:@"⚠️ getState(): Config enabled=true but service not tracking (will be restarted in ready())"]];
        }
    } else if (!_config.enabled && isActuallyTracking) {
        // Config'de enabled=false ama servis çalışıyor - servisi durdur
        if (_config.debug) {
            [LogHelper d:@"TSLocationManager" message:@"⚠️ Config enabled=false but service is tracking, stopping service"];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stop];
        });
    }
    
    state[@"enabled"] = @(_config.enabled);
    state[@"isMoving"] = @(_config.isMoving);
    state[@"odometer"] = @(_config.odometer);
    state[@"distanceFilter"] = @(_config.distanceFilter);
    state[@"desiredAccuracy"] = @(_config.desiredAccuracy);
    
    if (self.lastLocation) {
        state[@"lastLocation"] = @{
            @"latitude": @(self.lastLocation.coordinate.latitude),
            @"longitude": @(self.lastLocation.coordinate.longitude),
            @"accuracy": @(self.lastLocation.horizontalAccuracy)
        };
    }
    
    return state;
}

#pragma mark - Event Listener Methods

- (void)onLocation:(void(^)(TSLocation* location))success failure:(void(^)(NSError*))failure {
    if (success) {
        [_locationListeners addObject:success];
    }
}

- (void)onHttp:(void(^)(TSHttpEvent* event))success {
    if (success) {
        [_httpListeners addObject:success];
    }
}

- (void)onGeofence:(void(^)(TSGeofenceEvent* event))success {
    if (success) {
        [_geofenceManager onGeofence:success];
    }
}

- (void)onHeartbeat:(void(^)(TSHeartbeatEvent* event))success {
    if (success) {
        [_heartbeatListeners addObject:success];
    }
}

- (void)onMotionChange:(void(^)(TSLocation* event))success {
    if (success) {
        [_motionChangeListeners addObject:success];
    }
}

- (void)onActivityChange:(void(^)(TSActivityChangeEvent* event))success {
    if (success) {
        [_activityChangeListeners addObject:success];
    }
}

- (void)onProviderChange:(void(^)(TSProviderChangeEvent* event))success {
    if (success) {
        [_providerChangeListeners addObject:success];
    }
}

- (void)onGeofencesChange:(void(^)(TSGeofencesChangeEvent* event))success {
    if (success) {
        [_geofenceManager onGeofencesChange:success];
    }
}

- (void)onSchedule:(void(^)(TSScheduleEvent* event))success {
    if (success) {
        [_scheduleListeners addObject:success];
    }
}

- (void)onPowerSaveChange:(void(^)(TSPowerSaveChangeEvent* event))success {
    if (success) {
        [_powerSaveChangeListeners addObject:success];
    }
}

- (void)onConnectivityChange:(void(^)(TSConnectivityChangeEvent* event))success {
    if (success) {
        // Store listener
        // Note: We'll use ConnectivityChangeEvent and convert to TSConnectivityChangeEvent
        // For now, we'll create a wrapper
        ConnectivityMonitor *monitor = [ConnectivityMonitor sharedInstance];
        
        __typeof(self) __weak weakSelf = self;
        monitor.onConnectivityChangeCallback = ^(ConnectivityChangeEvent *event) {
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // Convert ConnectivityChangeEvent to TSConnectivityChangeEvent
            TSConnectivityChangeEvent *tsEvent = [[TSConnectivityChangeEvent alloc] initWithConnected:event.connected];
            
            // Fire listener
            success(tsEvent);
        };
    }
}

- (void)onEnabledChange:(void(^)(TSEnabledChangeEvent* event))success {
    if (success) {
        [_enabledChangeListeners addObject:success];
    }
}

- (void)onAuthorization:(void(^)(TSAuthorizationEvent*))callback {
    if (callback) {
        // Store authorization listener
        // TSAuthorization.resolve will call this when authorization changes
        // We'll hook into SyncService HTTP responses to detect 401/403
        // For now, store callback for future use
        // Note: This will be called from TSAuthorization.resolve method
        _authorizationListeners = _authorizationListeners ?: [NSMutableSet set];
        [_authorizationListeners addObject:callback];
    }
}

- (void)removeListener:(NSString*)event callback:(void(^)(id))callback {
    if ([event isEqualToString:@"location"]) {
        [_locationListeners removeObject:callback];
    } else if ([event isEqualToString:@"motionchange"]) {
        [_motionChangeListeners removeObject:callback];
    } else if ([event isEqualToString:@"activitychange"]) {
        [_activityChangeListeners removeObject:callback];
    } else if ([event isEqualToString:@"providerchange"]) {
        [_providerChangeListeners removeObject:callback];
    } else if ([event isEqualToString:@"http"]) {
        [_httpListeners removeObject:callback];
    } else if ([event isEqualToString:@"schedule"]) {
        [_scheduleListeners removeObject:callback];
    } else if ([event isEqualToString:@"heartbeat"]) {
        [_heartbeatListeners removeObject:callback];
    } else if ([event isEqualToString:@"powersavechange"]) {
        [_powerSaveChangeListeners removeObject:callback];
    } else if ([event isEqualToString:@"enabledchange"]) {
        [_enabledChangeListeners removeObject:callback];
    } else if ([event isEqualToString:@"connectivitychange"]) {
        // Connectivity listeners are managed by ConnectivityMonitor
    } else if ([event isEqualToString:@"authorization"]) {
        [_authorizationListeners removeObject:callback];
    }
}

- (void)un:(NSString*)event callback:(void(^)(id))callback {
    [self removeListener:event callback:callback];
}

- (void)removeListeners:(NSString*)event {
    if ([event isEqualToString:@"location"]) {
        [_locationListeners removeAllObjects];
    } else if ([event isEqualToString:@"motionchange"]) {
        [_motionChangeListeners removeAllObjects];
    } else if ([event isEqualToString:@"activitychange"]) {
        [_activityChangeListeners removeAllObjects];
    } else if ([event isEqualToString:@"providerchange"]) {
        [_providerChangeListeners removeAllObjects];
    } else if ([event isEqualToString:@"http"]) {
        [_httpListeners removeAllObjects];
    } else if ([event isEqualToString:@"schedule"]) {
        [_scheduleListeners removeAllObjects];
    } else if ([event isEqualToString:@"heartbeat"]) {
        [_heartbeatListeners removeAllObjects];
    } else if ([event isEqualToString:@"powersavechange"]) {
        [_powerSaveChangeListeners removeAllObjects];
    } else if ([event isEqualToString:@"enabledchange"]) {
        [_enabledChangeListeners removeAllObjects];
    } else if ([event isEqualToString:@"connectivitychange"]) {
        // Connectivity listeners are managed by ConnectivityMonitor
    } else if ([event isEqualToString:@"authorization"]) {
        [_authorizationListeners removeAllObjects];
    }
}

- (void)removeListenersForEvent:(NSString*)event {
    [self removeListeners:event];
}

- (void)removeListeners {
    [_locationListeners removeAllObjects];
    [_motionChangeListeners removeAllObjects];
    [_activityChangeListeners removeAllObjects];
    [_providerChangeListeners removeAllObjects];
    [_httpListeners removeAllObjects];
    [_scheduleListeners removeAllObjects];
    [_heartbeatListeners removeAllObjects];
    [_powerSaveChangeListeners removeAllObjects];
    [_enabledChangeListeners removeAllObjects];
    [_authorizationListeners removeAllObjects];
}

- (NSArray*)getListeners:(NSString*)event {
    NSMutableArray *listeners = [NSMutableArray array];
    
    if ([event isEqualToString:@"location"]) {
        [listeners addObjectsFromArray:[_locationListeners allObjects]];
    } else if ([event isEqualToString:@"motionchange"]) {
        [listeners addObjectsFromArray:[_motionChangeListeners allObjects]];
    } else if ([event isEqualToString:@"activitychange"]) {
        [listeners addObjectsFromArray:[_activityChangeListeners allObjects]];
    } else if ([event isEqualToString:@"providerchange"]) {
        [listeners addObjectsFromArray:[_providerChangeListeners allObjects]];
    } else if ([event isEqualToString:@"http"]) {
        [listeners addObjectsFromArray:[_httpListeners allObjects]];
    } else if ([event isEqualToString:@"schedule"]) {
        [listeners addObjectsFromArray:[_scheduleListeners allObjects]];
    } else if ([event isEqualToString:@"heartbeat"]) {
        [listeners addObjectsFromArray:[_heartbeatListeners allObjects]];
    } else if ([event isEqualToString:@"powersavechange"]) {
        [listeners addObjectsFromArray:[_powerSaveChangeListeners allObjects]];
    } else if ([event isEqualToString:@"enabledchange"]) {
        [listeners addObjectsFromArray:[_enabledChangeListeners allObjects]];
    } else if ([event isEqualToString:@"authorization"]) {
        [listeners addObjectsFromArray:[_authorizationListeners allObjects]];
    }
    
    return listeners;
}

#pragma mark - Application Lifecycle

- (void)onSuspend:(NSNotification *)notification {
    _suspendedAt = [NSDate date];
}

- (void)onResume:(NSNotification *)notification {
    _suspendedAt = nil;
}

- (void)onAppTerminate {
    if (_config.stopOnTerminate) {
        [self stop];
    }
}

#pragma mark - Geolocation Methods

- (void)changePace:(BOOL)value {
    _config.isMoving = value;
    [_config save];
}

- (void)getCurrentPosition:(TSCurrentPositionRequest*)request {
    if (!request) {
        request = [[TSCurrentPositionRequest alloc] init];
    }
    
    // Configure currentPositionManager
    if (request.timeout > 0) {
        _currentPositionManager.locationTimeout = request.timeout;
    }
    if (request.desiredAccuracy > 0) {
        _currentPositionManager.desiredAccuracy = request.desiredAccuracy;
    }
    if (request.samples > 0) {
        _currentPositionManager.maxLocationAttempts = request.samples;
    }
    
    // Setup callbacks
    __typeof(self) __weak weakSelf = self;
    TSCurrentPositionRequest *strongRequest = request; // Capture request in strong variable
    _currentPositionManager.locationChangedBlock = ^(LocationManager* manager, CLLocation* location, BOOL isSample) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Convert to TSLocation
        TSLocation *tsLocation = [[TSLocation alloc] initWithLocation:location type:TS_LOCATION_TYPE_CURRENT extras:strongRequest.extras];
        
        // Persist if requested (LocationService zaten persist ediyor, burada sadece callback için)
        // Note: getCurrentPosition için persist LocationService üzerinden yapılmıyor, burada yapılabilir
        if (strongRequest.persist) {
            // LocationService persist mekanizması tracking location'lar için, getCurrentPosition için ayrı
            NSDictionary *dict = [tsLocation toDictionary];
            [strongSelf->_locationDatabase persist:dict];
        }
        
        // Call success callback
        if (strongRequest.success) {
            strongRequest.success(tsLocation);
        }
        
        // Remove from requests
        [strongSelf->_currentPositionRequests removeObject:strongRequest];
    };
    
    _currentPositionManager.errorBlock = ^(LocationManager* manager, NSError* error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Call failure callback
        if (strongRequest.failure) {
            strongRequest.failure(error);
        }
        
        // Remove from requests
        [strongSelf->_currentPositionRequests removeObject:strongRequest];
    };
    
    // Add to requests
    [_currentPositionRequests addObject:request];
    
    // Request location
    [_currentPositionManager requestLocation];
}

- (void)setOdometer:(CLLocationDistance)odometer request:(TSCurrentPositionRequest*)request {
    _config.odometer = odometer;
    _lastOdometerLocation = nil;
    [_config save];
    
    // Get current position to set odometer reference
    if (request) {
        request.persist = NO; // Don't persist odometer reference location
        [self getCurrentPosition:request];
    }
}

- (CLLocationDistance)getOdometer {
    return _config.odometer;
}

- (void)watchPosition:(TSWatchPositionRequest*)request {
    if (!request) {
        return;
    }
    
    // Add to watch requests
    [_watchPositionRequests addObject:request];
    
    // Configure watchPositionManager
    if (request.desiredAccuracy > 0) {
        _watchPositionManager.desiredAccuracy = request.desiredAccuracy;
    }
    
    // Setup callbacks
    __typeof(self) __weak weakSelf = self;
    _watchPositionManager.locationChangedBlock = ^(LocationManager* manager, CLLocation* location, BOOL isSample) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Convert to TSLocation
        TSLocation *tsLocation = [[TSLocation alloc] initWithLocation:location type:TS_LOCATION_TYPE_WATCH extras:request.extras];
        
        // Persist if requested (LocationService zaten persist ediyor, burada sadece callback için)
        if (request.persist) {
            NSDictionary *dict = [tsLocation toDictionary];
            [strongSelf->_locationDatabase persist:dict];
        }
        
        // Call success callback
        if (request.success) {
            request.success(tsLocation);
        }
    };
    
    _watchPositionManager.errorBlock = ^(LocationManager* manager, NSError* error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Call failure callback
        if (request.failure) {
            request.failure(error);
        }
    };
    
    // Start watching
    [_watchPositionManager watchPosition:request];
}

- (void)stopWatchPosition {
    [_watchPositionManager stopWatchPosition];
    [_watchPositionRequests removeAllObjects];
}

- (NSDictionary*)getStationaryLocation {
    CLLocation *stationary = _locationService.stationaryLocation;
    if (stationary) {
        return @{
            @"latitude": @(stationary.coordinate.latitude),
            @"longitude": @(stationary.coordinate.longitude),
            @"accuracy": @(stationary.horizontalAccuracy),
            @"timestamp": @([stationary.timestamp timeIntervalSince1970] * 1000)
        };
    }
    return nil;
}

- (TSProviderChangeEvent*)getProviderState {
    CLAuthorizationStatus status = [_locationManager authorizationStatus];
    NSString *authRequest = _config.locationAuthorizationRequest ?: @"Always";
    return [[TSProviderChangeEvent alloc] initWithManager:_locationManager status:status authorizationRequest:authRequest];
}

- (void)requestPermission:(void(^)(NSNumber *status))success failure:(void(^)(NSNumber *status))failure {
    CLAuthorizationStatus currentStatus = [_locationManager authorizationStatus];
    
    // If already authorized, return immediately
    if (currentStatus == kCLAuthorizationStatusAuthorizedAlways || currentStatus == kCLAuthorizationStatusAuthorizedWhenInUse) {
        if (success) {
            success(@(currentStatus));
        }
        return;
    }
    
    // Store callbacks
    if (success || failure) {
        _requestPermissionCallback = [[TSCallback alloc] initWithSuccess:^(id result) {
            if (success) {
                success(result);
            }
        } failure:^(id error) {
            if (failure) {
                failure(error);
            }
        }];
    }
    
    // Request authorization
    NSString *authRequest = _config.locationAuthorizationRequest ?: @"Always";
    if ([authRequest isEqualToString:@"Always"]) {
        [_locationManager requestAlwaysAuthorization];
    } else {
        [_locationManager requestWhenInUseAuthorization];
    }
}

- (void)requestTemporaryFullAccuracy:(NSString*)purpose success:(void(^)(NSInteger))success failure:(void(^)(NSError*))failure {
    if (@available(iOS 14.0, *)) {
        [_locationManager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:purpose completion:^(NSError * _Nullable error) {
            if (error) {
                if (failure) {
                    failure(error);
                }
            } else {
                NSInteger accuracyAuth = _locationManager.accuracyAuthorization;
                if (success) {
                    success(accuracyAuth);
                }
            }
        }];
    } else {
        // iOS < 14 doesn't support temporary full accuracy
        if (failure) {
            NSError *error = [NSError errorWithDomain:@"TSLocationManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Temporary full accuracy not supported on iOS < 14"}];
            failure(error);
        }
    }
}

#pragma mark - HTTP & Persistence Methods

- (void)sync:(void(^)(NSArray* locations))success failure:(void(^)(NSError* error))failure {
    SyncService *syncService = [SyncService sharedInstance];
    
    // Setup HTTP callback
    __typeof(self) __weak weakSelf = self;
    syncService.onHttpCallback = ^(HttpResponseEvent *event) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Convert to TSHttpEvent
        TSHttpEvent *tsEvent = [[TSHttpEvent alloc] initWithStatusCode:event.statusCode
                                                             requestData:event.requestData
                                                            responseData:event.responseData
                                                                   error:event.error];
        
        // Fire HTTP listeners
        NSMutableSet *listeners = strongSelf->_httpListeners;
        for (void (^listener)(TSHttpEvent*) in listeners) {
            listener(tsEvent);
        }
        
        // Check for authorization errors (401/403) and fire authorization event
        if (event.statusCode == 401 || event.statusCode == 403) {
            __typeof(strongSelf) __weak weakSelf2 = strongSelf;
            if (strongSelf->_config.authorization) {
                [strongSelf->_config.authorization resolve:event.statusCode
                                                   success:^(TSAuthorizationEvent *authEvent) {
                    __strong typeof(self) strongSelf2 = weakSelf2;
                    if (!strongSelf2) return;
                    // Fire authorization listeners
                    NSMutableSet *listeners = strongSelf2->_authorizationListeners;
                    for (void (^listener)(TSAuthorizationEvent*) in listeners) {
                        listener(authEvent);
                    }
                } failure:^(TSAuthorizationEvent *authEvent) {
                    __strong typeof(self) strongSelf2 = weakSelf2;
                    if (!strongSelf2) return;
                    // Fire authorization listeners
                    NSMutableSet *listeners = strongSelf2->_authorizationListeners;
                    for (void (^listener)(TSAuthorizationEvent*) in listeners) {
                        listener(authEvent);
                    }
                }];
            }
        }
        
        if (event.success || event.isSuccess) {
            if (success) {
                success(event.locations ?: @[]);
            }
        } else {
            if (failure) {
                NSError *error = event.error ?: [NSError errorWithDomain:@"TSLocationManager" code:event.statusCode userInfo:@{NSLocalizedDescriptionKey: @"Sync failed"}];
                failure(error);
            }
        }
    };
    
    // Perform sync
    [syncService sync];
}

- (void)getLocations:(void(^)(NSArray* locations))success failure:(void(^)(NSString* error))failure {
    NSArray<LocationModel*> *models = [_locationDatabase all];
    NSMutableArray *locations = [NSMutableArray array];
    
    for (LocationModel *model in models) {
        CLLocation *clLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(model.latitude, model.longitude)
                                                                 altitude:model.altitude
                                                       horizontalAccuracy:model.accuracy
                                                         verticalAccuracy:model.altitudeAccuracy
                                                                   course:model.heading
                                                                    speed:model.speed
                                                                timestamp:[NSDate dateWithTimeIntervalSince1970:model.timestamp / 1000.0]];
        
        TSLocation *tsLocation = [[TSLocation alloc] initWithLocation:clLocation type:TS_LOCATION_TYPE_TRACKING extras:nil];
        [tsLocation setIsMoving:model.isMoving];
        [tsLocation setOdometer:@(model.odometer)];
        [tsLocation setEvent:model.event];
        
        [locations addObject:[tsLocation toDictionary]];
    }
    
    if (success) {
        success(locations);
    }
}

- (BOOL)clearDatabase {
    return [_locationDatabase clear];
}

- (BOOL)destroyLocations {
    return [_locationDatabase clear];
}

- (void)destroyLocations:(void(^)(void))success failure:(void(^)(NSString* error))failure {
    BOOL result = [_locationDatabase clear];
    if (result) {
        if (success) {
            success();
        }
    } else {
        if (failure) {
            failure(@"Failed to destroy locations");
        }
    }
}

- (void)destroyLocation:(NSString*)uuid {
    [self destroyLocation:uuid success:nil failure:nil];
}

- (void)destroyLocation:(NSString*)uuid success:(void(^)(void))success failure:(void(^)(NSString* error))failure {
    NSArray<LocationModel*> *all = [_locationDatabase all];
    for (LocationModel *model in all) {
        if ([model.uuid isEqualToString:uuid]) {
            BOOL result = [_locationDatabase destroy:model];
            if (result) {
                if (success) {
                    success();
                }
            } else {
                if (failure) {
                    failure(@"Failed to destroy location");
                }
            }
            return;
        }
    }
    
    if (failure) {
        failure(@"Location not found");
    }
}

- (void)insertLocation:(NSDictionary*)params success:(void(^)(NSString* uuid))success failure:(void(^)(NSString* error))failure {
    NSString *uuid = [_locationDatabase persist:params];
    if (uuid) {
        if (success) {
            success(uuid);
        }
    } else {
        if (failure) {
            failure(@"Failed to insert location");
        }
    }
}

// persistLocation, createLocationModel, cleanOldRecords metodları LocationService'te zaten var
// TSLocationManager sadece LocationEvent'leri TSLocation'a çevirip listener'lara fire ediyor

- (int)getCount {
    return (int)[_locationDatabase count];
}

- (UIBackgroundTaskIdentifier)createBackgroundTask {
    return [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
}

- (void)stopBackgroundTask:(UIBackgroundTaskIdentifier)taskId {
    [[UIApplication sharedApplication] endBackgroundTask:taskId];
}

- (BOOL)isPowerSaveMode {
    return [_locationService isPowerSaveMode];
}

#pragma mark - Logging & Debug Methods

- (void)getLog:(void(^)(NSString* log))success failure:(void(^)(NSString* error))failure {
    [self getLog:nil success:success failure:failure];
}

- (void)getLog:(LogQuery*)query success:(void(^)(NSString* log))success failure:(void(^)(NSString* error))failure {
    @try {
        // For now, return empty string or basic log info
        // In a full implementation, this would query a log database
        // For simplicity, we'll return a formatted string with current log level
        NSMutableString *logOutput = [NSMutableString string];
        [logOutput appendFormat:@"Log Level: %ld\n", (long)_config.logLevel];
        [logOutput appendFormat:@"Debug Mode: %@\n", _config.debug ? @"YES" : @"NO"];
        [logOutput appendString:@"\n"];
        [logOutput appendString:@"Note: Full log storage and query implementation requires a log database.\n"];
        [logOutput appendString:@"Current implementation uses NSLog for logging.\n"];
        
        if (query) {
            // Apply query filters if provided
            if (query.limit > 0) {
                [logOutput appendFormat:@"Query Limit: %d\n", query.limit];
            }
            if (query.start > 0 || query.end > 0) {
                [logOutput appendFormat:@"Time Range: %.0f - %.0f\n", query.start, query.end];
            }
        }
        
        if (success) {
            success(logOutput);
        }
    } @catch (NSException *exception) {
        if (failure) {
            failure(exception.reason);
        }
    }
}

- (void)emailLog:(NSString*)email success:(void(^)(void))success failure:(void(^)(NSString* error))failure {
    [self emailLog:email query:nil success:success failure:failure];
}

- (void)emailLog:(NSString*)email query:(LogQuery*)query success:(void(^)(void))success failure:(void(^)(NSString* error))failure {
    @try {
        // Get log content
        __typeof(self) __weak weakSelf = self;
        [self getLog:query success:^(NSString *log) {
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // Check if device can send email
            if (![MFMailComposeViewController canSendMail]) {
                if (failure) {
                    failure(@"Device cannot send email. Please configure an email account.");
                }
                return;
            }
            
            // Create mail composer
            MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc] init];
            [mailComposer setMailComposeDelegate:nil]; // Set delegate if needed
            [mailComposer setToRecipients:@[email]];
            [mailComposer setSubject:@"Background Location Log"];
            [mailComposer setMessageBody:log isHTML:NO];
            
            // Present mail composer
            if (strongSelf.viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf.viewController presentViewController:mailComposer animated:YES completion:^{
                        if (success) {
                            success();
                        }
                    }];
                });
            } else {
                if (failure) {
                    failure(@"No view controller available to present mail composer");
                }
            }
        } failure:^(NSString *error) {
            if (failure) {
                failure(error);
            }
        }];
    } @catch (NSException *exception) {
        if (failure) {
            failure(exception.reason);
        }
    }
}

- (void)uploadLog:(NSString*)url query:(LogQuery*)query success:(void(^)(void))success failure:(void(^)(NSString* error))failure {
    @try {
        // Get log content
        __typeof(self) __weak weakSelf = self;
        [self getLog:query success:^(NSString *log) {
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // Create HTTP request
            NSURL *uploadURL = [NSURL URLWithString:url];
            if (!uploadURL) {
                if (failure) {
                    failure(@"Invalid URL");
                }
                return;
            }
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:uploadURL];
            [request setHTTPMethod:@"POST"];
            [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
            
            // Convert log to data
            NSData *logData = [log dataUsingEncoding:NSUTF8StringEncoding];
            [request setHTTPBody:logData];
            
            // Apply authorization if available
            if (strongSelf->_config.authorization) {
                [strongSelf->_config.authorization apply:request];
            }
            
            // Perform upload
            NSURLSession *session = [NSURLSession sharedSession];
            NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    if (failure) {
                        failure(error.localizedDescription);
                    }
                } else {
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
                        if (success) {
                            success();
                        }
                    } else {
                        if (failure) {
                            failure([NSString stringWithFormat:@"Upload failed with status code: %ld", (long)httpResponse.statusCode]);
                        }
                    }
                }
            }];
            
            [task resume];
        } failure:^(NSString *error) {
            if (failure) {
                failure(error);
            }
        }];
    } @catch (NSException *exception) {
        if (failure) {
            failure(exception.reason);
        }
    }
}

- (BOOL)destroyLog {
    // For now, return YES as logs are not persisted
    // In a full implementation, this would clear the log database
    return YES;
}

- (void)setLogLevel:(NSInteger)level {
    [_config updateWithDictionary:@{@"logLevel": @(level)}];
    [_config save];
}

- (void)playSound:(SystemSoundID)soundId {
    AudioServicesPlaySystemSound(soundId);
}

- (void)error:(UIBackgroundTaskIdentifier)taskId message:(NSString*)message {
    [LogHelper e:@"TSLocationManager" message:message];
    [self stopBackgroundTask:taskId];
}

- (void)log:(NSString*)level message:(NSString*)message {
    [LogHelper log:level message:message];
}

#pragma mark - Geofencing Methods

- (void)addGeofence:(TSGeofence*)geofence success:(void (^)(void))success failure:(void (^)(NSString* error))failure {
    [self addGeofences:@[geofence] success:success failure:failure];
}

- (void)addGeofences:(NSArray*)geofences success:(void (^)(void))success failure:(void (^)(NSString* error))failure {
    [_geofenceManager create:geofences success:^{
        if (success) {
            success();
        }
    } failure:^(NSString* error) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void)removeGeofence:(NSString*)identifier success:(void (^)(void))success failure:(void (^)(NSString* error))failure {
    [self removeGeofences:@[identifier] success:success failure:failure];
}

- (void)removeGeofences:(NSArray*)identifiers success:(void (^)(void))success failure:(void (^)(NSString* error))failure {
    [_geofenceManager destroy:identifiers success:^{
        if (success) {
            success();
        }
    } failure:^(NSString* error) {
        if (failure) {
            failure(error);
        }
    }];
}

- (void)removeGeofences {
    // Get all geofences and remove them
    NSArray *all = [_geofenceDatabase all];
    NSMutableArray *identifiers = [NSMutableArray array];
    for (GeofenceModel *model in all) {
        [identifiers addObject:model.identifier];
    }
    
    if (identifiers.count > 0) {
        [self removeGeofences:identifiers success:nil failure:nil];
    }
}

- (NSArray*)getGeofences {
    NSArray *all = [_geofenceDatabase all];
    NSMutableArray *geofences = [NSMutableArray array];
    
    for (GeofenceModel *model in all) {
        TSGeofence *geofence = [[TSGeofence alloc] initWithIdentifier:model.identifier
                                                                 radius:model.radius
                                                               latitude:model.latitude
                                                              longitude:model.longitude
                                                          notifyOnEntry:model.notifyOnEntry
                                                           notifyOnExit:model.notifyOnExit
                                                          notifyOnDwell:model.notifyOnDwell
                                                         loiteringDelay:model.loiteringDelay / 1000.0];
        [geofences addObject:geofence];
    }
    
    return geofences;
}

- (void)getGeofences:(void (^)(NSArray*))success failure:(void (^)(NSString*))failure {
    NSArray *geofences = [self getGeofences];
    NSMutableArray *dicts = [NSMutableArray array];
    
    for (TSGeofence *geofence in geofences) {
        [dicts addObject:[geofence toDictionary]];
    }
    
    if (success) {
        success(dicts);
    }
}

- (void)getGeofence:(NSString*)identifier success:(void (^)(TSGeofence*))success failure:(void (^)(NSString*))failure {
    GeofenceModel *model = [_geofenceDatabase get:identifier];
    if (model) {
        TSGeofence *geofence = [[TSGeofence alloc] initWithIdentifier:model.identifier
                                                               radius:model.radius
                                                             latitude:model.latitude
                                                            longitude:model.longitude
                                                        notifyOnEntry:model.notifyOnEntry
                                                         notifyOnExit:model.notifyOnExit
                                                        notifyOnDwell:model.notifyOnDwell
                                                       loiteringDelay:model.loiteringDelay / 1000.0];
        if (success) {
            success(geofence);
        }
    } else {
        if (failure) {
            failure(@"Geofence not found");
        }
    }
}

- (void)geofenceExists:(NSString*)identifier callback:(void (^)(BOOL))callback {
    GeofenceModel *model = [_geofenceDatabase get:identifier];
    if (callback) {
        callback(model != nil);
    }
}

#pragma mark - Sensor Methods

- (BOOL)isMotionHardwareAvailable {
    return [TSDeviceInfo isMotionHardwareAvailable];
}

- (BOOL)isDeviceMotionAvailable {
    return [TSDeviceInfo isDeviceMotionAvailable];
}

- (BOOL)isAccelerometerAvailable {
    return [TSDeviceInfo isAccelerometerAvailable];
}

- (BOOL)isGyroAvailable {
    return [TSDeviceInfo isGyroAvailable];
}

- (BOOL)isMagnetometerAvailable {
    return [TSDeviceInfo isMagnetometerAvailable];
}

- (void)fireMotionActivityChangeEvent:(TSActivityChangeEvent*)event {
    for (void (^listener)(TSActivityChangeEvent*) in _activityChangeListeners) {
        listener(event);
    }
}

#pragma mark - Location Tracking (ESKI PATTERN - LocationService kullan)

// Bu metodlar artık LocationService'te - TSLocationManager sadece wrapper

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

