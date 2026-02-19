package com.backgroundlocation.logger;

import android.util.Log;

import java.util.ArrayList;
import java.util.List;

/**
 * LoggerFacade
 * LoggerFacade
 * Logger facade - Simple logger implementation
 */
public class LoggerFacade {
    
    private final List<LogEntry> queue = new ArrayList<>();
    private boolean isEnabled = false;
    
    /**
     * Log entry
     */
    public static class LogEntry {
        private final String level;
        private final String message;
        private final Throwable throwable;
        
        public LogEntry(String level, String message, Throwable throwable) {
            this.level = level;
            this.message = message;
            this.throwable = throwable;
        }
        
        public String getLevel() { return level; }
        public String getMessage() { return message; }
        public Throwable getThrowable() { return throwable; }
    }
    
    public void clear() {
        isEnabled = true;
        synchronized (queue) {
            queue.clear();
        }
    }
    
    public List<LogEntry> getQueue() {
        synchronized (queue) {
            List<LogEntry> result = new ArrayList<>(queue);
            queue.clear();
            return result;
        }
    }
    
    public void debug(String message) {
        if (isEnabled) {
            synchronized (queue) {
                queue.add(new LogEntry("DEBUG", message, null));
            }
        }
        Log.d("LoggerFacade", message);
    }
    
    public void debug(String format, Object arg) {
        debug(String.format(format, arg));
    }
    
    public void debug(String format, Object arg1, Object arg2) {
        debug(String.format(format, arg1, arg2));
    }
    
    public void debug(String format, Object... arguments) {
        debug(String.format(format, arguments));
    }
    
    public void debug(String message, Throwable t) {
        if (isEnabled) {
            synchronized (queue) {
                queue.add(new LogEntry("DEBUG", message, t));
            }
        }
        Log.d("LoggerFacade", message, t);
    }
    
    public void info(String message) {
        if (isEnabled) {
            synchronized (queue) {
                queue.add(new LogEntry("INFO", message, null));
            }
        }
        Log.i("LoggerFacade", message);
    }
    
    public void info(String format, Object arg) {
        info(String.format(format, arg));
    }
    
    public void info(String format, Object arg1, Object arg2) {
        info(String.format(format, arg1, arg2));
    }
    
    public void info(String format, Object... arguments) {
        info(String.format(format, arguments));
    }
    
    public void info(String message, Throwable t) {
        if (isEnabled) {
            synchronized (queue) {
                queue.add(new LogEntry("INFO", message, t));
            }
        }
        Log.i("LoggerFacade", message, t);
    }
    
    public void warn(String message) {
        if (isEnabled) {
            synchronized (queue) {
                queue.add(new LogEntry("WARN", message, null));
            }
        }
        Log.w("LoggerFacade", message);
    }
    
    public void warn(String format, Object arg) {
        warn(String.format(format, arg));
    }
    
    public void warn(String format, Object arg1, Object arg2) {
        warn(String.format(format, arg1, arg2));
    }
    
    public void warn(String format, Object... arguments) {
        warn(String.format(format, arguments));
    }
    
    public void warn(String message, Throwable t) {
        if (isEnabled) {
            synchronized (queue) {
                queue.add(new LogEntry("WARN", message, t));
            }
        }
        Log.w("LoggerFacade", message, t);
    }
    
    public void error(String message) {
        if (isEnabled) {
            synchronized (queue) {
                queue.add(new LogEntry("ERROR", message, null));
            }
        }
        Log.e("LoggerFacade", message);
    }
    
    public void error(String format, Object arg) {
        error(String.format(format, arg));
    }
    
    public void error(String format, Object arg1, Object arg2) {
        error(String.format(format, arg1, arg2));
    }
    
    public void error(String format, Object... arguments) {
        error(String.format(format, arguments));
    }
    
    public void error(String message, Throwable t) {
        if (isEnabled) {
            synchronized (queue) {
                queue.add(new LogEntry("ERROR", message, t));
            }
        }
        Log.e("LoggerFacade", message, t);
    }
    
    public void trace(String message) {
        // Trace not implemented
    }
    
    public void trace(String format, Object arg) {
        // Trace not implemented
    }
    
    public void trace(String format, Object arg1, Object arg2) {
        // Trace not implemented
    }
    
    public void trace(String format, Object... arguments) {
        // Trace not implemented
    }
    
    public void trace(String message, Throwable t) {
        // Trace not implemented
    }
    
    public boolean isTraceEnabled() {
        return false;
    }
    
    public boolean isDebugEnabled() {
        return true;
    }
    
    public boolean isInfoEnabled() {
        return true;
    }
    
    public boolean isWarnEnabled() {
        return true;
    }
    
    public boolean isErrorEnabled() {
        return true;
    }
    
    public String getName() {
        return "LoggerFacade";
    }
}
