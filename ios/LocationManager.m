//
//  LocationManager.m
//  RNBackgroundLocation
//
//  LocationManager wrapper - ExampleIOS/LocationManager.h pattern'ine göre
//

#import "LocationManager.h"
#import "TSWatchPositionRequest.h"
#import "TSCurrentPositionRequest.h"
#import <UIKit/UIKit.h>


@implementation LocationManager {
    CLLocationManager *_locationManager;
    NSInteger _currentAttempts;
    NSTimer *_timeoutTimer;
    NSTimer *_watchPositionTimer;
    NSTimeInterval _locationTimeout;
    BOOL _isAcquiringBackgroundTime;
    NSTimer *_preventSuspendTimer;
    UIBackgroundTaskIdentifier _preventSuspendTask;
    CLLocation *_lastLocation;
    CLLocation *_bestLocation;
    NSInteger _maxLocationAttempts;
    CLLocationDistance _distanceFilter;
    CLLocationAccuracy _desiredAccuracy;
    CLActivityType _activityType;
    BOOL _isUpdating;
    BOOL _isWatchingPosition;
    void (^_locationChangedBlock)(LocationManager*, CLLocation*, BOOL);
    void (^_errorBlock)(LocationManager*, NSError*);
    TSWatchPositionRequest *_watchRequest;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _currentAttempts = 0;
        _locationTimeout = 60.0; // Default 60 seconds
        _maxLocationAttempts = 3;
        _distanceFilter = kCLDistanceFilterNone;
        _desiredAccuracy = kCLLocationAccuracyBest;
        _activityType = CLActivityTypeOther;
        _isUpdating = NO;
        _isWatchingPosition = NO;
        _preventSuspendTask = UIBackgroundTaskInvalid;
    }
    return self;
}

- (void)dealloc {
    [self stopUpdatingLocation];
    [self stopWatchPosition];
    if (_preventSuspendTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:_preventSuspendTask];
    }
}

#pragma mark - Properties

- (NSInteger)currentAttempts {
    return _currentAttempts;
}

- (NSTimer*)timeoutTimer {
    return _timeoutTimer;
}

- (void)setTimeoutTimer:(NSTimer*)timer {
    if (_timeoutTimer) {
        [_timeoutTimer invalidate];
    }
    _timeoutTimer = timer;
}

- (NSTimer*)watchPositionTimer {
    return _watchPositionTimer;
}

- (void)setWatchPositionTimer:(NSTimer*)timer {
    if (_watchPositionTimer) {
        [_watchPositionTimer invalidate];
    }
    _watchPositionTimer = timer;
}

- (NSTimeInterval)locationTimeout {
    return _locationTimeout;
}

- (void)setLocationTimeout:(NSTimeInterval)locationTimeout {
    _locationTimeout = locationTimeout;
}

- (BOOL)isAcquiringBackgroundTime {
    return _isAcquiringBackgroundTime;
}

- (NSTimer*)preventSuspendTimer {
    return _preventSuspendTimer;
}

- (CLLocationManager*)locationManager {
    return _locationManager;
}

- (UIBackgroundTaskIdentifier)preventSuspendTask {
    return _preventSuspendTask;
}

- (CLLocation*)lastLocation {
    return _lastLocation;
}

- (CLLocation*)bestLocation {
    return _bestLocation ?: _lastLocation;
}

- (NSInteger)maxLocationAttempts {
    return _maxLocationAttempts;
}

- (void)setMaxLocationAttempts:(NSInteger)maxLocationAttempts {
    _maxLocationAttempts = maxLocationAttempts;
}

- (CLLocationDistance)distanceFilter {
    return _distanceFilter;
}

- (void)setDistanceFilter:(CLLocationDistance)distanceFilter {
    _distanceFilter = distanceFilter;
    _locationManager.distanceFilter = distanceFilter;
}

- (CLLocationAccuracy)desiredAccuracy {
    return _desiredAccuracy;
}

- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    _desiredAccuracy = desiredAccuracy;
    _locationManager.desiredAccuracy = desiredAccuracy;
}

- (CLActivityType)activityType {
    return _activityType;
}

- (void)setActivityType:(CLActivityType)activityType {
    _activityType = activityType;
    _locationManager.activityType = activityType;
}

- (BOOL)isUpdating {
    return _isUpdating;
}

- (BOOL)isWatchingPosition {
    return _isWatchingPosition;
}

- (void(^)(LocationManager*, CLLocation*, BOOL))locationChangedBlock {
    return _locationChangedBlock;
}

- (void)setLocationChangedBlock:(void(^)(LocationManager*, CLLocation*, BOOL))block {
    _locationChangedBlock = block;
}

