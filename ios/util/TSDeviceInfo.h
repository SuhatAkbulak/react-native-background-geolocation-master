//
//  TSDeviceInfo.h
//  RNBackgroundLocation
//
//  Device Info Utility
//  Transistorsoft TSDeviceInfo.h benzeri
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sys/utsname.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSDeviceInfo : NSObject

+ (TSDeviceInfo *)sharedInstance;

@property (nonatomic, readonly) NSString *model;
@property (nonatomic, readonly) NSString *manufacturer;
@property (nonatomic, readonly) NSString *platform;
@property (nonatomic, readonly) NSString *version;

- (NSDictionary *)toDictionary;
- (NSDictionary *)toDictionary:(NSString *)framework;

// Motion hardware methods (ExampleIOS/TSLocationManager.h pattern'ine göre)
+ (BOOL)isMotionHardwareAvailable;
+ (BOOL)isDeviceMotionAvailable;
+ (BOOL)isAccelerometerAvailable;
+ (BOOL)isGyroAvailable;
+ (BOOL)isMagnetometerAvailable;

@end

NS_ASSUME_NONNULL_END
