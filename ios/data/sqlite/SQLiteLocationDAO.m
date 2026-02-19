//
//  SQLiteLocationDAO.m
//  RNBackgroundLocation
//
//  SQLite Location DAO
//  Android SQLiteLocationDAO.java benzeri
//  CRITICAL: LOCKING mekanizması burada implement ediliyor
//

#import "SQLiteLocationDAO.h"
#import "LocationDatabase.h"
#import "LocationModel.h"
#import "LogHelper.h"
#import <sqlite3.h>

@interface SQLiteLocationDAO ()
@property (nonatomic, strong) LocationDatabase *database;
@end

@implementation SQLiteLocationDAO

+ (instancetype)sharedInstance {
    static SQLiteLocationDAO *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SQLiteLocationDAO alloc] init];
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

- (NSArray<LocationModel *> *)all {
    __block NSMutableArray<LocationModel *> *locations = [NSMutableArray array];
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "SELECT * FROM locations ORDER BY id ASC";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                LocationModel *location = [self cursorToLocation:stmt];
                if (location) {
                    [locations addObject:location];
                }
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return locations;
}

- (NSArray<LocationModel *> *)allWithLocking:(NSInteger)limit {
    __block NSMutableArray<LocationModel *> *locations = [NSMutableArray array];
    __block NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        // 1. SELECT unlocked locations
        const char *sql = "SELECT * FROM locations WHERE locked = 0 ORDER BY id ASC LIMIT ?";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_int(stmt, 1, (int)limit);
            
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                LocationModel *location = [self cursorToLocation:stmt];
                if (location) {
                    [ids addObject:@(location.id)];
                    [locations addObject:location];
                }
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
        
        // 2. LOCK them
        if (ids.count > 0) {
            NSMutableString *placeholders = [NSMutableString string];
            for (NSInteger i = 0; i < ids.count; i++) {
                if (i > 0) [placeholders appendString:@","];
                [placeholders appendString:@"?"];
            }
            
            NSString *updateSQL = [NSString stringWithFormat:@"UPDATE locations SET locked = 1 WHERE id IN (%@)", placeholders];
            sqlite3_stmt *updateStmt = NULL;
            
            if (sqlite3_prepare_v2(db, [updateSQL UTF8String], -1, &updateStmt, NULL) == SQLITE_OK) {
                for (NSInteger i = 0; i < ids.count; i++) {
                    sqlite3_bind_int64(updateStmt, (int)(i + 1), [ids[i] longLongValue]);
                }
                
                if (sqlite3_step(updateStmt) == SQLITE_DONE) {
                    int changes = sqlite3_changes(db);
                    [LogHelper d:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ Locked %d records", changes]];
                }
            }
            
            if (updateStmt) {
                sqlite3_finalize(updateStmt);
            }
        }
    }];
    
    return locations;
}

- (nullable LocationModel *)first {
    __block LocationModel *location = nil;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "SELECT * FROM locations WHERE locked = 0 ORDER BY id ASC LIMIT 1";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                location = [self cursorToLocation:stmt];
                
                if (location) {
                    // Lock it
                    const char *updateSQL = "UPDATE locations SET locked = 1 WHERE id = ?";
                    sqlite3_stmt *updateStmt = NULL;
                    
                    if (sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, NULL) == SQLITE_OK) {
                        sqlite3_bind_int64(updateStmt, 1, location.id);
                        sqlite3_step(updateStmt);
                        sqlite3_finalize(updateStmt);
                        
                        [LogHelper d:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ Locked 1 record: %@", location.uuid]];
                    }
                }
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return location;
}

