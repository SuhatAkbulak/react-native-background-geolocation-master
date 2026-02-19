package com.backgroundlocation.event;

/**
 * PowerSaveModeChangeEvent
 * PowerSaveModeChangeEvent.java
 * Power save mode değişiklik event
 */
public class PowerSaveModeChangeEvent {
    private final boolean isPowerSaveMode;
    
    public PowerSaveModeChangeEvent(boolean isPowerSaveMode) {
        this.isPowerSaveMode = isPowerSaveMode;
    }
    
    public boolean isPowerSaveMode() {
        return isPowerSaveMode;
    }
    
    public String getEventName() {
        return "powersavemodechange";
    }
}

