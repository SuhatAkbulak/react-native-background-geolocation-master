//
//  RNBackgroundLocation.m
//  RNBackgroundLocation
//
//  React Native Background Location Module
//  Android RNBackgroundLocationModule.java benzeri
//

#import "RNBackgroundLocation.h"
#import "TSLocationManager.h"
#import "TSConfig.h"
#import "LocationService.h"
#import "SyncService.h"
#import "ConnectivityMonitor.h"
#import "SQLiteLocationDAO.h"
#import "SQLiteGeofenceDAO.h"
#import "LocationModel.h"
#import "GeofenceModel.h"
#import "LocationEvent.h"
#import "HttpResponseEvent.h"
#import "ConnectivityChangeEvent.h"
#import "EnabledChangeEvent.h"
#import "MotionChangeEvent.h"
#import "GeofenceEvent.h"
#import "ActivityChangeEvent.h"
#import "HeartbeatEvent.h"
#import "TSPowerSaveChangeEvent.h"
#import "TSLocation.h"
#import "event/TSGeofenceEvent.h"
#import "event/TSHttpEvent.h"
#import "event/TSConnectivityChangeEvent.h"
#import "event/TSEnabledChangeEvent.h"
#import "event/TSActivityChangeEvent.h"
#import "event/TSHeartbeatEvent.h"
#import "TSCurrentPositionRequest.h"
#import "TSWatchPositionRequest.h"
#import "TSGeofence.h"
#import "service/ActivityRecognitionService.h"
#import "service/HeartbeatService.h"
#import "lifecycle/LifecycleManager.h"
#import "util/TSDeviceInfo.h"
#import "util/LogHelper.h"
#import "service/MotionDetectorService.h"
#import <React/RCTLog.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import <UserNotifications/UserNotifications.h>

static NSString *const EVENT_LOCATION = @"location";
static NSString *const EVENT_HTTP = @"http";
static NSString *const EVENT_CONNECTIVITYCHANGE = @"connectivitychange";
static NSString *const EVENT_ENABLEDCHANGE = @"enabledchange";
static NSString *const EVENT_MOTIONCHANGE = @"motionchange";
static NSString *const EVENT_GEOFENCE = @"geofence";
static NSString *const EVENT_ACTIVITYCHANGE = @"activitychange";
static NSString *const EVENT_HEARTBEAT = @"heartbeat";
static NSString *const EVENT_POWERSAVECHANGE = @"powersavechange";

@interface RNBackgroundLocation () <UNUserNotificationCenterDelegate>
@end

@implementation RNBackgroundLocation

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isReady = NO;
        _config = [TSConfig sharedInstance];
        _locationDatabase = [SQLiteLocationDAO sharedInstance];
        _geofenceDatabase = [SQLiteGeofenceDAO sharedInstance];
        
        // Initialize TSLocationManager (ExampleIOS pattern - only iOS pattern, no Android LocationService)
        _tsLocationManager = [TSLocationManager sharedInstance];
        
        // CRITICAL: iOS_PRECEDUR pattern - Set notification center delegate for foreground notifications
        // iOS'ta foreground'da notification göstermek için delegate gerekiyor
        if (@available(iOS 10.0, *)) {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            center.delegate = self;
        }
        
        // CRITICAL: iOS_PRECEDUR pattern - Register for app lifecycle notifications
        // Orijinal RCTBackgroundGeolocation.m'den alındı
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
        
        // HACK: it seems to be too late to register on launch observer so trigger it manually
        // Orijinal RCTBackgroundGeolocation.m'den alındı
        [self onFinishLaunching:nil];
        
        [self registerEventListeners];
    }
    return self;
}

