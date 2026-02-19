//
//  SQLiteLocationDAO.h
//  RNBackgroundLocation
//
//  SQLite Location DAO
//  Android SQLiteLocationDAO.java benzeri
//  CRITICAL: LOCKING mekanizması burada implement ediliyor
//

#import <Foundation/Foundation.h>
@class LocationModel;

NS_ASSUME_NONNULL_BEGIN

@interface SQLiteLocationDAO : NSObject

+ (instancetype)sharedInstance;

// Get all locations
- (NSArray<LocationModel *> *)all;

// CRITICAL: Get locations with LOCKING
// Process:
// 1. SELECT WHERE locked=0 LIMIT maxBatchSize
// 2. UPDATE SET locked=1 WHERE id IN (...)
// 3. Return locations
- (NSArray<LocationModel *> *)allWithLocking:(NSInteger)limit;

// Get first unlocked location and lock it
- (nullable LocationModel *)first;

// Insert location
- (nullable NSString *)persist:(NSDictionary *)json;

// Get count
- (NSInteger)count;
- (NSInteger)countOnlyUnlocked:(BOOL)onlyUnlocked;

// Delete location
- (BOOL)destroy:(LocationModel *)location;

// CRITICAL: Delete multiple locations (after successful sync)
- (void)destroyAll:(NSArray<LocationModel *> *)locations;

// CRITICAL: Unlock locations (for retry after failed sync)
- (BOOL)unlock:(NSArray<LocationModel *> *)locations;

// Unlock all locations
- (BOOL)unlockAll;

// Clear all locations
- (BOOL)clear;

// Prune old records
- (void)prune:(NSInteger)days;

// Shrink database to max size
- (void)shrink:(NSInteger)maxRecords;

@end

NS_ASSUME_NONNULL_END





