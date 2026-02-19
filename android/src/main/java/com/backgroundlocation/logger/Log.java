package com.backgroundlocation.logger;

import android.content.Context;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.adapter.callback.Callback;
import com.backgroundlocation.adapter.callback.EmailLogCallback;
import com.backgroundlocation.adapter.callback.GetLogCallback;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.data.SQLQuery;
import com.backgroundlocation.device.DeviceInfo;
import com.backgroundlocation.util.LogHelper;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.zip.GZIPOutputStream;

/**
 * Log
 * Log
 * Log yönetimi - formatted logging, email log, get log
 */
public class Log {
    
    public static final String ACTION_EMAIL_LOG = "emailLog";
    public static final String ACTION_GET_LOG = "getLog";
    public static final String ACTION_LOG = "log";
    public static final String ACTION_UPLOAD_LOG = "uploadLog";
    
    // Box drawing characters
    public static final String BOX_BOTTOM = "╚═════════════════════════════════════════════";
    public static final String BOX_HEADER_BOTTOM = "╠═════════════════════════════════════════════";
    public static final String BOX_HEADER_MIDDLE = "║";
    public static final String BOX_HEADER_TOP = "╔═════════════════════════════════════════════";
    public static final String BOX_ROW = "╟─ ";
    public static final String CRLF = "\n";
    public static final String HR = "╔══════════════════════════════════════════════";
    
    // Icons
    public static final String ICON_ACTIVITY = "🚘 ️";
    public static final String ICON_ALARM = "⏰ ";
    public static final String ICON_CALENDAR = "📅  ";
    public static final String ICON_CANCEL = "❌ ";
    public static final String ICON_CHECK = "✅  ";
    public static final String ICON_ERROR = "‼️  ";
    public static final String ICON_HOURGLASS = "⏳";
    public static final String ICON_INFO = "ℹ️  ";
    public static final String ICON_NOTICE = "🔵  ";
    public static final String ICON_OFF = "🔴  ";
    public static final String ICON_ON = "🎾  ";
    public static final String ICON_PIN = "📍  ";
    public static final String ICON_SIGNAL_BARS = "📶  ";
    public static final String ICON_WARN = "⚠️  ";
    
    public static final String LOG_FILENAME = "background-geolocation.log.gz";
    public static final String TAB = "  ";
    public static final String TREE_SW = "└";
    
    public static LoggerFacade logger = new LoggerFacade();
    
    /**
     * Format header
     */
    public static String header(String title) {
        return BOX_HEADER_TOP + "\n" +
               BOX_HEADER_MIDDLE + " " + title + "\n" +
               BOX_HEADER_BOTTOM + "\n";
    }
    
    /**
     * Format box row
     */
    public static String boxRow(String text) {
        return BOX_ROW + text + "\n";
    }
    
    /**
     * Format info
     */
    public static String info(String message) {
        return ICON_INFO + message;
    }
    
    /**
     * Format notice
     */
    public static String notice(String message) {
        return ICON_NOTICE + message;
    }
    
    /**
     * Format warn
     */
    public static String warn(String message) {
        return ICON_WARN + message;
    }
    
    /**
     * Format error
     */
    public static String error(String message) {
        return ICON_ERROR + message;
    }
    
    /**
     * Format on
     */
    public static String on(String message) {
        return ICON_ON + message;
    }
    
    /**
     * Format off
     */
    public static String off(String message) {
        return ICON_OFF + message;
    }
    
    /**
     * Format pin
     */
    public static String pin(String message) {
        return ICON_PIN + message;
    }
    
    /**
     * Get database appender
     */
    public static SQLiteAppender getDatabaseAppender() {
        return SQLiteAppender.getInstance();
    }
    
