package com.backgroundlocation.data.sqlite;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.util.Log;

import com.backgroundlocation.data.GeofenceModel;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * SQLite Geofence DAO
 * RAW SQLite operations
 */
public class SQLiteGeofenceDAO {
    
    private static final String TAG = "SQLiteGeofenceDAO";
    private static SQLiteGeofenceDAO instance;
    private Context context;
    
    private SQLiteGeofenceDAO(Context context) {
        this.context = context.getApplicationContext();
    }
    
    public static synchronized SQLiteGeofenceDAO getInstance(Context context) {
        if (instance == null) {
            instance = new SQLiteGeofenceDAO(context);
        }
        return instance;
    }
    
    /**
     * Insert or replace geofence
     */
    public boolean persist(GeofenceModel geofence) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return false;
        
        try {
            JSONObject json = geofence.toJSON();
            
            ContentValues values = new ContentValues();
            values.put("identifier", geofence.getIdentifier());
            values.put("latitude", geofence.getLatitude());
            values.put("longitude", geofence.getLongitude());
            values.put("radius", geofence.getRadius());
            values.put("notifyOnEntry", geofence.getNotifyOnEntry() ? 1 : 0);
            values.put("notifyOnExit", geofence.getNotifyOnExit() ? 1 : 0);
            values.put("notifyOnDwell", geofence.getNotifyOnDwell() ? 1 : 0);
            values.put("loiteringDelay", geofence.getLoiteringDelay());
            
            // Store full JSON in extras (includes vertices for polygon)
            if (json.has("extras")) {
                values.put("extras", json.getJSONObject("extras").toString());
            } else {
                // Store full geofence JSON in extras for polygon support
                values.put("extras", json.toString());
            }
            
            db.beginTransaction();
            try {
                long rowId = db.insertWithOnConflict(
                    LocationOpenHelper.GEOFENCES_TABLE,
                    null,
                    values,
                    SQLiteDatabase.CONFLICT_REPLACE
                );
                
                db.setTransactionSuccessful();
                
                if (rowId > -1) {
                    Log.d(TAG, "✅ INSERT geofence: " + geofence.getIdentifier());
                    return true;
                }
            } finally {
                db.endTransaction();
            }
        } catch (Exception e) {
            Log.e(TAG, "Persist geofence error: " + e.getMessage());
        }
        
