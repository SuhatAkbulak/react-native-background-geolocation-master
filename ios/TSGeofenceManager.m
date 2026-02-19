//
//  TSGeofenceManager.m
//  RNBackgroundLocation
//
//  Geofence Manager - ExampleIOS/TSGeofenceManager.h pattern'ine göre
//

#import "TSGeofenceManager.h"
#import "TSGeofence.h"
#import "TSLocation.h"
#import "event/TSGeofenceEvent.h"
#import "event/TSGeofencesChangeEvent.h"
#import "data/sqlite/SQLiteGeofenceDAO.h"
#import "data/GeofenceModel.h"
#import <CoreLocation/CoreLocation.h>

NSString *const STATIONARY_REGION_IDENTIFIER = @"TSLocationManager.stationary";

@implementation TSGeofenceManager {
    CLLocationManager *_locationManager;
    BOOL _isMoving;
    BOOL _enabled;
    BOOL _evaluated;
    BOOL _isUpdatingLocation;
    BOOL _isEvaluatingEvents;
    BOOL _isRequestingLocation;
    BOOL _isMonitoringSignificantChanges;
    BOOL _willEvaluateProximity;
    CLLocation *_lastLocation;
    NSMutableArray *_geofencesChangeListeners;
    NSMutableArray *_geofenceListeners;
    NSMutableDictionary *_monitoredRegions; // identifier -> CLCircularRegion
    SQLiteGeofenceDAO *_database;
    void (^_onGeofence)(TSGeofenceEvent*);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _geofencesChangeListeners = [NSMutableArray array];
        _geofenceListeners = [NSMutableArray array];
        _monitoredRegions = [NSMutableDictionary dictionary];
        _database = [SQLiteGeofenceDAO sharedInstance];
        _enabled = NO;
        _evaluated = NO;
        _isUpdatingLocation = NO;
        _isEvaluatingEvents = NO;
        _isRequestingLocation = NO;
        _isMonitoringSignificantChanges = NO;
        _willEvaluateProximity = NO;
    }
    return self;
}

#pragma mark - Properties

- (void)setOnGeofence:(void (^)(TSGeofenceEvent*))block {
    _onGeofence = block;
}

- (void (^)(TSGeofenceEvent*))onGeofence {
    return _onGeofence;
}

- (BOOL)isMoving {
    return _isMoving;
}

- (void)setIsMoving:(BOOL)isMoving {
    _isMoving = isMoving;
}

- (BOOL)enabled {
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
}

- (BOOL)evaluated {
    return _evaluated;
}

- (void)setEvaluated:(BOOL)evaluated {
    _evaluated = evaluated;
}

- (BOOL)isUpdatingLocation {
    return _isUpdatingLocation;
}

- (void)setIsUpdatingLocation:(BOOL)isUpdatingLocation {
    _isUpdatingLocation = isUpdatingLocation;
}

- (BOOL)isEvaluatingEvents {
    return _isEvaluatingEvents;
}

- (void)setIsEvaluatingEvents:(BOOL)isEvaluatingEvents {
    _isEvaluatingEvents = isEvaluatingEvents;
}

- (BOOL)isRequestingLocation {
    return _isRequestingLocation;
}

- (void)setIsRequestingLocation:(BOOL)isRequestingLocation {
    _isRequestingLocation = isRequestingLocation;
}

- (BOOL)isMonitoringSignificantChanges {
    return _isMonitoringSignificantChanges;
}

- (void)setIsMonitoringSignificantChanges:(BOOL)isMonitoringSignificantChanges {
    _isMonitoringSignificantChanges = isMonitoringSignificantChanges;
}

- (BOOL)willEvaluateProximity {
    return _willEvaluateProximity;
}

- (void)setWillEvaluateProximity:(BOOL)willEvaluateProximity {
    _willEvaluateProximity = willEvaluateProximity;
}

- (CLLocation*)lastLocation {
    return _lastLocation;
}

- (void)setLastLocation:(CLLocation*)location {
    _lastLocation = location;
}

- (NSMutableArray*)geofencesChangeListeners {
    return _geofencesChangeListeners;
}

- (NSMutableArray*)geofenceListeners {
    return _geofenceListeners;
}

