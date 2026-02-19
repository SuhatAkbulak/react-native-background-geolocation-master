package com.backgroundlocation.logger;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import com.backgroundlocation.data.SQLQuery;
import com.backgroundlocation.util.LogHelper;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/**
 * LogReader
 * TSLogReader.java
 * Log reader - SQLite'den log okuma
 */
public class LogReader {
    
    private static final String DATE_FORMAT = "MM-dd HH:mm:ss.SSS";
    private static final SimpleDateFormat dateFormatter;
    
    static {
        dateFormatter = new SimpleDateFormat(DATE_FORMAT, Locale.ENGLISH);
        dateFormatter.setTimeZone(TimeZone.getDefault());
    }
    
    /**
     * Get log from database
     */
    public static String getLog(Context context, SQLQuery query) {
        SQLiteAppender appender = SQLiteAppender.getInstance();
        SQLiteDatabase database = appender.getDatabase(context);
        
        if (database == null || !database.isOpen()) {
            LogHelper.e("LogReader", "Database is null or not open");
            return null;
        }
        
        try {
            StringBuilder logBuffer = new StringBuilder();
            
            // Build query
            String tableName = "logging_event";
            String[] columns = {"event_id", "timestmp", "level_string", "caller_class", "caller_method", "formatted_message"};
            String selection = query != null ? query.getSelection() : null;
            String[] selectionArgs = query != null ? query.getSelectionArgs() : null;
            String orderBy = query != null && query.getOrderBy() != null ? query.getOrderBy() : "event_id ASC";
            String limit = query != null ? query.getLimit() : null;
            
            Cursor cursor = database.query(tableName, columns, selection, selectionArgs, null, null, orderBy, limit);
            
            if (cursor != null) {
                try {
                    while (cursor.moveToNext()) {
                        long eventId = cursor.getLong(cursor.getColumnIndexOrThrow("event_id"));
                        long timestamp = cursor.getLong(cursor.getColumnIndexOrThrow("timestmp"));
                        String level = cursor.getString(cursor.getColumnIndexOrThrow("level_string"));
                        String callerClass = cursor.getString(cursor.getColumnIndexOrThrow("caller_class"));
                        String callerMethod = cursor.getString(cursor.getColumnIndexOrThrow("caller_method"));
                        String message = cursor.getString(cursor.getColumnIndexOrThrow("formatted_message"));
                        
                        // Format log entry
                        logBuffer.append(dateFormatter.format(new Date(timestamp))).append(" ");
                        logBuffer.append(level).append(" ");
                        logBuffer.append("[");
                        
                        // Get class name (last part)
                        String[] classParts = callerClass.split("\\.");
                        if (classParts.length > 0) {
                            logBuffer.append(classParts[classParts.length - 1]);
                        }
                        logBuffer.append(" ");
                        logBuffer.append(callerMethod);
                        logBuffer.append("] ");
                        logBuffer.append(message);
                        logBuffer.append("\n");
                        
                        // Get exception if exists
                        String exception = getException(database, eventId);
                        if (exception != null) {
                            logBuffer.append(exception);
                            logBuffer.append("\n");
                        }
                    }
                } finally {
                    cursor.close();
                }
            }
            
            return logBuffer.toString();
        } catch (Exception e) {
            LogHelper.e("LogReader", "Error reading log: " + e.getMessage(), e);
            return null;
        }
    }
    
    /**
     * Get exception for event
     */
    private static String getException(SQLiteDatabase database, long eventId) {
        try {
            String tableName = "logging_event_exception";
            String[] columns = {"i", "trace_line"};
            String selection = "event_id = ?";
            String[] selectionArgs = {String.valueOf(eventId)};
            String orderBy = "i ASC";
            
            Cursor cursor = database.query(tableName, columns, selection, selectionArgs, null, null, orderBy);
            
            if (cursor != null) {
                try {
                    StringBuilder exception = new StringBuilder();
                    while (cursor.moveToNext()) {
                        String traceLine = cursor.getString(cursor.getColumnIndexOrThrow("trace_line"));
                        exception.append(traceLine).append("\n");
                    }
                    return exception.length() > 0 ? exception.toString() : null;
                } finally {
                    cursor.close();
                }
            }
        } catch (Exception e) {
            LogHelper.w("LogReader", "Error reading exception: " + e.getMessage());
        }
        return null;
    }
}

