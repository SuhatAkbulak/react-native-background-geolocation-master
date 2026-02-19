//
//  ConnectivityMonitor.m
//  RNBackgroundLocation
//
//  Connectivity Monitor
//  Android ConnectivityMonitor.java benzeri
//   network monitoring
//

#import "ConnectivityMonitor.h"
#import "TSConfig.h"
#import "ConnectivityChangeEvent.h"
#import "SyncService.h"
#import "LogHelper.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

static void reachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);

@interface ConnectivityMonitor ()
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, assign) BOOL isMonitoring;
@end

@implementation ConnectivityMonitor

+ (instancetype)sharedInstance {
    static ConnectivityMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ConnectivityMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isMonitoring = NO;
        _reachability = NULL;
    }
    return self;
}

- (void)startMonitoring {
    if (self.isMonitoring) {
        [LogHelper d:@"ConnectivityMonitor" message:@"Already monitoring connectivity"];
        return;
    }
    
    if (![self isNetworkAvailable]) {
        // Emit offline event
        [self emitConnectivityEvent:NO];
    }
    
    [LogHelper i:@"ConnectivityMonitor" message:@"📶 Start monitoring connectivity changes"];
    
    // Create reachability reference
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    self.reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    
    if (self.reachability != NULL) {
        SCNetworkReachabilityContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
        
        if (SCNetworkReachabilitySetCallback(self.reachability, reachabilityCallback, &context)) {
            if (SCNetworkReachabilityScheduleWithRunLoop(self.reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
                self.isMonitoring = YES;
                [LogHelper i:@"ConnectivityMonitor" message:@"✅ Connectivity monitor started"];
            }
        }
    }
}

- (void)stopMonitoring {
    [LogHelper i:@"ConnectivityMonitor" message:@"📵 Stop monitoring connectivity changes"];
    
    if (self.reachability != NULL) {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        SCNetworkReachabilitySetCallback(self.reachability, NULL, NULL);
        CFRelease(self.reachability);
        self.reachability = NULL;
    }
    
    self.isMonitoring = NO;
    [LogHelper i:@"ConnectivityMonitor" message:@"✅ Connectivity monitor stopped"];
}

- (BOOL)isNetworkAvailable {
    SCNetworkReachabilityFlags flags;
    if (self.reachability != NULL && SCNetworkReachabilityGetFlags(self.reachability, &flags)) {
        return (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    }
    return NO;
}

- (void)handleConnectivityChange:(BOOL)connected {
    BOOL actuallyConnected = [self isNetworkAvailable];
    
    if (connected == actuallyConnected) {
        [LogHelper i:@"ConnectivityMonitor" message:[NSString stringWithFormat:@"📶 Connectivity change: %@", actuallyConnected ? @"ONLINE" : @"OFFLINE"]];
        
        TSConfig *config = [TSConfig sharedInstance];
        
        // Emit event (Android EventBus yerine callback)
        [self emitConnectivityEvent:actuallyConnected];
        
        // Trigger auto sync if online ()
        // CRITICAL: Only sync if tracking is enabled
        if (actuallyConnected && config.enabled && config.autoSync && config.url.length > 0) {
            // Delay 1 second before syncing ()
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [LogHelper d:@"ConnectivityMonitor" message:@"🔄 Network available, triggering auto sync..."];
                [[SyncService sharedInstance] sync];
            });
        } else if (actuallyConnected && !config.enabled) {
            [LogHelper d:@"ConnectivityMonitor" message:@"⏸️ Tracking not enabled, skipping sync"];
        }
    }
}

- (void)emitConnectivityEvent:(BOOL)connected {
    TSConfig *config = [TSConfig sharedInstance];
    
    // CRITICAL: Sadece enabled=true iken connectivity event'i gönder
    // Bu, start() çağrılmadan önce connectivity event'lerini engeller
    if (!config.enabled) {
        if (config.debug) {
            [LogHelper d:@"ConnectivityMonitor" message:@"⏸️ Connectivity change ignored (enabled=false)"];
        }
        return;
    }
    
    ConnectivityChangeEvent *event = [[ConnectivityChangeEvent alloc] initWithConnected:connected];
    if (self.onConnectivityChangeCallback) {
        self.onConnectivityChangeCallback(event);
    }
}

- (void)dealloc {
    [self stopMonitoring];
}

@end

static void reachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    ConnectivityMonitor *monitor = (__bridge ConnectivityMonitor *)info;
    BOOL connected = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    [monitor handleConnectivityChange:connected];
}

