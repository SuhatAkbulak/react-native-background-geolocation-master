//
//  BackgroundTaskManager.m
//  RNBackgroundLocation
//
//  Background task management
//  iOS_PRECEDUR pattern - 31 fonksiyon
//  Orijinal implementasyon: BackgroundTaskManager.o (iOS_PRECEDUR)
//

#import "BackgroundTaskManager.h"
#import "LogHelper.h"

@interface BackgroundTaskManager ()
@property (nonatomic, assign) UIBackgroundTaskIdentifier preventSuspendTask;
@property (nonatomic, strong) NSTimer *preventSuspendTimer;
@property (nonatomic, strong) NSTimer *keepAliveTimer;
@property (nonatomic, assign) NSTimeInterval preventSuspendInterval;
@end

@implementation BackgroundTaskManager

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static BackgroundTaskManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BackgroundTaskManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _preventSuspendTask = UIBackgroundTaskInvalid;
        _preventSuspendInterval = 0;
        
        // Register for app lifecycle notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onSuspend:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onResume:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopPreventSuspend];
    [self stopKeepAlive];
}

#pragma mark - Background Task Methods

/**
 * Create background task
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager createBackgroundTask]
 * iOS'ta UIBackgroundTaskIdentifier kullanarak background task oluşturur
 */
- (UIBackgroundTaskIdentifier)createBackgroundTask {
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        [LogHelper d:@"BackgroundTaskManager" message:@"ℹ️ Background task already exists"];
        return self.preventSuspendTask;
    }
    
    __weak typeof(self) weakSelf = self;
    UIBackgroundTaskIdentifier oldTask = self.preventSuspendTask;
    self.preventSuspendTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [LogHelper w:@"BackgroundTaskManager" message:@"⚠️ Background task expired, creating new one"];
        
        // Stop old task
        if (oldTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:oldTask];
        }
        strongSelf.preventSuspendTask = UIBackgroundTaskInvalid;
        
        // CRITICAL: Create new task on background queue to avoid recursion
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong typeof(weakSelf) strongSelf2 = weakSelf;
            if (!strongSelf2) return;
            
            // Create new task
            UIBackgroundTaskIdentifier newTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                // If this one expires too, just end it (don't recurse)
                [[UIApplication sharedApplication] endBackgroundTask:newTask];
            }];
            
            if (newTask != UIBackgroundTaskInvalid) {
                strongSelf2.preventSuspendTask = newTask;
                [LogHelper d:@"BackgroundTaskManager" message:[NSString stringWithFormat:@"✅ New background task created: %lu", (unsigned long)newTask]];
            }
        });
    }];
    
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        [LogHelper d:@"BackgroundTaskManager" message:[NSString stringWithFormat:@"✅ Background task created: %lu", (unsigned long)self.preventSuspendTask]];
    } else {
        [LogHelper w:@"BackgroundTaskManager" message:@"⚠️ Failed to create background task"];
    }
    
    return self.preventSuspendTask;
}

/**
 * Stop background task
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager stopBackgroundTask:]
 */
- (void)stopBackgroundTask:(UIBackgroundTaskIdentifier)taskId {
    if (taskId != UIBackgroundTaskInvalid) {
        [LogHelper d:@"BackgroundTaskManager" message:[NSString stringWithFormat:@"🛑 Stopping background task: %lu", (unsigned long)taskId]];
        [[UIApplication sharedApplication] endBackgroundTask:taskId];
        
        if (taskId == self.preventSuspendTask) {
            self.preventSuspendTask = UIBackgroundTaskInvalid;
        }
    }
}

#pragma mark - Prevent Suspend Methods

/**
 * Start prevent suspend
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager startPreventSuspend:]
 * iOS'ta uygulamanın suspend edilmesini önlemek için timer kullanır
 * CRITICAL: iOS background task limit'i ~30 saniye, bu yüzden timer ile sürekli yenilemek gerekiyor
 */
- (void)startPreventSuspend:(NSTimeInterval)interval {
    [self stopPreventSuspend];
    
    self.preventSuspendInterval = interval;
    
    // Create initial background task
    [self createBackgroundTask];
    
    // CRITICAL: Start timer to keep app alive and recreate background tasks
    // Timer interval should be less than 30 seconds to prevent expiration
    NSTimeInterval timerInterval = MIN(interval, 25.0); // Max 25 seconds to prevent expiration
    
    __weak typeof(self) weakSelf = self;
    self.preventSuspendTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval
                                                                 repeats:YES
                                                                   block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf onPreventSuspendTimer:timer];
    }];
    
    [LogHelper d:@"BackgroundTaskManager" message:[NSString stringWithFormat:@"✅ Prevent suspend started (interval: %.1fs, timer: %.1fs)", interval, timerInterval]];
}

