//
//  TSReachability.h
//  RNBackgroundLocation
//
//  Network Reachability
//  ExampleIOS/TSReachability.h pattern'ine göre
//  iOS_PRECEDUR pattern - 42 fonksiyon
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

//! Project version number for TSReachability.
FOUNDATION_EXPORT double TSReachabilityVersionNumber;

//! Project version string for TSReachability.
FOUNDATION_EXPORT const unsigned char TSReachabilityVersionString[];

extern NSString *const tsReachabilityChangedNotification;

typedef NS_ENUM(NSInteger, NetworkStatus) {
    // Apple NetworkStatus Compatible Names.
    NotReachable = 0,
    ReachableViaWiFi = 2,
    ReachableViaWWAN = 1
};

@class TSReachability;

typedef void (^NetworkReachable)(TSReachability * reachability);
typedef void (^NetworkUnreachable)(TSReachability * reachability);
typedef void (^NetworkReachability)(TSReachability * reachability, SCNetworkReachabilityFlags flags);

@interface TSReachability : NSObject

@property (nonatomic, copy) NetworkReachable reachableBlock;
@property (nonatomic, copy) NetworkUnreachable unreachableBlock;
@property (nonatomic, copy) NetworkReachability reachabilityBlock;
@property (nonatomic, copy) void (^reachabilityChangedBlock)(TSReachability *reachability);

@property (nonatomic, assign) BOOL reachableOnWWAN;
@property (nonatomic, assign) BOOL isMonitoring;

+ (instancetype)reachabilityWithHostname:(NSString*)hostname;
+ (instancetype)reachabilityWithHostName:(NSString*)hostname;
+ (instancetype)reachabilityForInternetConnection;
+ (instancetype)reachabilityWithAddress:(void *)hostAddress;
+ (instancetype)reachabilityForLocalWiFi;

- (instancetype)initWithReachabilityRef:(SCNetworkReachabilityRef)ref;

- (BOOL)startNotifier;
- (BOOL)startMonitoring;
- (void)stopNotifier;
- (void)stopMonitoring;

- (BOOL)isReachable;
- (BOOL)isReachableViaWWAN;
- (BOOL)isReachableViaWiFi;

// WWAN may be available, but not active until a connection has been established.
// WiFi may require a connection for VPN on Demand.
- (BOOL)isConnectionRequired;
- (BOOL)connectionRequired;
// Dynamic, on demand connection?
- (BOOL)isConnectionOnDemand;
// Is user intervention required?
- (BOOL)isInterventionRequired;

- (NetworkStatus)currentReachabilityStatus;
- (SCNetworkReachabilityFlags)reachabilityFlags;
- (NSString*)currentReachabilityString;
- (NSString*)currentReachabilityFlags;

@end

