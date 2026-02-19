//
//  MotionDetectorService.m
//  RNBackgroundLocation
//
//  SOMotionDetector benzeri basit sensör wrapper
//

#import "MotionDetectorService.h"
#import "LogHelper.h"
#import <math.h>

// Orijinal SOMotionDetector'dan alınan constants
static const double kMinimumWalkingAcceleration = 0.13; // m/s² - walking için minimum acceleration threshold
static const double kMinimumSpeed = 0.0; // m/s - minimum speed threshold
static const double kMaximumWalkingSpeed = 2.0; // m/s (~7.2 km/h) - maximum walking speed
static const double kMaximumRunningSpeed = 5.0; // m/s (~18 km/h) - maximum running speed

@interface MotionDetectorService ()
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) CMMotionActivityManager *activityManager;
@property (nonatomic, strong) NSOperationQueue *motionQueue;
@property (atomic, readwrite) CMAcceleration acceleration;
@property (atomic, readwrite) double averageVectorSum;
@property (atomic, readwrite) NSInteger shakeCount;
@property (atomic, readwrite) BOOL isShaking;
@property (atomic, readwrite) MDMotionType motionType;
@property (atomic, strong, nullable, readwrite) CMMotionActivity *motionActivity;
@property (atomic, readwrite) BOOL usingM7;
@property (atomic, readwrite) BOOL M7Authorized;
@property (nonatomic, strong) NSMutableArray *diagnostics;
// CRITICAL: History array for calculate method (SOMotionDetector pattern)
@property (nonatomic, strong) NSMutableArray *history; // Stores NSValue wrapping CMAcceleration
// CRITICAL: Current location (SOMotionDetector pattern)
@property (atomic, strong, nullable) CLLocation *location;
// CRITICAL: Current speed for motion type calculation (SOMotionDetector pattern)
@property (atomic, readwrite) double currentSpeed; // m/s
// CRITICAL: Previous motion type for change detection (SOMotionDetector pattern)
@property (atomic, readwrite) MDMotionType previousMotionType;
// CRITICAL: isMoving property (SOMotionDetector pattern)
@property (atomic, readwrite) BOOL isMoving; // motionType != 1 && motionType != 6
// CRITICAL: isUpdatingMotionActivity flag (SOMotionDetector pattern)
@property (atomic, readwrite) BOOL isUpdatingMotionActivity; // Motion activity updates aktif mi?
// CRITICAL: Shake detecting timer (SOMotionDetector pattern)
@property (nonatomic, strong, nullable) NSTimer *shakeDetectingTimer;
// CRITICAL: Motion detection interval (SOMotionDetector pattern)
@property (atomic, assign) NSTimeInterval motionDetectionInterval;
// CRITICAL: Samples per interval (SOMotionDetector pattern)
@property (atomic, readwrite) NSInteger samplesPerInterval;
@end

@implementation MotionDetectorService
 
 + (instancetype)sharedInstance {
     static MotionDetectorService *instance = nil;
     static dispatch_once_t onceToken;
     dispatch_once(&onceToken, ^{
         instance = [[MotionDetectorService alloc] init];
     });
     return instance;
 }
 
 - (instancetype)init {
     self = [super init];
     if (self) {
        _motionManager = [[CMMotionManager alloc] init];
        if (@available(iOS 7.0, *)) {
            _activityManager = [[CMMotionActivityManager alloc] init];
        }
        _motionQueue = [[NSOperationQueue alloc] init];
        _accelerometerUpdateInterval = 0.1; // 100ms varsayılan
        _acceleration = (CMAcceleration){0, 0, 0};
        _averageVectorSum = 0;
        _shakeCount = 0;
        _isShaking = NO;
        _motionType = MDMotionTypeUnknown;
        _usingM7 = NO;
        _M7Authorized = NO;
        _useM7IfAvailable = YES;
        _diagnostics = [NSMutableArray array];
        _history = [NSMutableArray array]; // Initialize history array
        _currentSpeed = 0.0; // Initialize current speed
        _previousMotionType = MDMotionTypeUnknown; // Initialize previous motion type
        _isMoving = NO; // Initialize isMoving
        _isUpdatingMotionActivity = NO; // Initialize isUpdatingMotionActivity
        _motionDetectionInterval = 1.0; // 1 saniye varsayılan
        _samplesPerInterval = 0; // Initialize samplesPerInterval
     }
     return self;
 }
 
 #pragma mark - Static capability helpers
 
 + (BOOL)isAccelerometerAvailable {
     return [[self sharedInstance].motionManager isAccelerometerAvailable];
 }
 
 + (BOOL)isGyroAvailable {
     return [[self sharedInstance].motionManager isGyroAvailable];
 }
 
 + (BOOL)isMagnetometerAvailable {
     if (@available(iOS 5.0, *)) {
         return [[self sharedInstance].motionManager isMagnetometerAvailable];
     }
     return NO;
 }
 
 + (BOOL)isDeviceMotionAvailable {
     return [[self sharedInstance].motionManager isDeviceMotionAvailable];
 }
 
+ (BOOL)motionHardwareAvailable {
    // CRITICAL: Orijinal SOMotionDetector pattern - dispatch_once ile cache'le
    // Orijinal kod: dispatch_once ile ilk çağrıda kontrol edip cache'liyor
    // Block içeriği: sadece CMMotionActivityManager.isActivityAvailable kontrol ediliyor
    // Orijinal block: motionHardwareAvailable_isAvailable = [CMMotionActivityManager isActivityAvailable]
    static dispatch_once_t onceToken;
    static BOOL isAvailable = NO;
    
    dispatch_once(&onceToken, ^{
        // CRITICAL: Orijinal SOMotionDetector pattern - sadece CMMotionActivityManager kontrolü
        // Orijinal kod: [CMMotionActivityManager isActivityAvailable]
        // Block içeriği: motionHardwareAvailable_isAvailable = objc_msgSend(CMMotionActivityManager, isActivityAvailable)
        if (@available(iOS 7.0, *)) {
            isAvailable = [CMMotionActivityManager isActivityAvailable];
        } else {
            // iOS 7.0 öncesi: CMMotionActivityManager yok, false döndür
            isAvailable = NO;
        }
    });
    
    return isAvailable;
}
 
 #pragma mark - Detection
 
