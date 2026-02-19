//
//  LifecycleManager.m
//  RNBackgroundLocation
//
//  Lifecycle Manager
//  Android LifecycleManager.java benzeri
//

#import "LifecycleManager.h"
#import "LogHelper.h"
#import <UIKit/UIKit.h>

@interface LifecycleManager ()
@property (nonatomic, assign) BOOL isBackground;
@property (nonatomic, assign) BOOL isHeadless;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL isPaused;
@end

@implementation LifecycleManager

+ (instancetype)sharedInstance {
    static LifecycleManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LifecycleManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isBackground = YES;
        _isHeadless = YES;
        _isInitialized = NO;
        _isPaused = NO;
        
        // Register for app lifecycle notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        // CRITICAL: iOS_PRECEDUR pattern - Listen for app termination
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)initialize {
    if (self.isInitialized) {
        return;
    }
    
    self.isInitialized = YES;
    [LogHelper d:@"LifecycleManager" message:@"✅ LifecycleManager initialized"];
    
    // Check initial state
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateBackground) {
        self.isBackground = YES;
        self.isHeadless = YES;
    } else {
        self.isBackground = NO;
        self.isHeadless = NO;
    }
}

- (BOOL)isBackground {
    return _isBackground;
}

- (BOOL)isHeadless {
    return _isHeadless;
}

- (void)setHeadless:(BOOL)headless {
    _isHeadless = headless;
    if (headless) {
        [LogHelper d:@"LifecycleManager" message:[NSString stringWithFormat:@"☯️ HeadlessMode? %@", headless ? @"YES" : @"NO"]];
    }
    
    if ([self.delegate respondsToSelector:@selector(onHeadlessChange:)]) {
        [self.delegate onHeadlessChange:headless];
    }
}

- (void)pause {
    self.isPaused = YES;
}

- (void)resume {
    self.isPaused = NO;
}

#pragma mark - UIApplication Notifications

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [LogHelper d:@"LifecycleManager" message:@"☯️ applicationDidEnterBackground"];
    self.isBackground = YES;
    
    if ([self.delegate respondsToSelector:@selector(onStateChange:)]) {
        [self.delegate onStateChange:YES];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [LogHelper d:@"LifecycleManager" message:@"☯️ applicationWillEnterForeground"];
    self.isBackground = NO;
    self.isHeadless = NO;
    
    if ([self.delegate respondsToSelector:@selector(onStateChange:)]) {
        [self.delegate onStateChange:NO];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [LogHelper d:@"LifecycleManager" message:@"☯️ applicationDidBecomeActive"];
    if (!self.isPaused) {
        self.isBackground = NO;
        self.isHeadless = NO;
        
        if ([self.delegate respondsToSelector:@selector(onStateChange:)]) {
            [self.delegate onStateChange:NO];
        }
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [LogHelper d:@"LifecycleManager" message:@"☯️ applicationWillResignActive"];
    self.isBackground = YES;
    
    if ([self.delegate respondsToSelector:@selector(onStateChange:)]) {
        [self.delegate onStateChange:YES];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [LogHelper d:@"LifecycleManager" message:@"☯️ applicationWillTerminate"];
    
    // CRITICAL: iOS_PRECEDUR pattern - Notify delegate about app termination
    if ([self.delegate respondsToSelector:@selector(onAppTerminate)]) {
        [self.delegate onAppTerminate];
    }
}

@end

