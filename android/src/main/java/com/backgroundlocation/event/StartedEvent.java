package com.backgroundlocation.event;

/**
 * StartedEvent
 * StartedEvent.java
 * Başlatıldı event
 */
public class StartedEvent {
    public final boolean success;
    
    public StartedEvent(boolean success) {
        this.success = success;
    }
    
    public boolean isSuccess() {
        return success;
    }
    
    public String getEventName() {
        return "started";
    }
}

