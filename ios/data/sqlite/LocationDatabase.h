//
//  LocationDatabase.h
//  RNBackgroundLocation
//
//  SQLite Database Helper
//  Android LocationOpenHelper.java benzeri
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const LOCATIONS_TABLE;
extern NSString *const GEOFENCES_TABLE;

@interface LocationDatabase : NSObject

+ (instancetype)sharedInstance;
- (sqlite3 *)database;
- (BOOL)openDatabase;
- (void)closeDatabase;

// Thread-safe database operations
- (void)executeInDatabaseQueue:(void (^)(sqlite3 *db))block;

@end

NS_ASSUME_NONNULL_END