- (void)startDetection {
    // CRITICAL: Orijinal SOMotionDetector pattern
    // 1. Shake/acceleration tarafını başlat
    [self startShakeDetection:self.accelerometerUpdateInterval];

    // 2. M7 / CMMotionActivity ile motionType takibi
    // Orijinal kod: if (!isUpdatingMotionActivity && useM7IfAvailable && motionHardwareAvailable)
    if (@available(iOS 7.0, *)) {
        if (!self.isUpdatingMotionActivity && 
            self.useM7IfAvailable && 
            [MotionDetectorService motionHardwareAvailable]) {
            
            // CRITICAL: motionActivityManager yoksa oluştur (Orijinal pattern)
            if (!self.activityManager) {
                self.activityManager = [[CMMotionActivityManager alloc] init];
            }
            
            // CRITICAL: Orijinal pattern - queryActivityStartingFromDate ile başlat
            // Orijinal kod: queryActivityStartingFromDate:date toDate:date toQueue:queue withHandler:block
            // Şu anki tarihten şu anki tarihe (son activity'yi al)
            NSDate *now = [NSDate date];
            NSOperationQueue *queryQueue = [[NSOperationQueue alloc] init];
            queryQueue.name = @"MotionActivityQueryQueue";
            
            __weak typeof(self) weakSelf = self;
            [self.activityManager queryActivityStartingFromDate:now
                                                        toDate:now
                                                       toQueue:queryQueue
                                                   withHandler:^(NSArray<CMMotionActivity *> * _Nullable activities, NSError * _Nullable error) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                
                // CRITICAL: Orijinal SOMotionDetector pattern - block içeriği
                if (error) {
                    // Error varsa: M7Authorized = 0, flag temizle
                    // Orijinal kod: error code kontrolü, M7Authorized = 0
                    strongSelf.M7Authorized = NO;
                    strongSelf.isUpdatingMotionActivity = NO;
                    [LogHelper w:@"MotionDetectorService" message:[NSString stringWithFormat:@"⚠️ Query activity error: %@", error.localizedDescription]];
                    return;
                }
                
                // CRITICAL: Orijinal pattern - query başarılı olursa:
                // 1. stopShakeDetection çağrılıyor (shake detection durduruluyor)
                // 2. M7Authorized = 1 set ediliyor
                // 3. isUpdatingMotionActivity = YES set ediliyor
                // 4. startActivityUpdatesToQueue:withHandler: çağrılıyor
                
                // Stop shake detection (M7 kullanılacak, shake detection'a gerek yok)
                [strongSelf stopShakeDetection];
                
                // M7Authorized = 1
                strongSelf.M7Authorized = YES;
                strongSelf.usingM7 = YES;
                
                // isUpdatingMotionActivity = YES
                strongSelf.isUpdatingMotionActivity = YES;
                
                // Son activity'yi kullan (varsa)
                if (activities && activities.count > 0) {
                    CMMotionActivity *lastActivity = activities.lastObject;
                    strongSelf.motionActivity = lastActivity;
                    
                    // Motion type'ı güncelle
                    MDMotionType newType = [strongSelf mapActivityToMotionType:lastActivity];
                    strongSelf.motionType = newType;
                }
                
                // CRITICAL: Orijinal pattern - startActivityUpdatesToQueue:withHandler: çağrılıyor
                // motionActivityManager alınıyor
                CMMotionActivityManager *activityManager = strongSelf.activityManager;
                
                // NSOperationQueue oluşturuluyor
                NSOperationQueue *activityQueue = [[NSOperationQueue alloc] init];
                activityQueue.name = @"MotionActivityQueue";
                
                // motionActivityChangedBlock alınıyor
                void (^handler)(CMMotionActivity * _Nullable) = [strongSelf createMotionActivityChangedHandler];
                
                // startActivityUpdatesToQueue:withHandler: çağrılıyor
                [activityManager startActivityUpdatesToQueue:activityQueue withHandler:handler];
            }];
        }
    }
 }

#pragma mark - SOMotionDetector createMotionActivityChangedHandler

/**
 * Create motion activity changed handler block (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector createMotionActivityChangedHandler]
 * Bu metod bir block oluşturur ve weak self reference kullanır
 * 
 * Block içeriği (decompile edilmiş):
 * 1. Activity kontrolü: stationary || walking || running || automotive || cycling
 * 2. Eğer activity varsa:
 *    - @synchronized ile thread-safe motionActivity set et
 *    - calculateMotionType:vectorSum: çağır (-1, 0.0 ile - activity varsa history'den hesaplamaya gerek yok)
 */
