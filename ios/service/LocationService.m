//
//  LocationService.m
//  RNBackgroundLocation
//
//  Location Tracking Service
//  Android LocationService.java benzeri
//

#import "LocationService.h"
#import "TSConfig.h"
#import "LocationModel.h"
#import "SQLiteLocationDAO.h"
#import "LocationEvent.h"
#import "EnabledChangeEvent.h"
#import "TSPowerSaveChangeEvent.h"
#import "ConnectivityMonitor.h"
#import "SyncService.h"
#import "ActivityRecognitionService.h"
#import "HeartbeatService.h"
#import "HeartbeatEvent.h"
#import "LifecycleManager.h"
#import "LogHelper.h"
#import "MotionDetectorService.h"
#import "TSScheduler.h"
#import "BackgroundTaskManager.h"
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <UserNotifications/UserNotifications.h>
#import <BackgroundTasks/BackgroundTasks.h>

// iOS 17+ batarya optimizasyonu için Swift header
#if __has_include("RNBackgroundLocation-Swift.h")
#import "RNBackgroundLocation-Swift.h"
#endif

// Background Fetch identifier (Info.plist'te tanımlı)
static NSString *const kBackgroundFetchIdentifier = @"com.rnbackgroundlocation.fetch";


@interface LocationService ()
@property (nonatomic, strong) SQLiteLocationDAO *database;
// stationaryLocation artık header'da public property olarak tanımlı
@property (nonatomic, assign) NSTimeInterval lastStationaryEventTime; // Stationary durumda event throttle için
@property (nonatomic, strong) CLLocation *lastPersistedLocation; // Son SQL'e yazılan konum
@property (nonatomic, assign) NSTimeInterval lastPersistedTime; // Son persist zamanı (saniye)
@property (nonatomic, assign) BOOL lastIsMovingState; // Motion change detection için önceki durum
@property (nonatomic, assign) BOOL isTracking; // Location tracking aktif mi? (iOS'ta isUpdatingLocation yok)
// Background task management (iOS_PRECEDUR pattern)
@property (nonatomic, assign) UIBackgroundTaskIdentifier preventSuspendTask; // Background task identifier
@property (nonatomic, assign) BOOL isMonitoringSignificantLocationChanges; // Track significant location changes state
@property (nonatomic, assign) NSTimeInterval lastLocationUpdateTime; // Son location update zamanı
// TRANSISTORSOFT PATTERN: PreventSuspend Timer - Background'da uygulamanın suspend olmasını önler
@property (nonatomic, strong) NSTimer *preventSuspendTimer; // 15 saniyede bir background task yenileme
@property (nonatomic, assign) BOOL isPreventSuspendActive; // PreventSuspend timer aktif mi?
// TRANSISTORSOFT PATTERN: Heartbeat Timer - 60 saniyede bir heartbeat event gönderir
@property (nonatomic, strong) NSTimer *heartbeatTimer; // 60 saniyede bir heartbeat
@property (nonatomic, assign) BOOL isHeartbeatActive; // Heartbeat timer aktif mi?
// TRANSISTORSOFT PATTERN: Stationary Region Monitoring - Kullanıcı hareket ettiğinde algıla
@property (nonatomic, strong) CLCircularRegion *stationaryRegion; // Stationary region
@property (nonatomic, assign) BOOL isMonitoringStationaryRegion; // Stationary region monitoring aktif mi?
/// Debug bildirim throttle: konum bildirimi en fazla bu aralıkla (saniye)
@property (nonatomic, assign) NSTimeInterval lastDebugLocationNotificationTime;
@end

@implementation LocationService

+ (instancetype)sharedInstance {
    static LocationService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LocationService alloc] init];
    });
    return instance;
}

#pragma mark - Location Tracking Helpers

/// Klasik CLLocationManager ile location tracking başlatır
- (void)startLocationTracking {
    // CRITICAL FIX: Background'a geçildiğinde allowsBackgroundLocationUpdates kontrolü
    // Uygulama background'dayken location tracking başlatılıyorsa, allowsBackgroundLocationUpdates MUTLAKA YES olmalı
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    CLAuthorizationStatus authStatus = [self.locationManager authorizationStatus];
    
    if (appState == UIApplicationStateBackground && authStatus == kCLAuthorizationStatusAuthorizedAlways) {
        // Background'dayken location tracking başlatılıyor - allowsBackgroundLocationUpdates MUTLAKA YES olmalı
        if (!self.locationManager.allowsBackgroundLocationUpdates) {
            self.locationManager.allowsBackgroundLocationUpdates = YES;
            [LogHelper w:@"LocationService" message:@"⚠️⚠️⚠️ [CRITICAL] startLocationTracking in BACKGROUND: allowsBackgroundLocationUpdates was NO, setting to YES ⚠️⚠️⚠️"];
        } else {
            [LogHelper i:@"LocationService" message:@"✅ [BG-START] allowsBackgroundLocationUpdates already YES"];
        }
    }
    
    // Klasik CLLocationManager kullan
    [self.locationManager startUpdatingLocation];
    
    if (appState == UIApplicationStateBackground) {
        [LogHelper i:@"LocationService" message:@"✅ [BG-START] Classic CLLocationManager started in BACKGROUND (allowsBackgroundLocationUpdates=YES)"];
    } else {
        [LogHelper d:@"LocationService" message:@"✅ Classic CLLocationManager started (stable, no crashes)"];
    }
}

/// Klasik CLLocationManager ile location tracking durdurur
- (void)stopLocationTracking {
    [self.locationManager stopUpdatingLocation];
    [LogHelper d:@"LocationService" message:@"✅ Classic CLLocationManager stopped"];
}

#pragma mark - Background Fetch (iOS 13+)

/// Background Fetch'i schedule et (periyodik görevler ve app restart için)
- (void)scheduleBackgroundFetch API_AVAILABLE(ios(13.0)) {
    // CRITICAL: Simulator'da Background Fetch çalışmaz
    #if TARGET_IPHONE_SIMULATOR
    [LogHelper d:@"LocationService" message:@"ℹ️ Background Fetch not available on simulator"];
    return;
    #endif
    
    // CRITICAL: Background App Refresh kontrolü
    if ([[UIApplication sharedApplication] backgroundRefreshStatus] != UIBackgroundRefreshStatusAvailable) {
        [LogHelper w:@"LocationService" message:@"⚠️ Background App Refresh is not available (user may have disabled it in Settings)"];
        return;
    }
    
    BGAppRefreshTaskRequest *request = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:kBackgroundFetchIdentifier];
    
    // 15 dakika sonra (minimum interval - iOS'un belirlediği süre)
    // iOS gerçekte kullanıcı davranışına göre optimize eder, bu sadece minimum
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:15 * 60];
    
    NSError *error = nil;
    BOOL success = [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
    
    if (!success) {
        // Error 1 = BGTaskSchedulerErrorCodeUnavailable (simulator veya Background App Refresh kapalı)
        // Error 2 = BGTaskSchedulerErrorCodeTooManyPendingTaskRequests
        NSInteger errorCode = error.code;
        if (errorCode == 1) {
            [LogHelper w:@"LocationService" message:@"⚠️ Background Fetch not available (simulator or Background App Refresh disabled)"];
        } else {
            [LogHelper w:@"LocationService" message:[NSString stringWithFormat:@"⚠️ Background Fetch schedule failed (code: %ld): %@", (long)errorCode, error.localizedDescription]];
        }
    } else {
        [LogHelper d:@"LocationService" message:@"✅ Background Fetch scheduled successfully (app will restart periodically)"];
    }
}

/// Background Fetch schedule'ı iptal et
- (void)cancelBackgroundFetch API_AVAILABLE(ios(13.0)) {
    [[BGTaskScheduler sharedScheduler] cancelTaskRequestWithIdentifier:kBackgroundFetchIdentifier];
    [LogHelper d:@"LocationService" message:@"✅ Background Fetch schedule cancelled"];
}

#pragma mark - iOS 17+ Batarya Optimizasyonu

/// iOS 17+ için CLBackgroundActivitySession başlatır
/// Batarya optimizasyonu için kritik - sistem'e uygulamanın aktif olduğunu bildirir
/// Swift wrapper üzerinden kullanılır (CLBackgroundActivitySession Objective-C'de direkt kullanılamaz)
- (void)startBackgroundActivitySession {
    if (@available(iOS 17.0, *)) {
        #if __has_include("RNBackgroundLocation-Swift.h")
        Class LiveLocationStreamClass = NSClassFromString(@"LiveLocationStream");
        if (LiveLocationStreamClass) {
            id sharedInstance = [LiveLocationStreamClass performSelector:@selector(sharedInstance)];
            if (sharedInstance) {
                [sharedInstance performSelector:@selector(startBackgroundActivitySession)];
                [LogHelper i:@"LocationService" message:@"✅ CLBackgroundActivitySession started (iOS 17+ batarya optimizasyonu)"];
            }
        }
        #else
        [LogHelper w:@"LocationService" message:@"⚠️ CLBackgroundActivitySession not available (Swift header not generated)"];
        #endif
    }
}

/// iOS 17+ için CLBackgroundActivitySession durdurur
- (void)stopBackgroundActivitySession {
    if (@available(iOS 17.0, *)) {
        #if __has_include("RNBackgroundLocation-Swift.h")
        Class LiveLocationStreamClass = NSClassFromString(@"LiveLocationStream");
        if (LiveLocationStreamClass) {
            id sharedInstance = [LiveLocationStreamClass performSelector:@selector(sharedInstance)];
            if (sharedInstance) {
                [sharedInstance performSelector:@selector(stopBackgroundActivitySession)];
                [LogHelper i:@"LocationService" message:@"✅ CLBackgroundActivitySession stopped"];
            }
        }
        #endif
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _config = [TSConfig sharedInstance];
        _database = [SQLiteLocationDAO sharedInstance];
        _totalDistance = 0.0;
        _trackingStartTime = 0;
        _preventSuspendTask = UIBackgroundTaskInvalid; // Initialize background task identifier
        _isMonitoringSignificantLocationChanges = NO; // Initialize significant location changes flag
        
        // CRITICAL: Don't start services in init - wait for start() method
        // This prevents sync operations from starting before tracking begins
        
        // Initialize LifecycleManager ()
        LifecycleManager *lifecycleManager = [LifecycleManager sharedInstance];
        [lifecycleManager initialize];
        lifecycleManager.delegate = self; // CRITICAL: Set delegate to handle lifecycle events
        [LogHelper d:@"LocationService" message:@"✅ LifecycleManager initialized and delegate set"];
        
        // CRITICAL: Orijinal TSLocationManager pattern - enabled onChange callback
        // Assembly: config.onChange("enabled", block) çağrılıyor
        // Block içeriği: TSEnabledChangeEvent oluşturuluyor ve TSQueue.runOnMainQueueWithoutDeadlocking ile çağrılıyor
        __weak typeof(self) weakSelf = self;
        [self.config onChange:@"enabled" callback:^(id value) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            // CRITICAL: Orijinal pattern - TSEnabledChangeEvent oluşturuluyor
            // Assembly: event = [[TSEnabledChangeEvent alloc] initWithEnabled:boolValue];
            BOOL enabled = [value boolValue];
            EnabledChangeEvent *event = [[EnabledChangeEvent alloc] initWithEnabled:enabled];
            
            // CRITICAL: Orijinal pattern - TSQueue.runOnMainQueueWithoutDeadlocking ile çağrılıyor
            // Assembly: [TSQueue.sharedInstance runOnMainQueueWithoutDeadlocking:block];
            // TSQueue yok, bu yüzden dispatch_async(dispatch_get_main_queue(), ...) kullanıyoruz
            dispatch_async(dispatch_get_main_queue(), ^{
                // CRITICAL: Orijinal pattern - event callback'i çağrılıyor
                // Assembly: block içinde event fire ediliyor
                // CRITICAL: Main queue'da çağır ki UI hemen güncellensin
                if (strongSelf.onEnabledChangeCallback) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (strongSelf.onEnabledChangeCallback) {
                            strongSelf.onEnabledChangeCallback(event);
                        }
                    });
                }
            });
        }];
        
        // Monitor power save mode changes (iOS)
        [self startPowerSaveMonitoring];
        
        // CRITICAL: iOS_PRECEDUR pattern - Auto-start if app was launched in background
        // iOS significant location change veya background fetch ile uygulama başlatıldığında otomatik başlat
        // Note: Config.load() will restore enabled state if stopOnTerminate: false
        UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
        if (appState == UIApplicationStateBackground && !self.isTracking) {
            // Check if stopOnTerminate is false (enabled state will be restored by config.load)
            // or startOnBoot is enabled
            if (!self.config.stopOnTerminate || self.config.startOnBoot) {
                [LogHelper d:@"LocationService" message:@"🔄 App launched in background (significant location change or background fetch), checking auto-start conditions..."];
                
                // Small delay to ensure all services are initialized and config is loaded
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // Reload config to ensure enabled state is restored (if stopOnTerminate: false)
                    [self.config load];
                    
                    // CRITICAL: stopOnTerminate: false ise ve önceki oturumda enabled=true idi, otomatik başlat
                    if (!self.config.stopOnTerminate) {
                        // Config.load() zaten enabled state'i restore etti (eğer savedEnabled=true ise)
                        if (self.config.enabled && !self.isTracking) {
                            [LogHelper i:@"LocationService" message:@"✅ Auto-starting location tracking (background launch - stopOnTerminate: false)"];
                            [self start];
                        } else {
                            [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"ℹ️ Auto-start skipped: enabled=%@, isTracking=%@", 
                                                                      self.config.enabled ? @"YES" : @"NO",
                                                                      self.isTracking ? @"YES" : @"NO"]];
                        }
                    } else if (self.config.startOnBoot && self.config.enabled && !self.isTracking) {
                        [LogHelper i:@"LocationService" message:@"✅ Auto-starting location tracking (background launch - startOnBoot: true)"];
                        [self start];
                    }
                });
            }
        }
    }
    return self;
}

