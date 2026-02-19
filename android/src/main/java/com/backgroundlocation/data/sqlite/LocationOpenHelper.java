package com.backgroundlocation.data.sqlite;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;

/**
 * SQLite Database Helper
 * RAW SQLite implementation
 */
public class LocationOpenHelper extends SQLiteOpenHelper {
    
    private static final String TAG = "LocationOpenHelper";
    private static final String DATABASE_NAME = "background_location.db";
    private static final int DATABASE_VERSION = 1;
    
    public static final String LOCATIONS_TABLE = "locations";
    public static final String GEOFENCES_TABLE = "geofences";
    
    // Locations table schema
    private static final String CREATE_LOCATIONS_TABLE = 
        "CREATE TABLE IF NOT EXISTS locations (" +
        "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
        "uuid TEXT NOT NULL DEFAULT '', " +
        "timestamp TEXT, " +
        "data BLOB, " +                          // JSON as BLOB ()
        "encrypted BOOLEAN NOT NULL DEFAULT 0, " +
        "locked BOOLEAN NOT NULL DEFAULT 0" +    // CRITICAL: Locking column
        ");";
    
    // Geofences table schema
    private static final String CREATE_GEOFENCES_TABLE =
        "CREATE TABLE IF NOT EXISTS geofences (" +
        "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
        "identifier TEXT NOT NULL UNIQUE, " +
        "latitude DOUBLE NOT NULL, " +
        "longitude DOUBLE NOT NULL, " +
        "radius DOUBLE NOT NULL, " +
        "notifyOnEntry BOOLEAN NOT NULL DEFAULT 0, " +
        "notifyOnExit BOOLEAN NOT NULL DEFAULT 0, " +
        "notifyOnDwell BOOLEAN NOT NULL DEFAULT 0, " +
        "loiteringDelay INTEGER NOT NULL DEFAULT 0, " +
        "extras TEXT" +
        ");";
    
    // Indexes for performance ()
    private static final String CREATE_LOCKED_INDEX = 
        "CREATE INDEX IF NOT EXISTS idx_locked ON locations(locked);";
    
    private static final String CREATE_TIMESTAMP_INDEX =
        "CREATE INDEX IF NOT EXISTS idx_timestamp ON locations(timestamp);";
    
    private static LocationOpenHelper instance;
    
    private LocationOpenHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }
    
    public static synchronized LocationOpenHelper getInstance(Context context) {
        if (instance == null) {
            instance = new LocationOpenHelper(context.getApplicationContext());
        }
        return instance;
    }
    
    @Override
    public void onCreate(SQLiteDatabase db) {
        Log.d(TAG, "🛠 Creating database tables");
        
        // Create tables
        db.execSQL(CREATE_LOCATIONS_TABLE);
        db.execSQL(CREATE_GEOFENCES_TABLE);
        
        // Create indexes
        db.execSQL(CREATE_LOCKED_INDEX);
        db.execSQL(CREATE_TIMESTAMP_INDEX);
        
        Log.d(TAG, "✅ Database created successfully");
    }
    
    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        Log.d(TAG, "🛠 Upgrading database from version " + oldVersion + " to " + newVersion);
        
        // Add new columns if needed (migration)
        // For now, simple approach:
        if (oldVersion < newVersion) {
            db.execSQL("DROP TABLE IF EXISTS locations");
            db.execSQL("DROP TABLE IF EXISTS geofences");
            onCreate(db);
        }
    }
    
    @Override
    public synchronized SQLiteDatabase getWritableDatabase() {
        return super.getWritableDatabase();
    }
    
    @Override
    public synchronized SQLiteDatabase getReadableDatabase() {
        return super.getReadableDatabase();
    }
}