    /**
     * Write log file
     */
    public static File writeLogFile(Context context, String logContent) {
        try {
            File logFile = new File(context.getCacheDir(), LOG_FILENAME);
            FileOutputStream fos = new FileOutputStream(logFile);
            GZIPOutputStream gzos = new GZIPOutputStream(fos);
            gzos.write(logContent.getBytes("UTF-8"));
            gzos.close();
            fos.close();
            return logFile;
        } catch (IOException e) {
            LogHelper.e("Log", "Failed to write log file: " + e.getMessage(), e);
            return null;
        }
    }
    
    /**
     * Get log
     */
    public static void getLog(Context context, SQLQuery query, GetLogCallback callback) {
        BackgroundLocationAdapter.getThreadPool().execute(() -> {
            try {
                String log = LogReader.getLog(context, query);
                if (log != null) {
                    BackgroundLocationAdapter.getUiHandler().post(() -> {
                        try {
                            callback.onSuccess(new JSONObject().put("log", log));
                        } catch (Exception e) {
                            callback.onFailure(e.getMessage());
                        }
                    });
                } else {
                    BackgroundLocationAdapter.getUiHandler().post(() -> {
                        callback.onFailure("Failed to fetch logs");
                    });
                }
            } catch (Exception e) {
                BackgroundLocationAdapter.getUiHandler().post(() -> {
                    callback.onFailure(e.getMessage());
                });
            }
        });
    }
    
    /**
     * Email log
     */
    public static void emailLog(android.app.Activity activity, String email, 
                                SQLQuery query, EmailLogCallback callback) {
        BackgroundLocationAdapter.getThreadPool().execute(() -> {
            try {
                String log = LogReader.getLog(activity, query);
                if (log == null) {
                    BackgroundLocationAdapter.getUiHandler().post(() -> {
                        callback.onFailure("Failed to read log database.");
                    });
                    return;
                }
                
                android.content.Intent intent = new android.content.Intent(android.content.Intent.ACTION_SEND);
                intent.setType("message/rfc822");
                intent.putExtra(android.content.Intent.EXTRA_EMAIL, new String[]{email});
                intent.putExtra(android.content.Intent.EXTRA_SUBJECT, "BackgroundGeolocation log");
                
                Config config = Config.getInstance(activity);
                StringBuilder body = new StringBuilder();
                body.append(header("TSLocationManager"));
                body.append(boxRow(DeviceInfo.getInstance(activity).print()));
                try {
                    body.append(config.toJSON().toString(2));
                } catch (Exception e) {
                    LogHelper.e("Log", "Failed to write state to email body: " + e.getMessage(), e);
                }
                
                intent.putExtra(android.content.Intent.EXTRA_TEXT, body.toString());
                
                File logFile = writeLogFile(activity, log);
                if (logFile == null) {
                    BackgroundLocationAdapter.getUiHandler().post(() -> {
                        callback.onFailure("Failed to write log file");
                    });
                    return;
                }
                
                // TODO: FileProvider URI
                // intent.putExtra(android.content.Intent.EXTRA_STREAM, FileProvider.getUriForFile(...));
                logFile.deleteOnExit();
                
                activity.runOnUiThread(() -> {
                    try {
                        activity.startActivityForResult(android.content.Intent.createChooser(intent, 
                            "Send log: " + email + "..."), 1);
                        callback.onSuccess();
                    } catch (android.content.ActivityNotFoundException e) {
                        callback.onFailure("NO_EMAIL_CLIENT");
                    }
                });
            } catch (Exception e) {
                BackgroundLocationAdapter.getUiHandler().post(() -> {
                    callback.onFailure(e.getMessage());
                });
            }
        });
    }
    
    /**
     * Destroy log
     */
    public static void destroyLog(Callback callback) {
        BackgroundLocationAdapter.getThreadPool().execute(() -> {
            if (getDatabaseAppender().destroyLog()) {
                BackgroundLocationAdapter.getUiHandler().post(() -> {
                    callback.onSuccess();
                });
            } else {
                BackgroundLocationAdapter.getUiHandler().post(() -> {
                    callback.onFailure("Failed to destroy log");
                });
            }
        });
    }
}