- (void)start {
    // CRITICAL: enabled=false ise start yapma
    // TSLocationManager.start() zaten enabled=true set ediyor, ama yine de kontrol et
    if (!self.config.enabled) {
        if (self.config.debug) {
            [LogHelper w:@"LocationService" message:@"⚠️ config.enabled=false in LocationService.start(), cannot start tracking"];
        }
        return;
    }
    
    // CRITICAL: Duplicate start'ı önle - eğer zaten tracking yapıyorsa VE enabled=true ise, tekrar start etme
    // Ama isTracking flag'i bazen gerçek durumu yansıtmayabilir (özellikle stop() sonrası)
    // Bu yüzden CLLocationManager'ın gerçek durumunu da kontrol et
    BOOL actuallyTracking = self.isTracking;
    
    // CRITICAL: Eğer isTracking=true ama enabled=false ise, önce stop et
    // Bu durum genellikle ready() sonrası stop() çağrıldığında oluşur
    if (actuallyTracking && !self.config.enabled) {
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:@"🔄 isTracking=true but enabled=false, stopping first..."];
        }
        // Location manager'ı durdur
        [self stopLocationTracking];
        if (self.isMonitoringSignificantLocationChanges) {
            [self.locationManager stopMonitoringSignificantLocationChanges];
            self.isMonitoringSignificantLocationChanges = NO;
        }
        // Flag'leri temizle
        _isTracking = NO;
        actuallyTracking = NO;
    }
    
    // CRITICAL: Eğer zaten tracking yapıyorsa VE enabled=true ise, tekrar start etme
    // Ama eğer stop() sonrası isTracking flag'i yanlış ise, restart et
    if (actuallyTracking && self.config.enabled) {
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:@"ℹ️ Already tracking and enabled, skipping start()"];
        }
        // CRITICAL: Ama yine de location manager'ın gerçek durumunu kontrol et
        // Eğer location manager durmuşsa, restart et
        // iOS'ta CLLocationManager'ın isUpdatingLocation property'si yok, bu yüzden manuel kontrol yapamıyoruz
        // Ama allowsBackgroundLocationUpdates kontrolü yapabiliriz
        if (!self.locationManager.allowsBackgroundLocationUpdates) {
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:@"🔄 isTracking=true but allowsBackgroundLocationUpdates=false, restarting..."];
            }
            // Restart et - aşağıdaki kod devam edecek
            _isTracking = NO;
            actuallyTracking = NO;
        } else {
            // Gerçekten tracking yapıyor, skip et
            return;
        }
    }
    
    // Use config for authorization request type
    NSString *authRequest = self.config.locationAuthorizationRequest ?: @"Always";
    BOOL requestAlways = [authRequest isEqualToString:@"Always"];
    
    if (requestAlways && self.config.foregroundService) {
        // Request always authorization for background location
        [self.locationManager requestAlwaysAuthorization];
        
        // Request notification permission for foreground service
        if (@available(iOS 10.0, *)) {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (granted) {
                    [LogHelper d:@"LocationService" message:@"✅ Notification permission granted"];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setupForegroundNotification];
                    });
                } else {
                    [LogHelper w:@"LocationService" message:@"⚠️ Notification permission denied"];
                }
                if (error) {
                    [LogHelper e:@"LocationService" message:[NSString stringWithFormat:@"❌ Notification permission error: %@", error.localizedDescription] error:error];
                }
            }];
        }
    } else {
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    // CRITICAL: isTracking flag'ini HENÜZ set etme - location manager başlatıldıktan SONRA set et
    // Bu, duplicate start'ı önler ve gerçek durumu yansıtır
    
    // Configure CLLocationManager
    // CRITICAL: iOS best practices 2024 - Stabil location tracking için
    self.locationManager.desiredAccuracy = [self.config getDesiredAccuracyForCLLocationManager];
    self.locationManager.distanceFilter = self.config.distanceFilter;
    self.locationManager.pausesLocationUpdatesAutomatically = NO; // CRITICAL: iOS'un otomatik pause etmesini engelle
    // CRITICAL: activityType ayarı batarya optimizasyonu için önemli
    if (@available(iOS 12.0, *)) {
        self.locationManager.activityType = CLActivityTypeOtherNavigation; // Navigation için en stabil
    }
    
    // iOS 11+ background location indicator
    if (@available(iOS 11.0, *)) {
        self.locationManager.showsBackgroundLocationIndicator = self.config.showsBackgroundLocationIndicator;
    }
    
    // CRITICAL: allowsBackgroundLocationUpdates should be set AFTER authorization
    // It will be set in locationManagerDidChangeAuthorization callback
    // For now, check current authorization status
    CLAuthorizationStatus currentStatus = [CLLocationManager authorizationStatus];
    
    // CRITICAL: Background location tracking için her zaman "Always" authorization gerekiyor
    // Eğer "WhenInUse" ise, background'da çalışmayacak
    // CRITICAL FIX: allowsBackgroundLocationUpdates HEMEN ve SYNC olarak set edilmeli
    // Async olarak set edilirse, uygulama hızla background'a geçtiğinde henüz set edilmemiş olabilir
    if (currentStatus == kCLAuthorizationStatusAuthorizedAlways) {
        // CRITICAL FIX: allowsBackgroundLocationUpdates'ı HEMEN set et (async DEĞİL!)
        // Bu kritik: Eğer kullanıcı uygulamayı hemen background'a gönderirse,
        // async callback'ten önce background'a geçilmiş olur ve location tracking çalışmaz
        self.locationManager.allowsBackgroundLocationUpdates = YES;
        [LogHelper i:@"LocationService" message:@"✅ [START] allowsBackgroundLocationUpdates set to YES IMMEDIATELY (sync)"];
        
        // CRITICAL: iOS 17+ için CLLocationUpdate.liveUpdates() kullan (batarya optimizasyonu)
        // iOS < 17 için klasik CLLocationManager kullanılacak
        if (@available(iOS 17.0, *)) {
            #if __has_include("RNBackgroundLocation-Swift.h")
            // Swift header mevcut, LiveLocationStream kullanılabilir
            Class LiveLocationStreamClass = NSClassFromString(@"LiveLocationStream");
            if (LiveLocationStreamClass) {
                SEL isAvailableSelector = NSSelectorFromString(@"isAvailable");
                if ([LiveLocationStreamClass respondsToSelector:isAvailableSelector]) {
                    BOOL isAvailable = ((BOOL (*)(id, SEL))[LiveLocationStreamClass methodForSelector:isAvailableSelector])(LiveLocationStreamClass, isAvailableSelector);
                    if (isAvailable) {
                        // CRITICAL: iOS 17+ batarya optimizasyonu - CLBackgroundActivitySession başlat
                        [self startBackgroundActivitySession];
                        [LogHelper i:@"LocationService" message:@"✅ [START] iOS 17+ detected - using CLLocationUpdate.liveUpdates() (batarya optimizasyonu)"];
                        
                        SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
                        id sharedInstance = ((id (*)(id, SEL))[LiveLocationStreamClass methodForSelector:sharedInstanceSelector])(LiveLocationStreamClass, sharedInstanceSelector);
                        
                        if (sharedInstance) {
                            __weak typeof(self) weakSelf = self;
                            void (^handler)(CLLocation *) = ^(CLLocation *location) {
                                __strong typeof(weakSelf) strongSelf = weakSelf;
                                if (!strongSelf) return;
                                if (!strongSelf.isTracking) return;
                                
                                // Mevcut pipeline'ı korumak için delegate metodunu tetikle
                                [strongSelf locationManager:strongSelf.locationManager didUpdateLocations:@[location]];
                            };
                            
                            SEL startSelector = NSSelectorFromString(@"startWithHandler:");
                            NSMethodSignature *signature = [sharedInstance methodSignatureForSelector:startSelector];
                            if (signature) {
                                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                                [invocation setTarget:sharedInstance];
                                [invocation setSelector:startSelector];
                                [invocation setArgument:&handler atIndex:2];
                                [invocation retainArguments];
                                [invocation invoke];
                                
                                _isTracking = YES;
                                [LogHelper i:@"LocationService" message:@"✅ [START] CLLocationUpdate.liveUpdates() started (iOS 17+ batarya optimizasyonu)"];
                            } else {
                                // Fallback to classic CLLocationManager
                                [self startLocationTracking];
                                _isTracking = YES;
                                [LogHelper i:@"LocationService" message:@"✅ [START] Location tracking started (classic CLLocationManager fallback)"];
                            }
                        } else {
                            // Fallback to classic CLLocationManager
                            [self startLocationTracking];
                            _isTracking = YES;
                            [LogHelper i:@"LocationService" message:@"✅ [START] Location tracking started (classic CLLocationManager fallback)"];
                        }
                    } else {
                        // Fallback to classic CLLocationManager
                        [self startLocationTracking];
                        _isTracking = YES;
                        [LogHelper i:@"LocationService" message:@"✅ [START] Location tracking started (classic CLLocationManager fallback)"];
                    }
                } else {
                    // Fallback to classic CLLocationManager
                    [self startLocationTracking];
                    _isTracking = YES;
                    [LogHelper i:@"LocationService" message:@"✅ [START] Location tracking started (classic CLLocationManager fallback)"];
                }
            } else {
                // Fallback to classic CLLocationManager
                [self startLocationTracking];
                _isTracking = YES;
                [LogHelper i:@"LocationService" message:@"✅ [START] Location tracking started (classic CLLocationManager fallback)"];
            }
            #else
            // Swift header yok, klasik yöntemi kullan
            [self startLocationTracking];
            _isTracking = YES;
            [LogHelper i:@"LocationService" message:@"✅ [START] Location tracking started (classic CLLocationManager - Swift header not available)"];
            #endif
        } else {
            // iOS < 17 için klasik CLLocationManager
            [self startLocationTracking];
            _isTracking = YES;
            [LogHelper i:@"LocationService" message:@"✅ [START] Location tracking started (classic CLLocationManager - iOS < 17)"];
        }
        
        // iOS 13+ için notification permission kontrolü (opsiyonel, background tracking zaten başladı)
        if (@available(iOS 13.0, *)) {
            if (self.config.foregroundService) {
                [LogHelper i:@"LocationService" message:@"🔄 [START] iOS 13+ checking notification permission (background tracking already active)..."];
                
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                            [LogHelper i:@"LocationService" message:@"✅ [START] Notification authorized - foreground notification setup"];
                            [self setupForegroundNotification];
                        } else {
                            [LogHelper w:@"LocationService" message:@"⚠️ [START] Notification NOT authorized - background tracking may have issues on some iOS versions"];
                            // allowsBackgroundLocationUpdates zaten set edildi, sadece uyarı ver
                        }
                    });
                }];
            }
        }
        
        // Foreground notification setup (iOS 12 ve altı için de)
        if (self.config.foregroundService && @available(iOS 10.0, *)) {
            if (@available(iOS 13.0, *)) {
                // iOS 13+ için yukarıda yapıldı
            } else {
                // iOS 12 için
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                    if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self setupForegroundNotification];
                        });
                    }
                }];
            }
        }
        
        [LogHelper d:@"LocationService" message:@"✅ Background location updates enabled (Always authorization)"];
    } else if (currentStatus == kCLAuthorizationStatusAuthorizedWhenInUse) {
        // When in use authorization - start updates (will work in foreground only)
        self.locationManager.allowsBackgroundLocationUpdates = NO;
        [self startLocationTracking];
        // CRITICAL: isTracking flag'ini location manager başlatıldıktan SONRA set et
        _isTracking = YES;
        [LogHelper w:@"LocationService" message:@"⚠️ Location updates started (when in use - background disabled)"];
    } else {
        // Authorization henüz verilmemiş - start updates anyway (authorization callback'te kontrol edilecek)
        self.locationManager.allowsBackgroundLocationUpdates = NO;
        [self startLocationTracking];
        // CRITICAL: isTracking flag'ini location manager başlatıldıktan SONRA set et
        _isTracking = YES;
        [LogHelper d:@"LocationService" message:@"✅ Location updates started (authorization pending)"];
    }
    
    // Start connectivity monitoring ()
    // Only start if autoSync is enabled and tracking is active
    if (self.config.autoSync) {
        [[ConnectivityMonitor sharedInstance] startMonitoring];
        [LogHelper d:@"LocationService" message:@"✅ Connectivity monitoring started"];
    }
    
    // Start Activity Recognition Service ()
    if (!self.config.disableMotionActivityUpdates) {
        [ActivityRecognitionService start];
        [LogHelper d:@"LocationService" message:@"✅ Activity recognition started"];
    }
    
    // Start Heartbeat Service ()
    if (self.config.heartbeatInterval > 0) {
        [HeartbeatService start];
        [LogHelper d:@"LocationService" message:@"✅ Heartbeat service started"];
    }
    

    // CRITICAL: iOS_PRECEDUR pattern - Start significant location changes for app restart
    // iOS uygulamayı terminate olduktan sonra significant location change geldiğinde arka planda başlatabilir
    // Bu, stopOnTerminate: false olduğunda kritik
    // CRITICAL: Her zaman significant location changes'i başlat (iOS'un location updates'i durdurmasını önlemek için)
    // Normal location updates ile birlikte kullanılabilir
    if (!self.isMonitoringSignificantLocationChanges) {
        [self.locationManager startMonitoringSignificantLocationChanges];
        self.isMonitoringSignificantLocationChanges = YES;
        // TRANSISTORSOFT LOG FORMAT
        [LogHelper i:@"TSTrackingService" message:@"🟢-[TSTrackingService startMonitoringSignificantLocationChanges]"];
    }
    
    // CRITICAL: Timer'sız event-driven monitoring
    // Her location update'te son update zamanını kaydedeceğiz ve kontrol edeceğiz
    // Timer yerine location update'lerin kendisi monitoring yapacak
    self.lastLocationUpdateTime = [[NSDate date] timeIntervalSince1970];
    
    // CRITICAL: Orijinal TSLocationManager pattern - SOMotionDetector initialization
    // Assembly: motionDetector = [SOMotionDetector sharedInstance];
    //          motionDetector.useM7IfAvailable = !config.disableMotionActivityUpdates;
    //          motionDetector.debug = config.debug;
    //          motionDetector.motionTypeChangedBlock = [self createMotionTypeChangedHandler];
    if ([MotionDetectorService motionHardwareAvailable]) {
        MotionDetectorService *motionDetector = [MotionDetectorService sharedInstance];
        
        // CRITICAL: Orijinal pattern - useM7IfAvailable set ediliyor
        // Assembly: motionDetector.useM7IfAvailable = !config.disableMotionActivityUpdates;
        // disableMotionActivityUpdates'in tersi (XOR ile: disableMotionActivityUpdates ^ 1)
        motionDetector.useM7IfAvailable = !self.config.disableMotionActivityUpdates;
        
        // CRITICAL: Orijinal pattern - debug set ediliyor
        // Assembly: motionDetector.debug = config.debug;
        // NOT: MotionDetectorService'de debug property'si yok, bu yüzden skip ediyoruz
        // Gerekirse debug property'si eklenebilir
        
        // CRITICAL: Orijinal pattern - motionTypeChangedBlock set ediliyor
        // Assembly: motionDetector.motionTypeChangedBlock = [self createMotionTypeChangedHandler];
        __typeof(self) __weak me = self;
        motionDetector.motionTypeChangedBlock = ^(MDMotionType motionType, NSInteger shakeCount, double averageVectorSum) {
            TSConfig *config = [TSConfig sharedInstance];
            if (config.debug) {
                NSString *motionTypeName = [motionDetector motionTypeName:motionType];
                NSInteger confidence = [motionDetector motionActivityConfidence];
                
                NSString *emoji = @"❓";
                if (motionType == MDMotionTypeAutomotive) emoji = @"🚗";
                else if (motionType == MDMotionTypeCycling) emoji = @"🚴";
                else if (motionType == MDMotionTypeRunning) emoji = @"🏃";
                else if (motionType == MDMotionTypeWalking) emoji = @"🚶";
                else if (motionType == MDMotionTypeStationary) emoji = @"🛑";
                
                NSString *debugBody = [NSString stringWithFormat:@"%@ %@\n📊 Confidence: %ld%%\n📈 Shake: %ld\n⚡ Vector: %.2f",
                                       emoji,
                                       motionTypeName,
                                       (long)confidence,
                                       (long)shakeCount,
                                       averageVectorSum];
                
                [me showDebugNotification:@"🎯 Motion Type Change" body:debugBody];
            }
        };
        
        [motionDetector startDetection];
        [LogHelper d:@"LocationService" message:@"✅ Motion detector (SOMotionDetector-style) started"];
    }
    
    // Start tracking timer
    if (self.trackingStartTime == 0) {
        self.trackingStartTime = [[NSDate date] timeIntervalSince1970];
        [self scheduleAutoStop];
    }
    
    // Initialize stationary detection
    self.stationaryLocation = nil; // Reset stationary reference point (stoppedAt location)
    self.lastStationaryEventTime = 0; // Reset throttle timer
    self.lastIsMovingState = self.config.isMoving; // Initialize motion state tracking
    
    // Reset persist state so ilk start'ta en az 1 konum mutlaka gönderilsin
    // (Önceki oturumdan kalan persist bilgisi yeni start'ı etkilemesin)
    self.lastPersistedLocation = nil;
    self.lastPersistedTime = 0;
    
    // Setup foreground notification if needed (immediate, permission will be requested above)
    if (self.config.foregroundService && @available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setupForegroundNotification];
                });
            }
        }];
    }
    
    // TRANSISTORSOFT PATTERN: Heartbeat Timer başlat (60s interval)
    // heartbeatInterval config'den alınır, default 60s
    if (self.config.heartbeatInterval > 0) {
        [self startHeartbeatTimer];
    }
    
    // CRITICAL: Background Fetch schedule et (iOS 13+)
    // Uygulama terminate olduğunda iOS'un uygulamayı periyodik olarak restart etmesini sağlar
    if (@available(iOS 13.0, *)) {
        [self scheduleBackgroundFetch];
        [LogHelper i:@"TSTrackingService" message:@"✅-[TSTrackingService start] Background Fetch scheduled"];
    }
    
    // TRANSISTORSOFT LOG FORMAT
    [LogHelper i:@"TSLocationManager" message:@"╔═══════════════════════════════════════════════════════════"];
    [LogHelper i:@"TSLocationManager" message:@"║ -[TSLocationManager start] "];
    [LogHelper i:@"TSLocationManager" message:@"╚═══════════════════════════════════════════════════════════"];
    [LogHelper i:@"TSTrackingService" message:[NSString stringWithFormat:@"╔═══════════════════════════════════════════════════════════\n║ -[TSTrackingService start:] 🟢 trackingMode: %d\n╚═══════════════════════════════════════════════════════════", self.config.trackingMode]];
}