#pragma mark - Event Listeners

- (void)onGeofencesChange:(void (^)(TSGeofencesChangeEvent*))success {
    if (success) {
        [_geofencesChangeListeners addObject:success];
    }
}

- (void)onGeofence:(void (^)(TSGeofenceEvent*))success {
    if (success) {
        [_geofenceListeners addObject:success];
    }
}

- (void)un:(NSString*)event callback:(void(^)(id))callback {
    if ([event isEqualToString:@"geofenceschange"]) {
        [_geofencesChangeListeners removeObject:callback];
    } else if ([event isEqualToString:@"geofence"]) {
        [_geofenceListeners removeObject:callback];
    }
}

- (void)removeListeners {
    [_geofencesChangeListeners removeAllObjects];
    [_geofenceListeners removeAllObjects];
}

#pragma mark - Methods

- (void)start {
    _enabled = YES;
    // Load geofences from database and start monitoring
    [self loadAndMonitorGeofences];
}

- (void)stop {
    _enabled = NO;
    // Stop monitoring all regions
    for (CLCircularRegion *region in _monitoredRegions.allValues) {
        [_locationManager stopMonitoringForRegion:region];
    }
    [_monitoredRegions removeAllObjects];
}

- (void)ready {
    // Initialize geofence manager
    [self loadAndMonitorGeofences];
}

- (void)setLocation:(CLLocation*)location isMoving:(BOOL)isMoving {
    _lastLocation = location;
    _isMoving = isMoving;
    
    if (_enabled && location) {
        [self evaluateProximityForLocation:location];
    }
}

- (void)setProximityRadius:(CLLocationDistance)radius {
    // Update proximity radius for all monitored regions
    // This is typically handled by re-creating regions with new radius
}

- (BOOL)isMonitoringRegion:(CLCircularRegion*)region {
    return [_monitoredRegions objectForKey:region.identifier] != nil;
}

- (void)didBecomeStationary:(CLLocation*)location {
    // Create stationary region
    CLCircularRegion *stationaryRegion = [[CLCircularRegion alloc] initWithCenter:location.coordinate
                                                                           radius:25.0 // Default stationary radius
                                                                       identifier:STATIONARY_REGION_IDENTIFIER];
    [_locationManager startMonitoringForRegion:stationaryRegion];
    [_monitoredRegions setObject:stationaryRegion forKey:STATIONARY_REGION_IDENTIFIER];
}

- (NSString*)identifierFor:(CLCircularRegion*)region {
    return region.identifier;
}

- (void)create:(NSArray*)geofences success:(void (^)(void))success failure:(void (^)(NSString*))failure {
    NSMutableArray *created = [NSMutableArray array];
    NSMutableArray *errors = [NSMutableArray array];
    
    for (TSGeofence *geofence in geofences) {
        // Save to database
        GeofenceModel *model = [[GeofenceModel alloc] init];
        model.identifier = geofence.identifier;
        model.latitude = geofence.latitude;
        model.longitude = geofence.longitude;
        model.radius = geofence.radius;
        model.notifyOnEntry = geofence.notifyOnEntry;
        model.notifyOnExit = geofence.notifyOnExit;
        model.notifyOnDwell = geofence.notifyOnDwell;
        model.loiteringDelay = (NSInteger)(geofence.loiteringDelay * 1000); // Convert to milliseconds
        
        if ([_database persist:model]) {
            // Start monitoring region
            CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(geofence.latitude, geofence.longitude)
                                                                         radius:geofence.radius
                                                                     identifier:geofence.identifier];
            [_locationManager startMonitoringForRegion:region];
            [_monitoredRegions setObject:region forKey:geofence.identifier];
            [created addObject:geofence];
        } else {
            [errors addObject:geofence.identifier];
        }
    }
    
    if (errors.count > 0 && failure) {
        failure([errors componentsJoinedByString:@", "]);
    } else if (success) {
        success();
    }
}