- (void (^)(CMMotionActivity * _Nullable activity))createMotionActivityChangedHandler {
    __weak typeof(self) weakSelf = self;
    
    // CRITICAL: Orijinal SOMotionDetector pattern - weak self ile block oluştur
    return ^(CMMotionActivity * _Nullable activity) {
        // Orijinal pattern: objc_retain(activity)
        // activity zaten ARC tarafından yönetiliyor, bu yüzden gerek yok
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !activity) {
            return;
        }
        
        // CRITICAL: Orijinal pattern - Activity kontrolü
        // stationary || walking || running || automotive || cycling
        BOOL hasValidActivity = activity.stationary ||
                               activity.walking ||
                               activity.running ||
                               activity.automotive ||
                               (activity.cycling);
        
        if (!hasValidActivity) {
            return; // Geçersiz activity, işleme
        }
        
        // CRITICAL: Orijinal pattern - @synchronized ile thread-safe motionActivity set et
        // Orijinal kod: objc_sync_enter(motionActivity), setMotionActivity:, objc_sync_exit
        @synchronized (strongSelf.motionActivity) {
            // Motion activity'yi güncelle
            strongSelf.motionActivity = activity;
            strongSelf.usingM7 = YES;
            strongSelf.M7Authorized = YES; // Eğer data geliyorsa izin verilmiş demektir
        }
        
        // CRITICAL: Orijinal pattern - calculateMotionType:vectorSum: çağır
        // Orijinal kod: calculateMotionType:vectorSum: (0xFFFFFFFF, qword_1D80)
        // 0xFFFFFFFF = -1 = walkingCount (activity varsa history'den hesaplamaya gerek yok)
        // qword_1D80 = muhtemelen 0.0 (default vectorSum, activity varsa kullanılmıyor)
        // Activity varsa motionActivity'den motion type belirlenir, history'den değil
        [strongSelf calculateMotionType:-1 vectorSum:0.0];
        
        // Diagnostics kaydı
        [strongSelf appendDiagnosticsEntryWithActivity:activity];
    };
}
 
/**
 * Stop detection (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector stopDetection]
 * 
 * Assembly pattern:
 * - isUpdatingMotionActivity = 0 set ediliyor
 * - motionActivityManager alınıyor
 * - Eğer manager varsa:
 *   - Debug log yazılıyor (opsiyonel)
 *   - stopActivityUpdates çağrılıyor
 * - stopShakeDetection çağrılıyor
 */
- (void)stopDetection {
    // CRITICAL: Orijinal SOMotionDetector pattern - isUpdatingMotionActivity flag'i temizle
    // Assembly: self->isUpdatingMotionActivity = 0;
    self.isUpdatingMotionActivity = NO;
    
    // CRITICAL: Orijinal pattern - motionActivityManager kontrolü
    // Assembly: v2 = [self motionActivityManager]; v3 = retain(v2); release(v3);
    CMMotionActivityManager *activityManager = nil;
    if (@available(iOS 7.0, *)) {
        activityManager = self.activityManager;
    }
    
    if (activityManager) {
        // CRITICAL: Orijinal pattern - debug log (opsiyonel)
        // Assembly: if (ddLogLevel & 4) DDLog...
        // Şimdilik skip ediyoruz, gerekirse LogHelper kullanılabilir
        
        // CRITICAL: Orijinal pattern - stopActivityUpdates
        // Assembly: [activityManager stopActivityUpdates];
        [activityManager stopActivityUpdates];
    }
    
    // CRITICAL: Orijinal pattern - stopShakeDetection çağrılıyor
    // Assembly: [self stopShakeDetection];
    [self stopShakeDetection];
}
 
/**
 * Start shake detection (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector startShakeDetection:]
 * 
 * Assembly pattern:
 * - isUsingM7 kontrolü - eğer M7 kullanılıyorsa shake detection başlatılmıyor
 * - accelerometerUpdateInterval set ediliyor
 * - samplesPerInterval hesaplanıyor: motionDetectionInterval / accelerometerUpdateInterval
 * - stopAccelerometerUpdates çağrılıyor
 * - setAccelerometerUpdateInterval: çağrılıyor
 * - setGyroUpdateInterval: çağrılıyor (aynı interval ile)
 * - startAccelerometerUpdatesToQueue:withHandler: çağrılıyor
 * - TSQueue.sharedInstance.runInMain: çağrılıyor (bir block ile)
 */