- (void)stop {
    // CRITICAL: Duplicate stop'u önle - eğer zaten durmuşsa, tekrar stop etme
    if (!self.isTracking && !self.config.enabled) {
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:@"ℹ️ Already stopped, skipping stop()"];
        }
        return;
    }
    
    [LogHelper i:@"TSLocationManager" message:@"🛑-[TSLocationManager stop] LocationService.stop() called"];
    
    // TRANSISTORSOFT PATTERN: PreventSuspend timer'ı durdur
    [self stopPreventSuspendTimer];
    
    // TRANSISTORSOFT PATTERN: Heartbeat timer'ı durdur
    [self stopHeartbeatTimer];
    
    // TRANSISTORSOFT PATTERN: Stationary region monitoring'i durdur
    [self stopMonitoringStationaryRegion];
    
    // CRITICAL: iOS 17+ için CLLocationUpdate.liveUpdates() durdur
    if (@available(iOS 17.0, *)) {
        #if __has_include("RNBackgroundLocation-Swift.h")
        Class LiveLocationStreamClass = NSClassFromString(@"LiveLocationStream");
        if (LiveLocationStreamClass) {
            SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
            id sharedInstance = ((id (*)(id, SEL))[LiveLocationStreamClass methodForSelector:sharedInstanceSelector])(LiveLocationStreamClass, sharedInstanceSelector);
            if (sharedInstance) {
                SEL stopSelector = NSSelectorFromString(@"stop");
                [sharedInstance performSelector:stopSelector];
                [LogHelper i:@"LocationService" message:@"✅ [STOP] CLLocationUpdate.liveUpdates() stopped (iOS 17+)"];
            }
        }
        #endif
    }
    
    // CRITICAL: ÖNCE location tracking'i HEMEN durdur - diğer işlemlerden önce
    // Bu, stop() çağrıldığında hemen durmasını sağlar
    [self stopLocationTracking];
    
    // CRITICAL: iOS 17+ batarya optimizasyonu - CLBackgroundActivitySession durdur
    [self stopBackgroundActivitySession];
    
    // CRITICAL: Background Fetch schedule'ı iptal et (iOS 13+)
    if (@available(iOS 13.0, *)) {
        [self cancelBackgroundFetch];
    }
    
    // CRITICAL: allowsBackgroundLocationUpdates'ı HEMEN NO yap
    // Bu, iOS'un location updates'i hemen durdurmasını sağlar
    if (self.locationManager.allowsBackgroundLocationUpdates) {
        self.locationManager.allowsBackgroundLocationUpdates = NO;
        [LogHelper d:@"LocationService" message:@"✅ [STOP] allowsBackgroundLocationUpdates set to NO (immediate stop)"];
    }
    
    // CRITICAL: Set enabled flag BEFORE stopping other services
    // This prevents sync operations from continuing after stop
    self.config.enabled = NO;
    [self.config save];
    
    // CRITICAL: isTracking flag'ini önce temizle
    _isTracking = NO;
    
    // CRITICAL: onChange:@"enabled" callback'i sadece notifyOnChange çağrıldığında tetikleniyor
    // notifyOnChange çağrısını kaldırdığımız için, direkt EnabledChangeEvent oluşturup onEnabledChangeCallback'i çağırmalıyız
    // CRITICAL: Main queue'da çağır ki UI hemen güncellensin
    EnabledChangeEvent *event = [[EnabledChangeEvent alloc] initWithEnabled:NO];
    if (self.onEnabledChangeCallback) {
        // Main queue'da çağır ki React Native tarafına hemen event gönderilsin
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.onEnabledChangeCallback) {
                self.onEnabledChangeCallback(event);
            }
        });
    }
    
    // CRITICAL: iOS_PRECEDUR pattern - Stop background task
    [self stopBackgroundTask];
    
    
    // CRITICAL: Timer'sız event-driven monitoring - Timer yok, temizlemeye gerek yok
    // Location update'lerin kendisi monitoring yapıyor
    
    // CRITICAL: iOS_PRECEDUR pattern - Stop significant location changes
    if (self.isMonitoringSignificantLocationChanges) {
        [self.locationManager stopMonitoringSignificantLocationChanges];
        self.isMonitoringSignificantLocationChanges = NO;
        [LogHelper d:@"LocationService" message:@"✅ Significant location changes stopped"];
    }
    
    // Stop connectivity monitoring ()
    [[ConnectivityMonitor sharedInstance] stopMonitoring];
    [LogHelper d:@"LocationService" message:@"✅ Connectivity monitoring stopped"];
    
    // Stop Activity Recognition Service ()
    [ActivityRecognitionService stop];
    [LogHelper d:@"LocationService" message:@"✅ Activity recognition stopped"];
    
    // Stop Heartbeat Service ()
    [HeartbeatService stop];
    [LogHelper d:@"LocationService" message:@"✅ Heartbeat service stopped"];
    
    // Remove notification
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center removeDeliveredNotificationsWithIdentifiers:@[@"BackgroundLocation"]];
        [center removePendingNotificationRequestsWithIdentifiers:@[@"BackgroundLocation"]];
        [LogHelper d:@"LocationService" message:@"✅ Notification removed"];
    }
    
    // CRITICAL: Memory leak prevention - Clear callbacks to break retain cycles
    // Callback'ler copy property olarak tanımlanmış, bu yüzden nil yapmak retain cycle'ı kırar
    self.onLocationCallback = nil;
    self.onEnabledChangeCallback = nil;
    self.onPowerSaveChangeCallback = nil;
    [LogHelper d:@"LocationService" message:@"✅ Callbacks cleared (memory leak prevention)"];
    
    [LogHelper i:@"LocationService" message:@"✅ LocationService stopped"];
}

- (void)scheduleAutoStop {
    if (self.config.stopAfterElapsedMinutes <= 0) {
        return;
    }
    
    // Tracking start time zaten set edildi (start() içinde)
    // Artık her location update'te kontrol edeceğiz (handleLocationUpdate içinde)
    // Bu yaklaşım daha güvenilir: app suspend olsa bile, bir sonraki location update'te kontrol edilir
    
    [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"✅ Auto stop enabled: will stop after %ld minutes", (long)self.config.stopAfterElapsedMinutes]];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    CLAuthorizationStatus status = manager.authorizationStatus;
    NSInteger errorCode = error.code;
    
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    NSString *appStateStr = (appState == UIApplicationStateBackground) ? @"BACKGROUND" : 
                           (appState == UIApplicationStateInactive) ? @"INACTIVE" : @"FOREGROUND";
    
    NSString *errorMessage = [NSString stringWithFormat:@"❌ [ERROR] LocationManager error: %@ (code: %ld, auth: %ld, state: %@)", 
                             error.localizedDescription, (long)errorCode, (long)status, appStateStr];
    
    [LogHelper e:@"LocationService" message:errorMessage error:error];
    
    // CRITICAL: Apple Documentation - Handle different error types
    // https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
    
    if (errorCode == kCLErrorLocationUnknown) {
        // kCLErrorLocationUnknown - Location service temporarily unavailable
        // This can happen if allowsBackgroundLocationUpdates is not properly set or iOS paused updates
        [LogHelper w:@"LocationService" message:@"⚠️ [ERROR] Location unknown - service temporarily unavailable"];
        
        if (status == kCLAuthorizationStatusAuthorizedAlways && self.config.enabled) {
            // Try to re-enable background location updates
            [LogHelper w:@"LocationService" message:@"⚠️ [ERROR] Attempting to re-enable background location updates..."];
            
            if (@available(iOS 13.0, *)) {
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                            self.locationManager.allowsBackgroundLocationUpdates = YES;
                            [self startLocationTracking];
                            self.isTracking = YES;
                            [LogHelper i:@"LocationService" message:@"✅ [FIXED] Background location updates re-enabled after error"];
                        } else {
                            [LogHelper w:@"LocationService" message:@"⚠️ [ERROR] Cannot re-enable: notification permission not granted"];
                        }
                    });
                }];
            } else {
                self.locationManager.allowsBackgroundLocationUpdates = YES;
                [self startLocationTracking];
                self.isTracking = YES;
                [LogHelper i:@"LocationService" message:@"✅ [FIXED] Background location updates re-enabled after error (iOS 12)"];
            }
        } else {
            [LogHelper w:@"LocationService" message:[NSString stringWithFormat:@"⚠️ [ERROR] Cannot re-enable: auth=%ld, enabled=%@", 
                                                     (long)status, self.config.enabled ? @"YES" : @"NO"]];
        }
    } else if (errorCode == kCLErrorDenied) {
        // kCLErrorDenied - User denied location access
        [LogHelper e:@"LocationService" message:@"❌ [ERROR] Location access denied by user - stopping tracking"];
        if (self.config.enabled) {
            [self stop];
        }
    } else if (errorCode == kCLErrorNetwork) {
        // kCLErrorNetwork - Network error (for geocoding, etc.)
        [LogHelper e:@"LocationService" message:@"❌ [ERROR] Location network error - GPS may still work"];
        // Don't stop tracking for network errors - GPS can still work
    } else if (errorCode == kCLErrorHeadingFailure) {
        // kCLErrorHeadingFailure - Heading service unavailable
        [LogHelper w:@"LocationService" message:@"⚠️ [ERROR] Heading service unavailable - location tracking continues"];
    } else {
        // Other errors
        [LogHelper e:@"LocationService" message:[NSString stringWithFormat:@"❌ [ERROR] Unknown location error (code: %ld)", (long)errorCode]];
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    CLAuthorizationStatus status = manager.authorizationStatus;
    
    if (status == kCLAuthorizationStatusAuthorizedAlways) {
        [LogHelper d:@"LocationService" message:@"✅ Location authorization: Always"];
        
        // CRITICAL: iOS_PRECEDUR pattern - Orijinal log formatı
        // ℹ️+[LocationAuthorization run:onCancel:] status: 3
        [LogHelper i:@"LocationAuthorization" message:[NSString stringWithFormat:@"run:onCancel: status: %ld", (long)status]];
        
        // CRITICAL: iOS 13+ requires allowsBackgroundLocationUpdates to be set AFTER authorization
        // CRITICAL: Eğer config.enabled=true ise, location updates'i başlat
        if (self.config.enabled) {
            // CRITICAL: Always authorization var - background location'ı enable et
            if (self.config.foregroundService) {
                // iOS 13+ requires notification for background location updates
                if (@available(iOS 13.0, *)) {
                    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                                // Notification authorized, enable background updates
                                self.locationManager.allowsBackgroundLocationUpdates = YES;
                                [LogHelper d:@"LocationService" message:@"✅ Background location updates enabled (notification authorized)"];
                            } else {
                                [LogHelper w:@"LocationService" message:@"⚠️ Background location requires notification permission (iOS 13+)"];
                                // Still enable it, but iOS might limit it
                                self.locationManager.allowsBackgroundLocationUpdates = YES;
                            }
                            
                            // CRITICAL: Restart location updates after setting allowsBackgroundLocationUpdates
                            // Eğer zaten çalışıyorsa, restart et
                            if (self.isTracking) {
                                [self stopLocationTracking];
                            }
                            [self startLocationTracking];
                            _isTracking = YES; // Set flag
                            [LogHelper d:@"LocationService" message:@"✅ Location updates started with background permission"];
                        });
                    }];
                } else {
                    // iOS 12 and below - notification permission not required
                    self.locationManager.allowsBackgroundLocationUpdates = YES;
                    [LogHelper d:@"LocationService" message:@"✅ Background location updates enabled (iOS 12)"];
                    
                    // Restart location updates
                    if (self.isTracking) {
                        [self stopLocationTracking];
                    }
                    [self startLocationTracking];
                    _isTracking = YES; // Set flag
                    [LogHelper d:@"LocationService" message:@"✅ Location updates started with background permission"];
                }
            } else {
                // foregroundService=false ama Always authorization var
                // Yine de background location'ı enable et
                self.locationManager.allowsBackgroundLocationUpdates = YES;
                if (!self.isTracking) {
                    [self startLocationTracking];
                    _isTracking = YES; // Set flag
                }
                [LogHelper d:@"LocationService" message:@"✅ Background location enabled (foregroundService=false)"];
            }
        }
    } else if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [LogHelper w:@"LocationService" message:@"⚠️ Location authorization: When In Use (background updates disabled)"];
        self.locationManager.allowsBackgroundLocationUpdates = NO;
        
        // CRITICAL: Eğer config.enabled=true ise, foreground'da çalışmaya devam et
        if (self.config.enabled && !self.isTracking) {
            [self startLocationTracking];
            _isTracking = YES; // Set flag
            [LogHelper d:@"LocationService" message:@"✅ Location updates started (when in use)"];
        }
    } else {
        [LogHelper w:@"LocationService" message:@"⚠️ Location authorization denied"];
        self.locationManager.allowsBackgroundLocationUpdates = NO;
        // Authorization denied, stop tracking
        if (self.isTracking) {
            [self stop];
        }
    }
}

#pragma mark - CLLocationManagerDelegate

/**
 * Location manager did update locations (TSLocationManager pattern)
 * Orijinal TSLocationManager'dan: -[TSLocationManager locationManager:didUpdateLocations:]
 * 
 * Assembly pattern:
 * - isRequestingLocation = 0 set ediliyor
 * - Locations count >= 2 ise log yazılıyor
 * - Scheduler enabled kontrolü yapılıyor ve evaluate çağrılıyor
 * - Son location alınıyor (lastObject)
 * - applyDistanceFilter: kontrolü yapılıyor
 * - Eğer applyDistanceFilter false dönerse, birçok kontrol yapılıyor
 * - SOMotionDetector.sharedInstance.setLocation:isMoving: çağrılıyor
 * - enabled kontrolü yapılıyor
 * - isMoving kontrolü yapılıyor
 * - horizontalAccuracy kontrolü yapılıyor
 * - lastLocation kontrolü ve time interval kontrolü yapılıyor
 * - isMoving kontrolü ve calculateDistanceFilter: çağrılıyor
 * - queue:type: çağrılıyor
 * - isLocationTrackingMode ve startMonitoringSignificantLocationChanges kontrolü yapılıyor
 */
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    // CRITICAL: Apple Documentation - https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
    // Debug logging for background location tracking
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    
    // TRANSISTORSOFT LOG FORMAT
    [LogHelper i:@"TSTrackingService" message:[NSString stringWithFormat:@"╔═══════════════════════════════════════════════════════════\n║ -[TSTrackingService locationManager:didUpdateLocations:] Enabled: %d | isMoving: %d | df: %.1fm\n╚═══════════════════════════════════════════════════════════",
                                              self.config.enabled ? 1 : 0,
                                              self.config.isMoving ? 1 : 0,
                                              self.config.distanceFilter]];
    
    if (appState == UIApplicationStateBackground) {
        [LogHelper i:@"TSTrackingService" message:@"✅-[TSTrackingService] Background location update received"];
        
        // CRITICAL: Reddit Solution Pattern - Her location update'te background task oluştur/yenile
        // Bu, iOS'un uygulamayı suspend etmesini önler ve 3 dakikaya kadar uzatır
        // https://www.reddit.com/r/iOSProgramming/comments/1dxt84v/implementing_background_location_tracking_in_ios/
        if (self.config.enabled && self.config.preventSuspend) {
            // Background task oluştur/yenile - iOS'un suspend etmesini önler
            UIBackgroundTaskIdentifier oldTask = self.preventSuspendTask;
            
            __weak typeof(self) weakSelf = self;
            self.preventSuspendTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                
                [LogHelper w:@"LocationService" message:@"⚠️ [REDDIT-PATTERN] Background task expired, creating new one"];
                
                // Eski task'ı sonlandır
                if (oldTask != UIBackgroundTaskInvalid) {
                    [[UIApplication sharedApplication] endBackgroundTask:oldTask];
                }
                strongSelf.preventSuspendTask = UIBackgroundTaskInvalid;
                
                // Yeni task oluştur (recursion önlemek için background queue'da)
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    __strong typeof(weakSelf) strongSelf2 = weakSelf;
                    if (!strongSelf2) return;
                    
                    UIBackgroundTaskIdentifier newTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                        [[UIApplication sharedApplication] endBackgroundTask:newTask];
                    }];
                    
                    if (newTask != UIBackgroundTaskInvalid) {
                        strongSelf2.preventSuspendTask = newTask;
                        [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"✅ [REDDIT-PATTERN] New background task created: %lu", (unsigned long)newTask]];
                    }
                });
            }];
            
            // Eski task'ı sonlandır (yeni task oluşturulduysa)
            if (oldTask != UIBackgroundTaskInvalid && self.preventSuspendTask != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:oldTask];
            }
            
            if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
                NSTimeInterval bgTimeRemaining = [[UIApplication sharedApplication] backgroundTimeRemaining];
                [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"✅ [REDDIT-PATTERN] Background task refreshed: %lu (BG time: %.1fs)", 
                                                          (unsigned long)self.preventSuspendTask, bgTimeRemaining]];
            }
        }
    }
    
    // CRITICAL: Event-driven monitoring - Timer yerine location update'lerin kendisi monitoring yapıyor
    // Her location update'te son update zamanını kaydet
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    self.lastLocationUpdateTime = now;
    
    // CRITICAL: Event-driven health check - Her location update'te allowsBackgroundLocationUpdates kontrolü yap
    // Timer yerine location update'lerin kendisi health check yapıyor
    if (appState == UIApplicationStateBackground && self.config.enabled && self.config.preventSuspend) {
        // iOS sometimes disables allowsBackgroundLocationUpdates, check and re-enable if needed
        if (!self.locationManager.allowsBackgroundLocationUpdates) {
            [LogHelper w:@"LocationService" message:@"⚠️ [EVENT-DRIVEN] allowsBackgroundLocationUpdates was disabled, re-enabling..."];
            self.locationManager.allowsBackgroundLocationUpdates = YES;
            
            // If it was disabled, restart location updates to ensure they continue
            [self stopLocationTracking];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startLocationTracking];
                self.isTracking = YES;
                [LogHelper i:@"LocationService" message:@"✅ [EVENT-DRIVEN] Location updates restarted after allowsBackgroundLocationUpdates was disabled"];
            });
        }
    }
    
    // CRITICAL: iOS_PRECEDUR pattern - Auto-start location tracking if app was launched in background
    // iOS significant location change ile uygulama başlatıldığında, eğer enabled: true ise otomatik başlat
    
    // CRITICAL: Check if app was launched in background (significant location change)
    // This happens when iOS restarts the app after termination due to significant location change
    if (appState == UIApplicationStateBackground && !self.isTracking) {
        // Check if this is from significant location changes (app restart scenario)
        if (self.isMonitoringSignificantLocationChanges || !self.config.stopOnTerminate) {
            // Reload config to ensure we have the latest enabled state
            // Config might not be loaded yet when app is restarted
            [self.config load];
            
            if (self.config.enabled) {
                [LogHelper i:@"LocationService" message:@"🔄 [RESTART] App restarted in background (significant location change), auto-starting location tracking..."];
                
                // Start full location tracking (not just significant changes)
                CLAuthorizationStatus status = [self.locationManager authorizationStatus];
                [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"🔍 [RESTART] Authorization status: %ld", (long)status]];
                
                if (status == kCLAuthorizationStatusAuthorizedAlways) {
                    if (self.config.foregroundService) {
                        self.locationManager.allowsBackgroundLocationUpdates = YES;
                    }
                    
                    // Configure location manager
                    self.locationManager.desiredAccuracy = [self.config getDesiredAccuracyForCLLocationManager];
                    self.locationManager.distanceFilter = self.config.distanceFilter;
                    self.locationManager.pausesLocationUpdatesAutomatically = NO;
                    
                    // Start location updates
                    [self startLocationTracking];
                    self.isTracking = YES;
                    [LogHelper i:@"LocationService" message:@"✅ [RESTART] Location updates started"];
                    
                    // CRITICAL: Ensure allowsBackgroundLocationUpdates is enabled
                    if (!self.locationManager.allowsBackgroundLocationUpdates) {
                        [LogHelper w:@"LocationService" message:@"⚠️ [RESTART] allowsBackgroundLocationUpdates was NO, enabling..."];
                        self.locationManager.allowsBackgroundLocationUpdates = YES;
                    }
                    [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"🔍 [RESTART] allowsBackgroundLocationUpdates: %@", 
                                                              self.locationManager.allowsBackgroundLocationUpdates ? @"YES" : @"NO"]];
                    
                    // Start other services
                    if (self.config.autoSync) {
                        [[ConnectivityMonitor sharedInstance] startMonitoring];
                        [LogHelper i:@"LocationService" message:@"✅ [RESTART] Connectivity monitoring started"];
                    }
                    if (!self.config.disableMotionActivityUpdates) {
                        [ActivityRecognitionService start];
                        [LogHelper i:@"LocationService" message:@"✅ [RESTART] Activity recognition started"];
                    }
                    if (self.config.heartbeatInterval > 0) {
                        [HeartbeatService start];
                        [LogHelper i:@"LocationService" message:@"✅ [RESTART] Heartbeat service started"];
                    }
                    
                    // Setup foreground notification
                    if (self.config.foregroundService && @available(iOS 10.0, *)) {
                        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self setupForegroundNotification];
                                    [LogHelper i:@"LocationService" message:@"✅ [RESTART] Foreground notification setup"];
                                });
                            }
                        }];
                    }
                    
                    // Create background task if needed
                    if (self.config.preventSuspend) {
                        [self createBackgroundTask];
                        [LogHelper i:@"LocationService" message:@"✅ [RESTART] Background task created"];
                    }
                    
                    // CRITICAL: Timer'sız event-driven monitoring
                    // Location update'lerin kendisi monitoring yapıyor (timer yerine)
                    
                    [LogHelper i:@"LocationService" message:@"✅ [RESTART] Location tracking auto-started after background restart"];
                } else {
                    [LogHelper w:@"LocationService" message:@"⚠️ Cannot auto-start: location authorization not granted"];
                }
            } else {
                [LogHelper d:@"LocationService" message:@"ℹ️ App restarted in background but enabled=false, skipping auto-start"];
            }
        }
    }
    
    // CRITICAL: Orijinal TSLocationManager pattern - isRequestingLocation = 0
    // Assembly: self->_isRequestingLocation = 0;
    // NOT: Property kaldırılmış, skip ediyoruz
    
    // CRITICAL: Orijinal pattern - locations count >= 2 ise log yazılıyor
    // Assembly: if (locations.count >= 2) { TSLog.notify.debug... }
    if (locations.count >= 2 && self.config.debug) {
        [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"📍 Received %lu locations", (unsigned long)locations.count]];
    }
    
    // CRITICAL: Orijinal pattern - scheduler enabled kontrolü
    if (self.config.schedulerEnabled) {
        [[TSScheduler sharedInstance] evaluate];
    }
    
    // CRITICAL: Orijinal pattern - son location alınıyor
    // Assembly: location = [locations lastObject];
    CLLocation *location = [locations lastObject];
    if (!location) {
        return;
    }
    
    // CRITICAL: iOS 15+ - Log location source information for debugging
    // This helps identify if location tracking stops due to simulated locations or external GPS issues
    if (@available(iOS 15.0, *)) {
        CLLocationSourceInformation *sourceInfo = location.sourceInformation;
        if (sourceInfo && self.config.debug) {
            if (sourceInfo.isSimulatedBySoftware) {
                [LogHelper d:@"LocationService" message:@"📍 [SOURCE] Location is simulated by software (test/simulator)"];
            }
            if (sourceInfo.isProducedByAccessory) {
                [LogHelper d:@"LocationService" message:@"📍 [SOURCE] Location from external GPS accessory"];
            }
        }
    }
    
    // CRITICAL: Orijinal pattern - enabled kontrolü
    // Assembly: if (!config.enabled) { return; }
    if (!self.config.enabled) {
        return;
    }
    
    // CRITICAL: Orijinal pattern - horizontalAccuracy kontrolü
    // Assembly: if (location.horizontalAccuracy < 0.0) { return; }
    if (location.horizontalAccuracy < 0.0) {
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"⚠️ Invalid horizontal accuracy: %.1fm", location.horizontalAccuracy]];
        }
        return;
    }
    
    // CRITICAL: Orijinal pattern - applyDistanceFilter kontrolü
    // Assembly: if (![self applyDistanceFilter:location]) { return; }
    // FIX: shouldProcess kontrolü yapılıyordu ama kullanılmıyordu - sabit konumda sürekli event geliyordu
    // Şimdi distanceFilter kontrolü geçmezse location'ı işleme
    if (self.lastLocation && self.config.distanceFilter > 0) {
        CLLocationDistance distance = [self.lastLocation distanceFromLocation:location];
        if (distance < self.config.distanceFilter) {
            // Distance filter'ı geçmedi - location'ı işleme
            // Ama lastLocation'ı güncelle (motion detection için gerekli olabilir)
            // NOT: lastLocation güncellemesi handleLocationUpdate içinde yapılıyor, bu yüzden burada güncellemeye gerek yok
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"⏸️ Distance filter: skipping location (distance=%.1fm < %.1fm)", 
                                                         distance, self.config.distanceFilter]];
            }
            return; // CRITICAL: Location'ı işleme, distanceFilter'ı geçmedi
        }
    }
    
    // CRITICAL: Orijinal pattern - SOMotionDetector.sharedInstance.setLocation:isMoving:
    // Assembly: [SOMotionDetector.sharedInstance setLocation:location isMoving:config.isMoving];
    if ([MotionDetectorService motionHardwareAvailable]) {
        MotionDetectorService *motionDetector = [MotionDetectorService sharedInstance];
        [motionDetector setLocation:location isMoving:self.config.isMoving];
    }
    
    // CRITICAL: Orijinal pattern - queue:type: çağrılıyor
    // Assembly: [self queue:location type:type];
    // handleLocationUpdate ile aynı işlevi görüyor
    [self handleLocationUpdate:location];
    
    // CRITICAL: Orijinal pattern - isLocationTrackingMode ve startMonitoringSignificantLocationChanges
    // Assembly: if (isLocationTrackingMode && !isMonitoringSignificantLocationChanges) { startMonitoringSignificantLocationChanges(); }
    // NOT: Property'ler kaldırılmış, skip ediyoruz
}

