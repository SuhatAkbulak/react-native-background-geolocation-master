//
//  LogHelper.h
//  RNBackgroundLocation
//
//  Log Helper Utility
//  Android LogHelper.java benzeri
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LogHelper : NSObject

// Debug log - sadece debug modda gözükür
+ (void)d:(NSString *)tag message:(NSString *)message;
+ (void)d:(NSString *)message;

// Info log - her zaman gözükür
+ (void)i:(NSString *)tag message:(NSString *)message;
+ (void)i:(NSString *)message;

// Warning log - her zaman gözükür
+ (void)w:(NSString *)tag message:(NSString *)message;
+ (void)w:(NSString *)message;

// Error log - her zaman gözükür
+ (void)e:(NSString *)tag message:(NSString *)message;
+ (void)e:(NSString *)message;
+ (void)e:(NSString *)tag message:(NSString *)message error:(NSError * _Nullable)error;

// Generic log method - level string ile
+ (void)log:(NSString *)level message:(NSString *)message;

// CRITICAL: iOS_PRECEDUR pattern - Orijinal log formatları
// Header log (╔═══════════════════════════════════════════════════════════)
+ (void)header:(NSString *)message;

// On log (🎾-[ClassName method])
+ (void)on:(NSString *)tag message:(NSString *)message;

// OK log (🔵-[ClassName method])
+ (void)ok:(NSString *)tag message:(NSString *)message;

// Check if debug mode is enabled
+ (BOOL)isDebugEnabled;

@end

NS_ASSUME_NONNULL_END