- (void)registerEventListeners {
    __typeof(self) __weak me = self;
    
    // Use TSLocationManager event listeners (ExampleIOS pattern)
    // Location event
    [self.tsLocationManager onLocation:^(TSLocation *location) {
        [me sendEventWithName:EVENT_LOCATION body:[location toDictionary]];
    } failure:^(NSError *error) {
        // Handle error if needed
    }];
    
    // HTTP event
    [self.tsLocationManager onHttp:^(TSHttpEvent *event) {
        [me sendEventWithName:EVENT_HTTP body:[event toDictionary]];
    }];
    
    // Connectivity change event
    [self.tsLocationManager onConnectivityChange:^(TSConnectivityChangeEvent *event) {
        [me sendEventWithName:EVENT_CONNECTIVITYCHANGE body:[event toDictionary]];
    }];
    
    // Enabled change event
    [self.tsLocationManager onEnabledChange:^(TSEnabledChangeEvent *event) {
        // CRITICAL: Listener kontrolü yap - eğer listener yoksa event gönderme
        // Bu, "Sending enabledchange with no listeners registered" uyarısını önler
        if (me.isReady) {
            [me sendEventWithName:EVENT_ENABLEDCHANGE body:[event toDictionary]];
        } else if (me.config.debug) {
            [LogHelper d:@"RNBackgroundLocation" message:@"ℹ️ enabledchange event skipped (listeners not ready yet)"];
        }
    }];
    
    // Activity change event
    [self.tsLocationManager onActivityChange:^(TSActivityChangeEvent *event) {
        [me sendEventWithName:EVENT_ACTIVITYCHANGE body:[event toDictionary]];
    }];
    
    // Heartbeat event
    [self.tsLocationManager onHeartbeat:^(TSHeartbeatEvent *event) {
        [me sendEventWithName:EVENT_HEARTBEAT body:[event toDictionary]];
    }];
    
    // Geofence event
    [self.tsLocationManager onGeofence:^(TSGeofenceEvent *event) {
        [me sendEventWithName:EVENT_GEOFENCE body:[event toDictionary]];
    }];
    
    // Motion change event (ExampleIOS pattern - TSLocationManager handles it)
    [self.tsLocationManager onMotionChange:^(TSLocation *location) {
        [me sendEventWithName:EVENT_MOTIONCHANGE body:[location toDictionary]];
    }];
    
    // Power save change event (ExampleIOS pattern - TSLocationManager handles it)
    [self.tsLocationManager onPowerSaveChange:^(TSPowerSaveChangeEvent *event) {
        [me sendEventWithName:EVENT_POWERSAVECHANGE body:[event toDictionary]];
    }];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        EVENT_LOCATION,
        EVENT_POWERSAVECHANGE,
        EVENT_HTTP,
        EVENT_CONNECTIVITYCHANGE,
        EVENT_ENABLEDCHANGE,
        EVENT_MOTIONCHANGE,
        EVENT_GEOFENCE,
        EVENT_ACTIVITYCHANGE,
        EVENT_HEARTBEAT
    ];
}

#pragma mark - Config Methods