#pragma mark - Location Handling

- (void)handleLocationUpdate:(CLLocation *)location {
    if (location == nil) {
        return;
    }
    
    // CRITICAL: Sadece enabled=true iken location'ları işle
    // Bu, start() çağrılmadan önce gelen location update'lerini engeller
    if (!self.config.enabled) {
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:@"⏸️ Location update ignored (enabled=false)"];
        }
        return;
    }
    
    // TRANISTORSOFT PATTERN: stopAfterElapsedMinutes kontrolü
    // Her location update'te kontrol et (daha güvenilir: app suspend olsa bile çalışır)
    if (self.config.stopAfterElapsedMinutes > 0 && self.trackingStartTime > 0) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval elapsed = now - self.trackingStartTime;
        NSTimeInterval maxElapsed = self.config.stopAfterElapsedMinutes * 60.0;
        
        if (elapsed >= maxElapsed) {
            [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"⏰ stopAfterElapsedMinutes expired (%.1f min elapsed), stopping service", elapsed / 60.0]];
            
            // Stop service
            [self stop];
            
            self.config.enabled = NO;
            [self.config save];
            // CRITICAL: notifyOnChange çağırma - onChange:@"enabled" callback'i zaten onEnabledChangeCallback'i çağırıyor
            // notifyOnChange çağrısı duplicate event'e sebep oluyor
            // Bunun yerine direkt EnabledChangeEvent oluşturup onEnabledChangeCallback'i çağırıyoruz
            
            // CRITICAL: onChange:@"enabled" callback'i sadece notifyOnChange çağrıldığında tetikleniyor
            // notifyOnChange çağrısını kaldırdığımız için, direkt EnabledChangeEvent oluşturup onEnabledChangeCallback'i çağırmalıyız
            // CRITICAL: Main queue'da çağır ki UI hemen güncellensin
            EnabledChangeEvent *event = [[EnabledChangeEvent alloc] initWithEnabled:NO];
            if (self.onEnabledChangeCallback) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.onEnabledChangeCallback) {
                        self.onEnabledChangeCallback(event);
                    }
                });
            }
            
            return; // Bu location'ı işleme, zaten stop ettik
        }
    }
    
    // CRITICAL: Update MotionDetectorService with location and isMoving (SOMotionDetector pattern)
    // Orijinal SOMotionDetector her location update'te setLocation:isMoving: çağırıyor
    if ([MotionDetectorService motionHardwareAvailable]) {
        MotionDetectorService *motionDetector = [MotionDetectorService sharedInstance];
        [motionDetector setLocation:location isMoving:self.config.isMoving];
    }
    
    // Log location update (debug mode) - TRANSISTORSOFT FORMAT
    if (self.config.debug) {
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:location.timestamp] * 1000.0; // ms
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"dd.MM.yyyy, HH:mm:ss"];
        [formatter setTimeZone:[NSTimeZone localTimeZone]];
        NSString *timeStr = [formatter stringFromDate:location.timestamp];
        NSString *tzStr = [[NSTimeZone localTimeZone] abbreviation];
        
        // TRANSISTORSOFT LOG FORMAT: 📍<+lat,+lon> +/- Xm (speed X mps / course X) @ time | age: X ms
        [LogHelper d:@"TSTrackingService" message:[NSString stringWithFormat:@"📍<%+.8f,%+.8f> +/- %.2fm (speed %.2f mps / course %.2f) @ %@ %@ | age: %.0f ms",
                                                 location.coordinate.latitude,
                                                 location.coordinate.longitude,
                                                 location.horizontalAccuracy,
                                                 location.speed,
                                                 location.course,
                                                 timeStr,
                                                 tzStr,
                                                 age]];
    }
    
    // CRITICAL: Speed-based motion detection (iOS'ta activity recognition gecikebilir)
    // Eğer speed yüksekse (> 0.5 m/s), otomatik olarak isMoving=true yap
    float speed = location.speed; // m/s
    if (speed > 0.5f && !self.config.isMoving) {
        // Speed yüksek ama isMoving=false - otomatik olarak isMoving=true yap
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"🏃 Speed-based motion detection: speed=%.2f m/s > 0.5 m/s, setting isMoving=true", speed]];
        }
        self.config.isMoving = YES;
        [self.config save];
        self.stationaryLocation = nil; // Reset stationary location
    } else if (speed <= 0.5f && self.config.isMoving) {
        // Speed düşük ama isMoving=true - stationary radius kontrolü yap
        // (Aşağıdaki stationary radius check'i yapacak)
    }
    
    // STATIONARY RADIUS CHECK ()
    // stationaryLocation sadece isMoving=false olduğunda set edilir (stoppedAt location)
    // Eğer stationaryRadius dışına çıkılırsa, isMoving=true yapılır
    
    // Minimum stationaryRadius 25 metre ()
    CLLocationDistance stationaryRadius = self.config.stationaryRadius;
    if (stationaryRadius < 25.0) {
        stationaryRadius = 25.0;
    }
    
    // Eğer isMoving=false ise ve stationaryLocation yoksa, şu anki konumu referans noktası olarak kaydet
    if (!self.config.isMoving && self.stationaryLocation == nil) {
        self.stationaryLocation = location;
        if (self.config.debug) {
            [LogHelper d:@"TSTrackingService" message:[NSString stringWithFormat:@"🎯-[TSTrackingService] Stationary: stoppedAt location set (%.6f,%.6f)", 
                                                     location.coordinate.latitude,
                                                     location.coordinate.longitude]];
        }
        
        // TRANSISTORSOFT PATTERN: Stationary region monitoring başlat
        // Radius: stationaryRadius * 6 (default 150m = 25 * 6)
        CLLocationDistance regionRadius = stationaryRadius * 6.0;
        if (regionRadius < 150.0) regionRadius = 150.0;
        [self startMonitoringStationaryRegion:location radius:regionRadius];
    }
    
    // Eğer stationaryLocation varsa ve isMoving=false ise, distance kontrolü yap
    if (self.stationaryLocation != nil && !self.config.isMoving) {
        // : distance = (distanceTo - stationaryLocation.accuracy) - location.accuracy
        CLLocationDistance rawDistance = [self.stationaryLocation distanceFromLocation:location];
        CLLocationDistance netDistance = (rawDistance - self.stationaryLocation.horizontalAccuracy) - location.horizontalAccuracy;
        
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"🎯 Stationary check: rawDistance=%.1fm, netDistance=%.1fm, radius=%.1fm", 
                                                     rawDistance,
                                                     netDistance,
                                                     stationaryRadius]];
        }
        
        // Eğer stationaryRadius dışına çıkıldıysa, isMoving=true yap (changePace)
        if (netDistance > stationaryRadius) {
            // TRANSISTORSOFT LOG FORMAT
            [LogHelper i:@"TSTrackingService" message:[NSString stringWithFormat:@"🟢-[TSTrackingService changePace:] isMoving: 1 | netDistance: %.1fm > radius: %.1fm", 
                                                       netDistance, stationaryRadius]];
            
            // Change pace: isMoving = true
            self.config.isMoving = YES;
            [self.config save];
            
            // Reset stationary location
            self.stationaryLocation = nil;
            
            // TRANSISTORSOFT PATTERN: Stationary region monitoring'i durdur (kullanıcı hareket ediyor)
            [self stopMonitoringStationaryRegion];
            
            // MotionChangeEvent gönder (ActivityRecognitionService'te de gönderiliyor ama burada da göndermek iyi)
            NSDictionary *locationJson = @{
                @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000),
                @"is_moving": @(YES),
                @"latitude": @(location.coordinate.latitude),
                @"longitude": @(location.coordinate.longitude),
                @"accuracy": @(location.horizontalAccuracy)
            };
            
            // MotionChangeEvent callback'i varsa çağır (ActivityRecognitionService'ten geliyor)
            // Burada sadece log, asıl event ActivityRecognitionService'ten geliyor
        }
    }
    
    // Eğer isMoving=true olduysa, stationaryLocation'ı reset et
    if (self.config.isMoving && self.stationaryLocation != nil) {
        self.stationaryLocation = nil;
    }
    
    // Calculate distance
    if (self.lastLocation != nil) {
        CLLocationDistance distance = [self.lastLocation distanceFromLocation:location] / 1000.0; // Convert to km
        
        // Filter out unrealistic movements
        if (distance < 1.0) { // Less than 1km
            self.totalDistance += distance;
            self.config.odometer = self.totalDistance;
            [self.config save];
        }
    }
    
    self.lastLocation = location;
    
    // Ortak zaman damgası
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    // TRANISTORSOFT PATTERN: Location Type belirleme
    // Her location update için type belirle (TRACKING, MOTIONCHANGE, SAMPLE, etc.)
    LocationType locationType = LOCATION_TYPE_TRACKING; // Default
    NSString *eventName = @"location"; // Default
    
    // Motion change detection (isMoving değişti mi?)
    BOOL motionChanged = (self.lastIsMovingState != self.config.isMoving);
    if (motionChanged) {
        locationType = LOCATION_TYPE_MOTIONCHANGE;
        eventName = @"motionchange";
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"🔄 Motion change detected: %@ → %@", 
                                                     self.lastIsMovingState ? @"MOVING" : @"STATIONARY",
                                                     self.config.isMoving ? @"MOVING" : @"STATIONARY"]];
        }
        self.lastIsMovingState = self.config.isMoving;
    }
    
    // Stationary durumda ve distanceFilter kontrolü geçmediyse SAMPLE type
    // (Transistorsoft: SAMPLE type'ları persist etmez, sadece iç hesaplama için kullanır)
    BOOL isSample = NO;
    if (!self.config.isMoving && !motionChanged) {
        // Son persist edilen konumla mesafe kontrolü
        if (self.lastPersistedLocation != nil) {
            CLLocationDistance distance = [self.lastPersistedLocation distanceFromLocation:location];
            if (distance < self.config.distanceFilter) {
                isSample = YES;
                locationType = LOCATION_TYPE_SAMPLE;
                if (self.config.debug) {
                    [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"📊 SAMPLE: distance (%.1fm) < distanceFilter (%.1fm)", 
                                                             distance, self.config.distanceFilter]];
                }
            }
        }
    }
    
    // STATIONARY THROTTLE (EVENT): Eğer isMoving=false ise, event'leri throttle et
    // Bu, GPS'in sürekli küçük değişiklikler algılaması nedeniyle gereklidir
    BOOL shouldEmitEvent = YES;
    if (!self.config.isMoving) {
        // İlk event'i her zaman gönder (lastStationaryEventTime == 0 ise)
        if (self.lastStationaryEventTime > 0) {
            NSTimeInterval timeSinceLastEvent = now - self.lastStationaryEventTime;
            
            // Stationary durumda minimum 60 saniye aralıkla event gönder (heartbeatInterval benzeri)
            // Bu, gereksiz location event'lerini azaltır
            NSTimeInterval minStationaryInterval = MAX(self.config.heartbeatInterval, 60.0); // En az 60 saniye
            
            if (timeSinceLastEvent < minStationaryInterval) {
                shouldEmitEvent = NO;
                if (self.config.debug) {
                    [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"⏸️ Stationary throttle: skipping event (%.1fs < %.1fs)", 
                                                             timeSinceLastEvent, minStationaryInterval]];
                }
            } else {
                // Event gönderilecek, zamanı kaydet
                self.lastStationaryEventTime = now;
            }
        } else {
            // İlk event - zamanı kaydet ama event'i gönder
            self.lastStationaryEventTime = now;
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:@"📍 First stationary event (throttle starts now)"];
            }
        }
    } else {
        // Moving durumda her zaman event gönder ve throttle timer'ı resetle
        self.lastStationaryEventTime = 0; // Reset throttle timer
    }
    
    // TRANISTORSOFT PATTERN: Persist kararı type'a göre
    // SAMPLE type'ları HİÇ persist etme ()
    BOOL shouldPersist = YES;
    
    if (locationType == LOCATION_TYPE_SAMPLE) {
        shouldPersist = NO;
        if (self.config.debug) {
            [LogHelper d:@"LocationService" message:@"📊 SAMPLE type: skipping persist ()"];
        }
    }
    
    // 1) allowIdenticalLocations = NO ise, son persist edilen konumla karşılaştır
    if (!self.config.allowIdenticalLocations && self.lastPersistedLocation != nil) {
        CLLocationDistance diffMeters = [self.lastPersistedLocation distanceFromLocation:location];
        
        // Çok küçük sapmaları (örneğin < 1m) ve hız farkı çok az olanları aynı kabul et
        CLLocationSpeed prevSpeed = self.lastPersistedLocation.speed;
        CLLocationSpeed currSpeed = location.speed;
        CLLocationDirection prevHeading = self.lastPersistedLocation.course;
        CLLocationDirection currHeading = location.course;
        
        BOOL speedClose = fabs(prevSpeed - currSpeed) < 0.3; // m/s
        BOOL headingClose = fabs(prevHeading - currHeading) < 5.0; // derece
        
        if (diffMeters < 1.0 && speedClose && headingClose) {
            shouldPersist = NO;
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"⏸️ Dedupe: identical location skipped (Δ=%.2fm)", diffMeters]];
            }
        }
    }
    
    // 2) Stationary durumda persist'i de throttle et ( davranış)
    if (shouldPersist && !self.config.isMoving && self.lastPersistedTime > 0) {
        NSTimeInterval timeSinceLastPersist = now - self.lastPersistedTime;
        NSTimeInterval minPersistInterval = MAX(self.config.heartbeatInterval, 60.0); // En az 60 saniye
        
        if (timeSinceLastPersist < minPersistInterval) {
            shouldPersist = NO;
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"⏸️ Stationary persist throttle: skipped (%.1fs < %.1fs)", 
                                                         timeSinceLastPersist, minPersistInterval]];
            }
        }
    }
    
    // Create location model with type
    LocationModel *locationModel = [self createLocationModel:location];
    locationModel.locationType = locationType;
    locationModel.event = eventName;
    
    // CRITICAL: Save to SQLite database (as BLOB) - ALWAYS persist if shouldPersist=true
    // This happens REGARDLESS of internet connection - locations are queued for later sync
    // Internet bağlantısından BAĞIMSIZ olarak konumlar SQLite'a kaydediliyor
    NSString *uuid = nil;
    if (shouldPersist) {
        NSDictionary *jsonDict = [locationModel toDictionary];
        uuid = [self.database persist:jsonDict];
        if (uuid != nil) {
            self.lastPersistedLocation = location;
            self.lastPersistedTime = now;
            
            // CRITICAL: Event-driven monitoring - Timer yerine location update'lerin kendisi monitoring yapıyor
            // Her location update'te son update zamanını kaydet ve kontrol et
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            self.lastLocationUpdateTime = now;
            self.lastLocation = location;
            
            // CRITICAL: Eğer son update'ten bu yana çok uzun süre geçtiyse (30 saniye), restart et
            // Bu timer yerine event-driven bir yaklaşım - sadece location update geldiğinde kontrol ediyoruz
            if (self.config.preventSuspend && self.lastLocationUpdateTime > 0) {
                NSTimeInterval timeSinceLastUpdate = now - self.lastLocationUpdateTime;
                // Eğer son update'ten bu yana 30 saniyeden fazla geçtiyse, muhtemelen durmuş
                // Ama bu kontrol sadece location update geldiğinde yapılıyor, bu yüzden mantıklı değil
                // Bunun yerine, her location update'te allowsBackgroundLocationUpdates kontrolü yapalım
            }
            
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"💾 Location persisted to SQLite (uuid: %@) - will sync when internet available", uuid]];
            }
        } else {
            [LogHelper e:@"LocationService" message:@"❌ Failed to persist location to SQLite"];
        }
    }
    
    // CRITICAL: Background location tracking health check after each location update
    // Apple Documentation: iOS may stop location updates in background, so we check after each update
    // Verify allowsBackgroundLocationUpdates is still enabled after each update
    UIApplicationState currentAppState = [[UIApplication sharedApplication] applicationState];
    if (currentAppState == UIApplicationStateBackground && self.config.enabled) {
        // CRITICAL: Verify allowsBackgroundLocationUpdates is still enabled after each update
        // iOS sometimes resets this property, especially after a few updates
        if (!self.locationManager.allowsBackgroundLocationUpdates) {
            [LogHelper w:@"LocationService" message:@"⚠️ [CRITICAL] allowsBackgroundLocationUpdates was disabled after location update, re-enabling..."];
            self.locationManager.allowsBackgroundLocationUpdates = YES;
            
            // CRITICAL: Apple Documentation - startUpdatingLocation() background'dayken çağrılırsa iOS durdurabilir
            // Bu yüzden restart etmek yerine, sadece allowsBackgroundLocationUpdates set ediyoruz
            // Eğer location updates durmuşsa, bir sonraki location update'te otomatik olarak kontrol edilecek
            [LogHelper i:@"LocationService" message:@"✅ [FIXED] allowsBackgroundLocationUpdates re-enabled, location updates should continue"];
        }
        
        // CRITICAL: Location tracking'in aktif olduğundan emin ol
        // Eğer isTracking=false ise, bir sorun var demektir
        if (!self.isTracking) {
            [LogHelper w:@"LocationService" message:@"⚠️ [CRITICAL] Location update received but isTracking=false, this should not happen!"];
            // Background'dayken restart etmek yerine, sadece flag'i set et
            // Foreground'a dönünce otomatik olarak restart edilecek
            _isTracking = YES;
        }
        
    }
    
    BOOL didPersistAndEmit = (uuid != nil && shouldEmitEvent);
    
    if (didPersistAndEmit) {
        // Emit event (Android EventBus yerine callback)
        // CRITICAL: Memory leak prevention - Event'i autorelease pool içinde oluştur
        // Bu, event'in hemen release edilmesini sağlar
        @autoreleasepool {
            LocationEvent *event = [[LocationEvent alloc] initWithLocation:locationModel];
            if (self.onLocationCallback) {
                self.onLocationCallback(event);
            }
            // Event autorelease pool'dan çıkınca otomatik release edilecek
        }
        
        // Debug notification for location update – throttle: en fazla 10 saniyede bir
        if (self.config.debug) {
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            if (now - self.lastDebugLocationNotificationTime >= 10.0) {
                self.lastDebugLocationNotificationTime = now;
                NSString *activity = @"unknown";
                CMMotionActivity *lastActivity = [ActivityRecognitionService getLastActivity];
                if (lastActivity) {
                    activity = [self getActivityName:lastActivity];
                }
                MotionDetectorService *motionDetector = [MotionDetectorService sharedInstance];
                NSString *motionTypeInfo = @"";
                if (motionDetector.motionTypeName && motionDetector.motionTypeName.length > 0) {
                    NSInteger confidence = [motionDetector motionActivityConfidence];
                    motionTypeInfo = [NSString stringWithFormat:@" | 🎯 Motion: %@ (%ld%%)", motionDetector.motionTypeName, (long)confidence];
                }
                NSString *debugBody = [NSString stringWithFormat:@"📍 %.6f,%.6f\n🎯 Accuracy: %.1fm | 🚶 %@%@ | 📏 Odometer: %.2f km",
                                       location.coordinate.latitude,
                                       location.coordinate.longitude,
                                       location.horizontalAccuracy,
                                       activity,
                                       motionTypeInfo,
                                       self.config.odometer];
                [self showDebugNotification:@"📍 Location Update" body:debugBody];
            }
        }
        
    }
    
    // Check auto sync () - Her zaman kontrol et (event göndermesek bile)
    // CRITICAL: Only sync if tracking is enabled
    if (self.config.enabled && self.config.autoSync && self.config.url.length > 0) {
        NSInteger unlockedCount = [self.database countOnlyUnlocked:YES];
        
        if (self.config.autoSyncThreshold <= 0 || unlockedCount >= self.config.autoSyncThreshold) {
            [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"🔄 AutoSync triggered: %ld >= %ld", (long)unlockedCount, (long)self.config.autoSyncThreshold]];
            [[SyncService sharedInstance] sync];
        }
    }
    
    // Update notification if foreground service is enabled
    // CRITICAL: iOS'ta foreground notification sadece background'da gösterilir
    // Foreground'da notification gösterilmez (iOS'un normal davranışı)
    // CRITICAL: debug=false ise bildirim gösterilmemeli (kullanıcı isteği)
    // CRITICAL: debug=true ise her event değişikliğinde bildirim gösterilmeli (throttle yok)
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    if (self.config.foregroundService && self.config.debug && shouldEmitEvent && appState == UIApplicationStateBackground) {
        // CRITICAL: Debug modda her event değişikliğinde bildirim göster
        // Throttle yok - her önemli event (location update, motion change, activity change) bildirim gösterir
        [self updateForegroundNotification];
    }
    // CRITICAL: Normal modda (debug=false) bildirim gösterilmemeli
    // Kullanıcı debug=false ise hiç bildirim görmek istemiyor
    
    // Clean old records
    [self cleanOldRecords];
}