- (void)startShakeDetection:(NSTimeInterval)sampleRate {
    // CRITICAL: Orijinal SOMotionDetector pattern - isUsingM7 kontrolü
    // Assembly: if (!isUsingM7) { ... }
    // Eğer M7 kullanılıyorsa shake detection başlatılmıyor
    if (self.usingM7) {
        return;
    }
    
    if (!self.motionManager.isAccelerometerAvailable) {
        return;
    }
    
    // CRITICAL: Orijinal pattern - accelerometerUpdateInterval set ediliyor
    // Assembly: self->_accelerometerUpdateInterval = accelerometerUpdateInterval;
    self.accelerometerUpdateInterval = sampleRate;
    
    // CRITICAL: Orijinal pattern - samplesPerInterval hesaplanıyor
    // Assembly: self->samplesPerInterval = (int)(motionDetectionInterval / accelerometerUpdateInterval);
    self.samplesPerInterval = (NSInteger)(self.motionDetectionInterval / sampleRate);
    
    // CRITICAL: Orijinal pattern - stopAccelerometerUpdates çağrılıyor
    // Assembly: [motionManager stopAccelerometerUpdates];
    if (self.motionManager.isAccelerometerActive) {
        [self.motionManager stopAccelerometerUpdates];
    }
    
    // CRITICAL: Orijinal pattern - setAccelerometerUpdateInterval: çağrılıyor
    // Assembly: [motionManager setAccelerometerUpdateInterval:accelerometerUpdateInterval];
    self.motionManager.accelerometerUpdateInterval = sampleRate;
    
    // CRITICAL: Orijinal pattern - setGyroUpdateInterval: çağrılıyor (aynı interval ile)
    // Assembly: [motionManager setGyroUpdateInterval:accelerometerUpdateInterval];
    if (self.motionManager.isGyroAvailable) {
        self.motionManager.gyroUpdateInterval = sampleRate;
    }
    
    // CRITICAL: Orijinal pattern - startAccelerometerUpdatesToQueue:withHandler: çağrılıyor
    __weak typeof(self) weakSelf = self;
    [self.motionManager startAccelerometerUpdatesToQueue:self.motionQueue
                                              withHandler:^(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error) {
         __strong typeof(weakSelf) strongSelf = weakSelf;
         if (!strongSelf || error) {
             return;
         }
         
         CMAcceleration acc = accelerometerData.acceleration;
         strongSelf.acceleration = acc;
         
         // CRITICAL: Add to history (SOMotionDetector pattern)
         // Store CMAcceleration as NSValue
         NSValue *accValue = [NSValue valueWithBytes:&acc objCType:@encode(CMAcceleration)];
         @synchronized (strongSelf.history) {
             [strongSelf.history addObject:accValue];
             // Limit history size (keep last 100 samples)
             if (strongSelf.history.count > 100) {
                 [strongSelf.history removeObjectAtIndex:0];
             }
         }
         
         // Basit SOMotionDetector benzeri vektör hesabı
         double vectorSum = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z);
         
         // Basit hareketlilik metriği: kayan ortalama
         const double alpha = 0.1; // low-pass filter
         strongSelf.averageVectorSum = alpha * vectorSum + (1.0 - alpha) * strongSelf.averageVectorSum;
         
         // Shake tespiti için threshold (yerçekimi 1g ~ 1.0 civarı)
         BOOL wasShaking = strongSelf.isShaking;
         double delta = fabs(vectorSum - 1.0);
         BOOL nowShaking = (delta > 0.7); // deneysel threshold
         strongSelf.isShaking = nowShaking;
         
         if (!wasShaking && nowShaking) {
             strongSelf.shakeCount += 1;
         }
         
         // CRITICAL: Orijinal pattern - TSQueue.sharedInstance.runInMain: çağrılıyor
         // Assembly: [TSQueue.sharedInstance runInMain:block];
         // Block içeriği: [self record] çağrılıyor + timer setup
         // TSQueue yok, bu yüzden dispatch_async(dispatch_get_main_queue(), ...) kullanıyoruz
         dispatch_async(dispatch_get_main_queue(), ^{
             // CRITICAL: Orijinal pattern - record metodu çağrılıyor
             // Assembly: objc_msgSend(self, sel_record);
             // Bu muhtemelen accelerometer data'sını kaydetmek için kullanılıyor
             [strongSelf record];
             
             // CRITICAL: Orijinal pattern - shake detecting timer setup
             // Assembly: 
             //   v1 = [self shakeDetectingTimer];
             //   if (v1) [v1 invalidate];
             //   timer = [NSTimer scheduledTimerWithTimeInterval:(samplesPerInterval + 1) 
             //                                           target:self 
             //                                         selector:@selector(detectShaking) 
             //                                         userInfo:nil 
             //                                          repeats:YES];
             //   [self setShakeDetectingTimer:timer];
             if (strongSelf.shakeDetectingTimer) {
                 [strongSelf.shakeDetectingTimer invalidate];
                 strongSelf.shakeDetectingTimer = nil;
             }
             
             // CRITICAL: Timer interval hesaplaması
             // Assembly: (double)(samplesPerInterval + 1)
             // samplesPerInterval = motionDetectionInterval / accelerometerUpdateInterval (örneğin: 1.0 / 0.1 = 10)
             // Timer interval = (samplesPerInterval + 1) * accelerometerUpdateInterval
             // Örnek: (10 + 1) * 0.1 = 1.1 saniye
             NSTimeInterval timerInterval = (strongSelf.samplesPerInterval + 1) * strongSelf.accelerometerUpdateInterval;
             strongSelf.shakeDetectingTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval
                                                                                target:strongSelf
                                                                              selector:@selector(detectShaking)
                                                                              userInfo:nil
                                                                               repeats:YES];
             
             // Callback'leri main thread'de çağır
             if (strongSelf.accelerationChangedBlock) {
                 strongSelf.accelerationChangedBlock(acc);
             }
             if (strongSelf.shakeStateChangedBlock) {
                 strongSelf.shakeStateChangedBlock(strongSelf.isShaking,
                                                   strongSelf.shakeCount,
                                                   strongSelf.averageVectorSum);
             }
         });
     }];
}
 
/**
 * Stop shake detection (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector stopShakeDetection]
 * 
 * Assembly pattern:
 * - shakeDetectingTimer alınıyor ve retain ediliyor
 * - Eğer timer varsa:
 *   - Debug log yazılıyor (opsiyonel)
 *   - Timer invalidate ediliyor
 *   - Timer nil set ediliyor (setShakeDetectingTimer: nil)
 *   - stopAccelerometerUpdates çağrılıyor
 * - Eğer timer yoksa hiçbir şey yapılmıyor
 */
- (void)stopShakeDetection {
    // CRITICAL: Orijinal SOMotionDetector pattern - timer kontrolü
    // Assembly: v2 = [self shakeDetectingTimer]; v3 = retain(v2); release(v3);
    NSTimer *timer = self.shakeDetectingTimer;
    
    if (timer) {
        // CRITICAL: Orijinal pattern - debug log (opsiyonel)
        // Assembly: if (ddLogLevel & 4) DDLog...
        // Şimdilik skip ediyoruz, gerekirse LogHelper kullanılabilir
        
        // CRITICAL: Orijinal pattern - timer invalidate
        // Assembly: [timer invalidate]; release(timer);
        [timer invalidate];
        
        // CRITICAL: Orijinal pattern - timer nil set et
        // Assembly: [self setShakeDetectingTimer: nil];
        self.shakeDetectingTimer = nil;
        
        // CRITICAL: Orijinal pattern - stopAccelerometerUpdates
        // Assembly: [motionManager stopAccelerometerUpdates];
        if (self.motionManager.isAccelerometerActive) {
            [self.motionManager stopAccelerometerUpdates];
        }
    }
    // NOT: Assembly'de timer yoksa hiçbir şey yapılmıyor
    // Ama güvenlik için accelerometer'ı kontrol ediyoruz
    else if (self.motionManager.isAccelerometerActive) {
        [self.motionManager stopAccelerometerUpdates];
    }
}

