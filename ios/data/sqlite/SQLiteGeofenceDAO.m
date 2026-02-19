//
//  SQLiteGeofenceDAO.m
//  RNBackgroundLocation
//
//  SQLite Geofence DAO
//  Android SQLiteGeofenceDAO.java benzeri
//

#import "SQLiteGeofenceDAO.h"
#import "LocationDatabase.h"
#import "GeofenceModel.h"
#import "LogHelper.h"
#import <sqlite3.h>

@interface SQLiteGeofenceDAO ()
@property (nonatomic, strong) LocationDatabase *database;
@end

@implementation SQLiteGeofenceDAO

+ (instancetype)sharedInstance {
    static SQLiteGeofenceDAO *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SQLiteGeofenceDAO alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _database = [LocationDatabase sharedInstance];
    }
    return self;
}

- (NSArray<GeofenceModel *> *)all {
    __block NSMutableArray<GeofenceModel *> *geofences = [NSMutableArray array];
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "SELECT * FROM geofences ORDER BY id ASC";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                GeofenceModel *geofence = [self cursorToGeofence:stmt];
                if (geofence) {
                    [geofences addObject:geofence];
                }
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return geofences;
}

- (nullable GeofenceModel *)get:(NSString *)identifier {
    __block GeofenceModel *geofence = nil;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "SELECT * FROM geofences WHERE identifier = ? LIMIT 1";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, [identifier UTF8String], -1, SQLITE_TRANSIENT);
            
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                geofence = [self cursorToGeofence:stmt];
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return geofence;
}

- (BOOL)persist:(GeofenceModel *)geofence {
    __block BOOL success = NO;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "INSERT OR REPLACE INTO geofences (identifier, latitude, longitude, radius, notifyOnEntry, notifyOnExit, notifyOnDwell, loiteringDelay, extras) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, [geofence.identifier UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_double(stmt, 2, geofence.latitude);
            sqlite3_bind_double(stmt, 3, geofence.longitude);
            sqlite3_bind_double(stmt, 4, geofence.radius);
            sqlite3_bind_int(stmt, 5, geofence.notifyOnEntry ? 1 : 0);
            sqlite3_bind_int(stmt, 6, geofence.notifyOnExit ? 1 : 0);
            sqlite3_bind_int(stmt, 7, geofence.notifyOnDwell ? 1 : 0);
            sqlite3_bind_int64(stmt, 8, geofence.loiteringDelay);
            
            NSString *extras = geofence.extras ?: @"";
            sqlite3_bind_text(stmt, 9, [extras UTF8String], -1, SQLITE_TRANSIENT);
            
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                success = YES;
                [LogHelper d:@"SQLiteGeofenceDAO" message:[NSString stringWithFormat:@"✅ INSERT/REPLACE geofence: %@", geofence.identifier]];
            } else {
                [LogHelper e:@"SQLiteGeofenceDAO" message:[NSString stringWithFormat:@"❌ INSERT/REPLACE failed: %s", sqlite3_errmsg(db)]];
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return success;
}

- (BOOL)destroy:(NSString *)identifier {
    __block BOOL success = NO;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "DELETE FROM geofences WHERE identifier = ?";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, [identifier UTF8String], -1, SQLITE_TRANSIENT);
            
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                success = YES;
                [LogHelper d:@"SQLiteGeofenceDAO" message:[NSString stringWithFormat:@"✅ DESTROY geofence: %@", identifier]];
            } else {
                [LogHelper e:@"SQLiteGeofenceDAO" message:[NSString stringWithFormat:@"❌ DESTROY failed: %@", identifier]];
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return success;
}

- (BOOL)clear {
    __block BOOL success = NO;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "DELETE FROM geofences";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                success = YES;
                [LogHelper i:@"SQLiteGeofenceDAO" message:@"✅ Database geofences cleared"];
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return success;
}

- (BOOL)exists:(NSString *)identifier {
    __block BOOL exists = NO;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "SELECT COUNT(*) FROM geofences WHERE identifier = ?";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, [identifier UTF8String], -1, SQLITE_TRANSIENT);
            
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                int count = sqlite3_column_int(stmt, 0);
                exists = (count > 0);
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return exists;
}

- (nullable GeofenceModel *)cursorToGeofence:(sqlite3_stmt *)stmt {
    @try {
        NSInteger id = sqlite3_column_int64(stmt, 0); // id column
        const unsigned char *identifierBytes = sqlite3_column_text(stmt, 1); // identifier column
        double latitude = sqlite3_column_double(stmt, 2); // latitude column
        double longitude = sqlite3_column_double(stmt, 3); // longitude column
        double radius = sqlite3_column_double(stmt, 4); // radius column
        BOOL notifyOnEntry = sqlite3_column_int(stmt, 5) != 0; // notifyOnEntry column
        BOOL notifyOnExit = sqlite3_column_int(stmt, 6) != 0; // notifyOnExit column
        BOOL notifyOnDwell = sqlite3_column_int(stmt, 7) != 0; // notifyOnDwell column
        NSInteger loiteringDelay = sqlite3_column_int64(stmt, 8); // loiteringDelay column
        const unsigned char *extrasBytes = sqlite3_column_text(stmt, 9); // extras column
        
        NSString *identifier = identifierBytes ? [NSString stringWithUTF8String:(const char *)identifierBytes] : @"";
        NSString *extras = extrasBytes ? [NSString stringWithUTF8String:(const char *)extrasBytes] : nil;
        
        GeofenceModel *geofence = [[GeofenceModel alloc] init];
        geofence.id = id;
        geofence.identifier = identifier;
        geofence.latitude = latitude;
        geofence.longitude = longitude;
        geofence.radius = radius;
        geofence.notifyOnEntry = notifyOnEntry;
        geofence.notifyOnExit = notifyOnExit;
        geofence.notifyOnDwell = notifyOnDwell;
        geofence.loiteringDelay = loiteringDelay;
        geofence.extras = extras;
        
        return geofence;
    } @catch (NSException *exception) {
        [LogHelper e:@"SQLiteGeofenceDAO" message:[NSString stringWithFormat:@"❌ Exception in cursorToGeofence: %@", exception.reason]];
        return nil;
    }
}

@end