- (LocationModel *)createLocationModel:(CLLocation *)location {
    LocationModel *model = [[LocationModel alloc] initWithCLLocation:location];
    
    model.isMoving = self.config.isMoving;
    model.odometer = self.config.odometer;
    
    // Battery info (iOS)
    UIDevice *device = [UIDevice currentDevice];
    device.batteryMonitoringEnabled = YES;
    model.batteryLevel = device.batteryLevel;
    model.batteryIsCharging = (device.batteryState == UIDeviceBatteryStateCharging || 
                               device.batteryState == UIDeviceBatteryStateFull);
    
    // CRITICAL: Get activity info from ActivityRecognitionService (Android pattern)
    // iOS CoreMotion CMMotionActivity kullanarak activity recognition
    CMMotionActivity *lastActivity = [ActivityRecognitionService getLastActivity];
    if (lastActivity) {
        // Get activity type from CoreMotion
        NSString *activityType = [self getActivityTypeFromMotionActivity:lastActivity];
        NSInteger confidence = [self getConfidenceFromMotionActivity:lastActivity];
        
        // CRITICAL: Fallback check - if speed is high but activity is STILL, use speed-based detection
        // This handles cases where activity recognition hasn't updated yet or isn't working
        float speed = location.speed; // m/s
        if ([activityType isEqualToString:@"still"] && speed > 0.5f) {
            // Activity is STILL but speed > 0.5 m/s - use speed-based detection
            activityType = [self getActivityFromSpeed:speed];
            confidence = 75; // Lower confidence since we're using fallback
            [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"📍 Activity: %@ (speed-based fallback: %.2f m/s)", activityType, speed]];
        } else {
            [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"📍 Activity: %@ (confidence: %ld)", activityType, (long)confidence]];
        }
        
        model.activityType = activityType;
        model.activityConfidence = confidence;
    } else {
        // Fallback: Use speed to determine activity (detailed detection)
        float speed = location.speed; // m/s
        NSString *activityType = [self getActivityFromSpeed:speed];
        model.activityType = activityType;
        model.activityConfidence = 50; // Lower confidence for speed-based detection
        [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"📍 Activity: %@ (speed-based: %.2f m/s)", activityType, speed]];
    }
    
    // Extras from config ()
    NSDictionary *extrasDict = [self.config getExtrasDictionary];
    if (extrasDict && extrasDict.count > 0) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extrasDict options:0 error:&error];
        if (!error) {
            model.extras = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    }
    
    return model;
}

- (void)cleanOldRecords {
    @try {
        // Prune: Remove records older than maxDaysToPersist
        if (self.config.maxDaysToPersist > 0) {
            [self.database prune:self.config.maxDaysToPersist];
        }
        
        // Shrink: Limit to maxRecordsToPersist
        if (self.config.maxRecordsToPersist > 0) {
            NSInteger count = [self.database count];
            if (count > self.config.maxRecordsToPersist) {
                [self.database shrink:self.config.maxRecordsToPersist];
            }
        }
    } @catch (NSException *exception) {
        [LogHelper e:@"LocationService" message:[NSString stringWithFormat:@"❌ Error cleaning old records: %@", exception.reason]];
    }
}

#pragma mark - Foreground Notification

- (void)setupForegroundNotification {
    // CRITICAL: debug=false ise bildirim setup edilmemeli
    if (!self.config.debug) {
        return;
    }
    
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"BackgroundLocation"
                                                                              content:[self createNotificationContent]
                                                                              trigger:nil];
        
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                [LogHelper e:@"LocationService" message:@"Failed to setup notification" error:error];
            }
        }];
    }
}

- (UNNotificationContent *)createNotificationContent API_AVAILABLE(ios(10.0)) {
    // Orijinal Transistorsoft field isimleri (title, text)
    NSString *title = self.config.title;
    NSString *text = self.config.text;
    
    // Debug modda ek bilgiler ekle
    if (self.config.debug) {
        NSInteger locationCount = [self.database count];
        NSInteger unlockedCount = [self.database countOnlyUnlocked:YES];
        NSString *activity = @"unknown";
        
        // Activity bilgisini al
        CMMotionActivity *lastActivity = [ActivityRecognitionService getLastActivity];
        if (lastActivity) {
            activity = [self getActivityName:lastActivity];
        }
        
        // Son location bilgisi
        NSString *locationInfo = @"N/A";
        if (self.lastLocation) {
            locationInfo = [NSString stringWithFormat:@"%.6f,%.6f", 
                           self.lastLocation.coordinate.latitude,
                           self.lastLocation.coordinate.longitude];
        }
        
        // Sync durumu
        NSString *syncStatus = self.config.autoSync ? @"ON" : @"OFF";
        NSString *syncInfo = @"";
        if (self.config.autoSync && self.config.url.length > 0) {
            syncInfo = [NSString stringWithFormat:@" | 🔄 Sync: %@ (%ld/%ld)", 
                       syncStatus, (long)unlockedCount, (long)self.config.autoSyncThreshold];
        }
        
        // Tracking süresi
        NSTimeInterval elapsed = 0;
        if (self.trackingStartTime > 0) {
            elapsed = [[NSDate date] timeIntervalSince1970] - self.trackingStartTime;
        }
        NSInteger minutes = (NSInteger)(elapsed / 60);
        NSInteger seconds = (NSInteger)(elapsed) % 60;
        
        // Debug bilgilerini text'e ekle (daha detaylı)
        text = [NSString stringWithFormat:@"%@\n📍 Loc: %ld | 🔓 Unlocked: %ld | 🚶 %@\n📏 Odometer: %.2f km | ⏱️ %ldm %lds\n🌍 %@%@",
                self.config.notificationText,
                (long)locationCount,
                (long)unlockedCount,
                activity,
                self.config.odometer,
                (long)minutes,
                (long)seconds,
                locationInfo,
                syncInfo];
    }
    
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = text;
    content.sound = nil; // Silent notification
    content.categoryIdentifier = @"BACKGROUND_LOCATION";
    
    // Debug modda badge ekle
    if (self.config.debug) {
        NSInteger locationCount = [self.database count];
        content.badge = @(locationCount);
    }
    
    return content;
}

- (void)updateForegroundNotification {
    // CRITICAL: debug=false ise bildirim güncellenmemeli
    if (!self.config.debug) {
        return;
    }
    
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        
        // Check authorization status
        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"BackgroundLocation"
                                                                                      content:[self createNotificationContent]
                                                                                      trigger:nil];
                
                [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        [LogHelper e:@"LocationService" message:[NSString stringWithFormat:@"❌ Failed to update notification: %@", error.localizedDescription] error:error];
                    } else {
                        // CRITICAL: Only log in debug mode to avoid spam
                        // Notification will be shown by UNUserNotificationCenterDelegate in RNBackgroundLocation
                        if (self.config.debug) {
                            [LogHelper d:@"LocationService" message:@"✅ Notification updated"];
                        }
                    }
                }];
            } else {
                [LogHelper w:@"LocationService" message:@"⚠️ Notification not authorized, cannot update"];
            }
        }];
    }
}

#pragma mark - Debug Notifications (Transistorsoft Pattern)