RCT_EXPORT_METHOD(ready:(NSDictionary *)params 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // CRITICAL: iOS state restore - Load config from persistence BEFORE configure()
        // NOT: Otomatik start yok - sadece enabled state'i restore et (UI'da durum gösterilsin diye)
        // Kullanıcı manuel olarak start/stop yapabilir
        [self.config load];
        
        // CRITICAL: Save enabled state BEFORE configure() - configure() calls save() which will override enabled
        // config.load() içinde enabled state restore ediliyor (stopOnTerminate: false ise)
        // Ama configure() içindeki save() bu state'i override edebilir, bu yüzden saklamalıyız
        BOOL savedEnabled = self.config.enabled;
        BOOL savedStopOnTerminate = self.config.stopOnTerminate;
        
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager configure:params];
        
        // CRITICAL: Restore enabled state AFTER configure() if stopOnTerminate: false
        // NOT: Otomatik start yok - sadece enabled state'i restore et (UI'da durum gösterilsin diye)
        // configure() içindeki updateWithDictionary() enabled state'ini değiştirmez
        // Ama updateWithDictionary() içinde save() çağrılıyor ve bu enabled state'ini koruyor (satır 729)
        // Yine de emin olmak için tekrar restore etmeliyiz
        if (!savedStopOnTerminate && savedEnabled) {
            // CRITICAL: enabled state'ini restore et
            // config.load() içinde zaten restore edilmiş ama configure() sonrası tekrar kontrol et
            self.config.enabled = YES;
            [self.config save]; // CRITICAL: Save enabled state so it persists (UI'da durum gösterilsin)
            if (self.config.debug) {
                [LogHelper d:@"RNBackgroundLocation" message:@"🔄 Restored enabled state after configure()"];
            }
        }
        
        [self.tsLocationManager ready];
        self.isReady = YES;
        
        // CRITICAL: iOS stabil tracking - Eğer config.enabled=true ama LocationService.isTracking=false ise,
        // servisi restart et (uygulama açıldığında arka planda çalışan servisi devam ettir)
        // NOT: Önce getState() çağır, sonra restart yap (state doğru dönsün)
        NSDictionary *currentState = [self.tsLocationManager getState];
        
        LocationService *locationService = [LocationService sharedInstance];
        BOOL isActuallyTracking = locationService.isTracking;
        
        if (self.config.enabled && !isActuallyTracking) {
            if (self.config.debug) {
                [LogHelper d:@"RNBackgroundLocation" message:@"🔄 ready(): Config enabled=true but service not tracking, restarting service..."];
            }
            // Servisi restart et (start() metodu duplicate kontrolü yapıyor)
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tsLocationManager start];
                // Restart sonrası state'i güncelle
                if (self.config.debug) {
                    NSDictionary *newState = [self.tsLocationManager getState];
                    [LogHelper d:@"RNBackgroundLocation" message:[NSString stringWithFormat:@"✅ Service restarted, new state: enabled=%@", newState[@"enabled"]]];
                }
            });
        } else if (self.config.debug) {
            [LogHelper d:@"RNBackgroundLocation" message:[NSString stringWithFormat:@"ℹ️ ready(): Service state: enabled=%@, isTracking=%@",
                                                            self.config.enabled ? @"YES" : @"NO",
                                                            isActuallyTracking ? @"YES" : @"NO"]];
        }
        
        success(@[currentState]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(configure:(NSDictionary *)params 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.config reset];
        [self.tsLocationManager configure:params];
        self.isReady = YES;
        success(@[[self.tsLocationManager getState]]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(setConfig:(NSDictionary *)params 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        [self.config updateWithDictionary:params];
        success(@[[self.config toDictionary]]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(reset:(NSDictionary *)params 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        [self.config reset];
        if (params && params.count > 0) {
            [self.config updateWithDictionary:params];
        }
        success(@[[self.config toDictionary]]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

#pragma mark - Control Methods

RCT_EXPORT_METHOD(start:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // CRITICAL: Duplicate start'ı önle - eğer zaten tracking yapıyorsa, başarılı döndür
            LocationService *locationService = [LocationService sharedInstance];
            if (self.config.enabled && locationService.isTracking) {
                if (self.config.debug) {
                    [LogHelper d:@"RNBackgroundLocation" message:@"ℹ️ Already tracking, returning current state"];
                }
                success(@[[self.tsLocationManager getState]]);
                return;
            }
            
            // Check authorization
            CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
            if (status != kCLAuthorizationStatusAuthorizedAlways && 
                status != kCLAuthorizationStatusAuthorizedWhenInUse) {
                failure(@[@"Location permissions not granted"]);
                return;
            }

            // Opsiyonel: Her yeni start çağrısında eski lokasyonları temizle
            // JS tarafında clearLocationsOnStart: true gönderildiğinde çalışır.
            if (self.config.clearLocationsOnStart) {
                [self.locationDatabase clear];
                // İsteğe bağlı: yeni session için odometreyi de sıfırla
                self.config.odometer = 0.0;
                [self.config save];
            }
            
            // Use TSLocationManager pattern (ExampleIOS)
            [self.tsLocationManager start];
            
            // CRITICAL: Kısa bir delay sonra state'i döndür (servis başlamak için zaman tanı)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                success(@[[self.tsLocationManager getState]]);
            });
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

RCT_EXPORT_METHOD(stop:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // CRITICAL: Duplicate stop'u önle - eğer zaten durmuşsa, başarılı döndür
            LocationService *locationService = [LocationService sharedInstance];
            if (!self.config.enabled && !locationService.isTracking) {
                if (self.config.debug) {
                    [LogHelper d:@"RNBackgroundLocation" message:@"ℹ️ Already stopped, returning current state"];
                }
                success(@[[self.tsLocationManager getState]]);
                return;
            }
            
            // Use TSLocationManager pattern (ExampleIOS)
            [self.tsLocationManager stop];
            
            // CRITICAL: Kısa bir delay sonra state'i döndür (servis durmak için zaman tanı)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                success(@[[self.tsLocationManager getState]]);
            });
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

RCT_EXPORT_METHOD(startGeofences:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
            if (status != kCLAuthorizationStatusAuthorizedAlways && 
                status != kCLAuthorizationStatusAuthorizedWhenInUse) {
                failure(@[@"Location permissions not granted"]);
                return;
            }
            
            // Use TSLocationManager pattern (ExampleIOS)
            [self.tsLocationManager startGeofences];
            success(@[[self.tsLocationManager getState]]);
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

RCT_EXPORT_METHOD(startSchedule:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager startSchedule];
        success(@[[self.tsLocationManager getState]]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(stopSchedule:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager stopSchedule];
        success(@[[self.tsLocationManager getState]]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(changePace:(BOOL)isMoving 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager changePace:isMoving];
        success(@[]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

#pragma mark - Location Methods

RCT_EXPORT_METHOD(getCurrentPosition:(NSDictionary *)options 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
            if (status != kCLAuthorizationStatusAuthorizedAlways && 
                status != kCLAuthorizationStatusAuthorizedWhenInUse) {
                failure(@[@"Location permissions not granted"]);
                return;
            }
            
            // Parse options
            double timeout = options[@"timeout"] ? [options[@"timeout"] doubleValue] : 30000;
            double maximumAge = options[@"maximumAge"] ? [options[@"maximumAge"] doubleValue] : 0;
            BOOL persist = options[@"persist"] ? [options[@"persist"] boolValue] : NO;
            NSInteger samples = options[@"samples"] ? [options[@"samples"] integerValue] : 1;
            double desiredAccuracy = options[@"desiredAccuracy"] ? [options[@"desiredAccuracy"] doubleValue] : 0;
            NSDictionary *extras = options[@"extras"];
            
            // Use TSLocationManager pattern (ExampleIOS)
            TSCurrentPositionRequest *request = [[TSCurrentPositionRequest alloc] init];
            request.timeout = timeout / 1000.0; // Convert ms to seconds
            request.maximumAge = maximumAge / 1000.0; // Convert ms to seconds
            request.persist = persist;
            request.samples = samples;
            if (desiredAccuracy > 0) {
                request.desiredAccuracy = [TSConfig decodeDesiredAccuracy:@(desiredAccuracy)];
            }
            request.extras = extras;
            
            request.success = ^(TSLocation *location) {
                success(@[[location toDictionary]]);
            };
            
            request.failure = ^(NSError *error) {
                failure(@[error.localizedDescription ?: @"Failed to get current position"]);
            };
            
            [self.tsLocationManager getCurrentPosition:request];
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

RCT_EXPORT_METHOD(watchPosition:(NSDictionary *)options 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Parse options
            double interval = options[@"interval"] ? [options[@"interval"] doubleValue] : 1000;
            double desiredAccuracy = options[@"desiredAccuracy"] ? [options[@"desiredAccuracy"] doubleValue] : 0;
            BOOL persist = options[@"persist"] ? [options[@"persist"] boolValue] : NO;
            NSDictionary *extras = options[@"extras"];
            
            // Use TSLocationManager pattern (ExampleIOS)
            TSWatchPositionRequest *request = [[TSWatchPositionRequest alloc] init];
            request.interval = interval;
            if (desiredAccuracy > 0) {
                request.desiredAccuracy = [TSConfig decodeDesiredAccuracy:@(desiredAccuracy)];
            }
            request.persist = persist;
            request.extras = extras;
            
            request.success = ^(TSLocation *location) {
                success(@[[location toDictionary]]);
            };
            
            request.failure = ^(NSError *error) {
                failure(@[error.localizedDescription ?: @"Failed to watch position"]);
            };
            
            [self.tsLocationManager watchPosition:request];
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

RCT_EXPORT_METHOD(stopWatchPosition:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager stopWatchPosition];
        success(@[]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

#pragma mark - State Methods

RCT_EXPORT_METHOD(getState:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        NSDictionary *state = [self.tsLocationManager getState];
        success(@[state]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

#pragma mark - Database Methods

RCT_EXPORT_METHOD(getLocations:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            // Use TSLocationManager pattern (ExampleIOS)
            [self.tsLocationManager getLocations:^(NSArray *locations) {
                success(@[locations ?: @[]]);
            } failure:^(NSString *error) {
                failure(@[error ?: @"Failed to get locations"]);
            }];
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

RCT_EXPORT_METHOD(getCount:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        NSInteger count = [self.tsLocationManager getCount];
        success(@[@(count)]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(insertLocation:(NSDictionary *)location 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager insertLocation:location success:^(NSString *uuid) {
            success(@[uuid ?: @""]);
        } failure:^(NSString *error) {
            failure(@[error ?: @"Failed to insert location"]);
        }];
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(destroyLocations:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager destroyLocations:^{
            success(@[]);
        } failure:^(NSString *error) {
            failure(@[error ?: @"Failed to clear locations"]);
        }];
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(destroyLocation:(NSString *)uuid 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager destroyLocation:uuid success:^{
            success(@[]);
        } failure:^(NSString *error) {
            failure(@[error ?: @"Failed to destroy location"]);
        }];
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

#pragma mark - Sync Methods

RCT_EXPORT_METHOD(sync:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            // Use TSLocationManager pattern (ExampleIOS)
            [self.tsLocationManager sync:^(NSArray *locations) {
                success(@[locations ?: @[]]);
            } failure:^(NSError *error) {
                failure(@[error.localizedDescription ?: @"Sync failed"]);
            }];
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

#pragma mark - Odometer Methods

RCT_EXPORT_METHOD(getOdometer:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        CLLocationDistance odometer = [self.tsLocationManager getOdometer];
        success(@[@(odometer)]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(setOdometer:(double)value 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Use TSLocationManager pattern (ExampleIOS)
            // setOdometer:request: - request nil ise sadece odometer set edilir
            [self.tsLocationManager setOdometer:value request:nil];
            
            // Return current location if available
            TSLocation *location = self.tsLocationManager.lastLocation;
            if (location) {
                success(@[[location toDictionary]]);
            } else {
                success(@[@{@"odometer": @(value)}]);
            }
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

#pragma mark - Geofence Methods

RCT_EXPORT_METHOD(addGeofence:(NSDictionary *)geofence 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Parse geofence dictionary to TSGeofence
        NSString *identifier = geofence[@"identifier"];
        NSNumber *radius = geofence[@"radius"];
        NSNumber *latitude = geofence[@"latitude"];
        NSNumber *longitude = geofence[@"longitude"];
        BOOL notifyOnEntry = geofence[@"notifyOnEntry"] ? [geofence[@"notifyOnEntry"] boolValue] : YES;
        BOOL notifyOnExit = geofence[@"notifyOnExit"] ? [geofence[@"notifyOnExit"] boolValue] : YES;
        BOOL notifyOnDwell = geofence[@"notifyOnDwell"] ? [geofence[@"notifyOnDwell"] boolValue] : NO;
        NSNumber *loiteringDelay = geofence[@"loiteringDelay"] ?: @(0);
        
        if (!identifier || !radius || !latitude || !longitude) {
            failure(@[@"Invalid geofence data: identifier, radius, latitude, longitude are required"]);
            return;
        }
        
        TSGeofence *tsGeofence = [[TSGeofence alloc] initWithIdentifier:identifier
                                                                   radius:[radius doubleValue]
                                                                 latitude:[latitude doubleValue]
                                                                longitude:[longitude doubleValue]
                                                            notifyOnEntry:notifyOnEntry
                                                             notifyOnExit:notifyOnExit
                                                            notifyOnDwell:notifyOnDwell
                                                           loiteringDelay:[loiteringDelay doubleValue] / 1000.0]; // Convert ms to seconds
        
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager addGeofence:tsGeofence success:^{
            success(@[]);
        } failure:^(NSString *error) {
            failure(@[error ?: @"Failed to add geofence"]);
        }];
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(removeGeofence:(NSString *)identifier 
                  success:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager removeGeofence:identifier success:^{
            success(@[]);
        } failure:^(NSString *error) {
            failure(@[error ?: @"Failed to remove geofence"]);
        }];
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(removeGeofences:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        [self.tsLocationManager removeGeofences];
        success(@[]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(getGeofences:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        // Use TSLocationManager pattern (ExampleIOS)
        NSArray *geofences = [self.tsLocationManager getGeofences];
        NSMutableArray *result = [NSMutableArray array];
        for (TSGeofence *geofence in geofences) {
            [result addObject:[geofence toDictionary]];
        }
        success(@[result]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

#pragma mark - Permission Methods

RCT_EXPORT_METHOD(requestPermission:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // Use TSLocationManager pattern (ExampleIOS)
            [self.tsLocationManager requestPermission:^(NSNumber *status) {
                success(@[status]);
            } failure:^(NSNumber *status) {
                failure(@[status]);
            }];
        } @catch (NSException *exception) {
            failure(@[exception.reason]);
        }
    });
}

#pragma mark - Device Methods

RCT_EXPORT_METHOD(getDeviceInfo:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        TSDeviceInfo *deviceInfo = [TSDeviceInfo sharedInstance];
        NSDictionary *info = [deviceInfo toDictionary:@"react-native"];
        success(@[info]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(getSensors:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        MotionDetectorService *motionDetector = [MotionDetectorService sharedInstance];
        BOOL accelerometer = [MotionDetectorService isAccelerometerAvailable];
        BOOL gyro = [MotionDetectorService isGyroAvailable];
        BOOL magnetometer = [MotionDetectorService isMagnetometerAvailable];
        BOOL deviceMotion = [MotionDetectorService isDeviceMotionAvailable];
        
        NSMutableDictionary *sensors = [NSMutableDictionary dictionaryWithDictionary:@{
            @"platform": @"ios",
            @"accelerometer": @(accelerometer),
            @"magnetometer": @(magnetometer),
            @"gyroscope": @(gyro),
            // significant_motion: CoreMotion deviceMotion veya activity varsa true
            @"significant_motion": @(deviceMotion)
        }];
        
        // SOMotionDetector benzeri ek bilgiler
        if (@available(iOS 7.0, *)) {
            sensors[@"usingM7"] = @(motionDetector.usingM7);
            sensors[@"M7Authorized"] = @(motionDetector.M7Authorized);
        }
        sensors[@"motionType"] = motionDetector.motionTypeName ?: @"unknown";
        sensors[@"motionActivityConfidence"] = @([motionDetector motionActivityConfidence]);
        
        success(@[sensors]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(getDiagnosticsData:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        MotionDetectorService *motionDetector = [MotionDetectorService sharedInstance];
        NSArray *diagnostics = [motionDetector getDiagnosticsData];
        success(@[diagnostics ?: @[]]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

#pragma mark - Helper Methods ()

RCT_EXPORT_METHOD(getActivity:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        CMMotionActivity *lastActivity = [ActivityRecognitionService getLastActivity];
        NSString *activityName = @"unknown";
        NSInteger confidence = 0;
        
        if (lastActivity) {
            if (lastActivity.automotive) {
                activityName = @"in_vehicle";
                confidence = lastActivity.confidence == CMMotionActivityConfidenceHigh ? 100 : 70;
            } else if (lastActivity.cycling) {
                activityName = @"on_bicycle";
                confidence = lastActivity.confidence == CMMotionActivityConfidenceHigh ? 100 : 70;
            } else if (lastActivity.running) {
                activityName = @"running";
                confidence = lastActivity.confidence == CMMotionActivityConfidenceHigh ? 100 : 70;
            } else if (lastActivity.walking) {
                activityName = @"walking";
                confidence = lastActivity.confidence == CMMotionActivityConfidenceHigh ? 100 : 70;
            } else if (lastActivity.stationary) {
                activityName = @"still";
                confidence = lastActivity.confidence == CMMotionActivityConfidenceHigh ? 100 : 70;
            }
        }
        
        NSDictionary *result = @{
            @"activity": activityName,
            @"confidence": @(confidence)
        };
        success(@[result]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(isMoving:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        BOOL moving = [ActivityRecognitionService isMoving];
        success(@[@(moving)]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(isBackground:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        BOOL background = [[LifecycleManager sharedInstance] isBackground];
        success(@[@(background)]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(isHeadless:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        BOOL headless = [[LifecycleManager sharedInstance] isHeadless];
        success(@[@(headless)]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

RCT_EXPORT_METHOD(isPowerSaveMode:(RCTResponseSenderBlock)success 
                  failure:(RCTResponseSenderBlock)failure) {
    @try {
        BOOL isPowerSaveMode = [self.tsLocationManager isPowerSaveMode];
        success(@[@(isPowerSaveMode)]);
    } @catch (NSException *exception) {
        failure(@[exception.reason]);
    }
}

#pragma mark - UNUserNotificationCenterDelegate (iOS_PRECEDUR Pattern)

/**
 * iOS_PRECEDUR pattern - Show notification even when app is in foreground
 * iOS'ta foreground'da notification göstermek için bu delegate metodu gerekiyor
 */
- (void)userNotificationCenter:(UNUserNotificationCenter *)center 
       willPresentNotification:(UNNotification *)notification 
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler API_AVAILABLE(ios(10.0)) {
    // CRITICAL: Show notification even when app is in foreground
    // This is required for background location tracking notifications
    if (@available(iOS 14.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge);
    } else {
        completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge);
    }
}

#pragma mark - RCTInvalidating

- (void)invalidate {
    [self.tsLocationManager stop];
    [[ConnectivityMonitor sharedInstance] stopMonitoring];
}

/**
 * on UIApplicationDidFinishLaunchingNotification
 * Orijinal RCTBackgroundGeolocation.m'den alındı
 * Uygulama location event ile başlatıldığında otomatik start yap
 */
- (void)onFinishLaunching:(NSNotification *)notification {
    NSDictionary *dict = [notification userInfo];
    
    // CRITICAL: iOS_PRECEDUR pattern - Check if app was launched by location event
    // Orijinal RCTBackgroundGeolocation.m'den: if ([dict objectForKey:UIApplicationLaunchOptionsLocationKey])
    // Bu, significant location change veya background fetch ile uygulama başlatıldığında true olur
    BOOL launchedByLocationEvent = [dict objectForKey:UIApplicationLaunchOptionsLocationKey] != nil;
    
    // CRITICAL: Background'da başlatıldıysa (location event veya background fetch)
    UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
    BOOL launchedInBackground = (appState == UIApplicationStateBackground);
    
    if (launchedByLocationEvent || launchedInBackground) {
        RCTLogInfo(@"🔄 App launched in background (location event: %@, state: %@)", 
                   launchedByLocationEvent ? @"YES" : @"NO",
                   launchedInBackground ? @"BACKGROUND" : @"FOREGROUND");
        
        // CRITICAL: Load config to check stopOnTerminate
        [self.config load];
        
        // CRITICAL: Orijinal pattern - If stopOnTerminate: false, auto-start
        // NOT: Normal uygulama açılışında otomatik start yok
        // Sadece location event veya background fetch ile başlatıldığında otomatik start yap
        if (![self.config stopOnTerminate]) {
            // Small delay to ensure all services are initialized
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // Reload config to ensure enabled state is restored
                [self.config load];
                
                // CRITICAL: Config.load() zaten enabled state'i restore etti (eğer savedEnabled=true ise)
                if (self.config.enabled) {
                    RCTLogInfo(@"✅ Auto-starting location tracking (background launch - stopOnTerminate: false)");
                    [self.tsLocationManager start];
                } else {
                    RCTLogInfo(@"ℹ️ Auto-start skipped: enabled=NO (stopOnTerminate: false but enabled was not saved)");
                }
            });
        } else {
            RCTLogInfo(@"ℹ️ Auto-start skipped: stopOnTerminate=YES");
        }
    }
}

@end

