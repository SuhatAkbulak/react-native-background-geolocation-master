//
//  MotionDetectorService.h
//  RNBackgroundLocation
//
//  SOMotionDetector benzeri motion sensör yardımcı servisi
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MDMotionType) {
    MDMotionTypeStationary = 1,
    MDMotionTypeWalking,
    MDMotionTypeRunning,
    MDMotionTypeAutomotive,
    MDMotionTypeCycling,
    MDMotionTypeUnknown,
    MDMotionTypeMoving
};

@interface MotionDetectorService : NSObject

+ (instancetype)sharedInstance;

// Sensör erişilebilirlik durumu
+ (BOOL)isAccelerometerAvailable;
+ (BOOL)isGyroAvailable;
+ (BOOL)isMagnetometerAvailable;
+ (BOOL)isDeviceMotionAvailable;
+ (BOOL)motionHardwareAvailable;

// SOMotionDetector benzeri ek state / callback'ler (basitleştirilmiş)

// Anlık ivme değeri
@property (atomic, readonly) CMAcceleration acceleration;

// Ortalama vektör toplamı (shake yoğunluğu için basit metrik)
@property (atomic, readonly) double averageVectorSum;

// Algılanan shake sayısı (oturum boyunca)
@property (atomic, readonly) NSInteger shakeCount;

// Cihaz şu anda "şiddetli hareket / shake" halinde mi?
@property (atomic, readonly) BOOL isShaking;

// CRITICAL: SOMotionDetector pattern - isMoving property
@property (atomic, readonly) BOOL isMoving;

// Accelerometer update interval (saniye)
@property (atomic, assign) NSTimeInterval accelerometerUpdateInterval;

// Hareket tipi (SOMotionDetector.motionType benzeri)
@property (atomic, readonly) MDMotionType motionType;

// CoreMotion aktivitesi (CMMotionActivity)
@property (atomic, strong, nullable, readonly) CMMotionActivity *motionActivity;

// M7 kullanımı tercih ediliyor mu (varsa)?
@property (atomic, assign) BOOL useM7IfAvailable;

// Cihazda M7 / motion coprocessor gerçekten kullanılıyor mu?
@property (atomic, readonly) BOOL usingM7;

// Motion chip için izin verilmiş mi (heuristic)
@property (atomic, readonly) BOOL M7Authorized;

// İvme değiştikçe çağrılan callback
@property (atomic, copy, nullable) void (^accelerationChangedBlock)(CMAcceleration acceleration);

// Shake state değiştikçe çağrılan callback
@property (atomic, copy, nullable) void (^shakeStateChangedBlock)(BOOL isShaking, NSInteger shakeCount, double averageVectorSum);

// Motion activity değiştikçe çağrılan callback
@property (atomic, copy, nullable) void (^motionTypeChangedBlock)(MDMotionType motionType, NSInteger shakeCount, double averageVectorSum);

// Hareket algılamayı başlat / durdur
- (void)startDetection;
- (void)stopDetection;

// Sadece shake detection için helper
- (void)startShakeDetection:(NSTimeInterval)sampleRate;
- (void)stopShakeDetection;

// SOMotionDetector benzeri yardımcılar
- (BOOL)queryMotionActivityHistory;
- (NSString *)motionTypeName;
- (NSString *)motionTypeName:(MDMotionType)motionType;
- (NSInteger)motionActivityConfidence;
- (NSArray *)getDiagnosticsData;

// CRITICAL: SOMotionDetector pattern - location ve speed güncelleme
- (void)setLocation:(CLLocation *)location isMoving:(BOOL)isMoving;

// CRITICAL: SOMotionDetector pattern - calculate motion type from history
- (void)calculate;

// CRITICAL: SOMotionDetector pattern - create motion activity changed handler block
- (void (^)(CMMotionActivity * _Nullable activity))createMotionActivityChangedHandler;

// CRITICAL: SOMotionDetector pattern - isMoving getter
- (BOOL)isMoving;

// CRITICAL: SOMotionDetector pattern - isMoving with activity string parameter
- (BOOL)isMoving:(NSString *)activityString;

// CRITICAL: SOMotionDetector pattern - set motion detection interval
- (void)setMotionDetectionInterval:(NSTimeInterval)interval;

@end

NS_ASSUME_NONNULL_END