/**
 * Detect shaking (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector detectShaking]
 * 
 * Assembly pattern:
 * - NSTimer tarafından periyodik olarak çağrılıyor
 * - samplesPerInterval + 1 interval ile çağrılıyor
 * - Bu muhtemelen history'den motion type hesaplamak için kullanılıyor
 */
- (void)detectShaking {
    // CRITICAL: Orijinal SOMotionDetector pattern - history'den motion type hesapla
    // Timer periyodik olarak çağrılıyor ve history'den motion type hesaplanıyor
    [self calculate];
}

#pragma mark - Motion Activity Helpers

- (MDMotionType)mapActivityToMotionType:(CMMotionActivity *)activity API_AVAILABLE(ios(7.0)) {
    if (activity.automotive) {
        return MDMotionTypeAutomotive;
    } else if (activity.cycling) {
        return MDMotionTypeCycling;
    } else if (activity.running) {
        return MDMotionTypeRunning;
    } else if (activity.walking) {
        return MDMotionTypeWalking;
    } else if (activity.stationary) {
        return MDMotionTypeStationary;
    } else {
        return MDMotionTypeUnknown;
    }
}

/**
 * Query motion activity history (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector queryMotionActivityHistory]
 * 
 * Assembly pattern:
 * - isUsingM7 kontrolü yapılıyor
 * - Eğer M7 kullanılıyorsa:
 *   - NSDate date alınıyor (şu anki tarih)
 *   - dateByAddingTimeInterval: ile geçmiş bir tarih hesaplanıyor (qword_1D88 değeri ile, muhtemelen -3600)
 *   - motionActivityManager alınıyor
 *   - NSOperationQueue mainQueue alınıyor
 *   - queryActivityStartingFromDate:toDate:toQueue:withHandler: çağrılıyor
 *   - Handler block'u global bir block literal
 * - Her zaman 1 (YES) return ediliyor
 */
- (BOOL)queryMotionActivityHistory {
    // CRITICAL: Orijinal SOMotionDetector pattern - isUsingM7 kontrolü
    // Assembly: if (isUsingM7) { ... }
    if (!self.usingM7) {
        return YES; // Assembly'de her zaman 1 return ediliyor
    }
    
    if (@available(iOS 7.0, *)) {
        if (![CMMotionActivityManager isActivityAvailable]) {
            return YES; // Assembly'de her zaman 1 return ediliyor
        }

        // CRITICAL: Orijinal pattern - NSDate date alınıyor
        // Assembly: v3 = [NSDate date];
        NSDate *now = [NSDate date];
        
        // CRITICAL: Orijinal pattern - dateByAddingTimeInterval ile geçmiş tarih hesaplanıyor
        // Assembly: v5 = [v4 dateByAddingTimeInterval:qword_1D88];
        // qword_1D88 muhtemelen -3600 (son 1 saat) veya benzeri bir değer
        NSDate *start = [now dateByAddingTimeInterval:-3600]; // Son 1 saat
        
        // CRITICAL: Orijinal pattern - motionActivityManager alınıyor
        // Assembly: v7 = [self motionActivityManager];
        CMMotionActivityManager *activityManager = self.activityManager;
        
        // CRITICAL: Orijinal pattern - NSOperationQueue mainQueue alınıyor
        // Assembly: v9 = [NSOperationQueue mainQueue];
        NSOperationQueue *queue = [NSOperationQueue mainQueue];
        
        // CRITICAL: Orijinal pattern - queryActivityStartingFromDate:toDate:toQueue:withHandler: çağrılıyor
        // Assembly: [activityManager queryActivityStartingFromDate:start toDate:now toQueue:queue withHandler:block];
        // Handler block'u global bir block literal (__block_literal_global_231)
        __weak typeof(self) weakSelf = self;
        [activityManager queryActivityStartingFromDate:start
                                                toDate:now
                                               toQueue:queue
                                           withHandler:^(NSArray<CMMotionActivity *> * _Nullable activities, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            // CRITICAL: Orijinal SOMotionDetector pattern - handler block içeriği
            // Assembly: __46__SOMotionDetector_queryMotionActivityHistory__block_invoke
            // 1. Error kontrolü: Eğer error varsa log yazılıyor
            // 2. Error yoksa:
            //    - Activities array'i enumerate ediliyor
            //    - Her activity için:
            //      - unknown kontrolü yapılıyor
            //      - Eğer unknown değilse:
            //        - stationary kontrolü yapılıyor
            //        - Eğer stationary değilse (hareket eden), counter artırılıyor
            //    - Sonunda counter log'lanıyor
            
            if (error) {
                // CRITICAL: Orijinal pattern - error varsa log yazılıyor
                // Assembly: if (error) { DDLog error... }
                [LogHelper e:@"MotionDetectorService" message:[NSString stringWithFormat:@"⚠️ Query activity history error: %@", error.localizedDescription]];
                return;
            }
            
            if (!activities || activities.count == 0) {
                return;
            }
            
            // CRITICAL: Orijinal pattern - activities array'i enumerate ediliyor
            // Assembly: countByEnumeratingWithState:objects:count: ile enumerate ediliyor
            // Her activity için unknown ve stationary kontrolü yapılıyor
            // Unknown olmayan ve stationary olmayan (hareket eden) activity'lerin sayısı sayılıyor
            NSInteger movingActivityCount = 0;
            for (CMMotionActivity *activity in activities) {
                // CRITICAL: Orijinal pattern - unknown kontrolü
                // Assembly: if (![activity unknown]) { ... }
                if (!activity.unknown) {
                    // CRITICAL: Orijinal pattern - stationary kontrolü
                    // Assembly: if (![activity stationary]) { counter++; }
                    // Eğer stationary değilse (hareket eden), counter artırılıyor
                    if (!activity.stationary) {
                        movingActivityCount++;
                    }
                }
            }
            
            // CRITICAL: Orijinal pattern - counter log'lanıyor
            // Assembly: DDLog debug: movingActivityCount, activities
            // Şimdilik skip ediyoruz, gerekirse LogHelper kullanılabilir
            
            // Son aktiviteyi state'e yansıt (mevcut implementasyon)
            CMMotionActivity *last = activities.lastObject;
            strongSelf.motionActivity = last;
            strongSelf.motionType = [strongSelf mapActivityToMotionType:last];
            strongSelf.usingM7 = YES;
            strongSelf.M7Authorized = YES;

            [strongSelf appendDiagnosticsEntryWithActivity:last];
        }];
        
        // CRITICAL: Orijinal pattern - her zaman 1 (YES) return ediliyor
        // Assembly: return 1;
        return YES;
    }
    
    // CRITICAL: Orijinal pattern - her zaman 1 (YES) return ediliyor
    return YES;
}

