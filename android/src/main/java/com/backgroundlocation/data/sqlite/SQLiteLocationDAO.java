package com.backgroundlocation.data.sqlite;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.text.TextUtils;
import android.util.Log;

import com.backgroundlocation.data.LocationModel;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * SQLite Location DAO
 * RAW SQLite operations
 * CRITICAL: LOCKING mekanizması burada implement ediliyor
 */
public class SQLiteLocationDAO {
    
    private static final String TAG = "SQLiteLocationDAO";
    private static SQLiteLocationDAO instance;
    private Context context;
    
    private SQLiteLocationDAO(Context context) {
        this.context = context.getApplicationContext();
    }
    
    public static synchronized SQLiteLocationDAO getInstance(Context context) {
        if (instance == null) {
            instance = new SQLiteLocationDAO(context);
        }
        return instance;
    }
    
    /**
     * Get all locations
     */
    public List<LocationModel> all() {
        List<LocationModel> locations = new ArrayList<>();
        SQLiteDatabase db = getDatabase();
        if (db == null) return locations;
        
        Cursor cursor = null;
        try {
            cursor = db.query(
                LocationOpenHelper.LOCATIONS_TABLE,
                null, // all columns
                null, // no where
                null,
                null,
                null,
                "id ASC",
                null
            );
            
            while (cursor.moveToNext()) {
                LocationModel location = cursorToLocation(cursor);
                if (location != null) {
                    locations.add(location);
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error fetching all locations: " + e.getMessage());
        } finally {
            if (cursor != null) cursor.close();
        }
        
        return locations;
    }
    
    /**
     * CRITICAL: Get locations with LOCKING
     * :
     * 1. SELECT WHERE locked=0 LIMIT maxBatchSize
     * 2. UPDATE SET locked=1 WHERE id IN (...)
     * 3. Return locations
     */
    public List<LocationModel> allWithLocking(int limit) {
        List<LocationModel> locations = new ArrayList<>();
        SQLiteDatabase db = getDatabase();
        if (db == null) return locations;
        
        Cursor cursor = null;
        try {
            // 1. SELECT unlocked locations
            cursor = db.query(
                LocationOpenHelper.LOCATIONS_TABLE,
                null,
                "locked=0", // WHERE locked=0
                null,
                null,
                null,
                "id ASC",
                limit > 0 ? String.valueOf(limit) : null
            );
            
            List<Integer> ids = new ArrayList<>();
            
            // 2. Collect IDs and locations
            while (cursor.moveToNext()) {
                LocationModel location = cursorToLocation(cursor);
                if (location != null) {
                    ids.add(location.id);
                    locations.add(location);
                }
            }
            
            // 3. LOCK them
            if (!ids.isEmpty()) {
                ContentValues values = new ContentValues();
                values.put("locked", 1);
                
                String whereClause = "id IN (" + TextUtils.join(",", ids) + ")";
                int updated = db.update(LocationOpenHelper.LOCATIONS_TABLE, values, whereClause, null);
                
                Log.d(TAG, "✅ Locked " + updated + " records");
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error in allWithLocking: " + e.getMessage());
        } finally {
            if (cursor != null) cursor.close();
        }
        
        return locations;
    }
    
    /**
     * Get first unlocked location and lock it
     */
    public LocationModel first() {
        SQLiteDatabase db = getDatabase();
        if (db == null) return null;
        
        Cursor cursor = null;
        try {
            cursor = db.query(
                LocationOpenHelper.LOCATIONS_TABLE,
                null,
                "locked=0",
                null,
                null,
                null,
                "id ASC",
                "1"
            );
            
            if (cursor.moveToFirst()) {
                LocationModel location = cursorToLocation(cursor);
                
                if (location != null) {
                    // Lock it
                    ContentValues values = new ContentValues();
                    values.put("locked", 1);
                    db.update(
                        LocationOpenHelper.LOCATIONS_TABLE,
                        values,
                        "id=?",
                        new String[]{String.valueOf(location.id)}
                    );
                    
                    Log.d(TAG, "✅ Locked 1 record: " + location.uuid);
                }
                
                return location;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in first: " + e.getMessage());
        } finally {
            if (cursor != null) cursor.close();
        }
        
        return null;
    }
    
    /**
     * Insert location
     */
    public String persist(JSONObject json) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return null;
        
        try {
            String uuid = json.has("uuid") ? json.getString("uuid") : UUID.randomUUID().toString();
            String timestamp = json.has("timestamp") ? 
                String.valueOf(json.getLong("timestamp")) : 
                String.valueOf(System.currentTimeMillis());
            
            if (!json.has("uuid")) {
                json.put("uuid", uuid);
            }
            
            ContentValues values = new ContentValues();
            values.put("uuid", uuid);
            values.put("timestamp", timestamp);
            values.put("data", json.toString().getBytes()); // Store as BLOB
            values.put("encrypted", 0);
            values.put("locked", 0);
            
            db.beginTransaction();
            try {
                long rowId = db.insert(LocationOpenHelper.LOCATIONS_TABLE, null, values);
                db.setTransactionSuccessful();
                
                if (rowId > -1) {
                    Log.d(TAG, "✅ INSERT: " + uuid);
                    return uuid;
                } else {
                    Log.e(TAG, "❌ INSERT failed");
                    return null;
                }
            } finally {
                db.endTransaction();
            }
        } catch (Exception e) {
            Log.e(TAG, "Persist error: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * Get count of locations
     */
    public int count() {
        return count(false);
    }
    
    /**
     * Get count (optionally only unlocked)
     */
    public int count(boolean onlyUnlocked) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return 0;
        
        Cursor cursor = null;
        try {
            String query = "SELECT count(*) FROM " + LocationOpenHelper.LOCATIONS_TABLE;
            if (onlyUnlocked) {
                query += " WHERE locked=0";
            }
            
            cursor = db.rawQuery(query, null);
            if (cursor.moveToFirst()) {
                return cursor.getInt(0);
            }
        } catch (Exception e) {
            Log.e(TAG, "Count error: " + e.getMessage());
        } finally {
            if (cursor != null) cursor.close();
        }
        
        return 0;
    }
    
    /**
     * Delete location
     */
    public boolean destroy(LocationModel location) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return false;
        
        db.beginTransaction();
        try {
            int deleted = db.delete(
                LocationOpenHelper.LOCATIONS_TABLE,
                "id=?",
                new String[]{String.valueOf(location.id)}
            );
            
            db.setTransactionSuccessful();
            
            if (deleted == 1) {
                Log.d(TAG, "✅ DESTROY: " + location.uuid);
                return true;
            } else {
                Log.e(TAG, "❌ DESTROY failed: " + location.uuid);
                return false;
            }
        } finally {
            db.endTransaction();
        }
    }
    
    /**
     * CRITICAL: Delete multiple locations (after successful sync)
     */
    public void destroyAll(List<LocationModel> locations) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return;
        
        List<Integer> ids = new ArrayList<>();
        for (LocationModel loc : locations) {
            ids.add(loc.id);
        }
        
        if (ids.isEmpty()) return;
        
        db.beginTransaction();
        try {
            String whereClause = "id IN (" + TextUtils.join(",", ids) + ")";
            int deleted = db.delete(LocationOpenHelper.LOCATIONS_TABLE, whereClause, null);
            
            db.setTransactionSuccessful();
            
            if (deleted == locations.size()) {
                Log.d(TAG, "✅ DELETED: (" + deleted + " records)");
            } else {
                Log.e(TAG, "❌ DELETE mismatch: expected " + locations.size() + ", deleted " + deleted);
            }
        } finally {
            db.endTransaction();
        }
    }
    
    /**
     * CRITICAL: Unlock locations (for retry after failed sync)
     */
    public boolean unlock(List<LocationModel> locations) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return false;
        
        List<Integer> ids = new ArrayList<>();
        for (LocationModel loc : locations) {
            ids.add(loc.id);
        }
        
        if (ids.isEmpty()) return false;
        
        db.beginTransaction();
        try {
            ContentValues values = new ContentValues();
            values.put("locked", 0);
            
            String whereClause = "id IN (" + TextUtils.join(",", ids) + ")";
            int updated = db.update(LocationOpenHelper.LOCATIONS_TABLE, values, whereClause, null);
            
            db.setTransactionSuccessful();
            
            boolean success = (updated == locations.size());
            if (success) {
                Log.d(TAG, "✅ UNLOCKED: (" + updated + " records)");
            } else {
                Log.e(TAG, "❌ UNLOCK mismatch: expected " + locations.size() + ", unlocked " + updated);
            }
            
            return success;
        } finally {
            db.endTransaction();
        }
    }
    
    /**
     * Unlock all locations
     */
    public boolean unlockAll() {
        SQLiteDatabase db = getDatabase();
        if (db == null) return false;
        
        db.beginTransaction();
        try {
            ContentValues values = new ContentValues();
            values.put("locked", 0);
            
            int updated = db.update(LocationOpenHelper.LOCATIONS_TABLE, values, null, null);
            db.setTransactionSuccessful();
            
            Log.d(TAG, "✅ UNLOCKED ALL: " + updated + " records");
            return true;
        } finally {
            db.endTransaction();
        }
    }
    
    /**
     * Clear all locations
     */
    public boolean clear() {
        SQLiteDatabase db = getDatabase();
        if (db == null) return false;
        
        db.beginTransaction();
        try {
            db.delete(LocationOpenHelper.LOCATIONS_TABLE, null, null);
            db.setTransactionSuccessful();
            Log.d(TAG, "✅ Database cleared");
            return true;
        } finally {
            db.endTransaction();
        }
    }
    
    /**
     * Prune old records
     */
    public void prune(int days) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return;
        
        db.beginTransaction();
        try {
            String whereClause = "datetime(timestamp) < datetime('now', '-" + days + " day')";
            int deleted = db.delete(LocationOpenHelper.LOCATIONS_TABLE, whereClause, null);
            
            db.setTransactionSuccessful();
            Log.d(TAG, "✅ PRUNED: " + deleted + " old records (>" + days + " days)");
        } finally {
            db.endTransaction();
        }
    }
    
    /**
     * Shrink database to max size
     */
    public void shrink(int maxRecords) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return;
        
        db.beginTransaction();
        try {
            String whereClause = "id <= (SELECT id FROM (SELECT id FROM " + 
                LocationOpenHelper.LOCATIONS_TABLE + 
                " ORDER BY id DESC LIMIT 1 OFFSET " + maxRecords + ") foo)";
            
            int deleted = db.delete(LocationOpenHelper.LOCATIONS_TABLE, whereClause, null);
            
            db.setTransactionSuccessful();
            
            if (deleted > 0) {
                Log.d(TAG, "✅ SHRINK: deleted " + deleted + " records (limit: " + maxRecords + ")");
            }
        } finally {
            db.endTransaction();
        }
    }
    
    /**
     * Convert Cursor to LocationModel
     */
    private LocationModel cursorToLocation(Cursor cursor) {
        try {
            int id = cursor.getInt(cursor.getColumnIndexOrThrow("id"));
            String uuid = cursor.getString(cursor.getColumnIndexOrThrow("uuid"));
            String timestamp = cursor.getString(cursor.getColumnIndexOrThrow("timestamp"));
            byte[] dataBlob = cursor.getBlob(cursor.getColumnIndexOrThrow("data"));
            
            // Parse JSON from BLOB
            String jsonStr = new String(dataBlob);
            JSONObject json = new JSONObject(jsonStr);
            
            LocationModel location = LocationModel.fromJSON(json);
            if (location != null) {
                location.id = id;
                location.uuid = uuid;
            }
            
            return location;
        } catch (Exception e) {
            Log.e(TAG, "Failed to parse location from cursor: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * Get writable database
     */
    private SQLiteDatabase getDatabase() {
        try {
            return LocationOpenHelper.getInstance(context).getWritableDatabase();
        } catch (Exception e) {
            Log.e(TAG, "Failed to open database: " + e.getMessage());
            return null;
        }
    }
}