/**
 * Stop prevent suspend
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager stopPreventSuspend]
 */
- (void)stopPreventSuspend {
    if (self.preventSuspendTimer) {
        [self.preventSuspendTimer invalidate];
        self.preventSuspendTimer = nil;
    }
    
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        [self stopBackgroundTask:self.preventSuspendTask];
    }
    
    [LogHelper d:@"BackgroundTaskManager" message:@"🛑 Prevent suspend stopped"];
}

/**
 * Prevent suspend timer callback
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager onPreventSuspendTimer:]
 * CRITICAL: Proactively recreate background task before expiration
 */
- (void)onPreventSuspendTimer:(NSTimer *)timer {
    // CRITICAL: Proactively recreate background task before expiration
    // iOS background tasks expire after ~30 seconds, so we recreate them every 25 seconds
    UIBackgroundTaskIdentifier oldTask = self.preventSuspendTask;
    
    // Create new background task
    __weak typeof(self) weakSelf = self;
    self.preventSuspendTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [LogHelper w:@"BackgroundTaskManager" message:@"⚠️ Background task expired in timer"];
        [[UIApplication sharedApplication] endBackgroundTask:strongSelf.preventSuspendTask];
        strongSelf.preventSuspendTask = UIBackgroundTaskInvalid;
    }];
    
    // End old task if valid
    if (oldTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:oldTask];
    }
    
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        [LogHelper d:@"BackgroundTaskManager" message:[NSString stringWithFormat:@"✅ Background task refreshed: %lu", (unsigned long)self.preventSuspendTask]];
    }
}

#pragma mark - Keep Alive Methods

/**
 * Start keep alive
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager startKeepAlive]
 * iOS'ta uygulamayı canlı tutmak için timer kullanır
 */
- (void)startKeepAlive {
    [self stopKeepAlive];
    
    // Create background task
    [self createBackgroundTask];
    
    // Start timer to keep app alive (every 30 seconds)
    __weak typeof(self) weakSelf = self;
    self.keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                          repeats:YES
                                                            block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // Recreate background task to keep app alive
        if (strongSelf.preventSuspendTask == UIBackgroundTaskInvalid) {
            [strongSelf createBackgroundTask];
        }
    }];
    
    [LogHelper d:@"BackgroundTaskManager" message:@"✅ Keep alive started"];
}

/**
 * Stop keep alive
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager stopKeepAlive]
 */
- (void)stopKeepAlive {
    if (self.keepAliveTimer) {
        [self.keepAliveTimer invalidate];
        self.keepAliveTimer = nil;
    }
    
    [LogHelper d:@"BackgroundTaskManager" message:@"🛑 Keep alive stopped"];
}

#pragma mark - Lifecycle Methods

/**
 * On suspend
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager onSuspend:]
 */
- (void)onSuspend:(NSNotification *)notification {
    [LogHelper d:@"BackgroundTaskManager" message:@"☯️ App entered background"];
    
    // Create background task if prevent suspend is enabled
    if (self.preventSuspendInterval > 0) {
        [self createBackgroundTask];
    }
}

/**
 * On resume
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager onResume:]
 */
- (void)onResume:(NSNotification *)notification {
    [LogHelper d:@"BackgroundTaskManager" message:@"☯️ App entered foreground"];
    
    // Stop background task when app comes to foreground
    if (self.preventSuspendTask != UIBackgroundTaskInvalid) {
        [self stopBackgroundTask:self.preventSuspendTask];
    }
}

#pragma mark - Utility Methods

/**
 * Acquire background time
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager acquireBackgroundTime]
 * iOS'ta background time kazanmak için location manager kullanır
 */
- (void)acquireBackgroundTime {
    // iOS'ta background time kazanmak için location manager kullanılabilir
    // Bu metod location manager'ı kullanarak background time kazanır
    if (self.locationManager) {
        // Location manager zaten background time sağlıyor
        [LogHelper d:@"BackgroundTaskManager" message:@"✅ Background time acquired via location manager"];
    } else {
        // Create background task as fallback
        [self createBackgroundTask];
    }
}

/**
 * Please stay awake
 * iOS_PRECEDUR pattern: -[BackgroundTaskManager pleaseStayAwake]
 * iOS'ta uygulamayı uyanık tutmak için background task oluşturur
 */
- (void)pleaseStayAwake {
    [self createBackgroundTask];
}

#pragma mark - Getters

- (UIBackgroundTaskIdentifier)bgTask {
    return self.preventSuspendTask;
}

@end

