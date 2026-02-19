//
//  TSDeviceInfo.m
//  RNBackgroundLocation
//
//  Device Info Utility
//  Transistorsoft TSDeviceInfo.m benzeri
//

#import "TSDeviceInfo.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <CoreMotion/CoreMotion.h>

@implementation TSDeviceInfo

+ (TSDeviceInfo *)sharedInstance {
    static TSDeviceInfo *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TSDeviceInfo alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Get device model
        struct utsname systemInfo;
        uname(&systemInfo);
        _model = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        
        // Manufacturer is always Apple for iOS
        _manufacturer = @"Apple";
        
        // Platform
        _platform = @"iOS";
        
        // iOS version
        _version = [[UIDevice currentDevice] systemVersion];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return [self toDictionary:@"react-native"];
}

- (NSDictionary *)toDictionary:(NSString *)framework {
    return @{
        @"model": self.model ?: @"unknown",
        @"manufacturer": self.manufacturer ?: @"Apple",
        @"platform": self.platform ?: @"iOS",
        @"version": self.version ?: @"unknown",
        @"framework": framework ?: @"react-native"
    };
}

#pragma mark - Motion Hardware Methods

+ (BOOL)isMotionHardwareAvailable {
    CMMotionManager *motionManager = [[CMMotionManager alloc] init];
    BOOL available = motionManager.deviceMotionAvailable || 
                     motionManager.accelerometerAvailable || 
                     motionManager.gyroAvailable || 
                     motionManager.magnetometerAvailable;
    return available;
}

+ (BOOL)isDeviceMotionAvailable {
    CMMotionManager *motionManager = [[CMMotionManager alloc] init];
    return motionManager.deviceMotionAvailable;
}

+ (BOOL)isAccelerometerAvailable {
    CMMotionManager *motionManager = [[CMMotionManager alloc] init];
    return motionManager.accelerometerAvailable;
}

+ (BOOL)isGyroAvailable {
    CMMotionManager *motionManager = [[CMMotionManager alloc] init];
    return motionManager.gyroAvailable;
}

+ (BOOL)isMagnetometerAvailable {
    CMMotionManager *motionManager = [[CMMotionManager alloc] init];
    return motionManager.magnetometerAvailable;
}

@end