- (nullable NSString *)persist:(NSDictionary *)json {
    NSString *uuid = json[@"uuid"] ?: [[NSUUID UUID] UUIDString];
    NSString *timestamp = json[@"timestamp"] ? [NSString stringWithFormat:@"%@", json[@"timestamp"]] : 
        [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970] * 1000];
    
    NSMutableDictionary *mutableJson = [json mutableCopy];
    mutableJson[@"uuid"] = uuid;
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:mutableJson options:0 error:&error];
    if (error) {
        [LogHelper e:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"❌ Failed to serialize JSON: %@", error.localizedDescription] error:error];
        return nil;
    }
    
    __block NSString *result = nil;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "INSERT INTO locations (uuid, timestamp, data, encrypted, locked) VALUES (?, ?, ?, 0, 0)";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, [uuid UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt, 2, [timestamp UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_blob(stmt, 3, [jsonData bytes], (int)[jsonData length], SQLITE_TRANSIENT);
            
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                result = uuid;
                [LogHelper d:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ INSERT: %@", uuid]];
            } else {
                [LogHelper e:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"❌ INSERT failed: %s", sqlite3_errmsg(db)]];
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return result;
}

- (NSInteger)count {
    return [self countOnlyUnlocked:NO];
}

- (NSInteger)countOnlyUnlocked:(BOOL)onlyUnlocked {
    __block NSInteger count = 0;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = onlyUnlocked ? 
            "SELECT count(*) FROM locations WHERE locked = 0" :
            "SELECT count(*) FROM locations";
        
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                count = sqlite3_column_int(stmt, 0);
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return count;
}

- (BOOL)destroy:(LocationModel *)location {
    __block BOOL success = NO;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "DELETE FROM locations WHERE id = ?";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(stmt, 1, location.id);
            
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                success = YES;
                [LogHelper d:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ DESTROY: %@", location.uuid]];
            } else {
                [LogHelper e:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"❌ DESTROY failed: %@", location.uuid]];
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return success;
}

- (void)destroyAll:(NSArray<LocationModel *> *)locations {
    if (locations.count == 0) return;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        NSMutableString *placeholders = [NSMutableString string];
        for (NSInteger i = 0; i < locations.count; i++) {
            if (i > 0) [placeholders appendString:@","];
            [placeholders appendString:@"?"];
        }
        
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM locations WHERE id IN (%@)", placeholders];
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, [sql UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            for (NSInteger i = 0; i < locations.count; i++) {
                sqlite3_bind_int64(stmt, (int)(i + 1), locations[i].id);
            }
            
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                int deleted = sqlite3_changes(db);
                if (deleted == (int)locations.count) {
                    [LogHelper i:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ DELETED: (%d records)", deleted]];
                } else {
                    [LogHelper w:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"❌ DELETE mismatch: expected %lu, deleted %d", (unsigned long)locations.count, deleted]];
                }
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
}

- (BOOL)unlock:(NSArray<LocationModel *> *)locations {
    if (locations.count == 0) return NO;
    
    __block BOOL success = NO;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        NSMutableString *placeholders = [NSMutableString string];
        for (NSInteger i = 0; i < locations.count; i++) {
            if (i > 0) [placeholders appendString:@","];
            [placeholders appendString:@"?"];
        }
        
        NSString *sql = [NSString stringWithFormat:@"UPDATE locations SET locked = 0 WHERE id IN (%@)", placeholders];
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, [sql UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            for (NSInteger i = 0; i < locations.count; i++) {
                sqlite3_bind_int64(stmt, (int)(i + 1), locations[i].id);
            }
            
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                int updated = sqlite3_changes(db);
                success = (updated == (int)locations.count);
                
                if (success) {
                    [LogHelper i:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ UNLOCKED: (%d records)", updated]];
                } else {
                    [LogHelper w:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"❌ UNLOCK mismatch: expected %lu, unlocked %d", (unsigned long)locations.count, updated]];
                }
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return success;
}

- (BOOL)unlockAll {
    __block BOOL success = NO;
    
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        const char *sql = "UPDATE locations SET locked = 0";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                int updated = sqlite3_changes(db);
                [LogHelper i:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ UNLOCKED ALL: %d records", updated]];
                success = YES;
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
        const char *sql = "DELETE FROM locations";
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                [LogHelper i:@"SQLiteLocationDAO" message:@"✅ Database cleared"];
                success = YES;
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
    
    return success;
}

- (void)prune:(NSInteger)days {
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM locations WHERE datetime(timestamp) < datetime('now', '-%ld day')", (long)days];
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, [sql UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                int deleted = sqlite3_changes(db);
                [LogHelper i:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ PRUNED: %d old records (>%ld days)", deleted, (long)days]];
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
}

- (void)shrink:(NSInteger)maxRecords {
    [_database executeInDatabaseQueue:^(sqlite3 *db) {
        NSString *sql = [NSString stringWithFormat:
            @"DELETE FROM locations WHERE id <= (SELECT id FROM (SELECT id FROM locations ORDER BY id DESC LIMIT 1 OFFSET %ld) foo)",
            (long)maxRecords];
        
        sqlite3_stmt *stmt = NULL;
        
        if (sqlite3_prepare_v2(db, [sql UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                int deleted = sqlite3_changes(db);
                if (deleted > 0) {
                    [LogHelper i:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"✅ SHRINK: deleted %d records (limit: %ld)", deleted, (long)maxRecords]];
                }
            }
        }
        
        if (stmt) {
            sqlite3_finalize(stmt);
        }
    }];
}

- (nullable LocationModel *)cursorToLocation:(sqlite3_stmt *)stmt {
    @try {
        NSInteger id = sqlite3_column_int64(stmt, 0); // id column
        const unsigned char *uuidBytes = sqlite3_column_text(stmt, 1); // uuid column
        const unsigned char *timestampBytes = sqlite3_column_text(stmt, 2); // timestamp column
        const void *dataBlob = sqlite3_column_blob(stmt, 3); // data column
        int dataLength = sqlite3_column_bytes(stmt, 3);
        
        NSString *uuid = uuidBytes ? [NSString stringWithUTF8String:(const char *)uuidBytes] : @"";
        
        // Parse JSON from BLOB
        NSData *jsonData = [NSData dataWithBytes:dataBlob length:dataLength];
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        
        if (error) {
            [LogHelper e:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"❌ Failed to parse location from cursor: %@", error.localizedDescription] error:error];
            return nil;
        }
        
        LocationModel *location = [LocationModel fromDictionary:json];
        if (location) {
            location.id = id;
            location.uuid = uuid;
        }
        
        return location;
    } @catch (NSException *exception) {
        [LogHelper e:@"SQLiteLocationDAO" message:[NSString stringWithFormat:@"❌ Exception in cursorToLocation: %@", exception.reason]];
        return nil;
    }
}

@end

