//
//  LocationDatabase.m
//  RNBackgroundLocation
//
//  SQLite Database Helper
//  Android LocationOpenHelper.java benzeri
//

#import "LocationDatabase.h"
#import "LogHelper.h"

NSString *const LOCATIONS_TABLE = @"locations";
NSString *const GEOFENCES_TABLE = @"geofences";

static NSString *const DATABASE_NAME = @"background_location.db";
static const int DATABASE_VERSION = 1;

@interface LocationDatabase ()
@property (nonatomic, assign) sqlite3 *db;
@property (nonatomic, strong) NSString *databasePath;
@property (nonatomic, strong) dispatch_queue_t databaseQueue; // Serial queue for thread safety
@end

@implementation LocationDatabase

+ (instancetype)sharedInstance {
    static LocationDatabase *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LocationDatabase alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        _databasePath = [documentsDirectory stringByAppendingPathComponent:DATABASE_NAME];
        _db = NULL;
        
        // Create serial queue for thread-safe database access
        _databaseQueue = dispatch_queue_create("com.backgroundlocation.database", DISPATCH_QUEUE_SERIAL);
        
        // Open database and create tables on the queue
        dispatch_sync(_databaseQueue, ^{
            [self openDatabase];
            [self createTables];
        });
    }
    return self;
}

- (BOOL)openDatabase {
    if (_db != NULL) {
        return YES;
    }
    
    int result = sqlite3_open([_databasePath UTF8String], &_db);
    if (result != SQLITE_OK) {
        [LogHelper e:@"LocationDatabase" message:[NSString stringWithFormat:@"❌ Failed to open database: %s", sqlite3_errmsg(_db)]];
        return NO;
    }
    
    [LogHelper d:@"LocationDatabase" message:[NSString stringWithFormat:@"✅ Database opened: %@", _databasePath]];
    return YES;
}

- (void)closeDatabase {
    if (_db != NULL) {
        sqlite3_close(_db);
        _db = NULL;
    }
}

- (sqlite3 *)database {
    if (_db == NULL) {
        [self openDatabase];
    }
    return _db;
}

- (void)createTables {
    sqlite3 *db = [self database];
    if (db == NULL) return;
    
    // Locations table schema (Transistorsoft compatible)
    NSString *createLocationsTable = 
        @"CREATE TABLE IF NOT EXISTS locations ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "uuid TEXT NOT NULL DEFAULT '', "
        "timestamp TEXT, "
        "data BLOB, "                          // JSON as BLOB ()
        "encrypted INTEGER NOT NULL DEFAULT 0, "
        "locked INTEGER NOT NULL DEFAULT 0"    // CRITICAL: Locking column
        ");";
    
    // Geofences table schema
    NSString *createGeofencesTable =
        @"CREATE TABLE IF NOT EXISTS geofences ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "identifier TEXT NOT NULL UNIQUE, "
        "latitude REAL NOT NULL, "
        "longitude REAL NOT NULL, "
        "radius REAL NOT NULL, "
        "notifyOnEntry INTEGER NOT NULL DEFAULT 0, "
        "notifyOnExit INTEGER NOT NULL DEFAULT 0, "
        "notifyOnDwell INTEGER NOT NULL DEFAULT 0, "
        "loiteringDelay INTEGER NOT NULL DEFAULT 0, "
        "extras TEXT"
        ");";
    
    // Indexes for performance ()
    NSString *createLockedIndex = 
        @"CREATE INDEX IF NOT EXISTS idx_locked ON locations(locked);";
    
    NSString *createTimestampIndex =
        @"CREATE INDEX IF NOT EXISTS idx_timestamp ON locations(timestamp);";
    
    char *errorMsg = NULL;
    
    // Create tables
    if (sqlite3_exec(db, [createLocationsTable UTF8String], NULL, NULL, &errorMsg) != SQLITE_OK) {
        [LogHelper e:@"LocationDatabase" message:[NSString stringWithFormat:@"❌ Failed to create locations table: %s", errorMsg]];
        sqlite3_free(errorMsg);
    }
    
    if (sqlite3_exec(db, [createGeofencesTable UTF8String], NULL, NULL, &errorMsg) != SQLITE_OK) {
        [LogHelper e:@"LocationDatabase" message:[NSString stringWithFormat:@"❌ Failed to create geofences table: %s", errorMsg]];
        sqlite3_free(errorMsg);
    }
    
    // Create indexes
    if (sqlite3_exec(db, [createLockedIndex UTF8String], NULL, NULL, &errorMsg) != SQLITE_OK) {
        [LogHelper e:@"LocationDatabase" message:[NSString stringWithFormat:@"❌ Failed to create locked index: %s", errorMsg]];
        sqlite3_free(errorMsg);
    }
    
    if (sqlite3_exec(db, [createTimestampIndex UTF8String], NULL, NULL, &errorMsg) != SQLITE_OK) {
        [LogHelper e:@"LocationDatabase" message:[NSString stringWithFormat:@"❌ Failed to create timestamp index: %s", errorMsg]];
        sqlite3_free(errorMsg);
    }
    
    [LogHelper i:@"LocationDatabase" message:@"✅ Database tables created successfully"];
}

- (void)executeInDatabaseQueue:(void (^)(sqlite3 *db))block {
    if (block == nil) return;
    
    dispatch_sync(self.databaseQueue, ^{
        sqlite3 *db = [self database];
        if (db != NULL) {
            block(db);
        }
    });
}

- (void)dealloc {
    dispatch_sync(self.databaseQueue, ^{
        [self closeDatabase];
    });
}

@end