- (void)showDebugNotification:(NSString *)title body:(NSString *)body {
    if (!self.config.debug) {
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
                content.badge = @([self.database count]);
                
                // Sabit ID: aynı başlık = aynı bildirim güncellenir, yığılma olmaz
                NSString *safeTitle = [title stringByReplacingOccurrencesOfString:@" " withString:@"_"];
                safeTitle = [[safeTitle componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
                if (safeTitle.length == 0) { safeTitle = @"Debug"; }
                NSString *identifier = [NSString stringWithFormat:@"DebugNotification_%@", safeTitle];
                
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                                      content:content
                                                                                      trigger:nil];
                
                [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        [LogHelper e:@"LocationService" message:[NSString stringWithFormat:@"❌ Failed to show debug notification: %@", error.localizedDescription] error:error];
                    } else {
                        [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"🔔 Debug notification: %@", title]];
                    }
                }];
            }
        }];
    }
}

- (NSString *)getActivityName:(CMMotionActivity *)activity {
    // Debug notification için emoji'li versiyon
    NSString *activityType = [self getActivityTypeFromMotionActivity:activity];
    if ([activityType isEqualToString:@"in_vehicle"]) {
        return @"🚗 Vehicle";
    } else if ([activityType isEqualToString:@"on_bicycle"]) {
        return @"🚴 Bicycle";
    } else if ([activityType isEqualToString:@"running"]) {
        return @"🏃 Running";
    } else if ([activityType isEqualToString:@"walking"]) {
        return @"🚶 Walking";
    } else if ([activityType isEqualToString:@"still"]) {
        return @"🛑 Still";
    } else {
        return @"❓ Unknown";
    }
}

/**
 * Get activity type from CMMotionActivity (Android getActivityName pattern)
 * Returns: "in_vehicle", "on_bicycle", "running", "walking", "still", "unknown"
 */
- (NSString *)getActivityTypeFromMotionActivity:(CMMotionActivity *)activity {
    // CoreMotion can have multiple flags true at once
    // Priority: automotive > cycling > running > walking > stationary > unknown
    // This matches Android's DetectedActivity pattern
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

/**
 * Get confidence from CMMotionActivity
 * CMMotionActivity provides confidence levels: Low, Medium, High
 */
- (NSInteger)getConfidenceFromMotionActivity:(CMMotionActivity *)activity {
    if (activity.confidence == CMMotionActivityConfidenceHigh) {
        return 100;
    } else if (activity.confidence == CMMotionActivityConfidenceMedium) {
        return 70;
    } else {
        return 50;
    }
}

/**
 * Get activity type from speed (fallback when activity recognition is not available)
 * Speed thresholds based on typical human/vehicle speeds (Android pattern):
 * - > 15 m/s (54 km/h) → in_vehicle (car/motorcycle)
 * - 5-15 m/s (18-54 km/h) → on_bicycle (bicycle)
 * - 2-5 m/s (7.2-18 km/h) → running (running)
 * - 0.5-2 m/s (1.8-7.2 km/h) → walking (walking)
 * - < 0.5 m/s → still (stationary)
 */
- (NSString *)getActivityFromSpeed:(float)speed {
    if (speed > 15.0f) {
        // Speed > 15 m/s (54 km/h) - likely in vehicle
        return @"in_vehicle";
    } else if (speed > 5.0f) {
        // Speed 5-15 m/s (18-54 km/h) - likely on bicycle
        return @"on_bicycle";
    } else if (speed > 2.0f) {
        // Speed 2-5 m/s (7.2-18 km/h) - likely running
        return @"running";
    } else if (speed > 0.5f) {
        // Speed 0.5-2 m/s (1.8-7.2 km/h) - likely walking
        return @"walking";
    } else {
        // Speed < 0.5 m/s - stationary
        return @"still";
    }
}

#pragma mark - Power Save Mode (iOS)

- (BOOL)isPowerSaveMode {
    if (@available(iOS 9.0, *)) {
        return [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    }
    return NO;
}

- (void)startPowerSaveMonitoring {
    if (@available(iOS 9.0, *)) {
        // Listen for Low Power Mode changes
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didChangePowerMode:)
                                                     name:NSProcessInfoPowerStateDidChangeNotification
                                                   object:nil];
        
        // Check initial state
        BOOL isPowerSaveMode = [self isPowerSaveMode];
        [self firePowerSaveChangeEvent:isPowerSaveMode];
    }
}

/**
 * Power save mode changed (TSLocationManager pattern)
 * Orijinal TSLocationManager'dan: -[TSLocationManager didChangePowerMode:]
 * 
 * Assembly pattern:
 * - isPowerSaveMode: kontrolü yapılıyor
 * - Power save mode durumuna göre log yazılıyor
 * - TSPowerSaveChangeEvent oluşturuluyor (new ile)
 * - TSQueue.sharedInstance.runOnMainQueueWithoutDeadlocking: ile bir block çağrılıyor
 * - Block içinde event callback'i çağrılıyor
 */
- (void)didChangePowerMode:(NSNotification *)notification {
    // CRITICAL: Orijinal TSLocationManager pattern - isPowerSaveMode kontrolü
    // Assembly: v3 = [self isPowerSaveMode:notification];
    BOOL isPowerSaveMode = [self isPowerSaveMode];
    
    // CRITICAL: Orijinal pattern - power save mode durumuna göre log yazılıyor
    // Assembly: if (isPowerSaveMode) { DDLog.debug... } else { DDLog.debug... }
    if (self.config.debug) {
        if (isPowerSaveMode) {
            [LogHelper d:@"LocationService" message:@"🔋 Power Save Mode: ON"];
        } else {
            [LogHelper d:@"LocationService" message:@"🔋 Power Save Mode: OFF"];
        }
    }
    
    // CRITICAL: Orijinal pattern - TSPowerSaveChangeEvent oluşturuluyor
    // Assembly: event = [TSPowerSaveChangeEvent new];
    TSPowerSaveChangeEvent *event = [[TSPowerSaveChangeEvent alloc] initWithIsPowerSaveMode:isPowerSaveMode];
    
    // CRITICAL: Orijinal pattern - TSQueue.sharedInstance.runOnMainQueueWithoutDeadlocking: ile bir block çağrılıyor
    // Assembly: [TSQueue.sharedInstance runOnMainQueueWithoutDeadlocking:block];
    // TSQueue yok, bu yüzden dispatch_async(dispatch_get_main_queue(), ...) kullanıyoruz
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        // CRITICAL: Orijinal pattern - event callback'i çağrılıyor
        // Assembly: block içinde event fire ediliyor
        if (strongSelf.onPowerSaveChangeCallback) {
            strongSelf.onPowerSaveChangeCallback(event);
        }
    });
}

- (void)firePowerSaveChangeEvent:(BOOL)isPowerSaveMode {
    TSPowerSaveChangeEvent *event = [[TSPowerSaveChangeEvent alloc] initWithIsPowerSaveMode:isPowerSaveMode];
    
    if (self.onPowerSaveChangeCallback) {
        self.onPowerSaveChangeCallback(event);
    }
    
    [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"🔋 Power Save Mode: %@", isPowerSaveMode ? @"ON" : @"OFF"]];
}

/**
 * Heartbeat event (TSLocationManager pattern)
 * Orijinal TSLocationManager'dan: -[TSLocationManager onHeartbeat]
 * 
 * Assembly pattern:
 * - Debug log yazılıyor
 * - shouldStopAfterElapsedMinutes kontrolü yapılıyor, eğer true ise stopAfterElapsedMinutes çağrılıyor
 * - Değilse:
 *   - TSScheduler.sharedInstance.evaluate() çağrılıyor (skip)
 *   - BackgroundTaskManager.sharedInstance.pleaseStayAwake() çağrılıyor (skip)
 *   - SOMotionDetector.sharedInstance.isMoving:triggerActivities kontrolü yapılıyor
 *   - Eğer isMoving ise, detectStartMotion:shakeCount: çağrılıyor (skip)
 *   - TSLog.sharedInstance.playSound:debug: çağrılıyor (skip)
 *   - TSHeartbeatEvent oluşturuluyor (initWithLocation:stationaryLocation)
 *   - TSQueue.sharedInstance.runOnMainQueueWithoutDeadlocking: ile block çağrılıyor
 *   - Block içinde event callback'i çağrılıyor
 */
- (void)onHeartbeat {
    // CRITICAL: Orijinal TSLocationManager pattern - debug log
    // Assembly: if (ddLogLevel & 4) { DDLog.debug... }
    if (self.config.debug) {
        [LogHelper d:@"LocationService" message:@"❤️ Heartbeat triggered"];
    }
    
    // CRITICAL: Orijinal pattern - shouldStopAfterElapsedMinutes kontrolü
    // Assembly: if ([self shouldStopAfterElapsedMinutes]) { [self stopAfterElapsedMinutes]; }
    // Basit implementasyon: stopAfterElapsedMinutes kontrolü
    if ([self shouldStopAfterElapsedMinutes]) {
        [self stopAfterElapsedMinutes];
        return;
    }
    
    // CRITICAL: Orijinal pattern - TSScheduler.sharedInstance.evaluate()
    // Assembly: [TSScheduler.sharedInstance evaluate];
    // NOT: TSScheduler yok, skip ediyoruz
    
    // CRITICAL: Orijinal pattern - BackgroundTaskManager.sharedInstance.pleaseStayAwake()
    // Assembly: [BackgroundTaskManager.sharedInstance pleaseStayAwake];
    // NOT: BackgroundTaskManager yok, skip ediyoruz
    
    // CRITICAL: Orijinal pattern - SOMotionDetector.sharedInstance.isMoving:triggerActivities
    // Assembly: isMoving = [SOMotionDetector.sharedInstance isMoving:triggerActivities];
    BOOL isMoving = NO;
    if ([MotionDetectorService motionHardwareAvailable]) {
        MotionDetectorService *motionDetector = [MotionDetectorService sharedInstance];
        NSString *triggerActivities = self.config.triggerActivities;
        if (triggerActivities && triggerActivities.length > 0) {
            isMoving = [motionDetector isMoving:triggerActivities];
        } else {
            isMoving = [motionDetector isMoving];
        }
    }
    
    // CRITICAL: Orijinal pattern - detectStartMotion:shakeCount: çağrılıyor
    // Assembly: if (isMoving) { [self detectStartMotion:motionType shakeCount:-1]; }
    // NOT: detectStartMotion metodu yok, skip ediyoruz
    // Bu metod muhtemelen motion change detection için kullanılıyor
    
    // CRITICAL: Orijinal pattern - TSLog.sharedInstance.playSound:debug:
    // Assembly: [TSLog.sharedInstance playSound:1072 debug:config.debug];
    // NOT: TSLog.playSound yok, skip ediyoruz
    
    // CRITICAL: Orijinal pattern - TSHeartbeatEvent oluşturuluyor
    // Assembly: event = [[TSHeartbeatEvent alloc] initWithLocation:stationaryLocation];
    // stationaryLocation'ı dictionary'ye çevir
    NSDictionary *locationDict = nil;
    if (self.stationaryLocation) {
        LocationModel *locationModel = [[LocationModel alloc] initWithCLLocation:self.stationaryLocation];
        locationModel.isMoving = self.config.isMoving;
        locationModel.locationType = LOCATION_TYPE_HEARTBEAT;
        locationModel.event = @"heartbeat";
        locationDict = [locationModel toDictionary];
    } else {
        // Eğer stationaryLocation yoksa, son location'ı kullan
        CLLocation *lastLocation = self.locationManager.location;
        if (lastLocation) {
            LocationModel *locationModel = [[LocationModel alloc] initWithCLLocation:lastLocation];
            locationModel.isMoving = self.config.isMoving;
            locationModel.locationType = LOCATION_TYPE_HEARTBEAT;
            locationModel.event = @"heartbeat";
            locationDict = [locationModel toDictionary];
        }
    }
    
    if (!locationDict) {
        [LogHelper w:@"LocationService" message:@"⚠️ Heartbeat: No location available"];
        return;
    }
    
    HeartbeatEvent *event = [[HeartbeatEvent alloc] initWithLocation:locationDict];
    
    // CRITICAL: Orijinal pattern - TSQueue.sharedInstance.runOnMainQueueWithoutDeadlocking: ile block çağrılıyor
    // Assembly: [TSQueue.sharedInstance runOnMainQueueWithoutDeadlocking:block];
    // TSQueue yok, bu yüzden dispatch_async(dispatch_get_main_queue(), ...) kullanıyoruz
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        // CRITICAL: Orijinal pattern - event callback'i çağrılıyor
        // Assembly: block içinde event fire ediliyor
        // NOT: HeartbeatEvent callback'i yok, HeartbeatService'ten çağrılıyor
        // Bu yüzden HeartbeatService'e de bildiriyoruz
        if ([HeartbeatService sharedInstance].onHeartbeatCallback) {
            [HeartbeatService sharedInstance].onHeartbeatCallback(event);
        }
    });
}

/**
 * Check if should stop after elapsed minutes
 * Orijinal TSLocationManager pattern - shouldStopAfterElapsedMinutes
 */
- (BOOL)shouldStopAfterElapsedMinutes {
    if (self.config.stopAfterElapsedMinutes <= 0 || self.trackingStartTime <= 0) {
        return NO;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval elapsed = now - self.trackingStartTime;
    NSTimeInterval maxElapsed = self.config.stopAfterElapsedMinutes * 60.0;
    
    return elapsed >= maxElapsed;
}

/**
 * Stop after elapsed minutes
 * Orijinal TSLocationManager pattern - stopAfterElapsedMinutes
 */
- (void)stopAfterElapsedMinutes {
    [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"⏰ stopAfterElapsedMinutes expired, stopping service"]];
    
    // Stop service
    [self stop];
    
    self.config.enabled = NO;
    [self.config save];
    // CRITICAL: notifyOnChange çağırma - onChange:@"enabled" callback'i zaten onEnabledChangeCallback'i çağırıyor
    // notifyOnChange çağrısı duplicate event'e sebep oluyor
    // Bunun yerine direkt EnabledChangeEvent oluşturup onEnabledChangeCallback'i çağırıyoruz
    
    // CRITICAL: onChange:@"enabled" callback'i sadece notifyOnChange çağrıldığında tetikleniyor
    // notifyOnChange çağrısını kaldırdığımız için, direkt EnabledChangeEvent oluşturup onEnabledChangeCallback'i çağırmalıyız
    // CRITICAL: Main queue'da çağır ki UI hemen güncellensin
    EnabledChangeEvent *event = [[EnabledChangeEvent alloc] initWithEnabled:NO];
    if (self.onEnabledChangeCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.onEnabledChangeCallback) {
                self.onEnabledChangeCallback(event);
            }
        });
    }
}

#pragma mark - LifecycleManagerDelegate

/**
 * Handle app state change (background/foreground)
 * Orijinal Transistorsoft implementasyonundan alındı
 * Uygulama background'a geçtiğinde veya foreground'a döndüğünde location tracking'i kontrol et ve gerekirse restart et
 * iOS'ta app lifecycle değişikliklerinde location tracking bazen durur, bu yüzden restart gerekli
 */