        return false;
    }
    
    /**
     * Get all geofences
     */
    public List<GeofenceModel> all() {
        List<GeofenceModel> geofences = new ArrayList<>();
        SQLiteDatabase db = getDatabase();
        if (db == null) return geofences;
        
        Cursor cursor = null;
        try {
            cursor = db.query(
                LocationOpenHelper.GEOFENCES_TABLE,
                null,
                null,
                null,
                null,
                null,
                "id ASC",
                null
            );
            
            while (cursor.moveToNext()) {
                GeofenceModel geofence = cursorToGeofence(cursor);
                if (geofence != null) {
                    geofences.add(geofence);
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error fetching geofences: " + e.getMessage());
        } finally {
            if (cursor != null) cursor.close();
        }
        
        return geofences;
    }
    
    /**
     * Get geofence by identifier
     */
    public GeofenceModel get(String identifier) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return null;
        
        Cursor cursor = null;
        try {
            cursor = db.query(
                LocationOpenHelper.GEOFENCES_TABLE,
                null,
                "identifier=?",
                new String[]{identifier},
                null,
                null,
                null,
                "1"
            );
            
            if (cursor.moveToFirst()) {
                return cursorToGeofence(cursor);
            }
        } catch (Exception e) {
            Log.e(TAG, "Get geofence error: " + e.getMessage());
        } finally {
            if (cursor != null) cursor.close();
        }
        
        return null;
    }
    
    /**
     * Find geofence by identifier (alias for get)
     */
    public GeofenceModel find(String identifier) {
        return get(identifier);
    }
    
    /**
     * Delete geofence by identifier
     */
    public boolean delete(String identifier) {
        return destroy(identifier);
    }
    
    /**
     * Get all identifiers
     */
    public List<String> getAllIdentifiers() {
        List<String> identifiers = new ArrayList<>();
        SQLiteDatabase db = getDatabase();
        if (db == null) return identifiers;
        
        Cursor cursor = null;
        try {
            cursor = db.query(
                LocationOpenHelper.GEOFENCES_TABLE,
                new String[]{"identifier"},
                null,
                null,
                null,
                null,
                null,
                null
            );
            
            while (cursor.moveToNext()) {
                identifiers.add(cursor.getString(0));
            }
        } catch (Exception e) {
            Log.e(TAG, "Error fetching identifiers: " + e.getMessage());
        } finally {
            if (cursor != null) cursor.close();
        }
        
        return identifiers;
    }
    
    /**
     * Get geofence count
     */
    public int count() {
        SQLiteDatabase db = getDatabase();
        if (db == null) return 0;
        
        Cursor cursor = null;
        try {
            cursor = db.rawQuery("SELECT COUNT(*) FROM " + LocationOpenHelper.GEOFENCES_TABLE, null);
            if (cursor.moveToFirst()) {
                return cursor.getInt(0);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error counting geofences: " + e.getMessage());
        } finally {
            if (cursor != null) cursor.close();
        }
        
        return 0;
    }
    
    /**
     * Check if geofence exists
     */
    public boolean exists(String identifier) {
        return get(identifier) != null;
    }
    
    /**
     * Delete geofence
     */
    public boolean destroy(String identifier) {
        SQLiteDatabase db = getDatabase();
        if (db == null) return false;
        
        db.beginTransaction();
        try {
            int deleted = db.delete(
                LocationOpenHelper.GEOFENCES_TABLE,
                "identifier=?",
                new String[]{identifier}
            );
            
            db.setTransactionSuccessful();
            
            if (deleted > 0) {
                Log.d(TAG, "✅ DELETED geofence: " + identifier);
                return true;
            }
        } finally {
            db.endTransaction();
        }
        
        return false;
    }
    
    /**
     * Delete all geofences
     */
    public boolean clear() {
        SQLiteDatabase db = getDatabase();
        if (db == null) return false;
        
        db.beginTransaction();
        try {
            db.delete(LocationOpenHelper.GEOFENCES_TABLE, null, null);
            db.setTransactionSuccessful();
            Log.d(TAG, "✅ All geofences cleared");
            return true;
        } finally {
            db.endTransaction();
        }
    }
    
    /**
     * Convert Cursor to GeofenceModel
     */
    private GeofenceModel cursorToGeofence(Cursor cursor) {
        try {
            JSONObject json = new JSONObject();
            json.put("identifier", cursor.getString(cursor.getColumnIndexOrThrow("identifier")));
            json.put("latitude", cursor.getDouble(cursor.getColumnIndexOrThrow("latitude")));
            json.put("longitude", cursor.getDouble(cursor.getColumnIndexOrThrow("longitude")));
            json.put("radius", cursor.getDouble(cursor.getColumnIndexOrThrow("radius")));
            json.put("notifyOnEntry", cursor.getInt(cursor.getColumnIndexOrThrow("notifyOnEntry")) == 1);
            json.put("notifyOnExit", cursor.getInt(cursor.getColumnIndexOrThrow("notifyOnExit")) == 1);
            json.put("notifyOnDwell", cursor.getInt(cursor.getColumnIndexOrThrow("notifyOnDwell")) == 1);
            json.put("loiteringDelay", cursor.getInt(cursor.getColumnIndexOrThrow("loiteringDelay")));
            
            int extrasIndex = cursor.getColumnIndex("extras");
            if (extrasIndex >= 0 && !cursor.isNull(extrasIndex)) {
                String extrasStr = cursor.getString(extrasIndex);
                if (extrasStr != null && !extrasStr.isEmpty()) {
                    json.put("extras", new JSONObject(extrasStr));
                }
            }
            
            // Vertices (polygon) - TODO: Add to database schema if needed
            // For now, polygon geofences will be stored in extras or separate table
            
            return GeofenceModel.fromJSON(json);
        } catch (Exception e) {
            Log.e(TAG, "Failed to parse geofence from cursor: " + e.getMessage());
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



