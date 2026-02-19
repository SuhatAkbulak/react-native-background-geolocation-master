package com.backgroundlocation.logger;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;
import com.backgroundlocation.util.LogHelper;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * SQLiteAppender
 * TSSQLiteAppender.java
 * SQLite log appender - logları SQLite'a kaydetme
 */
public class SQLiteAppender {
    
    private static final String DATABASE_NAME = "transistor_logback.db";
    private static final int DATABASE_VERSION = 1;
    private static final long MAX_DATABASE_SIZE = 5000000; // 5MB
    private static final long MAX_LOG_AGE = 86400000 * 7; // 7 days
    
    private static SQLiteAppender instance = null;
    private final AtomicLong eventCounter = new AtomicLong(0);
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    
    private SQLiteAppender() {
    }
    
    private static synchronized SQLiteAppender getInstanceInternal() {
        if (instance == null) {
            instance = new SQLiteAppender();
        }
        return instance;
    }
    
    public static SQLiteAppender getInstance() {
        if (instance == null) {
            instance = getInstanceInternal();
        }
        return instance;
    }
    
    /**
     * Get database
     */
    public SQLiteDatabase getDatabase(Context context) {
        LogDatabaseHelper helper = new LogDatabaseHelper(context);
        return helper.getWritableDatabase();
    }
    
    /**
     * Destroy log
     */
    public boolean destroyLog() {
        // TODO: Implement log destruction
        return true;
    }
    
    /**
     * SQLite Database Helper for logs
     */
    private static class LogDatabaseHelper extends SQLiteOpenHelper {
        
        private static final String CREATE_LOGGING_EVENT_TABLE = 
            "CREATE TABLE IF NOT EXISTS logging_event (" +
            "event_id INTEGER PRIMARY KEY AUTOINCREMENT, " +
            "timestmp INTEGER NOT NULL, " +
            "formatted_message TEXT, " +
            "logger_name TEXT, " +
            "level_string TEXT, " +
            "thread_name TEXT, " +
            "reference_flag INTEGER, " +
            "arg0 TEXT, " +
            "arg1 TEXT, " +
            "arg2 TEXT, " +
            "arg3 TEXT, " +
            "caller_filename TEXT, " +
            "caller_class TEXT, " +
            "caller_method TEXT, " +
            "caller_line TEXT, " +
            "mdc TEXT, " +
            "extended_info TEXT" +
            ")";
        
        private static final String CREATE_LOGGING_EVENT_EXCEPTION_TABLE = 
            "CREATE TABLE IF NOT EXISTS logging_event_exception (" +
            "event_id INTEGER NOT NULL, " +
            "i INTEGER NOT NULL, " +
            "trace_line TEXT, " +
            "PRIMARY KEY (event_id, i), " +
            "FOREIGN KEY (event_id) REFERENCES logging_event(event_id)" +
            ")";
        
        private static final String CREATE_LOGGING_EVENT_PROPERTY_TABLE = 
            "CREATE TABLE IF NOT EXISTS logging_event_property (" +
            "event_id INTEGER NOT NULL, " +
            "mapped_key TEXT NOT NULL, " +
            "mapped_value TEXT, " +
            "PRIMARY KEY (event_id, mapped_key), " +
            "FOREIGN KEY (event_id) REFERENCES logging_event(event_id)" +
            ")";
        
        public LogDatabaseHelper(Context context) {
            super(context, DATABASE_NAME, null, DATABASE_VERSION);
        }
        
        @Override
        public void onCreate(SQLiteDatabase db) {
            db.execSQL(CREATE_LOGGING_EVENT_TABLE);
            db.execSQL(CREATE_LOGGING_EVENT_EXCEPTION_TABLE);
            db.execSQL(CREATE_LOGGING_EVENT_PROPERTY_TABLE);
            LogHelper.d("SQLiteAppender", "Log database created");
        }
        
        @Override
        public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
            // Drop and recreate on upgrade
            db.execSQL("DROP TABLE IF EXISTS logging_event_property");
            db.execSQL("DROP TABLE IF EXISTS logging_event_exception");
            db.execSQL("DROP TABLE IF EXISTS logging_event");
            onCreate(db);
        }
    }
}