- (NSString *)motionTypeName {
    return [self motionTypeName:self.motionType];
}

/**
 * Get motion type name string (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector motionTypeName:]
 * 
 * Assembly pattern:
 * - v3 = motionType - 1 (enum 1'den başlıyor)
 * - if (v3 > 6) return default (unknown)
 * - return switch_table[v3]
 * 
 * Switch table sırası (v3 = motionType - 1):
 * - v3 = 0 → Stationary (1) → "still"
 * - v3 = 1 → Walking (2) → "walking"
 * - v3 = 2 → Running (3) → "running"
 * - v3 = 3 → Automotive (4) → "in_vehicle"
 * - v3 = 4 → Cycling (5) → "on_bicycle"
 * - v3 = 5 → Unknown (6) → "unknown"
 * - v3 = 6 → Moving (7) → "moving"
 * - v3 > 6 → default → "unknown"
 */
- (NSString *)motionTypeName:(MDMotionType)motionType {
    // CRITICAL: Orijinal SOMotionDetector pattern - switch table kullanımı
    // Assembly: v3 = motionType - 1, if (v3 > 6) return default, else return switch_table[v3]
    switch (motionType) {
        case MDMotionTypeStationary: // 1 → v3 = 0
            return @"still";
        case MDMotionTypeWalking: // 2 → v3 = 1
            return @"walking";
        case MDMotionTypeRunning: // 3 → v3 = 2
            return @"running";
        case MDMotionTypeAutomotive: // 4 → v3 = 3
            return @"in_vehicle";
        case MDMotionTypeCycling: // 5 → v3 = 4
            return @"on_bicycle";
        case MDMotionTypeUnknown: // 6 → v3 = 5
            return @"unknown";
        case MDMotionTypeMoving: // 7 → v3 = 6
            return @"moving";
        default: // v3 > 6
            return @"unknown";
    }
}

/**
 * Get motion activity confidence (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector motionActivityConfidence]
 * 
 * Assembly pattern:
 * - motionActivity retain ediliyor
 * - @synchronized ile thread-safe erişim
 * - motionActivity varsa:
 *   - Default: v5 = 100 (High)
 *   - confidence != High ise → v5 = 66 (Medium)
 *   - confidence != Medium ise → v5 = 33 (Low)
 *   - confidence yoksa → v5 = 0
 * - motionActivity yoksa → v5 = 0
 * 
 * CMMotionActivityConfidence enum değerleri:
 * - CMMotionActivityConfidenceHigh → 100
 * - CMMotionActivityConfidenceMedium → 66
 * - CMMotionActivityConfidenceLow → 33
 * - Yoksa → 0
 */
- (NSInteger)motionActivityConfidence {
    // CRITICAL: Orijinal SOMotionDetector pattern - @synchronized ile thread-safe erişim
    // Assembly: objc_retain(motionActivity), objc_sync_enter, check confidence, objc_sync_exit
    CMMotionActivity *motionActivity = nil;
    @synchronized (self.motionActivity) {
        motionActivity = self.motionActivity;
    }
    
    if (!motionActivity) {
        return 0;
    }
    
    if (@available(iOS 7.0, *)) {
        // CRITICAL: Orijinal pattern - confidence değerleri
        // Assembly: Default 100, else if != High → 66, else if != Medium → 33, else 0
        switch (motionActivity.confidence) {
            case CMMotionActivityConfidenceHigh:
                return 100;
            case CMMotionActivityConfidenceMedium:
                return 66; // Orijinal: 66 (mevcut: 70)
            case CMMotionActivityConfidenceLow:
                return 33; // Orijinal: 33 (mevcut: 50)
            default:
                return 0;
        }
    }
    return 0;
}

- (NSArray *)getDiagnosticsData {
    @synchronized (self.diagnostics) {
        return [self.diagnostics copy];
    }
}

#pragma mark - SOMotionDetector calculate methods

/**
 * Calculate motion type from history (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan decompile edilen algoritma
 */
- (void)calculate {
    double totalVectorSum = 0.0;
    NSInteger walkingCount = 0;
    NSInteger historyCount = 0;
    
    // Enumerate history array
    @synchronized (self.history) {
        historyCount = self.history.count;
        
        for (NSValue *accValue in self.history) {
            CMAcceleration acc;
            [accValue getValue:&acc];
            
            // Calculate vector sum: sqrt(x*x + y*y + z*z)
            double vectorSum = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z);
            totalVectorSum += vectorSum;
            
            // Count samples above minimum walking acceleration threshold
            if (vectorSum >= kMinimumWalkingAcceleration) {
                walkingCount++;
            }
        }
    }
    
    // Calculate average vector sum
    double averageVectorSum = (historyCount > 0) ? (totalVectorSum / historyCount) : 0.0;
    
    // Calculate confidence score (SOMotionDetector pattern)
    // Formula: (walkingCount * averageVectorSum) * (walkingCount * averageVectorSum)
    double confidenceScore = 0.0;
    if (historyCount > 0) {
        double walkingRatio = (double)walkingCount / (double)historyCount;
        confidenceScore = walkingRatio * averageVectorSum * (walkingRatio * averageVectorSum);
    }
    
    // Update averageVectorSum property
    self.averageVectorSum = averageVectorSum;
    
    // Call calculateMotionType:vectorSum: with walkingCount and averageVectorSum
    [self calculateMotionType:walkingCount vectorSum:averageVectorSum];
}

