package com.backgroundlocation.event;

import android.content.Context;
import java.util.ArrayList;
import java.util.List;

/**
 * ConfigChangeEvent
 * ConfigChangeEvent.java
 * Config değişiklik event
 */
public class ConfigChangeEvent {
    private final Context context;
    private final List<String> dirtyFields;
    
    public ConfigChangeEvent(Context context, List<String> dirtyFields) {
        this.context = context;
        this.dirtyFields = new ArrayList<>(dirtyFields);
    }
    
    public Context getContext() {
        return context;
    }
    
    public boolean isDirty(String fieldName) {
        synchronized (dirtyFields) {
            return dirtyFields.contains(fieldName);
        }
    }
    
    public List<String> getDirtyFields() {
        synchronized (dirtyFields) {
            return new ArrayList<>(dirtyFields);
        }
    }
    
    public String getEventName() {
        return "configchange";
    }
    
    @Override
    public String toString() {
        return "ConfigChangeEvent{Dirty: " + dirtyFields.toString() + "}";
    }
}