- (void)destroy:(NSArray*)identifiers success:(void (^)(void))success failure:(void (^)(NSString*))failure {
    NSMutableArray *errors = [NSMutableArray array];
    
    for (NSString *identifier in identifiers) {
        // Remove from database
        GeofenceModel *model = [_database get:identifier];
        if (model && [_database destroy:identifier]) {
            // Stop monitoring region
            CLCircularRegion *region = [_monitoredRegions objectForKey:identifier];
            if (region) {
                [_locationManager stopMonitoringForRegion:region];
                [_monitoredRegions removeObjectForKey:identifier];
            }
        } else {
            [errors addObject:identifier];
        }
    }
    
    if (errors.count > 0 && failure) {
        failure([errors componentsJoinedByString:@", "]);
    } else if (success) {
        success();
    }
}

- (BOOL)isInfiniteMonitoring {
    // iOS can monitor up to 20 regions
    return _monitoredRegions.count >= 20;
}

#pragma mark - Private Methods

- (void)loadAndMonitorGeofences {
    // Load geofences from database
    NSArray *geofences = [_database all];
    
    for (GeofenceModel *model in geofences) {
        CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(model.latitude, model.longitude)
                                                                     radius:model.radius
                                                                 identifier:model.identifier];
        [_locationManager startMonitoringForRegion:region];
        [_monitoredRegions setObject:region forKey:model.identifier];
    }
}

- (void)evaluateProximityForLocation:(CLLocation*)location {
    // Evaluate proximity to all geofences
    // This is typically handled by CLLocationManager delegate methods
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    if (!_enabled) return;
    
    // Find geofence model
    GeofenceModel *model = [_database get:region.identifier];
    if (!model || !model.notifyOnEntry) return;
    
    // Create TSGeofence from model
    TSGeofence *tsGeofence = [[TSGeofence alloc] initWithIdentifier:model.identifier
                                                               radius:model.radius
                                                             latitude:model.latitude
                                                            longitude:model.longitude
                                                        notifyOnEntry:model.notifyOnEntry
                                                         notifyOnExit:model.notifyOnExit
                                                        notifyOnDwell:model.notifyOnDwell
                                                       loiteringDelay:model.loiteringDelay / 1000.0];
    
    // Create TSLocation from lastLocation
    TSLocation *tsLocation = nil;
    if (_lastLocation) {
        tsLocation = [[TSLocation alloc] initWithLocation:_lastLocation type:TS_LOCATION_TYPE_GEOFENCE extras:nil];
    }
    
    // Create TSGeofenceEvent
    TSGeofenceEvent *tsEvent = [[TSGeofenceEvent alloc] initWithGeofence:tsGeofence action:@"ENTER"];
    if (tsLocation) {
        [tsEvent setLocation:tsLocation];
    }
    
    // Fire event
    if (_onGeofence) {
        _onGeofence(tsEvent);
    }
    
    for (void (^listener)(TSGeofenceEvent*) in _geofenceListeners) {
        listener(tsEvent);
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    if (!_enabled) return;
    
    // Find geofence model
    GeofenceModel *model = [_database get:region.identifier];
    if (!model || !model.notifyOnExit) return;
    
    // Create TSGeofence from model
    TSGeofence *tsGeofence = [[TSGeofence alloc] initWithIdentifier:model.identifier
                                                               radius:model.radius
                                                             latitude:model.latitude
                                                            longitude:model.longitude
                                                        notifyOnEntry:model.notifyOnEntry
                                                         notifyOnExit:model.notifyOnExit
                                                        notifyOnDwell:model.notifyOnDwell
                                                       loiteringDelay:model.loiteringDelay / 1000.0];
    
    // Create TSLocation from lastLocation
    TSLocation *tsLocation = nil;
    if (_lastLocation) {
        tsLocation = [[TSLocation alloc] initWithLocation:_lastLocation type:TS_LOCATION_TYPE_GEOFENCE extras:nil];
    }
    
    // Create TSGeofenceEvent
    TSGeofenceEvent *tsEvent = [[TSGeofenceEvent alloc] initWithGeofence:tsGeofence action:@"EXIT"];
    if (tsLocation) {
        [tsEvent setLocation:tsLocation];
    }
    
    // Fire event
    if (_onGeofence) {
        _onGeofence(tsEvent);
    }
    
    for (void (^listener)(TSGeofenceEvent*) in _geofenceListeners) {
        listener(tsEvent);
    }
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    // Handle monitoring failure
}

@end