/**
 * Calculate motion type from vector sum (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan decompile edilen algoritma
 * @param walkingCount Number of samples above minimum walking acceleration
 * @param vectorSum Average vector sum from history
 */
- (void)calculateMotionType:(NSInteger)walkingCount vectorSum:(double)vectorSum {
    MDMotionType motionType = MDMotionTypeUnknown;
    
    // CRITICAL: Orijinal SOMotionDetector algoritması
    // 1. Eğer motionActivity varsa, onu kullan (priority: stationary -> walking -> running -> automotive -> cycling)
    if (self.motionActivity) {
        @synchronized (self.motionActivity) {
            motionType = MDMotionTypeUnknown; // Default: 6 (unknown)
            
            // Priority order: stationary (1) -> walking (2) -> running (3) -> automotive (4) -> cycling (5)
            // Orijinal kod: if (stationary) return 1; else if (walking) return 2; etc.
            if (self.motionActivity.stationary) {
                motionType = MDMotionTypeStationary; // 1
            } else if (self.motionActivity.walking) {
                motionType = MDMotionTypeWalking; // 2
            } else if (self.motionActivity.running) {
                motionType = MDMotionTypeRunning; // 3
            } else if (self.motionActivity.automotive) {
                motionType = MDMotionTypeAutomotive; // 4
            } else if ([self.motionActivity respondsToSelector:@selector(cycling)] && self.motionActivity.cycling) {
                motionType = MDMotionTypeCycling; // 5
            }
        }
    } else if (walkingCount >= 0) {
        // 2. Fallback: Speed ve walkingCount kullanarak motion type belirle
        // NOT: walkingCount == -1 ise (activity varsa), bu branch'e girme
        // 2. Fallback: Speed ve walkingCount kullanarak motion type belirle
        // isShaking = walkingCount > 0
        self.isShaking = (walkingCount > 0);
        
        double speed = self.currentSpeed;
        
        // Speed kontrolü
        if (speed == 0.0 || speed < 0.0 || kMinimumSpeed > speed) {
            // Speed çok düşük veya 0
            motionType = MDMotionTypeStationary; // 1
            if (walkingCount > 0) {
                motionType = MDMotionTypeMoving; // 7 (moving but stationary)
            }
        } else if (kMaximumWalkingSpeed >= speed) {
            // Speed <= 2.0 m/s (~7.2 km/h) - walking
            motionType = MDMotionTypeWalking; // 2
        } else if (kMaximumRunningSpeed < speed) {
            // Speed > 5.0 m/s (~18 km/h) - automotive
            motionType = MDMotionTypeAutomotive; // 4
        } else {
            // Speed 2.0-5.0 m/s arası - running veya automotive
            // motionType = (walkingCount <= 0) + 3
            // walkingCount > 0 ise: 3 (running)
            // walkingCount <= 0 ise: 4 (automotive)
            motionType = (walkingCount <= 0) ? MDMotionTypeAutomotive : MDMotionTypeRunning; // 3 or 4
        }
    }
    
    // Update motion type
    self.motionType = motionType;
    
    // CRITICAL: Orijinal SOMotionDetector pattern - isMoving hesapla
    // isMoving = motionType != 1 && motionType != 6 (stationary ve unknown değilse moving)
    // motionType 1 = MDMotionTypeStationary
    // motionType 6 = MDMotionTypeUnknown
    self.isMoving = (motionType != MDMotionTypeStationary && motionType != MDMotionTypeUnknown);
    
    // Update previousMotionType
    self.previousMotionType = motionType;
    
    // Call motionTypeChangedBlock if set (main thread'de)
    if (self.motionTypeChangedBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.motionTypeChangedBlock(self.motionType, self.shakeCount, vectorSum);
        });
    }
}

/**
 * Record accelerometer data (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector record]
 * 
 * Assembly pattern:
 * - objc_msgSend(self, sel_record) çağrılıyor
 * - Bu muhtemelen accelerometer data'sını diagnostics'e kaydetmek için kullanılıyor
 * - startShakeDetection block içinde TSQueue.sharedInstance.runInMain: ile çağrılıyor
 */
- (void)record {
    // CRITICAL: Orijinal SOMotionDetector pattern - accelerometer data'sını kaydet
    // Assembly: objc_msgSend(self, sel_record);
    // Bu muhtemelen accelerometer data'sını diagnostics'e kaydetmek için kullanılıyor
    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    entry[@"timestamp"] = @([[NSDate date] timeIntervalSince1970] * 1000);
    entry[@"acceleration"] = @{
        @"x": @(self.acceleration.x),
        @"y": @(self.acceleration.y),
        @"z": @(self.acceleration.z)
    };
    entry[@"averageVectorSum"] = @(self.averageVectorSum);
    entry[@"shakeCount"] = @(self.shakeCount);
    entry[@"isShaking"] = @(self.isShaking);
    entry[@"motionType"] = [self motionTypeName];
    
    @synchronized (self.diagnostics) {
        [self.diagnostics addObject:entry];
        // Liste çok büyümesin
        if (self.diagnostics.count > 1000) {
            [self.diagnostics removeObjectsInRange:NSMakeRange(0, self.diagnostics.count - 1000)];
        }
    }
}