- (void)onStateChange:(BOOL)isBackground {
    [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"☯️ [STATE-CHANGE] App state changed: %@ | enabled=%@ | isTracking=%@ | allowsBG=%@", 
                                              isBackground ? @"BACKGROUND" : @"FOREGROUND",
                                              self.config.enabled ? @"YES" : @"NO",
                                              self.isTracking ? @"YES" : @"NO",
                                              self.locationManager.allowsBackgroundLocationUpdates ? @"YES" : @"NO"]];
    
    // CRITICAL: Tracking aktifse, hem background hem foreground'da location tracking'i kontrol et
    if (!self.config.enabled) {
        [LogHelper w:@"LocationService" message:@"⚠️ [STATE-CHANGE] enabled=false, skipping state change handling"];
        return;
    }
    
    CLAuthorizationStatus status = [self.locationManager authorizationStatus];
    if (status != kCLAuthorizationStatusAuthorizedAlways && status != kCLAuthorizationStatusAuthorizedWhenInUse) {
        [LogHelper w:@"LocationService" message:[NSString stringWithFormat:@"⚠️ Location authorization status: %ld (not authorized)", (long)status]];
        return;
    }
    
    if (isBackground) {
        // TRANSISTORSOFT LOG FORMAT
        [LogHelper i:@"TSAppState" message:@"ℹ️-[TSAppState onEnterBackground]"];
        
        // CRITICAL: Debug info - TÜM durum bilgilerini logla
        [LogHelper d:@"TSAppState" message:[NSString stringWithFormat:@"🔍 FULL STATUS CHECK:\n  enabled=%@\n  isTracking=%@\n  allowsBackgroundLocationUpdates=%@\n  preventSuspend=%@\n  authorizationStatus=%ld\n  isMonitoringSignificantChanges=%@",
                                                  self.config.enabled ? @"YES" : @"NO",
                                                  self.isTracking ? @"YES" : @"NO",
                                                  self.locationManager.allowsBackgroundLocationUpdates ? @"YES" : @"NO",
                                                  self.config.preventSuspend ? @"YES" : @"NO",
                                                  (long)status,
                                                  self.isMonitoringSignificantLocationChanges ? @"YES" : @"NO"]];
        
        // CRITICAL: Always authorization kontrolü
        if (status == kCLAuthorizationStatusAuthorizedAlways) {
            [LogHelper i:@"LocationService" message:@"✅ [BG-STATE] Authorization: Always - Background location should work"];
            
            // CRITICAL: allowsBackgroundLocationUpdates'ı MUTLAKA set et (iOS bazen bunu sıfırlayabilir)
            BOOL wasDisabled = !self.locationManager.allowsBackgroundLocationUpdates;
            if (wasDisabled) {
                self.locationManager.allowsBackgroundLocationUpdates = YES;
                [LogHelper w:@"LocationService" message:@"⚠️⚠️⚠️ [CRITICAL] allowsBackgroundLocationUpdates was NO in background, re-enabling IMMEDIATELY ⚠️⚠️⚠️"];
            } else {
                [LogHelper i:@"LocationService" message:@"✅ [BG-STATE] allowsBackgroundLocationUpdates already YES"];
            }
            
            // CRITICAL: Location tracking'in çalıştığından emin ol
            // Background'a geçildiğinde location tracking'in kesinlikle aktif olduğundan emin ol
            if (!self.isTracking) {
                [LogHelper e:@"LocationService" message:@"❌❌❌ [CRITICAL] Location tracking NOT active in background! This is the problem! ❌❌❌"];
                [LogHelper e:@"LocationService" message:@"❌ [CRITICAL] isTracking=false means startUpdatingLocation() was never called or stopped"];
                // CRITICAL FIX: Background'dayken location tracking'i RESTART et
                // iOS bazen location updates'i durdurur, bu yüzden restart gerekli
                [LogHelper w:@"LocationService" message:@"⚠️⚠️⚠️ [CRITICAL FIX] Restarting location tracking in background to ensure it continues ⚠️⚠️⚠️"];
                
                // Önce allowsBackgroundLocationUpdates'ı set et
                self.locationManager.allowsBackgroundLocationUpdates = YES;
                
                // Location tracking'i restart et
                [self startLocationTracking];
                _isTracking = YES;
                
                [LogHelper i:@"LocationService" message:@"✅ [BG-RESTART] Location tracking restarted in background"];
            } else {
                // isTracking=true - location tracking aktif
                // Ama yine de location manager'ın gerçekten çalıştığından emin ol
                [LogHelper i:@"LocationService" message:@"✅ [BG-STATE] Location tracking active (isTracking=YES)"];
                
                // CRITICAL: Location manager'ın gerçekten çalıştığından emin olmak için
                // allowsBackgroundLocationUpdates kontrolü yap ve gerekirse restart et
                // iOS bazen location updates'i sessizce durdurabilir
                if (!self.locationManager.allowsBackgroundLocationUpdates) {
                    [LogHelper w:@"LocationService" message:@"⚠️⚠️⚠️ [CRITICAL] isTracking=YES but allowsBackgroundLocationUpdates=NO! Restarting... ⚠️⚠️⚠️"];
                    self.locationManager.allowsBackgroundLocationUpdates = YES;
                    [self startLocationTracking];
                    _isTracking = YES;
                } else {
                    // Her şey normal görünüyor, ama yine de location tracking'i "touch" et
                    // Bu, iOS'un location updates'i durdurmamasını sağlar
                    [LogHelper i:@"LocationService" message:@"✅ [BG-STATE] Location tracking verified active (allowsBackgroundLocationUpdates=YES)"];
                    [LogHelper i:@"LocationService" message:@"✅ [BG-STATE] If you don't see [BG-LOC] logs, iOS may have stopped location updates"];
                }
            }
            
            // CRITICAL: Significant location changes kontrolü
            if (!self.isMonitoringSignificantLocationChanges) {
                [LogHelper w:@"LocationService" message:@"⚠️ [BG-STATE] Significant location changes NOT active, starting now..."];
                [self.locationManager startMonitoringSignificantLocationChanges];
                self.isMonitoringSignificantLocationChanges = YES;
            } else {
                [LogHelper i:@"LocationService" message:@"✅ [BG-STATE] Significant location changes active (backup tracking)"];
            }
            
            // TRANSISTORSOFT PATTERN: PreventSuspend Timer başlat
            // Background'a geçildiğinde 15 saniyede bir background task yenile
            if (self.config.preventSuspend) {
                [self startPreventSuspendTimer];
            }
            
            // CRITICAL: iOS 13+ requires foreground notification for background location
            // Background'a geçildiğinde notification gösterilmeli, yoksa iOS uygulamayı kapatabilir
            if (@available(iOS 13.0, *)) {
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                            [self setupForegroundNotification];
                            [LogHelper d:@"LocationService" message:@"✅ Foreground notification setup for background location (iOS 13+)"];
                        } else {
                            [LogHelper w:@"LocationService" message:@"⚠️ Notification permission required for background location (iOS 13+)"];
                            // Yine de notification'ı setup et (iOS izin verirse)
                            [self setupForegroundNotification];
                        }
                    });
                }];
            } else {
                // iOS 12 and below - notification permission not required
                // iOS 12'de de foreground notification göster (opsiyonel ama iyi)
                if (@available(iOS 10.0, *)) {
                    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                                [self setupForegroundNotification];
                                [LogHelper d:@"LocationService" message:@"✅ Foreground notification setup for background location (iOS 12)"];
                            }
                        });
                    }];
                }
            }
        } else {
            [LogHelper w:@"LocationService" message:@"⚠️ Cannot enable background location: Always authorization required"];
        }
    } else {
        // CRITICAL: Foreground'a döndüğünde
        [LogHelper i:@"LocationService" message:@"🔄 [FG-STATE] App returned to foreground"];
        
        // TRANSISTORSOFT PATTERN: PreventSuspend Timer durdur (foreground'da gerek yok)
        [self stopPreventSuspendTimer];
        
        // Tracking durumunu kontrol et
        // Eğer config.enabled=true ama isTracking=false ise, servisi restart et
        if (self.config.enabled && !self.isTracking) {
            [LogHelper d:@"LocationService" message:@"🔄 App returned to foreground: enabled=true but service not tracking, restarting..."];
            [self start];
        } else {
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"ℹ️ App returned to foreground: enabled=%@, isTracking=%@",
                                                            self.config.enabled ? @"YES" : @"NO",
                                                            self.isTracking ? @"YES" : @"NO"]];
            }
        }
    }
}

/**
 * Handle headless mode change
 * Orijinal Transistorsoft implementasyonundan alındı
 */
- (void)onHeadlessChange:(BOOL)isHeadless {
    [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"☯️ Headless mode changed: %@", isHeadless ? @"YES" : @"NO"]];
    
    // Headless mode'da da location tracking devam etmeli
    // iOS'ta headless mode genellikle background mode anlamına gelir
    if (isHeadless && self.config.enabled) {
        [LogHelper d:@"LocationService" message:@"☯️ Headless mode active, location tracking continues"];
    }
}

/**
 * Handle app termination (iOS_PRECEDUR pattern)
 * Orijinal TSLocationManager.onAppTerminate() pattern'ine göre
 * Uygulama terminate olduğunda, eğer stopOnTerminate: false ise location tracking durdurulmaz
 * Significant location changes ile uygulama arka planda başlatılabilir
 */
- (void)onAppTerminate {
    // TRANSISTORSOFT LOG FORMAT
    [LogHelper i:@"TSTrackingService" message:[NSString stringWithFormat:@"🔵-[TSTrackingService onAppTerminate] stopOnTerminate: %@", self.config.stopOnTerminate ? @"YES" : @"NO"]];
    
    // TRANSISTORSOFT PATTERN: Heartbeat timer'ı durdur
    [self stopHeartbeatTimer];
    
    if (self.config.stopOnTerminate) {
        [LogHelper i:@"TSTrackingService" message:@"🛑-[TSTrackingService onAppTerminate] stopOnTerminate: YES, stopping location tracking"];
        
        // iOS 17+ için CLLocationUpdate.liveUpdates() durdur
        if (@available(iOS 17.0, *)) {
            #if __has_include("RNBackgroundLocation-Swift.h")
            Class LiveLocationStreamClass = NSClassFromString(@"LiveLocationStream");
            if (LiveLocationStreamClass) {
                SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
                id sharedInstance = ((id (*)(id, SEL))[LiveLocationStreamClass methodForSelector:sharedInstanceSelector])(LiveLocationStreamClass, sharedInstanceSelector);
                if (sharedInstance) {
                    SEL stopSelector = NSSelectorFromString(@"stop");
                    [sharedInstance performSelector:stopSelector];
                }
            }
            #endif
        }
        
        // iOS 17+ batarya optimizasyonu - CLBackgroundActivitySession durdur
        [self stopBackgroundActivitySession];
        
        [self stop];
    } else {
        [LogHelper i:@"TSTrackingService" message:@"✅-[TSTrackingService onAppTerminate] stopOnTerminate: NO, keeping significant location changes active"];
        
        // CRITICAL: iOS 17+ için CLBackgroundActivitySession aktif kalmalı
        // stopOnTerminate: false ise session'ı koru (iOS uygulamayı restart ettiğinde devam eder)
        if (@available(iOS 17.0, *)) {
            #if __has_include("RNBackgroundLocation-Swift.h")
            // Session'ı başlat (iOS uygulamayı restart ettiğinde devam eder)
            [self startBackgroundActivitySession];
            [LogHelper i:@"TSTrackingService" message:@"✅-[TSTrackingService onAppTerminate] CLBackgroundActivitySession started (will continue after app restart)"];
            #endif
        }
        
        // CRITICAL: Ensure significant location changes is active
        // iOS will restart the app in background when significant location change occurs
        if (!self.isMonitoringSignificantLocationChanges) {
            [self.locationManager startMonitoringSignificantLocationChanges];
            self.isMonitoringSignificantLocationChanges = YES;
            [LogHelper i:@"TSTrackingService" message:@"🟢-[TSTrackingService startMonitoringSignificantLocationChanges] for app restart"];
        } else {
            [LogHelper i:@"TSTrackingService" message:@"✅-[TSTrackingService onAppTerminate] Significant location changes already active"];
        }
        
        // CRITICAL: Background Fetch schedule et (iOS 13+)
        // Bu, uygulama terminate olduktan sonra iOS'un uygulamayı periyodik olarak restart etmesini sağlar
        if (@available(iOS 13.0, *)) {
            [self scheduleBackgroundFetch];
            [LogHelper i:@"TSTrackingService" message:@"✅-[TSTrackingService onAppTerminate] Background Fetch scheduled for app restart"];
        }
        
        // CRITICAL: Save enabled state so app can resume tracking when restarted
        [self.config save];
        [LogHelper i:@"TSTrackingService" message:@"💾-[TSTrackingService onAppTerminate] Config saved - app will resume tracking when restarted by iOS"];
    }
}

#pragma mark - Background Task Management (iOS_PRECEDUR Pattern)

/**
 * Create background task to prevent app suspension
 * Orijinal BackgroundTaskManager.createBackgroundTask() pattern'ine göre
 * iOS'ta background location tracking için uygulamanın suspend edilmesini önler
 * CRITICAL: BackgroundTaskManager kullan (iOS_PRECEDUR pattern)
 */
- (UIBackgroundTaskIdentifier)createBackgroundTask {
    // CRITICAL: BackgroundTaskManager kullan (iOS_PRECEDUR pattern)
    BackgroundTaskManager *bgTaskManager = [BackgroundTaskManager sharedInstance];
    bgTaskManager.locationManager = self.locationManager;
    
    UIBackgroundTaskIdentifier taskId = [bgTaskManager createBackgroundTask];
    
    // Store task ID for reference
    self.preventSuspendTask = taskId;
    
    return taskId;
}

/**
 * Stop background task
 * Orijinal BackgroundTaskManager.stopBackgroundTask() pattern'ine göre
 * CRITICAL: BackgroundTaskManager kullan (iOS_PRECEDUR pattern)
 */
- (void)stopBackgroundTask {
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        BackgroundTaskManager *bgTaskManager = [BackgroundTaskManager sharedInstance];
        [bgTaskManager stopBackgroundTask:self.preventSuspendTask];
        self.preventSuspendTask = UIBackgroundTaskInvalid;
    }
    
    // CRITICAL: Location tracking için background task'a GEREK YOK
    // allowsBackgroundLocationUpdates = YES yeterli, iOS otomatik olarak background'da çalıştırır
    // Timer ile background task yenilemek gereksiz batarya tüketir
    
    // CRITICAL: Timer'sız event-driven monitoring - Timer yok, temizlemeye gerek yok
    // Location update'lerin kendisi monitoring yapıyor (didUpdateLocations içinde)
}

/**
 * CRITICAL: Timer'sız event-driven monitoring yaklaşımı
 * 
 * Timer yerine location update'lerin kendisi monitoring yapıyor:
 * - Her location update'te allowsBackgroundLocationUpdates kontrolü yapılıyor
 * - Eğer disabled ise, hemen re-enable ediliyor ve restart ediliyor
 * - Bu yaklaşım timer'dan daha verimli ve batarya dostu
 * 
 * Timer metodları kaldırıldı - artık event-driven yaklaşım kullanılıyor
 */

/**
 * Check and restart location tracking if needed (Event-driven - timer yerine)
 * CRITICAL: iOS sometimes stops location updates in background
 * Bu metod artık timer tarafından değil, location update'lerin kendisi tarafından çağrılıyor
 * didUpdateLocations içinde her location update'te kontrol ediliyor
 */
- (void)checkAndRestartLocationTracking {
    if (!self.config.enabled) {
        [LogHelper d:@"LocationService" message:@"🔍 [DEBUG] checkAndRestartLocationTracking: enabled=false, skipping"];
        return;
    }
    
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    NSString *appStateStr = (appState == UIApplicationStateBackground) ? @"BACKGROUND" : 
                           (appState == UIApplicationStateInactive) ? @"INACTIVE" : @"FOREGROUND";
    
    [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"🔍 [DEBUG] Location tracking health check - AppState: %@", appStateStr]];
    
    if (appState == UIApplicationStateBackground) {
        CLAuthorizationStatus status = [self.locationManager authorizationStatus];
        NSString *authStatusStr = @"UNKNOWN";
        switch (status) {
            case kCLAuthorizationStatusNotDetermined: authStatusStr = @"NotDetermined"; break;
            case kCLAuthorizationStatusRestricted: authStatusStr = @"Restricted"; break;
            case kCLAuthorizationStatusDenied: authStatusStr = @"Denied"; break;
            case kCLAuthorizationStatusAuthorizedWhenInUse: authStatusStr = @"WhenInUse"; break;
            case kCLAuthorizationStatusAuthorizedAlways: authStatusStr = @"Always"; break;
        }
        
        [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"🔍 [DEBUG] Authorization: %@, allowsBackgroundLocationUpdates: %@, isTracking: %@, isMonitoringSignificantChanges: %@", 
                                                  authStatusStr,
                                                  self.locationManager.allowsBackgroundLocationUpdates ? @"YES" : @"NO",
                                                  self.isTracking ? @"YES" : @"NO",
                                                  self.isMonitoringSignificantLocationChanges ? @"YES" : @"NO"]];
        
        if (status == kCLAuthorizationStatusAuthorizedAlways) {
            // CRITICAL: Check if allowsBackgroundLocationUpdates is still enabled
            if (!self.locationManager.allowsBackgroundLocationUpdates) {
                [LogHelper w:@"LocationService" message:@"⚠️ [CRITICAL] allowsBackgroundLocationUpdates was disabled, re-enabling..."];
                self.locationManager.allowsBackgroundLocationUpdates = YES;
            }
            
            // CRITICAL: Apple Documentation - Check if location updates are still active
            // Threshold: 30 seconds (very aggressive - if no location in 30s, restart immediately)
            // iOS sometimes stops location updates after a few updates, especially in background
            if (self.lastLocation) {
                NSTimeInterval locationAge = [[NSDate date] timeIntervalSinceDate:self.lastLocation.timestamp];
                [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"🔍 [DEBUG] Last location age: %.1f seconds (threshold: 30s)", locationAge]];
                
                if (locationAge > 30) { // 30 seconds - very aggressive threshold
                    [LogHelper w:@"LocationService" message:[NSString stringWithFormat:@"⚠️ [CRITICAL] Last location is %.0f seconds old (>30s), restarting location updates IMMEDIATELY...", locationAge]];
                    
                    // CRITICAL: Ensure allowsBackgroundLocationUpdates is enabled before restart
                    if (!self.locationManager.allowsBackgroundLocationUpdates) {
                        [LogHelper w:@"LocationService" message:@"⚠️ [CRITICAL] allowsBackgroundLocationUpdates was NO during restart, enabling..."];
                        self.locationManager.allowsBackgroundLocationUpdates = YES;
                    }
                    
                    // Using standard CLLocationManager APIs instead for maximum compatibility
                    
                    // Restart location updates immediately (no delay)
                    [self stopLocationTracking];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // CRITICAL: Double-check allowsBackgroundLocationUpdates before starting
                        if (!self.locationManager.allowsBackgroundLocationUpdates) {
                            self.locationManager.allowsBackgroundLocationUpdates = YES;
                        }
                        [self startLocationTracking];
                        self.isTracking = YES;
                        [LogHelper i:@"LocationService" message:@"✅ [FIXED] Location updates restarted IMMEDIATELY"];
                    });
                } else {
                    [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"✅ [OK] Location updates active (last location %.1fs ago)", locationAge]];
                }
            } else {
                // No last location - restart location updates immediately
                [LogHelper w:@"LocationService" message:@"⚠️ [CRITICAL] No last location, restarting location updates IMMEDIATELY..."];
                
                // CRITICAL: Ensure allowsBackgroundLocationUpdates is enabled
                if (!self.locationManager.allowsBackgroundLocationUpdates) {
                    [LogHelper w:@"LocationService" message:@"⚠️ [CRITICAL] allowsBackgroundLocationUpdates was NO, enabling..."];
                    self.locationManager.allowsBackgroundLocationUpdates = YES;
                }
                
                
                [self stopLocationTracking];
                dispatch_async(dispatch_get_main_queue(), ^{
                    // CRITICAL: Double-check allowsBackgroundLocationUpdates before starting
                    if (!self.locationManager.allowsBackgroundLocationUpdates) {
                        self.locationManager.allowsBackgroundLocationUpdates = YES;
                    }
                    [self startLocationTracking];
                    self.isTracking = YES;
                    [LogHelper i:@"LocationService" message:@"✅ [FIXED] Location updates restarted IMMEDIATELY (no last location)"];
                });
            }
            
            // CRITICAL: Ensure significant location changes is still active
            if (!self.isMonitoringSignificantLocationChanges) {
                [LogHelper w:@"LocationService" message:@"⚠️ [CRITICAL] Significant location changes stopped, restarting..."];
                [self.locationManager startMonitoringSignificantLocationChanges];
                self.isMonitoringSignificantLocationChanges = YES;
            }
            
            // CRITICAL: Recreate background task if expired
            BackgroundTaskManager *bgTaskManager = [BackgroundTaskManager sharedInstance];
            UIBackgroundTaskIdentifier bgTask = bgTaskManager.bgTask;
            [LogHelper i:@"LocationService" message:[NSString stringWithFormat:@"🔍 [DEBUG] Background task: %lu (invalid=%lu)", 
                                                      (unsigned long)bgTask, 
                                                      (unsigned long)UIBackgroundTaskInvalid]];
            
            if (bgTask == UIBackgroundTaskInvalid && self.config.preventSuspend) {
                [LogHelper w:@"LocationService" message:@"⚠️ [CRITICAL] Background task expired, recreating..."];
                bgTaskManager.locationManager = self.locationManager;
                [bgTaskManager createBackgroundTask];
            }
        } else {
            [LogHelper w:@"LocationService" message:[NSString stringWithFormat:@"⚠️ [WARNING] Authorization status is not Always (%@), background tracking may not work", authStatusStr]];
        }
    } else {
        [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"🔍 [DEBUG] App is in %@, skipping background check", appStateStr]];
    }
}

