//
//  LogHelper.m
//  RNBackgroundLocation
//
//  Log Helper Utility
//  Android LogHelper.java benzeri
//

#import "LogHelper.h"
#import "TSConfig.h"

static NSString *const DEFAULT_TAG = @"BackgroundLocation";

@implementation LogHelper

+ (void)d:(NSString *)tag message:(NSString *)message {
    if ([self isDebugEnabled]) {
        NSLog(@"[DEBUG] [%@] %@", tag, message);
    }
}

+ (void)d:(NSString *)message {
    [self d:DEFAULT_TAG message:message];
}

+ (void)i:(NSString *)tag message:(NSString *)message {
    NSLog(@"[INFO] [%@] %@", tag, message);
}

+ (void)i:(NSString *)message {
    [self i:DEFAULT_TAG message:message];
}

+ (void)w:(NSString *)tag message:(NSString *)message {
    NSLog(@"[WARN] [%@] %@", tag, message);
}

+ (void)w:(NSString *)message {
    [self w:DEFAULT_TAG message:message];
}

+ (void)e:(NSString *)tag message:(NSString *)message {
    NSLog(@"[ERROR] [%@] %@", tag, message);
}

+ (void)e:(NSString *)message {
    [self e:DEFAULT_TAG message:message];
}

+ (void)e:(NSString *)tag message:(NSString *)message error:(NSError *)error {
    if (error) {
        NSLog(@"[ERROR] [%@] %@ - Error: %@", tag, message, error.localizedDescription);
    } else {
        [self e:tag message:message];
    }
}

+ (void)log:(NSString *)level message:(NSString *)message {
    NSString *upperLevel = [level uppercaseString];
    if ([upperLevel isEqualToString:@"DEBUG"]) {
        [self d:message];
    } else if ([upperLevel isEqualToString:@"INFO"]) {
        [self i:message];
    } else if ([upperLevel isEqualToString:@"WARN"] || [upperLevel isEqualToString:@"WARNING"]) {
        [self w:message];
    } else if ([upperLevel isEqualToString:@"ERROR"]) {
        [self e:message];
    } else {
        // Default to info
        [self i:message];
    }
}

// CRITICAL: iOS_PRECEDUR pattern - Orijinal log formatları
+ (void)header:(NSString *)message {
    NSLog(@"╔═══════════════════════════════════════════════════════════");
    NSLog(@"║ %@", message);
    NSLog(@"╚═══════════════════════════════════════════════════════════");
}

+ (void)on:(NSString *)tag message:(NSString *)message {
    NSLog(@"🎾-[%@] %@", tag, message);
}

+ (void)ok:(NSString *)tag message:(NSString *)message {
    NSLog(@"🔵-[%@] %@", tag, message);
}

+ (BOOL)isDebugEnabled {
    TSConfig *config = [TSConfig sharedInstance];
    return config.debug;
}

@end