- (void)appendDiagnosticsEntryWithActivity:(CMMotionActivity *)activity API_AVAILABLE(ios(7.0)) {
    if (!activity) return;

    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    entry[@"timestamp"] = @([[NSDate date] timeIntervalSince1970] * 1000);
    entry[@"motionType"] = [self motionTypeName:[self mapActivityToMotionType:activity]];
    entry[@"confidence"] = @([self motionActivityConfidence]);
    entry[@"shakeCount"] = @(self.shakeCount);
    entry[@"averageVectorSum"] = @(self.averageVectorSum);
    entry[@"isShaking"] = @(self.isShaking);

    @synchronized (self.diagnostics) {
        [self.diagnostics addObject:entry];
        // Liste çok büyümesin
        if (self.diagnostics.count > 1000) {
            [self.diagnostics removeObjectsInRange:NSMakeRange(0, self.diagnostics.count - 1000)];
        }
    }
}

#pragma mark - SOMotionDetector isMoving getter

/**
 * Get isMoving state (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector isMoving]
 * Basit getter metodu - property'yi döndürür
 */
- (BOOL)isMoving {
    // Orijinal kod: return self->isMoving;
    // Property zaten var, sadece döndür
    return _isMoving;
}

/**
 * Check if moving with activity string (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector isMoving:] (NSString *)
 * triggerActivities kontrolü için kullanılır
 * 
 * @param activityString Comma-separated activity names (e.g. "in_vehicle,walking")
 * @return YES if activityString contains current motionTypeName, NO otherwise
 */
- (BOOL)isMoving:(NSString *)activityString {
    if (!activityString || activityString.length == 0) {
        // Parametre boşsa, sadece isMoving property'sini döndür
        return self.isMoving;
    }
    
    // CRITICAL: Orijinal pattern - motionActivity varsa ve activityString length > 0 ise
    // motionTypeName'i al ve activityString içinde var mı kontrol et
    if (self.motionActivity) {
        NSString *motionTypeName = [self motionTypeName];
        if (motionTypeName && motionTypeName.length > 0) {
            // activityString içinde motionTypeName var mı kontrol et
            // Orijinal kod: [activityString containsString:motionTypeName]
            // Case-insensitive kontrol (triggerActivities genelde case-insensitive)
            NSString *lowercaseActivityString = [activityString lowercaseString];
            NSString *lowercaseMotionTypeName = [motionTypeName lowercaseString];
            
            // Comma-separated list kontrolü
            NSArray *activities = [lowercaseActivityString componentsSeparatedByString:@","];
            for (NSString *activity in activities) {
                NSString *trimmedActivity = [activity stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([trimmedActivity isEqualToString:lowercaseMotionTypeName]) {
                    return YES; // Activity eşleşti
                }
            }
            
            // Direkt contains kontrolü (fallback)
            if ([lowercaseActivityString containsString:lowercaseMotionTypeName]) {
                return YES;
            }
        }
    }
    
    // Fallback: Sadece isMoving property'sini döndür
    return self.isMoving;
}

#pragma mark - SOMotionDetector setLocation method

/**
 * Set location and isMoving state (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector setLocation:isMoving:]
 * 
 * Assembly pattern:
 * - Location retain ediliyor
 * - Eğer mevcut location yeni location'dan farklıysa:
 *   - Location'dan speed alınıyor
 *   - currentSpeed set ediliyor
 *   - location property'si set ediliyor (objc_storeStrong)
 * - Location release ediliyor
 * 
 * NOT: isMoving parametresi assembly'de kullanılmıyor, sadece location ve speed güncelleniyor
 */
- (void)setLocation:(CLLocation *)location isMoving:(BOOL)isMoving {
    // CRITICAL: Orijinal SOMotionDetector pattern - location retain
    // Assembly: v6 = objc_retain(location);
    // ARC otomatik yapıyor
    
    // CRITICAL: Orijinal pattern - location değişikliği kontrolü
    // Assembly: if (self->_location != location) { ... }
    if (self.location != location) {
        // CRITICAL: Orijinal pattern - speed alınıyor ve currentSpeed set ediliyor
        // Assembly: v4 = [location speed]; self->_currentSpeed = v4;
        self.currentSpeed = location.speed;
        
        // CRITICAL: Orijinal pattern - location property'si set ediliyor
        // Assembly: objc_storeStrong(&self->_location, location);
        self.location = location;
    }
    
    // CRITICAL: Orijinal pattern - location release
    // Assembly: objc_release(location);
    // ARC otomatik yapıyor
    
    // NOT: Assembly'de calculate() çağrılmıyor, sadece location ve speed güncelleniyor
    // calculate() muhtemelen başka bir yerde (timer veya başka bir callback'te) çağrılıyor
}

/**
 * Set motion detection interval (SOMotionDetector pattern)
 * Orijinal SOMotionDetector'dan: -[SOMotionDetector setMotionDetectionInterval:]
 * 
 * Assembly pattern:
 * - motionDetectionInterval = (int)(interval / qword_1D90)
 * - qword_1D90 muhtemelen 1.0 (birim dönüşümü için)
 * - Sonuç integer'a cast ediliyor
 */
- (void)setMotionDetectionInterval:(NSTimeInterval)interval {
    // CRITICAL: Orijinal SOMotionDetector pattern - interval hesaplaması
    // Assembly: self->motionDetectionInterval = (int)(interval / qword_1D90);
    // qword_1D90 muhtemelen 1.0 (birim dönüşümü için)
    // Sonuç integer'a cast ediliyor, ama biz NSTimeInterval (double) kullanıyoruz
    // Bu yüzden direkt interval'i set ediyoruz
    self.motionDetectionInterval = interval;
}
 
@end
  