- (BOOL)isTracking {
    // CRITICAL: iOS stabil tracking - Gerçek CLLocationManager durumunu kontrol et
    // isTracking flag'i uygulama terminate olduğunda kaybolur, ama CLLocationManager çalışmaya devam edebilir
    // Bu yüzden hem flag'i hem de CLLocationManager'ın gerçek durumunu kontrol etmeliyiz
    
    // 1. Önce flag'i kontrol et (hızlı)
    if (_isTracking) {
        return YES;
    }
    
    // 2. Eğer flag false ise, CLLocationManager'ın gerçek durumunu kontrol et
    // iOS'ta CLLocationManager için doğrudan "isUpdatingLocation" property'si yok
    // Ama location manager'ın durumunu kontrol edebiliriz:
    // - Significant location changes monitoring aktifse, muhtemelen çalışıyor
    // - Son location varsa ve yakın zamanda güncellenmişse, muhtemelen çalışıyor
    // - allowsBackgroundLocationUpdates = YES ise, muhtemelen çalışıyor
    
    CLAuthorizationStatus status = [self.locationManager authorizationStatus];
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        // Authorization var, location manager muhtemelen çalışıyor
        
        // CRITICAL: Significant location changes monitoring aktifse, kesinlikle çalışıyor
        if (self.isMonitoringSignificantLocationChanges) {
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:@"✅ isTracking: YES (significant location changes active)"];
            }
            // Flag'i güncelle (senkronize et)
            _isTracking = YES;
            return YES;
        }
        
        // CRITICAL: allowsBackgroundLocationUpdates = YES ise, muhtemelen çalışıyor
        if (self.locationManager.allowsBackgroundLocationUpdates) {
            if (self.config.debug) {
                [LogHelper d:@"LocationService" message:@"✅ isTracking: YES (allowsBackgroundLocationUpdates=YES)"];
            }
            // Flag'i güncelle (senkronize et)
            _isTracking = YES;
            return YES;
        }
        
        // Son location'ı kontrol et (eğer yakın zamanda güncellenmişse, çalışıyor demektir)
        if (self.lastLocation) {
            NSTimeInterval locationAge = [[NSDate date] timeIntervalSinceDate:self.lastLocation.timestamp];
            // Eğer son location 10 dakikadan daha yeni ise, muhtemelen çalışıyor (5 dakika çok kısa)
            if (locationAge < 600) { // 10 dakika
                if (self.config.debug) {
                    [LogHelper d:@"LocationService" message:[NSString stringWithFormat:@"✅ isTracking: YES (last location %.0f seconds ago)", locationAge]];
                }
                // Flag'i güncelle (senkronize et)
                _isTracking = YES;
                return YES;
            }
        }
    }
    
    return _isTracking;
}

#pragma mark - PreventSuspend Timer (TRANSISTORSOFT PATTERN)

/**
 * TRANSISTORSOFT PATTERN: PreventSuspend Timer başlat
 * Background'da her 15 saniyede bir background task yenilenir
 * Bu, iOS'un uygulamayı suspend etmesini engeller
 * 
 * ÖNEMLI: Timer repeating: 0 olarak başlatılır ve her fired olduğunda yeniden başlatılır
 * Bu Transistorsoft'un orijinal implementasyonuna uygun
 */
- (void)startPreventSuspendTimer {
    if (self.isPreventSuspendActive && self.preventSuspendTimer != nil) {
        [LogHelper d:@"TSTimerService" message:@"⏰ [preventSuspend] Timer already active"];
        return;
    }
    
    // Eski timer'ı temizle
    if (self.preventSuspendTimer) {
        [self.preventSuspendTimer invalidate];
        self.preventSuspendTimer = nil;
    }
    
    // Background task oluştur
    [self createPreventSuspendBackgroundTask];
    
    // TRANSISTORSOFT PATTERN: Timer non-repeating (repeating: 0)
    // Her fired olduğunda yeniden başlatılır
    __weak typeof(self) weakSelf = self;
    self.preventSuspendTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                               repeats:NO  // CRITICAL: repeating: 0
                                                                 block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf onPreventSuspendTimerFired];
    }];
    
    // Timer'ın background'da da çalışması için RunLoop'a ekle
    [[NSRunLoop currentRunLoop] addTimer:self.preventSuspendTimer forMode:NSRunLoopCommonModes];
    
    self.isPreventSuspendActive = YES;
    
    // TRANSISTORSOFT LOG FORMAT
    [LogHelper i:@"TSTimerService" message:@"🟢-[TSTimerService startWithInterval:repeating:callback:] ⏰ [preventSuspend] Starting timer: 15.00s repeating: 0"];
}

/**
 * PreventSuspend Timer durdur
 * TRANSISTORSOFT LOG FORMAT
 */
- (void)stopPreventSuspendTimer {
    if (self.preventSuspendTimer) {
        [self.preventSuspendTimer invalidate];
        self.preventSuspendTimer = nil;
    }
    
    // Background task'ı sonlandır
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.preventSuspendTask];
        self.preventSuspendTask = UIBackgroundTaskInvalid;
    }
    
    self.isPreventSuspendActive = NO;
    [LogHelper i:@"TSTimerService" message:@"🛑-[TSTimerService stop] ⏰ [preventSuspend]"];
}

/**
 * PreventSuspend Timer fired - Background task yenile
 * TRANSISTORSOFT PATTERN: Her 15 saniyede background task yenilenir
 * Timer non-repeating olduğu için her fired olduğunda yeniden başlatılır
 */
- (void)onPreventSuspendTimerFired {
    // Mevcut background time'ı kontrol et
    NSTimeInterval bgTimeRemaining = [[UIApplication sharedApplication] backgroundTimeRemaining];
    int totalTasks = (self.preventSuspendTask != UIBackgroundTaskInvalid) ? 1 : 0;
    
    // TRANSISTORSOFT LOG FORMAT
    [LogHelper d:@"BackgroundTaskManager" message:[NSString stringWithFormat:@"🔵-[BackgroundTaskManager startPreventSuspendTimer:] BG time remaining: %.0f | Total tasks: %d",
                                              bgTimeRemaining, totalTasks]];
    
    // Yeni background task oluştur (mevcut biterse diye)
    [self createPreventSuspendBackgroundTask];
    
    // Location tracking'in hala aktif olduğundan emin ol
    if (self.config.enabled && !self.isTracking) {
        [LogHelper w:@"TSTrackingService" message:@"⚠️-[TSTrackingService changePace:] Tracking stopped, restarting..."];
        self.locationManager.allowsBackgroundLocationUpdates = YES;
        [self startLocationTracking];
        _isTracking = YES;
    }
    
    // allowsBackgroundLocationUpdates kontrolü
    if (self.config.enabled && !self.locationManager.allowsBackgroundLocationUpdates) {
        [LogHelper w:@"TSTrackingService" message:@"⚠️-[TSTrackingService] allowsBackgroundLocationUpdates was NO, re-enabling..."];
        self.locationManager.allowsBackgroundLocationUpdates = YES;
    }
    
    // TRANSISTORSOFT PATTERN: Timer'ı yeniden başlat (non-repeating olduğu için)
    // Bu, timer'ın sürekli çalışmasını sağlar
    if (self.config.enabled && self.config.preventSuspend && self.isPreventSuspendActive) {
        self.preventSuspendTimer = nil; // Eski referansı temizle
        __weak typeof(self) weakSelf = self;
        self.preventSuspendTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                                   repeats:NO
                                                                     block:^(NSTimer * _Nonnull timer) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf onPreventSuspendTimerFired];
        }];
        [[NSRunLoop currentRunLoop] addTimer:self.preventSuspendTimer forMode:NSRunLoopCommonModes];
    }
}

/**
 * PreventSuspend için Background Task oluştur
 */
- (void)createPreventSuspendBackgroundTask {
    // Eski task varsa sonlandır
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.preventSuspendTask];
        self.preventSuspendTask = UIBackgroundTaskInvalid;
    }
    
    // Yeni task oluştur
    __weak typeof(self) weakSelf = self;
    self.preventSuspendTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [LogHelper w:@"LocationService" message:@"⚠️ [preventSuspend] Background task expired, creating new one..."];
        
        // Task expire olunca yenisini oluştur
        if (strongSelf.preventSuspendTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:strongSelf.preventSuspendTask];
            strongSelf.preventSuspendTask = UIBackgroundTaskInvalid;
        }
        
        // Yeni task oluştur (recursive)
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf createPreventSuspendBackgroundTask];
        });
    }];
    
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        [LogHelper d:@"BackgroundTaskManager" message:[NSString stringWithFormat:@"✅-[BackgroundTaskManager createBackgroundTask] Created background task: %lu", (unsigned long)self.preventSuspendTask]];
    } else {
        [LogHelper w:@"BackgroundTaskManager" message:@"⚠️-[BackgroundTaskManager createBackgroundTask] Failed to create background task"];
    }
}

#pragma mark - Heartbeat Timer (TRANSISTORSOFT PATTERN)

/**
 * TRANSISTORSOFT PATTERN: Heartbeat Timer başlat
 * 60 saniyede bir heartbeat event gönderir
 * Bu, uygulamanın hala çalıştığını gösterir
 */
- (void)startHeartbeatTimer {
    if (self.isHeartbeatActive && self.heartbeatTimer != nil) {
        [LogHelper d:@"TSTimerService" message:@"⏰ [heartbeat] Timer already active"];
        return;
    }
    
    // Eski timer'ı temizle
    if (self.heartbeatTimer) {
        [self.heartbeatTimer invalidate];
        self.heartbeatTimer = nil;
    }
    
    NSTimeInterval heartbeatInterval = self.config.heartbeatInterval > 0 ? self.config.heartbeatInterval : 60.0;
    
    // TRANSISTORSOFT PATTERN: Timer repeating: 1 (repeating)
    __weak typeof(self) weakSelf = self;
    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:heartbeatInterval
                                                          repeats:YES
                                                            block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf onHeartbeatTimerFired];
    }];
    
    // Timer'ın background'da da çalışması için RunLoop'a ekle
    [[NSRunLoop currentRunLoop] addTimer:self.heartbeatTimer forMode:NSRunLoopCommonModes];
    
    self.isHeartbeatActive = YES;
    
    // TRANSISTORSOFT LOG FORMAT
    [LogHelper i:@"TSTimerService" message:[NSString stringWithFormat:@"🟢-[TSTimerService startWithInterval:repeating:callback:] ⏰ [heartbeat] Starting timer: %.2fs repeating: 1", heartbeatInterval]];
}

/**
 * Heartbeat Timer durdur
 */
- (void)stopHeartbeatTimer {
    if (self.heartbeatTimer) {
        [self.heartbeatTimer invalidate];
        self.heartbeatTimer = nil;
    }
    
    self.isHeartbeatActive = NO;
    [LogHelper i:@"TSTimerService" message:@"🛑-[TSTimerService stop] ⏰ [heartbeat]"];
}

/**
 * Heartbeat Timer fired - Heartbeat event gönder
 */
- (void)onHeartbeatTimerFired {
    [LogHelper d:@"TSTrackingService" message:@"💓-[TSTrackingService onHeartbeat] heartbeat event"];
    
    // HeartbeatService'e forward et (class method)
    [HeartbeatService onHeartbeat];
    
    // Location tracking'in hala aktif olduğundan emin ol
    if (self.config.enabled && !self.isTracking) {
        [LogHelper w:@"TSTrackingService" message:@"⚠️-[TSTrackingService onHeartbeat] Tracking stopped, restarting..."];
        self.locationManager.allowsBackgroundLocationUpdates = YES;
        [self startLocationTracking];
        _isTracking = YES;
    }
}

#pragma mark - Stationary Region Monitoring (TRANSISTORSOFT PATTERN)

/**
 * TRANSISTORSOFT PATTERN: Stationary Region Monitoring başlat
 * Kullanıcı belirli bir radius dışına çıktığında location update tetiklenir
 */
- (void)startMonitoringStationaryRegion:(CLLocation *)location radius:(CLLocationDistance)radius {
    // Eski region'ı durdur
    [self stopMonitoringStationaryRegion];
    
    if (!location) {
        [LogHelper w:@"TSTrackingService" message:@"⚠️-[TSTrackingService startMonitoringStationaryRegion:] No location provided"];
        return;
    }
    
    // Radius minimum 50m olmalı
    CLLocationDistance actualRadius = MAX(radius, 50.0);
    
    // Yeni stationary region oluştur
    NSString *identifier = @"com.rnbackgroundlocation.stationaryRegion";
    self.stationaryRegion = [[CLCircularRegion alloc] initWithCenter:location.coordinate
                                                              radius:actualRadius
                                                          identifier:identifier];
    self.stationaryRegion.notifyOnEntry = NO;
    self.stationaryRegion.notifyOnExit = YES;
    
    // Region monitoring başlat
    [self.locationManager startMonitoringForRegion:self.stationaryRegion];
    self.isMonitoringStationaryRegion = YES;
    
    // TRANSISTORSOFT LOG FORMAT
    [LogHelper i:@"TSTrackingService" message:[NSString stringWithFormat:@"🔵-[TSTrackingService startMonitoringStationaryRegion:radius:] Radius: %.0f", actualRadius]];
}

/**
 * Stationary Region Monitoring durdur
 */
- (void)stopMonitoringStationaryRegion {
    if (self.stationaryRegion && self.isMonitoringStationaryRegion) {
        [self.locationManager stopMonitoringForRegion:self.stationaryRegion];
        self.stationaryRegion = nil;
        self.isMonitoringStationaryRegion = NO;
        [LogHelper i:@"TSTrackingService" message:@"🛑-[TSTrackingService stopMonitoringStationaryRegion]"];
    }
}

#pragma mark - CLLocationManagerDelegate Region Monitoring

/**
 * Region'a girildiğinde çağrılır
 */
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    [LogHelper i:@"TSTrackingService" message:[NSString stringWithFormat:@"📍-[TSTrackingService locationManager:didEnterRegion:] %@", region.identifier]];
}

/**
 * Region'dan çıkıldığında çağrılır - Kullanıcı hareket etmeye başladı
 */
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    [LogHelper i:@"TSTrackingService" message:[NSString stringWithFormat:@"📍-[TSTrackingService locationManager:didExitRegion:] %@ | User started moving", region.identifier]];
    
    // Stationary region'dan çıkıldı - location update'leri yeniden başlat
    if ([region.identifier isEqualToString:@"com.rnbackgroundlocation.stationaryRegion"]) {
        [LogHelper i:@"TSTrackingService" message:@"🏃-[TSTrackingService didExitStationaryRegion] User exited stationary region, resuming location updates"];
        
        // Location tracking'i yeniden başlat
        if (self.config.enabled) {
            self.locationManager.allowsBackgroundLocationUpdates = YES;
            [self startLocationTracking];
            _isTracking = YES;
        }
    }
}

/**
 * Region monitoring başlatıldığında çağrılır
 */
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    [LogHelper d:@"TSTrackingService" message:[NSString stringWithFormat:@"✅-[TSTrackingService locationManager:didStartMonitoringForRegion:] %@", region.identifier]];
}

/**
 * Region monitoring hatası
 */
- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    [LogHelper e:@"TSTrackingService" message:[NSString stringWithFormat:@"❌-[TSTrackingService locationManager:monitoringDidFailForRegion:] %@ | Error: %@", region.identifier, error.localizedDescription]];
}

@end

