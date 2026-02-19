//
//  TSReachability.m
//  RNBackgroundLocation
//
//  Network Reachability
//  ExampleIOS/TSReachability.h pattern'ine göre
//  iOS_PRECEDUR pattern - 42 fonksiyon
//

#import "TSReachability.h"
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import "LogHelper.h"

NSString *const tsReachabilityChangedNotification = @"TSReachabilityChangedNotification";

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
#pragma unused (target, flags)
    NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
    NSCAssert([(__bridge NSObject*) info isKindOfClass: [TSReachability class]], @"info was wrong class in ReachabilityCallback");
    
    TSReachability* noteObject = (__bridge TSReachability *)info;
    // Post a notification to notify the client that the network reachability changed.
    [[NSNotificationCenter defaultCenter] postNotificationName: tsReachabilityChangedNotification object: noteObject];
    
    // Fire block callback
    if (noteObject.reachabilityChangedBlock) {
        noteObject.reachabilityChangedBlock(noteObject);
    }
}

@interface TSReachability ()
@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;
@end

@implementation TSReachability

#pragma mark - Class Methods

+ (instancetype)reachabilityWithHostname:(NSString *)hostname {
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(NULL, [hostname UTF8String]);
    if (ref != NULL) {
        TSReachability *returnValue = [[self alloc] initWithReachabilityRef:ref];
        return returnValue;
    }
    return nil;
}

+ (instancetype)reachabilityWithHostName:(NSString *)hostname {
    return [self reachabilityWithHostname:hostname];
}

+ (instancetype)reachabilityForInternetConnection {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    return [self reachabilityWithAddress:&zeroAddress];
}

+ (instancetype)reachabilityWithAddress:(void *)hostAddress {
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)hostAddress);
    if (ref != NULL) {
        TSReachability *returnValue = [[self alloc] initWithReachabilityRef:ref];
        return returnValue;
    }
    return nil;
}

+ (instancetype)reachabilityForLocalWiFi {
    struct sockaddr_in localWifiAddress;
    bzero(&localWifiAddress, sizeof(localWifiAddress));
    localWifiAddress.sin_len = sizeof(localWifiAddress);
    localWifiAddress.sin_family = AF_INET;
    // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
    localWifiAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
    
    TSReachability *returnValue = [self reachabilityWithAddress:&localWifiAddress];
    if (returnValue != NULL) {
        returnValue.reachableOnWWAN = NO;
    }
    
    return returnValue;
}

#pragma mark - Initialization

- (instancetype)initWithReachabilityRef:(SCNetworkReachabilityRef)ref {
    self = [super init];
    if (self != NULL) {
        self.reachableOnWWAN = YES;
        self.reachabilityRef = ref;
        self.isMonitoring = NO;
    }
    return self;
}

- (void)dealloc {
    [self stopNotifier];
    if (self.reachabilityRef != NULL) {
        CFRelease(self.reachabilityRef);
    }
}

#pragma mark - Notifier Methods

- (BOOL)startNotifier {
    return [self startMonitoring];
}

- (BOOL)startMonitoring {
    if (self.isMonitoring) {
        [LogHelper d:@"TSReachability" message:@"Already monitoring reachability"];
        return YES;
    }
    
    BOOL returnValue = NO;
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    if (SCNetworkReachabilitySetCallback(self.reachabilityRef, ReachabilityCallback, &context)) {
        if (SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
            self.isMonitoring = YES;
            returnValue = YES;
            [LogHelper d:@"TSReachability" message:@"✅ Reachability monitoring started"];
        }
    }
    
    return returnValue;
}

- (void)stopNotifier {
    [self stopMonitoring];
}

- (void)stopMonitoring {
    if (!self.isMonitoring) {
        return;
    }
    
    if (self.reachabilityRef != NULL) {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
    }
    
    self.isMonitoring = NO;
    [LogHelper d:@"TSReachability" message:@"🛑 Reachability monitoring stopped"];
}

#pragma mark - Network Flag Methods

- (BOOL)isReachable {
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
            // if target host is not reachable
            return NO;
        }
        
        if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
            // if target host is reachable and no connection is required
            //  then we'll assume (for now) that your on Wi-Fi
            return YES;
        }
        
        if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
             (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
            // ... and the connection is on-demand (or on-traffic) if the
            //     calling application is using the CFSocketStream or higher APIs
            
            if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
                // ... and no [user] intervention is needed
                return YES;
            }
        }
        
        if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
            // ... but WWAN connections are OK if the calling application
            //     is using the CFNetwork (CFSocketStream?) APIs.
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isReachableViaWWAN {
    SCNetworkReachabilityFlags flags = 0;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        // Check we're REACHABLE
        if ((flags & kSCNetworkReachabilityFlagsReachable)) {
            // Now, check we're on WWAN
            if ((flags & kSCNetworkReachabilityFlagsIsWWAN)) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)isReachableViaWiFi {
    SCNetworkReachabilityFlags flags = 0;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        // Check we're REACHABLE
        if ((flags & kSCNetworkReachabilityFlagsReachable)) {
            // Now, check we're NOT on WWAN
            if ((flags & kSCNetworkReachabilityFlagsIsWWAN)) {
                return NO;
            }
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isConnectionRequired {
    return [self connectionRequired];
}

- (BOOL)connectionRequired {
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
    }
    
    return NO;
}

- (BOOL)isConnectionOnDemand {
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        return ((flags & kSCNetworkReachabilityFlagsConnectionRequired) &&
                (flags & (kSCNetworkReachabilityFlagsConnectionOnTraffic | kSCNetworkReachabilityFlagsConnectionOnDemand)));
    }
    
    return NO;
}

- (BOOL)isInterventionRequired {
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        return ((flags & kSCNetworkReachabilityFlagsConnectionRequired) &&
                (flags & kSCNetworkReachabilityFlagsInterventionRequired));
    }
    
    return NO;
}

#pragma mark - Status Methods

- (NetworkStatus)currentReachabilityStatus {
    NSAssert(self.reachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
    NetworkStatus returnValue = NotReachable;
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
            // The target host is not reachable.
            return NotReachable;
        }
        
        returnValue = ReachableViaWiFi;
        
        if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
            // If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
            returnValue = ReachableViaWiFi;
        }
        
        if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
             (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
            // ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs.
            
            if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
                // ... and no [user] intervention is needed
                returnValue = ReachableViaWiFi;
            }
        }
        
        if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
            // ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
            returnValue = ReachableViaWWAN;
        }
    }
    
    return returnValue;
}

- (SCNetworkReachabilityFlags)reachabilityFlags {
    SCNetworkReachabilityFlags flags = 0;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        return flags;
    }
    
    return 0;
}

- (NSString *)currentReachabilityString {
    NetworkStatus temp = [self currentReachabilityStatus];
    
    if (temp == ReachableViaWWAN) {
        return NSLocalizedString(@"Cellular", @"");
    }
    if (temp == ReachableViaWiFi) {
        return NSLocalizedString(@"WiFi", @"");
    }
    return NSLocalizedString(@"No Connection", @"");
}

- (NSString *)currentReachabilityFlags {
    return [NSString stringWithFormat:@"%x", [self reachabilityFlags]];
}

@end