- (void(^)(LocationManager*, NSError*))errorBlock {
    return _errorBlock;
}

- (void)setErrorBlock:(void(^)(LocationManager*, NSError*))block {
    _errorBlock = block;
}

#pragma mark - Methods

- (void)watchPosition:(TSWatchPositionRequest*)request {
    _watchRequest = request;
    _isWatchingPosition = YES;
    
    // Configure location manager
    if (request.desiredAccuracy > 0) {
        self.desiredAccuracy = request.desiredAccuracy;
    }
    
    // Start updating location
    [self startUpdatingLocation];
    
    // Setup timer for interval-based updates
    if (request.interval > 0) {
        NSTimeInterval interval = request.interval / 1000.0; // Convert ms to seconds
        _watchPositionTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                                target:self
                                                              selector:@selector(onWatchPositionTimer:)
                                                              userInfo:nil
                                                               repeats:YES];
    }
}

- (void)onWatchPositionTimer:(NSTimer*)timer {
    // Timer fires to request new location
    if (_isWatchingPosition && _locationManager.location) {
        CLLocation *location = _locationManager.location;
        [self locationManager:_locationManager didUpdateLocations:@[location]];
    }
}

- (void)stopWatchPosition {
    _isWatchingPosition = NO;
    _watchRequest = nil;
    
    if (_watchPositionTimer) {
        [_watchPositionTimer invalidate];
        _watchPositionTimer = nil;
    }
    
    [self stopUpdatingLocation];
}

- (void)requestLocation {
    _currentAttempts = 0;
    _locationManager.desiredAccuracy = _desiredAccuracy;
    _locationManager.distanceFilter = kCLDistanceFilterNone;
    
    // Request single location update
    if (@available(iOS 9.0, *)) {
        [_locationManager requestLocation];
    } else {
        // Fallback for iOS 8
        [self startUpdatingLocation:1 timeout:_locationTimeout desiredAccuracy:_desiredAccuracy];
    }
}

- (void)startUpdatingLocation {
    [self startUpdatingLocation:0 timeout:0 desiredAccuracy:_desiredAccuracy];
}

- (void)startUpdatingLocation:(NSInteger)samples {
    [self startUpdatingLocation:samples timeout:_locationTimeout desiredAccuracy:_desiredAccuracy];
}

- (void)startUpdatingLocation:(NSInteger)samples timeout:(NSTimeInterval)timeout {
    [self startUpdatingLocation:samples timeout:timeout desiredAccuracy:_desiredAccuracy];
}

- (void)startUpdatingLocation:(NSInteger)samples timeout:(NSTimeInterval)timeout desiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    _isUpdating = YES;
    _currentAttempts = 0;
    _desiredAccuracy = desiredAccuracy;
    _locationManager.desiredAccuracy = desiredAccuracy;
    _locationManager.distanceFilter = _distanceFilter;

    // Setup timeout timer if specified
    if (timeout > 0) {
        _timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                         target:self
                                                       selector:@selector(onTimeout:)
                                                       userInfo:nil
                                                        repeats:NO];
    }

    // Klasik CLLocationManager kullan
    [_locationManager startUpdatingLocation];
}

- (void)onTimeout:(NSTimer*)timer {
    [self stopUpdatingLocation];
    
    if (_errorBlock) {
        NSError *error = [NSError errorWithDomain:@"LocationManager"
                                              code:TS_LOCATION_ERROR_TIMEOUT
                                          userInfo:@{NSLocalizedDescriptionKey: @"Location request timed out"}];
        _errorBlock(self, error);
    }
}

- (void)stopUpdatingLocation {
    _isUpdating = NO;

    if (_timeoutTimer) {
        [_timeoutTimer invalidate];
        _timeoutTimer = nil;
    }

    [_locationManager stopUpdatingLocation];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = [locations lastObject];
    
    // Update last location
    _lastLocation = location;
    
    // Update best location (choose best accuracy)
    if (!_bestLocation || location.horizontalAccuracy < _bestLocation.horizontalAccuracy) {
        _bestLocation = location;
    }
    
    // Increment attempts
    _currentAttempts++;
    
    // Check if we have acceptable accuracy
    BOOL isSample = (_currentAttempts < _maxLocationAttempts && location.horizontalAccuracy > _desiredAccuracy);
    
    // Call location changed block
    if (_locationChangedBlock) {
        _locationChangedBlock(self, location, isSample);
    }
    
    // Stop if we have good enough location or reached max attempts
    if (!isSample || _currentAttempts >= _maxLocationAttempts) {
        [self stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [self stopUpdatingLocation];
    
    if (_errorBlock) {
        _errorBlock(self, error);
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    // Handle authorization changes if needed
}

@end

